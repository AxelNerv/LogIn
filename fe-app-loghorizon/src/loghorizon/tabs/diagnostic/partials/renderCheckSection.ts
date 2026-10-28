import {
  renderCheckIcon24,
  renderCircleAlertIcon24,
  renderCircleCheckIcon24,
  renderCircleSlashIcon24,
  renderCircleXIcon24,
  renderLoaderCircleIcon24,
  renderSearchIcon24,
  renderTriangleAlertIcon24,
  renderXIcon24,
} from '../../../../icons';
import type { IDiagnosticsChecksStoreItem } from '../../../services';
import { renderButton } from '../../../../partials';

type IRenderCheckSectionProps = IDiagnosticsChecksStoreItem & {
  onRun?: () => void;
  disabled?: boolean;
};

const stateIcons = {
  loading: renderLoaderCircleIcon24,
  warning: renderCircleAlertIcon24,
  error: renderCircleXIcon24,
  success: renderCircleCheckIcon24,
  skipped: renderCircleSlashIcon24,
};

function renderCheckSummary(items: IRenderCheckSectionProps['items']) {
  const renderedItems = items.map((item) => {
    function getIcon() {
      const iconWrap = E('span', {
        class: 'lgh_diagnostic_alert__summary__item__icon',
      });
      iconWrap.setAttribute('aria-hidden', 'true');

      if (item.state === 'success') {
        iconWrap.appendChild(renderCheckIcon24());
      }

      if (item.state === 'warning') {
        iconWrap.appendChild(renderTriangleAlertIcon24());
      }

      if (item.state === 'error') {
        iconWrap.appendChild(renderXIcon24());
      }

      return iconWrap;
    }

    return E(
      'div',
      {
        class: `lgh_diagnostic_alert__summary__item lgh_diagnostic_alert__summary__item--${item.state}`,
      },
      [getIcon(), E('b', {}, item.key), E('div', {}, item.value)],
    );
  });

  return E('div', { class: 'lgh_diagnostic_alert__summary' }, renderedItems);
}

export function renderCheckSection(props: IRenderCheckSectionProps) {
  const renderStateIcon = stateIcons[props.state];
  if (!renderStateIcon) return E('div', {}, _('Not implement yet'));

  const loading = props.state === 'loading';
  const iconWrap = E('span', {
    class: 'lgh_diagnostic_alert__icon',
  });
  iconWrap.setAttribute('aria-hidden', 'true');
  iconWrap.appendChild(renderStateIcon());

  const content = E('div', { class: 'lgh_diagnostic_alert__content' }, [
    E('b', { class: 'lgh_diagnostic_alert__title' }, props.title),
    E('div', { class: 'lgh_diagnostic_alert__description' }, props.description),
  ]);
  const checkedAt = props.checkedAt;
  if (typeof checkedAt === 'number' && Number.isFinite(checkedAt)) {
    const checkedDate = new Date(checkedAt);
    if (!Number.isNaN(checkedDate.getTime())) {
      content.appendChild(
        E('div', { class: 'lgh_diagnostic_alert__last-checked' }, [
          E('span', {}, _('Last checked')),
          E(
            'time',
            { dateTime: checkedDate.toISOString() },
            checkedDate.toLocaleString(),
          ),
        ]),
      );
    }
  }

  const runButton = renderButton({
    text: _('Check'),
    icon: renderSearchIcon24,
    loading,
    disabled: props.disabled || !props.onRun,
    onClick: () => {
      if (!props.disabled && !loading) props.onRun?.();
    },
  });
  runButton.setAttribute('aria-label', `${_('Check')}: ${props.title}`);
  runButton.setAttribute('aria-busy', String(loading));

  const children = [
    iconWrap,
    content,
    E('div', { class: 'lgh_diagnostic_alert__actions' }, [runButton]),
  ];
  if (props.items.length) children.push(renderCheckSummary(props.items));

  return E(
    'div',
    { class: `lgh_diagnostic_alert lgh_diagnostic_alert--${props.state}` },
    children,
  );
}
