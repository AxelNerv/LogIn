import { beforeEach, describe, expect, it, vi } from 'vitest';

const mocks = vi.hoisted(() => ({
  checkConnectivityPath: vi.fn(),
  updateCheckStore: vi.fn(),
}));

vi.mock('../../../../methods', () => ({
  LogHorizonShellMethods: {
    checkConnectivityPath: mocks.checkConnectivityPath,
  },
}));

vi.mock('../updateCheckStore', () => ({
  updateCheckStore: mocks.updateCheckStore,
}));

import { runConnectivityPathCheck } from '../runConnectivityPathCheck';

describe('runConnectivityPathCheck', () => {
  beforeEach(() => {
    mocks.checkConnectivityPath.mockReset();
    mocks.updateCheckStore.mockReset();
  });

  it('reports HTTPS stages and keeps unsupported QUIC neutral', async () => {
    mocks.checkConnectivityPath.mockResolvedValue({
      success: true,
      data: {
        available: 1,
        summary: 'https_ok',
        ipv4: {
          available: 1,
          skipped: 0,
          stage: 'ok',
          reason: 'server_responded',
          curl_status: 0,
          http_code: 204,
          tcp_ms: 20,
          tls_ms: 45,
          total_ms: 80,
        },
        ipv6: {
          available: 0,
          skipped: 1,
          stage: 'route',
          reason: 'no_default_route',
          curl_status: 0,
          http_code: 0,
          tcp_ms: 0,
          tls_ms: 0,
          total_ms: 0,
        },
        quic: {
          supported: 0,
          available: 0,
          skipped: 1,
          reason: 'diagnostic_client_has_no_http3',
        },
      },
    });

    await expect(runConnectivityPathCheck()).resolves.toBeUndefined();
    expect(mocks.updateCheckStore).toHaveBeenLastCalledWith(
      expect.objectContaining({
        state: 'success',
        description: 'DNS, TCP handoff, TLS, and HTTP path is available',
        items: expect.arrayContaining([
          expect.objectContaining({
            state: 'success',
            key: 'IPv4 HTTPS',
            value: 'HTTP 204 · TCP handoff 20 ms · TLS 45 ms · total 80 ms',
          }),
          expect.objectContaining({ state: 'warning', key: 'QUIC / HTTP3' }),
        ]),
      }),
    );
  });

  it('does not call one failed control request proof of blocking', async () => {
    mocks.checkConnectivityPath.mockResolvedValue({
      success: true,
      data: {
        available: 0,
        summary: 'tls_failed',
        ipv4: {
          available: 0,
          skipped: 0,
          stage: 'tls',
          reason: 'tls_failed',
          curl_status: 35,
          http_code: 0,
          tcp_ms: 18,
          tls_ms: 0,
          total_ms: 31,
        },
        ipv6: {
          available: 0,
          skipped: 1,
          stage: 'route',
          reason: 'no_default_route',
          curl_status: 0,
          http_code: 0,
          tcp_ms: 0,
          tls_ms: 0,
          total_ms: 0,
        },
        quic: {
          supported: 0,
          available: 0,
          skipped: 1,
          reason: 'diagnostic_client_has_no_http3',
        },
      },
    });

    await expect(runConnectivityPathCheck()).rejects.toThrow(
      'Connection path is unavailable',
    );
    expect(mocks.updateCheckStore).toHaveBeenLastCalledWith(
      expect.objectContaining({
        state: 'error',
        description: 'TLS or upstream connection failed',
        items: expect.arrayContaining([
          expect.objectContaining({
            key: 'Interpretation',
            value:
              'TCP timing is the local transparent-proxy handoff. An upstream TCP or TLS failure may appear at the TLS stage, and one failed control request does not prove blocking.',
          }),
        ]),
      }),
    );
  });
});
