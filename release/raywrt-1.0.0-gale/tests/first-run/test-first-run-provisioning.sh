#!/bin/sh
set -eu

SOURCE_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
if [ -f "$SOURCE_ROOT/root/usr/libexec/raywrt-first-run-wifi" ]; then
	PACKAGE_ROOT=$SOURCE_ROOT
else
	PACKAGE_ROOT="$SOURCE_ROOT/package/luci-theme-raywrt"
fi
TMP_ROOT=$(mktemp -d)
trap 'rm -rf "$TMP_ROOT"' EXIT HUP INT TERM
mkdir -p "$TMP_ROOT/bin"

cat >"$TMP_ROOT/bin/uci" <<'EOF'
#!/bin/sh
exec python3 "$RAYWRT_TEST_SOURCE/tests/first-run/fake-uci.py" "$@"
EOF
cat >"$TMP_ROOT/bin/wifi" <<'EOF'
#!/bin/sh
[ "$1" = reload ] || exit 1
n=$(cat "${RAYWRT_TEST_WIFI_COUNT:-/dev/null}" 2>/dev/null || echo 0)
n=$((n + 1))
[ -z "${RAYWRT_TEST_WIFI_COUNT:-}" ] || echo "$n" >"$RAYWRT_TEST_WIFI_COUNT"
[ "$n" -gt "${RAYWRT_TEST_WIFI_FAIL_UNTIL:-0}" ]
EOF
cat >"$TMP_ROOT/bin/ubus" <<'EOF'
#!/bin/sh
[ "$*" = 'call network reload' ] || exit 1
[ -z "${RAYWRT_CONFIG_DIR:-}" ] || echo reload >>"$RAYWRT_CONFIG_DIR/.network-reloads"
EOF
chmod 755 "$TMP_ROOT/bin/uci" "$TMP_ROOT/bin/wifi" "$TMP_ROOT/bin/ubus"
export PATH="$TMP_ROOT/bin:$PATH" RAYWRT_TEST_SOURCE="$SOURCE_ROOT" RAYWRT_PACKAGE_SOURCE="$PACKAGE_ROOT"

fixture() {
  dir=$1
  shift
  mkdir -p "$dir"
  : >"$dir/wireless"
  printf '%s\n' "$@" >"$dir/.fixture-uci.json"
}

seed_json() {
  python3 - "$1" "$2" <<'PY'
import json, sys
from pathlib import Path
Path(sys.argv[1]).write_text(json.dumps(json.loads(sys.argv[2])))
PY
}

# Fresh image: register the RayWRT theme and select it once from the fresh
# config marker. Re-running after a user chooses another theme must preserve it.
fresh_theme="$TMP_ROOT/fresh-theme"
mkdir -p "$fresh_theme"
seed_json "$fresh_theme/.fixture-uci.json" '{
  "raywrt.system":"system","raywrt.system.theme_default":"pending"
}'
RAYWRT_CONFIG_DIR="$fresh_theme" sh "$PACKAGE_ROOT/root/etc/uci-defaults/30_luci-theme-raywrt"
[ "$(RAYWRT_CONFIG_DIR="$fresh_theme" uci -q get luci.main.mediaurlbase)" = /luci-static/raywrt ]
[ "$(RAYWRT_CONFIG_DIR="$fresh_theme" uci -q get luci.themes.RayWRT)" = /luci-static/raywrt ]
[ "$(RAYWRT_CONFIG_DIR="$fresh_theme" uci -q get raywrt.system.theme_default)" = applied ]
RAYWRT_CONFIG_DIR="$fresh_theme" uci set luci.main.mediaurlbase=/luci-static/bootstrap
RAYWRT_CONFIG_DIR="$fresh_theme" sh "$PACKAGE_ROOT/root/etc/uci-defaults/30_luci-theme-raywrt"
[ "$(RAYWRT_CONFIG_DIR="$fresh_theme" uci -q get luci.main.mediaurlbase)" = /luci-static/bootstrap ]
echo 'PASS: first-boot theme selection and later user theme preservation'

# Existing installs lack the new fresh-install marker, so even a stock theme
# selection remains untouched if this one-time script is introduced on upgrade.
legacy_theme="$TMP_ROOT/legacy-theme"
mkdir -p "$legacy_theme"
seed_json "$legacy_theme/.fixture-uci.json" '{
  "luci.main":"main","luci.main.mediaurlbase":"/luci-static/bootstrap",
  "raywrt.system":"system"
}'
RAYWRT_CONFIG_DIR="$legacy_theme" sh "$PACKAGE_ROOT/root/etc/uci-defaults/30_luci-theme-raywrt"
[ "$(RAYWRT_CONFIG_DIR="$legacy_theme" uci -q get luci.main.mediaurlbase)" = /luci-static/bootstrap ]
echo 'PASS: legacy config without marker preserves selected theme'

