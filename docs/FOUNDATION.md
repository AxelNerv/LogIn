# LogHorizon foundation

`logIn` starts as a compatibility-preserving derivative of Forkop. The first milestone deliberately keeps the existing `forkop` UCI, RPC and service identifiers so the upstream backend remains testable while the product shell is developed.

## Naming layers

| Layer | Foundation milestone | Target namespace |
| --- | --- | --- |
| Product UI | `logIn` | `logIn` |
| Repository | `loghorizon` | `loghorizon` |
| OpenWrt package | `forkop` compatibility | `loghorizon` |
| LuCI package | `luci-app-forkop` compatibility | `luci-app-loghorizon` |
| UCI config | `/etc/config/forkop` | `/etc/config/loghorizon` |
| Service | `/etc/init.d/forkop` | `/etc/init.d/loghorizon` |

## Why the migration is staged

Forkop currently references its runtime namespace across the installer, build scripts, ucode imports, RPC ACLs, LuCI routes, tests and update manifests. Renaming all of these before a clean baseline build would make functional regressions hard to distinguish from branding work.

The safe sequence is:

1. Establish a reproducible upstream baseline.
2. Add the `logIn` product shell and design tokens.
3. Add LogHorizon-specific tests around configuration and upgrades.
4. Introduce a migration that copies existing UCI data and preserves rollback.
5. Rename package and runtime identifiers in one versioned change.

## Resource profiles

- **Lite (128 MB RAM):** no local AI runtime, compact sing-box build, one active DPI provider, reduced monitoring history.
- **Standard (256 MB RAM):** full interface, subscriptions, diagnostics, multiple installed DPI providers, remote AI recommendations as an optional client.
- Secrets are never sent to the AI integration and diagnostic exports must be masked before leaving the router.

