# LogHorizon foundation

`logIn` began as a compatibility-preserving derivative of Forkop and now owns
its runtime namespace. Every package, path, service and configuration
identifier carries the `loghorizon` name; `logIn` is the product name shown to
the user, and `Forkop` survives only as attribution for the code this project
derives from.

## Naming layers

| Layer | Name |
| --- | --- |
| Product UI | `logIn` |
| Repository | `AxelNerv/LogIn` |
| Internal namespace | `loghorizon` |
| OpenWrt package | `loghorizon` |
| LuCI package | `luci-app-loghorizon` |
| Translations | `luci-i18n-loghorizon-ru` |
| UCI config | `/etc/config/loghorizon` |
| Service | `/etc/init.d/loghorizon` |
| Runtime library | `/usr/lib/loghorizon` |
| LuCI resources | `/www/luci-static/resources/view/loghorizon` |

The package cannot be called `login`: `/bin/login` already exists on every
OpenWrt system, so the name would collide. `loghorizon` is the internal name
precisely to keep that collision impossible.

## Why the rename came last

Forkop referenced its runtime namespace across the installer, build scripts,
ucode imports, RPC ACLs, LuCI routes, tests and update manifests. Renaming all
of that before a clean baseline build would have made functional regressions
indistinguishable from branding work, so the sequence was:

1. Establish a reproducible upstream baseline.
2. Add the `logIn` product shell and design tokens.
3. Add LogHorizon-specific tests around branding, configuration and upgrades.
4. Take ownership of distribution: maintainer, project URL, release endpoints.
5. Rename package and runtime identifiers in one versioned change.

Step five is done. There is deliberately **no migration from an installed
`forkop`**: nothing was ever running under that name outside test builds, so
the installer carries only the Podkop migration, which is the real upgrade path
for existing users.

## Resource profiles

- **Lite (128 MB RAM):** no local AI runtime, compact sing-box build, one active DPI provider, reduced monitoring history.
- **Standard (256 MB RAM):** full interface, subscriptions, diagnostics, multiple installed DPI providers, remote AI recommendations as an optional client.
- Secrets are never sent to the AI integration and diagnostic exports must be masked before leaving the router.
