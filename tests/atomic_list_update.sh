#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOGHORIZON_LIB="$ROOT_DIR/loghorizon/files/usr/lib"
UPDATES="$LOGHORIZON_LIB/components/updates.uc"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

RULESET_DIR="$WORK_DIR/rulesets"
TARGET="$RULESET_DIR/demo-lists-ruleset.json"
mkdir -p "$RULESET_DIR"

cat >"$WORK_DIR/good.lst" <<'EOF_LIST'
new.example
203.0.113.0/24
EOF_LIST

write_fixture() {
  local include_missing="$1"
  node - "$WORK_DIR/fixture.json" "$WORK_DIR/good.lst" "$WORK_DIR/missing.lst" "$include_missing" <<'NODE'
const fs = require('node:fs');
const [output, good, missing, includeMissing] = process.argv.slice(2);
const lists = includeMissing === '1' ? [good, missing] : [good];
fs.writeFileSync(output, JSON.stringify({
  settings: { '.name': 'settings', '.type': 'settings' },
  sections: [{
    '.name': 'demo', '.type': 'section', enabled: '1', action: 'dns',
    domain_ip_lists: lists
  }]
}));
NODE
}

old='{"version":3,"rules":[{"domain_suffix":["old.example"]}]}'
printf '%s\n' "$old" >"$TARGET"
write_fixture 1
if LOGHORIZON_LIB="$LOGHORIZON_LIB" TMP_RULESET_FOLDER="$RULESET_DIR" ucode -L "$LOGHORIZON_LIB" "$UPDATES" \
    rebuild-domain-ip-lists-fixture "$WORK_DIR/fixture.json" demo >/dev/null 2>&1; then
  fail "a missing source must fail the staged update"
fi
grep -Fq 'old.example' "$TARGET" || fail "failed update replaced the last-known-good rule set"
if grep -Fq 'new.example' "$TARGET"; then
  fail "failed update published a partial candidate"
fi
if find "$RULESET_DIR" -name '*.candidate.*' -print -quit | grep -q .; then
  fail "failed update left a candidate file behind"
fi

write_fixture 0
LOGHORIZON_LIB="$LOGHORIZON_LIB" TMP_RULESET_FOLDER="$RULESET_DIR" ucode -L "$LOGHORIZON_LIB" "$UPDATES" \
  rebuild-domain-ip-lists-fixture "$WORK_DIR/fixture.json" demo >/dev/null
grep -Fq 'new.example' "$TARGET" || fail "successful update did not publish the new rules"
if grep -Fq 'old.example' "$TARGET"; then
  fail "successful update kept stale rule contents"
fi

printf '%s\n' '# no valid rules' >"$WORK_DIR/empty.lst"
node - "$WORK_DIR/fixture.json" "$WORK_DIR/empty.lst" <<'NODE'
const fs = require('node:fs');
fs.writeFileSync(process.argv[2], JSON.stringify({
  settings: { '.name': 'settings', '.type': 'settings' },
  sections: [{ '.name': 'demo', '.type': 'section', enabled: '1', action: 'dns', domain_ip_lists: [process.argv[3]] }]
}));
NODE
if LOGHORIZON_LIB="$LOGHORIZON_LIB" TMP_RULESET_FOLDER="$RULESET_DIR" ucode -L "$LOGHORIZON_LIB" "$UPDATES" \
    rebuild-domain-ip-lists-fixture "$WORK_DIR/fixture.json" demo >/dev/null 2>&1; then
  fail "an empty candidate must not replace the working rule set"
fi
grep -Fq 'new.example' "$TARGET" || fail "empty update replaced the last-known-good rule set"

mkdir -p "$WORK_DIR/bin"
cat >"$WORK_DIR/bin/sing-box" <<'EOF_SING_BOX'
#!/bin/sh
input="$3"
output="$5"
case "$(cat "$input")" in
  binary-ok) printf '{"version":3,"rules":[]}\n' >"$output" ;;
  binary-malformed) printf 'not json\n' >"$output" ;;
  *) exit 1 ;;
esac
EOF_SING_BOX
chmod +x "$WORK_DIR/bin/sing-box"
printf 'binary-ok' >"$WORK_DIR/valid.srs"
printf 'binary-malformed' >"$WORK_DIR/malformed.srs"
printf 'binary-bad' >"$WORK_DIR/invalid.srs"
LOGHORIZON_LIB="$LOGHORIZON_LIB" PATH="$WORK_DIR/bin:$PATH" ucode -L "$LOGHORIZON_LIB" "$UPDATES" \
  validate-binary-ruleset-fixture "$WORK_DIR/valid.srs" >/dev/null ||
  fail "a structurally valid community SRS was rejected"
if LOGHORIZON_LIB="$LOGHORIZON_LIB" PATH="$WORK_DIR/bin:$PATH" ucode -L "$LOGHORIZON_LIB" "$UPDATES" \
    validate-binary-ruleset-fixture "$WORK_DIR/malformed.srs" >/dev/null 2>&1; then
  fail "malformed decompiled JSON was accepted"
fi
if LOGHORIZON_LIB="$LOGHORIZON_LIB" PATH="$WORK_DIR/bin:$PATH" ucode -L "$LOGHORIZON_LIB" "$UPDATES" \
    validate-binary-ruleset-fixture "$WORK_DIR/invalid.srs" >/dev/null 2>&1; then
  fail "a rejected community SRS was accepted"
fi

printf 'atomic list update checks passed\n'
