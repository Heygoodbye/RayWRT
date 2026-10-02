# RayWRT v1.1 — 2026-10-03 replacement build

Firmware: RayWRT 1.1.0-r1. OpenWrt: 25.12.5 / r33051-f5dae5ece4.
Target/profile/device: ipq40xx/chromium / google_wifi / google,wifi.
Image: raywrt-1.1.0-gale-sysupgrade.bin. Size: 9,513,501 bytes.
SHA256: `53907a84b9082ffea30e79b5672764d289ba15dc332ff5c72da42ce0efde073e`.
Ubuntu first-run, usage, package-index and WireGuard recovery tests: PASS.
Image metadata, critical source hashes and extracted squashfs: PASS.
Personal WireGuard configuration: NONE. Debug artifacts: NONE.
Clean-sysupgrade acceptance: PENDING. Flash: NOT STARTED.

Recovery now detects stale keepalive-enabled tunnels and restores WAN. A historical handshake cannot restore the failed VPN default route. Idle no-keepalive peers are not moved merely for an old handshake. Fallback uses normal WAN; this is not a VPN kill switch.
