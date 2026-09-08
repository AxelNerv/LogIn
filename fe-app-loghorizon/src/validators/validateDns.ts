import { validateDomain } from './validateDomain';
import { isValidPort, parseHostPort, unbracketHost } from './hostPort';
import { validateIP } from './validateIp';
import { ValidationResult } from './types';

export function validateDNS(value: string): ValidationResult {
  if (!value) {
    return { valid: false, message: _('DNS server address cannot be empty') };
  }

  if (value.includes('://')) {
    try {
      const parsed = new URL(value);
      const protocols = [
        'dns:',
        'udp:',
        'tcp:',
        'tls:',
        'dot:',
        'https:',
        'doh:',
        'quic:',
        'doq:',
        'h3:',
        'doh3:',
      ];
      const host = parsed.hostname.startsWith('[')
        ? parsed.hostname.slice(1, -1)
        : parsed.hostname;
      const address = parsed.searchParams.get('address') || '';
      const serverName =
        parsed.searchParams.get('server_name') ||
        parsed.searchParams.get('sni') ||
        '';

      if (
        !protocols.includes(parsed.protocol) ||
        (!validateIP(host).valid && !validateDomain(host).valid) ||
        (parsed.port && !isValidPort(parsed.port))
      ) {
        throw new Error('invalid endpoint');
      }

      if (address && !validateIP(address).valid) {
        return {
          valid: false,
          message: _('DNS endpoint address must be an IPv4 or IPv6 literal'),
        };
      }

      if (
        serverName &&
        (!validateDomain(serverName).valid || validateIP(serverName).valid)
      ) {
        return {
          valid: false,
          message: _('DNS TLS server name must be a domain name'),
        };
      }

      return { valid: true, message: _('Valid') };
    } catch (_error) {
      return { valid: false, message: _('Invalid DNS endpoint URL') };
    }
  }

  const [addressPart, ...pathParts] = value.split('/');
  const parsedHostPort = parseHostPort(addressPart);
  const host = parsedHostPort
    ? parsedHostPort.host
    : unbracketHost(addressPart);
  const domainValue = parsedHostPort
    ? host + (pathParts.length > 0 ? `/${pathParts.join('/')}` : '')
    : value.replace(/:(\d+)(?=\/|$)/, '');

  if (parsedHostPort && !isValidPort(parsedHostPort.port)) {
    return { valid: false, message: _('Invalid DNS server port') };
  }

  if (validateIP(host).valid) {
    return { valid: true, message: _('Valid') };
  }

  if (validateDomain(domainValue).valid) {
    return { valid: true, message: _('Valid') };
  }

  return {
    valid: false,
    message: _(
      'Invalid DNS server format. Examples: 8.8.8.8 or dns.example.com or dns.example.com/nicedns for DoH',
    ),
  };
}
