# RayWRT v1.1 — build verification

Firmware: RayWRT 1.1.0-r1. OpenWrt: 25.12.5 / r33051-f5dae5ece4.
Target/profile/device: ipq40xx/chromium / google_wifi / google,wifi.
Image: raywrt-1.1.0-gale-sysupgrade.bin. Size: 9,513,501 bytes.
SHA256: `56381a9f9decd7cec2eb453940ab4203c65db588895ac68c2f163728ee903dde`.
Ubuntu first-run, usage, WireGuard route and package-index retry tests: PASS.
Source syntax and Tools action tests: PASS.
Image metadata, critical source hashes and extracted squashfs: PASS.
Personal WireGuard configuration: NONE.
Android v2/v3 signatures and supplied artifact hashes: PASS.
Clean-sysupgrade acceptance: PENDING. Flash: NOT STARTED.

[Release](https://github.com/Heygoodbye/RayWRT/releases/tag/v1.1). Build verification does not replace device acceptance.

Replacement verified 2026-10-02 (Asia/Tehran). Boot recovery and no-handshake activation tests PASS. Live WAN restored; Iran list update SUCCESS (1808 ranges); user confirmed Internet works. VPN handshake remains absent; fallback currently uses WAN. Clean-sysupgrade acceptance of replacement remains PENDING.
