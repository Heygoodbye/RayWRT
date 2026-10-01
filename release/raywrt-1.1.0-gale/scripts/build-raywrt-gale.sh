#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
. "$SCRIPT_DIR/pins/openwrt.env"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
sh "$SCRIPT_DIR/scripts/check-build-host.sh" "${BUILD_ROOT:-$HOME}"

source_manifest="$SCRIPT_DIR/SOURCE-MANIFEST.sha256"
[ -s "$source_manifest" ] || fail 'Source hash manifest is missing.'
(cd "$SCRIPT_DIR/package/luci-theme-raywrt" && sha256sum -c "$source_manifest")
grep -Fqx "PKG_VERSION:=$RAYWRT_VERSION" "$SCRIPT_DIR/package/luci-theme-raywrt/Makefile" || fail "Bundle package version is not $RAYWRT_VERSION."
python3 - "$SCRIPT_DIR/release-manifest.json" "$RAYWRT_VERSION" "$OPENWRT_RELEASE" "$OPENWRT_SUPPORTED_DEVICE" "$RAYWRT_IMAGE_FILENAME" <<'PY'
import json, sys
from pathlib import Path
m = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
assert m["raywrt_version"] == sys.argv[2], m
assert m["openwrt_version"] == sys.argv[3], m
assert m["supported_device"] == sys.argv[4], m
assert m["image_filename"] == sys.argv[5], m
assert m["image_validation"] in ("pending", "build_artifact_verified"), m
print("PASS: public release manifest matches build pins")
PY

build_parent=${BUILD_ROOT:-"$HOME/openwrt-builds"}
mkdir -p "$build_parent"
if [ -n "${RAYWRT_OPENWRT_DIR:-}" ]; then
	openwrt=$(CDPATH= cd -- "$RAYWRT_OPENWRT_DIR" && pwd)
	work=$(dirname -- "$openwrt")
	artifacts="$work/raywrt-${RAYWRT_VERSION}-verified-$(date -u +%Y%m%dT%H%M%SZ)"
	mkdir -p "$artifacts"
	reuse_build=yes
else
	work="$build_parent/raywrt-${RAYWRT_VERSION}-${OPENWRT_RELEASE}-${OPENWRT_PROFILE}-$(date -u +%Y%m%dT%H%M%SZ)"
	mkdir "$work"
	openwrt="$work/openwrt"
	artifacts="$work/artifacts"
	mkdir -p "$artifacts"
	reuse_build=no

	git init "$openwrt"
	git -C "$openwrt" remote add origin https://github.com/openwrt/openwrt.git
	git -C "$openwrt" fetch --depth=1 origin "$OPENWRT_GIT_COMMIT"
	git -C "$openwrt" checkout --detach FETCH_HEAD
fi
[ "$(git -C "$openwrt" rev-parse HEAD)" = "$OPENWRT_GIT_COMMIT" ] || fail 'OpenWrt source commit does not match the pin.'

if [ "$reuse_build" = no ]; then cat >"$openwrt/feeds.conf" <<EOF
src-git packages https://git.openwrt.org/feed/packages.git^$FEED_PACKAGES_REVISION
src-git luci https://git.openwrt.org/project/luci.git^$FEED_LUCI_REVISION
src-git routing https://git.openwrt.org/feed/routing.git^$FEED_ROUTING_REVISION
src-git telephony https://git.openwrt.org/feed/telephony.git^$FEED_TELEPHONY_REVISION
src-git video https://github.com/openwrt/video.git^$FEED_VIDEO_REVISION
EOF
fi

if [ "$reuse_build" = no ]; then (cd "$openwrt" && ./scripts/feeds update -a); fi

check_feed() {
	feed=$1 expected=$2
	actual=$(git -C "$openwrt/feeds/$feed" rev-parse HEAD)
	[ "$actual" = "$expected" ] || fail "$feed feed resolved to $actual, expected $expected"
}
check_feed packages "$FEED_PACKAGES_REVISION"
check_feed luci "$FEED_LUCI_REVISION"
check_feed routing "$FEED_ROUTING_REVISION"
check_feed telephony "$FEED_TELEPHONY_REVISION"
check_feed video "$FEED_VIDEO_REVISION"

# Install normal packages only for a new checkout. Reused trees must match all
# feed pins below and already contain their pinned feed links.
if [ "$reuse_build" = no ]; then (cd "$openwrt" && ./scripts/feeds install -a); fi

