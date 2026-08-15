# Apple Packet Tunnel — notes

| Item | Value |
|------|--------|
| Host | `com.netbridge.netbridge` |
| Extension | `com.netbridge.netbridge.WGExtension` |
| App Group | `group.com.netbridge.netbridge` |
| Dart | `AppleTunnelConfig.extensionTargetLinked = true` |
| Team（工程内） | `846K6R4WU8`（Personal；可在 Xcode 更换） |

**已完成：** macOS / iOS `WGExtension` target + Embed Foundation Extensions。  
**Debug：** Host `AdHoc.entitlements`、Extension `WGExtension-Debug.entitlements`（无 NE，Personal Team 可编）。  
**Release：** Host / Extension 使用含 packet-tunnel + App Group 的 entitlements。  

**未完成：** WireGuardKit SPM/vendor；付费 NE 能力；公证。示例实现：`PacketTunnelProvider.WireGuardKit.swift.example`。  

详见 `IMPL.md` 诚实边界。
