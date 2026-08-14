# netbridge（网桥 VPN 客户端）

Flutter 四端客户端：Android / iOS / Windows / macOS。

## 打包分发

```bash
cd clients/netbridge
./scripts/package-all.sh
```

产物目录：`dist/`（见 `dist/README.txt`、`dist/PACKAGE-STATUS.txt`）。

| 产物 | 说明 |
|------|------|
| `NetBridge-android-arm64.apk` | R8 slim arm64，debug-signed 可侧载 |
| `NetBridge-macOS.dmg` | ad-hoc 签名，不上架 |
| `NetBridge-iOS.ipa` | 无 Team 时为 UNSIGNED stub |
| `NetBridge-windows.exe` | 需在 Windows 上构建 |

试用步骤：`docs/delivery/nbvpn/TRY-CONNECT.md`
