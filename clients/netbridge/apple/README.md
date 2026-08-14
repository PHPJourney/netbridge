# Apple Packet Tunnel — notes

Shared identifiers (also in `lib/services/vpn/apple_tunnel_config.dart`):

| Item | Value |
|------|--------|
| Host app | `com.netbridge.netbridge` |
| Extension | `com.netbridge.netbridge.WGExtension` |
| App Group | `group.com.netbridge.netbridge` |

Scaffold sources live under:

- `ios/WGExtension/` — PacketTunnelProvider (shell), Info.plist, entitlements
- `macos/WGExtension/` — same for macOS
- `ios/Runner/Runner.entitlements` / `macos/Runner/*entitlements` — host NE + App Group templates

**No Apple Team ID / provisioning profiles / certificates are committed.**

Full WireGuardKit-based provider (from `wireguard_flutter` example, MIT):  
`apple/PacketTunnelProvider.WireGuardKit.swift.example`

Exact Xcode steps: `clients/netbridge/IMPL.md` § iOS/macOS.
