import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:netbridge/profile/profile.dart';

NbVpnProfile _sampleProfile() {
  final clientKey = base64.encode(List<int>.generate(32, (i) => i + 1));
  final serverKey = base64.encode(List<int>.generate(32, (i) => 100 + i));
  return NbVpnProfile(
    v: 1,
    name: 't',
    client: ClientSection(
      privateKey: clientKey,
      address: const ['10.8.0.2/32'],
      dns: const ['1.1.1.1'],
    ),
    server: ServerSection(
      publicKey: serverKey,
      endpoint: '203.0.113.10:51820',
      allowedIPs: const ['0.0.0.0/0', '::/0'],
    ),
  );
}

void main() {
  group('SplitTunnel', () {
    test('isFullTunnelDefault detects 0.0.0.0/0 and ::/0', () {
      expect(
        SplitTunnel.isFullTunnelDefault(const ['0.0.0.0/0', '::/0']),
        isTrue,
      );
      expect(
        SplitTunnel.isFullTunnelDefault(const ['10.8.0.0/24']),
        isFalse,
      );
    });

    test('resolveAllowedIPs passthrough when excludePrivate is false', () {
      const input = ['0.0.0.0/0', '::/0', '10.8.0.0/24'];
      expect(
        SplitTunnel.resolveAllowedIPs(input, excludePrivate: false),
        input,
      );
    });

    test('resolveAllowedIPs expands full tunnel defaults', () {
      final got = SplitTunnel.resolveAllowedIPs(
        const ['0.0.0.0/0', '::/0'],
        excludePrivate: true,
      );
      expect(got, isNot(contains('0.0.0.0/0')));
      expect(got, isNot(contains('::/0')));
      expect(got, contains('192.169.0.0/16'));
      expect(got, contains('fec0::/10'));
      expect(got.length, SplitTunnel.ipv4ExcludePrivate.length +
          SplitTunnel.ipv6ExcludePrivate.length);
    });

    test('resolveAllowedIPs keeps custom CIDRs', () {
      final got = SplitTunnel.resolveAllowedIPs(
        const ['10.8.0.0/24', '203.0.113.0/24'],
        excludePrivate: true,
      );
      expect(got, ['10.8.0.0/24', '203.0.113.0/24']);
    });
  });

  group('ProfileCodec split tunnel conf', () {
    test('toWireGuardConf excludes private when requested', () {
      final p = _sampleProfile();
      final conf = ProfileCodec.toWireGuardConf(
        p,
        excludePrivateNetworks: true,
      );
      expect(conf, isNot(contains('0.0.0.0/0')));
      expect(conf, contains('192.169.0.0/16'));
      expect(conf, contains('fec0::/10'));
    });
  });
}
