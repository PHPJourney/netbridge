// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '网桥 VPN';

  @override
  String get settings => '设置';

  @override
  String get settingsTitle => '设置';

  @override
  String get killSwitch => 'Kill Switch';

  @override
  String get killSwitchSubtitleReal => '开启后，VPN 断开时将尝试阻止流量泄漏（视系统能力；完整阻断因平台而异）。';

  @override
  String get killSwitchSubtitleStub => '当前为模拟隧道，Kill Switch 仅保存偏好，不会真正阻断流量。';

  @override
  String get tunnelCapability => '隧道能力';

  @override
  String get tunnelStubSuffix => '（Stub ≠ 生产就绪）';

  @override
  String get tunnelAppleLinkedNote =>
      'WGExtension 已嵌入。Debug 可 Personal Team 编过；真 Packet Tunnel / 分发需付费 Apple Developer（NE）、Provisioning，且须接入 WireGuardKit。Personal Team 无法激活 NE。公证后才能较稳妥给别人用。';

  @override
  String get cantConnectTitle => '连不上节点时';

  @override
  String get cantConnectBody =>
      '检查 endpoint、UDP 51820（主机防火墙 + 云安全组），并用最新 nbvpn show 重新导入。';

  @override
  String get language => '语言';

  @override
  String get languageSystem => '跟随系统';

  @override
  String get languageChinese => '中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get aboutSection => '关于';

  @override
  String versionLabel(String version) {
    return '版本 $version';
  }

  @override
  String get officialWebsite => '官方网站';

  @override
  String get termsOfService => '用户协议';

  @override
  String get privacyPolicy => '隐私政策';

  @override
  String get responsibilityOneLiner => '去中心化自建节点工具——无官方节点、无需账号登录。';

  @override
  String get partnersTitle => '合作方';

  @override
  String get partnersBody => '可选提及：TradeMind / TM Open Platform。';

  @override
  String get aboutDetails => '关于与责任说明';

  @override
  String get aboutDetailsSubtitle => '去中心化说明与用户责任';

  @override
  String get aboutDialogTitle => '关于 网桥 VPN';

  @override
  String get aboutBody =>
      '网桥 VPN 是去中心化的自建节点工具。本产品不提供公共 VPN 节点，也不要求账号登录。\n\n节点部署在您的服务器上。出口网络与合法使用责任由您自行承担。\n\n连接信息（URI / 二维码 / 配置文件）等同于访问密钥，请勿公开发布。\n\n自建节点导入：\n1. 服务器：nbvpn show --uri（或扫 /var/lib/nbvpn/peers/*.png）\n2. 本应用：粘贴 URI / 扫码 / 导入 .nbvpn.json\n3. 若连不上：确认云安全组与主机防火墙已放行 UDP 51820，且 endpoint 为公网地址\n\n平台能力：\n• Android：真实 WireGuard 隧道（需系统 VPN 授权）\n• iOS/macOS：工程已嵌入 WGExtension；真连需付费 Apple Developer（Network Extension + App Group + 签名）。Personal Team 往往编过但无法激活 Packet Tunnel。打包给别人用还需公证/合适的分发方式。\n• Windows：需管理员权限；Kill Switch 未做系统防火墙级阻断';

  @override
  String get close => '关闭';

  @override
  String versionFooter(String version) {
    return '版本 $version · 无账号 · 无内置服务器';
  }

  @override
  String get openLinkFailed => '无法打开链接';

  @override
  String get emptyTitle => '还没有服务器';

  @override
  String get emptyBody => '从你的节点粘贴 URI、导入配置文件或扫描二维码添加。不会自动连接任何官方节点。';

  @override
  String get addServer => '添加服务器';

  @override
  String alreadyAdded(String name) {
    return '已添加「$name」';
  }

  @override
  String get added => '已添加';

  @override
  String get rename => '重命名';

  @override
  String get localDisplayName => '本地显示名';

  @override
  String get cancel => '取消';

  @override
  String get save => '保存';

  @override
  String get deleteServer => '删除服务器';

  @override
  String deleteConfirmConnected(String name) {
    return '删除后需重新导入才能连接。当前正在连接，将先断开。确定删除「$name」？';
  }

  @override
  String deleteConfirm(String name) {
    return '删除后需重新导入才能连接。确定删除「$name」？';
  }

  @override
  String get delete => '删除';

  @override
  String get copiedError => '已复制错误信息';

  @override
  String get connect => '连接';

  @override
  String get disconnect => '断开';

  @override
  String get statusDisconnected => '未连接';

  @override
  String get statusConnecting => '连接中';

  @override
  String get statusConnected => '已连接';

  @override
  String get statusReconnecting => '重连中';

  @override
  String get statusError => '连接错误';

  @override
  String statusConnectedDetail(String name) {
    return '已连接 · $name';
  }

  @override
  String statusConnectingDetail(String name) {
    return '正在连接 $name…';
  }

  @override
  String get statusReconnectingDetail => '网络中断，正在重连…';

  @override
  String get statusErrorFallback => '连接失败';

  @override
  String get copyError => '复制错误';

  @override
  String get retry => '重试';

  @override
  String get addMethodTitle => '添加服务器';

  @override
  String get chooseImportMethod => '选择导入方式';

  @override
  String get noOfficialNodes => '不会连接任何官方节点。配置由你从自建服务器导入。';

  @override
  String get pasteUri => '粘贴 URI / JSON';

  @override
  String get pasteUriSubtitle => '明文 nbvpn: 或加密 nbvpn-enc: / 加密 JSON';

  @override
  String get importFile => '导入文件';

  @override
  String get importFileSubtitle => '明文 .nbvpn.json 或加密 .nbvpn.enc.json';

  @override
  String get scanQr => '扫描二维码';

  @override
  String get scanQrSubtitleMobile => '支持明文 nbvpn: 与加密 nbvpn-enc:（需口令）';

  @override
  String get scanQrSubtitleDesktop => '桌面端请改用粘贴 URI 或导入文件';

  @override
  String get usePasteUriInstead => '改用粘贴 URI';

  @override
  String get cannotReadFile => '无法读取文件内容';

  @override
  String get secretWarning =>
      '连接信息包含访问密钥。仅从你信任的服务器获取。URI / 二维码 / 配置文件等同于密钥，请勿公开传播。';

  @override
  String get longPressCopy => '可长按选择复制';

  @override
  String get reenter => '重新输入';

  @override
  String get pasteUriTitle => '粘贴 URI';

  @override
  String get pasteUriHint => 'nbvpn:1?… / nbvpn-enc:1?… / JSON';

  @override
  String get pasteUriHelper => '支持明文 URI、加密 URI/JSON（会提示输入口令）；自动忽略多余换行与引号';

  @override
  String get pasteFromClipboard => '从剪贴板粘贴';

  @override
  String get validateContinue => '校验并继续';

  @override
  String get confirmAddTitle => '确认添加';

  @override
  String get endpointLooksBad =>
      '节点 endpoint 看起来不可达（空或 0.0.0.0）。请在服务器执行 nbvpn config set endpoint <公网IP或域名> 后重新导出 URI。';

  @override
  String get localNameHelper => '仅保存在本机，不会回写服务器';

  @override
  String get labelNode => '节点';

  @override
  String get labelAddress => '地址';

  @override
  String get labelDns => 'DNS';

  @override
  String get confirmSecretHint => '连接信息包含访问密钥。仅从你信任的服务器获取。';

  @override
  String get add => '添加';

  @override
  String get edit => '编辑';

  @override
  String get editServer => '编辑服务器';

  @override
  String get export => '导出';

  @override
  String get sync => '同步';

  @override
  String get share => '分享';

  @override
  String get saved => '已保存';

  @override
  String get profileName => '配置名称';

  @override
  String get labelEndpoint => 'Endpoint';

  @override
  String get labelAllowedIps => 'Allowed IPs';

  @override
  String get labelMtu => 'MTU';

  @override
  String get labelKeepalive => 'Keepalive';

  @override
  String get labelServerPublicKey => '服务器公钥';

  @override
  String get labelPrivateKey => '客户端私钥';

  @override
  String get labelPresharedKey => '预共享密钥（可选）';

  @override
  String get revealPrivateKeyTitle => '显示私钥？';

  @override
  String get revealPrivateKeyBody => '私钥等同完整访问权限。请仅在可信屏幕上查看。';

  @override
  String get reveal => '显示';

  @override
  String get hide => '隐藏';

  @override
  String get editKeysLockedHint => '密钥字段不可在此编辑。如需迁移请使用「导出备份」。';

  @override
  String get keysConfigured => '密钥已配置';

  @override
  String get keysConfiguredSubtitle => '客户端私钥与服务器公钥已安全存储，不在此显示';

  @override
  String get exportBackup => '导出备份（含密钥）';

  @override
  String get exportBackupTitle => '导出备份（含密钥）';

  @override
  String get exportBackupBody =>
      '备份文件包含完整私钥，等同账户密码。仅用于本机备份或可信迁移，切勿发到微信/邮件等外部渠道。';

  @override
  String get exportBackupHint =>
      '本机备份专用——明文 JSON/conf，含私钥。对外分享请用「分享」里的加密二维码/文件。';

  @override
  String get nearFieldSyncTitle => '近场同步';

  @override
  String get nearFieldSyncHint => 'NFC 为明文短 URI（无口令）；蓝牙可选加密后再通过系统分享发送。';

  @override
  String get syncViaNfcPlainSubtitle => '写入明文 nbvpn: URI（无口令，单台）';

  @override
  String get syncViaBluetooth => '蓝牙 / 系统分享';

  @override
  String get syncViaBluetoothSubtitle => '通过系统分享面板发送到蓝牙 / 附近设备';

  @override
  String get bluetoothUsePassword => '蓝牙分享时加密';

  @override
  String get bluetoothUsePasswordSubtitle =>
      '关闭 = 明文 URI 文件；开启 = 加密 JSON（接收端需口令）';

  @override
  String get encryptedShareTitle => '加密分享';

  @override
  String get encryptedShareHint => '用于微信/截图等外部渠道——必须设置口令，不含明文私钥 JSON';

  @override
  String get shareEncryptedFile => '加密文件';

  @override
  String get shareEncryptedFileSubtitle => '口令加密的 .nbvpn.enc.json';

  @override
  String get importPassphraseTitle => '输入解密口令';

  @override
  String get importPassphraseBody => '检测到加密配置。请输入分享时设置的口令。';

  @override
  String get importMethodsHint => '以下方式均支持明文与加密配置；加密内容会提示输入口令。多台配置将一次性全部导入。';

  @override
  String get importViaNfc => 'NFC 读取';

  @override
  String get importViaNfcSubtitle => '贴近标签读取明文 nbvpn: URI';

  @override
  String get importViaNfcBody =>
      '将含 NetBridge 配置的 NFC 标签贴近手机背面。标签内容为明文 nbvpn: URI，无需口令。';

  @override
  String get nfcStartRead => '开始读取 NFC 标签';

  @override
  String get nfcReadEmpty => '标签中未找到有效配置内容';

  @override
  String get importViaBluetooth => '蓝牙接收';

  @override
  String get importViaBluetoothSubtitle => '选择通过蓝牙收到的配置文件';

  @override
  String get importViaBluetoothBody =>
      '请让对方在「同步 → 蓝牙」发送配置。收到文件后，点击下方按钮从下载目录选择 .txt / .json 文件。加密文件需输入口令。';

  @override
  String get importViaBluetoothDesktop => '桌面端请使用「导入文件」选择收到的配置文件。';

  @override
  String get importBluetoothPickFile => '选择已接收的文件';

  @override
  String get nfcTooLargePlainBody => '配置过长，无法写入 NFC 标签。请逐台同步，或改用蓝牙/加密分享。';

  @override
  String importBatchTitle(int count) {
    return '导入 $count 台服务器？';
  }

  @override
  String get importBatchBody => '将添加以下服务器（已存在的会自动跳过）：';

  @override
  String importBatchResult(int added, int skipped) {
    return '已添加 $added 台，跳过 $skipped 台（重复）';
  }

  @override
  String get torchToggleFailed => '无法切换闪光灯';

  @override
  String get torchOn => '打开闪光灯';

  @override
  String get torchOff => '关闭闪光灯';

  @override
  String get qrGalleryNoCode => '图片中未识别到二维码';

  @override
  String get qrGalleryFailed => '无法从图片识别二维码';

  @override
  String get scanPasteEmpty => '请粘贴 nbvpn: 或 nbvpn-enc: 链接';

  @override
  String get scanPasteHint => '或粘贴 nbvpn: / nbvpn-enc: 链接';

  @override
  String get scanQrCameraHint => '支持明文与加密二维码；加密码扫到后会提示输入口令';

  @override
  String get scanFromGallery => '从相册选图';

  @override
  String cameraOpenFailed(String code) {
    return '无法打开相机：$code\n请允许相机权限，或改用相册/粘贴。';
  }

  @override
  String get exportSecretTitle => '导出含密钥';

  @override
  String get exportSecretBody => '导出文件包含私钥——等同密码。请勿公开发布。';

  @override
  String get exportServersTitle => '导出服务器';

  @override
  String get exportAlsoWireGuard => 'Also export WireGuard .conf';

  @override
  String get exportWireGuard => '导出 WireGuard';

  @override
  String get exportFailed => '导出失败';

  @override
  String get selectAll => '全选';

  @override
  String get selectNone => '清空';

  @override
  String get continueAction => '继续';

  @override
  String get server => '服务器';

  @override
  String get syncTitle => '近场同步';

  @override
  String get syncPassphraseTitle => '加密口令';

  @override
  String get syncPassphraseBody => '请设置接收端需要输入的口令。配置将使用 AES-GCM 加密。';

  @override
  String get passphrase => '口令';

  @override
  String get syncViaQr => '加密二维码';

  @override
  String get syncViaQrSubtitle => '在其它设备扫描（或分享图片）';

  @override
  String get syncViaFile => '加密文件分享';

  @override
  String get syncViaFileSubtitle => '系统分享面板——可跨手机传输';

  @override
  String get syncViaNfc => 'NFC 标签';

  @override
  String get syncViaNfcSubtitle => '写入明文 nbvpn: URI（无口令）';

  @override
  String get syncBluetoothNote => '未内置蓝牙点对点同步；请通过系统分享 / Wi‑Fi Direct 传文件。';

  @override
  String get syncFailed => '同步失败';

  @override
  String get nfcUnsupported => '本设备不支持 NFC';

  @override
  String get nfcTooLargeTitle => '载荷过大，无法写入 NFC';

  @override
  String get nfcTooLargeBody => '加密配置超过 NFC 实用长度限制。请改用文件分享或二维码。';

  @override
  String get nfcHoldTag => '请将 NFC 标签靠近设备…';

  @override
  String get nfcWriteOk => '已写入 NFC 标签';

  @override
  String get nfcFailed => 'NFC 失败';

  @override
  String get encryptedQrTitle => '加密二维码';

  @override
  String get encryptedQrHint => '接收方需使用相同口令解密。';

  @override
  String get qrTooDenseHint => '二维码较密——扫码失败时请改用文件分享。';

  @override
  String get qrEncodeFailed => '无法生成二维码';

  @override
  String get shareEncryptedQr => '加密二维码';

  @override
  String get shareEncryptedQrSubtitle => '口令加密的服务器配置';

  @override
  String get shareApp => '分享应用';

  @override
  String get shareAppSubtitle => '下载页 / 商店链接';

  @override
  String shareAppConfirm(String url) {
    return '分享下载链接？\n$url';
  }

  @override
  String get shareAppMessage => '下载网桥 VPN：';
}
