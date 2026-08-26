# logIn information architecture

Status: proposed structure for discussion. Operator Calm remains the only visual system.

logIn uses six primary navigation destinations. Each destination owns one kind of decision so configuration is not duplicated between screens.

## 1. Обзор

The operational home page. It answers: **what is active right now and is logIn running?**

- service state, active connection and resource use;
- active routing profiles and managed networks;
- active DPI provider and strategy per service;
- last manually obtained check result and its timestamp;
- quick actions: manual check, switch connection, switch DPI variant.

The page does not edit detailed rules and does not launch checks automatically.

## 2. Маршрутизация

The policy workspace. It answers: **which source traffic goes where?**

- ordered routing profiles and rules;
- source selectors: all LAN, managed network, existing interface/subnet, selected devices;
- destination selectors: service catalog, domains, IP ranges, ports and rule sets;
- actions: VPN connection, DPI strategy, direct, block or custom outbound;
- fallback action for each profile;
- managed networks, including the one-button wireless-network wizard;
- rule simulation/explanation that shows which rule would win without sending network traffic.

## 3. Подключения

The connection inventory. It answers: **what VPN/proxy paths are available?**

- subscription sources and their update state;
- imported and manually created connections;
- a local import wizard for `hy2`/Hysteria2, VLESS, Trojan, Shadowsocks, subscription URLs and JSON outbounds;
- groups, node selection and load-balancing modes;
- masked credentials and safe export;
- manual latency/connectivity check;
- advanced server inbounds in a separate subsection when implemented.

`Подключения` is preferred over `Подписки` because subscriptions are only one way of adding a connection.

New imports default to **add without activating**. Parsed secrets must never appear in notifications, diagnostics or interface logs.

## 4. DPI Lab

The DPI strategy workspace. It answers: **how should a selected service bypass DPI?**

- installed providers: Zapret, Zapret2 and ByeDPI;
- service targets such as YouTube and Discord;
- user-created strategy variants;
- manual test runner and comparable results;
- strategy import/export with validation and source metadata;
- quick activation and rollback to the previously active variant.

### Variant slots

Each service target or DPI profile can keep up to three ready variants: `A`, `B` and `C`. A variant contains provider configuration/arguments, not an arbitrary executable.

- exactly one variant is active;
- switching is a single explicit user action;
- **Проверить работу** may test one variant or, after confirmation, all configured variants sequentially;
- the result includes status, timestamp and enough detail to compare variants;
- logIn may recommend a variant after the manual test, but the user applies it;
- no automatic probe or reachability-based failover runs in the background.

Passive process recovery is separate: logIn may restart the currently selected provider if its process crashes. This verifies only process state and cannot determine whether YouTube or Discord is actually reachable. Automatically switching after a real service failure would require an automatic network probe and is therefore excluded by the manual-only diagnostics requirement.

Imported variants are treated as untrusted data. The first implementation accepts declarative provider options and referenced logIn-managed assets only; it does not execute embedded shell commands. Provider binaries are installed only through Components.

## 5. Диагностика

The troubleshooting workspace. It answers: **why is something not working?**

- manual full-system check;
- service, sing-box, DNS, nftables/NFQUEUE and interface status;
- conflict detection and configuration validation;
- logs with secret masking;
- downloadable redacted support report;
- history of user-triggered tests.

Service-specific DPI experiments remain in DPI Lab. Diagnostics explains system-wide failures and does not duplicate strategy editing.

## 6. Компоненты

The software and storage workspace. It answers: **what is installed, trusted and updateable?**

- logIn, sing-box, Zapret, Zapret2, ByeDPI and rule-set versions;
- stable/beta update channels per component;
- package size, free storage and compatibility warnings;
- source, checksum/signature where available, install/update/remove;
- rollback to a retained known-good version;
- Lite/Standard compatibility indicator.

Components never accepts a DPI strategy as an executable update. New binaries/providers require an explicitly trusted source and a separate installation path; DPI Lab only configures installed providers.

## Cross-navigation

Objects link to each other without duplicating their editors:

- Overview opens the active profile in Маршрутизация or variant in DPI Lab;
- Маршрутизация selects connections from Подключения and strategies from DPI Lab;
- DPI Lab links missing/outdated providers to Компоненты;
- failed actions link to a filtered Диагностика view.

## Interaction refinements agreed after prototype review

- The primary navigation uses a restrained green outline and inset marker for the current section instead of a solid green fill.
- Explanations about manual-only checks are placed in contextual help or settings rather than repeated as prominent overview text.
- Маршрутизация contains three functional subsections: profiles, OpenWrt networks/zones, and connected devices. Device assignments persist by MAC plus a reserved IP where possible.
- Subscription sources are collapsible and expose every imported location. Standalone configurations use their parsed display name; multi-hop configurations expand into the complete cascade with per-hop and total latency.
- DPI Lab exposes a manual provider strategy editor comparable to Forkop while retaining the three logIn variant slots.
- Диагностика creates two locally generated, secret-redacted reports: a technical system/error report and a readable operational/configuration report.
- Компоненты installs and updates logIn, sing-box and approved DPI providers from trusted Git sources without SSH commands. Downloads can use a selected existing VPN connection, including GitHub releases and routing lists.
- The list-update schedule includes hourly, every 6 hours, every 12 hours, daily and manual-only choices. This schedule never starts DPI reachability tests.
- Маршрутизация includes a `DNS и сеть` subsection mapped to the Forkop-compatible UCI options `dns_type`, `dns_server`, `bootstrap_dns_server`, `dns_rewrite_ttl`, `disable_quic` and `dont_touch_dhcp`.
- `Don't Touch My DHCP!` prevents logIn from changing the existing dnsmasq/DHCP configuration. Managed-network creation must explain any DHCP changes separately before applying them.

## Cascade availability exception

Automatic network activity is allowed only for an explicitly enabled VPN cascade health group. This is separate from DPI service diagnostics:

- activating an automatic cascade measures its candidates and selects the healthy location with the lowest latency;
- the user can instead choose a preferred location with automatic fallback, or strictly pin a location without fallback;
- each cascade stage may contain its own candidate group, so failure replaces only the unavailable entry, relay or exit stage;
- failover requires consecutive failures, a configurable check interval and latency tolerance to prevent route flapping;
- DPI reachability probes for YouTube/Discord remain manual-only;
- switching active connections is an explicit advanced option because it may briefly reconnect streams.
