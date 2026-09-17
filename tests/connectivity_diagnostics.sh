#!/usr/bin/env bash
set -eo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOGHORIZON_LIB="$ROOT_DIR/loghorizon/files/usr/lib"
DIAGNOSTICS_UC="$LOGHORIZON_LIB/diagnostics/runtime.uc"
CLI="$ROOT_DIR/loghorizon/files/usr/bin/loghorizon"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

run_fixture() {
  printf '%s\n' "$1" | ucode -L "$LOGHORIZON_LIB" "$DIAGNOSTICS_UC" connectivity-probe-classify-fixture
}

assert_contains() {
  local output="$1"
  local expected="$2"
  local label="$3"
  printf '%s\n' "$output" | grep -Fq "$expected" || fail "$label: expected $expected, got $output"
}

success="$(run_fixture '{"status":0,"output":"204\t0.020\t0.065\t0.080\n"}')"
assert_contains "$success" '"available": 1' 'successful HTTPS probe'
assert_contains "$success" '"stage": "ok"' 'successful HTTPS stage'
assert_contains "$success" '"tcp_ms": 20' 'TCP timing'
assert_contains "$success" '"tls_ms": 45' 'TLS timing'
assert_contains "$success" '"total_ms": 80' 'total timing'

server_response="$(run_fixture '{"status":0,"output":"403\t0.010\t0.030\t0.040"}')"
assert_contains "$server_response" '"available": 1' 'HTTP response proves path availability'
assert_contains "$server_response" '"http_code": 403' 'HTTP status is reported without treating it as blocking'

tcp_timeout="$(run_fixture '{"status":28,"output":"000\t0.000\t0.000\t4.001"}')"
assert_contains "$tcp_timeout" '"stage": "tcp"' 'TCP timeout stage'
assert_contains "$tcp_timeout" '"reason": "tcp_timeout"' 'TCP timeout reason'

tls_failure="$(run_fixture '{"status":35,"output":"000\t0.018\t0.000\t0.031"}')"
assert_contains "$tls_failure" '"stage": "tls"' 'TLS failure stage'
assert_contains "$tls_failure" '"reason": "tls_failed"' 'TLS failure reason'

http_timeout="$(run_fixture '{"status":28,"output":"000\t0.015\t0.055\t8.001"}')"
assert_contains "$http_timeout" '"stage": "http"' 'HTTP timeout stage'
assert_contains "$http_timeout" '"reason": "http_timeout"' 'HTTP timeout reason'

dns_failure="$(run_fixture '{"status":6,"output":"000\t0.000\t0.000\t0.002"}')"
assert_contains "$dns_failure" '"stage": "dns"' 'DNS failure stage'

doq_success="$(printf '%s\n' '{"status":0,"output":"status: NOERROR\nQuery time: 71 msec\n","log_output":""}' | ucode -L "$LOGHORIZON_LIB" "$DIAGNOSTICS_UC" connectivity-doq-classify-fixture)"
assert_contains "$doq_success" '"available": 1' 'successful DoQ probe'
assert_contains "$doq_success" '"latency_ms": 71' 'DoQ query timing'

doq_timeout="$(printf '%s\n' '{"status":9,"output":"","log_output":"context deadline exceeded"}' | ucode -L "$LOGHORIZON_LIB" "$DIAGNOSTICS_UC" connectivity-doq-classify-fixture)"
assert_contains "$doq_timeout" '"reason": "doq_timeout"' 'DoQ timeout classification'

doq_tls="$(printf '%s\n' '{"status":1,"output":"","log_output":"TLS handshake: certificate verify failed"}' | ucode -L "$LOGHORIZON_LIB" "$DIAGNOSTICS_UC" connectivity-doq-classify-fixture)"
assert_contains "$doq_tls" '"reason": "doq_tls_failed"' 'DoQ TLS classification'

