import type { logIn } from '../../types';

export function shouldApplyCompletedComponentActionResult(
  result: Pick<logIn.ComponentActionResult, 'action'>,
  notify: boolean,
) {
  return result.action !== 'check_update' || notify;
}
