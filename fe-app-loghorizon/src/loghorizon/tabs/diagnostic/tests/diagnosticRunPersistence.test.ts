import { describe, expect, it, vi } from 'vitest';
import { DIAGNOSTICS_CHECKS as C } from '../checks/contstants';

import {
  clearPersistedDiagnosticRun,
  readPersistedDiagnosticRun,
  savePersistedDiagnosticRun,
} from '../diagnosticRunPersistence';

class MemoryStorage implements Storage {
  private values = new Map<string, string>();

  get length() {
    return this.values.size;
  }

  clear() {
    this.values.clear();
  }

  getItem(key: string) {
    return this.values.get(key) ?? null;
  }

  key(index: number) {
    return Array.from(this.values.keys())[index] ?? null;
  }

  removeItem(key: string) {
    this.values.delete(key);
  }

  setItem(key: string, value: string) {
    this.values.set(key, value);
  }
}

describe('diagnostic run persistence', () => {
  it('restores the exact selected queue, cancellation and completed timestamps', () => {
    const storage = new MemoryStorage();
    savePersistedDiagnosticRun(
      {
        nextRunnerIndex: 0,
        providerOptions: {},
        checkCodes: [C.NFT],
        cancelRequested: true,
        diagnosticsChecks: [
          {
            order: 1,
            code: C.DNS,
            title: 'DNS',
            description: 'done',
            state: 'success',
            checkedAt: 1000,
            items: [],
          },
        ],
      },
      storage,
    );
    expect(readPersistedDiagnosticRun(storage)).toMatchObject({
      checkCodes: [C.NFT],
      cancelRequested: true,
      diagnosticsChecks: [{ code: C.DNS, checkedAt: 1000 }],
    });
  });

  it.each([
    { checkCodes: [] },
    { checkCodes: [C.DNS, C.DNS] },
    { checkCodes: ['UNKNOWN'] },
    { checkCodes: [C.DNS], nextRunnerIndex: 2 },
    { cancelRequested: 'yes' },
    { nextRunnerIndex: 999 },
    {
      diagnosticsChecks: [
        {
          order: 1,
          code: C.DNS,
          title: 'DNS',
          description: 'done',
          state: 'success',
          checkedAt: -1,
          items: [],
        },
      ],
    },
  ])('rejects malformed queues and timestamps: %j', (invalid) => {
    const storage = new MemoryStorage();
    storage.setItem(
      'loghorizon:diagnostic-run:v1',
      JSON.stringify({
        nextRunnerIndex: 0,
        providerOptions: {},
        diagnosticsChecks: [],
        updatedAt: Date.now(),
        ...invalid,
      }),
    );
    expect(readPersistedDiagnosticRun(storage)).toBeNull();
    expect(storage.length).toBe(0);
  });

  it('stores and restores a running diagnostic snapshot', () => {
    const storage = new MemoryStorage();

    savePersistedDiagnosticRun(
      {
        nextRunnerIndex: 2,
        providerOptions: { includeZapret: true },
        diagnosticsChecks: [
          {
            order: 1,
            code: 'DNS',
            title: 'DNS',
            description: 'Checks passed',
            state: 'success',
            items: [],
          },
        ],
      },
      storage,
    );

    expect(readPersistedDiagnosticRun(storage)).toMatchObject({
      nextRunnerIndex: 2,
      providerOptions: { includeZapret: true },
      diagnosticsChecks: [
        {
          code: 'DNS',
          state: 'success',
        },
      ],
    });
  });

  it('removes expired snapshots', () => {
    const storage = new MemoryStorage();

    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-06-07T00:00:00Z'));
    savePersistedDiagnosticRun(
      {
        nextRunnerIndex: 0,
        providerOptions: {},
        diagnosticsChecks: [],
      },
      storage,
    );

    vi.setSystemTime(new Date('2026-06-07T00:31:00Z'));

    expect(readPersistedDiagnosticRun(storage)).toBeNull();
    expect(storage.length).toBe(0);
    vi.useRealTimers();
  });

  it('removes invalid snapshots', () => {
    const storage = new MemoryStorage();
    storage.setItem('loghorizon:diagnostic-run:v1', '{broken');

    expect(readPersistedDiagnosticRun(storage)).toBeNull();
    expect(storage.length).toBe(0);
  });

  it('clears persisted snapshots', () => {
    const storage = new MemoryStorage();

    savePersistedDiagnosticRun(
      {
        nextRunnerIndex: 0,
        providerOptions: {},
        diagnosticsChecks: [],
      },
      storage,
    );

    clearPersistedDiagnosticRun(storage);

    expect(readPersistedDiagnosticRun(storage)).toBeNull();
  });

  it('removes snapshots with unsupported check shape', () => {
    const storage = new MemoryStorage();

    storage.setItem(
      'loghorizon:diagnostic-run:v1',
      JSON.stringify({
        nextRunnerIndex: 0,
        providerOptions: {},
        diagnosticsChecks: [
          {
            order: 1,
            code: 'UNKNOWN',
            title: 'Unknown',
            description: 'Checking',
            state: 'loading',
            items: [],
          },
        ],
        updatedAt: Date.now(),
      }),
    );

    expect(readPersistedDiagnosticRun(storage)).toBeNull();
    expect(storage.length).toBe(0);
  });

  it('removes snapshots with invalid numeric fields', () => {
    const storage = new MemoryStorage();

    storage.setItem(
      'loghorizon:diagnostic-run:v1',
      JSON.stringify({
        nextRunnerIndex: 0,
        providerOptions: {},
        diagnosticsChecks: [
          {
            order: Number.NaN,
            code: 'DNS',
            title: 'DNS',
            description: 'Checking',
            state: 'loading',
            items: [],
          },
        ],
        updatedAt: Date.now(),
      }),
    );

    expect(readPersistedDiagnosticRun(storage)).toBeNull();
    expect(storage.length).toBe(0);
  });
});
