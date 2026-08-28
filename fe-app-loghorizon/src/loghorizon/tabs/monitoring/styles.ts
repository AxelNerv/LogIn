// language=CSS
import { LOGHORIZON_UCI_PACKAGE as LOGHORIZON_CBI_PREFIX } from '../../../constants';

export const styles = `
#cbi-${LOGHORIZON_CBI_PREFIX}-monitoring-_mount_node {
    margin: 16px 0 22px;
    padding: 0;
}

#cbi-${LOGHORIZON_CBI_PREFIX}-monitoring-_mount_node > .cbi-value-title {
    display: none;
}

#cbi-${LOGHORIZON_CBI_PREFIX}-monitoring-_mount_node > .cbi-value-field {
    margin-left: 0;
    width: 100%;
}

#cbi-${LOGHORIZON_CBI_PREFIX}-monitoring-_mount_node > div {
    width: 100%;
}

#cbi-${LOGHORIZON_CBI_PREFIX}-monitoring > h3 {
    display: none;
}

.lgh_monitoring-page {
    --lgh-monitoring-control-height: 34px;
    --lgh-monitoring-row-action-size: 24px;
    --lgh-monitoring-divider-color: rgba(127, 127, 127, 0.22);
    --lgh-monitoring-soft-bg: rgba(127, 127, 127, 0.08);
    --lgh-monitoring-soft-bg-hover: rgba(127, 127, 127, 0.14);
    --lgh-monitoring-danger-color: var(--error-color-medium, #d32f2f);
    --lgh-monitoring-success-color: var(--success-color-medium, #2e7d32);
    --lgh-monitoring-paused-color: var(--primary-color-high, #1976d2);

    width: 100%;
    min-width: 0;
}

.lgh_monitoring-page__panel {
    margin-top: 0;
    border: 0;
    border-radius: 0;
    padding: 0;
    background: transparent;
    box-sizing: border-box;
    width: 100%;
    min-width: 0;
}

.lgh_monitoring-page .btn.lgh_monitoring-page__icon-button {
    width: 32px;
    height: 32px;
    min-width: 32px;
    min-height: 32px;
    padding: 0;
    box-sizing: border-box;
    display: flex;
    align-items: center;
    justify-content: center;
    flex: 0 0 auto;
    line-height: 1;
    margin: 0;
    border: 1px solid var(--lgh-monitoring-divider-color) !important;
    border-radius: 6px;
    background: var(--lgh-monitoring-soft-bg) !important;
    color: var(--text-color-medium) !important;
    box-shadow: none;
}

.lgh_monitoring-page .btn.lgh_monitoring-page__icon-button:hover:not(:disabled) {
    background: var(--lgh-monitoring-soft-bg-hover) !important;
    color: var(--text-color-high) !important;
}

.lgh_monitoring-page .btn.lgh_monitoring-page__icon-button--active {
    background: rgba(25, 118, 210, 0.16) !important;
    color: var(--primary-color-high, #1976d2) !important;
}

.lgh_monitoring-page .btn.lgh_monitoring-page__icon-button:disabled {
    opacity: 0.45;
    cursor: not-allowed;
}

.lgh_monitoring-page #monitoring-close-all.btn.lgh_monitoring-page__icon-button {
    order: 2;
    border-color: rgba(217, 83, 79, 0.4) !important;
    background: transparent !important;
    color: var(--lgh-monitoring-danger-color) !important;
}

.lgh_monitoring-page #monitoring-close-all.btn.lgh_monitoring-page__icon-button:hover:not(:disabled) {
    border-color: rgba(217, 83, 79, 0.6) !important;
    background: transparent !important;
    color: color-mix(in srgb, var(--lgh-monitoring-danger-color) 70%, white) !important;
}

.lgh_monitoring-page #monitoring-pause-toggle.btn.lgh_monitoring-page__icon-button,
.lgh_monitoring-page #monitoring-pause-toggle.btn.lgh_monitoring-page__icon-button--active {
    order: 1;
    border-color: rgba(128, 128, 128, 0.3) !important;
    background: transparent !important;
    color: var(--text-color-medium, #888) !important;
}

.lgh_monitoring-page #monitoring-pause-toggle.btn.lgh_monitoring-page__icon-button:hover:not(:disabled),
.lgh_monitoring-page #monitoring-pause-toggle.btn.lgh_monitoring-page__icon-button--active:hover:not(:disabled) {
    border-color: rgba(128, 128, 128, 0.6) !important;
    background: transparent !important;
    color: var(--text-color-high, #eee) !important;
}

.lgh_monitoring-page__icon-button svg,
.lgh_monitoring-page__row-action svg {
    width: 16px;
    height: 16px;
    display: block;
    flex: 0 0 auto;
}

.lgh_monitoring-page__controls {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    justify-content: space-between;
    gap: 16px;
    margin-bottom: 12px;
    width: 100%;
    min-width: 0;
}

.lgh_monitoring-page__actions {
    display: flex;
    align-items: center;
    justify-content: flex-end;
    gap: 8px;
    min-width: 0;
}

.lgh_monitoring-page__tabs {
    display: inline-flex;
    align-items: center;
    gap: 2px;
    width: max-content;
    padding: 2px;
    border: 1px solid var(--lgh-monitoring-divider-color);
    border-radius: 6px;
    background: var(--lgh-monitoring-soft-bg);
    box-sizing: border-box;
}

.lgh_monitoring-page .btn.lgh_monitoring-page__tab {
    height: calc(var(--lgh-monitoring-control-height) - 6px);
    min-height: calc(var(--lgh-monitoring-control-height) - 6px);
    margin: 0;
    padding: 0 12px;
    border: 0 !important;
    border-radius: 4px;
    background: transparent !important;
    color: var(--text-color-medium) !important;
    box-shadow: none;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    gap: 8px;
    font-weight: 600;
    line-height: 1;
}

.lgh_monitoring-page .btn.lgh_monitoring-page__tab:hover {
    background: var(--lgh-monitoring-soft-bg-hover) !important;
    color: var(--text-color-high) !important;
}

.lgh_monitoring-page .btn.lgh_monitoring-page__tab--active {
    background: rgba(25, 118, 210, 0.16) !important;
    color: var(--primary-color-high, #1976d2) !important;
    font-weight: 700;
}

.lgh_monitoring-page__tab-label {
    display: inline-block;
}

.lgh_monitoring-page__tab-badge {
    min-width: 18px;
    height: 18px;
    padding: 0 6px;
    border-radius: 999px;
    background: rgba(127, 127, 127, 0.22);
    color: var(--text-color-medium);
    display: inline-flex;
    align-items: center;
    justify-content: center;
    box-sizing: border-box;
    font-size: 12px;
    font-weight: 700;
    line-height: 1;
}

.lgh_monitoring-page__tab--active .lgh_monitoring-page__tab-badge {
    background: rgba(25, 118, 210, 0.22);
    color: var(--primary-color-high, #1976d2);
}

.lgh_monitoring-page__filters {
    display: flex;
    flex: 1 1 auto;
    flex-wrap: wrap;
    align-items: center;
    justify-content: flex-start;
    gap: 12px;
    min-width: 0;
}

.lgh_monitoring-page__device-filter {
    width: min(220px, 100%);
    min-width: 0;
    height: var(--lgh-monitoring-control-height) !important;
    min-height: var(--lgh-monitoring-control-height) !important;
    padding-top: 0 !important;
    padding-bottom: 0 !important;
    margin: 0 !important;
    box-sizing: border-box;
    line-height: calc(var(--lgh-monitoring-control-height) - 2px) !important;
}

.lgh_monitoring-page__search {
    position: relative;
    display: flex;
    align-items: center;
    width: min(320px, 100%);
    min-width: 0;
    height: var(--lgh-monitoring-control-height);
    margin: 0;
}

.lgh_monitoring-page__search-icon {
    position: absolute;
    left: 8px;
    width: 16px;
    height: 16px;
    color: var(--text-color-medium);
    pointer-events: none;
}

.lgh_monitoring-page__search-icon svg {
    width: 16px;
    height: 16px;
    display: block;
}

.lgh_monitoring-page__search-input {
    width: 100%;
    height: var(--lgh-monitoring-control-height) !important;
    min-height: var(--lgh-monitoring-control-height) !important;
    padding-left: 30px !important;
    padding-top: 0 !important;
    padding-bottom: 0 !important;
    margin: 0 !important;
    box-sizing: border-box;
    line-height: calc(var(--lgh-monitoring-control-height) - 2px) !important;
}

.lgh_monitoring-page__body {
    margin-top: 0;
    width: 100%;
    min-width: 0;
}

.lgh_monitoring-page__table-wrap {
    width: 100%;
    overflow-x: auto;
    margin-bottom: 0;
}

.lgh_monitoring-page__table {
    width: 100%;
    min-width: 840px;
    table-layout: fixed;
    border-collapse: collapse;
    border-spacing: 0;
    margin-bottom: 0;
}

.lgh_monitoring-page__table th,
.lgh_monitoring-page__table td {
    padding: 8px 6px;
    border-bottom: 1px solid var(--lgh-monitoring-divider-color);
    box-sizing: border-box;
    text-align: left;
    vertical-align: middle;
    overflow: hidden;
    white-space: nowrap;
}

.lgh_monitoring-page__table th {
    color: var(--text-color-medium);
    font-size: 11px;
    font-weight: 600;
    text-transform: uppercase;
    white-space: nowrap;
    border-bottom-color: rgba(127, 127, 127, 0.32);
}

.lgh_monitoring-page__table th:nth-child(1) {
    width: 28%;
}

.lgh_monitoring-page__table th:nth-child(2) {
    width: 6%;
}

.lgh_monitoring-page__table th:nth-child(3) {
    width: 16%;
}

.lgh_monitoring-page__table th:nth-child(4) {
    width: 8%;
}

.lgh_monitoring-page__table th:nth-child(5) {
    width: 9.5%;
}

.lgh_monitoring-page__table th:nth-child(6) {
    width: 8.5%;
}

.lgh_monitoring-page__table th:nth-child(7) {
    width: 16%;
}

.lgh_monitoring-page__table th:nth-child(8) {
    width: 8%;
}

.lgh_monitoring-page__table tbody tr:last-child td {
    border-bottom: 0;
}

.lgh_monitoring-page__table td:last-child {
    padding-top: 0;
    padding-bottom: 0;
}

.lgh_monitoring-page__table th:nth-child(4),
.lgh_monitoring-page__table td:nth-child(4),
.lgh_monitoring-page__table th:nth-child(5),
.lgh_monitoring-page__table td:nth-child(5),
.lgh_monitoring-page__table th:nth-child(6),
.lgh_monitoring-page__table td:nth-child(6) {
    text-align: right;
}

.lgh_monitoring-page__table th:nth-child(7),
.lgh_monitoring-page__table td:nth-child(7) {
    text-align: left;
}

.lgh_monitoring-page__table th:last-child,
.lgh_monitoring-page__table td:last-child {
    text-align: center;
}

.lgh_monitoring-page__value {
    display: block;
    max-width: 100%;
    min-width: 0;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    text-align: left;
    line-height: 1.3;
    color: var(--text-color-high);
    font-size: 13px;
    user-select: text;
}

.lgh_monitoring-page__source-value {
    display: flex;
    align-items: baseline;
    justify-content: flex-start;
    gap: 5px;
}

.lgh_monitoring-page__source-name {
    min-width: 0;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
}

.lgh_monitoring-page__source-ip {
    flex: 0 1 auto;
    min-width: 0;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    color: var(--text-color-medium);
    font-size: 12px;
}

.lgh_monitoring-page__source-value--ip-only {
    color: var(--text-color-high);
}

.lgh_monitoring-page__cell-main {
    color: var(--text-color-high);
    font-weight: 600;
    line-height: 1.25;
}

.lgh_monitoring-page__cell-secondary {
    margin-top: 2px;
    color: var(--text-color-medium);
    font-size: 12px;
    line-height: 1.25;
}

.lgh_monitoring-page__route {
    display: inline-block;
    width: auto;
    padding: 2px 6px;
    border-radius: 4px;
    background: rgba(128, 128, 128, 0.15);
    color: var(--text-color-high, #eee);
    font-size: 11px;
    font-weight: 500;
}

.lgh_monitoring-page__network {
    background: transparent;
    border: 0;
    padding: 0;
    color: var(--text-color-medium, #bbb);
    font-family: inherit;
    font-size: 13px;
    text-transform: lowercase;
}

.lgh_monitoring-page__table td:nth-child(4) .lgh_monitoring-page__value,
.lgh_monitoring-page__table td:nth-child(5) .lgh_monitoring-page__value,
.lgh_monitoring-page__table td:nth-child(6) .lgh_monitoring-page__value {
    color: var(--text-color-medium, #bbb);
    font-family: inherit;
    text-align: right;
}

.lgh_monitoring-page .btn.lgh_monitoring-page__row-action {
    width: var(--lgh-monitoring-row-action-size);
    height: var(--lgh-monitoring-row-action-size);
    min-width: var(--lgh-monitoring-row-action-size);
    min-height: var(--lgh-monitoring-row-action-size);
    padding: 0;
    box-sizing: border-box;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    line-height: 1;
    margin: 0;
    border: 0 !important;
    border-radius: 999px;
    background: transparent !important;
    color: var(--lgh-monitoring-danger-color) !important;
    box-shadow: none;
    cursor: pointer;
}

.lgh_monitoring-page__row-action svg {
    width: 14px;
    height: 14px;
}

.lgh_monitoring-page .btn.lgh_monitoring-page__row-action:hover:not(:disabled) {
    background: var(--lgh-monitoring-soft-bg-hover) !important;
    color: var(--lgh-monitoring-danger-color) !important;
}

.lgh_monitoring-page .btn.lgh_monitoring-page__row-action:disabled {
    opacity: 0.45;
    cursor: wait;
}

.lgh_monitoring-page__row--closing {
    opacity: 0.55;
}

.lgh_monitoring-page__state {
    min-height: 90px;
    width: 100%;
    display: flex;
    align-items: center;
    justify-content: center;
    color: var(--text-color-medium);
    text-align: center;
    box-sizing: border-box;
}

.lgh_monitoring-page__state-cell {
    padding: 0 !important;
}

.lgh_monitoring-page__state--error {
    color: var(--error-color-medium, #d32f2f);
}

@media (max-width: 900px) {
    .lgh_monitoring-page__controls {
        align-items: center;
    }

    .lgh_monitoring-page__tabs {
        flex: 1 0 100%;
    }

    .lgh_monitoring-page__filters {
        flex: 1 1 0;
    }

    .lgh_monitoring-page__device-filter,
    .lgh_monitoring-page__search {
        max-width: none;
    }

    .lgh_monitoring-page__table {
        min-width: 0;
    }

    .lgh_monitoring-page__table thead {
        display: none;
    }

    .lgh_monitoring-page__table,
    .lgh_monitoring-page__table tbody,
    .lgh_monitoring-page__table tr,
    .lgh_monitoring-page__table td {
        display: block;
        width: 100%;
    }

    .lgh_monitoring-page__table tr {
        border: 1px var(--background-color-low, lightgray) solid;
        border-radius: 4px;
        padding: 8px;
        box-sizing: border-box;
        margin-bottom: 8px;
    }

    .lgh_monitoring-page__table td {
        display: grid;
        grid-template-columns: minmax(92px, 34%) minmax(0, 1fr);
        gap: 8px;
        border: 0;
        border-bottom: 1px solid var(--lgh-monitoring-divider-color);
        padding: 4px 0;
        box-sizing: border-box;
        text-align: left;
    }

    .lgh_monitoring-page__table td::before {
        content: attr(data-label);
        color: var(--text-color-medium);
        font-weight: 700;
        overflow: hidden;
        text-overflow: ellipsis;
        white-space: nowrap;
    }

    .lgh_monitoring-page__table td:last-child {
        grid-template-columns: minmax(92px, 34%) minmax(0, 1fr);
        align-items: center;
        border-bottom: 0;
        min-height: var(--lgh-monitoring-row-action-size);
        padding: 0;
    }

    .lgh_monitoring-page__value {
        text-align: right;
    }

    .lgh_monitoring-page__source-value {
        justify-content: flex-end;
    }

    .lgh_monitoring-page__state-row td::before {
        display: none;
    }
}

@media (max-width: 520px) {
    .lgh_monitoring-page__controls,
    .lgh_monitoring-page__filters {
        align-items: stretch;
    }

    .lgh_monitoring-page__tabs,
    .lgh_monitoring-page__filters,
    .lgh_monitoring-page__device-filter,
    .lgh_monitoring-page__search {
        width: 100%;
    }

    .lgh_monitoring-page__controls,
    .lgh_monitoring-page__filters {
        flex-direction: column;
    }

    .lgh_monitoring-page__actions {
        align-self: flex-end;
    }

    .lgh_monitoring-page__tabs {
        display: grid;
        grid-template-columns: minmax(0, 1fr) minmax(0, 1fr);
        width: 100%;
    }

    .lgh_monitoring-page__table td {
        grid-template-columns: 1fr;
        gap: 2px;
    }

    .lgh_monitoring-page__value {
        text-align: left;
    }

    .lgh_monitoring-page__source-value {
        justify-content: flex-start;
    }
}
`;
