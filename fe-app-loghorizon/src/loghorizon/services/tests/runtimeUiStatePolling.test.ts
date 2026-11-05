import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

const mocks = vi.hoisted(() => ({
  executeShellCommand: vi.fn(),
}));

vi.mock('../../../helpers', () => ({
  executeShellCommand: mocks.executeShellCommand,
}));

function uiState(runningAction: boolean) {
  return {
    service: {
      loghorizon: {
        running: 1,
        enabled: 1,
        status: 'running & enabled',
        dns_configured: 1,
      },
      sing_box: { running: 1, enabled: 0, status: 'running but disabled' },
    },
    capabilities: {
      sing_box_extended: 1,
      sing_box_tiny: 0,
      sing_box_compressed: 0,
      sing_box_tailscale: 1,
      zapret_installed: 1,
      zapret2_installed: 0,
      byedpi_installed: 0,
      server_inbounds_enabled_count: 0,
    },
    actions: {
      service: runningAction
        ? [{ kind: 'service', action: 'restart', running: true }]
        : [],
      latency: [],
      component: [],
      subscription: [],
    },
  };
}

function respondWith(runningAction: boolean) {
  mocks.executeShellCommand.mockResolvedValue({
    stdout: JSON.stringify(uiState(runningAction)),
    stderr: '',
    code: 0,
  });
}

describe('runtime UI state polling', () => {
  beforeEach(() => {
    vi.useFakeTimers();
    // Tests run in node; polling only starts where a window exists.
    vi.stubGlobal('window', globalThis);
    vi.resetModules();
    mocks.executeShellCommand.mockReset();
  });

  afterEach(() => {
    vi.unstubAllGlobals();
    vi.useRealTimers();
  });

  it('polls the router slowly while nothing is running', async () => {
    respondWith(false);
    const { startRuntimeUiStatePolling } = await import(
      '../runtimeUiState.service'
    );

    startRuntimeUiStatePolling();
    await vi.advanceTimersByTimeAsync(0);
    expect(mocks.executeShellCommand).toHaveBeenCalledTimes(1);

    await vi.advanceTimersByTimeAsync(4900);
    expect(mocks.executeShellCommand).toHaveBeenCalledTimes(1);

    await vi.advanceTimersByTimeAsync(200);
    expect(mocks.executeShellCommand).toHaveBeenCalledTimes(2);
  });

  it('switches to fast polling as soon as an action is seen', async () => {
    respondWith(false);
    const { refreshRuntimeUiState, startRuntimeUiStatePolling } = await import(
      '../runtimeUiState.service'
    );

    startRuntimeUiStatePolling();
    await vi.advanceTimersByTimeAsync(0);
    expect(mocks.executeShellCommand).toHaveBeenCalledTimes(1);

    // An action starts between idle polls and a forced refresh sees it.
    respondWith(true);
    await refreshRuntimeUiState({ force: true });
    expect(mocks.executeShellCommand).toHaveBeenCalledTimes(2);

    await vi.advanceTimersByTimeAsync(600);
    expect(mocks.executeShellCommand).toHaveBeenCalledTimes(3);
  });
});
