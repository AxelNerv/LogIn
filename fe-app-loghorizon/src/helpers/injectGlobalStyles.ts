import { GlobalStyles } from '../styles';

const LOGHORIZON_GLOBAL_STYLES_ID = 'loghorizon-global-styles';

export function injectGlobalStyles() {
  if (document.getElementById(LOGHORIZON_GLOBAL_STYLES_ID)) {
    return;
  }

  document.head.insertAdjacentHTML(
    'beforeend',
    `
        <style id="${LOGHORIZON_GLOBAL_STYLES_ID}">
          ${GlobalStyles}
        </style>
    `,
  );
}
