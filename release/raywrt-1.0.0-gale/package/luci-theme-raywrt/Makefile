include $(TOPDIR)/rules.mk

LUCI_TITLE:=RayWRT theme and dashboard
LUCI_DEPENDS:=+luci-base +luci-mod-status
PKG_LICENSE:=Apache-2.0
PKG_VERSION:=1.0.0
PKG_RELEASE:=6

define Package/luci-theme-raywrt/conffiles
/etc/config/raywrt
endef

define Package/luci-theme-raywrt/postinst
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] || {
  chmod 755 /usr/libexec/raywrt-tools
  chmod 755 /usr/libexec/raywrt-diagnostics
  chmod 755 /usr/libexec/raywrt-first-run-wifi
  chmod 755 /usr/libexec/raywrt-first-run-dns
  chmod 755 /usr/libexec/raywrt-usage /usr/libexec/raywrt-usage-control /etc/init.d/raywrt-usage
  chmod 755 /usr/libexec/raywrt-device-usage /usr/libexec/raywrt-device-usage-control /etc/init.d/raywrt-device-usage
  chmod 755 /usr/libexec/raywrt-terminal /usr/libexec/raywrt-terminal-shell
  chmod 755 /usr/libexec/raywrt-wireguard-split /etc/init.d/raywrt-wireguard-split
  /etc/init.d/raywrt-usage enable
  /etc/init.d/raywrt-usage start
  /etc/init.d/raywrt-device-usage enable
  /etc/init.d/raywrt-device-usage start
  rm -f /tmp/luci-indexcache.*
  /etc/init.d/rpcd reload 2>/dev/null
  exit 0
}
endef

define Package/luci-theme-raywrt/postrm
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] || {
  [ "$$(uci -q get luci.main.mediaurlbase)" = "/luci-static/raywrt" ] && uci set luci.main.mediaurlbase=/luci-static/bootstrap
  /etc/init.d/raywrt-usage stop 2>/dev/null
  /etc/init.d/raywrt-usage disable 2>/dev/null
  /etc/init.d/raywrt-device-usage stop 2>/dev/null
  /etc/init.d/raywrt-device-usage disable 2>/dev/null
  /usr/libexec/raywrt-terminal stop 2>/dev/null
  /etc/init.d/raywrt-wireguard-split stop 2>/dev/null
  /etc/init.d/raywrt-wireguard-split disable 2>/dev/null
  ip -4 rule del priority 5215 fwmark 0x52570000/0xffff0000 lookup 52157 2>/dev/null
  ip -4 route del default table 52157 2>/dev/null
  nft delete table ip raywrt_wg_split 2>/dev/null
  uci -q delete luci.themes.RayWRT
  uci -q delete raywrt.wireguard_split
  uci commit raywrt
  uci commit luci
}
endef

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature

