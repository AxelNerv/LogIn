#!/usr/bin/env bash
set -eo pipefail

# Multiplexing and the XTLS flows cannot be combined. Switching multiplexing
# on makes sing-box drop the flow; the server, which still expects it, then
# refuses every connection. Reproduced against sing-box 1.13.18-extended with
# a local VLESS Reality server:
#
#   server: flow mismatch: expected xtls-rprx-vision, but got none
#   client: http2: client connection force closed via ClientConn.Close
#
# The configuration checker accepts the combination, so the first sign is a
# tunnel that stopped answering, taking DNS down with it when DNS is routed
# through the tunnel. The generator therefore refuses to apply multiplexing to
# such an outbound, and the interface will not let the combination be built.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GENERATOR="$ROOT_DIR/loghorizon/files/usr/lib/singbox/generator.uc"
SECTION_JS="$ROOT_DIR/luci-app-loghorizon/htdocs/luci-static/resources/view/loghorizon/section.js"
SETTINGS_JS="$ROOT_DIR/luci-app-loghorizon/htdocs/luci-static/resources/view/loghorizon/settings.js"
STYLES_TS="$ROOT_DIR/fe-app-loghorizon/src/styles.ts"
MAIN_TS="$ROOT_DIR/fe-app-loghorizon/src/main.ts"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

# --- The generator never multiplexes an outbound carrying a flow ------------

grep -Fq 'function outbound_carries_xtls_flow(' "$GENERATOR" ||
  fail "the generator must recognise an outbound that carries an XTLS flow"
grep -Fq '!outbound_carries_xtls_flow(outbound)' "$GENERATOR" ||
  fail "multiplexing must be skipped for an outbound carrying a flow"

# The skip has to be reported: a setting that silently does nothing is how
# this went unnoticed in the first place.
grep -Fq 'uses an XTLS flow that multiplexing would strip' "$GENERATOR" ||
  fail "the skip must name the flow as a reason"

# --- The interface blocks the combination instead of hiding it --------------

grep -Fq 'function guardOptionAgainstConflicts(' "$SECTION_JS" ||
  fail "there must be a way to disable an option whose combination cannot work"
grep -Fq 'guardOptionAgainstConflicts(o, multiplexConflictReason);' "$SECTION_JS" ||
  fail "the multiplex flag must be guarded"
grep -Fq 'refreshConflictGuards(section_id);' "$SECTION_JS" ||
  fail "the guards must be re-evaluated when the connection links change"

# A blocked control keeps its place and gains a reason, rather than vanishing.
grep -Fq 'lgh-conflict-blocked' "$SECTION_JS" ||
  fail "a blocked control must be marked so it can be greyed out"
grep -Fq 'lgh-conflict-note' "$SECTION_JS" ||
  fail "a blocked control must carry the reason next to it"
grep -Fq 'el.disabled = true;' "$SECTION_JS" ||
  fail "a blocked control must not be clickable"
grep -Fq 'widget.setValue("0");' "$SECTION_JS" ||
  fail "a blocked control must be cleared so the combination cannot be saved"

for selector in .lgh-conflict-blocked .lgh-conflict-note; do
  grep -Fq "$selector" "$STYLES_TS" ||
    fail "$selector must be styled"
done

# The modal renders outside the shell, so the rules must not be scoped to it.
grep -Fq '.lh-shell .lgh-conflict-blocked' "$STYLES_TS" &&
  fail "the conflict styles must not be scoped to the shell"

# --- Every conflicting combination the generator knows about is gated -------

grep -Fq 'flow.startsWith("xtls-")' "$SECTION_JS" ||
  fail "a link carrying an XTLS flow must block multiplexing"
for transport in xhttp grpc; do
  grep -Fq "transport === \"$transport\"" "$SECTION_JS" ||
    fail "a link using the $transport transport must block multiplexing"
done
grep -Fq '["hysteria2", "hy2", "tuic"].includes(scheme)' "$SECTION_JS" ||
  fail "the QUIC protocols must block multiplexing"

# --- ECH cannot be switched on against a resolver given by address ----------

grep -Fq 'function dnsServerAddressLiteral(' "$SETTINGS_JS" ||
  fail "the settings form must recognise a resolver given by address"
grep -Fq 'ECH needs a DNS server given by name' "$SETTINGS_JS" ||
  fail "the settings form must refuse ECH against an address, with a reason"
grep -Fq "export { validateIP, isIPv4, isIPv6 }" "$MAIN_TS" ||
  fail "the address checks must be reachable from the settings form"

printf 'conflicting option checks passed\n'
