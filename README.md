# awsvpnclient for NixOS

Nix package and NixOS module for the [AWS Client VPN for Linux](https://docs.aws.amazon.com/vpn/latest/clientvpn-user/client-vpn-connect-linux-release-notes.html)
client, version 6.2.0, repackaged from AWS's official `.deb`.

Version 6 consists of:

- `aws-client-vpn-daemon`: root daemon with OpenVPN built in (systemd service)
- `aws-vpn-client`: command-line client
- `AWS VPN Client`: Electron GUI
- `aws-vpn-client-agent`: device-posture agent

## Why there is a module

The daemon only accepts commands from binaries whose real path is under
`/opt/awsvpnclient`; a CLI run from `/nix/store` gets
`Binary path of caller PID … is not allowed`. The module therefore bind-mounts
the package at `/opt/awsvpnclient` and runs the daemon from there. The
`aws-vpn-client` and `awsvpnclient-gui` commands also start the programs from
`/opt/awsvpnclient`, so **the package does not work without the module**.

The module also:

- bind-mounts `iproute2`'s `ip` at `/sbin/ip` inside the daemon's service, because that path is hardcoded in the daemon
- warns if systemd-resolved is off, since the client's DNS script uses `resolvectl`

## Usage

Add the flake as an input:

```nix
inputs.awsvpnclient.url = "github:estebanheish/aws_vpn_client_flake";
```

Then in your NixOS configuration:

```nix
{ inputs, lib, ... }:
{
  imports = [ inputs.awsvpnclient.nixosModules.default ];

  programs.awsvpnclient.enable = true;
  services.resolved.enable = true;

  nixpkgs.config.allowUnfreePredicate = pkg: lib.getName pkg == "awsvpnclient";
}
```

After `nixos-rebuild switch`:

```sh
aws-vpn-client import-profile --help       # import your .ovpn from the Client VPN endpoint
aws-vpn-client list-profiles
aws-vpn-client connect --help
aws-vpn-client put-preference --help       # e.g. to turn off enable-telemetry (on by default)
```

Or start **AWS VPN Client** from your desktop launcher (`awsvpnclient-gui`).

The daemon logs to `/var/log/awsvpnclient` and journald
(`journalctl -u aws-client-vpn-daemon`).

## Testing

```sh
nix build github:estebanheish/aws_vpn_client_flake#awsvpnclient               # build the package
nix build github:estebanheish/aws_vpn_client_flake#checks.x86_64-linux.module # NixOS VM test (needs KVM)
```

From a local clone, use `.#awsvpnclient` and `.#checks.x86_64-linux.module`.

The VM test checks that the daemon starts, that a normal user can query it
through `/opt/awsvpnclient`, and that the same binary is rejected when run from
its store path.

## Known limitations

- **Not tested with a real VPN connection yet.** The DNS script
  (`dns/configure-dns`) is patched to use store paths. If the daemon checks that
  script's integrity, applying pushed DNS servers will fail.
- **Device posture checks** may fail on NixOS if the endpoint requires them.
- **AWS removes old downloads.** Once 6.2.0 is unsupported, its `.deb` URL may
  stop working, and the package will only build if the source is still in your
  Nix store.
- **Upgrading the package** restarts the daemon (dropping active connections).
  Restart any open GUI afterwards.
- systemd leaves an empty `/sbin/ip` file on the host (the mount point for the
  bind mount).
- AWS's bundled `libssl`/`libcrypto` are used, not nixpkgs' OpenSSL.
- x86_64-linux only; the package is unfree.

## Updating

1. Get the new version and its sha256 from the AWS release notes.
2. Bump `version` in `package.nix`.
3. Convert the hash with `nix hash convert --hash-algo sha256 --to sri <hex>` and
   put it in `hash`.
4. Rebuild and run the VM test.
