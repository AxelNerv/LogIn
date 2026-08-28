#!/usr/bin/env bash
set -eo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVER_RUNTIME="$ROOT_DIR/loghorizon/files/usr/lib/server/service.uc"
UCODE_LIB="$ROOT_DIR/loghorizon/files/usr/lib"
WORK_DIR="$(mktemp -d)"
STATE="$WORK_DIR/uci.state"
LOG="$WORK_DIR/uci.log"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  printf 'UCI state:\n' >&2
  cat "$STATE" >&2 2>/dev/null || true
  printf 'UCI log:\n' >&2
  cat "$LOG" >&2 2>/dev/null || true
  exit 1
}

mkdir -p "$WORK_DIR/bin"
cat >"$WORK_DIR/bin/sing-box" <<'SINGBOX'
#!/usr/bin/env bash
set -eo pipefail

case "$*" in
  "generate uuid")
    printf '%s\n' '33333333-3333-4333-8333-333333333333'
    ;;
  "generate rand --base64 18")
    printf '%s\n' 'generated-password'
    ;;
  "generate rand --hex 4")
    printf '%s\n' 'abcd1234'
    ;;
  "generate rand --hex 16")
    printf '%s\n' '11111111111111111111111111111111'
    ;;
  "generate reality-keypair")
    printf 'PrivateKey: private-key\nPublicKey: public-key\n'
    ;;
  *)
    printf 'unsupported sing-box command: %s\n' "$*" >&2
    exit 2
    ;;
esac
SINGBOX
chmod 0755 "$WORK_DIR/bin/sing-box"

cat >"$WORK_DIR/bin/logger" <<'LOGGER'
#!/usr/bin/env bash
set -eo pipefail
exit 0
LOGGER
chmod 0755 "$WORK_DIR/bin/logger"

export PATH="$WORK_DIR/bin:$PATH"
export LOGHORIZON_UCI_STATE_FILE="$STATE"
export LOGHORIZON_UCI_LOG_FILE="$LOG"
export LOGHORIZON_CONFIG_NAME="loghorizon"
export LOGHORIZON_SERVER_RUNTIME_UC="$SERVER_RUNTIME"

if grep -E 'uci -q|command -v uci' "$SERVER_RUNTIME" >/dev/null; then
  fail "server/service.uc must use ucode UCI access instead of shelling out to uci"
fi
if grep -F 'output("ucode "' "$SERVER_RUNTIME" >/dev/null; then
  fail "server defaults must not spawn service.uc without the logIn module path"
fi

cat >"$STATE" <<'EOF_STATE'
loghorizon.vless=server
loghorizon.vless.protocol=vless
loghorizon.vless.server_users=client|22222222-2222-4222-8222-222222222222|xtls-rprx-vision
loghorizon.socks=server
loghorizon.socks.protocol=socks
loghorizon.socks.label=desk
loghorizon.socks_open=server
loghorizon.socks_open.protocol=socks
loghorizon.socks_open.label=guest
loghorizon.socks_open.socks_auth_enabled=0
loghorizon.tailscale=server
loghorizon.tailscale.protocol=tailscale
loghorizon.json=server
loghorizon.json.protocol=json_inbound
loghorizon.mtproto=server
loghorizon.mtproto.protocol=mtproto
loghorizon.mtproto.mtproto_secret=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
loghorizon.mtproto_legacy=server
loghorizon.mtproto_legacy.protocol=mtproto
loghorizon.mtproto_legacy.server_users=client|eebbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb676f6f676c652e636f6d
EOF_STATE

ucode -L "$UCODE_LIB" "$SERVER_RUNTIME" prepare-all-defaults

uci_get() {
  awk -F= -v key="$1" '$1 == key { print substr($0, length($1) + 2); found = 1 } END { exit found ? 0 : 1 }' "$STATE"
}

assert_value() {
  local path="$1" expected="$2" actual
  actual="$(uci_get "$path" 2>/dev/null || true)"
  [ "$actual" = "$expected" ] || fail "$path: expected '$expected', got '$actual'"
}

assert_value loghorizon.vless.security reality
assert_value loghorizon.vless.listen 0.0.0.0
assert_value loghorizon.vless.listen_port 443
assert_value loghorizon.vless.server_uuid 22222222-2222-4222-8222-222222222222
assert_value loghorizon.vless.vless_flow xtls-rprx-vision
assert_value loghorizon.vless.reality_short_id abcd1234
assert_value loghorizon.vless.reality_private_key private-key
assert_value loghorizon.vless.reality_public_key public-key
assert_value loghorizon.socks.security none
assert_value loghorizon.socks.socks_auth_enabled 1
assert_value loghorizon.socks.server_username desk
assert_value loghorizon.socks.server_password generated-password
assert_value loghorizon.socks_open.socks_auth_enabled 0
assert_value loghorizon.socks_open.server_username guest
assert_value loghorizon.socks_open.server_password generated-password
assert_value loghorizon.tailscale.security none
assert_value loghorizon.tailscale.tailscale_control_url https://controlplane.tailscale.com
assert_value loghorizon.tailscale.tailscale_hostname loghorizon-tailscale
assert_value loghorizon.tailscale.tailscale_advertise_exit_node 1
assert_value loghorizon.json.security none
assert_value loghorizon.mtproto.mtproto_secret aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
assert_value loghorizon.mtproto_legacy.mtproto_secret bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
assert_value loghorizon.mtproto_legacy.mtproto_faketls google.com
grep -Fxq 'commit loghorizon' "$LOG" || fail 'expected config commit'

: >"$LOG"
ucode -L "$UCODE_LIB" "$SERVER_RUNTIME" prepare-all-defaults
[ ! -s "$LOG" ] || fail 'unchanged MTProto defaults must not rewrite or commit configuration on every reload'

printf 'server runtime checks passed\n'
