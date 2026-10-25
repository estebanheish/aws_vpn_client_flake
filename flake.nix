{
  inputs = {
    utils.url = "github:numtide/flake-utils";
  };
  outputs =
    {
      self,
      nixpkgs,
      utils,
    }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfreePredicate = pkg: nixpkgs.lib.getName pkg == "awsvpnclient";
      };
    in
    {
      nixosModules.default = ./module.nix;

      packages.${system} = {
        awsvpnclient = pkgs.callPackage ./package.nix { };
        default = self.packages.${system}.awsvpnclient;
      };

      checks.${system}.module = pkgs.testers.runNixOSTest {
        name = "awsvpnclient-module";
        nodes.machine = {
          imports = [ self.nixosModules.default ];
          programs.awsvpnclient.enable = true;
          services.resolved.enable = true;
          users.users.alice.isNormalUser = true;
        };
        testScript = ''
          machine.wait_for_unit("aws-client-vpn-daemon.service")
          machine.wait_for_file("/run/awsvpnclient/com.aws.vpn-client.daemon.sock")
          machine.succeed("test -x /opt/awsvpnclient/aws-client-vpn-daemon")
          machine.succeed("su - alice -c 'aws-vpn-client list-profiles'")
          print(machine.succeed("su - alice -c 'aws-vpn-client list-preferences'"))
          # A store-path caller must still be rejected (sanity check of the premise).
          machine.fail("su - alice -c '${self.packages.${system}.awsvpnclient}/opt/awsvpnclient/aws-vpn-client list-profiles'")
          machine.succeed("systemctl restart awsvpnclient-opt.service")
          machine.wait_for_unit("aws-client-vpn-daemon.service")
          machine.wait_until_succeeds("su - alice -c 'aws-vpn-client list-profiles'")
        '';
      };
    }
    // utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShell = pkgs.mkShell {
          buildInputs = with pkgs; [
          ];
        };
      }
    );
}
