# RayWRT 1.1.0 Gale Linux build

This bundle builds one OpenWrt 25.12.5 sysupgrade image for Google WiFi (Gale), with the frozen RayWRT 1.1.0 source package. It does not flash a router.

## Pinned inputs

See `pins/openwrt.env` for the exact OpenWrt source commit, Gale target/profile, architecture, and all five feed revisions. The build script rejects revision mismatches and uses the official 25.12.5 `config.buildinfo` for the `ipq40xx/chromium` target. The config fragment selects only the Google WiFi `google_wifi` profile and RayWRT packages, avoiding duplicate target-choice assignments. It also selects `luci-proto-wireguard`, `wireguard-tools` and `kmod-wireguard`, so LuCI offers WireGuard when adding an interface and the image includes its runtime support. It never checks out a moving branch.

## Ubuntu 24.04 dependencies

On a Linux x86_64 host with at least 40 GiB free disk and 8 GiB RAM:

```sh
sudo apt update
sudo apt install -y \
  build-essential clang flex bison g++ gawk gcc-multilib g++-multilib \
  gettext git libncurses-dev libssl-dev python3-dev python3-setuptools \
  rsync subversion swig unzip zlib1g-dev file wget bc libelf-dev \
  liblzma-dev libxml-parser-perl xsltproc zstd curl
```

Keep the bundle and build tree in the Linux filesystem, such as `~/src`, rather than `/mnt/c`. The host-check script confirms Linux x86_64, RAM, free space, build tools, and the listed Ubuntu dependencies.

## Build

Extract the bundle under `~/src/raywrt-1.1.0-gale`, then:

```sh
cd ~/src/raywrt-1.1.0-gale
sh scripts/build-raywrt-gale.sh
```

Optionally set `BUILD_ROOT` to a Linux filesystem path with sufficient space. The script creates a new timestamped build directory and refuses to reuse or delete an existing one. It fetches the pinned OpenWrt commit and feed commits, checks the source hash manifest, adds the bundled LuCI theme package, confirms the `google_wifi` profile, builds the image, and runs artifact verification.

When continuing from a previous verified build tree, reuse its toolchain, feeds, and download cache instead of downloading them again:

```sh
RAYWRT_OPENWRT_DIR="$HOME/openwrt-builds/<verified-build>/openwrt" \
  sh scripts/build-raywrt-gale.sh
```

The reuse path first checks the OpenWrt commit and all five feed pins. It replaces the RayWRT package source, reapplies each setting in the Gale fragment while preserving unrelated configuration, and cleans the package build output, package archive, and generated rootfs files before rebuilding incrementally. It preserves unrelated toolchain and package caches. If any pin does not match, the build stops.

The fragment selects `ip-full` and disables `ip-tiny`. Passwall2 requires the full provider; WireGuard accepts its virtual `ip` dependency. The installer also handles older images containing explicit `world[ip-tiny]` by replacing that constraint atomically in the same APK add transaction. It never removes the existing provider before dependency solving. The image verifier checks both build configuration and the built APK database for the selected provider.

The OpenWrt buildroot emits its normal intermediate image. The build script verifies it, then publishes this RayWRT-named artifact:

```text
raywrt-1.1.0-gale-sysupgrade.bin
```

The final artifact directory contains the public image, SHA256 file, OpenWrt firmware metadata, RayWRT release metadata JSON, build config, feed/source revisions, and build summary. Inspect `build-summary.txt` and retain the full build directory with the release records.

## Verify a build separately

```sh
sh scripts/verify-raywrt-image.sh \
  "$HOME/openwrt-builds/raywrt-1.1.0-25.12.5-google_wifi-<timestamp>/openwrt" \
  "$HOME/openwrt-builds/raywrt-1.1.0-25.12.5-google_wifi-<timestamp>/artifacts/raywrt-1.1.0-gale-sysupgrade.bin" \
  "$HOME/src/raywrt-1.1.0-gale"
```

