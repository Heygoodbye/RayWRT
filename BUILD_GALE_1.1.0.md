# RayWRT 1.1.0 Gale build procedure

The portable, self-contained source bundle is [release/raywrt-1.1.0-gale](release/raywrt-1.1.0-gale/). Use its [`BUILD.md`](release/raywrt-1.1.0-gale/BUILD.md) and run `scripts/build-raywrt-gale.sh` on Ubuntu 24.04 / WSL2 or Linux x86_64.

OpenWrt is pinned to 25.12.5, commit `f0a60eee2fe051741c643ea6118718aae1ef17fb`; Gale target `ipq40xx/chromium`, profile `google_wifi`, supported device `google,wifi`. All feeds are pinned in `pins/openwrt.env`. The build script verifies these pins and does not track a moving branch.

Run the source fixtures first:

```sh
sh tests/first-run/test-first-run-provisioning.sh
```

Then build and verify:

```sh
sh scripts/build-raywrt-gale.sh
```

The expected public artifact is `raywrt-1.1.0-gale-sysupgrade.bin`. The public release identity does not change the OpenWrt target or add features. Image validation and clean-sysupgrade testing are pending. See [`PRE_FLASH_GALE.md`](release/raywrt-1.1.0-gale/PRE_FLASH_GALE.md) and [`GALE_RECOVERY.md`](release/raywrt-1.1.0-gale/GALE_RECOVERY.md) before any later flash stage. This procedure does not flash.
