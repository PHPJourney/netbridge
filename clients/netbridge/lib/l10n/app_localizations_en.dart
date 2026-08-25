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
  String get fullTunnelCarTitle => 'Car / local network issues?';

  @override
  String get fullTunnelCarHint =>
      'If car hotspot, Bluetooth, or LAN devices break while connected, turn on automatic split tunnel below; public internet still uses the VPN. Reconnect after changing.';

  @override
  String get splitTunnelTitle => 'Automatic split tunnel';

  @override
  String get splitTunnelSubtitle =>
      'Optional. When on, private networks (10.x, 192.168.x, link-local, etc.) bypass the VPN; public internet still uses the tunnel. Default off (full tunnel). Reconnect to apply.';

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
  String get statusVerifyingHandshake => 'Verifying handshake…';

  @override
  String get handshakeFailedError =>
      'Handshake failed. The provider may block UDP forwarding, or server NAT may be misconfigured.';

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
  String get pasteUri => 'Paste URI / JSON';

  @override
  String get pasteUriSubtitle =>
      'Plain nbvpn: or encrypted nbvpn-enc: / encrypted JSON';

  @override
  String get importFile => 'Import file';

  @override
  String get importFileSubtitle =>
      'Plain .nbvpn.json or encrypted .nbvpn.enc.json';

  @override
  String get scanQr => 'Scan QR code';

  @override
  String get scanQrSubtitleMobile =>
      'Plain nbvpn: and encrypted nbvpn-enc: (passphrase required)';

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
  String get pasteUriHint => 'nbvpn:1?… / nbvpn-enc:1?… / JSON';

  @override
  String get pasteUriHelper =>
      'Supports plain URI and encrypted URI/JSON (passphrase prompt). Ignores extra whitespace and quotes.';

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

  @override
  String get edit => 'Edit';

  @override
  String get editServer => 'Edit server';

  @override
  String get export => 'Export';

  @override
  String get sync => 'Sync';

  @override
  String get share => 'Share';

  @override
  String get saved => 'Saved';

  @override
  String get profileName => 'Profile name';

  @override
  String get labelEndpoint => 'Endpoint';

  @override
  String get labelEndpointV6 => 'IPv6 endpoint';

  @override
  String get endpointV6Helper =>
      'Optional. Use [ipv6]:port form, e.g. [2001:db8::1]:51820. From server: nbvpn config set endpoint-v6 …';

  @override
  String get ipv6EnabledTitle => 'Use IPv6 endpoint';

  @override
  String get ipv6EnabledOnHint =>
      'Connect via IPv6 endpoint (WireGuard uses one Endpoint at a time)';

  @override
  String get ipv6EnabledOffHint =>
      'IPv6 endpoint saved but disabled — connecting via primary endpoint';

  @override
  String get ipv6EnabledNeedEndpointHint =>
      'Set an IPv6 endpoint first to enable';

  @override
  String get ipv6StatusLabel => 'IPv6';

  @override
  String get ipv6StatusEnabled => 'IPv6 enabled';

  @override
  String get ipv6StatusDisabled => 'IPv6 disabled';

  @override
  String get labelAllowedIps => 'Allowed IPs';

  @override
  String get allowedIpsHelper =>
      'Default 0.0.0.0/0 is full tunnel. Enable Settings → Automatic split tunnel to bypass private LAN, or set e.g. 10.8.0.0/24 here to route only the VPN subnet.';

  @override
  String get labelMtu => 'MTU';

  @override
  String get labelKeepalive => 'Keepalive';

  @override
  String get labelServerPublicKey => 'Server public key';

  @override
  String get labelPrivateKey => 'Client private key';

  @override
  String get labelPresharedKey => 'Preshared key (optional)';

  @override
  String get revealPrivateKeyTitle => 'Show private key?';

  @override
  String get revealPrivateKeyBody =>
      'The private key is equivalent to full access. Only reveal on a trusted screen.';

  @override
  String get reveal => 'Reveal';

  @override
  String get hide => 'Hide';

  @override
  String get editKeysLockedHint =>
      'Key fields cannot be edited here. Use Export backup to migrate keys.';

  @override
  String get keysConfigured => 'Keys configured';

  @override
  String get keysConfiguredSubtitle =>
      'Client private key and server public key are stored securely and not shown here';

  @override
  String get exportBackup => 'Export backup (with keys)';

  @override
  String get exportBackupTitle => 'Export backup (with keys)';

  @override
  String get exportBackupBody =>
      'Backup files contain your full private key — equivalent to a password. For trusted local backup or migration only. Never send to WeChat, email, or other public channels.';

  @override
  String get exportBackupHint =>
      'Local backup only — cleartext JSON/conf with private keys. For external sharing use encrypted QR/file under Share.';

  @override
  String get nearFieldSyncTitle => 'Near-field sync';

  @override
  String get nearFieldSyncHint =>
      'NFC uses a short plain URI (no passphrase). Bluetooth can optionally encrypt before sending via the system share sheet.';

  @override
  String get syncViaNfcPlainSubtitle =>
      'Write plain nbvpn: URI (no passphrase, one server)';

  @override
  String get syncViaBluetooth => 'Bluetooth / system share';

  @override
  String get syncViaBluetoothSubtitle =>
      'Send via system share sheet to Bluetooth / nearby devices';

  @override
  String get bluetoothUsePassword => 'Encrypt for Bluetooth share';

  @override
  String get bluetoothUsePasswordSubtitle =>
      'Off = plain URI file; On = encrypted JSON (recipient needs passphrase)';

  @override
  String get encryptedShareTitle => 'Encrypted share';

  @override
  String get encryptedShareHint =>
      'For WeChat / screenshots — passphrase required; never plain private-key JSON';

  @override
  String get shareEncryptedFile => 'Encrypted file';

  @override
  String get shareEncryptedFileSubtitle =>
      'Passphrase-encrypted .nbvpn.enc.json';

  @override
  String get importPassphraseTitle => 'Enter decryption passphrase';

  @override
  String get importPassphraseBody =>
      'Encrypted config detected. Enter the passphrase set when sharing.';

  @override
  String get importMethodsHint =>
      'All methods below support plain and encrypted config. Encrypted content prompts for a passphrase. Multi-server packs import all entries.';

  @override
  String get importViaNfc => 'Read NFC tag';

  @override
  String get importViaNfcSubtitle => 'Tap tag to read plain nbvpn: URI';

  @override
  String get importViaNfcBody =>
      'Hold an NFC tag containing a NetBridge config near your phone. Tags store a plain nbvpn: URI — no passphrase needed.';

  @override
  String get nfcStartRead => 'Start reading NFC tag';

  @override
  String get nfcReadEmpty => 'No valid config found on the tag';

  @override
  String get importViaBluetooth => 'Bluetooth receive';

  @override
  String get importViaBluetoothSubtitle =>
      'Pick a config file received via Bluetooth';

  @override
  String get importViaBluetoothBody =>
      'Ask the sender to use Sync → Bluetooth. After receiving the file, tap below to pick the .txt / .json from Downloads. Encrypted files require a passphrase.';

  @override
  String get importViaBluetoothDesktop =>
      'On desktop, use Import file to pick the received config.';

  @override
  String get importBluetoothPickFile => 'Pick received file';

  @override
  String get nfcTooLargePlainBody =>
      'Config is too long for an NFC tag. Sync one server at a time, or use Bluetooth / encrypted share.';

  @override
  String importBatchTitle(int count) {
    return 'Import $count servers?';
  }

  @override
  String get importBatchBody =>
      'The following servers will be added (duplicates are skipped):';

  @override
  String importBatchResult(int added, int skipped) {
    return 'Added $added, skipped $skipped (duplicate)';
  }

  @override
  String get torchToggleFailed => 'Could not toggle torch';

  @override
  String get torchOn => 'Turn torch on';

  @override
  String get torchOff => 'Turn torch off';

  @override
  String get qrGalleryNoCode => 'No QR code found in the image';

  @override
  String get qrGalleryFailed => 'Could not decode QR from image';

  @override
  String get scanPasteEmpty => 'Paste an nbvpn: or nbvpn-enc: link';

  @override
  String get scanPasteHint => 'Or paste nbvpn: / nbvpn-enc: link';

  @override
  String get scanQrCameraHint =>
      'Plain and encrypted QR supported; encrypted scans prompt for passphrase';

  @override
  String get scanFromGallery => 'Pick from gallery';

  @override
  String cameraOpenFailed(String code) {
    return 'Could not open camera: $code\nAllow camera permission, or use gallery / paste.';
  }

  @override
  String get exportSecretTitle => 'Export contains secrets';

  @override
  String get exportSecretBody =>
      'Exported files include private keys — equivalent to passwords. Do not share publicly.';

  @override
  String get exportServersTitle => 'Export servers';

  @override
  String get exportAlsoWireGuard => 'Also export WireGuard .conf';

  @override
  String get exportWireGuard => 'Export WireGuard';

  @override
  String get exportFailed => 'Export failed';

  @override
  String get selectAll => 'Select all';

  @override
  String get selectNone => 'Clear';

  @override
  String get continueAction => 'Continue';

  @override
  String get server => 'Server';

  @override
  String get syncTitle => 'Near-field sync';

  @override
  String get syncPassphraseTitle => 'Encryption passphrase';

  @override
  String get syncPassphraseBody =>
      'Choose a passphrase the receiving device will need. Config is encrypted with AES-GCM.';

  @override
  String get passphrase => 'Passphrase';

  @override
  String get syncViaQr => 'Encrypted QR code';

  @override
  String get syncViaQrSubtitle =>
      'Scan on the other device (or share the image)';

  @override
  String get syncViaFile => 'Encrypted file share';

  @override
  String get syncViaFileSubtitle => 'System share sheet — works across phones';

  @override
  String get syncViaNfc => 'NFC tag';

  @override
  String get syncViaNfcSubtitle => 'Write plain nbvpn: URI (no passphrase)';

  @override
  String get syncBluetoothNote =>
      'Bluetooth peer sync is not built in; use file share / Wi‑Fi Direct via the system share sheet.';

  @override
  String get syncFailed => 'Sync failed';

  @override
  String get nfcUnsupported => 'NFC is not available on this device';

  @override
  String get nfcTooLargeTitle => 'Payload too large for NFC';

  @override
  String get nfcTooLargeBody =>
      'Encrypted config exceeds the practical NFC size limit. Use file share or QR instead.';

  @override
  String get nfcHoldTag => 'Hold an NFC tag to the device…';

  @override
  String get nfcWriteOk => 'Written to NFC tag';

  @override
  String get nfcFailed => 'NFC failed';

  @override
  String get encryptedQrTitle => 'Encrypted QR';

  @override
  String get encryptedQrHint =>
      'Recipient needs the same passphrase to decrypt.';

  @override
  String get qrTooDenseHint =>
      'QR is dense — prefer file share if scanning fails.';

  @override
  String get qrEncodeFailed => 'Could not encode QR';

  @override
  String get shareEncryptedQr => 'Encrypted QR';

  @override
  String get shareEncryptedQrSubtitle => 'Passphrase-encrypted server config';

  @override
  String get shareApp => 'Share app';

  @override
  String get shareAppSubtitle => 'Download page / store link';

  @override
  String shareAppConfirm(String url) {
    return 'Share download link?\n$url';
  }

  @override
  String get shareAppMessage => 'Download NetBridge VPN:';
}
