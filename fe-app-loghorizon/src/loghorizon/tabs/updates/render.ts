export function render() {
  return E('div', { id: 'updates-status', class: 'lgh_updates-page' }, [
    E('div', {
      id: 'lgh_updates-components',
      class: 'lgh_updates-page__components',
    }),
  ]);
}
