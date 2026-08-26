# logIn · Brand Spec
> Captured: 2026-08-26
> Source: user brief and the existing Forkop/OpenWrt interface
> Completeness: foundation draft

## Core identity

### Name
- Display: `logIn`
- Internal namespace: `loghorizon`
- Wordmark treatment: lowercase `log` with emphasized `In`.
- The wordmark is text-only until a final logo is approved.

#### Spelling rules
Three written forms exist in prose. Anything else is a mistake.

| Form | Where it is used |
| --- | --- |
| `logIn` | every user-facing surface and all prose, including sentence starts |
| `LogHorizon` | the project/codename in prose, when the repository itself is meant |
| `loghorizon` | identifiers: packages, UCI, service, directories |

`LogIn`, `Login` and `LOGIN` are never correct in prose. Two identifiers are
exceptions, because they are names of things rather than written names:

- `LOGIN_BRAND` — the source-code constant.
- `AxelNerv/LogIn` — the GitHub repository at
  <https://github.com/AxelNerv/LogIn>. GitHub fixed this spelling when the
  repository was created; write it exactly as GitHub stores it inside URLs and
  clone commands, and use `logIn` everywhere else. The internal package
  namespace stays `loghorizon` and is unaffected by the repository name.

### Product UI context
- Platform: desktop-first LuCI administration interface with responsive tablet/mobile fallback.
- Existing UI source: Forkop TypeScript/LuCI frontend.
- Reference screenshot: user's dark OpenWrt status interface.

## Foundation direction · Operator Calm

### Color palette
- Canvas: `#0d1113`
- Surface: `#151a1d`
- Raised surface: `#1b2225`
- Border: `#2b3538`, strong border: `#3b494d`
- Ink: `#edf2ef`
- Muted ink: `#91a09a`, faint ink: `#6f7d78`
- Primary/status accent: `#45d483`, ink on accent: `#07150d`
- Warning: `#e6b85c`
- Error: `#ef6b67`

Operator Calm is **dark only**. The `.lh-shell` container declares
`color-scheme: dark` and defines every colour from the list above instead of
inheriting LuCI theme variables. `luci-theme-bootstrap` does not declare
`--border-color-low` or `--background-color-high`, so a theme-variable
approach with dark fallbacks rendered dark borders on a light page. On a light
router theme the logIn interface therefore reads as a deliberate dark panel.

### Typography
- UI: `Aptos`, `Segoe UI Variable`, sans-serif.
- Data: `Cascadia Mono`, `Consolas`, monospace.
- Custom web fonts are intentionally omitted in the router build to reduce package size.

### Layout
- Spacing grid: `4 / 8 / 12 / 16 / 24 / 32`.
- Radius: `3 / 6 / 10`; large pill shapes are avoided.
- Dashboard: four summary cells, followed by full-width routing groups.
- Status is communicated by text, color and shape together.

### Vibe keywords
- operational
- calm
- legible
- trustworthy
- compact

## Completeness notes
- Final logo, icon and public-facing brand guidelines do not exist yet.
- Operator Calm is the single approved product direction.
