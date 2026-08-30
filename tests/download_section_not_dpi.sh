#!/usr/bin/env bash
set -eo pipefail

# Zapret mangles packets on the direct path. It has no outbound, so a download
# cannot travel "through" it, yet it was offered as a source for the list and
# component downloads. Choosing one made sing-box fetch its rule sets over a
# path that is not up when it starts, and the service died on a live router:
#
#   start service: initialize rule-set[1]: initial rule-set:
#   dpiDS-youtube-community-ruleset: Get ".../youtube.srs":
#   lookup github.com: exchange4: context deadline exceeded
#
# ByeDPI is different: it provides a real local proxy, so it stays on offer.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOGHORIZON_LIB="$ROOT_DIR/loghorizon/files/usr/lib"
VALIDATOR="$LOGHORIZON_LIB/config/validator.uc"
MIGRATION="$LOGHORIZON_LIB/config/migration.uc"
SETTINGS_JS="$ROOT_DIR/luci-app-loghorizon/htdocs/luci-static/resources/view/loghorizon/settings.js"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

# --- Neither side offers a mangling section anymore -------------------------

awk '
  /function download_section_action_available\(/ { inside = 1 }
  inside && /action == "zapret"/ { found = 1 }
  inside && /^}/ { exit }
  END { exit found ? 1 : 0 }
' "$VALIDATOR" ||
  fail "the validator must not accept a zapret section as a download source"

awk '
  /function isDownloadSectionAction\(/ { inside = 1 }
  inside && /case "zapret"/ { found = 1 }
  inside && /^}/ { exit }
  END { exit found ? 1 : 0 }
' "$SETTINGS_JS" ||
  fail "the interface must not offer a zapret section as a download source"

# ByeDPI is a proxy and must survive both cuts.
grep -Fq 'if (action == "byedpi")' "$VALIDATOR" ||
  fail "byedpi must still be accepted as a download source"
grep -Fq 'case "byedpi":' "$SETTINGS_JS" ||
  fail "byedpi must still be offered as a download source"

# --- An existing router must not be bricked by the upgrade ------------------

grep -Fq '{ id: "download_via_dpi_section", run: migrate_download_via_dpi_section }' "$MIGRATION" ||
  fail "the migration must be registered so it runs once per configuration"

cat >"$WORK_DIR/fixture.json" <<'JSON'
{
  "settings": {
    ".name": "settings",
    ".type": "settings",
    "config_version": "1.0.5",
    "download_lists_via_proxy": "1",
    "download_lists_via_proxy_section": "dpiDS",
    "download_components_via_proxy_section": "vpn"
  },
  "section": [
    { ".name": "dpiDS", ".type": "section", "enabled": "1", "action": "zapret" },
    { ".name": "vpn", ".type": "section", "enabled": "1", "action": "connection" }
  ]
}
JSON

LOGHORIZON_LIB="$LOGHORIZON_LIB" ucode -L "$LOGHORIZON_LIB" "$MIGRATION" \
  migrate-fixture "$WORK_DIR/fixture.json" >"$WORK_DIR/output.json" ||
  fail "the migration failed to run over the fixture"

node - "$WORK_DIR/output.json" <<'NODE'
const fs = require('fs');
const out = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const settings = out.config.settings ?? {};
const fail = (m) => { process.stderr.write(`FAIL: ${m}\n`); process.exit(1); };

if (settings.download_lists_via_proxy_section !== undefined) {
  fail('a pointer at a zapret section must be cleared, not left to fail validation');
}
if (settings.download_components_via_proxy_section !== 'vpn') {
  fail('a pointer at a connection section must be left alone');
}

const applied = settings.applied_migrations ?? [];
const list = Array.isArray(applied) ? applied : [applied];
if (!list.includes('download_via_dpi_section')) {
  fail('the migration must record itself so it does not run twice');
}
process.stdout.write('fixture checks passed\n');
NODE

printf 'download source checks passed\n'
