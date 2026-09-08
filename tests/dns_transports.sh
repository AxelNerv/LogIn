#!/usr/bin/env bash
set -eo pipefail

# Covers the DNS transports the resolver can speak. DoQ and DoH3 were added
# after Russian ISPs started killing DoT and DoH at the TLS handshake in
# August 2026. They offer another transport path, but are not inherently
# invisible to traffic analysis and therefore need a TCP/TLS fallback.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UCODE_LIB="$ROOT_DIR/loghorizon/files/usr/lib"
VALIDATOR="$UCODE_LIB/config/validator.uc"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

run_server() {
  ucode -L "$UCODE_LIB" -e '
    let dns = require("singbox.dns");
    let argv = ARGV;
    printf("%J\n", dns.server_from_options("dns", argv[0], argv[1], argv[2] || ""));
  ' -- "$1" "$2" "${3:-}"
}

field() {
  printf '%s' "$1" | node -e '
    let raw = "";
    process.stdin.on("data", (chunk) => (raw += chunk));
    process.stdin.on("end", () => {
      const parsed = JSON.parse(raw);
      const value = parsed[process.argv[1]];
      process.stdout.write(value === undefined ? "" : String(value));
    });
  ' "$2"
}

expect_field() {
  local json="$1" key="$2" want="$3" label="$4"
  local got
  got="$(field "$json" "$key")"
  [ "$got" = "$want" ] ||
    fail "$label: expected $key '$want', got '$got'"
}

# --- Every transport maps to the sing-box server type ------------------------

udp="$(run_server udp 1.1.1.1)"
expect_field "$udp" type udp "udp"
expect_field "$udp" server_port 53 "udp"

dot="$(run_server dot dns.adguard-dns.com)"
expect_field "$dot" type tls "dot"
expect_field "$dot" server_port 853 "dot"

doh="$(run_server doh https://dns.adguard-dns.com/dns-query)"
expect_field "$doh" type https "doh"
expect_field "$doh" server_port 443 "doh"
expect_field "$doh" path /dns-query "doh"

doq="$(run_server doq dns.adguard-dns.com)"
expect_field "$doq" type quic "doq"
expect_field "$doq" server_port 853 "doq"

doh3="$(run_server doh3 h3://dns.adguard-dns.com/dns-query)"
expect_field "$doh3" type h3 "doh3"
expect_field "$doh3" server_port 443 "doh3"
expect_field "$doh3" path /dns-query "doh3"

tcp="$(run_server udp tcp://1.1.1.1)"
expect_field "$tcp" type tcp "per-entry TCP override"

# Each fallback can override the global transport with its URL scheme. A
# pinned address avoids recursive bootstrap while the logical host remains
# the TLS SNI and certificate name.
pinned="$(run_server udp 'https://cloudflare-dns.com/dns-query?address=1.1.1.1')"
expect_field "$pinned" type https "pinned DoH bootstrap"
expect_field "$pinned" server 1.1.1.1 "pinned DoH address"
expect_field "$pinned" path /dns-query "pinned DoH path"
printf '%s' "$pinned" | node -e '
  let raw = "";
  process.stdin.on("data", chunk => raw += chunk);
  process.stdin.on("end", () => {
    const value = JSON.parse(raw);
    if (value.domain_resolver !== undefined || value.tls?.server_name !== "cloudflare-dns.com") process.exit(1);
  });
' || fail "pinned DoH must verify the logical TLS name without a resolver dependency"

if ucode -L "$UCODE_LIB" -e '
  let dns = require("singbox.dns");
  let value = dns.bootstrap_server("bootstrap", "https://dns.google/dns-query");
  exit(value.unsupported ? 0 : 1);
'; then :; else
  fail "named bootstrap without pinned IP must be rejected as recursive"
fi

ucode -L "$UCODE_LIB" -e '
  let dns = require("singbox.dns");
  let settings = {
    dns_type: "doq",
    dns_server: [ "quic://dns.adguard-dns.com", "https://dns.google/dns-query" ],
    bootstrap_dns_server: [ "https://cloudflare-dns.com/dns-query?address=1.1.1.1" ]
  };
  let first = dns.config(settings, { version: 1, dns_type: "doq", dns_ech: false,
    dns_detour: "", main_servers: settings.dns_server,
    bootstrap_servers: settings.bootstrap_dns_server, main_index: 0, bootstrap_index: 0 });
  let second = dns.config(settings, { version: 1, dns_type: "doq", dns_ech: false,
    dns_detour: "", main_servers: settings.dns_server,
    bootstrap_servers: settings.bootstrap_dns_server, main_index: 1, bootstrap_index: 0 });
  if (first.servers[1].type != "quic" || second.servers[1].type != "https")
    die("mixed fallback transports were not preserved\n");
  if (length(first.inbounds || []) < 1)
    die("protected singleton bootstrap has no health probe\n");
' || fail "mixed DNS fallback configuration"

# --- Explicit ports win over the transport default ---------------------------

doq_port="$(run_server doq dns.adguard-dns.com:8853)"
expect_field "$doq_port" server_port 8853 "doq with explicit port"

# --- A named server needs the bootstrap resolver, a literal IP does not ------

expect_field "$doq" domain_resolver bootstrap-dns-server "doq by domain"
doq_ip="$(run_server doq 94.140.14.14)"
[ -z "$(field "$doq_ip" domain_resolver)" ] ||
  fail "doq by IP must not depend on the bootstrap resolver"

# --- Detour is carried through ----------------------------------------------

doq_detour="$(run_server doq dns.adguard-dns.com main-out)"
expect_field "$doq_detour" detour main-out "doq with detour"

# --- Unknown transports are still rejected -----------------------------------

bogus="$(run_server dnscrypt example.com)"
[ -n "$(field "$bogus" unsupported)" ] ||
  fail "an unknown dns_type must be reported as unsupported"

# --- The validator accepts exactly the implemented transports ----------------

for transport in udp tcp dot doh doq doh3; do
  grep -Fq "\"$transport\"" "$VALIDATOR" ||
    fail "config validator does not accept dns_type $transport"
done

printf 'dns transport checks passed\n'
