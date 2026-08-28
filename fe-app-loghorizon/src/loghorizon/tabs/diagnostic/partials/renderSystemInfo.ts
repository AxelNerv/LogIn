import { insertIf } from '../../../../helpers';

interface IRenderSystemInfoRow {
  key: string;
  value: string;
  tag?: {
    label: string;
    kind: 'neutral' | 'warning' | 'success';
  };
}

interface IRenderSystemInfoProps {
  items: Array<IRenderSystemInfoRow>;
}

export function renderSystemInfo({ items }: IRenderSystemInfoProps) {
  return E('div', { class: 'lgh_diagnostic-page__right-bar__system-info' }, [
    E(
      'b',
      { class: 'lgh_diagnostic-page__right-bar__system-info__title' },
      _('System information'),
    ),
    ...items.map((item) => {
      const tagClass = [
        'lgh_diagnostic-page__right-bar__system-info__row__tag',
        ...insertIf(item.tag?.kind === 'neutral', [
          'lgh_diagnostic-page__right-bar__system-info__row__tag--neutral',
        ]),
        ...insertIf(item.tag?.kind === 'warning', [
          'lgh_diagnostic-page__right-bar__system-info__row__tag--warning',
        ]),
        ...insertIf(item.tag?.kind === 'success', [
          'lgh_diagnostic-page__right-bar__system-info__row__tag--success',
        ]),
      ]
        .filter(Boolean)
        .join(' ');

      return E(
        'div',
        { class: 'lgh_diagnostic-page__right-bar__system-info__row' },
        [
          E('b', {}, item.key),
          E('div', {}, [
            E('span', {}, item.value),
            E('span', { class: tagClass }, item?.tag?.label),
          ]),
        ],
      );
    }),
  ]);
}
