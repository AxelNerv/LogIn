#!/usr/bin/env bash
set -eo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BRAND_TS="$ROOT_DIR/fe-app-loghorizon/src/brand.ts"
STYLES_TS="$ROOT_DIR/fe-app-loghorizon/src/styles.ts"
ENTRY_JS="$ROOT_DIR/luci-app-loghorizon/htdocs/luci-static/resources/view/loghorizon/loghorizon.js"
BUNDLE_JS="$ROOT_DIR/luci-app-loghorizon/htdocs/luci-static/resources/view/loghorizon/main.js"
MENU_JSON="$ROOT_DIR/luci-app-loghorizon/root/usr/share/luci/menu.d/luci-app-loghorizon.json"
SOURCE_POT="$ROOT_DIR/fe-app-loghorizon/locales/loghorizon.pot"
SOURCE_PO="$ROOT_DIR/fe-app-loghorizon/locales/loghorizon.ru.po"
PACKAGE_PO="$ROOT_DIR/luci-app-loghorizon/po/ru/loghorizon.po"
POT_GENERATOR="$ROOT_DIR/fe-app-loghorizon/generate-pot.js"
PO_GENERATOR="$ROOT_DIR/fe-app-loghorizon/generate-po.js"
BACKEND_MAKEFILE="$ROOT_DIR/loghorizon/Makefile"
LUCI_MAKEFILE="$ROOT_DIR/luci-app-loghorizon/Makefile"
BUILD_SCRIPT="$ROOT_DIR/build.sh"
CODEOWNERS="$ROOT_DIR/.github/CODEOWNERS"
PROJECT_REPO='https://github.com/AxelNerv/LogIn'
SHELL_DESCRIPTION='Routing, subscriptions and DPI control for OpenWrt'
SHELL_MARKER='logIn / LogHorizon foundation shell'

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

# --- Identity is defined in exactly one place -------------------------------

grep -Fq "displayName: 'logIn'" "$BRAND_TS" ||
  fail "brand.ts must define logIn as the display name"
grep -Fq "internalName: 'loghorizon'" "$BRAND_TS" ||
  fail "brand.ts must keep loghorizon as the internal namespace"
grep -Fq "prefix: 'log'" "$BRAND_TS" ||
  fail "brand.ts must define the wordmark prefix"
grep -Fq "accent: 'In'" "$BRAND_TS" ||
  fail "brand.ts must define the wordmark accent"

# Prose belongs in the view as a literal, never in brand.ts: extract-calls.js
# only sees string literals inside _(), so a constant would never be translated.
if grep -Eq '^[[:space:]]*description:' "$BRAND_TS"; then
  fail "brand.ts must not carry user-facing prose; keep it as a literal in the view"
fi
if grep -Fq '_(main.' "$ENTRY_JS"; then
  fail "loghorizon.js passes a variable to _(); the string would never reach the .pot"
fi

grep -Fq '"title": "logIn"' "$MENU_JSON" ||
  fail "LuCI menu entry must be titled logIn"

# --- Retired Forkop strings are gone from code and locales ------------------

for stale in 'Forkop Settings' 'Configuration for Forkop service'; do
  if grep -Fq "$stale" "$ENTRY_JS" "$SOURCE_POT" "$SOURCE_PO" "$PACKAGE_PO"; then
    fail "retired string must not remain anywhere: $stale"
  fi
done

# --- The shell description is extractable and translated --------------------

grep -Fq "_(\"$SHELL_DESCRIPTION\")" "$ENTRY_JS" ||
  fail "loghorizon.js must render the shell description as a translatable literal"
grep -Fq "msgid \"$SHELL_DESCRIPTION\"" "$SOURCE_POT" ||
  fail "shell description must be extracted into the .pot; run yarn locales:actualize"

