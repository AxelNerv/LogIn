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

export const DNS_SERVER_OPTIONS = {
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
