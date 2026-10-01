#!/bin/sh
# Use the same configure/enable/progress API as RayWRT's LuCI WireGuard page.
set -eu
action=$1
interface=$2
helper=/usr/libexec/raywrt-wireguard-split
fail() { printf '%s\n' "$1" >&2; exit 1; }
case "$interface" in ''|*[!A-Za-z0-9_]*) fail 'Invalid WireGuard interface.';; esac
[ "$(uci -q get "network.$interface.proto")" = wireguard ] || fail 'WireGuard interface was not found.'
[ -x "$helper" ] || fail 'RayWRT Iran Direct routing is unavailable on this router.'
case "$action" in connect|disconnect) :;; *) fail 'Invalid WireGuard action.';; esac
[ -z "$(uci changes network)" ] && [ -z "$(uci changes raywrt)" ] || fail 'Apply pending Network and RayWRT changes in LuCI first.'
mkdir /tmp/raywrt-wg-control.lock 2>/dev/null || fail 'Another WireGuard action is running.'
trap 'rmdir /tmp/raywrt-wg-control.lock' EXIT
progress=$("$helper" progress)
case "$(printf '%s\n' "$progress" | sed -n 's/^state=//p')" in
 starting|running) fail 'Iran Direct routing is still processing a task. Try again when it finishes.';;
esac
selected=$(uci -q get raywrt.wireguard_split.interface || true)
if [ "$action" = disconnect ]; then
 message='WireGuard disconnected.'
 if [ "$selected" = "$interface" ]; then
  "$helper" disable
  message='WireGuard disconnected. Iran Direct routing disabled for this tunnel.'
 fi
 uci set "network.$interface.disabled=1"
 uci commit network
 ifdown "$interface"
 printf '%s\n' "$message"
 exit 0
fi
wan=$(uci -q get raywrt.wireguard_split.wan_interface || printf wan)
case "$wan" in ''|*[!A-Za-z0-9_-]*) fail 'Invalid direct WAN interface.';; esac
wan_proto=$(uci -q get "network.$wan.proto" || true)
[ -n "$wan_proto" ] && [ "$wan_proto" != wireguard ] || fail 'Select a physical Direct WAN interface in RayWRT LuCI first.'
# Remove the old policy before changing the selected full-tunnel route.
"$helper" disable
if [ "$selected" != "$interface" ] && [ -n "$selected" ]; then
 case "$selected" in *[!A-Za-z0-9_-]*) fail 'Invalid previously selected interface.';; esac
 if [ "$(uci -q get "network.$selected.proto" || true)" = wireguard ]; then
  uci set "network.$selected.disabled=1"
 fi
fi
uci set "network.$interface.disabled=0"
uci commit network
ubus call network reload >/dev/null
/etc/init.d/firewall reload >/dev/null
if [ "$selected" != "$interface" ] && [ -n "$selected" ] && [ "$(uci -q get "network.$selected.proto" || true)" = wireguard ]; then
 ifdown "$selected"
fi
ifup "$interface"
attempt=0
while [ "$attempt" -lt 15 ]; do
 up=$(ubus call "network.interface.$interface" status 2>/dev/null | jsonfilter -e '@.up' || true)
 [ "$up" != true ] || break
 sleep 1
 attempt=$((attempt + 1))
done
[ "${up:-false}" = true ] || fail 'WireGuard did not come up. Check the interface and peer settings in LuCI.'
"$helper" configure "$interface" "$wan"
started=$("$helper" enable)
job=$(printf '%s\n' "$started" | sed -n 's/^job_id=//p')
[ -n "$job" ] || fail 'Router did not confirm the Iran Direct routing task.'
attempt=0
while [ "$attempt" -lt 120 ]; do
 progress=$("$helper" progress)
 current_job=$(printf '%s\n' "$progress" | sed -n 's/^job_id=//p')
 [ "$current_job" = "$job" ] || fail 'The routing task changed. Refresh before trying again.'
 state=$(printf '%s\n' "$progress" | sed -n 's/^state=//p')
 case "$state" in
  success)
   status=$("$helper" status)
   printf '%s\n' "$status" | grep -qx 'state=active' || fail 'Iran Direct routing finished but is not active. Check its status in LuCI.'
   printf '%s\n' "$status" | grep -qx "interface=$interface" || fail 'Iran Direct routing selected another interface. Refresh before retrying.'
   printf '%s\n' 'WireGuard connected. Iran Direct routing enabled for the selected interface.'
   exit 0;;
  failed)
   printf '%s\n' "$progress" | sed '1,/^--LOG--$/d' >&2
   fail 'Iran Direct routing failed. Review the router message above.';;
  starting|running) :;;
  *) fail 'Unexpected routing task status. Refresh and check LuCI.';;
 esac
 sleep 1
 attempt=$((attempt + 1))
done
fail 'Iran Direct routing is still processing. Check its progress in LuCI before retrying.'
