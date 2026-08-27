# Notice

grootshell is licensed GPL-3.0-only. It is an original work, but it owes ideas —
and in places structure — to other Quickshell configurations.

## Attribution

**[caelestia-dots/shell](https://github.com/caelestia-dots/shell)** — GPL-3.0-only.
The overall composition: a shell-drawn border that everything else insets into,
panels that appear to grow out of that border rather than float above it, the
centre island that tabs between dashboard, media and performance, and
notifications docked into the frame. grootshell builds these in pure QML;
caelestia's versions lean on a large C++/Qt plugin that grootshell does not have
and does not want.

**[end-4/dots-hyprland](https://github.com/end-4/dots-hyprland)** — GPL-3.0-only.
The left sidebar as a home for tools rather than status, and the shape of its
pluggable API-strategy layer, which is what makes adding another provider a new
file instead of a refactor.

**[LUCKYS1NGHH/ChillPill-Shell](https://github.com/LUCKYS1NGHH/ChillPill-Shell)** —
GPL-3.0-only. The cliphist integration.

## Runtime

Built on **[Quickshell](https://quickshell.outfoxxed.me/)** (LGPL-3.0), which
does the actual heavy lifting.

Theming is designed to interoperate with **[Stylix](https://github.com/danth/stylix)**
(MIT): `config/Theme.qml` reads a generated JSON with compiled-in fallbacks, so
one Nix definition can drive GTK, Qt and this shell alike while the shell still
renders correctly standalone.
