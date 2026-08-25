import 'package:flutter_test/flutter_test.dart';
import 'package:netbridge/profile/cidr_util.dart';
import 'package:netbridge/profile/split_tunnel.dart';

void main() {
  group('Ip4Cidr', () {
    test('parse host and cidr', () {
      expect(Ip4Cidr.tryParse('10.0.0.1')?.toString(), '10.0.0.1/32');
      expect(Ip4Cidr.tryParse('192.168.1.0/24')?.toString(), '192.168.1.0/24');
      expect(Ip4Cidr.tryParse('999.0.0.1'), isNull);
      expect(Ip4Cidr.tryParse('10.0.0.0/33'), isNull);
    });

    test('subtract carves a /24 from 0.0.0.0/0', () {
      final base = Ip4Cidr.tryParse('0.0.0.0/0')!;
      final cut = Ip4Cidr.tryParse('203.0.113.0/24')!;
      final parts = base.subtract(cut);
      expect(parts, isNotEmpty);
      expect(parts.any((p) => p.containsCidr(cut)), isFalse);
      // Spot-check: address inside cut must not be covered.
      final inside = Ip4Cidr.tryParse('203.0.113.50/32')!;
      expect(parts.any((p) => p.containsCidr(inside)), isFalse);
      // Outside still covered.
      final outside = Ip4Cidr.tryParse('1.1.1.1/32')!;
      expect(parts.any((p) => p.containsCidr(outside)), isTrue);
    });
  });

  group('applyIpv4BypassCidrs', () {
    test('removes bypass from full tunnel', () {
      final got = applyIpv4BypassCidrs(
        const ['0.0.0.0/0', '::/0'],
        const ['10.0.0.0/8'],
      );
      expect(got, isNot(contains('0.0.0.0/0')));
      expect(got, contains('::/0'));
      expect(
        got.any((c) {
          final p = Ip4Cidr.tryParse(c);
          return p != null && p.containsCidr(Ip4Cidr.tryParse('10.1.2.3/32')!);
        }),
        isFalse,
      );
    });
  });

  group('SplitTunnel bypass + forceFullTunnel', () {
    test('forceFullTunnel ignores excludePrivate', () {
      final got = SplitTunnel.resolveAllowedIPs(
        const ['0.0.0.0/0', '::/0'],
        excludePrivate: true,
        forceFullTunnel: true,
      );
      expect(got, ['0.0.0.0/0', '::/0']);
    });

    test('bypass applies after exclude-private expansion', () {
      final got = SplitTunnel.resolveAllowedIPs(
        const ['0.0.0.0/0'],
        excludePrivate: true,
        bypassCidrs: const ['8.8.8.8/32'],
      );
      expect(got, isNot(contains('0.0.0.0/0')));
      expect(
        got.any((c) {
          final p = Ip4Cidr.tryParse(c);
          return p != null && p.containsCidr(Ip4Cidr.tryParse('8.8.8.8/32')!);
        }),
        isFalse,
      );
    });
  });

  group('looksLike*', () {
    test('cidr vs domain', () {
      expect(looksLikeIpv4Cidr('1.2.3.4/24'), isTrue);
      expect(looksLikeDomain('example.com'), isTrue);
      expect(looksLikeDomain('1.2.3.4'), isFalse);
      expect(looksLikeIpv4Cidr('example.com'), isFalse);
    });
  });
}
