# OpenList 上传清单（nbvpn）

> 生成时间：2026-08-14  
> OpenList 浏览根（参考）：`http://154.37.213.245:5244/store`  
> **本表不含真实直链**。上传完成后把实际 URL / sha 回填 `apps/store/public/releases.json`（再同步 `apps/store/dist/`）。

建议目录约定：去掉 `mock/` 段，用下表「建议 OpenList 相对路径」。

---

## 上传优先级

| 优先级 | 类别 | 说明 |
|--------|------|------|
| P0 | 客户端主包 + 服务端二进制 | Store 落地页可下载 |
| P1 | 安装脚本（Linux / Windows） | `installCommand` / 文档引用 |
| P2 | 旁路产物（armv7 apk、mac zip、说明 txt） | 可选 |
| — | Windows **客户端** exe | **尚无产物**（需 Win10+ 构建） |
| — | Store 静态站 `apps/store/dist/` | 可选（落地页可另部署） |

---

## 1. 客户端（P0 / P2）

| 本地绝对路径 | 建议 OpenList 相对路径 | 用途 | 大小约 | sha256 |
|---|---|---|---|---|
| `/Users/mac/Documents/NetBridge/clients/netbridge/dist/NetBridge-android-arm64.apk` | `/store/clients/android/NetBridge-android-arm64.apk` | Android 主包（arm64，R8 slim，debug-signed release） | 27.5 MB | `a59e340d9dadd0681b38f2063e737b75fa7805e377d02795d56a1730d3cfff2f` |
| `/Users/mac/Documents/NetBridge/clients/netbridge/dist/NetBridge-android-armeabi-v7a.apk` | `/store/clients/android/NetBridge-android-armeabi-v7a.apk` | Android 32-bit（可选） | 23.3 MB | `90df7f0b00133739ede06aa50c4dd54aca7a11a3f9690f7bf280602c43dad726` |
| `/Users/mac/Documents/NetBridge/clients/netbridge/dist/NetBridge-android.apk` | `/store/clients/android/NetBridge-android.apk` | 与 arm64 同内容别名（可选） | 27.5 MB | `a59e340d9dadd0681b38f2063e737b75fa7805e377d02795d56a1730d3cfff2f` |
| `/Users/mac/Documents/NetBridge/clients/netbridge/dist/NetBridge-macOS.dmg` | `/store/clients/macos/NetBridge-macOS.dmg` | macOS 安装盘（ad-hoc，未公证） | 18.7 MB | `de040c6913fc4928e2bf029cbc9734bc1a73a6902f5f0329b9195f4643fbe9f0` |
| `/Users/mac/Documents/NetBridge/clients/netbridge/dist/NetBridge-macOS.app.zip` | `/store/clients/macos/NetBridge-macOS.app.zip` | macOS .app 压缩包（可选） | 17.1 MB | `60729d12bcd6ba3853c32b97d241ae7b6d60be28bd2554bed6864087813458b0` |
| `/Users/mac/Documents/NetBridge/clients/netbridge/dist/NetBridge-iOS.ipa` | `/store/clients/ios/NetBridge-iOS.ipa` | iOS **UNSIGNED stub**（非开发设备不可装） | 8.1 MB | `03d808fa721d0303d28a7f042d7f0c2f02e15c14221615f7fde91676f436d7a2` |

### 客户端旁路说明（可不上传）

