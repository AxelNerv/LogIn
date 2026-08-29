// language=CSS
import { DashboardTab } from './loghorizon/tabs/dashboard';
import { DiagnosticTab } from './loghorizon/tabs/diagnostic';
import { MonitoringTab } from './loghorizon/tabs/monitoring';
import { UpdatesTab } from './loghorizon/tabs/updates';
import { PartialStyles } from './partials';
import { LOGHORIZON_UCI_PACKAGE as LOGHORIZON_CBI_PREFIX } from './constants';

export const GlobalStyles = `
${DashboardTab.styles}
${DiagnosticTab.styles}
${MonitoringTab.styles}
${UpdatesTab.styles}
${PartialStyles}


/* Hide extra H3 for settings tab */
#cbi-${LOGHORIZON_CBI_PREFIX}-settings > h3 {
    display: none;
}

/* Hide extra H3 for rules tab */
#cbi-${LOGHORIZON_CBI_PREFIX}-section > h3:nth-child(1) {
    display: none;
}

/* Vertical align for remove rule action button */
#cbi-${LOGHORIZON_CBI_PREFIX}-section > .cbi-section-remove {
    margin-bottom: -32px;
}

#cbi-${LOGHORIZON_CBI_PREFIX}-section .cbi-section-actions > div {
    display: inline-flex;
    align-items: center;
    gap: 4px;
}

#cbi-${LOGHORIZON_CBI_PREFIX}-section .cbi-section-actions {
    text-align: right;
}

/* Rule reorder visuals */
#cbi-${LOGHORIZON_CBI_PREFIX}-section {
    position: relative;
}

#cbi-${LOGHORIZON_CBI_PREFIX}-section .cbi-section-table-row {
    position: relative;
}

#cbi-${LOGHORIZON_CBI_PREFIX}-section .cbi-section-table-row.placeholder {
    opacity: 1;
}

#cbi-${LOGHORIZON_CBI_PREFIX}-section .cbi-section-table-row.placeholder em {
    font-style: italic;
}

#cbi-${LOGHORIZON_CBI_PREFIX}-section .cbi-section-table-row.drag-over-above::after,
#cbi-${LOGHORIZON_CBI_PREFIX}-section .cbi-section-table-row.drag-over-below::after {
    content: '';
    position: absolute;
    left: 10px;
    right: 10px;
    height: 2px;
    border-radius: 2px;
    background: var(--primary-color-high, #1976d2);
    pointer-events: none;
    z-index: 2;
}

#cbi-${LOGHORIZON_CBI_PREFIX}-section .cbi-section-table-row.drag-over-above::after {
    top: -1px;
}

#cbi-${LOGHORIZON_CBI_PREFIX}-section .cbi-section-table-row.drag-over-below::after {
    bottom: -1px;
}

/* Centered class helper */
.centered {
    display: flex;
    align-items: center;
    justify-content: center;
}

/* Rotate class helper */
.rotate {
    animation: spin 1s linear infinite;
}

@keyframes spin {
    from { transform: rotate(0deg); }
    to { transform: rotate(360deg); }
}

/* Skeleton styles*/
.skeleton {
    background-color: var(--background-color-low, #e0e0e0);
    border-radius: 4px;
    position: relative;
    overflow: hidden;
}

.skeleton::after {
    content: '';
    position: absolute;
    top: 0;
    left: -150%;
    width: 150%;
    height: 100%;
    background: linear-gradient(
            90deg,
            transparent,
            rgba(255, 255, 255, 0.4),
            transparent
    );
    animation: skeleton-shimmer 1.6s infinite;
}

@keyframes skeleton-shimmer {
    100% {
        left: 150%;
    }
}
/* Toast */
.toast-container {
    position: fixed;
    bottom: 30px;
    left: 50%;
    transform: translateX(-50%);
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 10px;
    z-index: 9999;
    font-family: system-ui, sans-serif;
}

.toast {
    opacity: 0;
    transform: translateY(10px);
    transition: opacity 0.3s ease, transform 0.3s ease;
    padding: 10px 16px;
    border-radius: 6px;
    color: #fff;
    font-size: 14px;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.2);
    min-width: 220px;
    max-width: 340px;
    text-align: center;
}

.toast-success {
    background-color: #28a745;
}

.toast-error {
    background-color: #dc3545;
}

.toast.visible {
    opacity: 1;
    transform: translateY(0);
}

/* logIn / LogHorizon foundation shell
 * Type: 12 / 14 / 16 / 20 / 28
 * Space: 4 / 8 / 12 / 16 / 24 / 32
 * Surfaces: canvas + two elevations; green is reserved for actions/status.
 *
 * Operator Calm is a dark-only system. The shell therefore defines every
 * colour itself instead of leaning on LuCI theme variables: bootstrap does
 * not declare --border-color-low / --background-color-high, so relying on
 * fallbacks produced dark borders on a light page. Inside .lh-shell the
 * palette is ours regardless of the theme the router runs.
 */
/* The theme caps its content column at 940px, which left the tables cramped.
 * Lift that cap only on the page that hosts logIn, rather than dragging the
 * panel out of the column with negative margins: that depended on the column
 * being centred in the viewport and clipped the header when it was not. */
.container:has(> .lh-shell),
#maincontent:has(> .lh-shell) {
    max-width: min(1720px, calc(100vw - 32px));
}

.lh-shell {
    --lh-canvas: #0d1113;
    --lh-surface: #151a1d;
    --lh-surface-raised: #1b2225;
    --lh-border: #2b3538;
    --lh-border-strong: #3b494d;
    --lh-ink: #edf2ef;
    --lh-muted: #91a09a;
    --lh-faint: #6f7d78;
    --lh-primary: #45d483;
    --lh-primary-ink: #07150d;
    --lh-warning: #e6b85c;
    --lh-danger: #ef6b67;
    --lh-radius-sm: 3px;
    --lh-radius-md: 6px;
    --lh-radius-lg: 10px;
    color-scheme: dark;
    box-sizing: border-box;
    width: auto;
    padding: 6px 28px 22px;
    border-radius: var(--lh-radius-lg);
    color: var(--lh-ink);
    background: var(--lh-canvas);
    font-family: Aptos, "Segoe UI Variable", "Noto Sans", sans-serif;
}

/* Only the parts that must be allowed to shrink. A blanket rule here let row
 * buttons collapse narrower than their own labels. */
.lh-shell .lh-brand-header,
.lh-shell .lh-brand-header > *,
.lh-shell .cbi-tabmenu {
    min-width: 0;
}

.lh-brand-header {
    display: grid;
    grid-template-columns: auto minmax(0, 1fr);
    align-items: end;
    gap: 12px 24px;
    margin: 0 0 20px;
    padding: 16px 0 14px;
    border-bottom: 1px solid var(--lh-border);
}

.lh-brand-header__identity {
    display: flex;
    align-items: baseline;
    gap: 12px;
    min-width: 0;
}

.lh-wordmark {
    color: var(--lh-ink);
    font-size: clamp(28px, 4vw, 42px);
    font-weight: 650;
    letter-spacing: -0.055em;
    line-height: 0.95;
}

.lh-wordmark__in {
    color: var(--lh-primary);
}

.lh-brand-header__edition {
    color: var(--lh-muted);
    font-family: "Cascadia Mono", Consolas, monospace;
    font-size: 11px;
    letter-spacing: 0.08em;
    text-transform: uppercase;
}

.lh-brand-header__description {
    margin: 0;
    color: var(--lh-muted);
    font-size: 13px;
    line-height: 1.4;
    text-align: right;
    text-wrap: pretty;
}

/* The map title and description are empty by construction; the rule stays as
 * a guard in case a future LuCI version renders the nodes anyway. */
.lh-shell > .cbi-map > h2,
.lh-shell > .cbi-map > .cbi-map-descr {
    display: none;
}

.lh-shell h2,
.lh-shell h3,
.lh-shell h4,
.lh-shell legend,
.lh-shell label,
.lh-shell strong {
    color: var(--lh-ink);
}

.lh-shell .cbi-section-descr,
.lh-shell .cbi-value-description,
.lh-shell .cbi-value-title {
    color: var(--lh-muted);
}

.lh-shell a:not(.btn):not(.cbi-button) {
    color: var(--lh-primary);
}

.lh-shell .cbi-tabmenu {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: 4px;
    margin: 0 0 14px;
    padding: 4px;
    border: 1px solid var(--lh-border);
    border-radius: var(--lh-radius-md);
    background: var(--lh-surface);
    /* Wrapping instead of scrolling: overflow-x also produced a vertical
     * scrollbar whenever the row was a pixel taller than its box. The theme
     * paints a gradient rule under the tabs, which our own border replaces. */
    background-image: none;
    overflow: visible;
}

/* The theme pins tab items to height 25px, caps them at 48% width and paints
 * a gradient rule at 28px. Our taller tabs did not fit that box, which is what
 * produced the scrollbar, so the whole geometry is replaced rather than nudged. */
.lh-shell .cbi-tabmenu li,
.lh-shell .cbi-tabmenu > li {
    flex: 0 0 auto;
    height: auto;
    max-width: none;
    margin: 0;
    padding: 0;
    border: 0;
    border-radius: var(--lh-radius-sm);
    background: transparent;
    overflow: visible;
    line-height: 1;
}

.lh-shell .cbi-tabmenu li a,
.lh-shell .cbi-tabmenu > li > a {
    height: auto;
    min-height: 34px;
    overflow: visible;
    line-height: 1.2;
    box-sizing: border-box;
    display: inline-flex;
    align-items: center;
    padding: 8px 12px;
    border-radius: var(--lh-radius-sm);
    color: var(--lh-muted);
    font-size: 13px;
    font-weight: 600;
    text-decoration: none;
}

.lh-shell .cbi-tabmenu li.cbi-tab a,
.lh-shell .cbi-tabmenu li a:hover,
.lh-shell .cbi-tabmenu li a:focus-visible {
    color: var(--lh-primary-ink);
    background: var(--lh-primary);
    outline: 0;
}

.lh-shell .cbi-section,
.lh-shell .cbi-section-node {
    border-color: var(--lh-border);
    border-radius: var(--lh-radius-md);
    background: var(--lh-surface);
}

.lh-shell table,
.lh-shell .table {
    color: var(--lh-ink);
    background: transparent;
}

.lh-shell th,
.lh-shell td,
.lh-shell .tr,
.lh-shell .th,
.lh-shell .td {
    border-color: var(--lh-border);
}

/* The section list is the main working surface, and its rows were tight
 * enough to be awkward to hit. */
.lh-shell .cbi-section-table .tr,
.lh-shell .table .tr {
    min-height: 44px;
}

.lh-shell .cbi-section-table .td,
.lh-shell .cbi-section-table .th,
.lh-shell .table .td,
.lh-shell .table .th {
    padding: 10px 12px;
    vertical-align: middle;
}

.lh-shell .cbi-section-table .th,
.lh-shell .table .th {
    color: var(--lh-muted);
    font-size: 12px;
    letter-spacing: 0.04em;
    text-transform: uppercase;
}

/* Row actions keep their natural width; the label must never be clipped by a
 * neighbouring button. */
.lh-shell .cbi-section-table .td .btn,
.lh-shell .table .td .btn,
.lh-shell .cbi-section-table .td .cbi-button,
.lh-shell .table .td .cbi-button {
    min-height: 32px;
    flex: 0 0 auto;
    width: auto;
    min-width: max-content;
    margin: 0;
    white-space: nowrap;
}

.lh-shell .cbi-section-table .td.cbi-section-actions,
.lh-shell .table .td.cbi-section-actions {
    flex: 0 0 auto;
    width: auto;
    white-space: nowrap;
    text-align: right;
}

/* One row of actions, never a column: the buttons must stay side by side
 * and keep their labels. */
.lh-shell .cbi-section-actions > * {
    display: flex;
    flex-wrap: nowrap;
    gap: 6px;
    justify-content: flex-end;
    align-items: center;
}

.lh-shell input,
.lh-shell select,
.lh-shell textarea {
    border: 1px solid var(--lh-border-strong);
    border-radius: var(--lh-radius-sm);
    color: var(--lh-ink);
    background: var(--lh-canvas);
}

.lh-shell input::placeholder,
.lh-shell textarea::placeholder {
    color: var(--lh-faint);
}

.lh-shell .lgh_dashboard-page {
    --dashboard-grid-min-width: 190px;
}

.lh-shell .lgh_dashboard-page__widgets-section,
.lh-shell .lgh_dashboard-page__outbound-grid {
    gap: 12px;
}

/* The cards sit inside .cbi-section, which already uses --lh-surface. Giving
 * a card the same background makes it disappear, so cards go one step up. */
.lh-shell .lgh_dashboard-page__widgets-section__item,
.lh-shell .lgh_dashboard-page__outbound-section,
.lh-shell .lgh_dashboard-page__subscription-meta,
.lh-shell .lgh_dashboard-page__outbound-grid__item {
    border-width: 1px;
    border-color: var(--lh-border);
    border-radius: var(--lh-radius-md);
    background: var(--lh-surface-raised);
}

.lh-shell .lgh_dashboard-page__widgets-section__item {
    min-height: 92px;
    padding: 14px;
}

.lh-shell .lgh_dashboard-page__widgets-section__item__title,
.lh-shell .lgh_dashboard-page__outbound-section__title-section__title {
    letter-spacing: -0.01em;
}

.lh-shell .lgh_dashboard-page__widgets-section__item__row {
    display: flex;
    justify-content: space-between;
    gap: 12px;
    margin-top: 7px;
}

.lh-shell .lgh_dashboard-page__widgets-section__item__row__key {
    color: var(--lh-muted);
}

.lh-shell .lgh_dashboard-page__widgets-section__item__row__value,
.lh-shell .lgh_dashboard-page__outbound-grid__item__latency--green,
.lh-shell .lgh_dashboard-page__outbound-grid__item--active {
    color: var(--lh-primary);
}

.lh-shell .lgh_dashboard-page__outbound-grid__item--active,
.lh-shell .lgh_dashboard-page__outbound-grid__item--selectable:hover {
    border-color: var(--lh-primary);
}

.lh-shell .lgh_dashboard-page__outbound-grid__item__type,
.lh-shell .lgh_dashboard-page__outbound-grid__item__latency--green,
.lh-shell .lgh_dashboard-page__outbound-grid__item__latency--yellow,
.lh-shell .lgh_dashboard-page__outbound-grid__item__latency--red,
.lh-shell .lgh_dashboard-page__subscription-meta__fact-value {
    font-family: "Cascadia Mono", Consolas, monospace;
    font-size: 12px;
}

.lh-shell .btn,
.lh-shell .cbi-button {
    border: 1px solid var(--lh-border-strong);
    border-radius: var(--lh-radius-sm);
    color: var(--lh-ink);
    background: var(--lh-surface-raised);
    transition: border-color 140ms ease, background-color 140ms ease, color 140ms ease;
}

.lh-shell .btn:hover,
.lh-shell .cbi-button:hover {
    border-color: var(--lh-primary);
}

.lh-shell .btn:focus-visible,
.lh-shell .cbi-button:focus-visible,
.lh-shell input:focus-visible,
.lh-shell select:focus-visible,
.lh-shell textarea:focus-visible {
    outline: 2px solid var(--lh-primary);
    outline-offset: 2px;
}

.lh-shell .cbi-button-positive,
.lh-shell .cbi-button-add,
.lh-shell .cbi-button-apply,
.lh-shell .cbi-button-save {
    border-color: var(--lh-primary);
    color: var(--lh-primary-ink);
    background: var(--lh-primary);
}

.lh-shell .cbi-button-negative,
.lh-shell .cbi-button-remove,
.lh-shell .cbi-button-reset {
    border-color: var(--lh-danger);
    color: var(--lh-danger);
    background: transparent;
}

@media (max-width: 700px) {
    .lh-shell {
        padding: 4px 12px 16px;
    }

    .lh-brand-header {
        grid-template-columns: 1fr;
        align-items: start;
    }

    .lh-brand-header__description {
        text-align: left;
    }

    .lh-shell .cbi-tabmenu li a {
        min-height: 44px;
    }
}
`;
