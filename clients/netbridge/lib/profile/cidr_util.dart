/// Minimal IPv4 CIDR helpers for WireGuard AllowedIPs rewriting.
///
/// Used to carve whitelist (bypass) ranges out of full-tunnel / exclude-private
/// route sets so those destinations leave the device directly.
class Ip4Cidr {
  const Ip4Cidr(this.network, this.prefix)
      : assert(prefix >= 0 && prefix <= 32);

  /// Network address as host-order uint32 (host bits zeroed).
  final int network;
  final int prefix;

  static final _re = RegExp(
    r'^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})(?:/(\d{1,2}))?$',
  );

  static int _mask(int prefix) {
    if (prefix <= 0) return 0;
    if (prefix >= 32) return 0xffffffff;
    return (0xffffffff << (32 - prefix)) & 0xffffffff;
  }

  static int _octets(int a, int b, int c, int d) =>
      ((a & 0xff) << 24) | ((b & 0xff) << 16) | ((c & 0xff) << 8) | (d & 0xff);

  /// Parse `a.b.c.d` or `a.b.c.d/p`. Returns null if invalid.
  static Ip4Cidr? tryParse(String raw) {
    final m = _re.firstMatch(raw.trim());
    if (m == null) return null;
    final a = int.parse(m.group(1)!);
    final b = int.parse(m.group(2)!);
    final c = int.parse(m.group(3)!);
    final d = int.parse(m.group(4)!);
    if ([a, b, c, d].any((x) => x < 0 || x > 255)) return null;
    final prefix = m.group(5) == null ? 32 : int.parse(m.group(5)!);
    if (prefix < 0 || prefix > 32) return null;
    final addr = _octets(a, b, c, d);
    final network = addr & _mask(prefix);
    return Ip4Cidr(network, prefix);
  }

  int get mask => _mask(prefix);

  int get broadcast {
    if (prefix >= 32) return network;
    return network | (~mask & 0xffffffff);
  }

  bool containsCidr(Ip4Cidr other) {
    if (other.prefix < prefix) return false;
    return (other.network & mask) == network;
  }

  bool overlaps(Ip4Cidr other) {
    final a0 = network;
    final a1 = broadcast;
    final b0 = other.network;
    final b1 = other.broadcast;
    return a0 <= b1 && b0 <= a1;
  }

  /// Split this range into sub-CIDRs that do not cover [cut].
  ///
  /// If ranges do not overlap, returns `[this]`. If [cut] covers this entirely,
  /// returns empty.
  List<Ip4Cidr> subtract(Ip4Cidr cut) {
    if (!overlaps(cut)) return [this];
    if (cut.containsCidr(this)) return const [];

    // Work on the overlapping portion only.
    var remaining = <Ip4Cidr>[this];
    final out = <Ip4Cidr>[];
    while (remaining.isNotEmpty) {
      final cur = remaining.removeLast();
      if (!cur.overlaps(cut)) {
        out.add(cur);
        continue;
      }
      if (cut.containsCidr(cur)) {
        continue;
      }
      if (cur.prefix >= 32) {
        // Single host overlapping cut → drop.
        continue;
      }
      final bit = 1 << (31 - cur.prefix);
      final left = Ip4Cidr(cur.network, cur.prefix + 1);
      final right = Ip4Cidr(cur.network | bit, cur.prefix + 1);
      remaining.add(left);
      remaining.add(right);
    }
    out.sort((a, b) => a.network.compareTo(b.network));
    return out;
  }

  @override
  String toString() {
    final a = (network >> 24) & 0xff;
    final b = (network >> 16) & 0xff;
    final c = (network >> 8) & 0xff;
    final d = network & 0xff;
    return '$a.$b.$c.$d/$prefix';
  }

  @override
  bool operator ==(Object other) =>
      other is Ip4Cidr && other.network == network && other.prefix == prefix;

  @override
  int get hashCode => Object.hash(network, prefix);
}

/// Apply IPv4 [bypass] CIDRs by removing them from [allowedIPs].
///
/// Non-IPv4 entries (IPv6 CIDRs, junk) are passed through unchanged.
/// Invalid bypass strings are ignored.
List<String> applyIpv4BypassCidrs(
  List<String> allowedIPs,
  Iterable<String> bypass,
) {
  final cuts = <Ip4Cidr>[];
  for (final raw in bypass) {
    final c = Ip4Cidr.tryParse(raw);
    if (c != null) cuts.add(c);
  }
  if (cuts.isEmpty) return List<String>.from(allowedIPs);

  final out = <String>[];
  for (final raw in allowedIPs) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) continue;
    final base = Ip4Cidr.tryParse(trimmed);
    if (base == null) {
      out.add(trimmed);
      continue;
    }
    var pieces = <Ip4Cidr>[base];
    for (final cut in cuts) {
      final next = <Ip4Cidr>[];
      for (final p in pieces) {
        next.addAll(p.subtract(cut));
      }
      pieces = next;
    }
    for (final p in pieces) {
      out.add(p.toString());
    }
  }
  return out;
}

/// True if [raw] looks like an IPv4 CIDR or host (whitelist-applicable).
bool looksLikeIpv4Cidr(String raw) => Ip4Cidr.tryParse(raw) != null;

/// True if [raw] looks like a domain (hostname), not a CIDR.
bool looksLikeDomain(String raw) {
  final s = raw.trim().toLowerCase();
  if (s.isEmpty || s.contains('/') || s.contains(' ')) return false;
  if (Ip4Cidr.tryParse(s) != null) return false;
  // Basic hostname: labels with dots, or single label.
  return RegExp(r'^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)*$')
      .hasMatch(s);
}
