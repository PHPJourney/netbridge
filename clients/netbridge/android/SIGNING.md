# Android APK 签名（Release）

## 重要澄清

**GitHub Releases 上的 APK ≠ Android release 证书。**

- 商店/网页下载的是「发布渠道产物」，与 Android 是否用 **upload/release keystore** 无关。
- 若 CI/本机用 **debug.keystore** 打 `--release` APK，不同机器的 debug 证书不同 → 用户升级会报「应用未安装 / 签名不一致」。
- 面向用户分发的 APK 必须长期固定同一把 **upload-keystore**（或 Play App Signing 的 upload 密钥）。

| 场景 | 签名 | 覆盖安装 |
|------|------|----------|
| 本机 `flutter run` / 无 keystore 的侧载试装 | debug（fallback） | 仅同机 debug 可升级 |
| GitHub Release / 商店正式包 | release（upload-keystore） | 同证书可覆盖升级 |

## 一次性：生成本地 upload-keystore

```bash
cd clients/netbridge/android
keytool -genkey -v \
  -keystore upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

按提示设置 **keystore 密码**、**key 密码**（可相同）、组织信息。  
**妥善备份** `upload-keystore.jks` 与密码；丢失后无法用同一签名覆盖升级，只能让用户卸载重装。

## 本地：`key.properties`（勿提交）

在 `clients/netbridge/android/key.properties`（已 gitignore）：

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=upload-keystore.jks
```

- `storeFile` 相对 `android/` 目录（与 `key.properties` 同级）。
- 存在该文件时，`app/build.gradle.kts` 的 **release** 使用 release signingConfig。
- **不存在**时 fallback **debug** 签名，并在 Gradle 日志中警告（便于本机试装 / 无 secrets 的 CI）。

本地构建：

```bash
cd clients/netbridge
flutter build apk --release --split-per-abi
```

## CI：GitHub Secrets

在仓库 **Settings → Secrets and variables → Actions** 配置：

| Secret | 说明 |
|--------|------|
| `ANDROID_KEYSTORE_BASE64` | `base64 -i upload-keystore.jks \| pbcopy`（或 `base64 -w0`） |
| `ANDROID_KEYSTORE_PASSWORD` | keystore 密码 |
| `ANDROID_KEY_ALIAS` | 通常为 `upload` |
| `ANDROID_KEY_PASSWORD` | key 密码 |

`.github/workflows/build-clients.yml` 在上述 secrets **齐全** 时写入 `key.properties` 并用 release 签；**缺失**时仍打 debug 签（侧载/试装），workflow 内有注释说明。

编码示例（macOS）：

```bash
base64 -i clients/netbridge/android/upload-keystore.jks | pbcopy
# 粘贴到 ANDROID_KEYSTORE_BASE64
```

## 用户侧：签名变更时

- **临时**：卸载旧版再装新包（会清本地数据）。
- **长期**：全渠道（CI + 本机发版）统一同一把 upload-keystore，之后可覆盖安装升级。

切勿将 `*.jks` / `*.keystore` / `key.properties` 提交到 git。
