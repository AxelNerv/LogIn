#!/usr/bin/env bash
set -eo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SECTION_JS="$ROOT_DIR/luci-app-loghorizon/htdocs/luci-static/resources/view/loghorizon/section.js"
SOURCE_PO="$ROOT_DIR/fe-app-loghorizon/locales/loghorizon.ru.po"
PACKAGE_PO="$ROOT_DIR/luci-app-loghorizon/po/ru/loghorizon.po"

node - "$SECTION_JS" <<'NODE'
const fs = require("fs");
const source = fs.readFileSync(process.argv[2], "utf8");

function requireText(text) {
  if (!source.includes(text)) {
    console.error(`FAIL: missing provider visibility contract: ${text}`);
    process.exit(1);
  }
}

for (const text of [
  'function addProviderVisibilityNote(',
  '["bypass"]',
  '["zapret", "zapret2", "byedpi"]',
  '["connection"]',
  'Direct route: no additional encryption',
  'DPI bypass: not a VPN or encryption layer',
  'Proxy or VPN route',
  'destination IP and traffic sizes and timing',
  'server name is visible unless the application successfully uses ECH',
  'proxy or VPN server IP and tunnel traffic sizes and timing',
  'no direct fallback occurs',
]) {
  requireText(text);
}
NODE

for po in "$SOURCE_PO" "$PACKAGE_PO"; do
  for msgid in \
    "Provider visibility" \
    "Direct route: no additional encryption" \
    "DPI bypass: not a VPN or encryption layer" \
    "Proxy or VPN route"; do
    awk -v wanted="$msgid" '
      $0 == "msgid \"" wanted "\"" {
        getline
        if ($0 !~ /^msgstr ""$/)
          translated = 1
      }
      END { exit translated ? 0 : 1 }
    ' "$po" || {
      printf 'FAIL: missing Russian translation for %s in %s\n' "$msgid" "$po" >&2
      exit 1
    }
  done
done

printf 'Provider visibility UI checks passed\n'