resources="$(printf '%s\n' '{"before":{"cpu":{"total":1000,"idle":800},"memory":{"total_kib":262144,"available_kib":131072},"load":{"one":"0.10","five":"0.20","fifteen":"0.30"},"conntrack":{"count":100,"max":16384},"nfqueue":{"available":1,"queues":2,"queued":0,"kernel_dropped":10,"userspace_dropped":3},"interfaces":[{"name":"wan","rx_dropped":20,"tx_dropped":5,"qdisc":{"available":1,"backlog_bytes":0,"backlog_packets":0,"requeues":0}}]},"after":{"cpu":{"total":1200,"idle":940},"memory":{"total_kib":262144,"available_kib":126976},"load":{"one":"0.20","five":"0.20","fifteen":"0.30"},"conntrack":{"count":110,"max":16384},"nfqueue":{"available":1,"queues":2,"queued":1,"kernel_dropped":12,"userspace_dropped":4},"interfaces":[{"name":"wan","rx_dropped":21,"tx_dropped":5,"qdisc":{"available":1,"backlog_bytes":1200,"backlog_packets":2,"requeues":1}}]}}' | ucode -L "$LOGHORIZON_LIB" "$DIAGNOSTICS_UC" connectivity-resource-fixture)"
assert_contains "$resources" '"cpu_percent": 30' 'CPU usage across diagnostic window'
assert_contains "$resources" '"kernel_dropped_delta": 2' 'NFQUEUE kernel drop delta'
assert_contains "$resources" '"userspace_dropped_delta": 1' 'NFQUEUE userspace drop delta'
assert_contains "$resources" '"rx_dropped_delta": 1' 'interface drop delta'
assert_contains "$resources" '"backlog_packets": 2' 'qdisc backlog snapshot'

selection="$(printf '%s\n' '{"config":{"route":{"final":"main","rules":[{"outbound":"discord"},{"outbound":"direct"},{"outbound":"cycle-a"}]}},"proxies":{"main":{"type":"Selector","now":"main-node"},"main-node":{"type":"VLESS","server":"203.0.113.10","uuid":"must-not-leak"},"discord":{"type":"Fallback","now":"discord-node"},"discord-node":{"type":"Hysteria2","server":"198.51.100.20","password":"must-not-leak"},"direct":{"type":"Direct"},"cycle-a":{"type":"Selector","now":"cycle-b"},"cycle-b":{"type":"Selector","now":"cycle-a"}}}' | ucode -L "$LOGHORIZON_LIB" "$DIAGNOSTICS_UC" connectivity-user-server-selection-fixture)"
assert_contains "$selection" '"tag": "main-node"' 'selected VLESS leaf'
assert_contains "$selection" '"type": "VLESS"' 'selected VLESS type'
assert_contains "$selection" '"tag": "discord-node"' 'selected Hysteria2 leaf'
assert_contains "$selection" '"type": "Hysteria2"' 'selected Hysteria2 type'
if printf '%s\n' "$selection" | grep -Eq '203\.0\.113\.10|198\.51\.100\.20|must-not-leak'; then
  fail 'active server selection leaked endpoint or credentials'
fi
if printf '%s\n' "$selection" | grep -Fq 'cycle-a'; then
  fail 'selector cycle must not become an active server'
fi

primary_server="$(printf '%s\n' '{"server":{"tag":"main-node","type":"VLESS"},"primary":{"available":1,"delay_ms":42},"fallback":{"available":0,"delay_ms":0}}' | ucode -L "$LOGHORIZON_LIB" "$DIAGNOSTICS_UC" connectivity-user-server-classify-fixture)"
assert_contains "$primary_server" '"reason": "primary_available"' 'primary active server control'
assert_contains "$primary_server" '"delay_ms": 42' 'primary active server latency'

