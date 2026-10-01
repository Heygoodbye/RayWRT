#!/bin/sh
set -eu
build=${1:?build directory}; image=${2:?image}
rootfs=$(find "$build/build_dir" -type d -name root-ipq40xx -print -quit)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
python3 - "$image" "$work/rootfs.squashfs" <<'PYTHON'
import sys,tarfile
with tarfile.open(sys.argv[1]) as tar:
    roots=[m for m in tar.getmembers() if m.name.endswith('/root') and m.isfile()]
    assert len(roots)==1, roots
    with open(sys.argv[2],'wb') as out: out.write(tar.extractfile(roots[0]).read())
PYTHON
"$build/staging_dir/host/bin/unsquashfs4" -no-progress -d "$work/root" "$work/rootfs.squashfs" etc usr/libexec usr/share www lib/upgrade >/dev/null
for file in usr/libexec/raywrt-tools usr/libexec/raywrt-usage-control usr/libexec/raywrt-device-usage-control lib/upgrade/keep.d/raywrt usr/share/rpcd/acl.d/luci-theme-raywrt.json usr/share/ucode/luci/template/themes/raywrt/header.ut usr/share/ucode/luci/template/themes/raywrt/footer.ut www/luci-static/resources/view/raywrt/dashboard.js www/luci-static/resources/view/raywrt/tools-v3.js www/luci-static/raywrt/raywrt.css; do
    cmp "$rootfs/$file" "$work/root/$file"
done
if grep -E 'Meli|private_key|preshared_key|wg_import' "$work/root/etc/config/network" "$work/root/etc/config/wireless" 2>/dev/null; then
    echo 'FAIL: personal VPN configuration found' >&2; exit 1
fi
printf 'PASS: actual sysupgrade squashfs matches verified critical files; no personal VPN configuration in network/wireless defaults\n'
