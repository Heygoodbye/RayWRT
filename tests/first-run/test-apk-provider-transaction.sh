#!/bin/sh
set -eu
base=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
source="$base/root/usr/libexec/raywrt-tools"
[ -f "$source" ] || source="$base/package/luci-theme-raywrt/root/usr/libexec/raywrt-tools"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
sed -n '/^apk_add_full_ip() {/,/^}/p' "$source" > "$tmp/helper"
. "$tmp/helper"
apk() {
 if [ "$1" = info ]; then [ "$tiny" = yes ]; return; fi
 printf '%s\n' "$*" >> "$tmp/calls"
 return "$result"
}
tiny=yes result=0
apk_add_full_ip luci-app-passwall2 wireguard-tools
[ "$(cat "$tmp/calls")" = "add luci-app-passwall2 wireguard-tools ip-full !ip-tiny" ]
[ "$(wc -l < "$tmp/calls")" -eq 1 ]
tiny=no
: > "$tmp/calls"
apk_add_full_ip luci-app-passwall2
[ "$(cat "$tmp/calls")" = 'add luci-app-passwall2 ip-full' ]
tiny=yes result=23
if apk_add_full_ip luci-app-passwall2; then echo 'FAIL: solver failure swallowed'; exit 1; else [ "$?" -eq 23 ]; fi
echo 'PASS: one atomic provider transaction, no pre-removal, solver failure preserved.'
