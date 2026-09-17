import { DIAGNOSTICS_CHECKS_MAP } from './contstants';
import { LogHorizonShellMethods } from '../../../methods';
import type { IDiagnosticsChecksItem } from '../../../services';
import type { logIn } from '../../../types';
import { updateCheckStore } from './updateCheckStore';

type CheckState = IDiagnosticsChecksItem['state'];

function stageLabel(stage: logIn.ConnectivityProbeResult['stage']) {
  switch (stage) {
    case 'dns':
      return _('DNS resolution failed');
    case 'tcp':
      return _('TCP connection failed');
    case 'tls':
      return _('TLS or upstream connection failed');
    case 'http':
      return _('HTTP request failed');
    case 'route':
      return _('No default route');
    default:
      return _('Available');
  }
}

function familyItem(
  family: 'IPv4' | 'IPv6',
  probe: logIn.ConnectivityProbeResult | undefined,
  required: boolean,
): IDiagnosticsChecksItem {
  if (!probe) {
    return {
      state: required ? 'error' : 'warning',
      key: family,
      value: _('No result'),
    };
  }

  if (probe.skipped) {
    return {
      state: 'warning',
      key: `${family} HTTPS`,
      value: stageLabel(probe.stage),
    };
  }

  if (!probe.available) {
    return {
      state: required ? 'error' : 'warning',
      key: `${family} HTTPS`,
      value: `${stageLabel(probe.stage)} · curl ${probe.curl_status}`,
    };
  }

  const tcpHandoff = probe.tcp_ms > 0 ? `${probe.tcp_ms} ms` : '<1 ms';

  return {
    state: 'success',
    key: `${family} HTTPS`,
    value: `HTTP ${probe.http_code} · ${_('TCP handoff')} ${tcpHandoff} · TLS ${probe.tls_ms} ms · ${_('total')} ${probe.total_ms} ms`,
  };
}

function quicItem(
  quic: logIn.ConnectivityQuicResult | undefined,
): IDiagnosticsChecksItem {
  if (!quic || !quic.supported) {
    return {
      state: 'warning',
      key: 'UDP / QUIC / DoQ',
      value: _('Not tested: the sing-box build has no QUIC support'),
    };
  }

  const targetDetails = (quic.targets ?? [])
    .map((target) => {
      if (target.available) return `${target.name} ${target.latency_ms} ms`;
      let reason = _('failed');
      if (target.reason === 'doq_timeout') reason = _('timeout');
      else if (target.reason === 'doq_tls_failed')
        reason = _('TLS validation failed');
      else if (target.reason === 'doq_route_unavailable')
        reason = _('No route');
      else if (target.reason === 'doq_dns_response_error')
        reason = _('DNS response error');
      return `${target.name}: ${reason}`;
    })
    .join(' · ');

  if (quic.available) {
    return {
      state: quic.degraded ? 'warning' : 'success',
      key: 'UDP / QUIC / DoQ',
      value: quic.degraded
        ? `${_('Available through %s of %s independent targets')
            .replace('%s', String(quic.successful_targets ?? 0))
            .replace(
              '%s',
              String(quic.target_count ?? 0),
            )}${targetDetails ? ` · ${targetDetails}` : ''}`
        : `${_('Available')}${targetDetails ? ` · ${targetDetails}` : ''}`,
    };
  }

  return {
    state: 'warning',
    key: 'UDP / QUIC / DoQ',
    value: `${_(
      'Independent DoQ controls failed; this alone does not prove UDP blocking',
    )}${targetDetails ? ` · ${targetDetails}` : ''}`,
  };
}

function resourceItems(
  resources: logIn.ConnectivityResourcesResult | undefined,
): IDiagnosticsChecksItem[] {
  if (!resources) return [];

  const memoryAvailable = resources.memory.available_kib;
  const memoryTotal = resources.memory.total_kib;
  const memoryPercent =
    memoryAvailable !== null && memoryTotal !== null && memoryTotal > 0
      ? Math.round((memoryAvailable * 100) / memoryTotal)
      : null;
  const conntrackPercent =
    resources.conntrack.count !== null &&
    resources.conntrack.max !== null &&
    resources.conntrack.max > 0
      ? Math.round((resources.conntrack.count * 100) / resources.conntrack.max)
      : null;
  const nfqueueDrops =
    resources.nfqueue.kernel_dropped_delta +
    resources.nfqueue.userspace_dropped_delta;
  const interfaceDrops = resources.interfaces.reduce(
    (sum, item) => sum + item.rx_dropped_delta + item.tx_dropped_delta,
    0,
  );
  const backlogPackets = resources.interfaces.reduce(
    (sum, item) => sum + (item.qdisc?.backlog_packets ?? 0),
    0,
  );
  const qdiscAvailable = resources.interfaces.some(
    (item) => item.qdisc?.available,
  );

  return [
    {
      state:
        resources.cpu_percent === null || resources.cpu_percent >= 90
          ? 'warning'
          : 'success',
      key: _('Router load during check'),
      value: `${_('CPU')} ${resources.cpu_percent ?? '?'}% · ${_('load average')} ${resources.load.one || '?'} / ${resources.load.five || '?'} / ${resources.load.fifteen || '?'}`,
    },
    {
      state:
        memoryPercent === null || memoryPercent < 10 ? 'warning' : 'success',
      key: _('Available memory'),
      value:
        memoryAvailable !== null && memoryPercent !== null
          ? `${Math.round(memoryAvailable / 1024)} MiB · ${memoryPercent}%`
          : _('Not available'),
    },
    {
      state:
        conntrackPercent === null || conntrackPercent >= 90
          ? 'warning'
          : 'success',
      key: _('Connection tracking table'),
      value:
        resources.conntrack.count !== null &&
        resources.conntrack.max !== null &&
        conntrackPercent !== null
          ? `${resources.conntrack.count} / ${resources.conntrack.max} · ${conntrackPercent}%`
          : _('Not available'),
    },
    {
      state:
        !resources.nfqueue.available || nfqueueDrops > 0 || interfaceDrops > 0
          ? 'warning'
          : 'success',
      key: _('Packet queues during check'),
      value: resources.nfqueue.available
        ? `${_('NFQUEUE drops')} ${nfqueueDrops} · ${_('interface drops')} ${interfaceDrops} · ${_('qdisc backlog')} ${qdiscAvailable ? backlogPackets : _('Not available')}`
        : _('NFQUEUE counters are not available'),
    },
  ];
}

