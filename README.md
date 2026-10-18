# oriedita-flake

[![Build](https://github.com/make-42/oriedita-flake/actions/workflows/build.yml/badge.svg)](https://github.com/make-42/oriedita-flake/actions/workflows/build.yml)
[![Update](https://github.com/make-42/oriedita-flake/actions/workflows/update.yml/badge.svg)](https://github.com/make-42/oriedita-flake/actions/workflows/update.yml)

A Nix flake for [Oriedita](https://github.com/oriedita/oriedita), an origami crease pattern editor and folding simulator (a fork of Orihime). It builds Oriedita from source with Maven and wraps it with the right JDK and native libraries, so it works out of the box on Linux.

This repo is an unofficial packaging and is not affiliated with the Oriedita project. A GitHub Action checks for new upstream releases daily and updates the package automatically.

## Usage

Run without installing:

```sh
nix run github:make-42/oriedita-flake
```

Open a file directly:

```sh
nix run github:make-42/oriedita-flake -- path/to/pattern.ori
```

Install into your profile:

```sh
nix profile install github:make-42/oriedita-flake
```

### As a flake input (NixOS / home-manager)

```nix
{
  inputs.oriedita.url = "github:make-42/oriedita-flake";

  outputs = { nixpkgs, oriedita, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      modules = [
        ({ pkgs, ... }: {
          environment.systemPackages = [
            oriedita.packages.${pkgs.system}.default
          ];
        })
      ];
    };
  };
}
```

Pass `inputs.nixpkgs.follows = "nixpkgs";` on the input if you want it to share your nixpkgs.

### Development shell

```sh
nix develop
```

Provides JDK 17 and Maven, with the native libraries and GSettings schemas set up for running Swing apps.

## How it works

- Built with `maven.buildMavenPackage` using JDK 17 (Oriedita requires Java 17 or newer).
- The wrapper sets `LD_LIBRARY_PATH` for the X11, GL, fontconfig, and GTK libraries that AWT/Swing loads at runtime.
- `XDG_DATA_DIRS` includes the GTK and `gsettings-desktop-schemas` schema directories. Without them, the native file chooser crashes the JVM with a missing `org.gtk.Settings.FileChooser` schema error.
- Tests are skipped (`-DskipTests`). Don't use `-Dmaven.test.skip=true`: the `oriedita` module depends on `oriedita-common`'s test jar, and that flag stops it from being built.

## Automatic updates

Version and hashes live in [`version.json`](./version.json):

```json
{
  "version": "...",
  "srcHash": "...",
  "mvnHash": "..."
}
```

The [update workflow](./.github/workflows/update.yml) runs daily and on manual dispatch. It:

1. Queries the latest upstream release.
2. Runs [`scripts/update.sh`](./scripts/update.sh), which prefetches the source, computes the Maven dependency hash, and does a full verification build.
3. Runs `nix flake update` to refresh `flake.lock`.
4. Commits and pushes to `main` only if everything built successfully.

To update manually:

```sh
./scripts/update.sh          # bump to the latest release if newer
FORCE=1 ./scripts/update.sh  # recompute hashes even if the version is unchanged
```

## Platform support

Linux only (`x86_64-linux` and `aarch64-linux`). The runtime library setup is Linux-specific. macOS would need changes to the wrapper and `meta.platforms`.

## Configuration and data

Oriedita stores its settings in `~/.oriedita`. To reset the app, delete that directory.

## Troubleshooting

**The window is larger than my screen.** Disable Java's UI scaling:

```sh
nix run github:make-42/oriedita-flake -- -Dsun.java2d.uiScale=1
```

If your setup ignores that, run it as `JAVA_TOOL_OPTIONS="-Dsun.java2d.uiScale=1" nix run github:make-42/oriedita-flake`.

**Blank or odd window on a tiling WM.** The wrapper already sets `_JAVA_AWT_WM_NONREPARENTING=1`. Override it in your environment if it causes problems on your setup.

**File picker looks unstyled or has missing icons.** Add `pkgs.adwaita-icon-theme` to the `XDG_DATA_DIRS` prefixes in `flake.nix`.

**Build fails after an automatic bump.** The update workflow only pushes builds that succeed, so this usually means a local cache problem. Try `nix build .#oriedita -L --rebuild`. If upstream changed its build layout, open an issue.

## License

The Nix packaging in this repo is released under the [MIT License](./LICENSE).

Oriedita itself is licensed by its authors. See the [upstream repository](https://github.com/oriedita/oriedita) for its license.
