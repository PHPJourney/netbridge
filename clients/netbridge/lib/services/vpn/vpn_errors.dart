/// Map raw tunnel / platform exceptions to short UX copy.
/// Never include profile secrets in the returned string.
///
/// [languageCode] `en` → English; otherwise Chinese (default, keeps existing tests).
String humanizeVpnError(Object error, {String languageCode = 'zh'}) {
  final en = languageCode.toLowerCase().startsWith('en');
  final raw = error.toString();
  final lower = raw.toLowerCase();

  if (lower.contains('denied') ||
      lower.contains('permission') ||
      lower.contains('not authorized') ||
      lower.contains('user canceled') ||
      lower.contains('user cancelled')) {
    return en
        ? 'VPN permission was denied. Allow “NetBridge VPN” in system settings and retry.'
        : '系统拒绝了 VPN 权限。请在系统设置中允许「网桥 VPN」后重试。';
  }
  if (lower.contains('administrator') || lower.contains('elevat')) {
    return en
        ? 'Administrator rights are required to create the tunnel (Windows). Relaunch as admin.'
        : '需要管理员权限才能建立隧道（Windows）。请以管理员身份重新运行应用。';
  }
  if (lower.contains('network is unreachable') ||
      lower.contains('no route') ||
      lower.contains('timed out') ||
      lower.contains('timeout') ||
      lower.contains('unreachable')) {
    return en
        ? 'Cannot reach the node. Confirm the server is up, endpoint is correct, and UDP 51820 is allowed on the cloud SG / host firewall.'
        : '无法连上节点。请确认服务器在线、endpoint 正确，且云安全组/主机防火墙已放行 UDP 51820。';
  }
  if (lower.contains('wireguardkit') ||
      lower.contains('extension') ||
      lower.contains('provider')) {
    return en
        ? 'Packet Tunnel / Extension is not ready. iOS/macOS needs signing and WGExtension linked (see Settings); use Android or Stub for UI checks.'
        : 'Packet Tunnel / Extension 未就绪。iOS/macOS 需完成签名与 WGExtension 链接（见设置页说明）；当前请用 Android 或 Stub 验收 UI。';
  }
  if (lower.contains('already') && lower.contains('running')) {
    return en
        ? 'A tunnel is already running. Disconnect before connecting another node.'
        : '已有隧道在运行。请先断开再连接其他节点。';
  }

  // Keep message short; strip noisy exception prefixes.
  var msg = raw.replaceFirst(RegExp(r'^Exception:\s*'), '');
  msg = msg.replaceFirst(RegExp(r'^VpnException:\s*'), '');
  if (msg.length > 180) {
    msg = '${msg.substring(0, 177)}…';
  }
  return en ? 'Connection failed: $msg' : '连接失败：$msg';
}
