#!/bin/sh
set -eu

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
build_root=${1:?Usage: verify-raywrt-image.sh OPENWRT_BUILD_DIR IMAGE [BUNDLE_DIR]}
image=${2:?Usage: verify-raywrt-image.sh OPENWRT_BUILD_DIR IMAGE [BUNDLE_DIR]}
bundle=${3:-$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)}
. "$bundle/pins/openwrt.env"

python3 - "$bundle/release-manifest.json" "$RAYWRT_VERSION" "$OPENWRT_RELEASE" "$OPENWRT_SUPPORTED_DEVICE" "$RAYWRT_IMAGE_FILENAME" <<'PY'
import json, sys
from pathlib import Path
m = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
assert m["raywrt_version"] == sys.argv[2], m
assert m["openwrt_version"] == sys.argv[3], m
assert m["supported_device"] == sys.argv[4], m
assert m["image_filename"] == sys.argv[5], m
PY

[ -s "$image" ] || fail "Image is missing or empty: $image"
[ "$(basename -- "$image")" = "$RAYWRT_IMAGE_FILENAME" ] || fail "Expected public image filename $RAYWRT_IMAGE_FILENAME."

rootfs=$(find "$build_root/build_dir" -type d -name root-ipq40xx -print -quit)
[ -n "$rootfs" ] || fail 'Could not find the built ipq40xx root filesystem staging directory.'
grep -Fqx 'CONFIG_PACKAGE_ip-full=y' "$build_root/.config" || fail 'Image configuration lacks ip-full.'
if grep -Fqx 'CONFIG_PACKAGE_ip-tiny=y' "$build_root/.config"; then fail 'Image configuration selects conflicting ip-tiny.'; fi
grep -Fqx 'P:ip-full' "$rootfs/lib/apk/db/installed" || fail 'Built rootfs lacks ip-full.'
if grep -Fqx 'P:ip-tiny' "$rootfs/lib/apk/db/installed"; then fail 'Built rootfs contains conflicting ip-tiny.'; fi
printf 'IP PROVIDER PASS: ip-full installed; ip-tiny absent\n'
required_files='
etc/uci-defaults/30_luci-theme-raywrt
etc/config/raywrt
usr/libexec/raywrt-first-run-wifi
usr/libexec/raywrt-first-run-wifi-service
usr/libexec/raywrt-first-run-dns
usr/libexec/raywrt-tools
usr/libexec/raywrt-diagnostics
usr/libexec/raywrt-usage
usr/libexec/raywrt-usage-control
usr/libexec/raywrt-device-usage
usr/libexec/raywrt-device-usage-control
usr/libexec/raywrt-terminal
usr/libexec/raywrt-terminal-shell
usr/libexec/raywrt-wireguard-split
etc/init.d/raywrt-usage
etc/init.d/raywrt-device-usage
etc/init.d/raywrt-wireguard-split
etc/init.d/raywrt-package-index-init
etc/init.d/raywrt-first-run-wifi
usr/libexec/raywrt-package-index-init
usr/share/ucode/luci/template/themes/raywrt/header.ut
usr/share/ucode/luci/template/themes/raywrt/footer.ut
usr/share/rpcd/acl.d/luci-theme-raywrt.json
usr/share/luci/menu.d/luci-theme-raywrt.json
www/luci-static/raywrt/raywrt.css
www/luci-static/raywrt/base.css
www/luci-static/raywrt/logo.svg
www/luci-static/resources/view/raywrt/dashboard.js
www/luci-static/resources/menu-raywrt-v5.js
www/luci-static/resources/view/raywrt/tools-v3.js
www/luci-static/resources/view/raywrt/usage.js
www/luci-static/resources/view/raywrt/passwall2.js
www/luci-static/resources/view/raywrt/wireguard.js
www/luci-static/resources/view/raywrt/terminal.js
' 
printf '%s\n' "$required_files" | sed '/^$/d' | while IFS= read -r rel; do
	[ -s "$rootfs/$rel" ] || { echo "FAIL: missing image file $rel" >&2; exit 1; }
done