# Fresh Gale UCI: the band is discovered from each radio section, not the
# section name. Both devices and stock APs start disabled in this fixture.
fresh_wifi="$TMP_ROOT/fresh-wifi"
mkdir -p "$fresh_wifi"
: >"$fresh_wifi/wireless"
seed_json "$fresh_wifi/.fixture-uci.json" '{
  "wireless.radio5":"wifi-device","wireless.radio5.band":"5g","wireless.radio5.disabled":"1",
  "wireless.radio2":"wifi-device","wireless.radio2.band":"2g","wireless.radio2.disabled":"1",
  "wireless.default_radio5":"wifi-iface","wireless.default_radio5.device":"radio5",
  "wireless.default_radio5.mode":"ap","wireless.default_radio5.network":"lan","wireless.default_radio5.ssid":"OpenWrt","wireless.default_radio5.disabled":"1",
  "wireless.default_radio2":"wifi-iface","wireless.default_radio2.device":"radio2",
  "wireless.default_radio2.mode":"ap","wireless.default_radio2.network":"lan","wireless.default_radio2.ssid":"OpenWrt","wireless.default_radio2.disabled":"1",
  "raywrt.system.initialized":"0","raywrt.system.wifi_default":"pending"
}'
RAYWRT_CONFIG_DIR="$fresh_wifi" sh "$PACKAGE_ROOT/root/usr/libexec/raywrt-first-run-wifi"
[ "$(RAYWRT_CONFIG_DIR="$fresh_wifi" uci -q get wireless.default_radio2.ssid)" = RayWRT ]
[ "$(RAYWRT_CONFIG_DIR="$fresh_wifi" uci -q get wireless.default_radio5.ssid)" = RayWRT ]
[ "$(RAYWRT_CONFIG_DIR="$fresh_wifi" uci -q get wireless.default_radio2.disabled)" = 0 ]
[ "$(RAYWRT_CONFIG_DIR="$fresh_wifi" uci -q get wireless.default_radio5.disabled)" = 0 ]
[ "$(RAYWRT_CONFIG_DIR="$fresh_wifi" uci -q get wireless.radio2.disabled)" = 0 ]
[ "$(RAYWRT_CONFIG_DIR="$fresh_wifi" uci -q get wireless.radio5.disabled)" = 0 ]
[ "$(RAYWRT_CONFIG_DIR="$fresh_wifi" uci -q get wireless.default_radio5.network)" = lan ]
[ "$(RAYWRT_CONFIG_DIR="$fresh_wifi" uci -q get raywrt.system.wifi_default)" = applied ]
echo 'PASS: first-run enables Gale 2.4/5 GHz radios/APs, sets RayWRT and LAN'

# One band absent: provision only the detected 2.4 GHz radio.
one_radio="$TMP_ROOT/one-radio"
mkdir -p "$one_radio"; : >"$one_radio/wireless"
seed_json "$one_radio/.fixture-uci.json" '{
  "wireless.phy_blue":"wifi-device","wireless.phy_blue.band":"2g","wireless.phy_blue.disabled":"1",
  "wireless.ap_blue":"wifi-iface","wireless.ap_blue.device":"phy_blue","wireless.ap_blue.mode":"ap","wireless.ap_blue.ssid":"OpenWrt","wireless.ap_blue.disabled":"1",
  "raywrt.system.wifi_default":"pending"
}'
RAYWRT_CONFIG_DIR="$one_radio" sh "$PACKAGE_ROOT/root/usr/libexec/raywrt-first-run-wifi"
[ "$(RAYWRT_CONFIG_DIR="$one_radio" uci -q get wireless.ap_blue.ssid)" = RayWRT ]
[ "$(RAYWRT_CONFIG_DIR="$one_radio" uci -q show wireless | grep -c "mode='ap'")" = 1 ]
echo 'PASS: one missing radio is not fabricated or confused with radio indices'

# Upgrade/custom config: a custom AP label must remain untouched.
custom_wifi="$TMP_ROOT/custom-wifi"
mkdir -p "$custom_wifi"
: >"$custom_wifi/wireless"
seed_json "$custom_wifi/.fixture-uci.json" '{
  "wireless.radio5":"wifi-device","wireless.radio5.band":"5g","wireless.radio5.disabled":"1",
  "wireless.radio2":"wifi-device","wireless.radio2.band":"2g","wireless.radio2.disabled":"1",
  "wireless.default_radio5":"wifi-iface","wireless.default_radio5.device":"radio5",
  "wireless.default_radio5.mode":"ap","wireless.default_radio5.ssid":"MyHome","wireless.default_radio5.disabled":"1",
  "wireless.default_radio2":"wifi-iface","wireless.default_radio2.device":"radio2",
  "wireless.default_radio2.mode":"ap","wireless.default_radio2.ssid":"OpenWrt","wireless.default_radio2.disabled":"1",
  "raywrt.system.initialized":"0","raywrt.system.wifi_default":"pending"
}'
RAYWRT_CONFIG_DIR="$custom_wifi" sh "$PACKAGE_ROOT/root/usr/libexec/raywrt-first-run-wifi"
[ "$(RAYWRT_CONFIG_DIR="$custom_wifi" uci -q get wireless.default_radio5.ssid)" = MyHome ]
[ "$(RAYWRT_CONFIG_DIR="$custom_wifi" uci -q get wireless.radio5.disabled)" = 1 ]
[ "$(RAYWRT_CONFIG_DIR="$custom_wifi" uci -q get wireless.default_radio2.ssid)" = OpenWrt ]
echo 'PASS: a custom SSID preserves all user Wi-Fi settings'

