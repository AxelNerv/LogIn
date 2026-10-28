export const LOGHORIZON_UCI_PACKAGE = 'loghorizon';
export const LOGHORIZON_LUCI_APP_VERSION = '__COMPILED_VERSION_VARIABLE__';
export const LOGHORIZON_ACTION_PROVIDERS_AVAILABILITY_EVENT =
  'loghorizon:action-providers-availability';
export const FAKEIP_CHECK_DOMAIN = 'fakeip.podkop.fyi';
export const IP_CHECK_DOMAIN = 'ip.podkop.fyi';
export const DEFAULT_LATENCY_TEST_URL = 'https://www.gstatic.com/generate_204';
export const LATENCY_TEST_URL_OPTIONS = [
  DEFAULT_LATENCY_TEST_URL,
  'https://cp.cloudflare.com/generate_204',
  'https://captive.apple.com',
  'https://connectivity-check.ubuntu.com',
];

export const DOMAIN_LIST_OPTIONS = {
  russia_inside: 'Russia inside',
  russia_outside: 'Russia outside',
  ukraine_inside: 'Ukraine',
  geoblock: 'Geo Block',
  block: 'Block',
  porn: 'Porn',
  news: 'News',
  anime: 'Anime',
  youtube: 'Youtube',
  discord: 'Discord',
  meta: 'Meta',
  twitter: 'Twitter (X)',
  hdrezka: 'HDRezka',
  tiktok: 'Tik-Tok',
  telegram: 'Telegram',
  cloudflare: 'Cloudflare',
  google_ai: 'Google AI',
  google_play: 'Google Play',
  hodca: 'H.O.D.C.A',
  roblox: 'Roblox',
  ads_hagezi_pro: 'Ads (Hagezi Pro)',
  supercell: 'Supercell',
  github: 'GitHub',
  hetzner: 'Hetzner ASN',
  ovh: 'OVH ASN',
  digitalocean: 'Digital Ocean ASN',
  cloudfront: 'CloudFront ASN',
};

// Explicit transports and pinned addresses also work as bootstrap resolvers:
// resolving the resolver itself must not depend on an already-working DNS.
const PROTECTED_PUBLIC_DNS_OPTIONS = {
  'https://dns.google/dns-query?address=8.8.8.8': 'Google DoH (8.8.8.8)',
  'https://dns.google/dns-query?address=8.8.4.4': 'Google DoH (8.8.4.4)',
  'https://cloudflare-dns.com/dns-query?address=1.1.1.1':
    'Cloudflare DoH (1.1.1.1)',
  'https://cloudflare-dns.com/dns-query?address=1.0.0.1':
    'Cloudflare DoH (1.0.0.1)',
  'https://dns.quad9.net/dns-query?address=9.9.9.9':
    'Quad9 DoH (malware protection)',
  'https://dns10.quad9.net/dns-query?address=9.9.9.10':
    'Quad9 DoH (unfiltered)',
  'https://unfiltered.adguard-dns.com/dns-query?address=94.140.14.140':
    'AdGuard DoH (unfiltered)',
  'https://dns.adguard-dns.com/dns-query?address=94.140.14.14':
    'AdGuard DoH (ad blocking)',
  'https://family.adguard-dns.com/dns-query?address=94.140.14.15':
    'AdGuard DoH (family protection)',
  'https://doh.dns.sb/dns-query?address=185.222.222.222': 'DNS.SB DoH',
  'https://freedns.controld.com/p0?address=76.76.2.11':
    'Control D DoH (unfiltered)',
  'https://unfiltered.joindns4.eu/dns-query?address=86.54.11.100':
    'DNS4EU DoH (unfiltered)',
  'https://common.dot.dns.yandex.net/dns-query?address=77.88.8.8':
    'Yandex DoH (basic)',
  'https://odvr.nic.cz/doh?address=193.17.47.1': 'CZ.NIC DoH',
  'https://dns.alidns.com/dns-query?address=223.5.5.5': 'AliDNS DoH',
  'tls://dns10.quad9.net?address=9.9.9.10': 'Quad9 DoT (unfiltered)',
  'tls://unfiltered.adguard-dns.com?address=94.140.14.140':
    'AdGuard DoT (unfiltered)',
  'tls://dns.sb?address=185.222.222.222': 'DNS.SB DoT',
  'tls://p0.freedns.controld.com?address=76.76.2.11':
    'Control D DoT (unfiltered)',
  'tls://unfiltered.joindns4.eu?address=86.54.11.100':
    'DNS4EU DoT (unfiltered)',
  'tls://common.dot.dns.yandex.net?address=77.88.8.8': 'Yandex DoT (basic)',
  'tls://odvr.nic.cz?address=193.17.47.1': 'CZ.NIC DoT',
  'quic://unfiltered.adguard-dns.com?address=94.140.14.140':
    'AdGuard DoQ (unfiltered)',
  'quic://p0.freedns.controld.com?address=76.76.2.11':
    'Control D DoQ (unfiltered)',
  'quic://dns.alidns.com?address=223.5.5.5': 'AliDNS DoQ',
  'h3://cloudflare-dns.com/dns-query?address=1.1.1.1': 'Cloudflare DoH3',
  'h3://unfiltered.adguard-dns.com/dns-query?address=94.140.14.140':
    'AdGuard DoH3 (unfiltered)',
};

