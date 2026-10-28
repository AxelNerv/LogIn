import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

// Keep real buttons/SVGs without importing the application through this barrel.
vi.mock('../../../../../helpers', async () => ({
  ...(await import('../../../../../helpers/insertIf')),
  ...(await import('../../../../../helpers/svgEl')),
}));

import { renderCheckSection } from '../renderCheckSection';
import { renderRunAction } from '../renderRunAction';

// Minimal DOM for Node tests. Keyboard behavior and layout are checked in Chromium.
class TestElement extends EventTarget {
  private attributes = new Map<string, string>();
  private content: Array<TestElement | string> = [];

  constructor(readonly tagName: string) {
    super();
  }

  get children(): TestElement[] {
    return this.content.filter((child) => child instanceof TestElement);
  }

  get textContent(): string {
    return this.content
      .map((child) => (typeof child === 'string' ? child : child.textContent))
      .join('');
  }

  get disabled() {
    return this.getAttribute('disabled') !== null;
  }

  setAttribute(name: string, value: string) {
    this.attributes.set(name.toLowerCase(), value);
  }

  getAttribute(name: string) {
    return this.attributes.get(name.toLowerCase()) ?? null;
  }

  appendChild(child: TestElement) {
    this.content.push(child);
    return child;
  }

  appendText(text: string) {
    this.content.push(text);
  }

  click() {
    if (this.tagName === 'button' && this.disabled) return;
    this.dispatchEvent(new Event('click'));
  }
}

function createElement(
  tag: string,
  attributes: Record<string, unknown> = {},
  children: TestElement | string | Array<TestElement | string> = [],
) {
  const element = new TestElement(tag);
  for (const [key, value] of Object.entries(attributes)) {
    if (key === 'click' && typeof value === 'function') {
      element.addEventListener('click', value as EventListener);
    } else if (value !== undefined && value !== null && value !== false) {
      element.setAttribute(key, String(value));
    }
  }
  for (const child of Array.isArray(children) ? children : [children]) {
    if (typeof child === 'string') element.appendText(child);
    else element.appendChild(child);
  }
  return element;
}

function tree(element: TestElement): TestElement[] {
  return [element, ...element.children.flatMap(tree)];
}

function byClass(element: TestElement, name: string) {
  return tree(element).filter((child) =>
    (child.getAttribute('class') ?? '').split(/\s+/).includes(name),
  );
}

function buttons(element: TestElement) {
  return tree(element).filter((child) => child.tagName === 'button');
}

function asTestElement(element: HTMLElement) {
  return element as unknown as TestElement;
}

function checkProps(
  overrides: Partial<Parameters<typeof renderCheckSection>[0]> = {},
): Parameters<typeof renderCheckSection>[0] {
  return {
    order: 1,
    code: 'dns',
    title: 'DNS',
    description: 'Resolver availability',
    state: 'success',
    items: [
      { state: 'success', key: 'Main resolver', value: 'Available' },
      { state: 'warning', key: 'Bootstrap', value: 'Previous warning' },
      { state: 'error', key: 'Router resolver', value: 'Previous failure' },
    ],
    ...overrides,
  };
}

beforeEach(() => {
  vi.stubGlobal('E', createElement);
  vi.stubGlobal('document', {
    createElementNS: (_namespace: string, tag: string) => new TestElement(tag),
  });
});

afterEach(() => vi.unstubAllGlobals());

