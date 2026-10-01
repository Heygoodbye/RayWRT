# Google WiFi (Gale) recovery notes

This guide separates documented recovery mechanisms from items tested on this specific router. Recovery is not considered ready until the chosen method is prepared and verified locally.

## OpenWrt sysupgrade rollback

**VERIFIED DURING PREFLIGHT:** The inspected router identified as Google WiFi (Gale), OpenWrt 25.12.5, and responded on its LAN. A local official stock Gale sysupgrade image exists:

```text
openwrt-25.12.5-ipq40xx-chromium-google_wifi-squashfs-sysupgrade.bin
```

It is 8,899,101 bytes and its SHA256 is `11aa7bc9ba956ab76289740a0abcdb7b1bb718351769232908ea406a9a122679`, matching the official 25.12.5 target download index. This verifies the local artifact and its published digest, not a completed rollback test.

**LIKELY:** If OpenWrt still boots and its management interface is reachable by Ethernet, upload a known-good matching Gale **sysupgrade** image through LuCI or SSH, validate it with `sysupgrade -T`, then run sysupgrade. A clean rollback can erase configuration. Verify the image target and checksum first. Never use a factory image to downgrade a router already running OpenWrt.

**UNVERIFIED:** A rollback of this specific device has not been performed. Do not rely on it as the only recovery route.

## Google/OnHub recovery mode

**VERIFIED IN DEVICE DOCUMENTATION, NOT TESTED LOCALLY:** The OpenWrt Google WiFi guide documents these requirements to restore factory software:

- USB-C hub with power delivery, USB drive of at least 4 GB, and stable power.
- OnHub Recovery Utility in Chrome on Windows, Mac, or ChromeOS. The guide says the utility does not support GNU/Linux.
- A Google Gale recovery image, selected/created through the utility. This is a factory recovery image, not an OpenWrt sysupgrade image.

The documented sequence is: hold the router's Reset button while connecting power; release Reset when the LED blinks orange at about 16 seconds; insert the prepared recovery USB; wait for the LED to turn off and the recovery process to run; expect an automatic reboot after about 5–6 minutes. The guide warns that not all USB drives work. Follow the current device instructions and stop if the indicator behavior differs. Source: [OpenWrt Google WiFi device and recovery guide](https://openwrt.org/toh/google/wifi).

**UNVERIFIED LOCALLY:** No recovery USB has been created or tested for this router, and no compatible Gale recovery image/media was verified locally. Do not call physical recovery ready until a suitable hub, drive, matching image, recovery computer, and procedure have been prepared and checked.

## Failsafe and Ethernet

**VERIFIED:** The router currently responds on its LAN management address, and the OpenWrt LuCI interface identifies its board as Google WiFi (Gale). Keep a wired computer on a LAN port for management during normal OpenWrt recovery.

**UNVERIFIED:** A Gale-specific OpenWrt failsafe button/timing procedure and failsafe recovery boot were not verified. Do not assume a generic OpenWrt failsafe procedure works on this boot chain. The USB recovery process has different host/USB requirements and is not a substitute for ordinary LAN Ethernet.

## Main risks

- Wrong target, corrupted image, interrupted power, or an untested recovery path can make the router inaccessible.
- `sysupgrade -n` deliberately removes preserved configuration; save and verify the backup first.
- A backup restores configuration, not a router that cannot boot or enter recovery mode.
- Keep the recovery image, checksum, backup, and wired computer available before starting any flash.
