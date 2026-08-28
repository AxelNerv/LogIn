export function render() {
  return E(
    'div',
    {
      id: 'monitoring-status',
      class: 'lgh_monitoring-page',
    },
    [
      E('div', { class: 'lgh_monitoring-page__panel' }, [
        E('div', { class: 'lgh_monitoring-page__controls' }, [
          E('div', { class: 'lgh_monitoring-page__tabs' }, [
            E(
              'button',
              {
                id: 'monitoring-tab-active',
                class:
                  'btn cbi-button lgh_monitoring-page__tab lgh_monitoring-page__tab--active',
                type: 'button',
              },
              `${_('Active')} 0`,
            ),
            E(
              'button',
              {
                id: 'monitoring-tab-closed',
                class: 'btn cbi-button lgh_monitoring-page__tab',
                type: 'button',
              },
              `${_('Closed')} 0`,
            ),
          ]),
          E('div', { class: 'lgh_monitoring-page__filters' }, [
            E(
              'select',
              {
                id: 'monitoring-device-filter',
                class: 'cbi-input-select lgh_monitoring-page__device-filter',
              },
              [E('option', { value: 'all' }, _('All'))],
            ),
            E('label', { class: 'lgh_monitoring-page__search' }, [
              E('span', { class: 'lgh_monitoring-page__search-icon' }, []),
              E('input', {
                id: 'monitoring-search',
                class: 'cbi-input-text lgh_monitoring-page__search-input',
                type: 'search',
                placeholder: _('Search'),
                autocomplete: 'off',
              }),
            ]),
          ]),
          E('div', { class: 'lgh_monitoring-page__actions' }, [
            E(
              'button',
              {
                id: 'monitoring-close-all',
                class: 'btn cbi-button lgh_monitoring-page__icon-button',
                title: _('Close all connections'),
                'aria-label': _('Close all connections'),
                type: 'button',
                disabled: true,
              },
              [],
            ),
            E(
              'button',
              {
                id: 'monitoring-pause-toggle',
                class: 'btn cbi-button lgh_monitoring-page__icon-button',
                title: _('Pause updates'),
                'aria-label': _('Pause updates'),
                type: 'button',
              },
              [],
            ),
          ]),
        ]),
        E(
          'div',
          { id: 'monitoring-connections', class: 'lgh_monitoring-page__body' },
          [
            E(
              'div',
              {
                class:
                  'lgh_monitoring-page__state lgh_monitoring-page__state--loading',
              },
              _('Loading connections'),
            ),
          ],
        ),
      ]),
    ],
  );
}
