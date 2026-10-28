const NOTIFICATION_STACK_ID = 'lgh-notifications';

let observedMainContent: HTMLElement | null = null;
let notificationObserver: MutationObserver | null = null;

function getNotificationStack(): HTMLElement {
  let stack = document.getElementById(NOTIFICATION_STACK_ID);

  if (!stack) {
    stack = document.createElement('div');
    stack.id = NOTIFICATION_STACK_ID;
  }

  stack.classList.add('lgh-notification-stack');
  if (stack.parentElement !== document.body) {
    document.body.appendChild(stack);
  }

  return stack;
}

function moveNotification(
  node: Node,
  mainContent: HTMLElement,
  stack: HTMLElement,
) {
  if (
    node.nodeType === 1 &&
    node.parentNode === mainContent &&
    (node as Element).classList.contains('alert-message')
  ) {
    stack.appendChild(node);
  }
}

function disconnectNotifications() {
  notificationObserver?.disconnect();
  notificationObserver = null;
  observedMainContent = null;
  window.removeEventListener('pagehide', disconnectNotifications);
}

export function mountNotifications(): HTMLElement {
  const stack = getNotificationStack();
  const mainContent = document.getElementById('maincontent');

  if (mainContent !== observedMainContent) {
    disconnectNotifications();

    if (mainContent) {
      notificationObserver = new MutationObserver((records) => {
        const currentStack = getNotificationStack();
        for (const record of records) {
          for (const node of record.addedNodes) {
            moveNotification(node, mainContent, currentStack);
          }
        }
      });
      notificationObserver.observe(mainContent, { childList: true });
      observedMainContent = mainContent;
      window.addEventListener('pagehide', disconnectNotifications, {
        once: true,
      });
    }
  }

  if (mainContent) {
    for (const child of Array.from(mainContent.children)) {
      moveNotification(child, mainContent, stack);
    }
  }

  return stack;
}