for po in "$SOURCE_PO" "$PACKAGE_PO"; do
  awk -v key="msgid \"$SHELL_DESCRIPTION\"" '
    $0 == key {
      getline
      if ($0 != "msgstr \"\"")
        found = 1
    }
    END { exit found ? 0 : 1 }
  ' "$po" || fail "shell description must have a Russian translation in $po"
done

# --- Locale metadata carries no third-party contact -------------------------

if grep -Fq 'ushan0v' "$POT_GENERATOR" "$PO_GENERATOR"; then
  fail "locale generators must not embed upstream author contacts"
fi

# --- The generated bundle matches the stylesheet source ---------------------

extract_shell_css() {
  awk -v marker="$SHELL_MARKER" '
    index($0, marker) { found = 1 }
    found {
      if ($0 ~ /^`;/) exit
      print
    }
  ' "$1"
}

source_css="$(extract_shell_css "$STYLES_TS")"
bundle_css="$(extract_shell_css "$BUNDLE_JS")"

[ -n "$source_css" ] ||
  fail "shell stylesheet block not found in styles.ts"
[ -n "$bundle_css" ] ||
  fail "shell stylesheet block not found in the generated main.js; run yarn build"
# A mismatch usually means the bundle was not rebuilt. It can also mean the
# stylesheet block gained a non-ASCII character: esbuild escapes those to
# \uXXXX in the bundle, so keep the shell CSS block plain ASCII.
[ "$source_css" = "$bundle_css" ] ||
  fail "generated main.js does not match styles.ts; run yarn build, and keep the shell CSS ASCII-only"

# --- Only the three approved spellings appear in documentation --------------

while IFS= read -r doc; do
  # brand-spec.md is the document that defines the rule, so it is the one
  # place allowed to quote the forbidden spellings.
  [ "$doc" = "$ROOT_DIR/brand-spec.md" ] && continue

  # AxelNerv/LogIn is the GitHub repository name, which GitHub fixed when the
  # repository was created; it is an identifier, not the written product name.
  if sed 's|AxelNerv/LogIn|AxelNerv/REPO|g' "$doc" |
    grep -Eq '\b(LogIn|Login|LOGIN)\b'; then
    fail "documentation must spell the product logIn: $doc"
  fi
done < <(
  find "$ROOT_DIR/docs" "$ROOT_DIR" -maxdepth 1 -name '*.md' -type f
  find "$ROOT_DIR/design" -maxdepth 1 -name '*.html' -type f
)

# --- Ownership metadata points at this project, not upstream ----------------

grep -Fq "PKG_MAINTAINER:=AxelNerv" "$BACKEND_MAKEFILE" ||
  fail "loghorizon/Makefile must name the current maintainer"
grep -Fq "LUCI_MAINTAINER:=AxelNerv" "$LUCI_MAKEFILE" ||
  fail "luci-app-loghorizon/Makefile must name the current maintainer"
grep -Fq "URL:=$PROJECT_REPO" "$BACKEND_MAKEFILE" ||
  fail "loghorizon/Makefile must point at the logIn repository"
grep -Fq "PROJECT_URL=\"$PROJECT_REPO\"" "$BUILD_SCRIPT" ||
  fail "build.sh must point at the logIn repository"
grep -Fq '@AxelNerv' "$CODEOWNERS" ||
  fail "CODEOWNERS must name the current owner"

# --- The retired namespace is gone from everything but attribution ----------

# Documentation still names Forkop as the project this code derives from, and
# this file quotes the retired strings it checks for. Everything else must be
# free of the old namespace and of its CSS prefix.
while IFS= read -r tracked; do
  case "$tracked" in
    *.md | tests/branding_owner.sh) continue ;;
  esac
  if grep -qiE 'forkop|fkp[-_]' "$ROOT_DIR/$tracked"; then
    fail "the retired forkop namespace is back in $tracked"
  fi
done < <(git -C "$ROOT_DIR" ls-files)

printf 'branding ownership checks passed\n'
