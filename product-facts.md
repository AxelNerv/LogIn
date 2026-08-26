# logIn / LogHorizon facts
> Verified: 2026-08-26
> Status: private concept owned by the user; technical foundation verified against upstream
> Sources: https://github.com/ushan0v/forkop, https://github.com/itdoginfo/podkop

## Product status
- `logIn` is the user-facing product name.
- The repository is `AxelNerv/LogIn` at https://github.com/AxelNerv/LogIn. GitHub fixed that capitalisation at creation time; it is an identifier, not the written product name.
- `loghorizon` is the internal namespace for future packages, services and configuration.
- The project is private: it is built for the owner and two or three other people, with no public release planned.
- The initial technical foundation is Forkop, itself a fork of Podkop.
- The target platform is OpenWrt with LuCI.

## Foundation capabilities retained for the first milestone
- Subscription import and updates.
- sing-box routing and outbound selection.
- Zapret, Zapret2 and ByeDPI provider integration.
- Dashboard, monitoring, diagnostics and component updates.

## Verified implementation notes
- Operator Calm is the single approved interface direction as of 2026-08-26.
- The current upstream diagnostics verify provider binaries, processes, NFQUEUE allocation, conflicts and sing-box outbounds; they do not yet perform end-to-end YouTube or Discord service probes.
- Future end-to-end DPI probes are strictly manual: they run only after **Проверить работу** and never on page load, startup, a timer, or a background schedule.
- Routing profiles will support a source network with ordered service rules and a final fallback, including the TV profile: YouTube/Discord through DPI and Netflix/everything else through VPN.
- logIn will be able to create an isolated, owned OpenWrt wireless network and bind it to a routing profile with transactional rollback.
- The proposed primary navigation is: Обзор, Маршрутизация, Подключения, DPI Lab, Диагностика, Компоненты. The label `Подключения` intentionally includes subscriptions, manual connections and future server inbounds.
- DPI Lab profiles may retain up to three declarative strategy variants with explicit one-click switching. Reachability-based automatic failover is excluded while diagnostics remain manual-only.
- Imported subscriptions must expose all locations in a collapsible group; named standalone and multi-hop configurations remain individually visible, with cascades expandable to their hops and latency.
- Downloads of Git-hosted components and rule lists may be routed through a user-selected existing VPN connection. Packages are downloaded and verified before replacing the running version.
- Diagnostics provides separate redacted system/error and operational/configuration reports for review by an IT specialist or AI agent.
- Automatic VPN cascade health checks are an explicit exception to manual-only service diagnostics. They may select the lowest-latency healthy location and fail over between stage candidates; DPI service reachability checks remain manual.
- VPN imports accept share links, subscription URLs and JSON outbounds, are parsed locally, and default to being stored without immediate activation.
- DNS protocol/server, Bootstrap DNS, DNS TTL rewrite, QUIC blocking and `Don't Touch My DHCP!` use the corresponding Forkop UCI concepts; the DHCP guard disables logIn-managed dnsmasq changes.
- Rule-list schedules include 1-hour, 6-hour, 12-hour, daily and manual-only intervals and do not imply automatic DPI checks.
- The current generated LuCI `main.js` is 427,326 bytes, 5,765 bytes larger than the upstream bundle. Its gzip representation is 80,027 bytes.
- LuCI renders the JavaScript interface in the client browser; the router primarily serves static files and answers RPC/ubus calls.

## Target hardware from the user brief
- Standard profile: routers with 256 MB RAM.
- Lite profile: routers with 128 MB RAM.
- Initial physical targets: ASUS TUF-AX4200 and Cudy TR3000.
