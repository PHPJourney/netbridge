import 'package:flutter_test/flutter_test.dart';
import 'package:netbridge/models/server_entry.dart';
import 'package:netbridge/profile/nbvpn_profile.dart';
import 'package:netbridge/state/app_controller.dart';

import 'services/fake_vpn_tunnel.dart';

NbVpnProfile _profile(String name, String endpoint) {
  return NbVpnProfile(
    v: 1,
    name: name,
    client: const ClientSection(
      privateKey: 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',
      address: ['10.8.0.2/32'],
      dns: ['1.1.1.1'],
    ),
    server: ServerSection(
      publicKey: 'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=',
      endpoint: endpoint,
      allowedIPs: const ['0.0.0.0/0'],
      persistentKeepalive: 25,
    ),
  );
}

ServerEntry _entry(String id, String name, String endpoint) {
  final now = DateTime.utc(2024, 1, 1);
  return ServerEntry(
    id: id,
    localName: name,
    profile: _profile(name, endpoint),
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  test('switch server: serial disconnect then connect; only new id stays active',
      () async {
    final tunnel = FakeVpnTunnel(
      connectDelay: const Duration(milliseconds: 50),
      disconnectDelay: const Duration(milliseconds: 40),
    );
    final c = AppController(tunnel: tunnel);
    c.loading = false;
    c.servers = [
      _entry('s1', 'Server1', '1.1.1.1:51820'),
      _entry('s2', 'Server2', '2.2.2.2:51820'),
    ];

    await c.connect('s1');
    expect(c.activeServerId, 's1');
    expect(c.status, VpnUiStatus.connected);
    expect(tunnel.connectCount, 1);

    // Switch to s2 while s1 is connected.
    await c.connect('s2');
    expect(tunnel.disconnectCount, greaterThanOrEqualTo(1));
    expect(c.activeServerId, 's2');
    expect(c.status, VpnUiStatus.connected);
    expect(c.isServerConnected('s1'), isFalse);
    expect(c.isServerConnected('s2'), isTrue);
    expect(tunnel.connectedEndpoints.last, '2.2.2.2:51820');
  });

  test('rapid dual connect: last requested server wins without stuck disconnected',
      () async {
    final tunnel = FakeVpnTunnel(
      connectDelay: const Duration(milliseconds: 80),
      disconnectDelay: const Duration(milliseconds: 50),
    );
    final c = AppController(tunnel: tunnel);
    c.loading = false;
    c.servers = [
      _entry('s1', 'Server1', '1.1.1.1:51820'),
      _entry('s2', 'Server2', '2.2.2.2:51820'),
    ];

    await c.connect('s1');
    expect(c.status, VpnUiStatus.connected);

    // Fire two switches without awaiting the first.
    final a = c.connect('s2');
    final b = c.connect('s1');
    await Future.wait([a, b]);

    // Queue is serial: final connect is s1.
    expect(c.activeServerId, 's1');
    expect(c.status, VpnUiStatus.connected);
    expect(c.isServerConnected('s1'), isTrue);
    expect(c.isServerConnected('s2'), isFalse);
  });

  test('disconnect stage during switch does not clear the new activeServerId',
      () async {
    final tunnel = FakeVpnTunnel(
      connectDelay: const Duration(milliseconds: 20),
      disconnectDelay: const Duration(milliseconds: 60),
    );
    final c = AppController(tunnel: tunnel);
    c.loading = false;
    c.servers = [
      _entry('s1', 'Server1', '1.1.1.1:51820'),
      _entry('s2', 'Server2', '2.2.2.2:51820'),
    ];

    await c.connect('s1');
    await c.connect('s2');

    expect(c.activeServerId, 's2');
    expect(c.status, VpnUiStatus.connected);
  });
}