| 本地绝对路径 | 建议路径 | 用途 |
|---|---|---|
| `/Users/mac/Documents/NetBridge/clients/netbridge/dist/NetBridge-android-arm64.apk.sha256` | `/store/clients/android/NetBridge-android-arm64.apk.sha256` | 校验和旁路文件 |
| `/Users/mac/Documents/NetBridge/clients/netbridge/dist/NetBridge-macOS.dmg.sha256` | `/store/clients/macos/NetBridge-macOS.dmg.sha256` | 同上 |
| `/Users/mac/Documents/NetBridge/clients/netbridge/dist/NetBridge-iOS.ipa.sha256` | `/store/clients/ios/NetBridge-iOS.ipa.sha256` | 同上 |
| `/Users/mac/Documents/NetBridge/clients/netbridge/dist/IOS-IPA-README.txt` | `/store/clients/ios/IOS-IPA-README.txt` | stub IPA 说明 |
| `/Users/mac/Documents/NetBridge/clients/netbridge/dist/WINDOWS-BUILD.md` | `/store/clients/windows/WINDOWS-BUILD.md` | Windows 客户端构建说明（无 exe） |
| `/Users/mac/Documents/NetBridge/clients/netbridge/dist/PACKAGE-STATUS.txt` | `/store/clients/PACKAGE-STATUS.txt` | 打包状态摘要 |
| `/Users/mac/Documents/NetBridge/clients/netbridge/dist/README.txt` | `/store/clients/README.txt` | 产物说明 |

### Windows 客户端（缺失）

| 状态 | 说明 |
|------|------|
| **无本地产物** | Mac 无法 `flutter build windows`；测试机 `154.36.178.124` 为 **Server 2012 R2 (6.3.9600)**，不具备 Flutter Windows / VS2022 构建环境 |
| 需要 | **Windows 10/11 或 Server 2019+** + Visual Studio 2022 C++ + Flutter desktop；见 `clients/netbridge/dist/WINDOWS-BUILD.md` |
| 期望上传名 | `/store/clients/windows/NetBridge-windows.exe` + `/store/clients/windows/NetBridge-windows-portable.zip` |

---

## 2. 服务端二进制（P0）

| 本地绝对路径 | 建议 OpenList 相对路径 | 用途 | 大小约 | sha256 |
|---|---|---|---|---|
| `/Users/mac/Documents/NetBridge/server/nbvpn/dist/nbvpn-linux-amd64` | `/store/servers/linux/nbvpn-linux-amd64` | Linux x86_64 节点（Debian/Ubuntu/CentOS/RHEL 共用） | 8.3 MB | `66016b667c645785fc2ff26fff0ebfc469edd649c6a7e5c219abea5ecf922f88` |
| `/Users/mac/Documents/NetBridge/server/nbvpn/dist/nbvpn-linux-arm64` | `/store/servers/linux/nbvpn-linux-arm64` | Linux arm64 节点（可选） | 5.4 MB | `d9ac158113ab61401b4215ca9597a35b380df1ff07f3e029758e1cf4bec3a0ad` |
| `/Users/mac/Documents/NetBridge/server/nbvpn/dist/nbvpn-windows-amd64.exe` | `/store/servers/windows/nbvpn-windows-amd64.exe` | Windows **10+ / Server 2016+** 节点（Go 1.22 Docker） | 5.4 MB | `da9e7cb41146329efdd7ba90a09ddde46e8e7fc226568926b6e0842185bc2068` |
| `/Users/mac/Documents/NetBridge/server/nbvpn/dist/nbvpn-windows-amd64-win2012.exe` | `/store/servers/windows/nbvpn-windows-amd64-win2012.exe` | **Server 2012 R2** 节点（Go 1.20 Docker；必传给 2012 测试机） | 5.3 MB | `50d95ea105af67a303e8aefa2592f3dbb7494efecafaff298b008a2120c545e0` |

旁路 `.sha256`（可选）：

| 本地绝对路径 | 建议路径 |
|---|---|
| `/Users/mac/Documents/NetBridge/server/nbvpn/dist/nbvpn-linux-amd64.sha256` | `/store/servers/linux/nbvpn-linux-amd64.sha256` |
| `/Users/mac/Documents/NetBridge/server/nbvpn/dist/nbvpn-linux-arm64.sha256` | `/store/servers/linux/nbvpn-linux-arm64.sha256` |
| `/Users/mac/Documents/NetBridge/server/nbvpn/dist/nbvpn-windows-amd64.exe.sha256` | `/store/servers/windows/nbvpn-windows-amd64.exe.sha256` |
| `/Users/mac/Documents/NetBridge/server/nbvpn/dist/nbvpn-windows-amd64-win2012.exe.sha256` | `/store/servers/windows/nbvpn-windows-amd64-win2012.exe.sha256` |

