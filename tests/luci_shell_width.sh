#!/usr/bin/env bash
set -eo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STYLES_TS="$ROOT_DIR/fe-app-loghorizon/src/styles.ts"
ENTRY_JS="$ROOT_DIR/luci-app-loghorizon/htdocs/luci-static/resources/view/loghorizon/loghorizon.js"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

grep -Fq '.lh-page-container,' "$STYLES_TS" ||
  fail 'vendor-compatible host marker must be styled without :has() support'
grep -Fq '#maincontent.lh-page-maincontent {' "$STYLES_TS" ||
  fail 'the page main content override must not depend on :has() support'
grep -Fq 'max-width: min(1720px, calc(100vw - 32px)) !important;' "$STYLES_TS" ||
  fail 'vendor max-width constraints must be overridden'
grep -Fq 'width: calc(100% - 32px) !important;' "$STYLES_TS" ||
  fail 'desktop shell must override fixed-width vendor themes'
grep -Fq 'width: calc(100% - 16px) !important;' "$STYLES_TS" ||
  fail 'mobile shell must keep a small viewport gutter'
grep -Fq 'container.classList.add("lh-page-container");' "$ENTRY_JS" ||
  fail 'the rendered shell must mark its actual LuCI host container'
grep -Fq 'classList.add("lh-page-maincontent")' "$ENTRY_JS" ||
  fail 'the rendered shell must mark its actual LuCI main content'
grep -Fq 'new MutationObserver(mark)' "$ENTRY_JS" ||
  fail 'the host marker must wait until LuCI mounts the shell'

printf 'LuCI shell width checks passed\n'
