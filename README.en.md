# logIn

> Русская версия: [README.md](README.md)

`logIn` is an OpenWrt routing and DPI-control project, hosted at <https://github.com/AxelNerv/LogIn>. `loghorizon` is the internal namespace for its future packages, services and configuration.

The foundation milestone is based on [Forkop](https://github.com/ushan0v/forkop), which in turn is derived from [Podkop](https://github.com/itdoginfo/podkop). It retains the existing routing, subscription, diagnostics and DPI-provider functionality while a new product shell and a staged runtime migration are developed.

> **Status:** foundation development. Do not install on a production router — the installer deliberately displaces both podkop and podkop-plus: it stops the service, disables autostart, removes the packages and migrates the configuration into logIn.

## Installation

```sh
sh <(wget -O - https://raw.githubusercontent.com/AxelNerv/LogIn/main/install.sh)
```

The installer pulls packages from `AxelNerv/LogIn` releases, detects the package format (ipk for OpenWrt 24.10, apk for 25.12 and newer) and installs dependencies. Packages are built with `PKGARCH:=all`, so one build fits any router.

## Removal

```sh
sh <(wget -O - https://raw.githubusercontent.com/AxelNerv/LogIn/main/uninstall.sh)
```

Stops the service, hands dnsmasq back, drops the firewall rules and removes the packages, including the sing-box build and DPI engines logIn installed on demand. The router is then ready for another routing package: verified by installing podkop straight afterwards.

`--keep-config` keeps `/etc/config/loghorizon`; `--keep-components` leaves sing-box and the DPI engines in place.

## Current milestone

- `logIn` branding in LuCI.
- Operator Calm interface foundation as the single product design.
- Own `loghorizon` namespace: packages, service, configuration and paths.
- Podkop migration on install; there is nothing to migrate from forkop.
- Standard target for 256 MB RAM and a planned Lite profile for 128 MB RAM.

## Local frontend checks

```sh
cd fe-app-loghorizon
yarn install --frozen-lockfile
yarn lint --max-warnings=0
yarn test --run
yarn build
```

The generated LuCI bundle is written to `luci-app-loghorizon/htdocs/luci-static/resources/view/loghorizon/main.js` during the compatibility milestone. It is committed to the repository, and CI fails if a rebuild changes it — always rebuild after touching `fe-app-loghorizon/src`.

Backend checks are plain bash scripts:

```sh
printf '%s\0' tests/*.sh | xargs -0 -n1 -P4 bash
```

## Translations

Interface strings are English in source and translated into Russian through gettext. The extractor only sees string literals inside `_()`, so a string built from a variable never reaches the catalogue. After adding or changing any interface text:

```sh
cd fe-app-loghorizon
yarn locales:actualize
```

Then fill in the new `msgstr ""` entries in `locales/loghorizon.ru.po` and run `node distribute-locales.js`.

## Design preview

Open `design/logIn Operator Calm.html` in a browser. Operator Calm is the single product direction: dark, quiet, status-oriented and lightweight enough for LuCI. The interface is dark only and does not follow the LuCI theme.

## Project notes

- [Foundation and namespace migration](docs/FOUNDATION.md)
- [Information architecture](docs/INFORMATION_ARCHITECTURE.md)
- [Routing profiles and managed networks](docs/ROUTING_AND_NETWORKS.md)
- [Release checklist](docs/RELEASE_CHECKLIST.md)
- [Product facts](product-facts.md)
- [Brand foundation](brand-spec.md)

## License and attribution

The derivative router code remains licensed under GPL-2.0-or-later. Copyright and attribution notices inherited from Forkop and Podkop must remain intact. Independently developed components may be documented separately when they are introduced.
