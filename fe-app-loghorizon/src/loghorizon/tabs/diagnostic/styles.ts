// language=CSS
import { LOGHORIZON_UCI_PACKAGE as LOGHORIZON_CBI_PREFIX } from '../../../constants';

export const styles = `

#cbi-${LOGHORIZON_CBI_PREFIX}-diagnostic-_mount_node > div {
    width: 100%;
}

#cbi-${LOGHORIZON_CBI_PREFIX}-diagnostic > h3 {
    display: none;
}

.lgh_diagnostic-page {
    display: grid;
    grid-template-columns: minmax(0, 2fr) minmax(0, 1fr);
    grid-column-gap: 10px;
    align-items: start;
    min-width: 0;
}

@media (max-width: 800px) {
    .lgh_diagnostic-page {
        grid-template-columns: minmax(0, 1fr);
    }
}

.lgh_diagnostic-page__right-bar {
    display: grid;
    grid-template-columns: 1fr;
    grid-row-gap: 10px;
}

.lgh_diagnostic-page__right-bar__wiki {
    border: 2px var(--background-color-low, lightgray) solid;
    border-radius: 4px;
    padding: 10px;

    display: grid;
    grid-template-columns: auto;
    grid-row-gap: 10px;
}

.lgh_diagnostic-page__right-bar__wiki--warning {
    border: 2px var(--warn-color-medium, orange) solid;
}
.lgh_diagnostic-page__right-bar__wiki--error {
    border: 2px var(--error-color-medium, red) solid;
}

.lgh_diagnostic-page__right-bar__wiki__content {
    display: grid;
    grid-template-columns: 1fr 5fr;
    grid-column-gap: 10px;
}

.lgh_diagnostic-page__right-bar__wiki__texts {}

.lgh_diagnostic-page__right-bar__actions {
    border: 2px var(--background-color-low, lightgray) solid;
    border-radius: 4px;
    padding: 10px;

    display: grid;
    grid-template-columns: auto;
    grid-row-gap: 10px;

}

.lgh_diagnostic-page__right-bar__actions > .lgh-partial-button {
    width: 100%;
    min-width: 0;
    margin-left: 0;
}

.lgh_diagnostic-page__right-bar__system-info {
    border: 2px var(--background-color-low, lightgray) solid;
    border-radius: 4px;
    padding: 10px;

    display: grid;
    grid-template-columns: auto;
    grid-row-gap: 10px;
}

.lgh_diagnostic-page__right-bar__system-info__title {

}

.lgh_diagnostic-page__right-bar__system-info__row {
    display: grid;
    grid-template-columns: auto 1fr;
    grid-column-gap: 5px;
}

.lgh_diagnostic-page__right-bar__system-info__row__tag {
    padding: 2px 4px;
    border: 1px transparent solid;
    border-radius: 4px;
    margin-left: 5px;
}

.lgh_diagnostic-page__right-bar__system-info__row__tag--neutral {
    border: 1px var(--background-color-high, gray) solid;
    color: var(--text-color-medium, gray);
}

.lgh_diagnostic-page__right-bar__system-info__row__tag--warning {
    border: 1px var(--warn-color-medium, orange) solid;
    color: var(--warn-color-medium, orange);
}

.lgh_diagnostic-page__right-bar__system-info__row__tag--success {
    border: 1px var(--success-color-medium, green) solid;
    color: var(--success-color-medium, green);
}

.lgh_diagnostic-page__left-bar {
    display: grid;
    grid-template-columns: 1fr;
    grid-row-gap: 10px;
}

.lgh_diagnostic-page__left-bar,
.lgh_diagnostic-page__right-bar,
.lgh_diagnostic-page__checks,
.lgh_diagnostic_alert__content,
.lgh_diagnostic_alert__actions,
.lgh_diagnostic_alert__summary,
.lgh_diagnostic_alert__summary__item > * {
    min-width: 0;
    overflow-wrap: anywhere;
}

.lgh_diagnostic-page__run_check_wrapper {
    display: flex;
    flex-wrap: wrap;
    gap: 10px;
    min-width: 0;
}

.lgh_diagnostic-page__run_check_wrapper > button:first-child {
    flex: 1 1 220px;
}

.lgh_diagnostic-page__cancel-hint {
    flex: 1 1 100%;
    min-width: 0;
    margin: 0;
    color: var(--text-color-medium, #888);
    font-size: 12px;
    overflow-wrap: anywhere;
}

.lgh_diagnostic-page__run_check_wrapper > button,
.lgh_diagnostic_alert__actions > button {
    min-width: 0;
    max-width: 100%;
    min-height: 44px;
    width: auto;
    margin: 0;
    box-sizing: border-box;
    white-space: normal;
    overflow-wrap: anywhere;
}

.lgh_diagnostic-page__run_check_wrapper > button > span,
.lgh_diagnostic_alert__actions > button > span {
    min-width: 0;
}

.lgh_diagnostic-page__checks {
    display: grid;
    grid-template-columns: 1fr;
    grid-row-gap: 10px;
}

.lgh_diagnostic_alert {
    border: 2px var(--background-color-low, lightgray) solid;
    border-radius: 4px;

    display: grid;
    grid-template-columns: 24px minmax(0, 1fr) auto;
    grid-column-gap: 10px;
    grid-row-gap: 10px;
    align-items: start;
    padding: 10px;
    min-width: 0;
    box-sizing: border-box;
}

.lgh_diagnostic_alert--loading {
    border: 2px var(--primary-color-high, dodgerblue) solid;
}

.lgh_diagnostic_alert--warning {
    border: 2px var(--warn-color-medium, orange) solid;
    color: var(--warn-color-medium, orange);
}

.lgh_diagnostic_alert--error {
    border: 2px var(--error-color-medium, red) solid;
    color: var(--error-color-medium, red);
}

.lgh_diagnostic_alert--success {
    border: 2px var(--success-color-medium, green) solid;
    color: var(--success-color-medium, green);
}

.lgh_diagnostic_alert--skipped {}

.lgh_diagnostic_alert__icon {}

.lgh_diagnostic_alert__content {}

.lgh_diagnostic_alert__title {
    display: block;
}

.lgh_diagnostic_alert__description {}

.lgh_diagnostic_alert__last-checked {
    display: flex;
    flex-wrap: wrap;
    gap: 4px 8px;
    margin-top: 8px;
    font-size: 12px;
    color: var(--text-color-medium, #888);
}

.lgh_diagnostic_alert__last-checked time {
    min-width: 0;
    font-variant-numeric: tabular-nums;
    overflow-wrap: anywhere;
}

.lgh_diagnostic_alert__summary {
    grid-column: 2 / -1;
}

.lgh_diagnostic_alert__summary__item {
    display: grid;
    grid-template-columns: 16px minmax(0, 1fr) minmax(0, 2fr);
    grid-column-gap: 10px;
    min-width: 0;
}

.lgh_diagnostic_alert__summary__item--error {
    color: var(--error-color-medium, red);
}

.lgh_diagnostic_alert__summary__item--warning {
    color: var(--warn-color-medium, orange);
}

.lgh_diagnostic_alert__summary__item--success {
    color: var(--success-color-medium, green);
}

.lgh_diagnostic_alert__summary__item__icon {
    width: 16px;
    height: 16px;
}

@media (max-width: 560px) {
    .lgh_diagnostic_alert {
        grid-template-columns: 24px minmax(0, 1fr);
    }

    .lgh_diagnostic_alert__actions {
        grid-column: 2 / -1;
    }

    .lgh_diagnostic_alert__summary__item {
        grid-template-columns: 16px minmax(0, 1fr);
        gap: 4px 10px;
    }

    .lgh_diagnostic_alert__summary__item > div {
        grid-column: 2;
    }

    .lgh_diagnostic-page__run_check_wrapper > button {
        flex: 1 1 100%;
    }
}
`;
