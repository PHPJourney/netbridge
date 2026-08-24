import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:netbridge/models/server_entry.dart';
import 'package:netbridge/profile/nbvpn_profile.dart';
import 'package:netbridge/profile/profile_codec.dart';
import 'package:netbridge/services/server_import.dart';
import 'package:netbridge/services/server_pack_codec.dart';
import 'package:netbridge/services/server_pack_crypto.dart';

NbVpnProfile _sample({String name = 'demo'}) {
  final clientKey = base64.encode(List<int>.generate(32, (i) => i + 1));
  final serverKey = base64.encode(List<int>.generate(32, (i) => 100 + i));
  return NbVpnProfile(
    v: 1,
    name: name,
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

ServerEntry _entry(String id, String name) => ServerEntry(
      id: id,
      localName: name,
      profile: _sample(name: name),
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );

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

  test('ServerPackCodec encrypted QR URI roundtrip (compact gzip)', () async {
    final entry = _entry('id-1', 'Node A');
    final uri = await ServerPackCodec.encryptPackUri([entry], 'secret');
    expect(uri.startsWith('nbvpn-enc:1?'), isTrue);
    expect(uri.length, lessThan(2500), reason: 'QR payload should stay scannable');
    final got = await ServerPackCodec.decryptPackUri(uri, 'secret');
    expect(got.length, 1);
    expect(got.first.localName, 'Node A');
    expect(got.first.profile.server.endpoint, 'vpn.example.com:51820');
  });

  test('ServerPackCodec multi-server encrypted roundtrip', () async {
    final entries = [_entry('a', 'A'), _entry('b', 'B')];
    final uri = await ServerPackCodec.encryptPackUri(entries, 'pw');
    final got = await ServerPackCodec.decryptPackUri(uri, 'pw');
    expect(got.length, 2);
    expect(got.map((e) => e.localName).toList(), ['A', 'B']);
  });

  test('ProfileImportService wrong passphrase throws ImportException', () async {
    final entry = _entry('id-1', 'Node A');
    final uri = await ServerPackCodec.encryptPackUri([entry], 'right');
    expect(
      () => ProfileImportService.decryptWithPassphrase(uri, 'wrong'),
      throwsA(isA<ImportException>()),
    );
  });

  test('ProfileImportService parseClearText nbvpn URI', () {
    final profile = _sample();
    final uri = ProfileCodec.encodeUri(profile);
    final got = ProfileImportService.parseClearText(uri);
    expect(got.length, 1);
    expect(got.first.profile.name, 'demo');
  });
}
