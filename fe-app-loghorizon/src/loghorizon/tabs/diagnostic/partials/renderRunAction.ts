import { renderButton } from '../../../../partials';
import { renderSearchIcon24 } from '../../../../icons';

interface IRenderDiagnosticRunActionProps {
  loading: boolean;
  disabled?: boolean;
  click: () => void;
  running?: boolean;
  cancelling?: boolean;
  cancel?: () => void;
}

export function renderRunAction({
  loading,
  disabled,
  click,
  running,
  cancelling,
  cancel,
}: IRenderDiagnosticRunActionProps) {
  const runButton = renderButton({
    text: _('Run all checks'),
    onClick: click,
    icon: renderSearchIcon24,
    loading,
    disabled: disabled || running || cancelling,
    classNames: ['cbi-button-apply'],
  });
  runButton.setAttribute('aria-label', _('Run all checks'));
  runButton.setAttribute('aria-busy', String(loading));

  const buttons = [runButton];
  if (running) {
    const cancelText = cancelling ? _('Cancelling') : _('Cancel');
    const cancelButton = renderButton({
      text: cancelText,
      onClick: () => {
        if (!cancelling) cancel?.();
      },
      disabled: cancelling || !cancel,
    });
    cancelButton.setAttribute('aria-label', cancelText);
    cancelButton.setAttribute('aria-busy', String(Boolean(cancelling)));
    buttons.push(cancelButton);
  }

  const wrapper = E(
    'div',
    { class: 'lgh_diagnostic-page__run_check_wrapper' },
    buttons,
  );
  if (cancelling) {
    const hint = E(
      'p',
      { class: 'lgh_diagnostic-page__cancel-hint' },
      _(
        'The current request will finish before the remaining checks are cancelled.',
      ),
    );
    hint.setAttribute('role', 'status');
    hint.setAttribute('aria-live', 'polite');
    wrapper.appendChild(hint);
  }
  return wrapper;
}
