import { beforeEach, describe, expect, it, vi } from 'vitest';
import type { StoreType } from '../../../services';
import type { DiagnosticRunner } from '../diagnosticRunners';
import { DIAGNOSTICS_CHECKS as C } from '../checks/contstants';
import {
  getDiagnosticsChecks,
  mergeDiagnosticsChecks,
} from '../diagnostic.store';
import { cancelDiagnosticRun, runDiagnosticChecks } from '../diagnosticRun';

type State = Pick<StoreType, 'diagnosticsChecks' | 'diagnosticsRunAction'>;
const runtime = vi.hoisted(() => ({
  state: {} as State,
  runners: [] as DiagnosticRunner[],
  saved: [] as unknown[],
  cleared: vi.fn(),
  error: vi.fn(),
}));
vi.mock('../../../services', () => ({
  logger: { error: runtime.error },
  store: {
    get: () => runtime.state,
    set: (patch: Partial<State>) => {
      runtime.state = { ...runtime.state, ...patch };
    },
  },
}));
vi.mock('../diagnosticRunners', () => ({
  getDiagnosticRunners: () => runtime.runners,
}));
vi.mock('../diagnosticRunPersistence', () => ({
  savePersistedDiagnosticRun: (value: unknown) =>
    runtime.saved.push(structuredClone(value)),
  clearPersistedDiagnosticRun: runtime.cleared,
}));

function setResult(
  code: C,
  state: 'success' | 'error' | 'warning' = 'success',
  description = 'done',
) {
  runtime.state.diagnosticsChecks = runtime.state.diagnosticsChecks.map(
    (item) =>
      item.code === code
        ? {
            ...item,
            state,
            description,
            items: [{ state, key: code, value: 'result' }],
          }
        : item,
  );
}
function check(code: C) {
  return runtime.state.diagnosticsChecks.find((item) => item.code === code)!;
}
function deferred() {
  let resolve!: () => void;
  const promise = new Promise<void>((done) => {
    resolve = done;
  });
  return { promise, resolve };
}
const options = () => ({
  refreshProviders: vi.fn(async () => {}),
  getProviderOptions: () => ({}),
  canRun: () => true,
});

beforeEach(() => {
  vi.clearAllMocks();
  runtime.saved = [];
  runtime.state = {
    diagnosticsRunAction: { loading: false },
    diagnosticsChecks: getDiagnosticsChecks('old').map((item) => ({
      ...item,
      state: 'success',
      checkedAt: 1000,
    })),
  };
  runtime.runners = [C.DNS, C.CONNECTIVITY, C.NFT].map((code) => ({
    code,
    run: vi.fn(async () => setResult(code)),
  }));
});

describe('shared diagnostic runs', () => {
  it('refreshes cold-page capabilities before resuming only the selected check', async () => {
    let ready = false;
    await runDiagnosticChecks({
      ...options(),
      canRun: () => ready,
      refreshProviders: async () => {
        ready = true;
      },
      resume: {
        checkCodes: [C.NFT],
        nextRunnerIndex: 0,
        providerOptions: {},
        diagnosticsChecks: runtime.state.diagnosticsChecks,
        updatedAt: Date.now(),
      },
    });
    expect(check(C.NFT).state).toBe('success');
    expect(runtime.runners[2].run).toHaveBeenCalledOnce();
    expect(runtime.runners[0].run).not.toHaveBeenCalled();
  });

  it('handles a metadata failure without clearing unrelated results or holding the lock', async () => {
    const old = structuredClone(check(C.NFT));
    await runDiagnosticChecks({
      ...options(),
      code: C.DNS,
      refreshProviders: async () => {
        throw new Error('Metadata unavailable');
      },
    });
    expect(check(C.DNS).state).toBe('error');
    expect(check(C.NFT)).toEqual(old);
    expect(runtime.state.diagnosticsRunAction.loading).toBe(false);
    runtime.runners.forEach((runner) =>
      expect(runner.run).not.toHaveBeenCalled(),
    );
    expect(await runDiagnosticChecks({ ...options(), code: C.DNS })).toBe(true);
  });

  it('does not restore a second run over an active single check', async () => {
    const gate = deferred();
    const pending = runDiagnosticChecks({
      ...options(),
      code: C.DNS,
      refreshProviders: () => gate.promise,
    });
    expect(
      await runDiagnosticChecks({
        ...options(),
        resume: {
          nextRunnerIndex: 0,
          providerOptions: {},
          diagnosticsChecks: [],
          updatedAt: Date.now(),
          checkCodes: [C.NFT],
        },
      }),
    ).toBe(false);
    expect(runtime.state.diagnosticsChecks.length).toBeGreaterThan(0);
    gate.resolve();
    await pending;
    expect(runtime.runners[2].run).not.toHaveBeenCalled();
  });

  it('runs only the selected check and preserves every unrelated result and timestamp', async () => {
    const other = structuredClone(
      runtime.state.diagnosticsChecks.filter((item) => item.code !== C.DNS),
    );
    await runDiagnosticChecks({ ...options(), code: C.DNS });
    expect(runtime.runners[0].run).toHaveBeenCalledOnce();
    expect(runtime.runners[1].run).not.toHaveBeenCalled();
    expect(runtime.runners[2].run).not.toHaveBeenCalled();
    expect(
      runtime.state.diagnosticsChecks.filter((item) => item.code !== C.DNS),
    ).toEqual(other);
    expect(check(C.DNS).checkedAt).toBeGreaterThan(1000);
    expect(check(C.DNS).state).toBe('success');
    expect(runtime.state.diagnosticsRunAction.loading).toBe(false);
  });

  it('uses the same ordered runners for a complete run', async () => {
    const order: C[] = [];
    runtime.runners.forEach((runner) => {
      runner.run = vi.fn(async () => {
        order.push(runner.code);
        setResult(runner.code);
      });
    });
    await runDiagnosticChecks(options());
    expect(order).toEqual([C.DNS, C.CONNECTIVITY, C.NFT]);
    expect(runtime.cleared).toHaveBeenCalledOnce();
    expect(runtime.saved[runtime.saved.length - 1]).toMatchObject({
      nextRunnerIndex: 3,
      checkCodes: order,
    });
  });

  it('holds one lock even while capability metadata is still loading', async () => {
    const gate = deferred();
    const config = { ...options(), refreshProviders: () => gate.promise };
    const first = runDiagnosticChecks({ ...config, code: C.DNS });
    expect(await runDiagnosticChecks({ ...options(), code: C.NFT })).toBe(
      false,
    );
    expect(await runDiagnosticChecks(options())).toBe(false);
    gate.resolve();
    await first;
    expect(runtime.runners[0].run).toHaveBeenCalledOnce();
    expect(runtime.runners[2].run).not.toHaveBeenCalled();
  });

  it('does not start probes when service actions disable diagnostics', async () => {
    expect(
      await runDiagnosticChecks({
        ...options(),
        canRun: () => false,
        code: C.DNS,
      }),
    ).toBe(false);
    runtime.runners.forEach((runner) =>
      expect(runner.run).not.toHaveBeenCalled(),
    );
    expect(runtime.state.diagnosticsRunAction.loading).toBe(false);
  });

  it('turns rejected RPCs into errors, releases the lock, and allows a retry', async () => {
    runtime.runners[0].run = vi.fn(async () => {
      throw new Error('RPC unavailable');
    });
    await runDiagnosticChecks({ ...options(), code: C.DNS });
    expect(check(C.DNS).state).toBe('error');
    expect(check(C.DNS).checkedAt).toBeGreaterThan(1000);
    expect(runtime.error).toHaveBeenCalled();
    runtime.runners[0].run = vi.fn(async () => setResult(C.DNS));
    expect(await runDiagnosticChecks({ ...options(), code: C.DNS })).toBe(true);
    expect(check(C.DNS).state).toBe('success');
  });

  it('preserves a specific failure description already returned by the check', async () => {
    runtime.runners[0].run = vi.fn(async () => {
      setResult(C.DNS, 'error', 'DNS RPC failed');
      throw new Error('RPC');
    });
    await runDiagnosticChecks({ ...options(), code: C.DNS });
    expect(check(C.DNS)).toMatchObject({
      state: 'error',
      description: 'DNS RPC failed',
    });
  });

  it('does not turn an unfinished result into a green success', async () => {
    runtime.runners[0].run = vi.fn(async () => {});
    await runDiagnosticChecks({ ...options(), code: C.DNS });
    expect(check(C.DNS).state).toBe('error');
  });

  it('cancels after the current request, ignores its late success and skips the rest', async () => {
    const gate = deferred();
    runtime.runners[0].run = vi.fn(async () => {
      await gate.promise;
      setResult(C.DNS);
    });
    const pending = runDiagnosticChecks(options());
    await vi.waitFor(() =>
      expect(runtime.runners[0].run).toHaveBeenCalledOnce(),
    );
    cancelDiagnosticRun();
    expect(runtime.state.diagnosticsRunAction).toMatchObject({
      loading: true,
      cancelling: true,
    });
    expect(await runDiagnosticChecks({ ...options(), code: C.NFT })).toBe(
      false,
    );
    expect(runtime.saved[runtime.saved.length - 1]).toMatchObject({
      cancelRequested: true,
    });
    gate.resolve();
    await pending;
    expect(check(C.DNS)).toMatchObject({
      state: 'skipped',
      description: 'Cancelled',
    });
    expect(check(C.CONNECTIVITY).state).toBe('skipped');
    expect(check(C.NFT).state).toBe('skipped');
    expect(runtime.runners[1].run).not.toHaveBeenCalled();
    expect(runtime.runners[2].run).not.toHaveBeenCalled();
    expect(runtime.state.diagnosticsRunAction.loading).toBe(false);
  });

  it('cancels during metadata refresh without launching a network check', async () => {
    const gate = deferred();
    const pending = runDiagnosticChecks({
      ...options(),
      refreshProviders: () => gate.promise,
      code: C.DNS,
    });
    cancelDiagnosticRun();
    gate.resolve();
    await pending;
    runtime.runners.forEach((runner) =>
      expect(runner.run).not.toHaveBeenCalled(),
    );
    expect(check(C.DNS).description).toBe('Cancelled');
  });

  it('restores a single-check queue without expanding it to all checks', async () => {
    const config = options();
    await runDiagnosticChecks({
      ...config,
      resume: {
        checkCodes: [C.NFT],
        nextRunnerIndex: 0,
        providerOptions: {},
        diagnosticsChecks: runtime.state.diagnosticsChecks,
        updatedAt: Date.now(),
      },
    });
    expect(config.refreshProviders).toHaveBeenCalledOnce();
    expect(runtime.runners[2].run).toHaveBeenCalledOnce();
    expect(runtime.runners[0].run).not.toHaveBeenCalled();
    expect(runtime.runners[1].run).not.toHaveBeenCalled();
  });

  it('resumes at the stored cursor without repeating completed checks', async () => {
    await runDiagnosticChecks({
      ...options(),
      resume: {
        checkCodes: [C.DNS, C.NFT],
        nextRunnerIndex: 1,
        providerOptions: {},
        diagnosticsChecks: runtime.state.diagnosticsChecks,
        updatedAt: Date.now(),
      },
    });
    expect(runtime.runners[0].run).not.toHaveBeenCalled();
    expect(runtime.runners[2].run).toHaveBeenCalledOnce();
    expect(check(C.DNS).checkedAt).toBe(1000);
  });

  it('does not resurrect a cancelled persisted run', async () => {
    await runDiagnosticChecks({
      ...options(),
      resume: {
        checkCodes: [C.DNS],
        nextRunnerIndex: 0,
        providerOptions: {},
        cancelRequested: true,
        diagnosticsChecks: runtime.state.diagnosticsChecks,
        updatedAt: Date.now(),
      },
    });
    runtime.runners.forEach((runner) =>
      expect(runner.run).not.toHaveBeenCalled(),
    );
    expect(check(C.DNS).state).toBe('skipped');
  });

  it('handles a provider disappearing before the selected check starts', async () => {
    await runDiagnosticChecks({ ...options(), code: C.ZAPRET });
    runtime.runners.forEach((runner) =>
      expect(runner.run).not.toHaveBeenCalled(),
    );
    expect(check(C.ZAPRET)).toMatchObject({
      state: 'skipped',
      description: 'Check is unavailable for the current configuration',
    });
  });

  it('refreshes visible cards without discarding completed results', () => {
    const old = runtime.state.diagnosticsChecks;
    const next = mergeDiagnosticsChecks(old, { includeZapret: true });
    expect(next.find((item) => item.code === C.DNS)).toEqual(check(C.DNS));
    expect(next.find((item) => item.code === C.ZAPRET)?.state).toBe('skipped');
    expect(mergeDiagnosticsChecks(next, {})).toEqual(old);
  });
});
