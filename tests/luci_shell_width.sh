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

main_content_styles="$(sed -n '/^#maincontent.lh-page-maincontent:not(.lh-page-container),$/,/^}$/p' "$STYLES_TS")"
for declaration in \
  'width: 100% !important;' \
  'max-width: none !important;' \
  'min-width: 0 !important;' \
  'margin: 0 !important;' \
  'box-sizing: border-box !important;'; do
  grep -Fq "$declaration" <<<"$main_content_styles" ||
    fail "outer main content must fill the theme flex column: $declaration"
done

grep -Fq 'max-width: min(1720px, calc(100vw - 16px)) !important;' "$STYLES_TS" ||
  fail 'mobile container cap must preserve the 16px gutter in self-container themes'

host_styles="$(sed -n '/^\.main-right.lh-page-host {$/,/^}$/p' "$STYLES_TS")"
grep -Fq 'flex: 1 1 auto !important;' <<<"$host_styles" ||
  fail 'the theme content host must participate in flex sizing'
grep -Fq 'min-width: 0 !important;' <<<"$host_styles" ||
  fail 'the theme content host must shrink independently of tab content'
grep -Fq 'container.classList.add("lh-page-container");' "$ENTRY_JS" ||
  fail 'the rendered shell must mark its actual LuCI host container'
grep -Fq 'classList.add("lh-page-maincontent")' "$ENTRY_JS" ||
  fail 'the rendered shell must mark its actual LuCI main content'
grep -Fq 'container.style.setProperty("max-width", "1720px", "important");' "$ENTRY_JS" ||
  fail 'a late vendor max-width must be overridden inline'
grep -Fq 'mainContent.style.setProperty("max-width", "none", "important");' "$ENTRY_JS" ||
  fail 'the vendor main-content cap must be removed inline'
grep -Fq 'mainContent.style.setProperty("width", "100%", "important");' "$ENTRY_JS" ||
  fail 'outer main content must have a definite width before sizing its inner container'
grep -Fq 'mainContent.style.setProperty("margin", "0", "important");' "$ENTRY_JS" ||
  fail 'outer main content must not inherit auto cross-axis margins'
grep -Fq 'wrapper.classList.add("lh-page-wrapper");' "$ENTRY_JS" ||
  fail 'nested container ancestors must not restore content-based sizing'
grep -Fq 'new MutationObserver(mark)' "$ENTRY_JS" ||
  fail 'the layout normalizer must retry if LuCI has not mounted its container yet'
grep -Fq 'width: min(1180px, calc(100vw - 32px)) !important;' "$STYLES_TS" ||
  fail 'rule editor modal must keep a readable desktop width'
grep -Fq 'grid-template-columns: minmax(180px, 240px) minmax(0, 1fr);' "$STYLES_TS" ||
  fail 'rule editor fields must use the available desktop width'
grep -Fq 'grid-template-columns: minmax(0, 1fr);' "$STYLES_TS" ||
  fail 'rule editor fields must collapse to one mobile column'
grep -Fq 'visibility: visible !important;' "$STYLES_TS" ||
  fail 'mobile rule labels must override vendor theme hiding'
if grep -Eq 'cbi-modal \.cbi-value \{' "$STYLES_TS"; then
  fail 'rule editor grid must not override LuCI .hidden on dependent fields'
fi
grep -Fq '.modal.cbi-modal .cbi-value:not(.hidden) {' "$STYLES_TS" ||
  fail 'rule editor grid must apply only to visible field rows'

printf 'LuCI shell width checks passed\n'
