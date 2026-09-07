import { beforeEach, describe, expect, it, vi } from 'vitest';

const mocks = vi.hoisted(() => ({
  getFakeIpCheck: vi.fn(),
  getIpCheck: vi.fn(),
  checkNftRules: vi.fn(),
  updateCheckStore: vi.fn(),
}));

vi.mock('../../../../methods', () => ({
  RemoteFakeIPMethods: {
    getFakeIpCheck: mocks.getFakeIpCheck,
    getIpCheck: mocks.getIpCheck,
  },
  LogHorizonShellMethods: {
    checkNftRules: mocks.checkNftRules,
  },
}));

vi.mock('../updateCheckStore', () => ({
  updateCheckStore: mocks.updateCheckStore,
}));

import { runNftCheck } from '../runNftCheck';

const healthyNft = {
  table_exist: 1,
  rules_mangle_exist: 1,
  rules_mangle_counters: 1,
  rules_mangle_output_exist: 1,
  rules_mangle_output_counters: 1,
  rules_proxy_exist: 1,
  rules_proxy_counters: 1,
  rules_other_mark_exist: 0,
  flow_offloading_enabled: 0,
  flow_offloading_hw_enabled: 0,
};

describe('nftables diagnostics check', () => {
  beforeEach(() => {
    Object.values(mocks).forEach((mock) => mock.mockReset());
    mocks.getFakeIpCheck.mockResolvedValue(undefined);
    mocks.getIpCheck.mockResolvedValue(undefined);
  });

  it('warns when software flow offloading is enabled', async () => {
    mocks.checkNftRules.mockResolvedValue({
      success: true,
      data: { ...healthyNft, flow_offloading_enabled: 1 },
    });

    await runNftCheck();

    const result = mocks.updateCheckStore.mock.calls.slice(-1)[0]?.[0];
    expect(result).toMatchObject({ state: 'warning' });
    expect(result.items).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          state: 'warning',
          key: 'Software flow offloading is enabled',
        }),
      ]),
    );
  });

  it('warns more explicitly when hardware flow offloading is enabled', async () => {
    mocks.checkNftRules.mockResolvedValue({
      success: true,
      data: { ...healthyNft, flow_offloading_hw_enabled: 1 },
    });

    await runNftCheck();

    const result = mocks.updateCheckStore.mock.calls.slice(-1)[0]?.[0];
    expect(result).toMatchObject({ state: 'warning' });
    expect(result.items).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          state: 'warning',
          key: 'Hardware flow offloading is enabled',
          value: 'DPI traffic may bypass NFQUEUE entirely',
        }),
      ]),
    );
  });
});
