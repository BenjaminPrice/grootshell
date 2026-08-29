#!/usr/bin/env bash
#
# grootshell-theme — derive the whole desktop's colours from a wallpaper.
#
#   generate-theme.sh <image> [light|dark] [force]
#
# matugen reads the image and produces a Material 3 palette; the templates beside
# this script turn that palette into the config each consumer wants:
#
#   ~/.config/grootshell/theme.json        the shell (watched, applies live)
#   ~/.config/gtk-3.0/gtk.css              GTK 3 applications
#   ~/.config/gtk-4.0/gtk.css              libadwaita applications
#   ~/.config/wezterm/colours.lua          WezTerm (watched, applies live)
#   ~/.config/qt6ct/colors/grootshell.conf Qt applications
#
# The SHELL decides when to run this — services/Theming.qml calls it whenever the
# wallpaper changes. This script decides what colours come out. That split is the
# only one that works when the input is a file a human picks at runtime.
#
# Required: matugen (>= 4.1, for --prefer).
# Optional: ImageMagick, for automatic light/dark; dconf, to tell running
#           applications. Both degrade rather than fail.
#
# Nothing here is Nix-specific. The Nix package wraps this same file.

set -euo pipefail

here="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# Templates normally sit beside the repo's scripts/ directory. GROOTSHELL_TEMPLATES
# overrides that for a packaged install, where the two may not be siblings.
templates="${GROOTSHELL_TEMPLATES:-$here/../templates}"

config="${XDG_CONFIG_HOME:-$HOME/.config}"

# The GTK theme to switch between. adw-gtk3 is the default because it is the
# thing that makes any of this visible to GTK3 applications at all — see the note
# further down — but it is a name, not a law, so it is overridable.
gtk_dark="${GROOTSHELL_GTK_THEME_DARK:-adw-gtk3-dark}"
gtk_light="${GROOTSHELL_GTK_THEME_LIGHT:-adw-gtk3}"

die() {
  echo "grootshell-theme: $*" >&2
  exit 1
}

[ $# -ge 1 ] || die "usage: $(basename "$0") <image> [light|dark]"

image="$1"
[ -f "$image" ] || die "no such image: $image"
[ -d "$templates" ] || die "no templates directory at $templates"
command -v matugen >/dev/null || die "matugen is not on PATH; see the README"

mode="${2:-}"
# Any third argument means "ignore the cache". The shell passes it for the
# `theme regenerate` IPC call, whose whole purpose is the case where what is on
# disk is wrong rather than merely stale — and a cache is exactly the sort of
# thing that can be wrong.
force="${3:-}"

# --- The cache ----------------------------------------------------------------
#
# Generating is not free: matugen reads every pixel, measured at 131ms on a 2MP
# PNG and 1555ms on a 24MP JPEG. That used to be invisible because the wallpaper
# changed first and the colours caught up; now that the cross-fade waits for the
# palette, it is a pause between clicking a wallpaper and anything happening.
#
# It is also perfectly repeatable — the same image through the same templates
# gives the same five files every time. So the second visit to a wallpaper is a
# copy rather than a computation, which is most visits: people cycle among the
# wallpapers they like.
#
# The key covers everything that changes the output. The image by path AND by
# mtime and size, so editing a file in place invalidates it. The mode as it was
# ASKED for rather than as resolved, because "auto" resolves from the image and
# is therefore stable per image. The templates, so editing one takes effect
# without a manual purge. And the GTK theme names, which are overridable and end
# up in settings.ini.
cache_root="${XDG_CACHE_HOME:-$HOME/.cache}/grootshell/themes"

stamp() {
  # GNU first, BSD second. A missing stat is not fatal — the fingerprint just
  # gets weaker, and the worst case is a stale entry that `force` clears.
  stat -c '%Y %s' "$1" 2>/dev/null || stat -f '%m %z' "$1" 2>/dev/null || echo nostat
}

fingerprint() {
  if command -v sha256sum >/dev/null; then
    sha256sum | cut -d' ' -f1
  elif command -v shasum >/dev/null; then
    shasum -a 256 | cut -d' ' -f1
  else
    # Not cryptographic, and does not need to be: this names a cache entry, it
    # does not authenticate one.
    cksum | tr -d ' '
  fi
}

cache_key="$({
  printf '%s\n' 1 "$image" "$(stamp "$image")" "${2:-auto}" "$gtk_dark" "$gtk_light"
  for tpl in "$templates"/*.tpl; do
    printf '%s %s\n' "${tpl##*/}" "$(stamp "$tpl")"
  done
} | fingerprint)"
entry="$cache_root/$cache_key"

