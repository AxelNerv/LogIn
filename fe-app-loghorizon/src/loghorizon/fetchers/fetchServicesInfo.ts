import { LogHorizonShellMethods } from '../methods';
import { logger } from '../services/logger.service';
import { store } from '../services/store.service';
import { refreshRuntimeUiState } from '../services/runtimeUiState.service';
import { logIn } from '../types';

let latestServicesInfoRequestId = 0;

function getSettledMethodResponse<T>(
  scope: string,
  result: PromiseSettledResult<logIn.MethodResponse<T>>,
): logIn.MethodResponse<T> {
  if (result.status === 'fulfilled') {
    return result.value;
  }

  logger.error('[SERVICES_INFO]', `${scope} failed`, result.reason);

  return {
    success: false,
    error: result.reason instanceof Error ? result.reason.message : '',
  };
}

export async function fetchServicesInfo() {
  const requestId = ++latestServicesInfoRequestId;
  const uiState = await refreshRuntimeUiState({ force: true });

  if (requestId !== latestServicesInfoRequestId) {
    return;
  }

  if (uiState) {
    return uiState;
  }

  const [loghorizonResult, singboxResult] = await Promise.allSettled([
    LogHorizonShellMethods.getStatus(),
    LogHorizonShellMethods.getSingBoxStatus(),
  ]);

  if (requestId !== latestServicesInfoRequestId) {
    return;
  }

  const loghorizon = getSettledMethodResponse('getStatus', loghorizonResult);
  const singbox = getSettledMethodResponse('getSingBoxStatus', singboxResult);
  const previousData = store.get().servicesInfoWidget.data;

  store.set({
    servicesInfoWidget: {
      loading: false,
      failed: !loghorizon.success || !singbox.success,
      data: {
        singbox: singbox.success ? singbox.data.running : previousData.singbox,
        loghorizonRunning: loghorizon.success
          ? loghorizon.data.running
          : previousData.loghorizonRunning,
        loghorizonEnabled: loghorizon.success
          ? loghorizon.data.enabled
          : previousData.loghorizonEnabled,
        loghorizonStatus: loghorizon.success
          ? loghorizon.data.status
          : previousData.loghorizonStatus,
      },
    },
  });

  return undefined;
}
