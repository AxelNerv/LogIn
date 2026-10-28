import { runDnsCheck } from './checks/runDnsCheck';
import { runConnectivityPathCheck } from './checks/runConnectivityPathCheck';
import { runSingBoxCheck } from './checks/runSingBoxCheck';
import { runInboundsCheck } from './checks/runInboundsCheck';
import { runNftCheck } from './checks/runNftCheck';
import { runFakeIPCheck } from './checks/runFakeIPCheck';
import { runZapretCheck } from './checks/runZapretCheck';
import { runZapret2Check } from './checks/runZapret2Check';
import { runByedpiCheck } from './checks/runByedpiCheck';
import { runSectionsCheck } from './checks/runSectionsCheck';
import { DIAGNOSTICS_CHECKS } from './checks/contstants';
import type { DiagnosticsProviderOptions } from './diagnostic.store';

export interface DiagnosticRunner {
  code: DIAGNOSTICS_CHECKS;
  run: () => Promise<void>;
}

export function getDiagnosticRunners(
  options: DiagnosticsProviderOptions,
): DiagnosticRunner[] {
  return [
    { code: DIAGNOSTICS_CHECKS.DNS, run: runDnsCheck },
    { code: DIAGNOSTICS_CHECKS.CONNECTIVITY, run: runConnectivityPathCheck },
    { code: DIAGNOSTICS_CHECKS.SINGBOX, run: runSingBoxCheck },
    ...(options.includeInbounds
      ? [{ code: DIAGNOSTICS_CHECKS.INBOUNDS, run: runInboundsCheck }]
      : []),
    { code: DIAGNOSTICS_CHECKS.NFT, run: runNftCheck },
    ...(options.includeZapret
      ? [{ code: DIAGNOSTICS_CHECKS.ZAPRET, run: runZapretCheck }]
      : []),
    ...(options.includeZapret2
      ? [{ code: DIAGNOSTICS_CHECKS.ZAPRET2, run: runZapret2Check }]
      : []),
    ...(options.includeByedpi
      ? [{ code: DIAGNOSTICS_CHECKS.BYEDPI, run: runByedpiCheck }]
      : []),
    { code: DIAGNOSTICS_CHECKS.OUTBOUNDS, run: runSectionsCheck },
    { code: DIAGNOSTICS_CHECKS.FAKEIP, run: runFakeIPCheck },
  ];
}
