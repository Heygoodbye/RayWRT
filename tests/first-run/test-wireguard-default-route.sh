#!/bin/sh
set -eu

source_root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
helper="$source_root/root/usr/libexec/raywrt-wireguard-split"
[ -f "$helper" ] || helper="$source_root/package/luci-theme-raywrt/root/usr/libexec/raywrt-wireguard-split"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
for function in valid_id configured_wg vpn_is_default full_tunnel_peer restore_wg_default_route ensure_wg_default_route; do
  sed -n "/^$function() {/,/^}/p" "$helper" >> "$work/functions"
done
. "$work/functions"

flag=unavailable disabled=1 active=no peers=1 allowed='0.0.0.0/0' works=yes changes=0
uci() {
  [ "${1:-}" != -q ] || shift
  case "$1 $2" in
    'show network')
      printf 'network.@wireguard_wgtest[0]=wireguard_wgtest\n'
      [ "$peers" != 2 ] || printf 'network.@wireguard_wgtest[1]=wireguard_wgtest\n'
      ;;
    'get network.wgtest.proto') echo wireguard ;;
    'get network.@wireguard_wgtest[0].allowed_ips'|'get network.@wireguard_wgtest[1].allowed_ips') echo "$allowed" ;;
    'get network.@wireguard_wgtest[0].route_allowed_ips')
      [ "$flag" != unavailable ] || return 1
      echo "$flag" ;;
    'get network.wgtest.disabled') echo "$disabled" ;;
    'set network.@wireguard_wgtest[0].route_allowed_ips=1') flag=1; changes=$((changes+1)) ;;
    'set network.@wireguard_wgtest[0].route_allowed_ips=0') flag=0; changes=$((changes+1)) ;;
    'set network.wgtest.disabled=0') disabled=0; changes=$((changes+1)) ;;
    'set network.wgtest.disabled=1') disabled=1; changes=$((changes+1)) ;;
    'delete network.@wireguard_wgtest[0].route_allowed_ips') flag=unavailable; changes=$((changes+1)) ;;
    'commit network') : ;;
    *) echo "Unexpected UCI call: $*" >&2; return 1 ;;
  esac
}
ip() {
  [ "$1 $2 $3 $4" = '-4 route get 1.1.1.1' ] || return 1
  if [ "$active" = yes ]; then echo '1.1.1.1 dev wgtest src 10.0.0.2'; else echo '1.1.1.1 dev wan src 192.0.2.2'; fi
}
ifdown() { active=no; }
ifup() { [ "$works" != yes ] || [ "$flag" != 1 ] || [ "$disabled" = 1 ] || active=yes; }
sleep() { :; }

ensure_wg_default_route wgtest >/dev/null
[ "$flag" = 1 ] && [ "$disabled" = 0 ] && [ "$active" = yes ] && [ "$changes" -eq 2 ]
restore_wg_default_route
[ "$flag" = unavailable ] && [ "$disabled" = 1 ] && [ "$changes" -eq 4 ]

active=yes disabled=0 changes=0
ensure_wg_default_route wgtest >/dev/null
[ "$changes" -eq 0 ]

active=no disabled=1 peers=2 changes=0
if ensure_wg_default_route wgtest >/dev/null 2>&1; then exit 1; fi
[ "$changes" -eq 0 ]

peers=1 allowed='10.0.0.0/8' changes=0
if ensure_wg_default_route wgtest >/dev/null 2>&1; then exit 1; fi
[ "$changes" -eq 0 ]

allowed='0.0.0.0/0' works=no changes=0
if ensure_wg_default_route wgtest >/dev/null 2>&1; then exit 1; fi
[ "$flag" = unavailable ] && [ "$disabled" = 1 ] && [ "$active" = no ] && [ "$changes" -eq 4 ]

flag=0 disabled=0 changes=0
if ensure_wg_default_route wgtest >/dev/null 2>&1; then exit 1; fi
[ "$flag" = 0 ] && [ "$changes" -eq 2 ]

works=yes flag=1 disabled=1 changes=0
ensure_wg_default_route wgtest >/dev/null
[ "$flag" = 1 ] && [ "$disabled" = 0 ] && [ "$changes" -eq 1 ]
restore_wg_default_route
[ "$disabled" = 1 ] && [ "$changes" -eq 2 ]

works=no flag=1 disabled=0 active=no changes=0
if ensure_wg_default_route wgtest >/dev/null 2>&1; then exit 1; fi
[ "$flag" = 1 ] && [ "$disabled" = 0 ] && [ "$changes" -eq 0 ]
echo 'PASS: WireGuard default-route setup, preservation and rollback.'
