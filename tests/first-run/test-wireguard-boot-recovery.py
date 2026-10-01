#!/usr/bin/env python3
import os,re,subprocess,tempfile
from pathlib import Path
base=Path(__file__).resolve().parents[2]
source=base/'root/usr/libexec/raywrt-wireguard-split'
if not source.exists(): source=base/'package/luci-theme-raywrt/root/usr/libexec/raywrt-wireguard-split'
code=source.read_text()
with tempfile.TemporaryDirectory() as directory:
 root=Path(directory)
 functions='\n'.join(re.search(r'^'+name+r'\(\) \{.*?^}',code,re.M|re.S).group() for name in ['vpn_has_handshake','check_boot_tunnel'])
 functions=functions.replace('/tmp/raywrt-wg-boot-fallback',str(root/'fallback'))
 script=functions+"""
setting() { echo wgtest; }
configured_wg() { return 0; }
full_tunnel_peer() { echo peer; }
uci() { echo key; }
wg() { printf 'key %s\n' "$handshake"; }
ubus() { echo '{}'; }
jsonfilter() { echo "$up"; }
vpn_is_default() { [ "$default" = vpn ]; }
restore_wan_runtime() { echo WAN >>"$TEST_ROOT/actions"; }
remove_policy() { echo CLEAN >>"$TEST_ROOT/actions"; }
logger() { :; }
ip() { echo VPN >>"$TEST_ROOT/actions"; }
handshake=0 up=30 default=vpn
check_boot_tunnel
[ ! -f "$TEST_ROOT/actions" ]
up=100
check_boot_tunnel
[ "$(cat "$TEST_ROOT/actions")" = "$(printf 'WAN\nCLEAN')" ]
[ "$(cat "$TEST_ROOT/fallback")" = wgtest ]
handshake=123 default=wan
check_boot_tunnel
[ ! -f "$TEST_ROOT/fallback" ]
[ "$(tail -n1 "$TEST_ROOT/actions")" = VPN ]
rm "$TEST_ROOT/actions"
default=vpn
check_boot_tunnel
[ ! -f "$TEST_ROOT/actions" ]
"""
 helper=root/'test.sh';helper.write_text('set -eu\n'+script)
 subprocess.run(['sh',str(helper)],env=dict(os.environ,TEST_ROOT=str(root)),check=True)
print('PASS: boot grace, zero-handshake WAN recovery, handshake reconnection, working tunnel untouched')
