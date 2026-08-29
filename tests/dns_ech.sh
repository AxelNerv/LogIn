#!/usr/bin/env bash
set -eo pipefail

# Russian providers block DoH and DoT by reading the resolver name out of the
# TLS handshake. ECH puts that name inside an encrypted extension, so there is
# nothing left to match.
#
# The catch is that ECH keys are published in HTTPS DNS records, and the
# generator rejects every HTTPS query to stop browsers doing their own DoH.
# Turning ECH on without letting the resolver's own record through would give
# a setting that silently does nothing.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UCODE_LIB="$ROOT_DIR/loghorizon/files/usr/lib"
CONFIG_TEMPLATE="$ROOT_DIR/loghorizon/files/etc/config/loghorizon"
VALIDATOR="$UCODE_LIB/config/validator.uc"
SETTINGS_JS="$ROOT_DIR/luci-app-loghorizon/htdocs/luci-static/resources/view/loghorizon/settings.js"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

server_json() {
  ucode -L "$UCODE_LIB" -e '
    let dns = require("singbox.dns");
    let argv = ARGV;
    printf("%J\n", dns.server_from_options("dns", argv[0], argv[1], "", argv[2] == "1"));
  ' -- "$1" "$2" "$3"
}

has_ech() {
  printf '%s' "$1" | node -e '
    let raw = "";
    process.stdin.on("data", (chunk) => (raw += chunk));
    process.stdin.on("end", () => {
      const parsed = JSON.parse(raw);
      process.stdout.write(parsed?.tls?.ech?.enabled ? "yes" : "no");
    });
  '
}

# --- ECH reaches the encrypted transports, and only those -------------------

for transport in dot doh doq doh3; do
  [ "$(has_ech "$(server_json "$transport" dns.adguard-dns.com 1)")" = "yes" ] ||
    fail "ECH must be applied to $transport"
  [ "$(has_ech "$(server_json "$transport" dns.adguard-dns.com 0)")" = "no" ] ||
    fail "$transport must not carry ECH when it is switched off"
done

[ "$(has_ech "$(server_json udp 77.88.8.8 1)")" = "no" ] ||
  fail "plain UDP has no handshake to hide and must not claim ECH"

# --- The resolver's HTTPS record stays reachable ----------------------------

domains() {
  printf '%s' "$1" > "$WORK_DIR/settings.json"
  ucode -L "$UCODE_LIB" -e '
    let dns = require("singbox.dns");
    let fs = require("fs");
    let handle = fs.open(ARGV[0], "r");
    let settings = json(handle.read("all"));
    handle.close();
    printf("%J\n", dns.ech_resolver_domains(settings));
  ' -- "$WORK_DIR/settings.json"
}

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

named="$(domains '{"dns_type":"doh","dns_ech_enabled":"1","dns_server":["dns.adguard-dns.com"]}')"
printf '%s' "$named" | grep -Fq 'dns.adguard-dns.com' ||
  fail "a named resolver must be exempted from the HTTPS reject when ECH is on"

by_ip="$(domains '{"dns_type":"doh","dns_ech_enabled":"1","dns_server":["94.140.14.14"]}')"
[ "$(printf '%s' "$by_ip" | tr -d '[] \n')" = "" ] ||
  fail "a resolver given by IP needs no HTTPS exemption"

disabled="$(domains '{"dns_type":"doh","dns_ech_enabled":"0","dns_server":["dns.adguard-dns.com"]}')"
[ "$(printf '%s' "$disabled" | tr -d '[] \n')" = "" ] ||
  fail "no exemption may be added while ECH is off"

# --- The exemption is ordered before the blanket reject ---------------------

awk '
  /query_type: "HTTPS",/ && !seen_reject { exempt = 1 }
  /action: "reject", query_type: "HTTPS"/ { seen_reject = 1 }
  END { exit exempt ? 0 : 1 }
' "$UCODE_LIB/singbox/generator.uc" ||
  fail "the HTTPS exemption must be pushed before the reject rule"

# --- Nonsense combinations are refused --------------------------------------

grep -Fq 'ECH needs an encrypted DNS protocol' "$VALIDATOR" ||
  fail "ECH over plain UDP must be rejected with an explanation"

# --- The option exists in the config template and the interface -------------

grep -Fq "option dns_ech_enabled '0'" "$CONFIG_TEMPLATE" ||
  fail "the config template must ship the option, switched off"
grep -Fq '"dns_ech_enabled"' "$SETTINGS_JS" ||
  fail "the option must be offered in the settings tab"
grep -Fq 'o.depends({ dns_type: "dot" });' "$SETTINGS_JS" ||
  fail "the option must only appear for encrypted transports"

printf 'dns ECH checks passed\n'
