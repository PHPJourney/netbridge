import 'package:flutter_test/flutter_test.dart';
import 'package:netbridge/models/server_entry.dart';
import 'package:netbridge/profile/nbvpn_profile.dart';
import 'package:netbridge/services/server_store.dart';
import 'package:netbridge/services/vpn/stub_vpn_tunnel.dart';
import 'package:netbridge/state/app_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

NbVpnProfile _sampleProfile({String endpoint = '1.2.3.4:51820'}) {
  return NbVpnProfile.fromJson({
    'v': 1,
    'name': 'node-a',
    'server': {
      'publicKey': 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',
      'endpoint': endpoint,
    },
    'client': {
      'privateKey': 'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=',
      'address': ['10.7.0.2/32'],
      'dns': ['1.1.1.1'],
    },
  });
}

class _BoomStore extends ServerStore {
  _BoomStore() : super(prefs: null);

  @override
  Future<void> save(List<ServerEntry> entries) async {
    throw StateError('simulated keychain failure');
  }

  @override
  Future<List<ServerEntry>> load() async => [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('addServer notifies even when persist fails', () async {
    final c = AppController(
      tunnel: StubVpnTunnel(),
      serverStore: _BoomStore(),
    );
    c.loading = false;
    var notified = 0;
    c.addListener(() => notified++);

    final entry = await c.addServer(
      profile: _sampleProfile(),
      localName: '我的节点',
    );

    expect(c.servers, hasLength(1));
    expect(c.servers.first.id, entry.id);
    expect(c.servers.first.localName, '我的节点');
    expect(notified, greaterThan(0));
    expect(c.lastError, contains('写入本地存储失败'));
  });

  test('connect on Stub sets error, not connected', () async {
    final c = AppController(tunnel: StubVpnTunnel());
    c.loading = false;
    await c.addServer(profile: _sampleProfile(), localName: 'n');
    // Force in-memory only if boom — use working store via default after add
    // Re-create with real prefs store for this path:
    final c2 = AppController(tunnel: StubVpnTunnel());
    c2.loading = false;
    SharedPreferences.setMockInitialValues({});
    final e = await c2.addServer(profile: _sampleProfile(), localName: 'n');
    await c2.connect(e.id);
    expect(c2.status, VpnUiStatus.error);
    expect(c2.status, isNot(VpnUiStatus.connected));
    expect(c2.lastError, contains('Network Extension'));
  });

  test('ServerStore prefs roundtrip on desktop path', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = ServerStore(prefs: prefs);
    final entry = ServerEntry(
      id: 'id-1',
      localName: '桌面节点',
      profile: _sampleProfile(),
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );
    await store.save([entry]);
    final loaded = await store.load();
    expect(loaded, hasLength(1));
    expect(loaded.first.localName, '桌面节点');
    expect(loaded.first.profile.server.endpoint, '1.2.3.4:51820');
  });
}