The verifier fails closed on the wrong image name, target/profile metadata, OpenWrt version/revision, missing RayWRT payload/ACL/DNS/Wi-Fi files, stale runtime version strings, debug markers, or a missing/mismatched SHA256. It compares the rootfs bytes for `raywrt-tools`, Tools, Passwall 2, Terminal, and theme CSS with the frozen source processed by the exact pinned LuCI build tools (`jsmin` for JavaScript and `csstidy` for CSS). It inspects OpenWrt's staged Gale root filesystem as well as the image metadata. The build also removes an untracked stale RayWRT copy under a feed and fails if a pinned feed itself defines a duplicate package.

## Important DNS behavior

The new `raywrt-first-run-dns` script is invoked by the package UCI-default after Wi-Fi provisioning. The clean image seeds `raywrt.system.dns_default=pending`; on first boot it applies only if the Wi-Fi helper successfully normalized stock `OpenWrt` AP names, and only to a DHCP IPv4 `network.wan` with peer DNS at its stock default and no custom WAN DNS. It stores `peerdns=0` and DNS servers `1.1.1.1` and `1.0.0.1`. It does not change the WAN protocol, the separate `wan6` interface, dnsmasq, routes, or IPv6 settings. An older preserved RayWRT config has no pending marker, so an upgrade does not apply this default. Customized Wi-Fi, custom WAN DNS, and non-DHCP WAN protocols are preserved.

The bundled fixture test is `tests/first-run/test-first-run-provisioning.sh`; run it on Linux with `sh tests/first-run/test-first-run-provisioning.sh` before the image build. The Wi-Fi fixtures model disabled 2.4/5 GHz Gale radios and disabled stock APs, identify radios by their configured band instead of a radio-section number, cover one missing radio and AP, preserve custom SSIDs and later radio-disable choices, and verify one-shot behavior. Other fixtures cover the theme and WAN DNS defaults, IPv6 separation, legacy config, explicit custom DNS, and non-DHCP WAN behavior. Package-index tests simulate APK failure/retry/success and bounded failure state.

## First-boot Wi-Fi and package indexes

Google WiFi (Gale) uses QCA4019 2.4 GHz and 5 GHz radios. The 25.12 first-run helper reads each `wifi-device` band's UCI `band` value; it never assigns 2.4/5 GHz meaning to `radio0` or `radio1`. On the fresh-image `wifi_default=pending` marker only, it enables those detected radios and their existing AP-mode interfaces, changes stock `OpenWrt` SSIDs to `RayWRT`, and attaches APs to `lan`. If an AP is missing for a detected band it adds only that band's minimal AP section. Country, channel, transmit power, encryption and credentials are left as supplied by OpenWrt. A custom AP SSID completes the marker as preserved. The completed marker prevents future boots or upgrades from enabling a radio the user later disabled.

OpenWrt 25.12.5 uses APK. The fresh image seeds `package_indexes=pending`; `/etc/init.d/raywrt-package-index-init` launches an asynchronous procd job. Before each refresh it verifies that the first configured APK repository can be reached over HTTPS, then runs up to four `apk update` attempts with 30/60/120 second backoff and a bounded 20-second network timeout per repository connection. It records `ready` or `failed` and disables its boot link. LuCI boot, LAN and wireless do not wait on the download. If all attempts fail, Tools exposes Retry indexes and never reports a transient empty package database as Unsupported. A successful manual Package Update also refreshes package-state detection. Passwall 2 is resolved separately as supported/not-installed and its fixed install action remains available before general indexes are ready; on APK firmware it uses the signed Passwall APK feed, since the upstream IRAN_Passwall2 shell installer is opkg-specific.

The package's UCI-defaults script registers `/luci-static/raywrt` and selects it as `luci.main.mediaurlbase` when the fresh `/etc/config/raywrt` contains `theme_default=pending`. It commits both settings and marks the default applied. Because `/etc/config/raywrt` is preserved across sysupgrade, an existing install without the pending marker keeps its chosen LuCI theme. The fresh-install fixture also verifies that rerunning the script does not overwrite a later theme selection. A clean first boot on the actual Gale is still required to verify LuCI uses the built theme assets.

## Flashing

Do not flash as part of this build. Use `PRE_FLASH_GALE.md` and `GALE_RECOVERY.md` to prepare a verified backup and independent recovery path. The release remains blocked until clean sysupgrade and the other release gates pass.