function userServerItems(
  result: logIn.ConnectivityUserServersResult | undefined,
): IDiagnosticsChecksItem[] {
  if (!result || result.skipped) {
    const reason =
      result?.reason === 'clash_api_unavailable'
        ? _('Clash API is unavailable')
        : result?.reason === 'config_unavailable'
          ? _('Generated sing-box config is unavailable')
          : _('No active VPN server is used by current routes');
    return [
      {
        state: 'warning',
        key: _('Active VPN server'),
        value: `${_('Not tested')} · ${reason}`,
      },
    ];
  }

  return (result.servers ?? []).map((server) => {
    const protocol = server.type || _('Unknown protocol');
    if (!server.available) {
      return {
        state: 'error',
        key: `${_('Active VPN server')}: ${server.name}`,
        value: `${protocol} · ${_('Both independent control requests failed')}`,
      };
    }
    return {
      state: server.degraded ? 'warning' : 'success',
      key: `${_('Active VPN server')}: ${server.name}`,
      value: server.degraded
        ? `${protocol} · ${server.delay_ms} ms · ${_('Available only through fallback control')}`
        : `${protocol} · ${server.delay_ms} ms · ${_('Available')}`,
    };
  });
}

function historyItems(
  data: logIn.ConnectivityPathCheckResult,
): IDiagnosticsChecksItem[] {
  if (data.history_saved !== 0) return [];
  return [
    {
      state: 'warning',
      key: _('Connectivity history'),
      value: _('The diagnostic result could not be saved locally'),
    },
  ];
}

export async function runConnectivityPathCheck() {
  const { order, title, code } = DIAGNOSTICS_CHECKS_MAP.CONNECTIVITY;

  updateCheckStore({
    order,
    code,
    title,
    description: _('Checking, please wait'),
    state: 'loading',
    items: [],
  });

  const response = await LogHorizonShellMethods.checkConnectivityPath();
  if (!response.success) {
    updateCheckStore({
      order,
      code,
      title,
      description: _('Cannot receive checks result'),
      state: 'error',
      items: [],
    });
    throw new Error('Connection path check failed');
  }

  const data = response.data;
  if (data.summary === 'diagnostic_tools_missing') {
    const items: IDiagnosticsChecksItem[] = [
      {
        state: data.dig_available ? 'success' : 'error',
        key: 'dig',
        value: data.dig_available ? _('Installed') : _('Not installed'),
      },
      {
        state: data.curl_available ? 'success' : 'error',
        key: 'curl',
        value: data.curl_available ? _('Installed') : _('Not installed'),
      },
    ];
    updateCheckStore({
      order,
      code,
      title,
      description: _('Diagnostic tools are missing'),
      state: 'error',
      items,
    });
    throw new Error('Connection path tools are missing');
  }

  const ipv4Required = !data.ipv6?.available;
  const items = [
    familyItem('IPv4', data.ipv4, ipv4Required),
    familyItem('IPv6', data.ipv6, false),
    quicItem(data.quic),
    ...userServerItems(data.user_servers),
    ...resourceItems(data.resources),
    ...historyItems(data),
    {
      state: 'warning' as CheckState,
      key: _('Interpretation'),
      value: _(
        'TCP timing is the local transparent-proxy handoff. An upstream TCP or TLS failure may appear at the TLS stage, and one failed control request does not prove blocking.',
      ),
    },
  ];

  const quicFailure = Boolean(
    data.quic?.supported && (!data.quic.available || data.quic.degraded),
  );
  const userServerFailure = Boolean(
    data.user_servers &&
      !data.user_servers.skipped &&
      (!data.user_servers.available || data.user_servers.degraded),
  );
  const historyFailure = data.history_saved === 0;
  const controlPathFailure = quicFailure || userServerFailure;
  const state: CheckState = data.available
    ? controlPathFailure || historyFailure
      ? 'warning'
      : 'success'
    : 'error';
  const description = data.available
    ? historyFailure
      ? _('Connectivity works, but diagnostic history was not saved')
      : controlPathFailure
        ? _('HTTPS works, but one control path is degraded')
        : _('DNS, TCP handoff, TLS, and HTTP path is available')
    : stageLabel(data.ipv4?.stage ?? data.ipv6?.stage ?? 'http');

  updateCheckStore({ order, code, title, description, state, items });
  if (!data.available) throw new Error('Connection path is unavailable');
}
