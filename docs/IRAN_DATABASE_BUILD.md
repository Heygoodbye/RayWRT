# RayWRT Iran Direct database update

## Iran IP database replacement — 2026-10-01

- Source: farshidmousavii/iran-ip-ranges, plain IPv4 list; previous KAJOOSH URL removed from current runtime.
- MIT copyright and license notice included in firmware; RayWRT package 1.0.0-r6.
- Ubuntu first-run and WireGuard default-route tests: PASS.
- Live upstream list accepted by existing validator: 1,808 IPv4 ranges.
- Frozen source and bundle checksums: PASS.
- Build/image verifier: PASS; OpenWrt 25.12.5 r33051-f5dae5ece4, ipq40xx/chromium, google_wifi, google,wifi.
- Actual sysupgrade SquashFS helper and MIT notice match frozen source: PASS.
- Image: raywrt-1.0.0-gale-sysupgrade.bin; 9,513,501 bytes.
- SHA256: `3fba84f17103484fbb43a06933fcc75110892ce5bc3c1925745e4cacf12ab7fc`
- Windows copy checksum: PASS.
- No router changes or flash; VM remains running.
- Clean-sysupgrade validation remains pending. The GitHub v1.0.0 release now includes this firmware plus the supplied Windows installer and universal Android APK; all uploaded sizes and SHA256 digests match local files. The prerelease flag was removed at the user's request.
