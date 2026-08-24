import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:netbridge/models/server_entry.dart';
import 'package:netbridge/profile/nbvpn_profile.dart';
import 'package:netbridge/services/server_pack_codec.dart';
import 'package:netbridge/services/server_pack_crypto.dart';

NbVpnProfile _sample() {
  final clientKey = base64.encode(List<int>.generate(32, (i) => i + 1));
  final serverKey = base64.encode(List<int>.generate(32, (i) => 100 + i));
  return NbVpnProfile(
    v: 1,
    name: 'demo',
    client: ClientSection(
      privateKey: clientKey,
      address: const ['10.0.0.2/32'],
      dns: const ['1.1.1.1'],
      mtu: 1280,
    ),
    server: ServerSection(
      publicKey: serverKey,
      endpoint: 'vpn.example.com:51820',
      allowedIPs: const ['0.0.0.0/0'],
      persistentKeepalive: 25,
    ),
  );
}

void main() {
  test('ServerPackCrypto roundtrip', () async {
    final plain = utf8.encode('hello-netbridge');
    final env = await ServerPackCrypto.encrypt(
      plaintext: plain,
      passphrase: 'test-pass',
    );
    final out = await ServerPackCrypto.decrypt(
      envelope: env,
      passphrase: 'test-pass',
    );
    expect(utf8.decode(out), 'hello-netbridge');
  });

  test('ServerPackCodec encrypt URI roundtrip', () async {
    final entry = ServerEntry(
      id: 'id-1',
      localName: 'Node A',
      profile: _sample(),
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );
    final uri = await ServerPackCodec.encryptPackUri([entry], 'secret');
    expect(uri.startsWith('nbvpn-enc:1?'), isTrue);
    final got = await ServerPackCodec.decryptPackUri(uri, 'secret');
    expect(got.length, 1);
    expect(got.first.localName, 'Node A');
    expect(got.first.profile.server.endpoint, 'vpn.example.com:51820');
  });
}
