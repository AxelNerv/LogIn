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
        resources: {
          cpu_percent: 12.5,
          memory: { total_kib: 262144, available_kib: 131072 },
          load: { one: '0.10', five: '0.20', fifteen: '0.30' },
          conntrack: { count: 128, max: 16384 },
          nfqueue: {
            available: 1,
            queues: 2,
            queued: 0,
            kernel_dropped_delta: 0,
            userspace_dropped_delta: 0,
          },
          interfaces: [
            {
              name: 'wan',
              rx_dropped_delta: 0,
              tx_dropped_delta: 0,
              qdisc: {
                available: 1,
                backlog_bytes: 0,
                backlog_packets: 0,
                requeues: 0,
              },
            },
          ],
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
          expect.objectContaining({
            state: 'warning',
            key: 'UDP / QUIC / DoQ',
          }),
          expect.objectContaining({
            state: 'success',
            key: 'Packet queues during check',
            value: 'NFQUEUE drops 0 · interface drops 0 · qdisc backlog 0',
          }),
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

  it('reports a partial DoQ result as degraded instead of blocked', async () => {
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
          tcp_ms: 1,
          tls_ms: 20,
          total_ms: 30,
        },
        quic: {
          supported: 1,
          available: 1,
          skipped: 0,
          degraded: 1,
          reason: 'doq_degraded',
          successful_targets: 1,
          target_count: 2,
          targets: [
            {
              name: 'adguard',
              available: 1,
              reason: 'doq_available',
              latency_ms: 70,
            },
            {
              name: 'alidns',
              available: 0,
              reason: 'doq_timeout',
              latency_ms: 0,
            },
          ],
        },
      },
    });

    await expect(runConnectivityPathCheck()).resolves.toBeUndefined();
    expect(mocks.updateCheckStore).toHaveBeenLastCalledWith(
      expect.objectContaining({
        state: 'warning',
        description: 'HTTPS works, but one control path is degraded',
        items: expect.arrayContaining([
          expect.objectContaining({
            state: 'warning',
            key: 'UDP / QUIC / DoQ',
            value:
              'Available through 1 of 2 independent targets · adguard 70 ms · alidns: timeout',
          }),
        ]),
      }),
    );
  });

  it('shows only active VPN server metadata and marks fallback control degraded', async () => {
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
          tcp_ms: 1,
          tls_ms: 20,
          total_ms: 30,
        },
        quic: {
          supported: 1,
          available: 1,
          skipped: 0,
          degraded: 0,
          reason: 'doq_available',
          targets: [],
        },
        user_servers: {
          available: 1,
          skipped: 0,
          degraded: 1,
          reason: 'servers_degraded',
          successful_servers: 2,
          server_count: 2,
          servers: [
            {
              name: 'main-node',
              type: 'VLESS',
              available: 1,
              degraded: 0,
              reason: 'primary_available',
              delay_ms: 42,
            },
            {
              name: 'discord-node',
              type: 'Hysteria2',
              available: 1,
              degraded: 1,
              reason: 'fallback_available',
              delay_ms: 67,
            },
          ],
        },
      },
    });

    await expect(runConnectivityPathCheck()).resolves.toBeUndefined();
    expect(mocks.updateCheckStore).toHaveBeenLastCalledWith(
      expect.objectContaining({
        state: 'warning',
        description: 'HTTPS works, but one control path is degraded',
        items: expect.arrayContaining([
          expect.objectContaining({
            state: 'success',
            key: 'Active VPN server: main-node',
            value: 'VLESS · 42 ms · Available',
          }),
          expect.objectContaining({
            state: 'warning',
            key: 'Active VPN server: discord-node',
            value:
              'Hysteria2 · 67 ms · Available only through fallback control',
          }),
        ]),
      }),
    );
  });

  it('surfaces a local history write failure', async () => {
    mocks.checkConnectivityPath.mockResolvedValue({
      success: true,
      data: {
        available: 1,
        summary: 'https_ok',
        history_saved: 0,
        history_reason: 'history_write_failed',
        ipv4: {
          available: 1,
          skipped: 0,
          stage: 'ok',
          reason: 'server_responded',
          curl_status: 0,
          http_code: 204,
          tcp_ms: 1,
          tls_ms: 20,
          total_ms: 30,
        },
      },
    });

    await expect(runConnectivityPathCheck()).resolves.toBeUndefined();
    expect(mocks.updateCheckStore).toHaveBeenLastCalledWith(
      expect.objectContaining({
        state: 'warning',
        description: 'Connectivity works, but diagnostic history was not saved',
        items: expect.arrayContaining([
          expect.objectContaining({
            state: 'warning',
            key: 'Connectivity history',
            value: 'The diagnostic result could not be saved locally',
          }),
        ]),
      }),
    );
  });
});
