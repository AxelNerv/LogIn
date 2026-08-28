// language=CSS
import { LOGHORIZON_UCI_PACKAGE as LOGHORIZON_CBI_PREFIX } from '../../../constants';

export const styles = `
#cbi-${LOGHORIZON_CBI_PREFIX}-updates-_mount_node > div {
    width: 100%;
}

#cbi-${LOGHORIZON_CBI_PREFIX}-updates > h3 {
    display: none;
}

.lgh_updates-page {
    width: 100%;
}

.lgh_updates-page__components {
    display: flex;
    align-items: flex-start;
    gap: 10px;
    width: 100%;
    flex-wrap: wrap;
}

.lgh_updates-page__components-column {
    display: flex;
    flex: 1 1 auto;
    flex-direction: column;
    gap: 10px;
    min-width: max-content;
}

@media (max-width: 760px) {
    .lgh_updates-page__components {
        flex-direction: column;
    }

    .lgh_updates-page__components-column {
        width: 100%;
        min-width: 0;
    }
}

.lgh_updates-page__component {
    border: 2px var(--background-color-low, lightgray) solid;
    border-radius: 4px;
    padding: 10px;
    display: flex;
    flex-direction: column;
    gap: 10px;
    min-width: max-content;
}

.lgh_updates-page__component__header {
    display: flex;
    align-items: center;
    flex-wrap: wrap;
    gap: 8px;
    border-bottom: 1px var(--background-color-low, lightgray) solid;
    padding-bottom: 8px;
    margin-bottom: 2px;
}

.lgh_updates-page__component__title {
    color: var(--text-color-high);
    font-size: 16px;
    font-weight: bold;
    line-height: 1.2;
}

.lgh_updates-page__component__header-version {
    color: var(--text-color-medium, #888);
    font-size: 13px;
    font-weight: normal;
}

.lgh_updates-page__component__details {
    display: flex;
    flex-direction: column;
    gap: 6px;
}

.lgh_updates-page__component__info-row {
    display: flex;
    justify-content: flex-start;
    align-items: center;
    min-height: 24px;
    gap: 8px;
    white-space: nowrap;
}

.lgh_updates-page__component__info-label {
    color: var(--text-color-medium, #888);
    font-size: 12px;
}

.lgh_updates-page__component__info-value {
    color: var(--text-color-high, #000);
    font-weight: 500;
    font-size: 13px;
    text-align: left;
    display: flex;
    align-items: center;
    gap: 6px;
    min-width: 0;
    overflow-wrap: anywhere;
}

.lgh_updates-page__component__info-value--latest {
    flex-wrap: wrap;
    justify-content: flex-start;
}

.lgh_updates-page__component__release-version-link {
    color: var(--link-color, #3498db) !important;
    text-decoration: underline;
    font-weight: bold;
}

.lgh_updates-page__component__release-version-link:hover {
    color: var(--link-color-dark, #2980b9) !important;
}

.lgh_updates-page__component__actions {
    display: flex;
    flex-direction: column;
    gap: 10px;
    margin-top: auto;
}

.lgh_updates-page__component__actions--with-details {
    border-top: 1px var(--background-color-low, lightgray) solid;
    padding-top: 10px;
}

.lgh_updates-page__component__actions-main {
    display: flex;
    justify-content: flex-start;
    align-items: center;
    flex-wrap: nowrap;
    gap: 6px;
}

.lgh_updates-page__component__variants {
    display: flex;
    flex-direction: column;
    gap: 6px;
    margin-top: 4px;
}

.lgh_updates-page__component__variants-title {
    font-size: 11px;
    font-weight: bold;
    color: var(--text-color-medium, gray);
}

.lgh_updates-page__component__variants-buttons {
    display: flex;
    flex-wrap: nowrap;
    gap: 6px;
}
`;