# The marker makes the provisioning one-shot; an intentional later radio-off
# choice survives a subsequent helper invocation/reboot.
RAYWRT_CONFIG_DIR="$fresh_wifi" uci set wireless.radio2.disabled=1
RAYWRT_CONFIG_DIR="$fresh_wifi" uci set wireless.default_radio2.disabled=1
RAYWRT_CONFIG_DIR="$fresh_wifi" sh "$PACKAGE_ROOT/root/usr/libexec/raywrt-first-run-wifi"
[ "$(RAYWRT_CONFIG_DIR="$fresh_wifi" uci -q get wireless.radio2.disabled)" = 1 ]
[ "$(RAYWRT_CONFIG_DIR="$fresh_wifi" uci -q get wireless.default_radio2.disabled)" = 1 ]
echo 'PASS: intentionally disabling a radio after first run is preserved'

# A detected supported band with no AP gets one minimal LAN AP.
missing_ap="$TMP_ROOT/missing-ap"
mkdir -p "$missing_ap"; : >"$missing_ap/wireless"
seed_json "$missing_ap/.fixture-uci.json" '{
  "wireless.device24":"wifi-device","wireless.device24.band":"2g",
  "wireless.device5":"wifi-device","wireless.device5.band":"5g",
  "wireless.stock_ap":"wifi-iface","wireless.stock_ap.device":"device24","wireless.stock_ap.mode":"ap","wireless.stock_ap.ssid":"OpenWrt",
  "raywrt.system.wifi_default":"pending"
}'
RAYWRT_CONFIG_DIR="$missing_ap" sh "$PACKAGE_ROOT/root/usr/libexec/raywrt-first-run-wifi"
python3 - "$missing_ap/.fixture-uci.json" <<'PY'
import json, sys
from pathlib import Path
state = json.loads(Path(sys.argv[1]).read_text())
aps = {key.split('.')[1]: value for key, value in state.items()
       if key.startswith('wireless.') and key.count('.') == 1 and value == 'wifi-iface'}
created = [name for name in aps if state.get(f'wireless.{name}.device') == 'device5']
assert len(created) == 1, created
name = created[0]
assert state.get(f'wireless.{name}.mode') == 'ap'
assert state.get(f'wireless.{name}.network') == 'lan'
assert state.get(f'wireless.{name}.ssid') == 'RayWRT'
assert state.get(f'wireless.{name}.disabled') == '0'
PY
echo 'PASS: a missing supported AP gets one minimal 5 GHz LAN interface'

# First-boot APK index initialization is asynchronous and bounded. Mock apk
# fails once then succeeds; a second fixture proves the retry limit is 4.
mkdir -p "$TMP_ROOT/package-bin"
cat >"$TMP_ROOT/package-bin/apk" <<'EOF'
#!/bin/sh
n=$(cat "$RAYWRT_TEST_APK_COUNT" 2>/dev/null || echo 0)
n=$((n + 1)); echo "$n" >"$RAYWRT_TEST_APK_COUNT"
[ "${RAYWRT_TEST_APK_ALWAYS_FAIL:-0}" != 1 ] || exit 1
[ "$n" -gt "${RAYWRT_TEST_APK_FAIL_UNTIL:-0}" ]
EOF
cat >"$TMP_ROOT/package-bin/logger" <<'EOF'
#!/bin/sh
exit 0
EOF
cat >"$TMP_ROOT/package-bin/wget" <<'EOF'
#!/bin/sh
n=$(cat "$RAYWRT_TEST_WGET_COUNT" 2>/dev/null || echo 0)
n=$((n + 1)); echo "$n" >"$RAYWRT_TEST_WGET_COUNT"
[ "${RAYWRT_TEST_WGET_ALWAYS_FAIL:-0}" != 1 ] || exit 1
[ "$n" -gt "${RAYWRT_TEST_WGET_FAIL_UNTIL:-0}" ]
EOF
cat >"$TMP_ROOT/package-bin/sleep" <<'EOF'
#!/bin/sh
echo "$1" >>"$RAYWRT_TEST_SLEEP_LOG"
if [ -n "${RAYWRT_TEST_MARKER_LOG:-}" ]; then
  marker=$(RAYWRT_CONFIG_DIR="$RAYWRT_CONFIG_DIR" uci -q get raywrt.system.wifi_default 2>/dev/null || true)
  echo "$marker" >>"$RAYWRT_TEST_MARKER_LOG"
