import 'package:flutter_test/flutter_test.dart';
import 'package:netbridge/models/server_entry.dart';
import 'package:netbridge/profile/nbvpn_profile.dart';
import 'package:netbridge/services/server_store.dart';
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

Future<AppController> _boot(FakeVpnTunnel tunnel) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final c = AppController(
    tunnel: tunnel,
    serverStore: ServerStore(prefs: prefs),
  );
  await c.bootstrap();
  return c;
}

Future<ServerEntry> _addOne(AppController c) async {
  return c.addServer(profile: _profile(), localName: 'node');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('empty server list: bootstrap reconnect/noConnection → disconnected',
      () async {
    for (final noise in [
      VpnTunnelStage.reconnecting,
      VpnTunnelStage.noConnection,
      VpnTunnelStage.preparing,
      VpnTunnelStage.connecting,
      VpnTunnelStage.denied,
    ]) {
      final tunnel = FakeVpnTunnel()..initialStage = noise;
      final c = await _boot(tunnel);
      expect(c.servers, isEmpty);
      expect(c.activeServerId, isNull);
      expect(c.status, VpnUiStatus.disconnected,
          reason: 'stage $noise must not surface as reconnect/error');
      expect(c.lastError, isNull);
      c.dispose();
    }
  });

  test('empty list: late plugin reconnect stream stays disconnected', () async {
    final tunnel = FakeVpnTunnel();
    final c = await _boot(tunnel);

    tunnel.simulateStage(VpnTunnelStage.reconnecting);
    await Future<void>.delayed(Duration.zero);
    expect(c.status, VpnUiStatus.disconnected);

    tunnel.simulateStage(VpnTunnelStage.noConnection);
    await Future<void>.delayed(Duration.zero);
    expect(c.status, VpnUiStatus.disconnected);
    c.dispose();
  });

  test('transient denied during first connect is ignored', () async {
    final tunnel = FakeVpnTunnel(
      connectDelay: const Duration(milliseconds: 60),
    );
    final c = await _boot(tunnel);
    final entry = await _addOne(c);

    final fut = c.connect(entry.id);
    await Future<void>.delayed(const Duration(milliseconds: 8));
    expect(c.status, VpnUiStatus.connecting);
    tunnel.simulateStage(VpnTunnelStage.denied);
    await Future<void>.delayed(Duration.zero);
    expect(c.status, VpnUiStatus.connecting);
    expect(c.lastError, isNull);

    await fut;
    expect(c.status, VpnUiStatus.connected);
    expect(c.activeServerId, entry.id);
    c.dispose();
  });

  test('real denied after connect settles shows permission error', () async {
    final tunnel = FakeVpnTunnel(
      connectDelay: const Duration(milliseconds: 10),
      finalStage: VpnTunnelStage.denied,
    );
    final c = await _boot(tunnel);
    final entry = await _addOne(c);

    await c.connect(entry.id);

    expect(c.status, VpnUiStatus.error);
    expect(c.status, isNot(VpnUiStatus.reconnecting));
    expect(c.activeServerId, isNull);
    expect(c.lastError, anyOf(contains('权限'), contains('permission')));
    c.dispose();
  });

  test('noConnection only becomes reconnect after connected session', () async {
    final tunnel = FakeVpnTunnel(
      connectDelay: const Duration(milliseconds: 20),
    );
    final c = await _boot(tunnel);
    final entry = await _addOne(c);

    await c.connect(entry.id);
    expect(c.status, VpnUiStatus.connected);

    tunnel.simulateStage(VpnTunnelStage.noConnection);
    await Future<void>.delayed(Duration.zero);
    expect(c.status, VpnUiStatus.reconnecting);
    c.dispose();
  });

  test('noConnection during first connect stays connecting, not reconnect',
      () async {
    final tunnel = FakeVpnTunnel(
      connectDelay: const Duration(milliseconds: 80),
    );
    final c = await _boot(tunnel);
    final entry = await _addOne(c);

    final fut = c.connect(entry.id);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(c.status, VpnUiStatus.connecting);
    tunnel.simulateStage(VpnTunnelStage.noConnection);
    await Future<void>.delayed(Duration.zero);
    expect(c.status, VpnUiStatus.connecting);
    expect(c.status, isNot(VpnUiStatus.reconnecting));
    await fut;
    c.dispose();
  });
}