> Store `releases.json` 里 Debian/Ubuntu/CentOS/RHEL 四条可共用同一 `nbvpn-linux-amd64` 直链；Windows Win10+ 用 `nbvpn-windows-amd64.exe`，**2012 R2 必须用 `nbvpn-windows-amd64-win2012.exe`**（Go 1.21+ 二进制无法运行）。  
> 构建：`./server/nbvpn/scripts/build-windows-docker.sh all`

---

## 3. 安装脚本与文档（P1）

| 本地绝对路径 | 建议 OpenList 相对路径 | 用途 | sha256 |
|---|---|---|---|
| `/Users/mac/Documents/NetBridge/server/install/install.sh` | `/store/servers/linux/install.sh` | 通用 Linux 入口 | `d11149fba7e1b3c7beb3474de5b880a278bc83aceff387ac227eb9be05f09345` |
| `/Users/mac/Documents/NetBridge/server/install/debian.sh` | `/store/servers/debian/debian.sh` | Debian 入口（→ deb-family） | `23103d5c5e26daef312b915467bbcef150c2e8e1d0ac18cbf36750ffc594ff2a` |
| `/Users/mac/Documents/NetBridge/server/install/ubuntu.sh` | `/store/servers/ubuntu/ubuntu.sh` | Ubuntu 入口 | `8fb1080d7d647335c97a4ad2513706f1a74f4b072509242906c4f099a4577a50` |
| `/Users/mac/Documents/NetBridge/server/install/centos.sh` | `/store/servers/centos/centos.sh` | CentOS/Rocky/Alma 入口 | `26419f4619e38da9f3340fb2c90c7b40b051b85ae772909a327a0960db2db208` |
| `/Users/mac/Documents/NetBridge/server/install/rhel.sh` | `/store/servers/rhel/rhel.sh` | RHEL 入口 | `8de545e981b14b1f4b80b4cf308c10c39b40ee8a2654167a2e9d59db3ea97af1` |
| `/Users/mac/Documents/NetBridge/server/install/deb-family.sh` | `/store/servers/linux/deb-family.sh` | deb 系实现（脚本依赖） | `9c2c3f269419e45a4654cb57fc841723506908011f84011d58e2261c694878f2` |
| `/Users/mac/Documents/NetBridge/server/install/rhel-family.sh` | `/store/servers/linux/rhel-family.sh` | rhel 系实现 | `b9bc7a537ae471f77aa8d48a58a4c9b05e81b1ecefb9542b4031fbf934493c87` |
| `/Users/mac/Documents/NetBridge/server/install/_common.sh` | `/store/servers/linux/_common.sh` | 公共函数 | `00fdfae1edd906985cfba62edd366d6bb2f35eeb607bfe7f6d6bf86cc1345fbf` |
| `/Users/mac/Documents/NetBridge/server/install/smoke-verify.sh` | `/store/servers/linux/smoke-verify.sh` | 安装后冒烟 | `add1cbf90cc0d0a54b199a3bd7990fa14f237df09ec77af067eea60da6807cb3` |
| `/Users/mac/Documents/NetBridge/server/install/FIREWALL.md` | `/store/servers/linux/FIREWALL.md` | 防火墙说明 | `4507bff68d3bd604ff53f54f39fb89abbee9dceab9dafe3a64fd3c11eca36151` |
| `/Users/mac/Documents/NetBridge/server/install/windows/install.ps1` | `/store/servers/windows/install.ps1` | Windows 安装脚本（PS4 / 2012 安全） | （随 main 更新后重算 sha） |
| `/Users/mac/Documents/NetBridge/server/install/windows/WINDOWS.md` | `/store/servers/windows/WINDOWS.md` | Windows 节点文档（Setup.exe + 2012） | （随 main 更新后重算 sha） |
| GitHub Release `NetBridge-nbvpn-Setup.exe` | `/store/servers/windows/NetBridge-nbvpn-Setup.exe` | **首选** 服务端安装包 | 下一 tag CI 产出 |
| GitHub Release `NetBridge-windows-setup.exe` | `/store/clients/windows/NetBridge-windows-setup.exe` | **首选** 客户端安装包 | 下一 tag CI 产出 |
| GitHub Release `NetBridge-windows-portable.zip` | `/store/clients/windows/NetBridge-windows-portable.zip` | 客户端便携 zip（次选） | 已有 / 续传 |