# Compare the final target-root filesystem staging tree against the frozen
# package inputs. Presence-only checks let mixed or stale package assets pass.
check_critical_hash() {
	rel=$1
	package_source=$2
	transform=${3:-copy}
	expected="$bundle/package/luci-theme-raywrt/$package_source"
	actual="$rootfs/$rel"
	[ -s "$expected" ] || fail "Critical source file is missing: $package_source"
	[ -s "$actual" ] || fail "Critical rootfs file is missing: $rel"
	processed=$(mktemp "${TMPDIR:-/tmp}/raywrt-verify.XXXXXX")
	case "$transform" in
		copy) cp "$expected" "$processed" ;;
		jsmin)
			jsmin="$build_root/staging_dir/hostpkg/bin/jsmin"
			[ -x "$jsmin" ] || fail 'Pinned LuCI JavaScript minifier is missing.'
			"$jsmin" <"$expected" >"$processed"
			;;
		csstidy)
			csstidy="$build_root/staging_dir/hostpkg/bin/csstidy"
			[ -x "$csstidy" ] || fail 'Pinned LuCI CSS processor is missing.'
			"$csstidy" "$expected" --template=highest --remove_last_semicolon=true "$processed" >/dev/null 2>&1
			;;
		*) fail "Unknown critical payload transform: $transform" ;;
	esac
	expected_hash=$(sha256sum "$processed" | awk '{print $1}')
	actual_hash=$(sha256sum "$actual" | awk '{print $1}')
	rm -f "$processed"
	[ "$expected_hash" = "$actual_hash" ] || fail "Stale or modified rootfs payload: $rel (expected $expected_hash, got $actual_hash)"
	source_hash=$(sha256sum "$expected" | awk '{print $1}')
	printf 'ROOTFS HASH PASS: %s source=%s packaged=%s\n' "$rel" "$source_hash" "$actual_hash"
}
check_critical_hash usr/share/luci/menu.d/luci-theme-raywrt.json root/usr/share/luci/menu.d/luci-theme-raywrt.json
check_critical_hash usr/share/ucode/luci/template/themes/raywrt/footer.ut ucode/template/themes/raywrt/footer.ut
check_critical_hash usr/libexec/raywrt-tools root/usr/libexec/raywrt-tools
grep -Fq "apk_add_full_ip luci-app-passwall2" "$rootfs/usr/libexec/raywrt-tools" || fail 'Atomic Passwall provider replacement is missing.'
grep -Fq 'openvpn_manager_route' "$rootfs/usr/libexec/raywrt-tools" || fail 'Native OpenVPN route detection is missing.'
check_critical_hash www/luci-static/resources/view/raywrt/tools.js htdocs/luci-static/resources/view/raywrt/tools.js jsmin
check_critical_hash www/luci-static/resources/view/raywrt/tools-v3.js htdocs/luci-static/resources/view/raywrt/tools-v3.js jsmin
check_critical_hash www/luci-static/resources/view/raywrt/passwall2.js htdocs/luci-static/resources/view/raywrt/passwall2.js jsmin
check_critical_hash usr/libexec/raywrt-terminal root/usr/libexec/raywrt-terminal
check_critical_hash usr/libexec/raywrt-wireguard-split root/usr/libexec/raywrt-wireguard-split
check_critical_hash usr/share/raywrt/licenses/iran-ip-ranges-MIT.txt root/usr/share/raywrt/licenses/iran-ip-ranges-MIT.txt
grep -Fqx 'SOURCE=https://raw.githubusercontent.com/farshidmousavii/iran-ip-ranges/main/dist/raw/ipv4.txt' "$rootfs/usr/libexec/raywrt-wireguard-split" || fail 'Iran IP database source mismatch.'
check_critical_hash www/luci-static/resources/view/raywrt/wireguard.js htdocs/luci-static/resources/view/raywrt/wireguard.js jsmin
check_critical_hash www/luci-static/raywrt/raywrt.css htdocs/luci-static/raywrt/raywrt.css csstidy
grep -Fq 'ensure_wg_default_route "$wg"' "$rootfs/usr/libexec/raywrt-wireguard-split" || fail 'WireGuard default-route preparation is missing.'
grep -Fq 'restore_wg_default_route' "$rootfs/usr/libexec/raywrt-wireguard-split" || fail 'WireGuard default-route rollback is missing.'

