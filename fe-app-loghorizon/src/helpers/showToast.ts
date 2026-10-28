import { mountNotifications } from './mountNotifications';

export function showToast(
  message: string,
  type: 'success' | 'error',
  duration: number = 3000,
) {
  const container = mountNotifications();

  const toast = document.createElement('div');
  toast.className = `lgh-toast lgh-toast-${type}`;
  toast.setAttribute('role', type === 'error' ? 'alert' : 'status');
  toast.textContent = message;

  container.appendChild(toast);
  setTimeout(() => toast.classList.add('visible'), 100);

  setTimeout(() => {
    toast.classList.remove('visible');
    setTimeout(() => toast.remove(), 300);
  }, duration);
}
