// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'NetBridge VPN';

  @override
  String get settings => 'Settings';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get killSwitch => 'Kill Switch';

  @override
  String get killSwitchSubtitleReal =>
      'When on, the app will try to block traffic leaks if the VPN drops (depends on the OS; full blocking varies by platform).';

  @override
  String get killSwitchSubtitleStub =>
      'Stub tunnel only — Kill Switch preference is saved but does not block traffic.';

  @override
  String get tunnelCapability => 'Tunnel capability';

  @override
  String get tunnelStubSuffix => '(Stub ≠ production-ready)';

  @override
  String get tunnelAppleLinkedNote =>
      'WGExtension is embedded. Debug builds can sign with a Personal Team; real Packet Tunnel / distribution need a paid Apple Developer account (NE), provisioning, and WireGuardKit. Personal Team cannot activate NE. Notarization is typically required before sharing builds.';

  @override
  String get cantConnectTitle => 'Can\'t reach a node?';

  @override
  String get cantConnectBody =>
      'Check endpoint, UDP 51820 (host firewall + cloud security group), and re-import with a fresh nbvpn show.';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System';

  @override
  String get languageChinese => '中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get aboutSection => 'About';

  @override
  String versionLabel(String version) {
    return 'Version $version';
  }

  @override
  String get officialWebsite => 'Official website';

  @override
  String get termsOfService => 'Terms of Service';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get responsibilityOneLiner =>
      'Decentralized self-hosted nodes — no official VPN servers, no account required.';

  @override
  String get partnersTitle => 'Partners';

  @override
  String get partnersBody => 'Optional mention: TradeMind / TM Open Platform.';

  @override
  String get aboutDetails => 'About & responsibility';

  @override
  String get aboutDetailsSubtitle => 'Decentralization and user responsibility';

  @override
  String get aboutDialogTitle => 'About NetBridge VPN';

  @override
  String get aboutBody =>
      'NetBridge VPN is a decentralized self-hosted node tool. This product does not provide public VPN nodes and does not require login.\n\nNodes run on your servers. You are responsible for egress network use and lawful use.\n\nConnection info (URI / QR / config) is an access secret — do not publish it.\n\nSelf-hosted import:\n1. Server: nbvpn show --uri (or scan /var/lib/nbvpn/peers/*.png)\n2. App: paste URI / scan / import .nbvpn.json\n3. If it fails: allow UDP 51820 on cloud SG + host firewall; endpoint must be public\n\nPlatform notes:\n• Android: real WireGuard (system VPN consent)\n• iOS/macOS: WGExtension is embedded; real tunnels need a paid Apple Developer account (Network Extension + App Group + signing). A Personal Team often builds but cannot activate Packet Tunnel. Sharing builds also needs notarization / proper distribution.\n• Windows: admin often required; Kill Switch is not WFP-level yet';

  @override
  String get close => 'Close';

  @override
  String versionFooter(String version) {
    return 'Version $version · no account · no built-in servers';
  }

  @override
  String get openLinkFailed => 'Could not open link';

  @override
  String get emptyTitle => 'No servers yet';

  @override
  String get emptyBody =>
      'Add a node by pasting a URI, importing a config file, or scanning a QR code. The app never auto-connects to any official node.';

  @override
  String get addServer => 'Add server';

  @override
  String alreadyAdded(String name) {
    return 'Already added \"$name\"';
  }

  @override
  String get added => 'Added';

  @override
  String get rename => 'Rename';

  @override
  String get localDisplayName => 'Local display name';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get deleteServer => 'Delete server';

  @override
  String deleteConfirmConnected(String name) {
    return 'You will need to re-import to connect again. This server is active and will disconnect first. Delete \"$name\"?';
  }

  @override
  String deleteConfirm(String name) {
    return 'You will need to re-import to connect again. Delete \"$name\"?';
  }

  @override
  String get delete => 'Delete';

  @override
  String get copiedError => 'Error copied';

  @override
  String get connect => 'Connect';

  @override
  String get disconnect => 'Disconnect';

  @override
  String get statusDisconnected => 'Disconnected';

  @override
  String get statusConnecting => 'Connecting';

  @override
  String get statusConnected => 'Connected';

  @override
  String get statusReconnecting => 'Reconnecting';

  @override
  String get statusError => 'Connection error';

  @override
  String statusConnectedDetail(String name) {
    return 'Connected · $name';
  }

  @override
  String statusConnectingDetail(String name) {
    return 'Connecting to $name…';
  }

  @override
  String get statusReconnectingDetail => 'Network interrupted, reconnecting…';

  @override
  String get statusErrorFallback => 'Connection failed';

  @override
  String get copyError => 'Copy error';

  @override
  String get retry => 'Retry';

  @override
  String get addMethodTitle => 'Add server';

  @override
  String get chooseImportMethod => 'Choose import method';

  @override
  String get noOfficialNodes =>
      'Does not connect to any official node. You import config from your own server.';

  @override
  String get pasteUri => 'Paste URI';

  @override
  String get pasteUriSubtitle => 'Paste an nbvpn:1?… link';

  @override
  String get importFile => 'Import file';

  @override
  String get importFileSubtitle => 'Choose a .nbvpn.json config file';

  @override
  String get scanQr => 'Scan QR code';

  @override
  String get scanQrSubtitleMobile =>
      'Camera / gallery / paste URI on this screen';

  @override
  String get scanQrSubtitleDesktop =>
      'On desktop, paste a URI or import a file instead';

  @override
  String get usePasteUriInstead => 'Use paste URI instead';

  @override
  String get cannotReadFile => 'Could not read file contents';

  @override
  String get secretWarning =>
      'Connection info contains access secrets. Only take it from servers you trust. URI / QR / config equal a key — do not share publicly.';

  @override
  String get longPressCopy => 'Long-press to select and copy';

  @override
  String get reenter => 'Re-enter';

  @override
  String get pasteUriTitle => 'Paste URI';

  @override
  String get pasteUriHint => 'nbvpn:1?… or full .nbvpn.json text';

  @override
  String get pasteUriHelper =>
      'Ignores WARNING lines, quotes, newlines, and code fences; JSON paste also works';

  @override
  String get pasteFromClipboard => 'Paste from clipboard';

  @override
  String get validateContinue => 'Validate & continue';

  @override
  String get confirmAddTitle => 'Confirm add';

  @override
  String get endpointLooksBad =>
      'Endpoint looks unreachable (empty or 0.0.0.0). On the server run nbvpn config set endpoint <public IP or domain>, then re-export the URI.';

  @override
  String get localNameHelper =>
      'Stored on this device only; not written back to the server';

  @override
  String get labelNode => 'Node';

  @override
  String get labelAddress => 'Address';

  @override
  String get labelDns => 'DNS';

  @override
  String get confirmSecretHint =>
      'Connection info contains access secrets. Only take it from servers you trust.';

  @override
  String get add => 'Add';
}