grep -Fqx "PKG_VERSION:=$RAYWRT_VERSION" "$bundle/package/luci-theme-raywrt/Makefile" || fail 'Bundle package version mismatch.'
grep -Fq "RayWRT $RAYWRT_VERSION" "$rootfs/usr/share/ucode/luci/template/themes/raywrt/header.ut" || fail 'Header version mismatch.'
grep -Fq "RayWRT $RAYWRT_VERSION" "$rootfs/usr/share/ucode/luci/template/themes/raywrt/footer.ut" || fail 'Footer version mismatch.'
grep -Fq "RayWRT $RAYWRT_VERSION" "$rootfs/usr/libexec/raywrt-terminal-shell" || fail 'Terminal version mismatch.'
grep -Fq "option dns_default 'pending'" "$rootfs/etc/config/raywrt" || fail 'Fresh-install DNS marker is missing.'
grep -Fq "option theme_default 'pending'" "$rootfs/etc/config/raywrt" || fail 'Fresh-install theme marker is missing.'
grep -Fq "option package_indexes 'pending'" "$rootfs/etc/config/raywrt" || fail 'Fresh-install package index marker is missing.'
grep -Fq 'mediaurlbase=/luci-static/raywrt' "$rootfs/etc/uci-defaults/30_luci-theme-raywrt" || fail 'Fresh-install theme activation is missing.'
grep -Fq 'theme_default=applied' "$rootfs/etc/uci-defaults/30_luci-theme-raywrt" || fail 'Theme selection is not guarded by a one-time marker.'
grep -Fq "network.wan.peerdns" "$rootfs/usr/libexec/raywrt-first-run-dns" || fail 'DNS provisioning logic missing.'
grep -Fq 'wifi_default' "$rootfs/usr/libexec/raywrt-first-run-dns" || fail 'DNS provisioning is not gated on stock Wi-Fi first-run detection.'
grep -Fq '1.1.1.1' "$rootfs/usr/libexec/raywrt-first-run-dns" || fail 'Primary DNS default missing.'
grep -Fq '1.0.0.1' "$rootfs/usr/libexec/raywrt-first-run-dns" || fail 'Secondary DNS default missing.'
grep -Fq 'RayWRT' "$rootfs/usr/libexec/raywrt-first-run-wifi" || fail 'First-run Wi-Fi default missing.'
grep -Fq 'wireless.$radio.disabled=0' "$rootfs/usr/libexec/raywrt-first-run-wifi" || fail 'Fresh-install radio enablement is missing.'
grep -Fq 'wireless.$section.disabled=0' "$rootfs/usr/libexec/raywrt-first-run-wifi" || fail 'Fresh-install AP enablement is missing.'
grep -Fq 'wireless.$section.network=lan' "$rootfs/usr/libexec/raywrt-first-run-wifi" || fail 'Fresh-install AP LAN assignment is missing.'
grep -Fq 'verify_provisioning' "$rootfs/usr/libexec/raywrt-first-run-wifi" || fail 'Wi-Fi completion marker is not gated on verification.'
grep -Fq 'raywrt-first-run-wifi enable' "$rootfs/etc/uci-defaults/30_luci-theme-raywrt" || fail 'Delayed first-run Wi-Fi service is not enabled.'
grep -Fq 'raywrt-first-run-wifi start' "$rootfs/etc/uci-defaults/30_luci-theme-raywrt" || fail 'Delayed Wi-Fi worker is not started after first-run defaults.'
grep -Fq 'raywrt-first-run-wifi --wait' "$rootfs/usr/libexec/raywrt-first-run-wifi-service" || fail 'Delayed first-run Wi-Fi retry runner is missing.'
grep -Fq 'raywrt-first-run-dns' "$rootfs/usr/libexec/raywrt-first-run-wifi-service" || fail 'First-run DNS is not sequenced after Wi-Fi provisioning.'
grep -Fq 'for delay in 30 60 120' "$rootfs/usr/libexec/raywrt-package-index-init" || fail 'Bounded package index retry policy is missing.'
grep -Fq 'apk --timeout 20 update' "$rootfs/usr/libexec/raywrt-package-index-init" || fail 'APK first-boot index refresh is missing.'
grep -Fq 'repository_ready' "$rootfs/usr/libexec/raywrt-package-index-init" || fail 'First-boot repository connectivity gate is missing.'
grep -Fq 'tool_passwall2=not_installed' "$rootfs/usr/libexec/raywrt-tools" || fail 'Passwall fixed-installer state is missing.'
grep -Fq 'install_passwall2) start_fixed_job passwall2 install' "$rootfs/usr/libexec/raywrt-tools" || fail 'Fixed Passwall installer action is missing.'
grep -Fq "tool_%s=checking" "$rootfs/usr/libexec/raywrt-tools" || fail 'Tools package-index initialization state is missing.'
grep -Fq "not_installed:'Not installed'" "$rootfs/www/luci-static/resources/view/raywrt/tools-v3.js" || fail 'Tools Passwall state label is missing.'
grep -Fq 'System running in recovery' "$rootfs/usr/share/ucode/luci/template/themes/raywrt/header.ut" || fail 'Recovery warning is missing from the RayWRT header.'
if grep -Fqi 'No password set' "$rootfs/usr/share/ucode/luci/template/themes/raywrt/header.ut"; then
	fail 'The stock no-password banner must not be added to the RayWRT header.'
fi

acl="$rootfs/usr/share/rpcd/acl.d/luci-theme-raywrt.json"
python3 - "$acl" <<'PY'
import json, sys
acl = json.load(open(sys.argv[1], encoding="utf-8"))["luci-theme-raywrt"]
write = acl["write"]["file"]
assert "/usr/libexec/raywrt-terminal start" in write
assert "/usr/libexec/raywrt-tools start *" in write
assert "/usr/libexec/raywrt-wireguard-split configure *" in write
assert not any(k in write for k in ("/usr/libexec/raywrt-terminal *", "/usr/libexec/raywrt-tools *", "/bin/sh *", "/usr/bin/ttyd *"))
PY

