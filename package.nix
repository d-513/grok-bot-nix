{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  makeShellWrapper,
  wrapGAppsHook3,
  addDriverRunpath,

  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  atk,
  cairo,
  cups,
  dbus,
  expat,
  fontconfig,
  freetype,
  gdk-pixbuf,
  glib,
  gtk3,
  libdrm,
  libgbm,
  libGL,
  libglvnd,
  libnotify,
  libpulseaudio,
  libsecret,
  libuuid,
  libx11,
  libxcb,
  libxcomposite,
  libxcursor,
  libxdamage,
  libxext,
  libxfixes,
  libxi,
  libxkbcommon,
  libxrandr,
  libxrender,
  libxscrnsaver,
  libxshmfence,
  libxtst,
  nspr,
  nss,
  pango,
  systemd,
  vulkan-loader,
  wayland,
  xdg-utils,
}:

let
  inherit (stdenv.hostPlatform) system;

  # Rewritten by ./update.sh from the stable JSON feed.
  version = "0.30.0";
  commitSha = "2385d097738b3719cc5ecd9281a107aa106215f1";
  hashes = {
    x86_64-linux = "sha256-+4iLIgTIpRxxqfX5opE6wQVh8+9pOcEkXsrk6DfUraI=";
    aarch64-linux = "sha256-fEyB1XYYGlezS4EiWLJiBiZxfOyE8QBQOnNj83qo4/4=";
  };

  archTag = {
    x86_64-linux = "x64";
    aarch64-linux = "arm64";
  };
  debArch = {
    x86_64-linux = "amd64";
    aarch64-linux = "arm64";
  };

  runtimeLibs = [
    libglvnd
    libGL
    libgbm
    libdrm
    vulkan-loader
    wayland
    libxkbcommon
    libpulseaudio
    libsecret
    libnotify
    (lib.getLib systemd)
  ];
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
    wrapGAppsHook3
  ];

  buildInputs = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    dbus
    expat
    fontconfig
    freetype
    gdk-pixbuf
    glib
    gtk3
    libuuid
    nspr
    nss
    pango
    stdenv.cc.cc.lib
    libx11
    libxcb
    libxcomposite
    libxcursor
    libxdamage
    libxext
    libxfixes
    libxi
    libxrandr
    libxrender
    libxscrnsaver
    libxshmfence
    libxtst
  ]
  ++ runtimeLibs;

  # Chromium dlopen()s these; autoPatchelfHook only sees DT_NEEDED.
  runtimeDependencies = runtimeLibs;

  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;
  dontWrapGApps = true;

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb -x "$src" .
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/share/grok-bot"
    cp -r "opt/Grok Bot/." "$out/share/grok-bot/"

    rm -f "$out/share/grok-bot/chrome-sandbox"
    rm -f "$out/share/grok-bot/resources/apparmor-profile"

    cp -r usr/share/icons "$out/share/"
    install -Dm644 usr/share/applications/grok-bot.desktop \
      "$out/share/applications/grok-bot.desktop"
    substituteInPlace "$out/share/applications/grok-bot.desktop" \
      --replace-fail '"/opt/Grok Bot/grok-bot"' "$out/bin/grok-bot"

    runHook postInstall
  '';

  preFixup = ''
    # makeShellWrapper, not makeWrapper: wrapGAppsHook3 pulls in
    # makeBinaryWrapper, whose wrappers pass argv through literally. The
    # conditional ozone flags below need real shell parameter expansion.
    makeShellWrapper "$out/share/grok-bot/grok-bot" "$out/bin/grok-bot" \
      "''${gappsWrapperArgs[@]}" \
      --suffix PATH : ${lib.makeBinPath [ xdg-utils ]} \
      --prefix LD_LIBRARY_PATH : ${addDriverRunpath.driverLink}/lib \
      --set-default CHROME_DESKTOP grok-bot.desktop \
      --add-flags "--no-sandbox" \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations}}"

    ln -s grok-bot "$out/bin/sand"
  '';

  # skip: --no-sandbox — upstream Electron crash-loops sandboxed webview
  # renderers (FATAL:platform_shared_memory_region_posix.cc). Drop when
  # their sandboxed-renderer shm path is fixed (electron#30758 class).

  passthru = {
    inherit commitSha hashes;
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
