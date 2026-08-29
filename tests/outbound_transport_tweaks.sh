#!/usr/bin/env bash
set -eo pipefail

# Two opt-in traffic-shaping settings for a connection section.
#
# Splitting the TLS handshake sends the ClientHello across several packets, so
# a filter cannot read the server name out of one. Multiplexing folds streams
# into a single connection and pads them, which hides the shape of the traffic
# and cuts the connection count.
#
# Verified against sing-box 1.13.18-extended: both are accepted alongside
# Reality and uTLS, including over XHTTP. Multiplexing is refused outright on
# the QUIC protocols, which already multiplex, so those outbounds are skipped
# and the skip is reported rather than swallowed.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GENERATOR="$ROOT_DIR/loghorizon/files/usr/lib/singbox/generator.uc"
VALIDATOR="$ROOT_DIR/loghorizon/files/usr/lib/config/validator.uc"
SECTION_JS="$ROOT_DIR/luci-app-loghorizon/htdocs/luci-static/resources/view/loghorizon/section.js"
CONFIG_TEMPLATE="$ROOT_DIR/loghorizon/files/etc/config/loghorizon"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

# --- The pass exists and runs over the section's own outbounds --------------

grep -Fq 'function apply_section_transport_tweaks(' "$GENERATOR" ||
  fail "the generator must have a transport tweak pass"
grep -Fq 'apply_section_transport_tweaks(config, cascade_start, section, section_name);' "$GENERATOR" ||
  fail "the pass must run over the outbounds added for this section"

# It has to run before interfaces and JSON outbounds are added, matching the
# detour pass: those source kinds are deliberately left alone.
awk '
  /apply_section_transport_tweaks\(config, cascade_start/ { tweak = NR }
  /add_connection_interfaces\(config, state, section/ { iface = NR }
  END { exit (tweak > 0 && iface > 0 && tweak < iface) ? 0 : 1 }
' "$GENERATOR" ||
  fail "the pass must run before interface outbounds are added"

# --- Fragmentation only touches outbounds that actually speak TLS -----------

grep -Fq 'if (fragment && type(outbound.tls) == "object" && outbound.tls.enabled)' "$GENERATOR" ||
  fail "fragmentation must require an enabled TLS block"
grep -Fq 'outbound.tls.fragment = true;' "$GENERATOR" ||
  fail "fragmentation must set the sing-box tls.fragment field"

# --- Multiplexing is limited to the protocols that accept it ----------------

grep -Fq 'function multiplex_supported_outbound_type(' "$GENERATOR" ||
  fail "there must be an explicit list of protocols that accept multiplexing"

for proto in vless vmess trojan shadowsocks; do
  grep -Fq "outbound_type == \"$proto\"" "$GENERATOR" ||
    fail "multiplexing must be allowed for $proto"
done

if awk '
  /function multiplex_supported_outbound_type\(/ { inside = 1 }
  inside && /hysteria2|tuic/ { found = 1 }
  inside && /^}/ { exit }
  END { exit found ? 0 : 1 }
' "$GENERATOR"; then
  fail "the QUIC protocols must not be listed as accepting multiplexing"
fi

grep -Fq 'multiplexing skipped for ' "$GENERATOR" ||
  fail "outbounds skipped for multiplexing must be reported, not swallowed"

# --- An unknown multiplex protocol is refused -------------------------------

grep -Fq 'uses unsupported multiplex protocol' "$VALIDATOR" ||
  fail "the validator must refuse an unknown multiplex protocol"
for proto in h2mux smux yamux; do
  grep -Fq "\"$proto\"" "$VALIDATOR" ||
    fail "the validator must accept $proto"
done

# --- Both settings are offered, and only on connection sections -------------

for option_name in tls_fragment_enabled multiplex_enabled multiplex_protocol multiplex_padding; do
  grep -Fq "\"$option_name\"" "$SECTION_JS" ||
    fail "the interface must offer $option_name"
  grep -Fq "option $option_name " "$CONFIG_TEMPLATE" ||
    fail "the config template must document $option_name"
done

grep -Fq 'o.depends({ action: "connection", multiplex_enabled: "1" });' "$SECTION_JS" ||
  fail "the multiplex details must only appear once multiplexing is on"

printf 'outbound transport tweak checks passed\n'
