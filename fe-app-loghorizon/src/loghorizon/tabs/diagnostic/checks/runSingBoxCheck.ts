import { DIAGNOSTICS_CHECKS_MAP } from './contstants';
import { LogHorizonShellMethods } from '../../../methods';
import { updateCheckStore } from './updateCheckStore';
import { getMeta } from '../helpers/getMeta';

export async function runSingBoxCheck() {
  const { order, title, code } = DIAGNOSTICS_CHECKS_MAP.SINGBOX;

  updateCheckStore({
    order,
    code,
    title,
    description: _('Checking, please wait'),
    state: 'loading',
    items: [],
  });

  const singBoxChecks = await LogHorizonShellMethods.checkSingBox();

  if (!singBoxChecks.success) {
    updateCheckStore({
      order,
      code,
      title,
      description: _('Cannot receive checks result'),
      state: 'error',
      items: [],
    });

    throw new Error('Sing-box checks failed');
  }

  const data = singBoxChecks.data;
  const insecureOutbounds = Array.isArray(data.tls_insecure_outbounds)
    ? data.tls_insecure_outbounds
    : [];
  const unpinnedInsecureOutbounds = Array.isArray(
    data.tls_unpinned_insecure_outbounds,
  )
    ? data.tls_unpinned_insecure_outbounds
    : [];

  const allGood =
    Boolean(data.sing_box_installed) &&
    Boolean(data.sing_box_version_ok) &&
    Boolean(data.sing_box_service_exist) &&
    Boolean(data.sing_box_autostart_disabled) &&
    Boolean(data.sing_box_process_running) &&
    Boolean(data.sing_box_ports_listening) &&
    Boolean(data.config_file_private) &&
    unpinnedInsecureOutbounds.length === 0;

  const atLeastOneGood =
    Boolean(data.sing_box_installed) ||
    Boolean(data.sing_box_version_ok) ||
    Boolean(data.sing_box_service_exist) ||
    Boolean(data.sing_box_autostart_disabled) ||
    Boolean(data.sing_box_process_running) ||
    Boolean(data.sing_box_ports_listening);

  const { state, description } = getMeta({ atLeastOneGood, allGood });

  updateCheckStore({
    order,
    code,
    title,
    description,
    state,
    items: [
      {
        state: data.sing_box_installed ? 'success' : 'error',
        key: _('Sing-box installed'),
        value: '',
      },
      {
        state: data.sing_box_version_ok ? 'success' : 'error',
        key: _('Sing-box version is compatible (newer than 1.12.4)'),
        value: '',
      },
      {
        state: data.sing_box_service_exist ? 'success' : 'error',
        key: _('Sing-box service exist'),
        value: '',
      },
      {
        state: data.sing_box_autostart_disabled ? 'success' : 'error',
        key: _('Sing-box autostart disabled'),
        value: '',
      },
      {
        state: data.sing_box_process_running ? 'success' : 'error',
        key: _('Sing-box process running'),
        value: '',
      },
      {
        state: data.sing_box_ports_listening ? 'success' : 'error',
        key: _('Sing-box listening ports'),
        value: '',
      },
      {
        state: data.config_file_private ? 'success' : 'warning',
        key: _('logIn configuration is private (root, 0600)'),
        value: data.config_file_private ? '' : _('Unsafe file permissions'),
      },
      {
        state: unpinnedInsecureOutbounds.length === 0 ? 'success' : 'warning',
        key: _('TLS certificate verification'),
        value:
          unpinnedInsecureOutbounds.length > 0
            ? _(
                'Disabled without a public-key pin for: %s. Configure a trusted certificate/SNI or a pin obtained through a trusted channel.',
              ).replace('%s', unpinnedInsecureOutbounds.join(', '))
            : insecureOutbounds.length > 0
              ? _('Disabled, but protected by a public-key pin')
              : _('Enabled'),
      },
    ],
  });

  if (!atLeastOneGood || !data.sing_box_process_running) {
    throw new Error('Sing-box checks failed');
  }
}
