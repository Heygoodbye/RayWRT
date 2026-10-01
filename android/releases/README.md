# RayWRT v1 for Android

RayWRT is a native Android companion for OpenWrt by [Heygoodbye](https://github.com/Heygoodbye). Install `releases/RayWRT-v1-Android-universal.apk` on Android 8 or newer. It uses the existing RayWRT package and signing key; internal version code 21 allows an update over the previous test APK.

Connect over SSH on port 22 with a router IP or hostname, username, and password. Confirm the router's SSH fingerprint. Passwords are not saved or backed up. The app reads real UCI and ubus state.

Features: Passwall 2 control, node selection, node-link and subscription import, manual subscription update, eligible node deletion, and LuCI shortcut; WireGuard interface status and connect/disconnect, client `.conf` import with `wan` firewall assignment, and automatic interface selection and enabling of RayWRT Iran Direct routing on Connect, with coordinated switching and Disconnect; ping test of 15 EU gaming servers with latency, loss, replies, and per-server details; 2.4/5 GHz Wi-Fi state, radio controls, SSID and password editing; confirmed router reboot.

The app has a dark responsive interface, status heartbeat, and GitHub author link. The SSH connection indicator does not test Internet access or WireGuard peer handshakes. The APK is universal across supported processor architectures.
