'use strict';
'require baseclass';
'require fs';
'require uci';
'require ui';

if (typeof structuredClone !== 'function')
  globalThis.structuredClone = (obj) => JSON.parse(JSON.stringify(obj));

export { validateIP } from './validators/validateIp';
export { validateDomain } from './validators/validateDomain';
export { validateDNS } from './validators/validateDns';
export { validateUrl } from './validators/validateUrl';
export { validatePath } from './validators/validatePath';
export { validateSubnet } from './validators/validateSubnet';
export { bulkValidate } from './validators/bulkValidate';
export { validateOutboundJson } from './validators/validateOutboundJson';
export { validateProxyUrl } from './validators/validateProxyUrl';
export { parseValueList } from './helpers/parseValueList';
export { getProxyUrlName } from './helpers/getProxyUrlName';
export { injectGlobalStyles } from './helpers/injectGlobalStyles';
export { showToast } from './helpers/showToast';
export { getClashUIUrl } from './helpers/getClashApiUrl';
export { LogHorizonShellMethods } from './loghorizon/methods/shell';
export { coreService } from './loghorizon/services/core.service';
export { store } from './loghorizon/services/store.service';
export { applyUiStateToStore } from './loghorizon/services/uiState.service';
export { DashboardTab } from './loghorizon/tabs/dashboard';
export { DiagnosticTab } from './loghorizon/tabs/diagnostic';
export { MonitoringTab } from './loghorizon/tabs/monitoring';
export { UpdatesTab } from './loghorizon/tabs/updates';
export { LOGIN_BRAND } from './brand';
export {
  BOOTSTRAP_DNS_SERVER_OPTIONS,
  DEFAULT_LATENCY_TEST_URL,
  DNS_SERVER_OPTIONS,
  DOMAIN_LIST_OPTIONS,
  LATENCY_TEST_URL_OPTIONS,
  LOGHORIZON_ACTION_PROVIDERS_AVAILABILITY_EVENT,
  LOGHORIZON_UCI_PACKAGE,
} from './constants';
