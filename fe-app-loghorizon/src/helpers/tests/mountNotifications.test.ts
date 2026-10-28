import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { mountNotifications } from '../mountNotifications';
import { showToast } from '../showToast';

// The project runs tests in Node without a DOM dependency. Keep node identity
// and real EventTarget listeners while modelling only the tree operations used.
class TestElement extends EventTarget {
  readonly nodeType = 1;
  id = '';
  className = '';
  textContent = '';
  parentNode: TestElement | null = null;
  children: TestElement[] = [];
  private attributes = new Map<string, string>();

  readonly classList = {
    contains: (name: string) => this.className.split(/\s+/).includes(name),
    add: (name: string) => {
      this.className = [...new Set([...this.className.split(/\s+/), name])]
        .filter(Boolean)
        .join(' ');
    },
    remove: (name: string) => {
      this.className = this.className
        .split(/\s+/)
        .filter((value) => value !== name)
        .join(' ');
    },
  };

  get parentElement() {
    return this.parentNode;
  }

  appendChild(child: TestElement) {
    child.remove();
    this.children.push(child);
    child.parentNode = this;
    return child;
  }

  prepend(child: TestElement) {
    this.appendChild(child);
    this.children.unshift(this.children.pop()!);
  }

  remove() {
    if (this.parentNode) {
      this.parentNode.children = this.parentNode.children.filter(
        (child) => child !== this,
      );
      this.parentNode = null;
    }
  }

  setAttribute(name: string, value: string) {
    this.attributes.set(name, value);
  }

  getAttribute(name: string) {
    return this.attributes.get(name) ?? null;
  }
}

class TestObserver {
  readonly observe = vi.fn();
  readonly disconnect = vi.fn();

  constructor(private callback: MutationCallback) {
    observers.push(this);
  }

  deliver(addedNodes: TestElement[]) {
    this.callback(
      [{ addedNodes } as unknown as MutationRecord],
      this as unknown as MutationObserver,
    );
  }
}

let body: TestElement;
let mainContent: TestElement;
let page: EventTarget;
let observers: TestObserver[];

function appendElement(parent: TestElement, className = '') {
  const node = new TestElement();
  node.className = className;
  return parent.appendChild(node);
}

beforeEach(() => {
  body = new TestElement();
  mainContent = appendElement(body);
  mainContent.id = 'maincontent';
  page = new EventTarget();
  observers = [];
  vi.stubGlobal('window', page);
  vi.stubGlobal('document', {
    body,
    getElementById: vi.fn(
      (id: string) => body.children.find((child) => child.id === id) ?? null,
    ),
    createElement: vi.fn(() => new TestElement()),
    querySelector: vi.fn(() => {
      throw new Error('Notification mounting must not scan the document');
    }),
    querySelectorAll: vi.fn(() => {
      throw new Error('Notification mounting must not scan the document');
    }),
  });
  vi.stubGlobal('MutationObserver', TestObserver);
});

afterEach(() => {
  page.dispatchEvent(new Event('pagehide'));
  vi.useRealTimers();
  vi.unstubAllGlobals();
});

describe('notification mounting', () => {
  it('moves only direct LuCI alerts intact and mounts one observer until pagehide', () => {
    const existing = appendElement(mainContent, 'alert-message warning');
    existing.textContent = 'Existing notification';
    const onClick = vi.fn();
    existing.addEventListener('click', onClick);
    const close = appendElement(existing, 'close');
    close.addEventListener('click', () => existing.remove());
    const wrapper = appendElement(mainContent);
    const nested = appendElement(wrapper, 'alert-message');
    const outside = appendElement(body, 'alert-message');

    const stack = mountNotifications() as unknown as TestElement;
    expect(stack.id).toBe('lgh-notifications');
    expect(stack.classList.contains('lgh-notification-stack')).toBe(true);
    expect(stack.parentNode).toBe(body);
    expect(stack.children).toEqual([existing]);
    expect(existing.textContent).toBe('Existing notification');
    expect(existing.children).toEqual([close]);
    expect(observers).toHaveLength(1);
    expect(observers[0].observe).toHaveBeenCalledExactlyOnceWith(mainContent, {
      childList: true,
    });

    const newest = new TestElement();
    newest.className = 'alert-message error';
    mainContent.prepend(newest);
    const unrelated = appendElement(mainContent, 'cbi-value');
    observers[0].deliver([newest, wrapper, nested, outside, unrelated]);
    // Moving an alert itself produces a childList removal with no added nodes.
    observers[0].deliver([]);

    expect(stack.children).toEqual([existing, newest]);
    expect(nested.parentNode).toBe(wrapper);
    expect(outside.parentNode).toBe(body);
    expect(unrelated.parentNode).toBe(mainContent);
    expect(mountNotifications()).toBe(stack);
    expect(mountNotifications()).toBe(stack);
    expect(observers).toHaveLength(1);
    expect(document.createElement).toHaveBeenCalledExactlyOnceWith('div');

    existing.dispatchEvent(new Event('click'));
    expect(onClick).toHaveBeenCalledOnce();
    close.dispatchEvent(new Event('click'));
    expect(stack.children).toEqual([newest]);

    page.dispatchEvent(new Event('pagehide'));
    expect(observers[0].disconnect).toHaveBeenCalledOnce();
    expect(mountNotifications()).toBe(stack);
    expect(observers).toHaveLength(2);
    expect(body.children.filter((child) => child.id === stack.id)).toHaveLength(1);
  });

  it('shares the unique stack with accessible toasts and preserves their timers', () => {
    vi.useFakeTimers();
    const genericContainer = appendElement(body, 'toast-container');

    showToast('Copied', 'success', 1500);
    showToast('Failed to copy!', 'error');
    const stack = mountNotifications() as unknown as TestElement;
    const [success, error] = stack.children;

    expect(genericContainer.children).toEqual([]);
    expect(success.className).toBe('lgh-toast lgh-toast-success');
    expect(error.className).toBe('lgh-toast lgh-toast-error');
    expect(success.getAttribute('role')).toBe('status');
    expect(error.getAttribute('role')).toBe('alert');
    expect(success.textContent).toBe('Copied');
    expect(error.textContent).toBe('Failed to copy!');
    expect(observers).toHaveLength(1);

    vi.advanceTimersByTime(100);
    expect(success.classList.contains('visible')).toBe(true);
    expect(error.classList.contains('visible')).toBe(true);
    vi.advanceTimersByTime(1400);
    expect(success.classList.contains('visible')).toBe(false);
    expect(success.parentNode).toBe(stack);
    vi.advanceTimersByTime(300);
    expect(success.parentNode).toBeNull();
    expect(error.classList.contains('visible')).toBe(true);
    vi.advanceTimersByTime(1200);
    expect(error.classList.contains('visible')).toBe(false);
    expect(error.parentNode).toBe(stack);
    vi.advanceTimersByTime(300);
    expect(error.parentNode).toBeNull();
    expect(stack.children).toEqual([]);
    expect(stack.parentNode).toBe(body);
  });
});
