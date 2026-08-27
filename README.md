# grootshell

A [Quickshell](https://quickshell.outfoxxed.me/) desktop shell for `groot`, a
headless Hyprland host driven entirely over Moonlight.

Pure QML on `pkgs.quickshell` — no C++ plugin, so it builds from the binary cache
in minutes rather than compiling Qt from source.

## Layout

```
shell.qml            entry point: windows, IPC surface, input mask
config/              Config singleton, design tokens, colour scheme
services/            system state — audio, network, metrics, players, wallpapers
components/          shared widgets
modules/
  border/            the frame everything else insets into
  bar/               top bar
  island/            centre dropdown: dashboard | media | performance
  launcher/          slides up from the bottom
  notifications/     docked into the border
  osd/               volume and brightness, right edge
  sidebar/           left panel: tools
  wallpaper/         switcher
  network/           wifi popout
  clipboard/         cliphist history
  switcher/          desktop/window switcher
  background/        wallpaper surface
```

## Developing

Quickshell hot-reloads QML on save. The NixOS module reads
`GROOTSHELL_CONFIG_PATH`, so pointing it at a writable checkout means edits apply
live instead of needing a rebuild:

```nix
# hosts/groot/settings.nix
grootshell.devPath = "/home/bprice/dev/quickshell-dots";
```

Then edit, save, watch it reload over the stream. Set `devPath = null` to run the
pinned flake input from the store instead.

Run it by hand against a checkout:

```sh
GROOTSHELL_CONFIG_PATH=$PWD nix run .#grootshell
```

IPC, which is how the Hyprland keybinds drive it:

```sh
grootshell-ipc call launcher toggle
grootshell-ipc call island show media
grootshell-ipc call gameMode set true
```

## Licence

GPL-3.0-only. See [NOTICE.md](NOTICE.md) for what this owes to whom.