apkdb="$rootfs/lib/apk/db/installed"
[ -s "$apkdb" ] || fail 'APK installed-package database missing.'
grep -Fqx 'P:luci-theme-raywrt' "$apkdb" || fail 'RayWRT package absent from APK database.'
for package in luci-proto-wireguard wireguard-tools kmod-wireguard; do
	grep -Fqx "P:${package}" "$apkdb" || fail "WireGuard support package ${package} missing from APK database."
done
version_regex=$(printf '%s' "$RAYWRT_VERSION" | sed 's/[.]/\\./g')
grep -Eq "^V:${version_regex}(-r[0-9]+)?$" "$apkdb" || fail "APK database does not identify RayWRT $RAYWRT_VERSION."

if grep -RIl --exclude='terminal-vendor*' --exclude='*.map' '1\.5\.0' \
	"$rootfs/www/luci-static/raywrt" "$rootfs/www/luci-static/resources/view/raywrt" \
	"$rootfs/usr/libexec/raywrt-"* 2>/dev/null | grep -q .; then
	fail 'Stale 1.5.0 runtime string found in RayWRT files.'
fi
if grep -RInE --exclude='terminal-vendor*' --exclude='*.map' \
	'console\.(log|debug)|debugger;|TODO|FIXME|DEBUG' \
	"$rootfs/www/luci-static/resources/view/raywrt" "$rootfs/usr/libexec/raywrt-"* 2>/dev/null; then
	fail 'Debug marker found in first-party runtime assets.'
fi

metadata_tool="$build_root/staging_dir/host/bin/fwtool"
[ -x "$metadata_tool" ] || fail 'fwtool is missing from the OpenWrt build host tools.'
"$metadata_tool" -i "$image.metadata.json" "$image"
python3 - "$image.metadata.json" "$OPENWRT_BUILD_REVISION" <<'PY'
import json, sys
m = json.load(open(sys.argv[1], encoding="utf-8"))
v = m.get("version", {})
devices = m.get("new_supported_devices") or m.get("supported_devices", [])
assert any(d == "google,wifi" or d.startswith("google,wifi - ") for d in devices), m
assert v.get("target") == "ipq40xx/chromium", v
assert v.get("version") == "25.12.5", v
assert v.get("revision") == sys.argv[2], v
print("METADATA:", json.dumps({"target": v.get("target"), "version": v.get("version"), "revision": v.get("revision"), "supported_devices": devices, "compat_message": m.get("compat_message")}, sort_keys=True))
PY

(cd "$(dirname -- "$image")" && sha256sum "$(basename -- "$image")" >"$(basename -- "$image").sha256")
(cd "$(dirname -- "$image")" && sha256sum -c "$(basename -- "$image").sha256")
image_sha256=$(sha256sum "$image" | awk '{print $1}')
python3 - "$image" "$image.metadata.json" "$image_sha256" "$RAYWRT_VERSION" "$OPENWRT_RELEASE" "$OPENWRT_BUILD_REVISION" "$OPENWRT_TARGET" "$OPENWRT_PROFILE" "$OPENWRT_SUPPORTED_DEVICE" <<'PY'
import json, sys
from pathlib import Path
image, metadata, digest, raywrt, release, revision, target, profile, device = sys.argv[1:]
fw = json.loads(Path(metadata).read_text(encoding="utf-8"))
result = {
    "raywrt_version": raywrt,
    "openwrt_version": release,
    "openwrt_revision": revision,
    "target": target,
    "profile": profile,
    "supported_device": device,
    "image": Path(image).name,
    "sha256": digest,
    "image_validation": "build_artifact_verified",
    "clean_sysupgrade_validation": "pending",
    "public_release_status": "not_yet_validated",
    "image_metadata": fw.get("version", {}),
}
Path(image + ".raywrt.json").write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
printf 'BUILD: PASS\nIMAGE: %s\nSIZE: %s bytes\nSHA256: ' "$image" "$(wc -c <"$image" | tr -d ' ')"
sha256sum "$image" | awk '{print $1}'
printf 'PACKAGE: RayWRT %s\nFIRST-RUN DNS/WI-FI, ACL, dashboard, Tools, usage, Passwall, WireGuard and Terminal files: PASS\nDEBUG ARTIFACTS: NONE\n' "$RAYWRT_VERSION"
printf 'RAYWRT METADATA: %s\n' "$image.raywrt.json"
