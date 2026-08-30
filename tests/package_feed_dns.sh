#!/usr/bin/env bash
set -eo pipefail

# The router's package feed must keep resolving to real addresses.
#
# Routed through FakeIP it hands opkg an address the router cannot reach from
# its own output path, so "opkg update" fails and every component install dies
# on a dependency it cannot download - unzip for Zapret, then gzip. That
# leaves the router without the very tool needed to repair it. Observed on a
# live 24.10.5 router with the tunnel up.
#
# The exemption uses the bootstrap resolver on purpose: packages are wanted
# precisely when the tunnel is not working.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GENERATOR="$ROOT_DIR/loghorizon/files/usr/lib/singbox/generator.uc"
SB_CONSTANTS="$ROOT_DIR/loghorizon/files/usr/lib/singbox/constants.uc"
MAKEFILE="$ROOT_DIR/loghorizon/Makefile"
BUILD_SH="$ROOT_DIR/build.sh"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

# --- The exemption exists and names the feed --------------------------------

grep -Fq 'const PACKAGE_FEED_DOMAIN_SUFFIXES = [ "openwrt.org" ];' "$SB_CONSTANTS" ||
  fail "the package feed domains must be declared"
grep -Fq '    PACKAGE_FEED_DOMAIN_SUFFIXES,' "$SB_CONSTANTS" ||
  fail "the package feed domains must be exported"

grep -Fq 'runtime_constants.PACKAGE_FEED_DOMAIN_SUFFIXES' "$GENERATOR" ||
  fail "the generator must exempt the package feed from FakeIP"
grep -Fq 'server: runtime_constants.BOOTSTRAP_DNS_SERVER_TAG,' "$GENERATOR" ||
  fail "the exemption must use the bootstrap resolver"

# --- It has to be evaluated before anything routes to FakeIP ----------------

# sing-box takes the first matching DNS rule. Pushed after the section rules,
# a domain caught by a community list would reach FakeIP first and the
# exemption would never fire.
awk '
  /PACKAGE_FEED_DOMAIN_SUFFIXES\)/ { feed = NR }
  /for \(let rule in dns_config.rules\)/ { section = NR }
  END { exit (feed > 0 && section > 0 && section < feed) ? 0 : 1 }
' "$GENERATOR" ||
  fail "the exemption must be pushed after the section rules are collected"

# --- The tools the component installer needs ship with the package ----------

# Zapret is unpacked with unzip and gzip. Installing them on demand means an
# opkg download at the worst possible moment, with the tunnel already up. At
# install time the tunnel is not running yet and the feed is reachable.
for tool in unzip gzip; do
  grep -Fq "+$tool" "$MAKEFILE" ||
    fail "$tool must be a package dependency"
  grep -Fq ", $tool" "$BUILD_SH" ||
    fail "$tool must be listed in the ipk dependencies"
  grep -Fq " $tool " "$BUILD_SH" ||
    fail "$tool must be listed in the apk dependencies"
done

printf 'package feed dns checks passed\n'
