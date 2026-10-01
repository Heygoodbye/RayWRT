[Download from GitHub Releases](https://github.com/Heygoodbye/RayWRT/releases/tag/v1.0.0)

# RayWRT v1 for Windows

RayWRT is a portable OpenWrt companion by [Heygoodbye](https://github.com/Heygoodbye). Extract the ZIP and run `RayWRT.exe`, or use `RayWRT-v1-Windows-x64-Setup.exe` for a per-user installation with `uninstall.exe`. The portable app includes .NET and does not need a separate runtime.

Connect using your router IP or hostname, SSH username, and password. Confirm the router's SSH fingerprint on first connection. The password is not saved. The app needs SSH on port 22 and sufficient router permissions; it reads real UCI and ubus state rather than sample data.

Features: Passwall 2 enable/disable, node selection, node-link and subscription import, manual subscription updates, eligible node deletion, and LuCI shortcut; WireGuard interface status and connect/disconnect, client `.conf` import with `wan` firewall assignment, and automatic interface selection and enabling of RayWRT Iran Direct routing on Connect, with coordinated switching and Disconnect; ping test across 15 EU gaming servers; 2.4/5 GHz Wi-Fi status, radio control, SSID and password changes; and confirmed router reboot.

The dark borderless window has rounded corners, a draggable title bar, hidden scrollbar, status heartbeat, and scalable layout. The footer links to the author's GitHub. The connection indicator reflects the SSH session; WireGuard Connected means the router interface is up, not that a peer handshake was recently verified.
