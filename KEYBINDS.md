# Keybinds and IPC

grootshell does not bind any keys. It listens, and your compositor does the
binding.

That is deliberate. Hyprland is configured at least four ways — `hyprland.conf`,
Home Manager, [hyprland-lua](https://github.com/luckasRanarison/hyprland-lua),
and hand-rolled generators — and a shell that wrote binds for one of them would
be wrong for everyone using the rest. So every panel is reachable over IPC, and
you spend ten minutes wiring the ones you want to keys you like.

- [How the shell is reached](#how-the-shell-is-reached)
- [Every IPC call](#every-ipc-call)
- [Recommended binds](#recommended-binds)
- [The cheatsheet](#the-cheatsheet)
- [Non-Hyprland compositors](#non-hyprland-compositors)
- [When a bind does nothing](#when-a-bind-does-nothing)

## How the shell is reached

Quickshell ships an `ipc` subcommand. It finds a running shell by the config
path it was launched with, then calls a function on it:

```bash
qs -p ~/.config/quickshell/grootshell ipc call island toggle
```

That `-p` is the fiddly part, and it is the source of nearly every "my keybind
does nothing" report. **The path you pass must be the same path the shell was
started with.** Not equivalent, not a symlink to it — the same string, after
Quickshell canonicalises it. A shell started from a dev checkout will not answer
to the path of its packaged copy.

So the repo ships a wrapper, `grootshell-ipc`, which reads
`$GROOTSHELL_CONFIG_PATH` and passes it for you:

```bash
grootshell-ipc call island toggle
```

Set that variable once, session-wide, and every bind stops caring where the
shell is installed:

```bash
# ~/.profile, or your compositor's environment
export GROOTSHELL_CONFIG_PATH=$HOME/.config/quickshell/grootshell
```

The NixOS module sets it for you (`environment.sessionVariables`), which is why
none of the binds below mention a path.

**Use the wrapper in binds, not `qs` directly.** Nothing enforces this; it is
just that the day you move the checkout, one file changes instead of twenty.

### Checking it works before you bind anything

```bash
grootshell-ipc call island toggle     # the dashboard should appear
grootshell-ipc call island toggle     # and go away
```

If that works from a terminal and the same line does nothing from a keybind, the
problem is the environment, not the shell — see
[When a bind does nothing](#when-a-bind-does-nothing).

`grootshell-ipc show` lists the live targets, which is the authoritative version
of the table below.

## Every IPC call

Fourteen targets. Anything a panel does can be done from a script, which is the
point — the binds are just the most common caller.

### Panels

Every panel's `toggle` opens it if closed and closes it if open. That is what you
want on a key: one bind, no state to track.

| Call | Does |
| --- | --- |
| `launcher toggle` | Application launcher |
| `launcher open` / `launcher close` | Unconditional, for scripts that need a known state |
| `island toggle` | The centre panel, on whichever tab was last open |
| `island show <tab>` | Opens straight to a tab: `dashboard`, `media`, `performance`, `wallpaper`, `weather` |
| `notifications toggle` | Notification centre |
| `clipboard toggle` | Clipboard history (needs `cliphist`) |
| `network toggle` | Wi-Fi panel — join, forget, radio on/off |
| `keybinds toggle` | The cheatsheet |
| `settings toggle` | Settings |
| `translate toggle` | Translation panel |
| `switcher toggle` | Window switcher |

### Desktops

| Call | Does |
| --- | --- |
| `desktops toggle` | The desktop switcher, with live previews |
| `desktops next` | Opens it if closed **and** advances the selection |
| `desktops previous` | Same, backwards |

`next` is what you bind to SUPER+Tab. It does both jobs, so holding SUPER and
tapping Tab walks along the desktops the way alt-tab walks along windows —
without needing a second bind for "open it first".

Advancing is an IPC call rather than a key handler inside the panel for a reason
worth knowing if you build on this: Hyprland dispatches its own binds *before*
forwarding keys to clients. SUPER+Tab fires even while the panel holds exclusive
keyboard focus, so a Tab handler in the panel would move the selection twice per
press.

### Notifications

| Call | Does |
| --- | --- |
| `notifications clear` | Dismiss everything |
| `notifications dnd <true\|false>` | Do not disturb |

`dnd` takes a string, since IPC arguments are always strings. `"true"` and `"1"`
both count as on; anything else is off.

### Wallpaper and theme

| Call | Does |
| --- | --- |
| `wallpaper toggle` | The picker (the island's wallpaper tab) |
| `wallpaper next` | Next wallpaper in the directory, no UI |
| `wallpaper set <path>` | A specific file — absolute path |
| `theme regenerate` | Re-run matugen against the current wallpaper |

`wallpaper next` on a timer is a slideshow:

```bash
# a wallpaper every half hour. Both variables are needed: cron has neither, and
# without WAYLAND_DISPLAY the call cannot find the shell at all — see below.
*/30 * * * * GROOTSHELL_CONFIG_PATH=$HOME/.config/quickshell/grootshell WAYLAND_DISPLAY=wayland-1 grootshell-ipc call wallpaper next
```

`theme regenerate` is the one to call after editing anything under
`templates/` — it re-derives the palette and rewrites GTK, Qt and terminal
colours without touching the wallpaper.

### Screenshots

| Call | Does |
| --- | --- |
| `screenshot region` | Select a region (needs `slurp`, `grim`, `swappy`) |
| `screenshot screen` | The whole output |

Both close every open panel first, so the shell does not photograph itself.

### Game mode

| Call | Does |
| --- | --- |
| `gameMode toggle` | Strip effects and hide the desktop |
| `gameMode set <true\|false>` | The same, to a known state |
| `gameMode isEnabled` | Prints `true` or `false` — for scripts that need to branch |

These only set the shell's own indicator and panel behaviour. It does not
touch your compositor's animations — that is your script's job, and keeping it
that way means mode switching still works when the shell is not running.

## Recommended binds

These are the defaults this shell was built around, in `hyprland.conf` syntax.
They assume `GROOTSHELL_CONFIG_PATH` is exported.

Nothing here is required. The shell has no opinion about which key opens what;
this is a starting point that avoids the obvious collisions.

```bash
# ── Shell ────────────────────────────────────────────────────────────────
bind = SUPER, slash,      exec, grootshell-ipc call keybinds toggle
bind = SUPER, space,      exec, grootshell-ipc call launcher toggle
bind = SUPER, S,          exec, grootshell-ipc call island toggle
bind = SUPER, Tab,        exec, grootshell-ipc call desktops next
bind = SUPER, N,          exec, grootshell-ipc call notifications toggle
bind = SUPER SHIFT, V,    exec, grootshell-ipc call clipboard toggle
bind = SUPER, P,          exec, grootshell-ipc call wallpaper toggle
bind = SUPER, T,          exec, grootshell-ipc call translate toggle
bind = SUPER, comma,      exec, grootshell-ipc call settings toggle
bind =      , Print,      exec, grootshell-ipc call screenshot region
bind = SUPER, Print,      exec, grootshell-ipc call screenshot screen

# Optional: straight to a tab, skipping the one you left open
bind = SUPER, M,          exec, grootshell-ipc call island show media
bind = SUPER SHIFT, P,    exec, grootshell-ipc call island show performance
```

SUPER+slash for the cheatsheet is the one worth keeping wherever you put
everything else — it is how you find the rest again.

### The compositor half

Not the shell's business, but the shell's panels are designed around these
existing, and the cheatsheet looks thin without them:

```bash
# ── Essentials ───────────────────────────────────────────────────────────
bind = SUPER, Return,     exec, $terminal
bind = SUPER, W,          killactive
bind = SUPER SHIFT, Tab,  cyclenext
bind = SUPER SHIFT, D,    exec, $fallback_launcher   # works without the shell

# ── Windows ──────────────────────────────────────────────────────────────
bind = SUPER, F,          fullscreen, 0
bind = SUPER, V,          togglefloating
bind = SUPER, C,          centerwindow
bind = SUPER, H,          movefocus, l
bind = SUPER, J,          movefocus, d
bind = SUPER, K,          movefocus, u
bind = SUPER, L,          movefocus, r
bind = SUPER SHIFT, H,    movewindow, l
bind = SUPER SHIFT, J,    movewindow, d
bind = SUPER SHIFT, K,    movewindow, u
bind = SUPER SHIFT, L,    movewindow, r

# ── Workspaces ───────────────────────────────────────────────────────────
bind = SUPER, 1, workspace, 1          # ... through 9
bind = SUPER SHIFT, 1, movetoworkspace, 1

# ── Audio (the shell draws the OSD; wpctl does the work) ─────────────────
bindel = , XF86AudioRaiseVolume, exec, wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+
bindel = , XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
bindl  = , XF86AudioMute,        exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
```

Keep a launcher bind that does **not** go through the shell (SUPER+SHIFT+D
above). When you are debugging the shell, it is the difference between a broken
session and an inconvenient one.

## The cheatsheet

SUPER+slash opens a searchable list of your binds. The shell cannot read your
compositor config, so you tell it what you bound:

```json
[
  { "keys": ["SUPER + space"], "description": "Application launcher", "category": "Shell" },
  { "keys": ["SUPER + Return"], "description": "Terminal", "category": "Essentials" }
]
```

Save that as `~/.config/grootshell/keybinds.json`. Categories are free text and
become the section headings, in first-seen order. `keys` is a list so a bind with
two ways in shows both.

This is a second copy of information you already wrote, and it will drift. The
fix is to generate both from one source. On NixOS that is what
`programs.grootshell.keybinds` does — the same list produces the compositor binds
and `/etc/grootshell/keybinds.json`, so they cannot disagree. Anywhere else, a
short script over your `hyprland.conf` gets you the same guarantee:

```bash
# every `bind = ...` line with a trailing `# description` comment
grep -oP '^bind[a-z]* = \K[^,]+,[^,]+(?=.*#\s*)(?:.*#\s*)(.*)' ~/.config/hypr/hyprland.conf \
  | jq -Rn '[inputs | split("#") | {keys: [.[0] | ltrimstr(" ") | rtrimstr(" ")], description: .[1], category: "Hyprland"}]' \
  > ~/.config/grootshell/keybinds.json
```

The shell watches that file, so it updates without a restart.

## Non-Hyprland compositors

The IPC is compositor-agnostic — it is a Unix socket, and anything that can run
a command can drive it. Sway, river and Niri all bind commands the same way:

```bash
# sway
bindsym $mod+space exec grootshell-ipc call launcher toggle
```

What is *not* portable is the parts of the shell that ask Hyprland questions
directly: the workspace strip, the window-title pill, the desktop switcher's
previews, and the frame's auto-sizing (which reads Hyprland's gaps so the shell's
border lines up with your window borders). Those go quiet elsewhere rather than
breaking — you get a shell with a blank workspace area. The bar, launcher,
notifications, media, clipboard, wifi, weather, settings and theming all work on
any wlroots compositor.

## When a bind does nothing

Almost always the environment, and almost always one of four things.

**1. The shell cannot be found.** Run the same command in a terminal. If it
works there and not from the bind, the bind has a different
`GROOTSHELL_CONFIG_PATH` — or none. Compositor binds inherit the *compositor's*
environment, which is not necessarily your shell's. Check with:

```bash
grootshell-ipc call island toggle   # in a terminal: works?
hyprctl dispatch exec 'sh -c "env > /tmp/bindenv"'   # then read /tmp/bindenv
```

**2. `WAYLAND_DISPLAY` is not set.** Only bites non-keybind callers — cron jobs,
systemd units, an ssh session — because a compositor bind always has it. But it
fails in a thoroughly misleading way: `qs list --all` shows the instance running
at exactly the path you passed, and `ipc` in the same breath says *"No running
instances"* for that path. IPC discovery filters by display connection, and a
caller with no `WAYLAND_DISPLAY` matches nothing.

```bash
WAYLAND_DISPLAY=wayland-1 grootshell-ipc call island toggle
```

**3. The wrapper is not on PATH.** Same cause, different symptom. A bind runs
with the compositor's PATH; if you installed grootshell into a profile that is
sourced by your login shell but not by the compositor, `grootshell-ipc` is not
found and the bind fails silently. Use an absolute path in the bind to confirm.

**4. The target or function name is wrong.** IPC calls to a name that does not
exist fail quietly by design. `grootshell-ipc show` lists what is actually
registered; compare it against your bind, character for character. `island show
media` is right, `island tab media` is not.

If the call reaches the shell and still nothing happens, that is a bug rather
than configuration — the shell logs to its journal:

```bash
journalctl --user -u grootshell -f      # systemd
qs -p <path> 2>&1 | tee /tmp/shell.log  # run in a terminal
```