# A hit also supplies the mode, which is what lets the brightness probe below be
# skipped entirely — that probe is a second full read of the image.
cached=""
if [ -z "$force" ] && [ -r "$entry/meta" ]; then
  cached_mode="$(sed -n 's/^mode=//p' "$entry/meta")"
  if [ -n "$cached_mode" ]; then
    cached="$entry"
    mode="$cached_mode"
  fi
fi

# --- Light or dark, from the image itself ------------------------------------
#
# A pale wallpaper behind a dark shell looks like a mistake rather than a theme.
#
# The measure is the SHARE OF PIXELS brighter than mid-grey, not mean brightness.
# Mean is dragged around by whichever region is largest: on a pale blue image with
# dark banding it reads 51%, barely above a dark photograph at 38%, and the two
# are not remotely alike. Counting bright pixels puts the same pair at 58% and
# 32%, which is a gap you can put a threshold in the middle of.
if [ -z "$mode" ]; then
  magick=""
  if command -v magick >/dev/null; then
    magick="magick"
  elif command -v convert >/dev/null; then
    # ImageMagick 6 has no `magick`; the old name does the same job here.
    magick="convert"
  fi

  if [ -n "$magick" ]; then
    bright=$("$magick" "$image" -colorspace Gray -threshold 50% -format "%[fx:mean*100]" info:)
    if [ "${bright%%.*}" -ge 50 ]; then mode=light; else mode=dark; fi
    echo "grootshell-theme: ${bright%%.*}% bright -> $mode mode"
  else
    mode=dark
    echo "grootshell-theme: ImageMagick not found, defaulting to dark mode" >&2
  fi
fi

case "$mode" in
  light | dark) ;;
  *) die "mode must be light or dark, got: $mode" ;;
esac

# --- Semantic colours ---------------------------------------------------------
#
# success and warning are absent from Material 3, which has no semantic colour for
# either, so they are NOT derived from the wallpaper: a green computed from a
# violet source is whatever the algorithm felt like, and "your disk is nearly
# full" must not change meaning with the picture behind it.
#
# They do have to change with the MODE, which is a different thing. The dark pair
# are pastels built to sit on a dark ground; measured on a light one they come out
# at 1.57:1 and 1.51:1, which is not a colour, it is an absence. The light pair
# are their dark-on-light counterparts, at about 6:1.
if [ "$mode" = light ]; then
  success="#2e6b32"
  warning="#7a5900"
  gtk_theme="$gtk_light"
  prefer="prefer-light"
else
  success="#a9d5a0"
  warning="#e8c98a"
  gtk_theme="$gtk_dark"
  prefer="prefer-dark"
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# The shell's template is the one thing that varies by mode, so it is
# materialised rather than shipped twice — one file to edit when a role changes.
sed -e "s|@mode@|$mode|g" -e "s|@success@|$success|g" -e "s|@warning@|$warning|g" \
  "$templates/theme.json.tpl" >"$work/theme.json.tpl"

# matugen resolves paths itself, but only from an absolute base — relative paths
# fail with "Failed to get the input and output paths".
cat >"$work/matugen.toml" <<TOML
# [config] is mandatory: matugen fails to parse the file without it, even empty.
[config]

[templates.grootshell]
input_path = "$work/theme.json.tpl"
output_path = "$work/out/theme.json"

[templates.gtk3]
input_path = "$templates/gtk.css.tpl"
output_path = "$work/out/gtk3.css"

[templates.gtk4]
input_path = "$templates/gtk.css.tpl"
output_path = "$work/out/gtk4.css"

[templates.wezterm]
input_path = "$templates/wezterm-colours.lua.tpl"
output_path = "$work/out/wezterm-colours.lua"

[templates.qt6ct]
input_path = "$templates/qt6ct-colors.conf.tpl"
output_path = "$work/out/qt6ct.conf"
TOML

# matugen does not create output directories, and on a fresh machine most of
# these do not exist.
mkdir -p \
  "$config/grootshell" \
  "$config/gtk-3.0" \
  "$config/gtk-4.0" \
  "$config/wezterm" \
  "$config/qt6ct/colors"

# Rendered files are staged and then copied into place, rather than written
# where they belong directly. Staging is what makes them cacheable: the five
# outputs become a directory that can be kept and copied back next time.
#
# `cp` and not `mv`: an atomic replace swaps the inode, and the shell's FileView
# watches theme.json by PATH — it would never see the change. Overwriting in
# place is what makes the colours apply live, and is worth not tidying up.
install_theme() {
  cp -f "$1/theme.json" "$config/grootshell/theme.json"
  cp -f "$1/gtk3.css" "$config/gtk-3.0/gtk.css"
  cp -f "$1/gtk4.css" "$config/gtk-4.0/gtk.css"
  cp -f "$1/wezterm-colours.lua" "$config/wezterm/colours.lua"
  cp -f "$1/qt6ct.conf" "$config/qt6ct/colors/grootshell.conf"
}

