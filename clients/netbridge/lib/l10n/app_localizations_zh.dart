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
  String get pasteUri => '粘贴 URI';

  @override
  String get pasteUriSubtitle => '粘贴 nbvpn:1?… 链接';

  @override
  String get importFile => '导入文件';

  @override
  String get importFileSubtitle => '选择 .nbvpn.json 配置文件';

  @override
  String get scanQr => '扫描二维码';

  @override
  String get scanQrSubtitleMobile => '摄像头 / 相册选图 / 同页粘贴 URI';

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
  String get pasteUriHint => 'nbvpn:1?… 或 .nbvpn.json 全文';

  @override
  String get pasteUriHelper => '自动忽略 WARNING 行、引号、换行与代码块；也可直接粘贴 JSON';

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
}