fi
if [ "${RAYWRT_TEST_ADD_LATE_WIFI:-0}" = 1 ]; then
  python3 - "$RAYWRT_CONFIG_DIR/.fixture-uci.json" <<'PY'
import json, sys
from pathlib import Path
path = Path(sys.argv[1])
state = json.loads(path.read_text())
state.update({
    'wireless.radio5': 'wifi-device', 'wireless.radio5.band': '5g', 'wireless.radio5.disabled': '1',
    'wireless.radio2': 'wifi-device', 'wireless.radio2.band': '2g', 'wireless.radio2.disabled': '1',
    'wireless.default_radio5': 'wifi-iface', 'wireless.default_radio5.device': 'radio5',
    'wireless.default_radio5.mode': 'ap', 'wireless.default_radio5.network': 'lan',
    'wireless.default_radio5.ssid': 'OpenWrt', 'wireless.default_radio5.disabled': '1',
    'wireless.default_radio2': 'wifi-iface', 'wireless.default_radio2.device': 'radio2',
    'wireless.default_radio2.mode': 'ap', 'wireless.default_radio2.network': 'lan',
    'wireless.default_radio2.ssid': 'OpenWrt', 'wireless.default_radio2.disabled': '1',
})
path.write_text(json.dumps(state, sort_keys=True))
PY
fi
EOF
cat >"$TMP_ROOT/package-bin/service" <<'EOF'
#!/bin/sh
echo "$*" >>"$RAYWRT_TEST_SERVICE_LOG"
EOF
chmod 755 "$TMP_ROOT/package-bin/"*

# Wireless config can appear after early boot; the durable marker must remain
# pending until the supported radios/APs are actually applied and verified.
late_wireless="$TMP_ROOT/late-wireless"
mkdir -p "$late_wireless"; : >"$late_wireless/wireless"
seed_json "$late_wireless/.fixture-uci.json" '{"raywrt.system":"system","raywrt.system.wifi_default":"pending"}'
: >"$TMP_ROOT/sleep-log"; : >"$TMP_ROOT/marker-log"
RAYWRT_CONFIG_DIR="$late_wireless" RAYWRT_WIFI_RETRIES=3 RAYWRT_WIFI_RETRY_DELAY=1 \
  RAYWRT_TEST_SLEEP_LOG="$TMP_ROOT/sleep-log" RAYWRT_TEST_MARKER_LOG="$TMP_ROOT/marker-log" RAYWRT_TEST_ADD_LATE_WIFI=1 \
  PATH="$TMP_ROOT/package-bin:$PATH" sh "$PACKAGE_ROOT/root/usr/libexec/raywrt-first-run-wifi" --wait
[ "$(RAYWRT_CONFIG_DIR="$late_wireless" uci -q get raywrt.system.wifi_default)" = applied ]
[ "$(cat "$TMP_ROOT/marker-log")" = pending ]
[ "$(RAYWRT_CONFIG_DIR="$late_wireless" uci -q get wireless.default_radio2.ssid)" = RayWRT ]
echo 'PASS: first-run waits for late wireless UCI and keeps its marker pending until both APs verify'

# The init-time runner must retry when wireless is not yet configured or a
# reload temporarily fails, and it must keep the durable marker pending until
# the UCI values have been applied and verified.
retry_wifi="$TMP_ROOT/retry-wifi"
mkdir -p "$retry_wifi"; : >"$retry_wifi/wireless"
seed_json "$retry_wifi/.fixture-uci.json" '{
  "wireless.radio5":"wifi-device","wireless.radio5.band":"5g","wireless.radio5.disabled":"1",
  "wireless.radio2":"wifi-device","wireless.radio2.band":"2g","wireless.radio2.disabled":"1",
  "wireless.default_radio5":"wifi-iface","wireless.default_radio5.device":"radio5",
  "wireless.default_radio5.mode":"ap","wireless.default_radio5.network":"lan",
  "wireless.default_radio5.ssid":"OpenWrt","wireless.default_radio5.disabled":"1",
  "wireless.default_radio2":"wifi-iface","wireless.default_radio2.device":"radio2",
  "wireless.default_radio2.mode":"ap","wireless.default_radio2.network":"lan",
  "wireless.default_radio2.ssid":"OpenWrt","wireless.default_radio2.disabled":"1",
  "raywrt.system":"system","raywrt.system.wifi_default":"pending"
}'
cat >"$TMP_ROOT/package-bin/sleep" <<'EOF'
#!/bin/sh
echo "$1" >>"$RAYWRT_TEST_SLEEP_LOG"
if [ -n "${RAYWRT_TEST_MARKER_LOG:-}" ]; then
  marker=$(RAYWRT_CONFIG_DIR="$RAYWRT_CONFIG_DIR" uci -q get raywrt.system.wifi_default 2>/dev/null || true)
  echo "$marker" >>"$RAYWRT_TEST_MARKER_LOG"