if [ -n "$cached" ]; then
  install_theme "$cached"
  # Touch it so the pruning below is least-recently-USED rather than oldest.
  touch "$cached" 2>/dev/null || true
  echo "grootshell-theme: cached colours for $(basename "$image") ($mode)"
else

# scheme-content, not the default scheme-tonal-spot. Measured against real
# wallpapers: tonal-spot desaturates surfaces toward neutral grey, which stops
# reading as "matches the wallpaper" the moment the image has a strong hue.
# content keeps the source's chroma in the surfaces and its accents true.
#
# --prefer saturation because an image with several viable source colours makes
# matugen ask, and on a headless host there is nobody to answer — it exits with
# "IO error: not a terminal". Saturation picks the most chromatic candidate,
# which is the one a person would have chosen. The flag needs matugen 4.1+.
mkdir -p "$work/out"
matugen image "$image" \
  --mode "$mode" \
  --type scheme-content \
  --prefer saturation \
  --config "$work/matugen.toml" \
  --quiet

install_theme "$work/out"

# Keep the result. Built beside the entry and moved into place, so a run that
# dies midway cannot leave a half-written entry to be found as a hit later.
if mkdir -p "$cache_root" 2>/dev/null; then
  printf 'mode=%s\n' "$mode" >"$work/out/meta"
  rm -rf "$entry" "$entry.tmp"
  if mv "$work/out" "$entry.tmp" 2>/dev/null && mv "$entry.tmp" "$entry" 2>/dev/null; then
    # LRU, capped. Each entry is five small text files, so this is about tidiness
    # rather than space — but a cache that only grows is a bug with a slow fuse.
    # shellcheck disable=SC2012
    ls -1dt "$cache_root"/*/ 2>/dev/null | tail -n +65 | while read -r old; do
      rm -rf "$old"
    done
  else
    echo "grootshell-theme: could not cache colours for $(basename "$image")" >&2
  fi
fi

fi

# --- The GTK theme name -------------------------------------------------------
#
# Not a colour, so not something matugen can write, and it has to follow the mode:
# adw-gtk3 still bakes 124 literal colours our CSS does not name, so its light and
# dark variants are not interchangeable even with every named colour overridden.
#
# Why adw-gtk3 at all: @define-color only restyles rules that REFERENCE the name.
# GTK3's stock Adwaita is compiled from SASS with literal hex baked into its
# widget rules, so redefining theme_bg_color restyles essentially nothing — and
# Chrome derives its colours by rendering real GTK widgets and sampling them, so
# it saw Adwaita's grey no matter what we wrote. adw-gtk3 is a port of
# libadwaita's stylesheet, which both defines and references the named colours.
#
# Only these two keys are touched. The rest of settings.ini is the user's — font,
# cursor, DPI, decoration layout — and a colour generator has no business
# rewriting it on every wallpaper change.
settings="$config/gtk-3.0/settings.ini"
[ -f "$settings" ] || printf '[Settings]\n' >"$settings"
set_key() {
  if grep -q "^$1=" "$settings"; then
    sed -i.bak "s|^$1=.*|$1=$2|" "$settings" && rm -f "$settings.bak"
  else
    # Appending under [Settings] rather than at the end, which would land it
    # in whatever group happens to be last.
    sed -i.bak "/^\[Settings\]/a\\
$1=$2" "$settings" && rm -f "$settings.bak"
  fi
}
set_key gtk-theme-name "$gtk_theme"
set_key gtk-application-prefer-dark-theme "$([ "$mode" = dark ] && echo true || echo false)"

# --- Tell anything that is listening -----------------------------------------
#
# The one part of this that RUNNING applications notice. Chrome and libadwaita
# both subscribe to the portal's color-scheme over D-Bus, so this flips them
# live; everything else here needs a restart.
if command -v dconf >/dev/null; then
  dconf write /org/gnome/desktop/interface/color-scheme "'$prefer'" || true
fi

# qt6ct watches ~/.config/qt6ct for DIRECTORY changes and reloads its palette
# three seconds later. It does not watch colors/ underneath it, and a write
# inside a subdirectory is not a change to the parent, so nothing would fire.
# Creating and removing an entry in the directory it does watch is what wakes it,
# and is why Qt applications recolour without restarting.
poke="$config/qt6ct/.grootshell-reload"
: >"$poke" && rm -f "$poke"