fallback_server="$(printf '%s\n' '{"server":{"tag":"discord-node","type":"Hysteria2"},"primary":{"available":0,"delay_ms":0},"fallback":{"available":1,"delay_ms":67}}' | ucode -L "$LOGHORIZON_LIB" "$DIAGNOSTICS_UC" connectivity-user-server-classify-fixture)"
assert_contains "$fallback_server" '"degraded": 1' 'fallback active server control'
assert_contains "$fallback_server" '"reason": "fallback_available"' 'fallback active server reason'

failed_server="$(printf '%s\n' '{"server":{"tag":"offline","type":"VLESS"},"primary":{"available":0,"delay_ms":0},"fallback":{"available":0,"delay_ms":0}}' | ucode -L "$LOGHORIZON_LIB" "$DIAGNOSTICS_UC" connectivity-user-server-classify-fixture)"
assert_contains "$failed_server" '"available": 0' 'failed active server control'
assert_contains "$failed_server" '"reason": "server_unavailable"' 'failed active server reason'

history_entry="$(printf '%s\n' '{"available":1,"summary":"https_ok","target":"https://secret.example/path?token=must-not-leak","ipv4":{"available":1,"stage":"ok","reason":"server_responded","http_code":204,"tcp_ms":10,"tls_ms":20,"total_ms":30},"quic":{"supported":1,"available":1,"reason":"doq_available","targets":[{"name":"adguard","available":1,"reason":"doq_available","latency_ms":70}]},"user_servers":{"available":1,"reason":"servers_available","successful_servers":1,"server_count":1,"servers":[{"name":"vless://user:must-not-leak@example.test","type":"Hysteria2?token=must-not-leak","available":1,"reason":"primary_available","delay_ms":55}]},"resources":{"cpu_percent":12,"memory":{"total_kib":100,"available_kib":50},"load":{"one":"0.10","five":"0.20","fifteen":"0.30"},"conntrack":{"count":10,"max":100},"nfqueue":{"kernel_dropped_delta":0,"userspace_dropped_delta":0},"interfaces":[{"name":"wan-secret","rx_dropped_delta":1,"tx_dropped_delta":2,"qdisc":{"backlog_packets":3}}]}}' | ucode -L "$LOGHORIZON_LIB" "$DIAGNOSTICS_UC" connectivity-history-entry-fixture)"
assert_contains "$history_entry" '"timestamp": 1700000000' 'history timestamp'
assert_contains "$history_entry" '"type": "unknown"' 'unsafe protocol metadata is replaced'
assert_contains "$history_entry" '"interface_rx_drops": 1' 'history stores aggregate interface counters'
if printf '%s\n' "$history_entry" | grep -Eq 'secret\.example|must-not-leak|wan-secret|vless://'; then
  fail 'connectivity history leaked URL, server name, token, or interface name'
fi

ring="$(printf '%s\n' '{"history":{"entries":[{"timestamp":1},{"timestamp":2}]},"result":{"available":1,"summary":"https_ok"}}' | LOGHORIZON_DIAGNOSTICS_HISTORY_MAX_ENTRIES=2 ucode -L "$LOGHORIZON_LIB" "$DIAGNOSTICS_UC" connectivity-history-updated-fixture)"
assert_contains "$ring" '"max_entries": 2' 'history ring limit'
assert_contains "$ring" '"timestamp": 2' 'history keeps newest old entry'
assert_contains "$ring" '"timestamp": 1700000000' 'history appends new entry'
if printf '%s\n' "$ring" | grep -Fq '"timestamp": 1'; then
  fail 'history ring did not discard its oldest entry'
fi

grep -Fq 'check_connectivity_path: [ "diagnostics/runtime.uc", "check-connectivity-path", 0 ]' "$CLI" ||
  fail 'CLI must expose the bounded connectivity path diagnostic'
grep -Fq 'get_connectivity_history: [ "diagnostics/runtime.uc", "get-connectivity-history", 0 ]' "$CLI" ||
  fail 'CLI must expose manual connectivity history export'

printf 'Connectivity diagnostics tests passed\n'
