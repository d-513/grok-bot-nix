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
`./update.sh`. Keep the `hashes = { ... };` block distinct from `archTag` /
`debArch` — the updater greps those system keys only inside `hashes`.

A stale pin does **not** fail the build. The URL is versioned by `commitSha`, so
Nix keeps fetching that exact `.deb`. You only get a hash mismatch if the file
at that URL changes, or a 404 if Cursor deletes it. `.github/workflows/update.yml`
runs `./update.sh` every six hours and pushes a new pin when the feed moves.

## Layout

Install prefix: `$out/share/grok-bot` (asar + unpacked natives only).
Wrapper: nixpkgs `electron_42` → `$out/bin/grok-bot`. Compatibility symlink: `$out/bin/sand`.
Upstream ships Electron 42.1.0; we run nixpkgs `electron_42` instead of the bundled Chromium.

## Wrap pitfalls

- `makeShellWrapper`, not `makeWrapper`, so `${NIXOS_OZONE_WL:+…}` expands in a
  shell. nixpkgs `electron_42` already carries GApps; do not wrapGApps again.
- `CHROME_DESKTOP=grok-bot.desktop` so Electron registers `sand://` / `grokbot://`
  against the right desktop id.
- `--class=grok-bot --name=grok-bot` so KDE/Wayland `app_id` matches
  `grok-bot.desktop`. Without that, wrapping nixpkgs `electron` shows the
  generic Wayland icon. Plasma still only sees the icon if the package is on
  the session `XDG_DATA_DIRS` (NixOS / Home Manager / `nix profile`), not
  `nix run` / `./result`.
- `ELECTRON_FORCE_IS_PACKAGED=1` because we launch via `electron app.asar`.
- Unfree: `packages` / `apps` import nixpkgs with `allowUnfree` so `nix run`
  works. The overlay does not — consumers must allow `grok-bot`.
- Native `.node` modules are ABI-tied to Electron 42. Stay on `electron_42`.