package_dir="$SCRIPT_DIR/package/luci-theme-raywrt"
raywrt_package="$openwrt/package/luci-theme-raywrt"
# A previous local-package injection can leave a second, untracked RayWRT
# package under a feed. OpenWrt may select that copy instead of this frozen
# bundle. Remove only untracked duplicates; fail rather than altering any
# package that belongs to a pinned feed revision.
for candidate in "$openwrt"/feeds/*/luci-theme-raywrt; do
	[ -d "$candidate" ] || continue
	feed_root=${candidate%/luci-theme-raywrt}
	if git -C "$feed_root" ls-files --error-unmatch luci-theme-raywrt/Makefile >/dev/null 2>&1; then
		fail "Pinned feed already contains luci-theme-raywrt at $candidate; refusing ambiguous package selection."
	fi
	rm -rf "$candidate"
	printf 'Removed untracked duplicate RayWRT package: %s\n' "$candidate"
done
rm -rf "$raywrt_package"
mkdir -p "$raywrt_package"
cp -a "$package_dir/." "$raywrt_package/"
(cd "$raywrt_package" && sha256sum -c "$source_manifest")
chmod 755 "$raywrt_package/root/usr/libexec/"* \
	"$raywrt_package/root/etc/init.d/"* \
	"$raywrt_package/root/etc/uci-defaults/"*

if [ "$reuse_build" = no ]; then
	base="https://downloads.openwrt.org/releases/$OPENWRT_RELEASE/targets/$OPENWRT_TARGET"
	curl -fsSLo "$work/config.buildinfo" "$base/config.buildinfo"
	cp "$work/config.buildinfo" "$openwrt/.config"
else
	[ -s "$openwrt/.config" ] || fail 'Reused OpenWrt tree has no saved configuration.'
fi
python3 - "$openwrt/.config" "$SCRIPT_DIR/config/gale.config.fragment" <<'PY'
import re, sys
from pathlib import Path
config, fragment = map(Path, sys.argv[1:])
lines = fragment.read_text().splitlines()
symbol = re.compile(r'^(?:# )?(CONFIG_[A-Za-z0-9_-]+)(?:=| is not set)')
keys = {m.group(1) for line in lines if (m := symbol.match(line))}
kept = [line for line in config.read_text().splitlines()
        if not ((m := symbol.match(line)) and m.group(1) in keys)]
config.write_text('\n'.join(kept + lines) + '\n')
PY
(cd "$openwrt" && make defconfig)

# Fail before the expensive toolchain build if the pinned source tree does not
# identify itself as the requested OpenWrt release. This catches snapshot
# commits that can still consume the release's config.buildinfo.
python3 - "$openwrt/include/version.mk" "$openwrt/.config" "$OPENWRT_RELEASE" "$OPENWRT_BUILD_REVISION" <<'PY'
import re, sys
from pathlib import Path
version_file, config_file, expected_version, expected_revision = sys.argv[1:]
version_text = Path(version_file).read_text(encoding="utf-8")
config_text = Path(config_file).read_text(encoding="utf-8")
version_match = re.search(
    r"^VERSION_NUMBER:=\$\(if \$\(VERSION_NUMBER\),\$\(VERSION_NUMBER\),([^)]+)\)[ \t]*$",
    version_text,
    re.MULTILINE,
)
revision_match = re.search(
    r"^VERSION_CODE:=\$\(if \$\(VERSION_CODE\),\$\(VERSION_CODE\),([^)]+)\)[ \t]*$",
    version_text,
    re.MULTILINE,
)
assert version_match and revision_match, f"Cannot read version defaults from {version_file}"
configured_version = re.search(r'^CONFIG_VERSION_NUMBER="(.*)"$', config_text, re.MULTILINE)
configured_revision = re.search(r'^CONFIG_VERSION_CODE="(.*)"$', config_text, re.MULTILINE)
actual_version = configured_version.group(1) if configured_version and configured_version.group(1) else version_match.group(1)
actual_revision = configured_revision.group(1) if configured_revision and configured_revision.group(1) else revision_match.group(1)
assert actual_version == expected_version, f"OpenWrt source/config version is {actual_version}, expected {expected_version}"
assert actual_revision == expected_revision, f"OpenWrt source/config revision is {actual_revision}, expected {expected_revision}"
print(f"PASS: OpenWrt source version {actual_version}, revision {actual_revision}")
PY

grep -Fqx 'CONFIG_TARGET_ipq40xx=y' "$openwrt/.config" || fail 'Wrong target system.'
grep -Fqx 'CONFIG_TARGET_ipq40xx_chromium=y' "$openwrt/.config" || fail 'Wrong target subtarget.'
grep -Fqx 'CONFIG_TARGET_DEVICE_ipq40xx_chromium_DEVICE_google_wifi=y' "$openwrt/.config" || fail 'Wrong device profile.'
grep -Fqx 'CONFIG_PACKAGE_luci-theme-raywrt=y' "$openwrt/.config" || fail 'RayWRT is not selected in the image.'
grep -Fqx 'CONFIG_PACKAGE_luci-theme-bootstrap=y' "$openwrt/.config" || fail 'Bootstrap fallback theme is not selected.'
for package in luci-proto-wireguard wireguard-tools kmod-wireguard; do
grep -Fqx "CONFIG_PACKAGE_${package}=y" "$openwrt/.config" || fail "WireGuard support package ${package} is not selected in the image."
done
grep -Fqx 'CONFIG_PACKAGE_ip-full=y' "$openwrt/.config" || fail 'Full ip provider is not selected.'
if grep -Fqx 'CONFIG_PACKAGE_ip-tiny=y' "$openwrt/.config"; then fail 'Conflicting tiny ip provider remains selected.'; fi
printf 'PASS: exact profile %s / %s / %s\n' "$OPENWRT_TARGET" "$OPENWRT_PROFILE" "$OPENWRT_SUPPORTED_DEVICE"

# Invalidate only RayWRT build outputs. Keep the pinned toolchain, feeds,
# downloads, and unrelated package build caches available for incremental use.
(cd "$openwrt" && make package/luci-theme-raywrt/clean)
rm -f "$openwrt/bin/packages/$OPENWRT_ARCH/base/"luci-theme-raywrt-*.apk \
	"$openwrt/bin/packages/$OPENWRT_ARCH/base/"luci-theme-raywrt-*.ipk
for rootfs in "$openwrt"/staging_dir/target-*/root-ipq40xx "$openwrt"/build_dir/target-*/root-ipq40xx; do
	[ -d "$rootfs" ] || continue
	find "$raywrt_package/root" "$raywrt_package/htdocs" "$raywrt_package/ucode" -type f -print |
	while IFS= read -r source_file; do
		case "$source_file" in
			"$raywrt_package/root/"*) rel=${source_file#"$raywrt_package/root/"} ;;
			"$raywrt_package/htdocs/"*) rel="www/${source_file#"$raywrt_package/htdocs/"}" ;;
			"$raywrt_package/ucode/"*) rel="usr/share/${source_file#"$raywrt_package/ucode/"}" ;;
			*) fail "Unexpected RayWRT package path: $source_file" ;;
		esac
		rm -f "$rootfs/$rel"
	done
