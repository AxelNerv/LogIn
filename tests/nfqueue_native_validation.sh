#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$ROOT_DIR/loghorizon/files/usr/lib"
RUNTIME="$LIB/providers/zapret/runtime.uc"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

cat >"$WORK_DIR/nfqws" <<'EOF_NFQWS'
#!/bin/sh
printf '%s\n' "$*" >"$NFQWS_ARGUMENTS"
touch "$NFQWS_CALLED"
case " $* " in
  *' --dry-run '*) ;;
  *) printf 'dry-run flag is missing\n'; exit 3 ;;
esac
case " $* " in
  *' --dpi-desync=not-a-real-mode '*) printf 'invalid dpi-desync mode\n'; exit 4 ;;
esac
exit 0
EOF_NFQWS
chmod +x "$WORK_DIR/nfqws"

run_validation() {
  LOGHORIZON_LIB="$LIB" \
  ZAPRET_NFQWS_BIN="$WORK_DIR/nfqws" \
  ZAPRET_PROVIDER_NFQWS_BIN="$WORK_DIR/nfqws" \
  NFQWS_ARGUMENTS="$WORK_DIR/arguments" \
  NFQWS_CALLED="$WORK_DIR/called" \
    ucode -L "$LIB" -- "$RUNTIME" validate-strategy-fixture 65000 "$1"
}

valid="$(run_validation '--dpi-desync=fake --dpi-desync-repeats=2')"
JSON_VALUE="$valid" node - <<'NODE'
const result = JSON.parse(process.env.JSON_VALUE);
if (result.valid !== true || result.status !== 0) process.exit(1);
NODE
grep -Fq -- '--qnum=65000' "$WORK_DIR/arguments" || fail "native validation lost the managed queue"
grep -Fq -- '--dpi-desync-fwmark=' "$WORK_DIR/arguments" || fail "native validation lost provider base arguments"
grep -Fq -- '--dry-run' "$WORK_DIR/arguments" || fail "native validation did not use dry-run"

rm -f "$WORK_DIR/called"
if internal="$(run_validation '--qnum=1' 2>/dev/null)"; then
  fail "the internal validator accepted a managed queue override"
fi
[ ! -e "$WORK_DIR/called" ] || fail "native provider ran after internal validation failed"

if native="$(run_validation '--dpi-desync=not-a-real-mode' 2>/dev/null)"; then
  fail "the native provider failure was accepted"
fi
JSON_VALUE="$native" node - <<'NODE'
const result = JSON.parse(process.env.JSON_VALUE);
if (result.valid !== false || result.status !== 4 || !result.message.includes('invalid dpi-desync mode')) process.exit(1);
NODE

printf 'NFQUEUE native validation checks passed\n'
