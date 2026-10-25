{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.awsvpnclient;
in
{
  options.programs.awsvpnclient = {
    enable = lib.mkEnableOption "the AWS Client VPN client and its daemon";
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ./package.nix { };
      defaultText = lib.literalExpression "pkgs.callPackage ./package.nix { }";
      description = "The awsvpnclient package to use.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    warnings = lib.optional (!config.services.resolved.enable) ''
      programs.awsvpnclient: the daemon's DNS script uses systemd-resolved;
      VPN-pushed DNS servers will not be applied unless services.resolved.enable = true.
    '';

    # The daemon hardcodes /opt/awsvpnclient and rejects IPC from binaries
    # whose real path lies elsewhere, so expose the package there.
    systemd.services.awsvpnclient-opt = {
      description = "Expose AWS VPN Client at /opt/awsvpnclient";
      wantedBy = [ "multi-user.target" ];
      path = [ pkgs.util-linux ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        if mountpoint -q /opt/awsvpnclient; then umount -l /opt/awsvpnclient; fi
        mkdir -p /opt/awsvpnclient
        mount --bind ${cfg.package}/opt/awsvpnclient /opt/awsvpnclient
        mount -o remount,bind,ro /opt/awsvpnclient
      '';
      preStop = ''
        umount -l /opt/awsvpnclient || true
      '';
    };

    systemd.services.aws-client-vpn-daemon = {
      description = "AWS VPN Client Daemon";
      wantedBy = [ "multi-user.target" ];
      after = [
        "network.target"
        "awsvpnclient-opt.service"
      ];
      bindsTo = [ "awsvpnclient-opt.service" ];
      restartTriggers = [ cfg.package ];
      serviceConfig = {
        ExecStart = "/opt/awsvpnclient/aws-client-vpn-daemon";
        Restart = "always";
        RestartSec = "2s";
        TimeoutStopSec = "60s";
        RuntimeDirectory = "awsvpnclient";
        RuntimeDirectoryMode = "0755";
        StateDirectory = "awsvpnclient";
        StateDirectoryMode = "0700";
        LogsDirectory = "awsvpnclient";
        # Hardcoded in the daemon binary.
        BindReadOnlyPaths = [ "${pkgs.iproute2}/bin/ip:/sbin/ip" ];
      };
    };
  };
}
