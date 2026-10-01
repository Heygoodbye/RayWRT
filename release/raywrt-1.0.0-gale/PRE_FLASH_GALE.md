# Gale pre-flash checklist

Do not start a sysupgrade until every required item below is ready. This guide creates a backup only; it does not reset or alter the router.

1. Create a full OpenWrt configuration backup and copy it to another computer. The archive can contain private keys and passwords; keep it private.
2. Download and save the currently working image and checksum. The locally verified OpenWrt 25.12.5 stock Gale sysupgrade is a useful software rollback image, but it is not a substitute for a physical recovery method.
3. Record the installed OpenWrt/RayWRT versions, LAN address/subnet, DHCP range, gateway, and any static routes.
4. Record each radio's band, enabled state, SSID, encryption, and channel. Never publish passwords or VPN keys.
5. Verify the new image checksum from its `.sha256` file with `sha256sum -c`.
6. Run the bundled image verifier and check `supported_devices` includes `google,wifi`, target `ipq40xx/chromium`, and OpenWrt version 25.12.5.
7. Prepare and test a Gale recovery method described in `GALE_RECOVERY.md`.
8. Confirm physical access to the router and stable power throughout the flash and reboot.
9. Confirm a computer is connected to the router by LAN Ethernet and can reach the management address after reboot.
10. Do not flash if rollback or physical recovery is uncertain.

## Safe timestamped config backup

Run these commands from a Linux/macOS shell or WSL host with SSH/SCP access. They ask the running router to create a backup archive under `/tmp`, then copy it to the current computer. They do not run `sysupgrade`, reset settings, or modify the router's configuration.

```sh
ROUTER="${ROUTER:?Set ROUTER to the router's current LAN address}"
STAMP=$(date -u +%Y%m%dT%H%M%SZ)
REMOTE="/tmp/openwrt-config-backup-$STAMP.tar.gz"
LOCAL="$PWD/openwrt-config-backup-$STAMP.tar.gz"
ssh "root@$ROUTER" "sysupgrade -b '$REMOTE' && test -s '$REMOTE'"
scp "root@$ROUTER:$REMOTE" "$LOCAL"
test -s "$LOCAL"
sha256sum "$LOCAL" | tee "$LOCAL.sha256"
```

Verify the archive is readable without extracting secrets:

```sh
tar -tzf "$LOCAL" >/dev/null
sha256sum -c "$LOCAL.sha256"
```

Keep the archive and hash in a secure local location. Do not upload or paste the archive into chats, issue trackers, or public storage.
