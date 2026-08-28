import { TabServiceInstance } from './tab.service';
import { store } from './store.service';
import { logger } from './logger.service';
import { LogHorizonLogWatcher } from './loghorizonLogWatcher.service';
import {
  getLogHorizonLogNotification,
  LogNotificationDeduper,
  LogHorizonLogNotification,
} from './logNotificationDeduper.service';
import { LogHorizonShellMethods } from '../methods';
import {
  registerRuntimeStateResumeRefresh,
  startRuntimeUiStatePolling,
} from './runtimeUiState.service';

type CoreServiceOptions = {
  waitForLogWatcherStart?: () => Promise<unknown>;
  logWatcherStartDelayMs?: number;
};

const LOG_WATCHER_INTERVAL_MS = 10000;
const LOG_WATCHER_START_DELAY_MS = 5000;

function componentDisplayName(component: string) {
  const names: Record<string, string> = {
    loghorizon: 'logIn',
    sing_box: 'sing-box',
    zapret: 'Zapret',
    zapret2: 'Zapret2',
    byedpi: 'ByeDPI',
  };

  return names[component] || component;
}

function showLogNotification(notification: LogHorizonLogNotification) {
  if (notification.kind === 'component-update') {
    const message = _('New version %s is available for %s')
      .replace('%s', notification.version)
      .replace('%s', componentDisplayName(notification.component));

    ui.addNotification(
      _('Component update available'),
      E('div', {}, message),
      'warning',
      'lgh-component-update-notification',
    );
    return;
  }

  ui.addNotification(
    _('logIn Error'),
    E('div', {}, notification.line),
    'error',
    'lgh-log-error-notification',
  );
}

export function coreService(options: CoreServiceOptions = {}) {
  TabServiceInstance.onChange((activeId, tabs) => {
    logger.info('[TAB]', activeId);
    store.set({
      tabService: {
        current: activeId || '',
        all: tabs.map((tab) => tab.id),
      },
    });
  });

  const watcher = LogHorizonLogWatcher.getInstance();
  const logNotificationDeduper = new LogNotificationDeduper();

  watcher.init(
    async () => {
      const logs = await LogHorizonShellMethods.checkLogs();

      if (logs.success) {
        return logs.data as string;
      }

      return '';
    },
    {
      intervalMs: LOG_WATCHER_INTERVAL_MS,
      onNewLog: (line) => {
        if (logNotificationDeduper.shouldNotify(line)) {
          const notification = getLogHorizonLogNotification(line);
          if (notification) {
            showLogNotification(notification);
          }
        }
      },
    },
  );

  const startWatcher = async () => {
    if (options.waitForLogWatcherStart) {
      await Promise.resolve()
        .then(() => options.waitForLogWatcherStart?.())
        .catch(() => null);
    }

    watcher.start();
  };
  const scheduleStartWatcher = () =>
    window.setTimeout(() => {
      void startWatcher();
    }, options.logWatcherStartDelayMs ?? LOG_WATCHER_START_DELAY_MS);

  if (typeof window !== 'undefined') {
    scheduleStartWatcher();
  } else {
    void startWatcher();
  }

  registerRuntimeStateResumeRefresh();
  startRuntimeUiStatePolling();
}
