> **🧪 Tested only on Google WiFi AC-1304 (Gale) running OpenWrt 25.12.5. Other devices and firmware versions are unverified.**

# 🟢 RayWRT

Modern LuCI dashboard, router tools, and Windows / Android companion applications by [Heygoodbye](https://github.com/Heygoodbye).

[📖 English documentation](english.md) · [🇮🇷 راهنمای فارسی](FA.md)

## 📥 RayWRT v1 downloads

1. [Google WiFi Gale sysupgrade — OpenWrt 25.12.5](https://github.com/Heygoodbye/RayWRT/releases/download/v1.0.0/raywrt-1.0.0-gale-sysupgrade.bin)
2. [Windows x64 installer](https://github.com/Heygoodbye/RayWRT/releases/download/v1.0.0/RayWRT-v1-Windows-x64-Setup.exe)
3. [Android universal APK — Android 8+](https://github.com/Heygoodbye/RayWRT/releases/download/v1.0.0/RayWRT-v1-Android-universal.apk)

[Release notes and SHA256 checksums](https://github.com/Heygoodbye/RayWRT/releases/tag/v1.0.0)

![RayWRT dashboard](docs/screenshots/dashboard.png)

RayWRT combines a dark green OpenWrt interface with live statistics, traffic accounting, VPN integrations, an embedded terminal, and optional Iran Direct routing for WireGuard. Windows and Android apps manage your router through SSH.

## 🇮🇷 Iran Direct routing

Iran IPv4 traffic uses your normal WAN connection; other IPv4 traffic uses the selected WireGuard tunnel. The current firmware uses [farshidmousavii/iran-ip-ranges](https://github.com/farshidmousavii/iran-ip-ranges), whose upstream refresh is scheduled every six hours. RayWRT validates downloaded ranges before applying them. The upstream MIT copyright and license notice are included in the firmware. IPv6 routing is unchanged.

The latest image includes the WireGuard import/default-route fixes, the responsive LuCI dashboard and Tools, per-device traffic accounting, and the embedded terminal. Both default AP SSIDs are `RayWRT` on a fresh stock install; upgrades preserve custom SSIDs. Personal VPN configurations and keys are not included.

RayWRT 1.0.0 build and image checks passed. Formal clean-sysupgrade validation remains **pending**; public firmware is **not yet fully validated**.

Read the language guides for features, screenshots, build instructions, and upstream credits.
