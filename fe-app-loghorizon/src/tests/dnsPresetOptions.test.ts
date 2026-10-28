import { describe, expect, it } from 'vitest';

import { BOOTSTRAP_DNS_SERVER_OPTIONS, DNS_SERVER_OPTIONS } from '../constants';
import { validateDNS } from '../validators/validateDns';

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

  it('accepts every published preset with the same validator as the form', () => {
    for (const value of new Set([
      ...Object.keys(DNS_SERVER_OPTIONS),
      ...Object.keys(BOOTSTRAP_DNS_SERVER_OPTIONS),
    ])) {
      expect(validateDNS(value).valid, value).toBe(true);
    }
  });

  it('offers independent providers without forcing filtering or an account', () => {
    expect(DNS_SERVER_OPTIONS).toMatchObject({
      'https://dns10.quad9.net/dns-query?address=9.9.9.10':
        expect.stringContaining('unfiltered'),
      'https://unfiltered.adguard-dns.com/dns-query?address=94.140.14.140':
        expect.stringContaining('unfiltered'),
      'https://freedns.controld.com/p0?address=76.76.2.11':
        expect.stringContaining('unfiltered'),
      'https://doh.dns.sb/dns-query?address=185.222.222.222':
        expect.stringContaining('DNS.SB'),
    });
    for (const value of Object.keys(DNS_SERVER_OPTIONS).filter((item) =>
      item.includes('://'),
    )) {
      expect(BOOTSTRAP_DNS_SERVER_OPTIONS).toHaveProperty(value);
    }
  });
});
