include $(TOPDIR)/rules.mk

PKG_NAME:=solve2surf
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

PKG_MAINTAINER:=Anuvrat <solve2surf@fastingrat.com>
PKG_LICENSE:=MIT
PKGARCH:=all

include $(INCLUDE_DIR)/package.mk

define Package/solve2surf
	SECTION:=net
	CATEGORY:=Network
	SUBMENU:=Captive Portals
	TITLE:=Solve problems to gain WiFi access
	DEPENDS:=+opennds +uhttpd +curl +jshn
endef

define Package/solve2surf/description
	A lightweight captive portal extension that requires users to solve a problem to gain internet access.
endef

define Build/Compile
endef

define Package/solve2surf/install
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_DIR) $(1)/etc/solve2surf
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_DIR) $(1)/www/cgi-bin
	$(INSTALL_DIR) $(1)/www/solve2surf

	$(INSTALL_CONF) ./files/etc/config/solve2surf $(1)/etc/config/solve2surf
	$(INSTALL_BIN) ./files/etc/init.d/solve2surf $(1)/etc/init.d/solve2surf
	$(INSTALL_CONF) ./files/etc/solve2surf/sample_problems.json $(1)/etc/solve2surf/sample_problems.json
	$(INSTALL_BIN) ./files/usr/bin/solve2surf-sync.sh $(1)/usr/bin/solve2surf-sync.sh
	$(INSTALL_BIN) ./files/usr/libexec/solve2surf/fas.sh $(1)/www/cgi-bin/fas.sh
	$(CP) ./files/www/solve2surf/* $(1)/www/solve2surf/
endef

$(eval $(call BuildPackage,solve2surf))