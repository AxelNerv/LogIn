import { beforeEach, describe, expect, it, vi } from 'vitest';

const mocks = vi.hoisted(() => ({
  checkSingBox: vi.fn(),
  updateCheckStore: vi.fn(),
}));

vi.mock('../../../../methods', () => ({
  LogHorizonShellMethods: {
    checkSingBox: mocks.checkSingBox,
  },
}));

vi.mock('../updateCheckStore', () => ({
  updateCheckStore: mocks.updateCheckStore,
}));

import { runSingBoxCheck } from '../runSingBoxCheck';

const healthySingBox = {
  sing_box_installed: 1,
  sing_box_version_ok: 1,
  sing_box_service_exist: 1,
  sing_box_autostart_disabled: 1,
  sing_box_process_running: 1,
  sing_box_ports_listening: 1,
  config_file_private: 1,
  tls_insecure_outbounds: [],
  tls_unpinned_insecure_outbounds: [],
};

describe('sing-box security diagnostics', () => {
  beforeEach(() => {
    mocks.checkSingBox.mockReset();
    mocks.updateCheckStore.mockReset();
  });

  it('warns about insecure TLS without a public-key pin', async () => {
    mocks.checkSingBox.mockResolvedValue({
      success: true,
      data: {
        ...healthySingBox,
        tls_insecure_outbounds: ['Discord-1-out'],
        tls_unpinned_insecure_outbounds: ['Discord-1-out'],
      },
    });

    await runSingBoxCheck();

    const result = mocks.updateCheckStore.mock.calls.slice(-1)[0]?.[0];
    expect(result).toMatchObject({ state: 'warning' });
    expect(result.items).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          state: 'warning',
          key: 'TLS certificate verification',
          value: expect.stringContaining('Discord-1-out'),
        }),
      ]),
    );
  });

  it('accepts insecure TLS when a trusted public-key pin is configured', async () => {
    mocks.checkSingBox.mockResolvedValue({
      success: true,
      data: {
        ...healthySingBox,
        tls_insecure_outbounds: ['pinned-hy2'],
      },
    });

    await runSingBoxCheck();

    const result = mocks.updateCheckStore.mock.calls.slice(-1)[0]?.[0];
    expect(result).toMatchObject({ state: 'success' });
    expect(result.items).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          state: 'success',
          key: 'TLS certificate verification',
          value: 'Disabled, but protected by a public-key pin',
        }),
      ]),
    );
  });

  it('warns when the UCI configuration permissions expose secrets', async () => {
    mocks.checkSingBox.mockResolvedValue({
      success: true,
      data: { ...healthySingBox, config_file_private: 0 },
    });

    await runSingBoxCheck();

    const result = mocks.updateCheckStore.mock.calls.slice(-1)[0]?.[0];
    expect(result).toMatchObject({ state: 'warning' });
    expect(result.items).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          state: 'warning',
          key: 'logIn configuration is private (root, 0600)',
        }),
      ]),
    );
  });
});
