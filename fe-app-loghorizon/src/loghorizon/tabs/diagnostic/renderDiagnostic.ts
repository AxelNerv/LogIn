export function render() {
  return E('div', { id: 'diagnostic-status', class: 'lgh_diagnostic-page' }, [
    E('div', { class: 'lgh_diagnostic-page__left-bar' }, [
      E('div', { id: 'lgh_diagnostic-page-run-check' }),
      E('div', {
        class: 'lgh_diagnostic-page__checks',
        id: 'lgh_diagnostic-page-checks',
      }),
    ]),
    E('div', { class: 'lgh_diagnostic-page__right-bar' }, [
      E('div', { id: 'lgh_diagnostic-page-wiki' }),
      E('div', { id: 'lgh_diagnostic-page-actions' }),
      E('div', { id: 'lgh_diagnostic-page-system-info' }),
    ]),
  ]);
}
