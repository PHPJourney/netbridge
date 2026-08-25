import 'dart:async';
import 'dart:io';

import '../../profile/split_tunnel.dart';

/// Outcome of post-connect VPN connectivity / handshake verification.
enum VpnVerificationResult {
  success,
  failed,
  cancelled,
}

/// Probes tunnel reachability after the OS reports VPN interface up.
///
/// `wireguard_flutter` does not expose WireGuard handshake stats, so for
/// routes that send public traffic through the tunnel we verify with short
/// HTTP requests (traffic must traverse the encrypted tunnel).
class VpnConnectivityVerifier {
  const VpnConnectivityVerifier({
    this.timeout = const Duration(seconds: 25),
    this.interval = const Duration(seconds: 2),
    this.httpProbe,
    this.httpProbeUrls = defaultHttpProbeUrls,
    this.perProbeTimeout = const Duration(seconds: 4),
  });

  static const defaultHttpProbeUrls = [
    'https://connectivitycheck.gstatic.com/generate_204',
    'https://www.msftconnecttest.com/connecttest.txt',
    'https://cloudflare.com/cdn-cgi/trace',
  ];

  static const Duration defaultTimeout = Duration(seconds: 25);

  final Duration timeout;
  final Duration interval;
  final Duration perProbeTimeout;

  /// When set (tests), bypasses real HTTP and returns this value directly.
  final Future<bool> Function()? httpProbe;

  final List<String> httpProbeUrls;

  /// Fast verifier for unit tests ([AppController] injects this in tests).
  factory VpnConnectivityVerifier.testing({
    bool succeed = true,
    Duration timeout = const Duration(milliseconds: 30),
    Duration interval = const Duration(milliseconds: 5),
  }) {
    return VpnConnectivityVerifier(
      timeout: timeout,
      interval: interval,
      httpProbe: () async => succeed,
    );
  }

  /// Whether HTTP probes are expected to traverse the VPN (full or split-public).
  static bool routesPublicInternet(Iterable<String> allowedIPs) {
    if (SplitTunnel.isFullTunnelDefault(allowedIPs)) return true;
    // Exclude-private rewrite emits the static public CIDR chunks.
    return allowedIPs.any(
      (raw) => raw.trim() == SplitTunnel.ipv4ExcludePrivate.first,
    );
  }

  /// Resolve effective AllowedIPs (mirrors tunnel connect).
  static List<String> effectiveAllowedIPs(
    List<String> profileAllowedIPs, {
    required bool excludePrivateNetworks,
  }) {
    return SplitTunnel.resolveAllowedIPs(
      profileAllowedIPs,
      excludePrivate: excludePrivateNetworks,
    );
  }

  Future<VpnVerificationResult> verify({
    required List<String> allowedIPs,
    required String endpoint,
    required bool Function() isCancelled,
  }) async {
    final useHttp = routesPublicInternet(allowedIPs);
    final deadline = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(deadline)) {
      if (isCancelled()) return VpnVerificationResult.cancelled;

      if (useHttp) {
        if (await _probeHttp()) {
          return VpnVerificationResult.success;
        }
      } else {
        // VPN-subnet-only routing: HTTP cannot prove handshake; best-effort UDP.
        if (await _probeUdpEndpoint(endpoint)) {
          return VpnVerificationResult.success;
        }
      }

      await Future<void>.delayed(interval);
    }

    return VpnVerificationResult.failed;
  }

  Future<bool> _probeHttp() async {
    if (httpProbe != null) return httpProbe!();
    for (final url in httpProbeUrls) {
      if (await _httpHead(url)) return true;
    }
    return false;
  }

  Future<bool> _httpHead(String url) async {
    final client = HttpClient();
    client.connectionTimeout = perProbeTimeout;
    try {
      final uri = Uri.parse(url);
      final request = await client.headUrl(uri).timeout(perProbeTimeout);
      request.followRedirects = true;
      final response =
          await request.close().timeout(perProbeTimeout);
      await response.drain<void>();
      // Any HTTP response means egress through the tunnel works.
      return response.statusCode > 0;
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }

  /// Best-effort UDP reachability to the WireGuard endpoint (VPN-subnet-only).
  Future<bool> _probeUdpEndpoint(String endpoint) async {
    final parsed = _parseEndpoint(endpoint);
    if (parsed == null) return false;
    final (host, port) = parsed;

    RawDatagramSocket? socket;
    try {
      final addresses = await InternetAddress.lookup(host)
          .timeout(const Duration(seconds: 3));
      if (addresses.isEmpty) return false;

      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = false;

      final completer = Completer<bool>();
      late StreamSubscription<RawSocketEvent> sub;
      final timer = Timer(const Duration(seconds: 3), () {
        if (!completer.isCompleted) completer.complete(false);
      });

      sub = socket.listen((event) {
        if (event == RawSocketEvent.read && !completer.isCompleted) {
          completer.complete(true);
        }
      });

      // Junk datagram — WireGuard may ignore it; ICMP unreachable still counts.
      socket.send(const [0], addresses.first, port);

      final gotReply = await completer.future;
      timer.cancel();
      await sub.cancel();
      return gotReply;
    } catch (_) {
      return false;
    } finally {
      socket?.close();
    }
  }

  (String host, int port)? _parseEndpoint(String endpoint) {
    final trimmed = endpoint.trim();
    if (trimmed.isEmpty) return null;

    String host;
    String portStr;
    if (trimmed.startsWith('[')) {
      final idx = trimmed.lastIndexOf(']:');
      if (idx < 0) return null;
      host = trimmed.substring(1, idx); // strip brackets for lookup
      portStr = trimmed.substring(idx + 2);
    } else {
      final colon = trimmed.lastIndexOf(':');
      if (colon <= 0 || colon >= trimmed.length - 1) return null;
      // Reject bare IPv6 (ambiguous without brackets).
      if (trimmed.substring(0, colon).contains(':')) return null;
      host = trimmed.substring(0, colon);
      portStr = trimmed.substring(colon + 1);
    }
    final port = int.tryParse(portStr);
    if (host.isEmpty || port == null || port < 1 || port > 65535) return null;
    return (host, port);
  }
}
