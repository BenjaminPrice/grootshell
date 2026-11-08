#!/usr/bin/env bash
#
# tray-context-menu.sh <item id> <x> <y>
#
# Sends ContextMenu(x, y) to the StatusNotifierItem whose Id is <item id>, at
# X root coordinates (device pixels).
#
# Exists because Quickshell's SystemTrayItem has no way to send ContextMenu,
# and no way to say where the icon is: activate() and secondaryActivate() always
# pass 0,0. For an item that draws its own menu — a Wine/Proton tray icon relayed
# by xembedsniproxy — the position is the whole point: Wine opens the menu where
# it believes the icon is, so without it the menu could only ever open wherever
# the proxy parked the icon. Neither does Quickshell expose the item's D-Bus
# address, so this finds it the long way: ask the watcher for every registered
# item and match on Id.
#
# Exit status is non-zero when no item matched or the call failed, so the bar
# can fall back to secondaryActivate().

set -euo pipefail

id="$1" x="$2" y="$3"

watcher=org.kde.StatusNotifierWatcher

# `as N "service/path" ...` — one quoted entry per item. Quickshell's watcher
# registers items as "<unique name>/<object path>".
entries="$(busctl --user get-property "$watcher" /StatusNotifierWatcher "$watcher" RegisteredStatusNotifierItems)"

while IFS= read -r entry; do
  service="${entry%%/*}"
  path="/${entry#*/}"
  # `s "<id>"`
  got="$(busctl --user get-property "$service" "$path" org.kde.StatusNotifierItem Id 2>/dev/null)" || continue
  got="${got#s \"}"
  got="${got%\"}"
  if [[ "$got" == "$id" ]]; then
    exec busctl --user call "$service" "$path" org.kde.StatusNotifierItem ContextMenu ii "$x" "$y"
  fi
done < <(grep -oE '"[^"]+"' <<<"$entries" | tr -d '"')

echo "tray-context-menu: no item with Id $id" >&2
exit 1