describe('renderCheckSection', () => {
  it.each([
    ['loading', 'lucide-loader-circle'],
    ['warning', 'lucide-circle-alert'],
    ['error', 'lucide-circle-x'],
    ['success', 'lucide-circle-check'],
    ['skipped', 'lucide-circle-slash'],
  ] as const)(
    'preserves %s styling, icons, and every summary item',
    (state, iconClass) => {
      const onRun = vi.fn();
      const props = checkProps({ state, onRun });
      const originalItems = props.items.map((item) => ({ ...item }));
      const card = asTestElement(renderCheckSection(props));
      expect(byClass(card, `lgh_diagnostic_alert--${state}`)).toHaveLength(1);
      const [statusIcon] = byClass(card, 'lgh_diagnostic_alert__icon');
      expect(byClass(statusIcon, iconClass)).toHaveLength(1);
      expect(statusIcon.getAttribute('aria-hidden')).toBe('true');
      expect(card.textContent).toContain('DNS');
      expect(card.textContent).toContain('Resolver availability');
      expect(byClass(card, 'lgh_diagnostic_alert__summary__item')).toHaveLength(
        3,
      );
      for (const item of originalItems) {
        expect(card.textContent).toContain(item.key);
        expect(card.textContent).toContain(item.value);
        expect(
          byClass(card, `lgh_diagnostic_alert__summary__item--${item.state}`),
        ).toHaveLength(1);
      }
      expect(props.items).toEqual(originalItems);
      expect(onRun).not.toHaveBeenCalled();
    },
  );

  it('runs only the native Check button and keeps the card/summary passive', () => {
    const onRun = vi.fn();
    const card = asTestElement(renderCheckSection(checkProps({ onRun })));
    const [button] = buttons(card);
    expect(button.textContent).toBe('Check');
    expect(button.getAttribute('type')).toBe('button');
    expect(button.getAttribute('aria-label')).toBe('Check: DNS');
    expect(button.getAttribute('aria-busy')).toBe('false');
    expect(card.getAttribute('role')).not.toBe('button');
    expect(card.getAttribute('tabindex')).toBeNull();
    card.click();
    byClass(card, 'lgh_diagnostic_alert__summary')[0].click();
    expect(onRun).not.toHaveBeenCalled();
    button.click();
    expect(onRun).toHaveBeenCalledOnce();
  });

  it.each(['disabled', 'loading', 'missing callback'] as const)(
    'does not run when %s',
    (reason) => {
      const onRun = vi.fn();
      const card = asTestElement(
        renderCheckSection(
          checkProps({
            onRun: reason === 'missing callback' ? undefined : onRun,
            disabled: reason === 'disabled',
            state: reason === 'loading' ? 'loading' : 'success',
          }),
        ),
      );
      const [button] = buttons(card);
      expect(button.disabled).toBe(true);
      button.click();
      expect(onRun).not.toHaveBeenCalled();
      expect(button.getAttribute('aria-busy')).toBe(
        String(reason === 'loading'),
      );
      expect(byClass(button, 'lucide-loader-circle')).toHaveLength(
        reason === 'loading' ? 1 : 0,
      );
      if (reason !== 'missing callback') {
        button.dispatchEvent(new Event('click'));
        expect(onRun).not.toHaveBeenCalled();
      }
    },
  );

  it('blocks other cards externally without hiding their summaries', () => {
    const onRun = vi.fn();
    for (const state of ['success', 'warning', 'error', 'skipped'] as const) {
      const card = asTestElement(
        renderCheckSection(checkProps({ state, onRun, disabled: true })),
      );
      expect(buttons(card)[0].disabled).toBe(true);
      buttons(card)[0].click();
      expect(card.textContent).toContain('Previous failure');
    }
    expect(onRun).not.toHaveBeenCalled();
  });

  it.each(['success', 'loading'] as const)(
    'keeps the last completion timestamp during %s',
    (state) => {
      const checkedAt = Date.UTC(2026, 9, 28, 12, 34, 56);
      const card = asTestElement(
        renderCheckSection(checkProps({ state, checkedAt })),
      );
      const timestamps = tree(card).filter(
        (element) => element.tagName === 'time',
      );
      expect(timestamps).toHaveLength(1);
      expect(card.textContent).toContain('Last checked');
      expect(timestamps[0].getAttribute('datetime')).toBe(
        new Date(checkedAt).toISOString(),
      );
      expect(timestamps[0].textContent).toBe(
        new Date(checkedAt).toLocaleString(),
      );
      expect(card.textContent).toContain('Previous failure');
    },
  );

  it.each([undefined, NaN, Infinity, -Infinity, 8.64e15 + 1])(
    'omits invalid/missing checkedAt (%s)',
    (checkedAt) => {
      const card = asTestElement(renderCheckSection(checkProps({ checkedAt })));
      expect(
        tree(card).filter((element) => element.tagName === 'time'),
      ).toHaveLength(0);
      expect(card.textContent).not.toContain('Last checked');
      expect(card.textContent).not.toContain('Invalid Date');
    },
  );

  it('accepts the valid Unix epoch and omits an empty summary', () => {
    const card = asTestElement(
      renderCheckSection(checkProps({ checkedAt: 0, items: [] })),
    );
    const timestamp = tree(card).find((element) => element.tagName === 'time');
    expect(timestamp?.getAttribute('datetime')).toBe(
      '1970-01-01T00:00:00.000Z',
    );
    expect(byClass(card, 'lgh_diagnostic_alert__summary')).toHaveLength(0);
    expect(buttons(card)).toHaveLength(1);
  });
});