> `curl … \| bash` 类 `installCommand` 至少要保证入口脚本 + `_common.sh` + `*-family.sh` + 对应二进制同目录或脚本内 `NBVPN_BINARY_URL` 可下。

---

## 4. Store 静态站（可选 P2）

落地页源构建产物目录：`/Users/mac/Documents/NetBridge/apps/store/dist/`

| 建议 | 说明 |
|------|------|
| 可整体上传到独立站点目录（非 `/store` 包仓） | `index.html`、`assets/`、`releases.json`、`privacy.html`、`terms.html`、图标等 |
| **不要**把安装包塞进 store dist | 包仓与落地页分离；`releases.json` 只存直链 |

---

## 5. 最小必传清单（复制勾选）

```
[ ] /store/clients/android/NetBridge-android-arm64.apk
[ ] /store/clients/windows/NetBridge-windows.exe
[ ] （不分发）macOS — 源码本机运行；勿上传 DMG / app.zip
[ ] （暂不分发）iOS — CI 无签名 IPA
[ ] /store/servers/linux/nbvpn-linux-amd64
[ ] /store/servers/windows/nbvpn-windows-amd64.exe          # Win10+
[ ] /store/servers/windows/nbvpn-windows-amd64-win2012.exe   # Server 2012 R2（Go 1.20）
[ ] /store/servers/debian/debian.sh (+ ubuntu/centos/rhel 入口)
[ ] /store/servers/linux/{install.sh,_common.sh,deb-family.sh,rhel-family.sh}
[ ] /store/servers/windows/install.ps1
[ ] /store/servers/windows/WINDOWS.md
```

上传后请提供各文件的 **OpenList 直链**（或 `/d/...` 路径），以便更新 `apps/store/public/releases.json`。

---

## 6. Windows 编译 / 测试机备注（2026-08-14）

| 项 | 结果 |
|----|------|
| 服务端 Docker 双产物 | **OK** — `build-windows-docker.sh all` → `nbvpn-windows-amd64.exe`（golang:1.22.10）+ `nbvpn-windows-amd64-win2012.exe`（golang:1.20.14） |
| 2012 兼容性 | Go 1.21+ 会「此应用无法在你的电脑上运行」；2012 必须用 **win2012** 产物 |
| 客户端 Flutter Windows | **未产出**；Linux Docker **不能**编 Flutter Windows；需 Win10+ 机；**2012 不能跑客户端** |
| 测试机 `154.36.178.124` | Server 2012 R2；部署建议：`C:\NetBridge\deploy\` 放 `install.ps1` + `nbvpn-windows-amd64-win2012.exe` |
| 远程 `nbvpn install` | 隧道/WG 仍可能受限（官方 WG/Wintun 对 2012 支持存疑） |
| 密码 | 仅 bootstrap；**勿写入仓库**；建议登录后轮换 |


---

## 7. GitHub Actions / Releases（推荐主路径，2026-08-14）

OpenList 仍可作为镜像；**默认分发改为 GitHub Releases + Pages**。

| 项 | 说明 |
|----|------|
| Store UI | https://phpjourney.github.io/netbridge/ （workflow `pages-store.yml`） |
| 产物 | Actions artifacts；打 `v*` tag 后挂到 GitHub Release |
| 服务端 workflow | `build-server.yml` → `nbvpn-linux-amd64` / `arm64` / `nbvpn-windows-amd64.exe` / `nbvpn-windows-amd64-win2012.exe` + install zip |
| 客户端 workflow | `build-clients.yml` → Android APK、Windows exe；**macOS / iOS 跳过分发**（仅 skip note） |
| `releases.json` | 已改为 `…/releases/latest/download/<filename>` 占位；首个 Release 发布后更新 sha256 |

本地大文件不必上传 OpenList 也可完成分发：在 Actions 下载 artifact，或使用 Release 直链。
