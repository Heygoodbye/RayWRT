# RayWRT 1.0.0

RayWRT 1.0.0 is the first public release identity for the current RayWRT LuCI theme and package source. Previous 1.5.x numbers refer to internal development iterations and are not public release numbers.

This versioning pass changes release identity and metadata only. It adds no features. The supported build target remains Google WiFi (Gale) on OpenWrt 25.12.5.

The expected image filename is `raywrt-1.0.0-gale-sysupgrade.bin`. A rebuilt image is still pending clean-install and clean-sysupgrade acceptance; the public release is not yet validated.
# RayWRT 1.0.0

## First-boot theme activation

The fresh-install UCI defaults now select `/luci-static/raywrt` as LuCI's active media URL base using a one-time `theme_default=pending` marker. Existing configurations without that marker keep their selected theme during upgrades. A fresh Gale boot is still required to validate the live UI.

## Fresh-install corrections

- First boot identifies Gale 2.4/5 GHz radios by configured band, enables stock radios and APs, renames stock APs to `RayWRT`, attaches APs to `lan`, and adds only an AP missing from a supported band. Custom SSIDs and later intentional radio disables are preserved.
- APK package indexes initialize asynchronously with bounded retry. Tools distinguishes initialization or failure from an unavailable package and refreshes detection when indexing completes; manual Package Update remains available.
- Passwall 2 resolves as supported and Not installed independently of the standard package index, with its fixed Install action enabled. On OpenWrt 25.12 it uses the signed Passwall APK feed. The upstream IRAN_Passwall2 v1 shell installer requires opkg and is not run on this APK target.
- Passwall 2 readiness now checks the installed package, discovers either a LuCI menu route or the route registered by the package's Lua controller, resolves the service path from package contents, verifies executable Xray and nftables proxy support, and reports configuration/runtime separately. A stopped or unconfigured service does not turn a successful install into a failure; incomplete installs show individual failed checks.
- Passwall's APK transaction replaces conflicting ip-tiny with ip-full atomically. Fresh Gale images use ip-full, retaining WireGuard support.
- OpenVPN detection recognizes its legacy Lua controller and opens the native VPN → OpenVPN manager. Successful package jobs refresh LuCI controller/menu caches and rpcd ACLs.
- Iran direct routing now activates the selected imported WireGuard interface even when Route Allowed IPs is already on but WAN still holds the IPv4 default route. It verifies the new route and restores the interface/peer settings it changed if activation fails. Clicking Enable performs this setup; flashing alone does not change any peer.
- Fixtures now cover disabled Gale radios/APs, a missing band/AP, custom settings, later disable, one-shot behavior, package index retries and Passwall state.

These corrections do not add unrelated features. They require a new build and a real clean Gale boot before public release validation.