fi
EOF
chmod 755 "$TMP_ROOT/package-bin/sleep"
: >"$TMP_ROOT/wifi-count"; : >"$TMP_ROOT/sleep-log"; : >"$TMP_ROOT/marker-log"
RAYWRT_CONFIG_DIR="$retry_wifi" RAYWRT_WIFI_RETRIES=3 RAYWRT_WIFI_RETRY_DELAY=1 \
  RAYWRT_TEST_WIFI_COUNT="$TMP_ROOT/wifi-count" RAYWRT_TEST_WIFI_FAIL_UNTIL=2 \
  RAYWRT_TEST_SLEEP_LOG="$TMP_ROOT/sleep-log" RAYWRT_TEST_MARKER_LOG="$TMP_ROOT/marker-log" \
  PATH="$TMP_ROOT/package-bin:$PATH" sh "$PACKAGE_ROOT/root/usr/libexec/raywrt-first-run-wifi" --wait
[ "$(RAYWRT_CONFIG_DIR="$retry_wifi" uci -q get raywrt.system.wifi_default)" = applied ]
[ "$(cat "$TMP_ROOT/marker-log")" = pending ]
[ "$(RAYWRT_CONFIG_DIR="$retry_wifi" uci -q get wireless.default_radio2.ssid)" = RayWRT ]
[ "$(RAYWRT_CONFIG_DIR="$retry_wifi" uci -q get wireless.default_radio5.ssid)" = RayWRT ]
echo 'PASS: wireless reload retries leave the first-run marker pending until verified provisioning succeeds'

failed_wifi="$TMP_ROOT/failed-wifi"
mkdir -p "$failed_wifi"; : >"$failed_wifi/wireless"
printf '%s\n' '# original wireless config fixture' >"$failed_wifi/wireless"
cp "$failed_wifi/wireless" "$TMP_ROOT/failed-wireless.expected"
seed_json "$failed_wifi/.fixture-uci.json" '{
  "wireless.radio2":"wifi-device","wireless.radio2.band":"2g","wireless.radio2.disabled":"1",
  "wireless.default_radio2":"wifi-iface","wireless.default_radio2.device":"radio2",
  "wireless.default_radio2.mode":"ap","wireless.default_radio2.network":"lan",
  "wireless.default_radio2.ssid":"OpenWrt","wireless.default_radio2.disabled":"1",
  "raywrt.system":"system","raywrt.system.wifi_default":"pending"
}'
: >"$TMP_ROOT/wifi-count"; : >"$TMP_ROOT/sleep-log"; : >"$TMP_ROOT/marker-log"
if RAYWRT_CONFIG_DIR="$failed_wifi" RAYWRT_WIFI_RETRIES=2 RAYWRT_WIFI_RETRY_DELAY=1 \
  RAYWRT_TEST_WIFI_COUNT="$TMP_ROOT/wifi-count" RAYWRT_TEST_WIFI_FAIL_UNTIL=99 \
  RAYWRT_TEST_SLEEP_LOG="$TMP_ROOT/sleep-log" RAYWRT_TEST_MARKER_LOG="$TMP_ROOT/marker-log" \
  PATH="$TMP_ROOT/package-bin:$PATH" sh "$PACKAGE_ROOT/root/usr/libexec/raywrt-first-run-wifi" --wait; then
  echo 'FAIL: a Wi-Fi apply that never verifies must not be reported as successful' >&2; exit 1
fi
[ "$(RAYWRT_CONFIG_DIR="$failed_wifi" uci -q get raywrt.system.wifi_default)" = failed ]
[ "$(cat "$failed_wifi/wireless")" = "$(cat "$TMP_ROOT/failed-wireless.expected")" ]
echo 'PASS: exhausted provisioning rolls back and never records an applied marker'
package_indexes="$TMP_ROOT/package-indexes"
mkdir -p "$package_indexes"; : >"$package_indexes/raywrt"
seed_json "$package_indexes/.fixture-uci.json" '{"raywrt.system":"system","raywrt.system.package_indexes":"pending"}'
: >"$TMP_ROOT/apk-count"; : >"$TMP_ROOT/wget-count"; : >"$TMP_ROOT/sleep-log"; : >"$TMP_ROOT/service-log"
printf '%s\n' 'https://packages.openwrt.invalid/packages.adb' >"$TMP_ROOT/repositories.list"
RAYWRT_CONFIG_DIR="$package_indexes" RAYWRT_APK_REPOSITORIES="$TMP_ROOT/repositories.list" RAYWRT_PACKAGE_INIT_SERVICE="$TMP_ROOT/package-bin/service" \
  RAYWRT_TEST_APK_COUNT="$TMP_ROOT/apk-count" RAYWRT_TEST_SLEEP_LOG="$TMP_ROOT/sleep-log" \
  RAYWRT_TEST_SERVICE_LOG="$TMP_ROOT/service-log" RAYWRT_TEST_WGET_COUNT="$TMP_ROOT/wget-count" RAYWRT_TEST_APK_FAIL_UNTIL=1 \
  PATH="$TMP_ROOT/package-bin:$PATH" sh "$PACKAGE_ROOT/root/usr/libexec/raywrt-package-index-init"
