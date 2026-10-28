import { logger, store } from '../../services';
import type { IDiagnosticsChecksStoreItem } from '../../services';
import {
  DIAGNOSTICS_CHECKS,
  DIAGNOSTICS_CHECKS_MAP,
} from './checks/contstants';
import { getDiagnosticRunners } from './diagnosticRunners';
import { mergeDiagnosticsChecks } from './diagnostic.store';
import type { DiagnosticsProviderOptions } from './diagnostic.store';
import {
  clearPersistedDiagnosticRun,
  savePersistedDiagnosticRun,
} from './diagnosticRunPersistence';
import type { PersistedDiagnosticRun } from './diagnosticRunPersistence';

interface RunOptions {
  code?: DIAGNOSTICS_CHECKS;
  resume?: PersistedDiagnosticRun;
  refreshProviders: () => Promise<void>;
  getProviderOptions: () => DiagnosticsProviderOptions;
  canRun: () => boolean;
  onFinished?: () => void;
}

interface ActiveRun {
  codes: DIAGNOSTICS_CHECKS[];
  nextRunnerIndex: number;
  providerOptions: DiagnosticsProviderOptions;
  cancelRequested: boolean;
}

// One lock covers both buttons and reload recovery in the same page runtime.
let activeRun: ActiveRun | null = null;

function patchCheck(
  code: DIAGNOSTICS_CHECKS,
  patch: Partial<IDiagnosticsChecksStoreItem>,
) {
  const checks = store.get().diagnosticsChecks;
  const previous = checks.find((item) => item.code === code);
  store.set({
    diagnosticsChecks: [
      ...checks.filter((item) => item.code !== code),
      {
        ...DIAGNOSTICS_CHECKS_MAP[code],
        description: _('Not running'),
        state: 'skipped',
        items: [],
        ...previous,
        ...patch,
      },
    ],
  });
}

function persist(run: ActiveRun) {
  savePersistedDiagnosticRun({
    checkCodes: run.codes,
    nextRunnerIndex: run.nextRunnerIndex,
    providerOptions: run.providerOptions,
    cancelRequested: run.cancelRequested,
    diagnosticsChecks: store.get().diagnosticsChecks,
  });
}

export function cancelDiagnosticRun() {
  if (!activeRun || activeRun.cancelRequested) return;
  activeRun.cancelRequested = true;
  store.set({
    diagnosticsRunAction: {
      ...store.get().diagnosticsRunAction,
      cancelling: true,
    },
  });
  persist(activeRun);
}

export async function runDiagnosticChecks(
  options: RunOptions,
): Promise<boolean> {
  if (
    activeRun ||
    (!options.resume &&
      (store.get().diagnosticsRunAction.loading || !options.canRun()))
  )
    return false;

  const providerOptions =
    options.resume?.providerOptions ?? options.getProviderOptions();
  const run: ActiveRun = {
    codes:
      options.resume?.checkCodes ??
      (options.code
        ? [options.code]
        : getDiagnosticRunners(providerOptions).map((r) => r.code)),
    nextRunnerIndex: options.resume?.nextRunnerIndex ?? 0,
    providerOptions,
    cancelRequested: options.resume?.cancelRequested ?? false,
  };
  activeRun = run;
  if (options.resume)
    store.set({ diagnosticsChecks: options.resume.diagnosticsChecks });
  store.set({
    diagnosticsRunAction: {
      loading: true,
      checkCodes: run.codes,
      cancelling: run.cancelRequested,
    },
  });
  // Mark only the selected checks; unrelated results and timestamps stay intact.
  const preparePending = () => {
    for (const code of run.codes.slice(run.nextRunnerIndex))
      patchCheck(code, {
        state: 'skipped',
        description: _('Pending'),
        items: [],
      });
  };
  preparePending();
  persist(run);
  try {
    // A reloaded page has no capability/service snapshot yet. Refresh metadata
    // before recovery too, without expanding the persisted selection.
    if (!run.cancelRequested) {
      await options.refreshProviders();
      run.providerOptions = options.getProviderOptions();
      if (!options.resume && !options.code)
        run.codes = getDiagnosticRunners(run.providerOptions).map(
          (r) => r.code,
        );
      store.set({
        diagnosticsChecks: mergeDiagnosticsChecks(
          store.get().diagnosticsChecks,
          run.providerOptions,
        ),
        diagnosticsRunAction: {
          loading: true,
          checkCodes: run.codes,
          cancelling: run.cancelRequested,
        },
      });
      preparePending();
      persist(run);
    }
    const runners = getDiagnosticRunners(run.providerOptions);
    for (let index = run.nextRunnerIndex; index < run.codes.length; index++) {
      run.nextRunnerIndex = index;
      if (run.cancelRequested) break;
      const code = run.codes[run.nextRunnerIndex];
      const runner = runners.find((item) => item.code === code);
      if (!runner) {
        patchCheck(code, {
          state: 'skipped',
          description: _('Check is unavailable for the current configuration'),
          checkedAt: undefined,
          items: [],
        });
        run.nextRunnerIndex = index + 1;
        persist(run);
        continue;
      }
      if (!options.canRun())
        throw new Error(
          'Diagnostics are unavailable during a service transition',
        );
      patchCheck(code, {
        state: 'loading',
        description: _('Checking, please wait'),
        items: [],
      });
      persist(run);
      let failed = false;
      try {
        await runner.run();
      } catch (error) {
        failed = true;
        logger.error('[DIAGNOSTIC]', `Check ${code} failed`, error);
      }
      const result = store
        .get()
        .diagnosticsChecks.find((item) => item.code === code);
      if (run.cancelRequested) {
        patchCheck(code, {
          state: 'skipped',
          description: _('Cancelled'),
          checkedAt: undefined,
          items: [],
        });
      } else if (failed || !result || result.state === 'loading') {
        patchCheck(code, {
          state: 'error',
          description:
            result?.state === 'error'
              ? result.description
              : _('Cannot receive checks result'),
          checkedAt: Date.now(),
        });
      } else {
        patchCheck(code, { checkedAt: Date.now() });
      }
      // The persisted cursor always points at the next unfinished check.
      run.nextRunnerIndex = index + 1;
      persist(run);
    }
  } catch (error) {
    logger.error('[DIAGNOSTIC]', 'Diagnostic run failed', error);
    if (!run.cancelRequested)
      for (const code of run.codes.slice(run.nextRunnerIndex))
        patchCheck(code, {
          state: 'error',
          description: _('Cannot receive checks result'),
          items: [],
          checkedAt: Date.now(),
        });
  } finally {
    if (run.cancelRequested)
      for (const code of run.codes.slice(run.nextRunnerIndex))
        patchCheck(code, {
          state: 'skipped',
          description: _('Cancelled'),
          items: [],
          checkedAt: undefined,
        });
    clearPersistedDiagnosticRun();
    activeRun = null;
    store.set({ diagnosticsRunAction: { loading: false } });
    options.onFinished?.();
  }
  return true;
}