describe('renderRunAction', () => {
  it('preserves the native run-all click and hides Cancel when idle', () => {
    const click = vi.fn();
    const cancel = vi.fn();
    const toolbar = asTestElement(
      renderRunAction({ loading: false, click, cancel }),
    );
    const [button] = buttons(toolbar);
    expect(buttons(toolbar)).toHaveLength(1);
    expect(button.textContent).toBe('Run all checks');
    expect(button.getAttribute('aria-label')).toBe('Run all checks');
    expect(button.getAttribute('type')).toBe('button');
    expect(button.disabled).toBe(false);
    expect(byClass(button, 'lucide-loader-circle')).toHaveLength(0);
    expect(click).not.toHaveBeenCalled();
    expect(cancel).not.toHaveBeenCalled();
    expect(byClass(toolbar, 'lgh_diagnostic-page__cancel-hint')).toHaveLength(
      0,
    );
    button.click();
    expect(click).toHaveBeenCalledOnce();
  });

  it('honors external disabled without displaying a full-run spinner', () => {
    const click = vi.fn();
    const toolbar = asTestElement(
      renderRunAction({ loading: false, disabled: true, click }),
    );
    const [button] = buttons(toolbar);
    expect(button.disabled).toBe(true);
    expect(button.getAttribute('aria-busy')).toBe('false');
    expect(byClass(button, 'lucide-loader-circle')).toHaveLength(0);
    button.click();
    expect(click).not.toHaveBeenCalled();
  });

  it('keeps Cancel available during a globally disabled, loading full run', () => {
    const click = vi.fn();
    const cancel = vi.fn();
    const toolbar = asTestElement(
      renderRunAction({
        loading: true,
        disabled: true,
        running: true,
        click,
        cancel,
      }),
    );
    const [runButton, cancelButton] = buttons(toolbar);
    expect(runButton.disabled).toBe(true);
    expect(runButton.getAttribute('aria-busy')).toBe('true');
    expect(byClass(runButton, 'lucide-loader-circle')).toHaveLength(1);
    expect(cancelButton.textContent).toBe('Cancel');
    expect(cancelButton.getAttribute('type')).toBe('button');
    expect(cancelButton.getAttribute('aria-label')).toBe('Cancel');
    expect(cancelButton.disabled).toBe(false);
    runButton.click();
    cancelButton.click();
    expect(click).not.toHaveBeenCalled();
    expect(cancel).toHaveBeenCalledOnce();
  });

  it('shows disabled Cancelling and keeps loading under caller control', () => {
    const click = vi.fn();
    const cancel = vi.fn();
    const toolbar = asTestElement(
      renderRunAction({
        loading: false,
        running: true,
        cancelling: true,
        click,
        cancel,
      }),
    );
    const [runButton, cancelButton] = buttons(toolbar);
    expect(runButton.disabled).toBe(true);
    expect(byClass(runButton, 'lucide-loader-circle')).toHaveLength(0);
    expect(cancelButton.textContent).toBe('Cancelling');
    expect(cancelButton.getAttribute('aria-label')).toBe('Cancelling');
    expect(cancelButton.getAttribute('aria-busy')).toBe('true');
    expect(cancelButton.disabled).toBe(true);
    const [hint] = byClass(toolbar, 'lgh_diagnostic-page__cancel-hint');
    expect(hint.textContent).toBe(
      'The current request will finish before the remaining checks are cancelled.',
    );
    expect(hint.getAttribute('role')).toBe('status');
    expect(hint.getAttribute('aria-live')).toBe('polite');
    cancelButton.click();
    cancelButton.dispatchEvent(new Event('click'));
    expect(cancel).not.toHaveBeenCalled();
  });

  it('disables Cancel if its optional callback is missing', () => {
    const toolbar = asTestElement(
      renderRunAction({ loading: false, running: true, click: vi.fn() }),
    );
    expect(buttons(toolbar)[1].textContent).toBe('Cancel');
    expect(buttons(toolbar)[1].disabled).toBe(true);
  });
});
