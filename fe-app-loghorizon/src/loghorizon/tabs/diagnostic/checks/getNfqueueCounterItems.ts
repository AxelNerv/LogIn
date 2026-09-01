import { IDiagnosticsChecksItem } from '../../../services';

interface NfqueueCounter {
  section?: unknown;
  queue?: unknown;
  rule_present?: unknown;
  tcp_packets?: unknown;
  udp_packets?: unknown;
  total_packets?: unknown;
}

export function getNfqueueCounterItems(
  counters: unknown,
): Array<IDiagnosticsChecksItem> {
  if (!Array.isArray(counters)) return [];

  return counters.map((raw: NfqueueCounter) => {
    const section = String(raw.section || '?');
    const queue = Number(raw.queue || 0);
    const tcpPackets = Number(raw.tcp_packets || 0);
    const udpPackets = Number(raw.udp_packets || 0);
    const totalPackets = Number(raw.total_packets ?? tcpPackets + udpPackets);
    const rulePresent = Boolean(raw.rule_present);

    let state: IDiagnosticsChecksItem['state'] = 'warning';
    let key = _('No NFQUEUE traffic observed for rule %s').replace(
      '%s',
      section,
    );
    if (!rulePresent) {
      state = 'error';
      key = _('NFQUEUE rules are missing for rule %s').replace('%s', section);
    } else if (totalPackets > 0) {
      state = 'success';
      key = _('NFQUEUE traffic reaches rule %s').replace('%s', section);
    }

    return {
      state,
      key,
      value: _('Queue %s · TCP %s · UDP %s')
        .replace('%s', String(queue))
        .replace('%s', String(tcpPackets))
        .replace('%s', String(udpPackets)),
    };
  });
}
