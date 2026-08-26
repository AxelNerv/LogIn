# Routing profiles and managed networks

Status: product requirements agreed on 2026-08-26. This document defines behavior; menu placement and final screens remain open.

## Manual diagnostics only

- End-to-end DPI checks run only after the user presses **Проверить работу**.
- Opening the dashboard, selecting a provider, starting logIn, booting OpenWrt, saving a profile, or updating a component must not start a network probe.
- No cron job, timer, watchdog, background retry, startup probe, or automatic periodic recheck may be created for these tests.
- The last result and timestamp may be displayed, but cached results must never trigger a refresh.
- A running check must be visible and cancellable. It stops when complete or cancelled and leaves no background worker.

## Routing profile model

A routing profile combines a source with ordered destination rules and one fallback action.

Example profile `TV`:

| Priority | Source | Destination | Action |
| --- | --- | --- | --- |
| 10 | Network `lh_tv` | YouTube | selected DPI provider |
| 20 | Network `lh_tv` | Discord | selected DPI provider |
| 30 | Network `lh_tv` | Netflix | selected VPN connection |
| 1000 | Network `lh_tv` | everything else | selected VPN connection |

Specific service rules are evaluated before the profile fallback. The existing Forkop `fully_routed_ips` option is not suitable for this fallback because it is unconditional and can swallow the YouTube and Discord exceptions.

The source selector should accept:

- a logIn-managed wireless network;
- an existing OpenWrt network/interface;
- a subnet or selected local devices.

In product language this is **binding a source network to a routing profile**. A sing-box/Forkop server inbound is a separate feature for accepting external proxy clients and must not be conflated with a local TV Wi-Fi network.

## One-button wireless network creation

The creation flow collects a display name, SSID, radio, encryption/password, isolation choice, address mode and routing profile. Automatic mode selects an unused private IPv4 subnet only after checking existing interfaces and routes.

logIn creates additive, owned resources with deterministic `lh_` identifiers:

- bridge device and static OpenWrt network interface;
- wireless AP attached to that interface;
- DHCP scope;
- dedicated firewall zone;
- DHCP and DNS access rules;
- forwarding to WAN while blocking access to the main LAN/router administration by default;
- source-network membership for logIn interception;
- selected routing profile and ordered rules.

The implementation must not depend on anonymous indexes such as `firewall.@zone[0]` or on guessed runtime device names such as `phy1-ap1`. It resolves named UCI objects and runtime devices through netifd/ubus.

## Safe apply and removal

- Never alter the active LAN or WAN as part of this wizard.
- Validate name, subnet, radio capability and configuration conflicts before applying.
- Show a configuration preview before the final apply.
- Snapshot the affected UCI packages (`network`, `wireless`, `dhcp`, `firewall`, logIn) and roll back all of them if any stage fails.
- Adding an AP can briefly reload its physical radio. Warn the user before apply, especially when administration is over that radio.
- Store an ownership manifest in the logIn config. Removal may delete only resources listed in that manifest.
- Existing user-created OpenWrt networks can be selected for routing, but logIn must never claim ownership of or delete them.

## Compatibility notes

The concept is based on `AxelNerv/podkop-section-interface`, but is integrated into logIn instead of patching installed Podkop/Forkop files. Multi-SSID support depends on the router's wireless driver; unsupported hardware must fail validation without partially applying configuration.
