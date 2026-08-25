import 'package:flutter_test/flutter_test.dart';
import 'package:netbridge/profile/nbvpn_profile.dart';
import 'package:netbridge/services/vpn/vpn_connectivity_verifier.dart';

void main() {
  group('routesPublicInternet', () {
    test('full tunnel default', () {
      expect(
        VpnConnectivityVerifier.routesPublicInternet(const ['0.0.0.0/0']),
        isTrue,
      );
    });

    test('exclude-private split still routes public', () {
      final allowed = VpnConnectivityVerifier.effectiveAllowedIPs(
        const ['0.0.0.0/0', '::/0'],
        excludePrivateNetworks: true,
      );
      expect(VpnConnectivityVerifier.routesPublicInternet(allowed), isTrue);
    });

    test('vpn-subnet-only does not route public', () {
      expect(
        VpnConnectivityVerifier.routesPublicInternet(const ['10.8.0.0/24']),
        isFalse,
      );
    });
  });

  group('verify', () {
    test('succeeds when injected http probe passes', () async {
      final verifier = VpnConnectivityVerifier.testing(succeed: true);
      final result = await verifier.verify(
        allowedIPs: const ['0.0.0.0/0'],
        endpoint: '1.2.3.4:51820',
        isCancelled: () => false,
      );
      expect(result, VpnVerificationResult.success);
    });

    test('fails when http probe never passes', () async {
      final verifier = VpnConnectivityVerifier.testing(
        succeed: false,
        timeout: const Duration(milliseconds: 40),
        interval: const Duration(milliseconds: 10),
      );
      final result = await verifier.verify(
        allowedIPs: const ['0.0.0.0/0'],
        endpoint: '1.2.3.4:51820',
        isCancelled: () => false,
      );
      expect(result, VpnVerificationResult.failed);
    });

    test('cancelled when isCancelled flips', () async {
      var cancelled = false;
      final verifier = VpnConnectivityVerifier.testing(
        succeed: false,
        timeout: const Duration(seconds: 2),
        interval: const Duration(milliseconds: 20),
      );
      Future<void>.delayed(const Duration(milliseconds: 15), () {
        cancelled = true;
      });
      final result = await verifier.verify(
        allowedIPs: const ['0.0.0.0/0'],
        endpoint: '1.2.3.4:51820',
        isCancelled: () => cancelled,
      );
      expect(result, VpnVerificationResult.cancelled);
    });
  });
}