[ "$(RAYWRT_CONFIG_DIR="$package_indexes" uci -q get raywrt.system.package_indexes)" = ready ]
[ "$(cat "$TMP_ROOT/apk-count")" = 2 ]
[ "$(cat "$TMP_ROOT/sleep-log")" = 30 ]
[ "$(cat "$TMP_ROOT/service-log")" = disable ]
echo 'PASS: APK package indexes initialize in background with bounded retry and success state'

package_failure="$TMP_ROOT/package-failure"
mkdir -p "$package_failure"; : >"$package_failure/raywrt"
seed_json "$package_failure/.fixture-uci.json" '{"raywrt.system":"system","raywrt.system.package_indexes":"pending"}'
: >"$TMP_ROOT/apk-count"; : >"$TMP_ROOT/wget-count"; : >"$TMP_ROOT/sleep-log"; : >"$TMP_ROOT/service-log"
if RAYWRT_CONFIG_DIR="$package_failure" RAYWRT_APK_REPOSITORIES="$TMP_ROOT/repositories.list" RAYWRT_PACKAGE_INIT_SERVICE="$TMP_ROOT/package-bin/service" \
  RAYWRT_TEST_APK_COUNT="$TMP_ROOT/apk-count" RAYWRT_TEST_SLEEP_LOG="$TMP_ROOT/sleep-log" \
  RAYWRT_TEST_WGET_COUNT="$TMP_ROOT/wget-count" RAYWRT_TEST_SERVICE_LOG="$TMP_ROOT/service-log" RAYWRT_TEST_APK_ALWAYS_FAIL=1 \
  PATH="$TMP_ROOT/package-bin:$PATH" sh "$PACKAGE_ROOT/root/usr/libexec/raywrt-package-index-init"; then
  echo 'FAIL: package index initializer should report exhausted retries' >&2; exit 1
fi
[ "$(RAYWRT_CONFIG_DIR="$package_failure" uci -q get raywrt.system.package_indexes)" = failed ]
[ "$(cat "$TMP_ROOT/apk-count")" = 4 ]
[ "$(tr '\n' ' ' <"$TMP_ROOT/sleep-log")" = '30 60 120 ' ]
echo 'PASS: failed package initialization stops after 4 attempts and leaves manual retry state'

network_wait="$TMP_ROOT/network-wait"
mkdir -p "$network_wait"; : >"$network_wait/raywrt"
seed_json "$network_wait/.fixture-uci.json" '{"raywrt.system":"system","raywrt.system.package_indexes":"pending"}'
: >"$TMP_ROOT/apk-count"; : >"$TMP_ROOT/wget-count"; : >"$TMP_ROOT/sleep-log"; : >"$TMP_ROOT/service-log"
RAYWRT_CONFIG_DIR="$network_wait" RAYWRT_APK_REPOSITORIES="$TMP_ROOT/repositories.list" RAYWRT_PACKAGE_INIT_SERVICE="$TMP_ROOT/package-bin/service" \
  RAYWRT_TEST_APK_COUNT="$TMP_ROOT/apk-count" RAYWRT_TEST_SLEEP_LOG="$TMP_ROOT/sleep-log" \
  RAYWRT_TEST_WGET_COUNT="$TMP_ROOT/wget-count" RAYWRT_TEST_SERVICE_LOG="$TMP_ROOT/service-log" RAYWRT_TEST_WGET_FAIL_UNTIL=1 \
  PATH="$TMP_ROOT/package-bin:$PATH" sh "$PACKAGE_ROOT/root/usr/libexec/raywrt-package-index-init"
[ "$(RAYWRT_CONFIG_DIR="$network_wait" uci -q get raywrt.system.package_indexes)" = ready ]
[ "$(cat "$TMP_ROOT/wget-count")" = 2 ]
[ "$(cat "$TMP_ROOT/apk-count")" = 1 ]
[ "$(cat "$TMP_ROOT/sleep-log")" = 30 ]
echo 'PASS: first-boot index refresh waits for a reachable configured repository'

