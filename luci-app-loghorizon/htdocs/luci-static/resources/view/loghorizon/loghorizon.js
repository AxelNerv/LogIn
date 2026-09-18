"use strict";
"require view";
"require form";
"require baseclass";
"require uci";
"require ui";
"require view.loghorizon.main as main";

// Global settings
"require view.loghorizon.settings as settings";

// Sections
"require view.loghorizon.section as section";

// Server
"require view.loghorizon.server as server";

// Dashboard
"require view.loghorizon.dashboard as dashboard";

// Monitoring
"require view.loghorizon.monitoring as monitoring";

// Diagnostic
"require view.loghorizon.diagnostic as diagnostic";

// Updates
"require view.loghorizon.updates as updates";

const UCI_PACKAGE = main.LOGHORIZON_UCI_PACKAGE;

function normalizeLogHorizonPageLayout() {
  let observer = null;

  const mark = function () {
    const mainContent = document.getElementById("maincontent");
    const container = Array.from(mainContent?.children || []).find((child) =>
      child.classList.contains("container"),
    );
    if (!container) return false;

    container.classList.add("lh-page-container");
    mainContent.classList.add("lh-page-maincontent");

    // Vendor themes may inject a late max-width declaration with !important.
    // An inline important declaration is the only deterministic override and
    // is safe here because this is LuCI's container for the current page only.
    container.style.setProperty("width", "calc(100% - 32px)", "important");
    container.style.setProperty("max-width", "1720px", "important");
    container.style.setProperty("flex-basis", "auto", "important");
    container.style.setProperty("box-sizing", "border-box", "important");
    container.style.setProperty("margin-left", "auto", "important");
    container.style.setProperty("margin-right", "auto", "important");
    mainContent.style.setProperty("max-width", "none", "important");

    observer?.disconnect();
    return true;
  };

  if (mark()) return;

  observer = new MutationObserver(mark);
  observer.observe(document.body, { childList: true, subtree: true });
}

function renderSectionAdd(sectionRef, extra_class) {
  const el = form.GridSection.prototype.renderSectionAdd.apply(sectionRef, [
    extra_class,
  ]);
  const nameEl = el.querySelector(".cbi-section-create-name");

  ui.addValidator(
    nameEl,
    "uciname",
    true,
    (value) => {
      const button = el.querySelector(".cbi-section-create > .cbi-button-add");
      const uciconfig = sectionRef.uciconfig || sectionRef.map.config;

      if (!value) {
        button.disabled = true;
        return true;
      }

      if (uci.get(uciconfig, value)) {
        button.disabled = true;
        return _("Expecting: %s").format(_("unique UCI identifier"));
      }

      button.disabled = null;
      return true;
    },
    "blur",
    "keyup",
  );

  return el;
}

function getRuleEditButtonText() {
  const label = _("Edit rule action");

  return label === "Edit rule action" ? "Edit" : label;
}

function configureGridSection(sectionRef, type, title, addTitle) {
  sectionRef.anonymous = false;
  sectionRef.addremove = true;
  sectionRef.sortable = true;
  sectionRef.rowcolors = true;
  sectionRef.nodescriptions = true;
  sectionRef.modaltitle = function (section_id) {
    const label = uci.get(UCI_PACKAGE, section_id, "label");
    return section_id ? `${title}: ${label || section_id}` : addTitle;
  };
  sectionRef.sectiontitle = function (section_id) {
    return uci.get(UCI_PACKAGE, section_id, "label") || section_id;
  };
  sectionRef.renderSectionAdd = function (extra_class) {
    return renderSectionAdd(sectionRef, extra_class);
  };

  if (type === "section") {
    sectionRef.renderRowActions = function (section_id) {
      return form.TableSection.prototype.renderRowActions.call(
        this,
        section_id,
        getRuleEditButtonText(),
      );
    };
  }
}

