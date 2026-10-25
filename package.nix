{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  runtimeShell,
  coreutils,
  systemd,
  gsettings-desktop-schemas,
  # Electron GUI
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  cairo,
  cups,
  dbus,
  expat,
  glib,
  gtk3,
  libdrm,
  libgbm,
  libGL,
  libnotify,
  libxkbcommon,
  nspr,
  nss,
  pango,
  systemdLibs,
  libx11,
  libxcb,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxrandr,
  libxscrnsaver,
  libxtst,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "awsvpnclient";
  version = "6.2.0";

  src = fetchurl {
    url = "https://d20adtppz83p9s.cloudfront.net/GTK/${finalAttrs.version}/awsvpnclient_amd64.deb";
    hash = "sha256-J3mor3SK3cLm9QYcjqieyffLAKb0Va86PaF9z4tAq7c=";
  };

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
  ];

  buildInputs = [
    stdenv.cc.cc.lib
    alsa-lib
    at-spi2-atk
    at-spi2-core
    cairo
    cups
    dbus
    expat
    glib
    gtk3
    libdrm
    libgbm
    libnotify
    libxkbcommon
    nspr
    nss
    pango
    libx11
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxrandr
    libxscrnsaver
    libxtst
    libxcb
  ];

  # Electron dlopen()s these at runtime.
  runtimeDependencies = [
    libGL
    systemdLibs
  ];

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb -x $src .
    runHook postUnpack
  '';

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/opt $out/bin $out/share/applications
    cp -a opt/awsvpnclient $out/opt/awsvpnclient

    chmod 755 $out/opt/awsvpnclient/{aws-client-vpn-daemon,aws-vpn-client,aws-vpn-client-agent}
    chmod 755 $out/opt/awsvpnclient/dns/configure-dns

    substituteInPlace $out/opt/awsvpnclient/dns/configure-dns \
      --replace-fail /usr/bin/resolvectl ${systemd}/bin/resolvectl \
      --replace-fail /usr/bin/date ${coreutils}/bin/date \
      --replace-fail /usr/bin/mkdir ${coreutils}/bin/mkdir \
      --replace-fail /usr/bin/rm ${coreutils}/bin/rm

    # The daemon only accepts IPC from binaries whose real path is under
    # /opt/awsvpnclient, so entry points must exec through that path (the
    # NixOS module bind-mounts $out/opt/awsvpnclient there), never the store.
    cat > $out/bin/aws-vpn-client <<EOF
    #!${runtimeShell}
    exec /opt/awsvpnclient/aws-vpn-client "\$@"
    EOF
    cat > $out/bin/awsvpnclient-gui <<EOF
    #!${runtimeShell}
    export XDG_DATA_DIRS="${glib.getSchemaDataDirPath gtk3}:${glib.getSchemaDataDirPath gsettings-desktop-schemas}\''${XDG_DATA_DIRS:+:\$XDG_DATA_DIRS}"
    exec "/opt/awsvpnclient/AWS VPN Client" --no-sandbox --ozone-platform=x11 --disable-gpu "\$@"
    EOF
    chmod 755 $out/bin/*

    substitute usr/share/applications/aws-vpn-client.desktop \
      $out/share/applications/aws-vpn-client.desktop \
      --replace-fail "/opt/awsvpnclient/launch-vpn-client.sh" "$out/bin/awsvpnclient-gui" \
      --replace-fail "/opt/awsvpnclient/resources/app.png" "$out/opt/awsvpnclient/resources/app.png"

    runHook postInstall
  '';

  meta = {
    description = "AWS Client VPN desktop client";
    homepage = "https://docs.aws.amazon.com/vpn/latest/clientvpn-user/client-vpn-connect-linux.html";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "aws-vpn-client";
  };
})