# Guard the UI/backend state contract against regression to a generic
# Unsupported state while the index marker says initializing.
grep -Fq 'tool_%s=checking' "$PACKAGE_ROOT/root/usr/libexec/raywrt-tools"
grep -Fq 'tool_passwall2=not_installed' "$PACKAGE_ROOT/root/usr/libexec/raywrt-tools"
grep -Fq 'tool_passwall2=install_failed' "$PACKAGE_ROOT/root/usr/libexec/raywrt-tools"
grep -Fq 'tool_%s=index_error' "$PACKAGE_ROOT/root/usr/libexec/raywrt-tools"
grep -Fq "install_passwall2) start_fixed_job passwall2 install" "$PACKAGE_ROOT/root/usr/libexec/raywrt-tools"
grep -Fq "not_installed:'Not installed'" "$PACKAGE_ROOT/htdocs/luci-static/resources/view/raywrt/tools-v3.js"
grep -Fq 'passwall_readiness_report' "$PACKAGE_ROOT/root/usr/libexec/raywrt-tools"
grep -Fq 'passwall_manager_route_ready' "$PACKAGE_ROOT/root/usr/libexec/raywrt-tools"
grep -Fq 'passwall_package_files luci-app-passwall2' "$PACKAGE_ROOT/root/usr/libexec/raywrt-tools"
grep -Fq 'luci.passwall2.api' "$PACKAGE_ROOT/root/usr/libexec/raywrt-tools"
grep -Fq 'passwall_service_ready' "$PACKAGE_ROOT/root/usr/libexec/raywrt-tools"
grep -Fq 'passwall_service_ready=%s' "$PACKAGE_ROOT/root/usr/libexec/raywrt-tools"
grep -Fq 'passwall_module_ready kmod-nft-tproxy nft_tproxy' "$PACKAGE_ROOT/root/usr/libexec/raywrt-tools"
grep -Fq 'xray_path=$(passwall_xray_path)' "$PACKAGE_ROOT/root/usr/libexec/raywrt-tools"
grep -Fq 'Configured: YES' "$PACKAGE_ROOT/root/usr/libexec/raywrt-tools"
grep -Fq 'Running: NO' "$PACKAGE_ROOT/root/usr/libexec/raywrt-tools"
if grep -Fq "[ -x /etc/init.d/passwall2 ]" "$PACKAGE_ROOT/root/usr/libexec/raywrt-tools"; then
  echo 'FAIL: Passwall installation must not require a hard-coded init script path' >&2; exit 1
fi
if grep -Fq "grep -q '^nft_tproxy ' /proc/modules" "$PACKAGE_ROOT/root/usr/libexec/raywrt-tools"; then
  echo 'FAIL: Passwall installation must not require nft_tproxy to be loaded' >&2; exit 1
fi
if grep -Fq 'Packages installed but Passwall 2 service, LuCI route, Xray or transparent proxy module is missing.' "$PACKAGE_ROOT/root/usr/libexec/raywrt-tools"; then
  echo 'FAIL: legacy generic Passwall readiness failure is still present' >&2; exit 1
fi
echo 'PASS: Tools distinguishes initializing indexes, absent packages, and supported Passwall install'

# Terminal startup must use BusyBox-compatible integer sleeps and wait for the
# actual listener, not only the ttyd process, before returning session details.
if grep -Eq '^[[:space:]]*sleep[[:space:]]+[0-9]+\.[0-9]+' "$PACKAGE_ROOT/root/usr/libexec/raywrt-terminal"; then
  echo 'FAIL: terminal helper contains an unsupported fractional sleep' >&2; exit 1
fi
grep -Fq 'listener_ready' "$PACKAGE_ROOT/root/usr/libexec/raywrt-terminal"
grep -Fq 'sleep 1' "$PACKAGE_ROOT/root/usr/libexec/raywrt-terminal"
echo 'PASS: terminal startup uses bounded BusyBox-compatible listener polling'

dns_fixture() {
  dir=$1
  json=$2
  mkdir -p "$dir"
  seed_json "$dir/.fixture-uci.json" "$json"
}

# Fresh DHCP WAN: exact DNS delta, with the separate WAN6 config unchanged.
fresh_dns="$TMP_ROOT/fresh-dns"
dns_fixture "$fresh_dns" '{
  "network.wan":"interface","network.wan.proto":"dhcp","network.wan.peerdns":"1",
  "network.wan6":"interface","network.wan6.proto":"dhcpv6","network.wan6.peerdns":"1",
  "raywrt.system":"system","raywrt.system.wifi_default":"applied","raywrt.system.dns_default":"pending"
}'
RAYWRT_CONFIG_DIR="$fresh_dns" sh "$PACKAGE_ROOT/root/usr/libexec/raywrt-first-run-dns"
[ "$(RAYWRT_CONFIG_DIR="$fresh_dns" uci -q get network.wan.peerdns)" = 0 ]
[ "$(RAYWRT_CONFIG_DIR="$fresh_dns" uci -q get network.wan.dns)" = "1.1.1.1 1.0.0.1" ]
[ "$(cat "$fresh_dns/.network-reloads")" = reload ]
[ "$(RAYWRT_CONFIG_DIR="$fresh_dns" uci -q get network.wan6.peerdns)" = 1 ]
[ "$(RAYWRT_CONFIG_DIR="$fresh_dns" uci -q get raywrt.system.dns_default)" = applied ]
RAYWRT_CONFIG_DIR="$fresh_dns" sh "$PACKAGE_ROOT/root/usr/libexec/raywrt-first-run-dns"
[ "$(RAYWRT_CONFIG_DIR="$fresh_dns" uci -q get network.wan.dns)" = "1.1.1.1 1.0.0.1" ]
[ "$(wc -l <"$fresh_dns/.network-reloads")" -eq 1 ]
echo 'PASS: first-run DHCP WAN DNS default, IPv6 separation, and idempotence'

