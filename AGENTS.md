# Grok Bot Nix flake

Binary repack of the official Grok Bot `.deb` (Electron, unfree). Nothing is
compiled. `flake.nix` is the consumer surface; `package.nix` is the derivation;
`update.sh` bumps pins.

## Source

Do not vendor the `.deb` (gitignored under `tmp/`). Pin `fetchurl` to:

`https://downloads.cursor.com/grokbot/stable/<commitSha>/linux/{x64,arm64}/grok-bot_<ver>_{amd64,arm64}.deb`

JSON feed (app name is still `sand`):

- `https://api2.cursor.sh/updates/api/download/stable/linux-x64/sand`
- `https://api2.cursor.sh/updates/api/download/stable/linux-arm64/sand`

The browser redirect `api2.cursor.sh/updates/download/stable/linux-x64/grok-bot-…`
always points at latest — never use it as `src`.

`version`, `commitSha`, and `hashes` in `package.nix` are rewritten by
`./update.sh`. Keep those assignment lines in the form the script greps.

A stale pin does **not** fail the build. The URL is versioned by `commitSha`, so
Nix keeps fetching that exact `.deb`. You only get a hash mismatch if the file
at that URL changes, or a 404 if Cursor deletes it. `.github/workflows/update.yml`
runs `./update.sh` every six hours and pushes a new pin when the feed moves.

## Layout

Install prefix: `$out/share/grok-bot` (no spaces; upstream uses `/opt/Grok Bot`).
Wrapper: `$out/bin/grok-bot`. Compatibility symlink: `$out/bin/sand`.

## Wrap pitfalls

- `makeShellWrapper`, not `makeWrapper`. `wrapGAppsHook3` otherwise uses
  `makeBinaryWrapper`, which passes the literal `${NIXOS_OZONE_WL:+…}` string to
  Electron. `dontWrapGApps = true` then apply `"${gappsWrapperArgs[@]}"` by hand.
- `--no-sandbox` is required until upstream fixes sandboxed-renderer shm
  (`FATAL:platform_shared_memory_region_posix.cc`). See the `skip:` comment in
  `package.nix`.
- `CHROME_DESKTOP=grok-bot.desktop` so Electron registers `sand://` / `grokbot://`
  against the right desktop id.
- Unfree: `packages` / `apps` import nixpkgs with `allowUnfree` so `nix run`
  works. The overlay does not — consumers must allow `grok-bot`.
- Do not swap in `pkgs.electron`; bundled `.node` modules are ABI-tied to
  upstream's Electron.
