# Grok Bot for Nix

[Grok Bot](https://x.ai/bot) on Linux, as a Nix flake. Proprietary; not
affiliated with xAI or Cursor.

```sh
nix run github:d-513/grok-bot-nix
```

`nix run` is a one-shot. Login redirects (`sand://` / `grokbot://`) need a real
install so the desktop file is on `XDG_DATA_DIRS`.

## Install

### NixOS

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    grok-bot-nix = {
      url = "github:d-513/grok-bot-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
```

```nix
{ inputs, pkgs, ... }:
{
  environment.systemPackages = [
    inputs.grok-bot-nix.packages.${pkgs.system}.default
  ];
}
```

### Home Manager

Same flake input, then:

```nix
{ inputs, pkgs, ... }:
{
  home.packages = [
    inputs.grok-bot-nix.packages.${pkgs.system}.default
  ];
}
```

### Overlay (`pkgs.grok-bot`)

```nix
{
  nixpkgs.overlays = [ inputs.grok-bot-nix.overlays.default ];
  nixpkgs.config.allowUnfreePredicate =
    pkg: builtins.elem (pkgs.lib.getName pkg) [ "grok-bot" ];
  environment.systemPackages = [ pkgs.grok-bot ];
}
```

The overlay respects your unfree config. `nix run` / `packages` already allow
unfree for this package.

### Profile

```sh
nix profile install github:d-513/grok-bot-nix
```

## Wayland

```nix
environment.sessionVariables.NIXOS_OZONE_WL = "1";
```

Without that, it runs under XWayland/X11.

## Updates

The in-app updater does not work under Nix. This repo pins a `.deb` URL and
hash, so **an old pin still builds** — you just stay on that version until the
pin moves.

A GitHub Action here checks upstream every six hours and commits a new pin
when a release appears. On your machine, pick it up with:

```sh
nix flake update grok-bot-nix
```

then rebuild. `nix flake update` without an attribute updates nixpkgs too.