# Old/custom installations have no pending marker and must never be rewritten.
legacy_dns="$TMP_ROOT/legacy-dns"
dns_fixture "$legacy_dns" '{
  "network.wan":"interface","network.wan.proto":"dhcp","network.wan.peerdns":"1",
  "network.wan.dns":["9.9.9.9"],"raywrt.system":"system"
}'
RAYWRT_CONFIG_DIR="$legacy_dns" sh "$PACKAGE_ROOT/root/usr/libexec/raywrt-first-run-dns"
[ "$(RAYWRT_CONFIG_DIR="$legacy_dns" uci -q get network.wan.dns)" = 9.9.9.9 ]
[ "$(RAYWRT_CONFIG_DIR="$legacy_dns" uci -q get network.wan.peerdns)" = 1 ]
echo 'PASS: legacy RayWRT config without the marker is unchanged'

custom_dns="$TMP_ROOT/custom-dns"
dns_fixture "$custom_dns" '{
  "network.wan":"interface","network.wan.proto":"dhcp","network.wan.peerdns":"0",
  "network.wan.dns":["9.9.9.9"],"raywrt.system":"system","raywrt.system.wifi_default":"applied","raywrt.system.dns_default":"pending"
}'
RAYWRT_CONFIG_DIR="$custom_dns" sh "$PACKAGE_ROOT/root/usr/libexec/raywrt-first-run-dns"
[ "$(RAYWRT_CONFIG_DIR="$custom_dns" uci -q get network.wan.dns)" = 9.9.9.9 ]
[ "$(RAYWRT_CONFIG_DIR="$custom_dns" uci -q get raywrt.system.dns_default)" = preserved ]
echo 'PASS: explicitly configured DNS is preserved'

custom_wifi_dns="$TMP_ROOT/custom-wifi-dns"
dns_fixture "$custom_wifi_dns" '{
  "network.wan":"interface","network.wan.proto":"dhcp","network.wan.peerdns":"1",
  "raywrt.system":"system","raywrt.system.wifi_default":"preserved",
  "raywrt.system.dns_default":"pending"
}'
RAYWRT_CONFIG_DIR="$custom_wifi_dns" sh "$PACKAGE_ROOT/root/usr/libexec/raywrt-first-run-dns"
[ "$(RAYWRT_CONFIG_DIR="$custom_wifi_dns" uci -q get network.wan.peerdns)" = 1 ]
[ "$(RAYWRT_CONFIG_DIR="$custom_wifi_dns" uci -q get raywrt.system.dns_default)" = preserved ]
echo 'PASS: customized Wi-Fi installation preserves DHCP peer DNS'

non_dhcp="$TMP_ROOT/non-dhcp"
dns_fixture "$non_dhcp" '{
  "network.wan":"interface","network.wan.proto":"pppoe","raywrt.system":"system",
  "raywrt.system.wifi_default":"applied","raywrt.system.dns_default":"pending"
}'
RAYWRT_CONFIG_DIR="$non_dhcp" sh "$PACKAGE_ROOT/root/usr/libexec/raywrt-first-run-dns"
[ "$(RAYWRT_CONFIG_DIR="$non_dhcp" uci -q get raywrt.system.dns_default)" = preserved ]
[ "$(RAYWRT_CONFIG_DIR="$non_dhcp" uci -q get network.wan.peerdns 2>/dev/null || true)" = '' ]
echo 'PASS: non-DHCP WAN is preserved'

# The Gale image must ship LuCI's WireGuard protocol plugin as well as its
# userspace and kernel support, otherwise Add New Interface omits WireGuard.
if [ -f "$SOURCE_ROOT/config/gale.config.fragment" ]; then
	GALE_CONFIG="$SOURCE_ROOT/config/gale.config.fragment"
else
	GALE_CONFIG="$SOURCE_ROOT/release/raywrt-1.0.0-gale/config/gale.config.fragment"
fi
for package in luci-proto-wireguard wireguard-tools kmod-wireguard; do
	grep -Fqx "CONFIG_PACKAGE_${package}=y" "$GALE_CONFIG"
done
echo 'PASS: Gale image selects LuCI, userspace, and kernel WireGuard support'
