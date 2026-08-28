include $(TOPDIR)/rules.mk

PKG_NAME:=loghorizon

LOGHORIZON_SOURCE_VERSION:=$(or $(LOGHORIZON_PACKAGE_VERSION),$(LOGHORIZON_VERSION))
LOGHORIZON_HAS_RELEASE_VERSION:=$(if $(filter dev,$(LOGHORIZON_SOURCE_VERSION)),,$(LOGHORIZON_SOURCE_VERSION))
LOGHORIZON_COMPILED_VERSION:=$(if $(LOGHORIZON_HAS_RELEASE_VERSION),$(LOGHORIZON_SOURCE_VERSION),$(or $(LOGHORIZON_SOURCE_VERSION),dev))
LOGHORIZON_RELEASE_VERSION_VALID:=$(if $(LOGHORIZON_HAS_RELEASE_VERSION),$(shell printf '%s\n' '$(LOGHORIZON_SOURCE_VERSION)' | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$$' && printf '1'),1)

ifeq ($(LOGHORIZON_RELEASE_VERSION_VALID),)
$(error LOGHORIZON_PACKAGE_VERSION and LOGHORIZON_VERSION must use x.y.z format)
endif

PKG_VERSION:=$(or $(LOGHORIZON_HAS_RELEASE_VERSION),0.0.0)
PKG_RELEASE:=

PKG_MAINTAINER:=AxelNerv <AxelNerv@users.noreply.github.com>
PKG_LICENSE:=GPL-2.0-or-later

include $(INCLUDE_DIR)/package.mk

define Package/loghorizon
	SECTION:=net
	CATEGORY:=Network
	DEPENDS:=+ca-bundle +kmod-inet-diag +kmod-netlink-diag +kmod-tun +curl +ucode +ucode-mod-fs +ucode-mod-uci +kmod-nft-tproxy +coreutils-base64 +bind-dig +nftables +kmod-nft-nat +ip-full
	CONFLICTS:=https-dns-proxy nextdns luci-app-passwall luci-app-passwall2
	TITLE:=logIn backend service (logIn compatibility)
	URL:=https://github.com/AxelNerv/LogIn
	PKGARCH:=all
endef

define Package/loghorizon/description
	logIn foundation backend with logIn-compatible sing-box and DPI orchestration
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/loghorizon/prerm
#!/usr/bin/ucode

if (getenv("IPKG_INSTROOT") == null || getenv("IPKG_INSTROOT") == "")
	system("/usr/bin/loghorizon package_prerm " + (ARGV[0] || "") + " >/dev/null 2>&1");

exit(0);
endef

define Package/loghorizon/postinst
#!/bin/sh

[ -n "$${IPKG_INSTROOT}" ] && exit 0
LOGHORIZON_LIB=/usr/lib/loghorizon ucode -L /usr/lib/loghorizon /usr/lib/loghorizon/config/migration.uc migrate || exit $$?
/usr/bin/loghorizon package_postinst
endef

define Package/loghorizon/conffiles
/etc/config/loghorizon
endef

define Package/loghorizon/install
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/etc/init.d/loghorizon $(1)/etc/init.d/loghorizon

	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/etc/config/loghorizon $(1)/etc/config/loghorizon

	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) ./files/usr/bin/loghorizon $(1)/usr/bin/loghorizon

	$(INSTALL_DIR) $(1)/usr/lib/loghorizon
	$(CP) ./files/usr/lib/. $(1)/usr/lib/loghorizon/

	sed -i -e 's/__COMPILED_VERSION_VARIABLE__/$(LOGHORIZON_COMPILED_VERSION)/g' $(1)/usr/lib/loghorizon/core/constants.uc
endef

$(eval $(call BuildPackage,loghorizon))
