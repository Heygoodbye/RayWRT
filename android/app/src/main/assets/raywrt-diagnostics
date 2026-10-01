#!/bin/sh
# Fixed connectivity checks. Only opaque endpoint IDs and results are returned to LuCI.
set -u
umask 077
[ "${1:-}" = run ] && [ "$#" -eq 1 ] || { echo 'Unsupported action' >&2; exit 2; }

tmpdir="/tmp/raywrt-ping-$$"
mkdir -p "$tmpdir" || exit 1
trap 'rm -rf "$tmpdir"' EXIT HUP INT TERM

run_ping() {
  id=$1
  host=$2
  out="$tmpdir/$id.out"
  result="$tmpdir/$id.result"
  if ! command -v ping >/dev/null 2>&1; then
    printf '%s|error|NA|NA|NA|NA|ping_unavailable|0|0\n' "$id" >"$result"
    return
  fi
  ping -n -q -c 4 -W 2 "$host" >"$out" 2>&1
  metrics=$(sed -n 's#.*= \([0-9.][0-9.]*\)/\([0-9.][0-9.]*\)/\([0-9.][0-9.]*\).*#\1|\2|\3#p' "$out" | tail -n 1)
  loss=$(sed -n 's/.* \([0-9][0-9]*\)% packet loss.*/\1/p' "$out" | tail -n 1)
  counts=$(sed -n 's/^\([0-9][0-9]*\) packets transmitted, \([0-9][0-9]*\).*received.*/\1|\2/p' "$out" | tail -n 1)
  counts=${counts:-NA|NA}
  loss=${loss:-NA}
  if [ -n "$metrics" ]; then
    printf '%s|ok|%s|%s||%s\n' "$id" "$metrics" "$loss" "$counts" >"$result"
  else
    if grep -Eiq 'bad address|unknown host|name or service not known' "$out"; then detail=dns_error
    elif grep -Eiq 'network is unreachable|no route to host|destination host unreachable' "$out"; then detail=no_route
    elif grep -Eiq 'operation not permitted|permission denied' "$out"; then detail=permission_error
    else detail=timeout; fi
    printf '%s|error|NA|NA|NA|%s|%s|%s\n' "$id" "$loss" "$detail" "$counts" >"$result"
  fi
}

while IFS='|' read -r id host; do
  [ -n "$id" ] || continue
  run_ping "$id" "$host" &
done <<'TARGETS'
openwrt|openwrt.org
wow1|185.60.112.157
wow2|185.60.112.158
league_euw|euw1.api.riotgames.com
league_eune|eun1.api.riotgames.com
tarkov1|104.18.7.148
tarkov2|104.18.6.148
wot1|92.223.20.1
fortnite_de|ping-de.ds.on.epicgames.com
fortnite_fr|ping-fr.ds.on.epicgames.com
fortnite_gb|ping-gb.ds.on.epicgames.com
pubg1|52.16.0.2
pubg2|52.19.0.2
pubg3|52.30.63.252
pubg4|34.248.60.213
TARGETS
wait

for id in openwrt wow1 wow2 league_euw league_eune tarkov1 tarkov2 wot1 fortnite_de fortnite_fr fortnite_gb pubg1 pubg2 pubg3 pubg4; do
  [ ! -f "$tmpdir/$id.result" ] || cat "$tmpdir/$id.result"
done
