import 'package:flutter_test/flutter_test.dart';
import 'package:netbridge/models/server_entry.dart';
import 'package:netbridge/profile/nbvpn_profile.dart';
import 'package:netbridge/services/server_store.dart';
import 'package:netbridge/services/vpn/vpn_connectivity_verifier.dart';
import 'package:netbridge/services/vpn/vpn_tunnel.dart';
import 'package:netbridge/state/app_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/fake_vpn_tunnel.dart';

NbVpnProfile _profile() {
  return NbVpnProfile(
    v: 1,
    name: 'n',
    client: const ClientSection(
      privateKey: 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',
      address: ['10.8.0.2/32'],
      dns: ['1.1.1.1'],
    ),
    server: const ServerSection(
      publicKey: 'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=',
      endpoint: '1.1.1.1:51820',
      allowedIPs: ['0.0.0.0/0'],
      persistentKeepalive: 25,
    ),
  );
}

Future<AppController> _boot(
  FakeVpnTunnel tunnel, {
  VpnConnectivityVerifier? verifier,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final c = AppController(
    tunnel: tunnel,
    serverStore: ServerStore(prefs: prefs),
    connectivityVerifier:
        verifier ?? VpnConnectivityVerifier.testing(succeed: true),
  );
  await c.bootstrap();
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('does not show connected until handshake verification passes', () async {
    final tunnel = FakeVpnTunnel(connectDelay: const Duration(milliseconds: 20));
    var probeStarted = false;
    final verifier = VpnConnectivityVerifier(
      timeout: const Duration(seconds: 2),
      interval: const Duration(milliseconds: 30),
      httpProbe: () async {
        probeStarted = true;
        await Future<void>.delayed(const Duration(milliseconds: 150));
        return true;
      },
    );
    final c = await _boot(tunnel, verifier: verifier);
    final entry = await c.addServer(profile: _profile(), localName: 'node');

    final fut = c.connect(entry.id);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(probeStarted, isTrue);
    expect(c.status, VpnUiStatus.connecting);
    expect(c.statusDetail, anyOf(contains('握手'), contains('handshake')));

    await fut;
    expect(c.status, VpnUiStatus.connected);
    expect(c.activeServerId, entry.id);
    c.dispose();
  });

  test('handshake failure disconnects and shows error', () async {
    final tunnel = FakeVpnTunnel(
      connectDelay: const Duration(milliseconds: 15),
      disconnectDelay: const Duration(milliseconds: 10),
    );
    final verifier = VpnConnectivityVerifier.testing(
      succeed: false,
      timeout: const Duration(milliseconds: 50),
      interval: const Duration(milliseconds: 10),
    );
    final c = await _boot(tunnel, verifier: verifier);
    final entry = await c.addServer(profile: _profile(), localName: 'node');

    await c.connect(entry.id);

    expect(c.status, VpnUiStatus.error);
    expect(c.status, isNot(VpnUiStatus.connected));
    expect(c.activeServerId, isNull);
    expect(c.lastError, anyOf(contains('握手'), contains('Handshake')));
    expect(tunnel.disconnectCount, greaterThanOrEqualTo(1));
    c.dispose();
  });
}
