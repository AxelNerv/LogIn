/**
 * The single source of truth for product identity.
 *
 * Identity only: name, wordmark parts, internal namespace and edition. User
 * facing prose does not belong here — extract-calls.js sees string literals
 * inside `_()` and nothing else, so prose kept in a constant would never
 * reach the .pot and would stay untranslated.
 */
export const LOGIN_BRAND = Object.freeze({
  displayName: 'logIn',
  wordmark: Object.freeze({ prefix: 'log', accent: 'In' }),
  internalName: 'loghorizon',
  edition: 'Foundation',
});
