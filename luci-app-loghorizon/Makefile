include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-loghorizon

LOGHORIZON_SOURCE_VERSION:=$(or $(LOGHORIZON_PACKAGE_VERSION),$(LOGHORIZON_VERSION))
LOGHORIZON_HAS_RELEASE_VERSION:=$(if $(filter dev,$(LOGHORIZON_SOURCE_VERSION)),,$(LOGHORIZON_SOURCE_VERSION))
LOGHORIZON_COMPILED_VERSION:=$(if $(LOGHORIZON_HAS_RELEASE_VERSION),$(LOGHORIZON_SOURCE_VERSION),$(or $(LOGHORIZON_SOURCE_VERSION),dev))
LOGHORIZON_RELEASE_VERSION_VALID:=$(if $(LOGHORIZON_HAS_RELEASE_VERSION),$(shell printf '%s\n' '$(LOGHORIZON_SOURCE_VERSION)' | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$$' && printf '1'),1)

ifeq ($(LOGHORIZON_RELEASE_VERSION_VALID),)
$(error LOGHORIZON_PACKAGE_VERSION and LOGHORIZON_VERSION must use x.y.z format)
endif

PKG_VERSION:=$(or $(LOGHORIZON_HAS_RELEASE_VERSION),0.0.0)
PKG_RELEASE:=
PKG_PO_VERSION:=$(PKG_VERSION)

LUCI_TITLE:=LuCI logIn app (logIn compatibility)
LUCI_DEPENDS:=+luci-base +loghorizon
LUCI_PKGARCH:=all
LUCI_LANG.ru:=Русский (Russian)
LUCI_LANG.en:=English
LUCI_MAINTAINER:=AxelNerv <AxelNerv@users.noreply.github.com>
LUCI_DESCRIPTION:=logIn routing and DPI control UI with logIn-compatible runtime
LUCI_MINIFY_JS:=0

PKG_LICENSE:=GPL-2.0-or-later
LUCI_LANGUAGES:=en ru

define Build/Prepare/$(PKG_NAME)
	sed -i -e 's/__COMPILED_VERSION_VARIABLE__/$(LOGHORIZON_COMPILED_VERSION)/g' $(PKG_BUILD_DIR)/htdocs/luci-static/resources/view/loghorizon/main.js
endef

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
