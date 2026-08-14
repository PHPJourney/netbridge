import 'package:flutter_test/flutter_test.dart';
import 'package:netbridge/services/vpn/vpn_errors.dart';

void main() {
  test('maps permission denial', () {
    expect(
      humanizeVpnError(Exception('VpnStage.denied')),
      contains('VPN 权限'),
    );
  });

  test('maps unreachable / timeout', () {
    expect(
      humanizeVpnError(Exception('connection timed out')),
      contains('UDP 51820'),
    );
  });

  test('maps windows elevation', () {
    expect(
      humanizeVpnError(Exception('requires administrator')),
      contains('管理员'),
    );
  });

  test('keeps short generic message without secrets dump', () {
    final msg = humanizeVpnError(Exception('weird boom'));
    expect(msg, startsWith('连接失败：'));
    expect(msg.toLowerCase(), isNot(contains('privatekey')));
  });
}
