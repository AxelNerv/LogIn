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
    grid-template-columns: 2fr 1fr;
    grid-column-gap: 10px;
    align-items: start;
}

@media (max-width: 800px) {
    .lgh_diagnostic-page {
        grid-template-columns: 1fr;
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

.lgh_diagnostic-page__run_check_wrapper {}

.lgh_diagnostic-page__run_check_wrapper button {
    width: 100%;
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
    grid-template-columns: 24px 1fr;
    grid-column-gap: 10px;
    align-items: center;
    padding: 10px;
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

.lgh_diagnostic_alert__summary {
    margin-top: 10px;
}

.lgh_diagnostic_alert__summary__item {
    display: grid;
    grid-template-columns: 16px auto 1fr;
    grid-column-gap: 10px;
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
`;
