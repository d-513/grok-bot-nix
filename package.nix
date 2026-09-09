{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  makeShellWrapper,
  electron_42,
  addDriverRunpath,
  xdg-utils,
}:

let
  inherit (stdenv.hostPlatform) system;

  # Rewritten by ./update.sh from the stable JSON feed.
  version = "0.47.0";
  commitSha = "c1e7d7a46549956d25f53e9c0b9f59666e03aa3a";
  hashes = {
    x86_64-linux = "sha256-EcoPUaU1uXr1GjUq35wPns0uGwQwpprpRRtoinoGWAg=";
    aarch64-linux = "sha256-g2+NGdOCbGVzwxrEXHqbeXq8czga4NKx56ja5UEOfkY=";
  };

  archTag = {
    x86_64-linux = "x64";
    aarch64-linux = "arm64";
  };
  debArch = {
    x86_64-linux = "amd64";
    aarch64-linux = "arm64";
  };
in
stdenv.mkDerivation {
  pname = "grok-bot";
  inherit version;

  src = fetchurl {
    url = "https://downloads.cursor.com/grokbot/stable/${commitSha}/linux/${archTag.${system}}/grok-bot_${version}_${debArch.${system}}.deb";
    hash = hashes.${system} or (throw "Unsupported system: ${system}");
  };

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    makeShellWrapper
  ];

  buildInputs = [
    stdenv.cc.cc.lib
  ];

  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb -x "$src" .
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/share/grok-bot"
    cp -a "opt/Grok Bot/resources/app.asar" "$out/share/grok-bot/"
    cp -a "opt/Grok Bot/resources/app.asar.unpacked" "$out/share/grok-bot/"

    cp -r usr/share/icons "$out/share/"
    install -Dm644 usr/share/applications/grok-bot.desktop \
      "$out/share/applications/grok-bot.desktop"
    # Upstream Exec= has been both an absolute /opt path and a PATH lookup.
    if ! grep -q '^Exec=' "$out/share/applications/grok-bot.desktop"; then
      echo "error: grok-bot.desktop has no Exec= line" >&2
      cat "$out/share/applications/grok-bot.desktop" >&2
      exit 1
    fi
    sed -i "s|^Exec=.*|Exec=$out/bin/grok-bot %U|" \
      "$out/share/applications/grok-bot.desktop"

    runHook postInstall
  '';

  preFixup = ''
    makeShellWrapper ${lib.getExe electron_42} "$out/bin/grok-bot" \
      --add-flags "$out/share/grok-bot/app.asar" \
      --add-flags --class=grok-bot \
      --add-flags --name=grok-bot \
      --suffix PATH : ${lib.makeBinPath [ xdg-utils ]} \
      --prefix LD_LIBRARY_PATH : ${addDriverRunpath.driverLink}/lib \
      --prefix XDG_DATA_DIRS : "$out/share" \
      --set-default CHROME_DESKTOP grok-bot.desktop \
      --set-default ELECTRON_FORCE_IS_PACKAGED 1 \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations}}"

    ln -s grok-bot "$out/bin/sand"
  '';

  passthru = {
    inherit commitSha hashes;
    electron = electron_42;
    updateScript = ./update.sh;
  };

  meta = {
    description = "Grok Bot desktop agent";
    homepage = "https://x.ai/bot";
    downloadPage = "https://x.ai/bot";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    mainProgram = "grok-bot";
  };
}
