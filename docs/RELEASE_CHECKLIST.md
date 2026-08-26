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
| Package title and description | `forkop/Makefile`, `luci-app-forkop/Makefile`, `build.sh` | done — logIn |
| LuCI menu entry | `luci-app-forkop/root/usr/share/luci/menu.d/luci-app-forkop.json` | done — logIn |
| Frontend package name and licence | `fe-app-forkop/package.json` | done |
| Locale catalogue metadata | `fe-app-forkop/generate-pot.js`, `generate-po.js` | done — project identity, no personal contact |
| Package maintainer | `forkop/Makefile`, `luci-app-forkop/Makefile`, `build.sh` | done — `AxelNerv <AxelNerv@users.noreply.github.com>` |
| Project URL | `forkop/Makefile`, `build.sh` | done — AxelNerv/LogIn |
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
| `FORKOP_RELEASE_REPO` default | `core/constants.uc`, `components/action.uc`, `diagnostics/runtime.uc` | done — `AxelNerv/LogIn` |
| `SRS_SUPERCELL_URL` | `core/constants.uc`, `singbox/rulesets.uc` | kept upstream on purpose — community rule set, covered by attribution |

Installation and component updates now resolve against this repository, so they
only work once a release is published here. Publish one by pushing an `x.y.z`
tag: `build.yml` builds the ipk and apk packages and attaches them to the
release automatically.

## Before calling a build ready

1. `cd fe-app-forkop && yarn lint --max-warnings=0 && yarn test --run && yarn build`
   — the build must leave `main.js` unchanged in git.
2. `printf '%s\0' tests/*.sh | xargs -0 -n1 -P4 bash` — all backend checks pass.
3. `yarn locales:actualize`, then no empty `msgstr ""` remains in
   `locales/forkop.ru.po` except the catalogue header.
4. `bash tests/branding_owner.sh` — branding, locales and bundle are in sync.
5. Install on a spare router, not the one serving the household.
6. Confirm rollback: the previous package can be reinstalled and the existing
   `/etc/config/forkop` still loads.

## Still open before the namespace rename

The rename from `forkop` to `loghorizon` touches the installer, build scripts,
ucode imports, RPC ACLs, LuCI routes, tests and update manifests at once. It is
deliberately the last step; see [FOUNDATION.md](FOUNDATION.md) for the staged
sequence and the migration that has to copy existing UCI data first.