export const DNS_SERVER_OPTIONS = {
  ...PROTECTED_PUBLIC_DNS_OPTIONS,
  '77.88.8.8': '77.88.8.8 (Yandex)',
  '77.88.8.1': '77.88.8.1 (Yandex)',
  'dns.google': 'dns.google (Google, DoH/DoT)',
  'cloudflare-dns.com': 'cloudflare-dns.com (Cloudflare, DoH)',
  'one.one.one.one': 'one.one.one.one (Cloudflare, DoT)',
  'dns.quad9.net': 'dns.quad9.net (Quad9, DoH/DoT)',
  'dns.adguard-dns.com': 'dns.adguard-dns.com (AdGuard Default)',
  'unfiltered.adguard-dns.com':
    'unfiltered.adguard-dns.com (AdGuard Unfiltered)',
  'family.adguard-dns.com': 'family.adguard-dns.com (AdGuard Family)',
  '94.140.14.14': '94.140.14.14 (AdGuard, by IP)',
  '9.9.9.9': '9.9.9.9 (Quad9)',
  '1.1.1.1': '1.1.1.1 (Cloudflare)',
  '8.8.8.8': '8.8.8.8 (Google)',
};
export const BOOTSTRAP_DNS_SERVER_OPTIONS = {
  ...PROTECTED_PUBLIC_DNS_OPTIONS,
  'https://cloudflare-dns.com/dns-query?address=1.1.1.1':
    'Protected DoH (Cloudflare, pinned IP)',
  'https://dns.google/dns-query?address=8.8.8.8':
    'Protected DoH (Google, pinned IP)',
  'tls://dns.quad9.net?address=9.9.9.9': 'Protected DoT (Quad9, pinned IP)',
  'https://dns.adguard-dns.com/dns-query?address=94.140.14.14':
    'Protected DoH (AdGuard, pinned IP)',
  'quic://dns.adguard-dns.com?address=94.140.14.14':
    'Protected DoQ (AdGuard, pinned IP)',
  'tls://one.one.one.one?address=1.1.1.1':
    'Protected DoT (Cloudflare, pinned IP)',
  'tls://dns.google?address=8.8.8.8': 'Protected DoT (Google, pinned IP)',
  '77.88.8.8': '77.88.8.8 (Yandex DNS)',
  '77.88.8.1': '77.88.8.1 (Yandex DNS)',
  '1.1.1.1': '1.1.1.1 (Cloudflare DNS)',
  '1.0.0.1': '1.0.0.1 (Cloudflare DNS)',
  '8.8.8.8': '8.8.8.8 (Google DNS)',
  '8.8.4.4': '8.8.4.4 (Google DNS)',
  '9.9.9.9': '9.9.9.9 (Quad9 DNS)',
  '9.9.9.11': '9.9.9.11 (Quad9 DNS)',
};

export const COMMAND_TIMEOUT = 10000; // 10 seconds
