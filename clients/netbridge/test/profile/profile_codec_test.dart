import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:netbridge/profile/profile.dart';

NbVpnProfile sampleProfile() {
  // 32-byte keys (base64) — validation only checks length, not curve math.
  final clientKey = base64.encode(List<int>.generate(32, (i) => i + 1));
  final serverKey = base64.encode(List<int>.generate(32, (i) => 100 + i));
  return NbVpnProfile(
    v: 1,
    name: 'test-peer',
    client: ClientSection(
      privateKey: clientKey,
      address: const ['10.8.0.2/32'],
      dns: const ['1.1.1.1', '1.0.0.1'],
      mtu: 1280,
    ),
    server: ServerSection(
      publicKey: serverKey,
      endpoint: '203.0.113.10:51820',
      allowedIPs: const ['0.0.0.0/0', '::/0'],
      persistentKeepalive: 25,
      presharedKey: null,
    ),
  );
}

void main() {
  group('ProfileCodec URI roundtrip', () {
    test('sanitize strips quotes and newlines', () {
      final p = sampleProfile();
      final uri = ProfileCodec.encodeUri(p);
      final wrapped = '"\n  $uri\n"';
      final got = ProfileCodec.decodeUri(wrapped);
      expect(got.name, p.name);
      expect(got.server.endpoint, p.server.endpoint);
      expect(ProfileCodec.sanitizeUriInput("  'nbvpn:1?abc'  "), 'nbvpn:1?abc');
    });

    test('sanitize extracts URI from SSH show --uri paste', () {
      final p = sampleProfile();
      final uri = ProfileCodec.encodeUri(p);
      final paste = '''
WARNING: URI / QR / profile file contain the client private key — treat as secrets; do not share publicly.
$uri
''';
      final got = ProfileCodec.parseFlexibleImport(paste);
      expect(got.server.endpoint, p.server.endpoint);
      expect(got.name, p.name);
    });

    test('sanitize strips markdown fence', () {
      final p = sampleProfile();
      final uri = ProfileCodec.encodeUri(p);
      final got = ProfileCodec.decodeUri('```\n$uri\n```');
      expect(got.name, p.name);
    });

    test('parseFlexibleImport accepts JSON', () {
      final p = sampleProfile();
      final json = jsonEncode(p.toJson());
      final got = ProfileCodec.parseFlexibleImport('prefix\n$json\n');
      expect(got.client.privateKey, p.client.privateKey);
    });

    test('encode/decode preserves fields', () {
      final p = sampleProfile();
      final uri = ProfileCodec.encodeUri(p);
      expect(uri.startsWith('nbvpn:1?'), isTrue);
      final payload = uri.substring('nbvpn:1?'.length);
      expect(payload.contains('+'), isFalse);
      expect(payload.contains('/'), isFalse);
      expect(payload.contains('='), isFalse);

      final got = ProfileCodec.decodeUri(uri);
      expect(got.v, p.v);
      expect(got.name, p.name);
      expect(got.client.privateKey, p.client.privateKey);
      expect(got.server.publicKey, p.server.publicKey);
      expect(got.server.endpoint, p.server.endpoint);
      expect(got.client.address, p.client.address);
      expect(got.server.allowedIPs.length, 2);
      expect(got.client.dns, p.client.dns);
    });

    test('JSON parse roundtrip equals URI path', () {
      final p = sampleProfile();
      final uriProfile = ProfileCodec.decodeUri(ProfileCodec.encodeUri(p));
      final jsonProfile =
          ProfileCodec.parseJsonString(jsonEncode(p.toJson()));
      expect(uriProfile.client.privateKey, jsonProfile.client.privateKey);
      expect(uriProfile.server.endpoint, jsonProfile.server.endpoint);
    });
    test('sameCredentialsAs ignores name', () {
      final a = sampleProfile();
      final b = NbVpnProfile(
        v: a.v,
        name: 'other-local-name',
        client: a.client,
        server: a.server,
      );
      expect(a.sameCredentialsAs(b), isTrue);
      final c = NbVpnProfile(
        v: a.v,
        name: a.name,
        client: a.client,
        server: ServerSection(
          publicKey: a.server.publicKey,
          endpoint: '198.51.100.1:51820',
          allowedIPs: a.server.allowedIPs,
        ),
      );
      expect(a.sameCredentialsAs(c), isFalse);
    });

    test('sanitize keeps long nbvpn:1? payload intact', () {
      final p = sampleProfile();
      final uri = ProfileCodec.encodeUri(p);
      expect(uri.length, greaterThan(100));
      final got = ProfileCodec.decodeUri('  $uri  ');
      expect(got.client.privateKey, p.client.privateKey);
    });
  });

  group('ProfileCodec errors', () {
    test('E_URI_SCHEME', () {
      expect(
        () => ProfileCodec.decodeUri('wireguard:1?abc'),
        throwsA(
          isA<ProfileException>().having(
            (e) => e.code,
            'code',
            ProfileErrorCode.uriScheme,
          ),
        ),
      );
      try {
        ProfileCodec.decodeUri('http://x');
      } on ProfileException catch (e) {
        expect(e.messageZh, contains('nbvpn'));
      }
    });

    test('E_URI_VERSION', () {
      expect(
        () => ProfileCodec.decodeUri('nbvpn:99?abc'),
        throwsA(
          isA<ProfileException>().having(
            (e) => e.code,
            'code',
            ProfileErrorCode.uriVersion,
          ),
        ),
      );
    });

    test('E_URI_DECODE bad base64', () {
      expect(
        () => ProfileCodec.decodeUri('nbvpn:1?!!!'),
        throwsA(
          isA<ProfileException>().having(
            (e) => e.code,
            'code',
            ProfileErrorCode.uriDecode,
          ),
        ),
      );
    });

    test('endpoint without port', () {
      final p = sampleProfile();
      final bad = NbVpnProfile(
        v: p.v,
        name: p.name,
        client: p.client,
        server: ServerSection(
          publicKey: p.server.publicKey,
          endpoint: '203.0.113.10',
          allowedIPs: p.server.allowedIPs,
        ),
      );
      expect(
        () => ProfileCodec.validate(bad),
        throwsA(
          isA<ProfileException>().having(
            (e) => e.code,
            'code',
            ProfileErrorCode.profileInvalid,
          ),
        ),
      );
    });

    test('E_PROFILE_UNSUPPORTED when v too high', () {
      final p = sampleProfile();
      final high = NbVpnProfile(
        v: 99,
        name: p.name,
        client: p.client,
        server: p.server,
      );
      expect(
        () => ProfileCodec.validate(high),
        throwsA(
          isA<ProfileException>().having(
            (e) => e.code,
            'code',
            ProfileErrorCode.profileUnsupported,
          ),
        ),
      );
      try {
        ProfileCodec.validate(high);
      } on ProfileException catch (e) {
        expect(e.messageZh, contains('升级'));
      }
    });

    test('bad key length', () {
      final p = sampleProfile();
      final bad = NbVpnProfile(
        v: p.v,
        name: p.name,
        client: ClientSection(
          privateKey: base64.encode([1, 2, 3]),
          address: p.client.address,
          dns: p.client.dns,
        ),
        server: p.server,
      );
      expect(
        () => ProfileCodec.validate(bad),
        throwsA(isA<ProfileException>()),
      );
    });
  });

  group('WireGuard conf', () {
    test('contains interface and peer', () {
      final conf = ProfileCodec.toWireGuardConf(sampleProfile());
      expect(conf, contains('[Interface]'));
      expect(conf, contains('[Peer]'));
      expect(conf, contains('PrivateKey ='));
      expect(conf, contains('Endpoint ='));
      expect(conf.toLowerCase(), isNot(contains('server private')));
    });
  });

  group('optional endpointV6', () {
    test('roundtrip preserves endpointV6 and ipv6Enabled', () {
      final p = sampleProfile();
      final withV6 = NbVpnProfile(
        v: p.v,
        name: p.name,
        client: p.client,
        server: ServerSection(
          publicKey: p.server.publicKey,
          endpoint: p.server.endpoint,
          endpointV6: '[2001:db8::1]:51820',
          ipv6Enabled: true,
          allowedIPs: p.server.allowedIPs,
          persistentKeepalive: p.server.persistentKeepalive,
        ),
      );
      final got = ProfileCodec.decodeUri(ProfileCodec.encodeUri(withV6));
      expect(got.server.endpointV6, '[2001:db8::1]:51820');
      expect(got.server.ipv6Enabled, isTrue);
      expect(got.server.activeEndpoint, '[2001:db8::1]:51820');
      final conf = ProfileCodec.toWireGuardConf(got);
      expect(conf, contains('Endpoint = [2001:db8::1]:51820'));
    });

    test('legacy profile without endpointV6 still validates', () {
      final p = sampleProfile();
      expect(p.server.endpointV6, isNull);
      expect(p.server.ipv6Enabled, isFalse);
      expect(p.server.activeEndpoint, p.server.endpoint);
      ProfileCodec.validate(p);
      final map = p.toJson()['server'] as Map<String, dynamic>;
      expect(map.containsKey('endpointV6'), isFalse);
      expect(map.containsKey('ipv6Enabled'), isFalse);
    });

    test('ipv6Enabled off uses primary endpoint', () {
      final p = sampleProfile();
      final withV6 = NbVpnProfile(
        v: p.v,
        name: p.name,
        client: p.client,
        server: ServerSection(
          publicKey: p.server.publicKey,
          endpoint: p.server.endpoint,
          endpointV6: '[2001:db8::1]:51820',
          ipv6Enabled: false,
          allowedIPs: p.server.allowedIPs,
        ),
      );
      expect(withV6.server.activeEndpoint, p.server.endpoint);
      final conf = ProfileCodec.toWireGuardConf(withV6);
      expect(conf, contains('Endpoint = ${p.server.endpoint}'));
    });

    test('rejects bare IPv6 without brackets', () {
      final p = sampleProfile();
      final bad = NbVpnProfile(
        v: p.v,
        name: p.name,
        client: p.client,
        server: ServerSection(
          publicKey: p.server.publicKey,
          endpoint: p.server.endpoint,
          endpointV6: '2001:db8::1',
          ipv6Enabled: true,
          allowedIPs: p.server.allowedIPs,
        ),
      );
      expect(
        () => ProfileCodec.validate(bad),
        throwsA(isA<ProfileException>()),
      );
    });
  });
}
