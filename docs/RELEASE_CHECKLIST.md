# Release checklist

Status: living document. "Release" here means the private build handed to the
owner and two or three other people — not a public launch.

## What must stay, by licence

The router code is a derivative of Forkop, which derives from Podkop, and it is
distributed under GPL-2.0-or-later. Handing a build to three people is still
distribution, so these are obligations rather than preferences:

- `LICENSE` stays as it is, unmodified.
- Copyright headers inside inherited source files stay.
- Attribution to Forkop and Podkop stays somewhere visible in the project —
  the README section is enough.
- Anyone who receives a binary can ask for the corresponding source.

Removing these would make the distribution unlicensed, which is a bigger
problem than a branding inconsistency.

## What is free to change

Everything below is project metadata or presentation, not a licence term:

The project lives at <https://github.com/AxelNerv/LogIn>.

| Item | Location | State |
| --- | --- | --- |
| Package title and description | `loghorizon/Makefile`, `luci-app-loghorizon/Makefile`, `build.sh` | done — logIn |
| LuCI menu entry | `luci-app-loghorizon/root/usr/share/luci/menu.d/luci-app-loghorizon.json` | done — logIn |
| Frontend package name and licence | `fe-app-loghorizon/package.json` | done |
| Locale catalogue metadata | `fe-app-loghorizon/generate-pot.js`, `generate-po.js` | done — project identity, no personal contact |
| Package maintainer | `loghorizon/Makefile`, `luci-app-loghorizon/Makefile`, `build.sh` | done — `AxelNerv <AxelNerv@users.noreply.github.com>` |
| Project URL | `loghorizon/Makefile`, `build.sh` | done — AxelNerv/LogIn |
| Repository owner | `.github/CODEOWNERS` | done — was still `@itdoginfo`, inherited from Podkop |
| Issue and README links | `.github/ISSUE_TEMPLATE/*`, `singbox/runtime.uc`, `renderWikiDisclaimer.ts` | done |
| README, docs, brand spec | repository root, `docs/` | done |

The GitHub noreply address is used deliberately instead of a personal mailbox:
these values are embedded in every built package and in anything handed to
another person. Swap it for a different contact if you prefer.

## Download endpoints

| Value | Location | State |
| --- | --- | --- |
| `REPO_OWNER` / `REPO_NAME` | `install.sh` | done — `AxelNerv/LogIn` |
| `LOGHORIZON_RELEASE_REPO` default | `core/constants.uc`, `components/action.uc`, `diagnostics/runtime.uc` | done — `AxelNerv/LogIn` |
| `SRS_SUPERCELL_URL` | `core/constants.uc`, `singbox/rulesets.uc` | kept upstream on purpose — community rule set, covered by attribution |

Installation and component updates now resolve against this repository, so they
only work once a release is published here. Publish one by pushing an `x.y.z`
tag: `build.yml` builds the ipk and apk packages and attaches them to the
release automatically.

## Before calling a build ready

1. `cd fe-app-loghorizon && yarn lint --max-warnings=0 && yarn test --run && yarn build`
   — the build must leave `main.js` unchanged in git.
2. `printf '%s\0' tests/*.sh | xargs -0 -n1 -P4 bash` — all backend checks pass.
3. `yarn locales:actualize`, then no empty `msgstr ""` remains in
   `locales/loghorizon.ru.po` except the catalogue header.
4. `bash tests/branding_owner.sh` — branding, locales and bundle are in sync.
5. Install on a spare router, not the one serving the household.
6. Confirm rollback: the previous package can be reinstalled and the existing
   `/etc/config/loghorizon` still loads.

## Namespace rename

Done. Packages, paths, services, the UCI config, LuCI routes and every
`LOGHORIZON_*` environment override now carry the `loghorizon` name; see
[FOUNDATION.md](FOUNDATION.md) for the full table. There is no migration from
an installed `forkop`, because nothing ever ran under that name outside test
builds. The Podkop migration stays: that is the real upgrade path.
