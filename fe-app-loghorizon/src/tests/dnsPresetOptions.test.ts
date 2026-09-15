import { describe, expect, it } from 'vitest';

import { BOOTSTRAP_DNS_SERVER_OPTIONS, DNS_SERVER_OPTIONS } from '../constants';

describe('DNS preset options', () => {
  it('offers named encrypted resolver endpoints', () => {
    expect(DNS_SERVER_OPTIONS).toMatchObject({
      'dns.google': expect.stringContaining('Google'),
      'cloudflare-dns.com': expect.stringContaining('Cloudflare'),
      'one.one.one.one': expect.stringContaining('Cloudflare'),
      'dns.quad9.net': expect.stringContaining('Quad9'),
    });
  });

  it('offers protected bootstrap transports with pinned addresses', () => {
    expect(BOOTSTRAP_DNS_SERVER_OPTIONS).toMatchObject({
      'https://dns.adguard-dns.com/dns-query?address=94.140.14.14':
        expect.stringContaining('AdGuard'),
      'quic://dns.adguard-dns.com?address=94.140.14.14':
        expect.stringContaining('AdGuard'),
      'tls://one.one.one.one?address=1.1.1.1':
        expect.stringContaining('Cloudflare'),
      'tls://dns.google?address=8.8.8.8': expect.stringContaining('Google'),
    });

    Object.keys(BOOTSTRAP_DNS_SERVER_OPTIONS)
      .filter((value) => /^(https|tls|quic):/.test(value))
      .forEach((value) => expect(value).toContain('address='));
  });
});