const EntryPoint = {
  async render() {
    normalizeLogHorizonPageLayout();
    main.injectGlobalStyles();
    const uiCapabilities = {
      loaded: false,
      singBoxExtended: false,
      singBoxTiny: false,
      singBoxTailscale: true,
      zapretInstalled: false,
      zapret2Installed: false,
      byedpiInstalled: false,
      serverInboundsEnabledCount: -1,
    };
    let uiCapabilitiesPromise = null;
    let serverSectionRef = null;

    const applyUiCapabilities = function () {
      if (serverSectionRef) {
        server.applyServerCapabilities(serverSectionRef, uiCapabilities);
      }

      if (typeof window !== "undefined") {
        window.dispatchEvent(
          new CustomEvent(main.LOGHORIZON_ACTION_PROVIDERS_AVAILABILITY_EVENT, {
            detail: {
              zapretInstalled: uiCapabilities.zapretInstalled,
              zapret2Installed: uiCapabilities.zapret2Installed,
              byedpiInstalled: uiCapabilities.byedpiInstalled,
            },
          }),
        );
      }

      if (main.store && typeof main.store.set === "function") {
        const currentSystemInfo = main.store.get().diagnosticsSystemInfo;
        main.store.set({
          diagnosticsSystemInfo: {
            ...currentSystemInfo,
            providerInfoLoaded: true,
            sing_box_extended: uiCapabilities.singBoxExtended ? 1 : 0,
            sing_box_tiny: uiCapabilities.singBoxTiny ? 1 : 0,
            sing_box_tailscale: uiCapabilities.singBoxTailscale ? 1 : 0,
            zapret_installed: uiCapabilities.zapretInstalled ? 1 : 0,
            zapret2_installed: uiCapabilities.zapret2Installed ? 1 : 0,
            byedpi_installed: uiCapabilities.byedpiInstalled ? 1 : 0,
            server_inbounds_enabled_count:
              uiCapabilities.serverInboundsEnabledCount,
            zapret_version: uiCapabilities.zapretInstalled
              ? currentSystemInfo.zapret_version
              : "not installed",
            zapret2_version: uiCapabilities.zapret2Installed
              ? currentSystemInfo.zapret2_version
              : "not installed",
            byedpi_version: uiCapabilities.byedpiInstalled
              ? currentSystemInfo.byedpi_version
              : "not installed",
          },
        });
      }
    };

    const updateUiCapabilities = function (data) {
      uiCapabilities.loaded = true;
      uiCapabilities.singBoxExtended = Boolean(
        Number(data?.sing_box_extended) === 1,
      );
      uiCapabilities.singBoxTiny = Boolean(Number(data?.sing_box_tiny) === 1);
      uiCapabilities.singBoxTailscale =
        typeof data?.sing_box_tailscale === "undefined"
          ? true
          : Boolean(Number(data.sing_box_tailscale) === 1);
      uiCapabilities.zapretInstalled = Boolean(
        Number(data?.zapret_installed) === 1,
      );
      uiCapabilities.zapret2Installed = Boolean(
        Number(data?.zapret2_installed) === 1,
      );
      uiCapabilities.byedpiInstalled = Boolean(
        Number(data?.byedpi_installed) === 1,
      );
      const serverInboundsEnabledCount =
        typeof data?.server_inbounds_enabled_count !== "undefined"
          ? Number(data.server_inbounds_enabled_count)
          : -1;
      uiCapabilities.serverInboundsEnabledCount = Number.isFinite(
        serverInboundsEnabledCount,
      )
        ? serverInboundsEnabledCount
        : -1;

      applyUiCapabilities();

      return uiCapabilities;
    };

    const applyUiState = function (data) {
      const result = updateUiCapabilities(data?.capabilities || data || {});

      if (typeof main.applyUiStateToStore === "function" && data?.service) {
        main.applyUiStateToStore(data);
      } else if (
        main.store &&
        typeof main.store.set === "function" &&
        data?.service
      ) {
        main.store.set({
          servicesInfoWidget: {
            loading: false,
            failed: false,
            data: {
              singbox: Number(data.service.sing_box?.running) || 0,
              loghorizonRunning: Number(data.service.loghorizon?.running) || 0,
              loghorizonEnabled: Number(data.service.loghorizon?.enabled) || 0,
              loghorizonStatus: data.service.loghorizon?.status || "",
            },
          },
        });
      }

      return result;
    };

    const loadFallbackUiCapabilities = function () {
      return Promise.allSettled([
        main.LogHorizonShellMethods.getServerCapabilities(),
        main.LogHorizonShellMethods.checkZapretRuntime(),
        main.LogHorizonShellMethods.checkZapret2Runtime(),
        main.LogHorizonShellMethods.checkByedpiRuntime(),
        main.LogHorizonShellMethods.checkInboundsConfig(),
      ]).then(
        ([
          serverCapabilitiesResult,
          zapretRuntimeResult,
          zapret2RuntimeResult,
          byedpiRuntimeResult,
          inboundsConfigResult,
        ]) => {
          // Every probe below degrades a failure into "not installed". That is
          // only honest while at least one probe answered: if none did, the
          // backend is unreachable and reporting an empty install would be a
          // lie. Fail loudly instead so the caller can tell the user.
          const answered = [
            serverCapabilitiesResult,
            zapretRuntimeResult,
            zapret2RuntimeResult,
            byedpiRuntimeResult,
            inboundsConfigResult,
          ].some(
            (result) => result.status === "fulfilled" && result.value?.success,
          );

          if (!answered) {
            throw new Error(
              "no logIn capability probe answered; the backend is unreachable",
            );
          }

          const serverCapabilities =
            serverCapabilitiesResult.status === "fulfilled"
              ? serverCapabilitiesResult.value
              : null;
          const zapretRuntime =
            zapretRuntimeResult.status === "fulfilled"
              ? zapretRuntimeResult.value
              : null;
          const zapret2Runtime =
            zapret2RuntimeResult.status === "fulfilled"
              ? zapret2RuntimeResult.value
              : null;
          const byedpiRuntime =
            byedpiRuntimeResult.status === "fulfilled"
              ? byedpiRuntimeResult.value
              : null;
          const inboundsConfig =
            inboundsConfigResult.status === "fulfilled"
              ? inboundsConfigResult.value
              : null;

          return updateUiCapabilities({
            sing_box_extended:
              serverCapabilities?.success &&
              Number(serverCapabilities.data?.sing_box_extended) === 1
                ? 1
                : 0,
            sing_box_tiny:
              serverCapabilities?.success &&
              Number(serverCapabilities.data?.sing_box_tiny) === 1
                ? 1
                : 0,
            sing_box_tailscale:
              !serverCapabilities?.success ||
              typeof serverCapabilities.data?.sing_box_tailscale ===
                "undefined" ||
              Number(serverCapabilities.data?.sing_box_tailscale) === 1
                ? 1
                : 0,
            zapret_installed:
              zapretRuntime?.success &&
              Number(zapretRuntime.data?.zapret_installed) === 1
                ? 1
                : 0,
            zapret2_installed:
              zapret2Runtime?.success &&
              Number(zapret2Runtime.data?.zapret2_installed) === 1
                ? 1
                : 0,
            byedpi_installed:
              byedpiRuntime?.success &&
              Number(byedpiRuntime.data?.byedpi_installed) === 1
                ? 1
                : 0,
            server_inbounds_enabled_count:
              inboundsConfig?.success &&
              typeof inboundsConfig.data?.enabled_count !== "undefined"
                ? inboundsConfig.data.enabled_count
                : -1,
          });
        },
      );
    };

    const loadUiCapabilities = function () {
      if (uiCapabilities.loaded) {
        return Promise.resolve(uiCapabilities);
      }

      if (uiCapabilitiesPromise) {
        return uiCapabilitiesPromise;
      }

      uiCapabilitiesPromise = main.LogHorizonShellMethods.getUiCapabilities()
        .then((response) => {
          if (!response?.success) {
            throw new Error("UI capabilities request failed");
          }

          return updateUiCapabilities(response.data);
        })
        .catch((error) => {
          console.warn("Failed to load logIn UI capabilities", error);
          return main.LogHorizonShellMethods.getUiState()
            .then((response) => {
              if (!response?.success) {
                throw new Error("UI state request failed");
              }

              return applyUiState(response.data);
            })
            .catch((fallbackError) => {
              console.warn("Failed to load logIn UI state", fallbackError);
              return loadFallbackUiCapabilities();
            });
        })
        .finally(() => {
          uiCapabilitiesPromise = null;
        });

      return uiCapabilitiesPromise;
    };
    // The map title and description are intentionally empty: the
    // .lh-brand-header below fills that role. Keeping both produced two
    // competing descriptions, one hidden by CSS and dead weight in locales.
    const loghorizonMap = new form.Map(UCI_PACKAGE, "", "");
    loghorizonMap.tabbed = true;
    const originalHandleSaveApply = loghorizonMap.handleSaveApply;
    loghorizonMap.handleSaveApply = function (ev, mode) {
      const refreshUiState = function () {
        main.LogHorizonShellMethods.getUiState()
          .then((response) => {
            if (!response?.success) {
              throw new Error(response?.error || "UI state request failed");
            }

            if (typeof main.applyUiStateToStore === "function") {
              main.applyUiStateToStore(response.data);
            }
          })
          .catch((error) => {
            // Settings were applied, but the displayed state is now stale.
            // Staying silent here makes the interface look up to date.
            console.error("Failed to refresh logIn state after apply", error);
            ui.addNotification(
              null,
              E(
                "p",
                {},
                _(
                  "Settings were applied, but the service state could not be re-read. The values shown may be out of date; reload the page.",
                ),
              ),
              "warning",
            );
          });
      };

      if (main.store && typeof main.store.set === "function") {
        const servicesInfoWidget = main.store.get().servicesInfoWidget;
        main.store.set({
          servicesInfoWidget: {
            ...servicesInfoWidget,
            data: {
              ...servicesInfoWidget.data,
              loghorizonStatus: "reloading",
            },
          },
        });
      }

      return Promise.resolve(originalHandleSaveApply.call(this, ev, mode))
        .then((result) => {
          window.setTimeout(refreshUiState, 250);

          return result;
        })
        .catch((error) => {
          refreshUiState();

          throw error;
        });
    };

    const rulesSection = loghorizonMap.section(
      form.GridSection,
      "section",
      _("Sections"),
      _("Drag rows to change priority. The rule at the top is checked first."),
    );
    configureGridSection(
      rulesSection,
      "section",
      _("Section"),
      _("Add a section"),
    );
    section.configureSectionSection(rulesSection, {
      loadActionProvidersAvailability: loadUiCapabilities,
    });
    section.createSectionContent(rulesSection);

    const serverSection = loghorizonMap.section(
      form.GridSection,
      "server",
      _("Servers"),
      _("Accept external proxy connections and route them with sing-box."),
    );
    configureGridSection(
      serverSection,
      "server",
      _("Server"),
      _("Add a server inbound"),
    );
    serverSectionRef = serverSection;
    server.configureServerSection(serverSection, {
      loadCapabilities: loadUiCapabilities,
    });
    server.createServerContent(serverSection, uiCapabilities);

    const settingsSection = loghorizonMap.section(
      form.TypedSection,
      "settings",
      _("Settings"),
    );
    settingsSection.anonymous = true;
    settingsSection.addremove = false;
    settingsSection.cfgsections = function () {
      return ["settings"];
    };
    settings.createSettingsContent(settingsSection, uiCapabilities);

    const diagnosticSection = loghorizonMap.section(
      form.TypedSection,
      "diagnostic",
      _("Diagnostics"),
    );
    diagnosticSection.anonymous = true;
    diagnosticSection.addremove = false;
    diagnosticSection.cfgsections = function () {
      return ["diagnostic"];
    };
    diagnostic.createDiagnosticContent(diagnosticSection);

    const dashboardSection = loghorizonMap.section(
      form.TypedSection,
      "dashboard",
      _("Dashboard"),
    );
    dashboardSection.anonymous = true;
    dashboardSection.addremove = false;
    dashboardSection.cfgsections = function () {
      return ["dashboard"];
    };
    dashboard.createDashboardContent(dashboardSection);

    const monitoringSection = loghorizonMap.section(
      form.TypedSection,
      "monitoring",
      _("Monitoring"),
    );
    monitoringSection.anonymous = true;
    monitoringSection.addremove = false;
    monitoringSection.cfgsections = function () {
      return ["monitoring"];
    };
    monitoring.createMonitoringContent(monitoringSection);

    const updatesSection = loghorizonMap.section(
      form.TypedSection,
      "updates",
      _("Components"),
    );
    updatesSection.anonymous = true;
    updatesSection.addremove = false;
    updatesSection.cfgsections = function () {
      return ["updates"];
    };
    updates.createUpdatesContent(updatesSection);

    await loadUiCapabilities().catch((error) => {
      // Without this the page renders as if nothing were installed: no Zapret,
      // no ByeDPI, plain sing-box. That looks like a working interface and is
      // the worst way to fail, so say it out loud.
      console.error("Failed to load logIn state", error);
      ui.addNotification(
        null,
        E(
          "p",
          {},
          _(
            "Could not read the logIn service state. Installed components and DPI providers may be shown incorrectly. Check that the service is running.",
          ),
        ),
        "error",
        "lgh-capability-error-notification",
      );
      return null;
    });

    const rendered = await loghorizonMap.render();
    main.coreService({
      waitForLogWatcherStart: loadUiCapabilities,
      logWatcherStartDelayMs: 5000,
    });

    const brandHeader = E("header", { class: "lh-brand-header" }, [
      E("div", { class: "lh-brand-header__identity" }, [
        E("div", { class: "lh-wordmark" }, [
          E(
            "span",
            { class: "lh-wordmark__log" },
            main.LOGIN_BRAND.wordmark.prefix,
          ),
          E(
            "span",
            { class: "lh-wordmark__in" },
            main.LOGIN_BRAND.wordmark.accent,
          ),
        ]),
        E(
          "span",
          { class: "lh-brand-header__edition" },
          main.LOGIN_BRAND.edition,
        ),
      ]),
      E(
        "p",
        { class: "lh-brand-header__description" },
        // A literal is required here: extract-calls.js only collects string
        // literals inside _(), so a variable would silently never be extracted.
        _("Routing, subscriptions and DPI control for OpenWrt"),
      ),
    ]);

    const shell = E(
      "div",
      { class: "lh-shell", "data-loghorizon-shell": "foundation" },
      [brandHeader, rendered],
    );

    return shell;
  },
};

return view.extend(EntryPoint);
