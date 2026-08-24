# netbridge（网桥 VPN 客户端）

Flutter 四端客户端：Android / iOS / Windows / macOS。

## 本机 macOS 业务（暂不分发）

macOS **不**走 GitHub Releases / OpenList / Pages 下载。本机使用：

```bash
cd clients/netbridge
flutter pub get && flutter gen-l10n
flutter run -d macos
```

- Flutter 内隧道：无 Network Extension 签名时多为 **Stub**（UI / 导入）。
- **真 VPN**：安装[官方 WireGuard](https://www.wireguard.com/install/)，用节点上 `nbvpn show --conf` 导出的 `.conf` 导入激活。
- 可选本机 ad-hoc `.app`：`./scripts/package-all.sh`（仅本机，不上架）。

详见 `docs/delivery/nbvpn/TRY-CONNECT.md`「本机 macOS 业务」。

## 打包分发

```bash
cd clients/netbridge
./scripts/package-all.sh
```

产物目录：`dist/`（见 `dist/README.txt`、`dist/PACKAGE-STATUS.txt`）。

| 产物 | 说明 |
|------|------|
| `NetBridge-android-arm64.apk` | R8 slim arm64，debug-signed 可侧载；**CI / Releases 主路径** |
| `NetBridge-windows.exe` | Windows 上构建；**CI / Releases 主路径** |
| `NetBridge-macOS.dmg` / `.app` | **仅本机可选**；CI **不**上传 Releases；不上 OpenList/Pages |
| `NetBridge-iOS.ipa` | 无 Team 时为 UNSIGNED stub；CI 跳过签名 |

试用步骤：`docs/delivery/nbvpn/TRY-CONNECT.md`

## 已知限制（编辑 / 导出 / 同步 / 分享）

功能已合入（`c3d1a46`）：主页可编辑、导出、同步、分享。

| 限制 | 说明 |
|------|------|
| 加密多台包粘贴导入 | 「粘贴 URI」解密 `nbvpn-enc:…` 后**只取第一台**（添加流返回单个 profile）；多台请用导出的 JSON 文件逐台导入，或分多次同步 |
| 扫码 `nbvpn-enc` | 相机扫码路径按明文 `nbvpn:` URI 解析，**不**提示口令解密加密包；请用粘贴 URI / 文件 |
| NFC / 蓝牙直连同步 | 未实现；跨设备用系统分享加密文件或加密 QR |

切换服务器：`b18be0a` 已在 main（disconnect → 等待 → connect + epoch），见 `test/app_controller_switch_test.dart`。