done

(cd "$openwrt" && make -j"$(nproc)" download && make -j"$(nproc)" world)

find "$openwrt/bin/targets/ipq40xx/chromium" -maxdepth 1 -type f \
	-name "openwrt-${OPENWRT_RELEASE}-*-${OPENWRT_PROFILE}-squashfs-sysupgrade.bin" \
	-print -quit >"$work/image.path"
[ -s "$work/image.path" ] || fail 'Expected Google WiFi sysupgrade image was not produced.'
image=$(cat "$work/image.path")
public_image="$artifacts/$RAYWRT_IMAGE_FILENAME"
cp "$image" "$public_image"
sh "$SCRIPT_DIR/scripts/verify-raywrt-image.sh" "$openwrt" "$public_image" "$SCRIPT_DIR" >"$artifacts/build-summary.txt"
sh "$SCRIPT_DIR/scripts/verify-raywrt-payload.sh" "$openwrt" "$public_image" >>"$artifacts/build-summary.txt"
cat "$artifacts/build-summary.txt"
cp "$openwrt/.config" "$artifacts/openwrt.config"
git -C "$openwrt" rev-parse HEAD >"$artifacts/openwrt-commit.txt"
for feed in packages luci routing telephony video; do
	printf '%s ' "$feed" >>"$artifacts/feed-revisions.txt"
	git -C "$openwrt/feeds/$feed" rev-parse HEAD >>"$artifacts/feed-revisions.txt"
done
printf 'Artifacts: %s\n' "$artifacts"
