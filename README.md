# grootshell

A [Quickshell](https://quickshell.outfoxxed.me/) desktop shell for Hyprland,
written entirely in QML.

It was built for `groot` — a headless NixOS box with no monitor, driven over
[Moonlight](https://moonlight-stream.org/) — and that constraint shaped most of
it. Every animated frame is a frame encoded and pushed over a network, so motion
is short, polling is demand-driven, and anything that redraws without being
looked at was removed. It works just as well on a machine you sit in front of;
you simply get a shell that is stingier with the GPU than it needs to be.

**No C++ plugin.** Everything here is QML against stock `quickshell`, which means
it builds from a binary cache in minutes instead of compiling a Qt plugin from
source. Configuration, system metrics, the colour scheme and the widgets are all
QML or small shell-outs to ordinary userspace tools.

![GPL-3.0](https://img.shields.io/badge/license-GPL--3.0-blue)

---

## Features

**The bar** is three floating pills over a thin frame rather than a solid band —
workspaces on the left, a clock in the centre, tray and status on the right.
Windows tile below them, so nothing is ever hidden behind a pill.

**The island.** The clock pill *is* the dashboard: clicking it expands the
capsule into a panel that rises into the top border and hangs off it. Five tabs:

- **Dashboard** — clock, month grid, agenda, and current weather at a glance
- **Media** — album art cropped to a disc inside a live audio spectrum ring
- **Performance** — CPU, GPU, memory, and both temperatures as dials
- **Wallpaper** — a grid that applies as you move through it, regenerating the
  whole colour scheme with each pick
- **Weather** — current conditions, the next twelve hours, and ten days

**Wallpaper-derived theming.** Picking a wallpaper runs it through
[matugen](https://github.com/InioX/matugen) to produce a Material 3 palette, and
the entire shell cross-fades to it — image and colours together, on the same
frame. Light or dark is chosen from the image's own brightness, with a manual
override. The same palette is written out for GTK, Qt (via qt6ct) and WezTerm,
so applications follow the desktop.

Generated palettes are cached under `~/.cache/grootshell/themes`, keyed by the
image, its mtime, the mode and the templates. Wallpapers you have used before
apply in about 40ms rather than the 0.1–1.6 seconds matugen takes to read them,
which matters because the cross-fade waits for the palette. Editing an image or
a template invalidates its entry; `grootshell-ipc call theme regenerate` ignores
the cache entirely.

**Calendar and agenda.** Several iCal feeds merged into one agenda, with
colour-coded calendars, day indicators on the month grid, and one-press joining
of Zoom / Meet / Teams links found in an event.

**A desktop switcher** on `SUPER+Tab` showing every workspace drawn to scale,
with live previews of the windows on each — including workspaces you cannot
currently see.

**Notifications** that extrude from the right border, with actions, drag- and
click-to-dismiss, and a centre that holds what you missed.

**Side panels** that *reserve* screen edge rather than covering it, so tiled
windows resize around them and animate back when they close.

**Also:** an application launcher with command and calculator prefixes, a
clipboard history browser, a translation panel, a wifi popout, a volume readout
on the right edge that opens on hover, a keybind cheatsheet generated from the
compositor's actual binds, and a game mode that strips every effect for
streaming.

---

## Requirements

### Essential

| Tool | Why |
| --- | --- |
| `quickshell` 0.3.0+ | The runtime. Qt 6.7+ for `ClippingRectangle`. |
| Hyprland | Workspaces, window management and keybinds all go through it |
| **Material Symbols Rounded** | Every icon in the shell. Without it you get boxes. |

### Fonts

Bundled into a closed fontconfig by the Nix package; install them yourself
otherwise. Only the first is load-bearing.

- **Material Symbols Rounded** — all iconography. Qt substitutes silently when a
  font is missing, so its absence shows up as boxes rather than an error; the
  shell logs a warning at startup naming any of these it cannot find.
- **Rubik** — UI text
- **CaskaydiaCove Nerd Font Mono** — monospace readouts
- **Noto Sans CJK** — kanji numerals on empty workspaces (tofu without it)

### Per feature

Each of these is probed at runtime, and its feature degrades quietly rather than
erroring if it is missing.

| Tool | Feature |
| --- | --- |
| `matugen` | Wallpaper-derived colour schemes |
| `cava` | The media tab's spectrum ring |
| `cliphist` | Clipboard history |
| `nmcli` (NetworkManager) | The wifi popout |
| `grim`, `slurp`, `swappy` | Screenshots |
| `lm_sensors` | Temperatures on the performance tab |
| `python3` + `icalendar` + `recurring-ical-events` | The calendar agenda |
| `systemd` | `systemd-run`, so launched apps outlive a shell restart |
| `wl-clipboard`, `libnotify`, `procps`, `util-linux`, `gawk`, `glib` | Assorted |

No API keys anywhere. The weather comes from
[Open-Meteo](https://open-meteo.com/), which needs none.

The two helpers the shell shells out to — the theme generator and the calendar
fetcher — live in `scripts/` here. The shell prefers a packaged `grootshell-theme`
or `grootshell-calendar` on `PATH` when there is one, because the Nix wrappers
bring their own dependencies, and otherwise runs the bundled script directly. So
neither feature needs Nix; they need the tools in the table above.

---

## Installing it

### With Nix (NixOS)

The flake ships a NixOS module, so this is the whole of it:

```nix
{
  inputs.grootshell.url = "github:BenjaminPrice/grootshell";

  # in your configuration.nix / a module
  imports = [ inputs.grootshell.nixosModules.default ];

  programs.grootshell = {
    enable = true;
    user = "you";
  };
}
```

That gives you the shell as a user service with the right `PATH`, the fonts and
icon themes it draws with, the tools it shells out to, and the environment a
keybind needs to find a running instance.

Then bind some keys in your own Hyprland config — every shell action is
`grootshell-ipc call <target> <function>`:

```
bind = SUPER, space, exec, grootshell-ipc call launcher toggle
bind = SUPER, S,     exec, grootshell-ipc call island toggle
bind = SUPER, comma, exec, grootshell-ipc call settings toggle
```

Pass the same list to `programs.grootshell.keybinds` as
`[{ keys, description, category }]` and the in-shell cheatsheet on `SUPER+/`
documents exactly what you bound. Extra fields are ignored, so one list can carry
your dispatchers too.

Useful options:

| Option | What it does |
| --- | --- |
| `devPath` | Run the QML from a writable checkout. Quickshell hot-reloads on save, so editing the shell stops needing a rebuild per change. |
| `target` | The systemd user target to bind to. Use a compositor-specific one if you have it, so the shell cannot outlive the compositor. |
| `calendarUrlFile` | Where the agenda's feed list lives, when it is a secret rather than a file in your config directory. |
| `theming` | Install matugen and adw-gtk3. On by default; turn it off to keep your own colours. |
| `fonts`, `clipboardHistory` | Both on by default. |

**What the module deliberately does not do:** it does not touch your cursor
theme, GTK or Qt settings files, or dconf keys, and it does not generate
compositor keybinds. Those are opinions about a whole desktop rather than about
this shell.

### Without Nix

Nix is a convenience here, not a requirement. Point Quickshell at a checkout:

```bash
git clone https://github.com/BenjaminPrice/grootshell
qs -p grootshell
```

You are responsible for the fonts and the tools in the table above being on
`PATH`; the shell names any font it cannot find, at startup, and every optional
tool degrades quietly.

The helpers in `scripts/` are found relative to `shell.qml`, so nothing needs
installing:

```bash
scripts/generate-theme.sh ~/Pictures/Wallpapers/some.png   # colours, by hand
scripts/grootshell-ipc call launcher toggle                # for keybinds
```

Two files to know about:

- `~/.config/grootshell/keybinds.json` — the cheatsheet, if you are not using
  the NixOS module to generate it.
- `~/.config/grootshell/calendars` — one `name|url` per line, each being a
  calendar's "secret address in iCal format".

### Binding keys

The shell binds nothing itself — your compositor does, and every panel is
reachable over IPC:

```bash
grootshell-ipc call island toggle       # the dashboard
grootshell-ipc call launcher toggle
grootshell-ipc show                     # every target and function, live
```

**[KEYBINDS.md](KEYBINDS.md)** is the full version: all fifteen IPC targets,
a set of default binds to paste into `hyprland.conf`, how to keep the in-shell
cheatsheet from drifting out of sync with them, what does and does not carry
across to Sway and Niri, and the four environment problems behind essentially
every bind that silently does nothing.

To run it as a user service, the module's unit is a reasonable template: bind it
to `graphical-session.target`, put your profile on its `PATH` so launched
applications resolve, and set `KillMode=process` so a restart does not take the
applications with it.

## Configuration

Everything is optional — `~/.config/grootshell/shell.json`, watched and applied
live. See `config/Config.qml` for the full surface with defaults.

```jsonc
{
  "appearance": { "fontScale": 1.0 },   // "sofa, not desk" — scales everything
  "bar":        { "workspaces": 5, "clockFormat": "ddd d MMM  HH:mm" },
  "border":     { "thickness": 0, "rounding": 25 },  // 0 = follow the compositor
  "wallpaper":  { "directory": "~/Pictures/Wallpapers" },
  "weather":    { "location": "Osaka", "units": "metric", "days": 10 }
}
```

Keys you have not set stay **absent**, and absent means "follow the shipped
default" — so a default that improves upstream reaches you. Nothing writes this
file wholesale for that reason; see `services/Settings.qml`.

Runtime state — the current wallpaper, the light/dark override — lives separately
in `$XDG_STATE_HOME/quickshell/by-shell/grootshell/state.json`, deliberately: the
config file is read and never written, so a later change to a default is not
silently frozen by something the shell wrote.

---

## Layout

```
shell.qml            entry point: windows, IPC surface, input mask
config/              Config singleton, design tokens, colour scheme
services/            system state — audio, network, metrics, players, weather
components/          shared widgets
modules/
  background/        wallpaper surface
  border/            the frame everything else insets into
  bar/               the pill bar
  island/            the clock pill that becomes the dashboard
  launcher/          slides up from the bottom
  notifications/     toasts and the centre, docked into the border
  osd/               volume, right edge
  network/           wifi popout
  clipboard/         cliphist history
  switcher/          window and desktop switchers
  translate/         translation panel
  keybinds/          the cheatsheet
nix/                 package definition and the NixOS module
templates/           matugen templates: the shell, GTK, Qt, WezTerm
scripts/             theme generator, calendar fetcher, ipc wrapper, qml-audit
```

## Developing

```bash
nix flake check      # parses every QML file, then audits it
```

`scripts/qml-audit.py` catches mistakes that **parse cleanly and fail at load** —
which matters because Quickshell exits when its config fails, and on a headless
host that is a black screen with no console. Every rule in it is there because it
shipped: a `Behavior` on a read-only property, a file named after a built-in
type, a duplicate `id`, a type used without importing its module, a property
named with a reserved word, a delegate shadowing a required property it already
inherits, an alias reaching into a grouped property, a component redeclaring a
property `Item` already has, and a `Behavior` on a property whose name starts
with `on` — which segfaults the QML engine outright.

Run it before pushing. It is faster than finding out from a crash loop.

## Credits

GPL-3.0-only. An original work, but it owes ideas — and in places structure — to
other Quickshell configurations, all GPL-3.0-only themselves.

**[caelestia-dots/shell](https://github.com/caelestia-dots/shell)** — the overall
composition: a shell-drawn border everything else insets into, panels that grow
out of that border rather than float above it, the centre island that tabs
between dashboard, media and performance, and notifications docked into the
frame. Caelestia's versions lean on a large C++/Qt plugin; these are pure QML.

**[AvengeMedia/DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell)**
— the wallpaper picker as a dashboard tab that applies as you browse, easing the
whole palette between schemes instead of snapping, and album art cropped to a
disc inside an audio spectrum ring.

**[Axenide/Ambxst](https://github.com/Axenide/Ambxst)** — the bar as separate
floating pills over a uniformly thin border, rather than one solid band.

**[pctrade/end4-pC](https://github.com/pctrade/end4-pC)** and
**[enhaoswen/Tide-island](https://github.com/enhaoswen/Tide-island)** — the
desktop switcher: workspaces drawn to scale with live window previews, including
the ones not currently on screen.

**[end-4/dots-hyprland](https://github.com/end-4/dots-hyprland)** — a side panel
as a home for tools rather than status, which is what the translate panel is.

**[LUCKYS1NGHH/ChillPill-Shell](https://github.com/LUCKYS1NGHH/ChillPill-Shell)**
— the cliphist integration.

Built on **[Quickshell](https://quickshell.outfoxxed.me/)** (LGPL-3.0), which
does the actual heavy lifting, with colour schemes from
**[matugen](https://github.com/InioX/matugen)** and forecasts from
**[Open-Meteo](https://open-meteo.com/)**.
