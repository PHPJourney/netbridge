import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'NetBridge VPN'**
  String get appTitle;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @killSwitch.
  ///
  /// In en, this message translates to:
  /// **'Kill Switch'**
  String get killSwitch;

  /// No description provided for @killSwitchSubtitleReal.
  ///
  /// In en, this message translates to:
  /// **'When on, the app will try to block traffic leaks if the VPN drops (depends on the OS; full blocking varies by platform).'**
  String get killSwitchSubtitleReal;

  /// No description provided for @killSwitchSubtitleStub.
  ///
  /// In en, this message translates to:
  /// **'Stub tunnel only — Kill Switch preference is saved but does not block traffic.'**
  String get killSwitchSubtitleStub;

  /// No description provided for @tunnelCapability.
  ///
  /// In en, this message translates to:
  /// **'Tunnel capability'**
  String get tunnelCapability;

  /// No description provided for @tunnelStubSuffix.
  ///
  /// In en, this message translates to:
  /// **'(Stub ≠ production-ready)'**
  String get tunnelStubSuffix;

  /// No description provided for @tunnelAppleLinkedNote.
  ///
  /// In en, this message translates to:
  /// **'WGExtension is embedded. Debug builds can sign with a Personal Team; real Packet Tunnel / distribution need a paid Apple Developer account (NE), provisioning, and WireGuardKit. Personal Team cannot activate NE. Notarization is typically required before sharing builds.'**
  String get tunnelAppleLinkedNote;

  /// No description provided for @cantConnectTitle.
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach a node?'**
  String get cantConnectTitle;

  /// No description provided for @cantConnectBody.
  ///
  /// In en, this message translates to:
  /// **'Check endpoint, UDP 51820 (host firewall + cloud security group), and re-import with a fresh nbvpn show.'**
  String get cantConnectBody;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get languageSystem;

  /// No description provided for @languageChinese.
  ///
  /// In en, this message translates to:
  /// **'中文'**
  String get languageChinese;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @aboutSection.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutSection;

  /// No description provided for @versionLabel.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String versionLabel(String version);

  /// No description provided for @officialWebsite.
  ///
  /// In en, this message translates to:
  /// **'Official website'**
  String get officialWebsite;

  /// No description provided for @termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @responsibilityOneLiner.
  ///
  /// In en, this message translates to:
  /// **'Decentralized self-hosted nodes — no official VPN servers, no account required.'**
  String get responsibilityOneLiner;

  /// No description provided for @partnersTitle.
  ///
  /// In en, this message translates to:
  /// **'Partners'**
  String get partnersTitle;

  /// No description provided for @partnersBody.
  ///
  /// In en, this message translates to:
  /// **'Optional mention: TradeMind / TM Open Platform.'**
  String get partnersBody;

  /// No description provided for @aboutDetails.
  ///
  /// In en, this message translates to:
  /// **'About & responsibility'**
  String get aboutDetails;

  /// No description provided for @aboutDetailsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Decentralization and user responsibility'**
  String get aboutDetailsSubtitle;

  /// No description provided for @aboutDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'About NetBridge VPN'**
  String get aboutDialogTitle;

  /// No description provided for @aboutBody.
  ///
  /// In en, this message translates to:
  /// **'NetBridge VPN is a decentralized self-hosted node tool. This product does not provide public VPN nodes and does not require login.\n\nNodes run on your servers. You are responsible for egress network use and lawful use.\n\nConnection info (URI / QR / config) is an access secret — do not publish it.\n\nSelf-hosted import:\n1. Server: nbvpn show --uri (or scan /var/lib/nbvpn/peers/*.png)\n2. App: paste URI / scan / import .nbvpn.json\n3. If it fails: allow UDP 51820 on cloud SG + host firewall; endpoint must be public\n\nPlatform notes:\n• Android: real WireGuard (system VPN consent)\n• iOS/macOS: WGExtension is embedded; real tunnels need a paid Apple Developer account (Network Extension + App Group + signing). A Personal Team often builds but cannot activate Packet Tunnel. Sharing builds also needs notarization / proper distribution.\n• Windows: admin often required; Kill Switch is not WFP-level yet'**
  String get aboutBody;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @versionFooter.
  ///
  /// In en, this message translates to:
  /// **'Version {version} · no account · no built-in servers'**
  String versionFooter(String version);

  /// No description provided for @openLinkFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open link'**
  String get openLinkFailed;

  /// No description provided for @emptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No servers yet'**
  String get emptyTitle;

  /// No description provided for @emptyBody.
  ///
  /// In en, this message translates to:
  /// **'Add a node by pasting a URI, importing a config file, or scanning a QR code. The app never auto-connects to any official node.'**
  String get emptyBody;

  /// No description provided for @addServer.
  ///
  /// In en, this message translates to:
  /// **'Add server'**
  String get addServer;

  /// No description provided for @alreadyAdded.
  ///
  /// In en, this message translates to:
  /// **'Already added \"{name}\"'**
  String alreadyAdded(String name);

  /// No description provided for @added.
  ///
  /// In en, this message translates to:
  /// **'Added'**
  String get added;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @localDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Local display name'**
  String get localDisplayName;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @deleteServer.
  ///
  /// In en, this message translates to:
  /// **'Delete server'**
  String get deleteServer;

  /// No description provided for @deleteConfirmConnected.
  ///
  /// In en, this message translates to:
  /// **'You will need to re-import to connect again. This server is active and will disconnect first. Delete \"{name}\"?'**
  String deleteConfirmConnected(String name);

  /// No description provided for @deleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'You will need to re-import to connect again. Delete \"{name}\"?'**
  String deleteConfirm(String name);

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @copiedError.
  ///
  /// In en, this message translates to:
  /// **'Error copied'**
  String get copiedError;

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// No description provided for @disconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnect;

  /// No description provided for @statusDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get statusDisconnected;

  /// No description provided for @statusConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting'**
  String get statusConnecting;

  /// No description provided for @statusConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get statusConnected;

  /// No description provided for @statusReconnecting.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting'**
  String get statusReconnecting;

  /// No description provided for @statusError.
  ///
  /// In en, this message translates to:
  /// **'Connection error'**
  String get statusError;

  /// No description provided for @statusConnectedDetail.
  ///
  /// In en, this message translates to:
  /// **'Connected · {name}'**
  String statusConnectedDetail(String name);

  /// No description provided for @statusConnectingDetail.
  ///
  /// In en, this message translates to:
  /// **'Connecting to {name}…'**
  String statusConnectingDetail(String name);

  /// No description provided for @statusReconnectingDetail.
  ///
  /// In en, this message translates to:
  /// **'Network interrupted, reconnecting…'**
  String get statusReconnectingDetail;

  /// No description provided for @statusErrorFallback.
  ///
  /// In en, this message translates to:
  /// **'Connection failed'**
  String get statusErrorFallback;

  /// No description provided for @copyError.
  ///
  /// In en, this message translates to:
  /// **'Copy error'**
  String get copyError;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @addMethodTitle.
  ///
  /// In en, this message translates to:
  /// **'Add server'**
  String get addMethodTitle;

  /// No description provided for @chooseImportMethod.
  ///
  /// In en, this message translates to:
  /// **'Choose import method'**
  String get chooseImportMethod;

  /// No description provided for @noOfficialNodes.
  ///
  /// In en, this message translates to:
  /// **'Does not connect to any official node. You import config from your own server.'**
  String get noOfficialNodes;

  /// No description provided for @pasteUri.
  ///
  /// In en, this message translates to:
  /// **'Paste URI'**
  String get pasteUri;

  /// No description provided for @pasteUriSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Paste an nbvpn:1?… link'**
  String get pasteUriSubtitle;

  /// No description provided for @importFile.
  ///
  /// In en, this message translates to:
  /// **'Import file'**
  String get importFile;

  /// No description provided for @importFileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a .nbvpn.json config file'**
  String get importFileSubtitle;

  /// No description provided for @scanQr.
  ///
  /// In en, this message translates to:
  /// **'Scan QR code'**
  String get scanQr;

  /// No description provided for @scanQrSubtitleMobile.
  ///
  /// In en, this message translates to:
  /// **'Camera / gallery / paste URI on this screen'**
  String get scanQrSubtitleMobile;

  /// No description provided for @scanQrSubtitleDesktop.
  ///
  /// In en, this message translates to:
  /// **'On desktop, paste a URI or import a file instead'**
  String get scanQrSubtitleDesktop;

  /// No description provided for @usePasteUriInstead.
  ///
  /// In en, this message translates to:
  /// **'Use paste URI instead'**
  String get usePasteUriInstead;

  /// No description provided for @cannotReadFile.
  ///
  /// In en, this message translates to:
  /// **'Could not read file contents'**
  String get cannotReadFile;

  /// No description provided for @secretWarning.
  ///
  /// In en, this message translates to:
  /// **'Connection info contains access secrets. Only take it from servers you trust. URI / QR / config equal a key — do not share publicly.'**
  String get secretWarning;

  /// No description provided for @longPressCopy.
  ///
  /// In en, this message translates to:
  /// **'Long-press to select and copy'**
  String get longPressCopy;

  /// No description provided for @reenter.
  ///
  /// In en, this message translates to:
  /// **'Re-enter'**
  String get reenter;

  /// No description provided for @pasteUriTitle.
  ///
  /// In en, this message translates to:
  /// **'Paste URI'**
  String get pasteUriTitle;

  /// No description provided for @pasteUriHint.
  ///
  /// In en, this message translates to:
  /// **'nbvpn:1?… or full .nbvpn.json text'**
  String get pasteUriHint;

  /// No description provided for @pasteUriHelper.
  ///
  /// In en, this message translates to:
  /// **'Ignores WARNING lines, quotes, newlines, and code fences; JSON paste also works'**
  String get pasteUriHelper;

  /// No description provided for @pasteFromClipboard.
  ///
  /// In en, this message translates to:
  /// **'Paste from clipboard'**
  String get pasteFromClipboard;

  /// No description provided for @validateContinue.
  ///
  /// In en, this message translates to:
  /// **'Validate & continue'**
  String get validateContinue;

  /// No description provided for @confirmAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm add'**
  String get confirmAddTitle;

  /// No description provided for @endpointLooksBad.
  ///
  /// In en, this message translates to:
  /// **'Endpoint looks unreachable (empty or 0.0.0.0). On the server run nbvpn config set endpoint <public IP or domain>, then re-export the URI.'**
  String get endpointLooksBad;

  /// No description provided for @localNameHelper.
  ///
  /// In en, this message translates to:
  /// **'Stored on this device only; not written back to the server'**
  String get localNameHelper;

  /// No description provided for @labelNode.
  ///
  /// In en, this message translates to:
  /// **'Node'**
  String get labelNode;

  /// No description provided for @labelAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get labelAddress;

  /// No description provided for @labelDns.
  ///
  /// In en, this message translates to:
  /// **'DNS'**
  String get labelDns;

  /// No description provided for @confirmSecretHint.
  ///
  /// In en, this message translates to:
  /// **'Connection info contains access secrets. Only take it from servers you trust.'**
  String get confirmSecretHint;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @editServer.
  ///
  /// In en, this message translates to:
  /// **'Edit server'**
  String get editServer;

  /// No description provided for @export.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get export;

  /// No description provided for @sync.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get sync;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// No description provided for @profileName.
  ///
  /// In en, this message translates to:
  /// **'Profile name'**
  String get profileName;

  /// No description provided for @labelEndpoint.
  ///
  /// In en, this message translates to:
  /// **'Endpoint'**
  String get labelEndpoint;

  /// No description provided for @labelAllowedIps.
  ///
  /// In en, this message translates to:
  /// **'Allowed IPs'**
  String get labelAllowedIps;

  /// No description provided for @labelMtu.
  ///
  /// In en, this message translates to:
  /// **'MTU'**
  String get labelMtu;

  /// No description provided for @labelKeepalive.
  ///
  /// In en, this message translates to:
  /// **'Keepalive'**
  String get labelKeepalive;

  /// No description provided for @labelServerPublicKey.
  ///
  /// In en, this message translates to:
  /// **'Server public key'**
  String get labelServerPublicKey;

  /// No description provided for @labelPrivateKey.
  ///
  /// In en, this message translates to:
  /// **'Client private key'**
  String get labelPrivateKey;

  /// No description provided for @labelPresharedKey.
  ///
  /// In en, this message translates to:
  /// **'Preshared key (optional)'**
  String get labelPresharedKey;

  /// No description provided for @revealPrivateKeyTitle.
  ///
  /// In en, this message translates to:
  /// **'Show private key?'**
  String get revealPrivateKeyTitle;

  /// No description provided for @revealPrivateKeyBody.
  ///
  /// In en, this message translates to:
  /// **'The private key is equivalent to full access. Only reveal on a trusted screen.'**
  String get revealPrivateKeyBody;

  /// No description provided for @reveal.
  ///
  /// In en, this message translates to:
  /// **'Reveal'**
  String get reveal;

  /// No description provided for @hide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get hide;

  /// No description provided for @exportServersTitle.
  ///
  /// In en, this message translates to:
  /// **'Export servers'**
  String get exportServersTitle;

  /// No description provided for @exportSecretTitle.
  ///
  /// In en, this message translates to:
  /// **'Export contains secrets'**
  String get exportSecretTitle;

  /// No description provided for @exportSecretBody.
  ///
  /// In en, this message translates to:
  /// **'Exported files include private keys — equivalent to passwords. Do not share publicly.'**
  String get exportSecretBody;

  /// No description provided for @exportAlsoWireGuard.
  ///
  /// In en, this message translates to:
  /// **'Also export WireGuard .conf'**
  String get exportAlsoWireGuard;

  /// No description provided for @exportWireGuard.
  ///
  /// In en, this message translates to:
  /// **'Export WireGuard'**
  String get exportWireGuard;

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed'**
  String get exportFailed;

  /// No description provided for @selectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get selectAll;

  /// No description provided for @selectNone.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get selectNone;

  /// No description provided for @continueAction.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueAction;

  /// No description provided for @server.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get server;

  /// No description provided for @syncTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync to another device'**
  String get syncTitle;

  /// No description provided for @syncPassphraseTitle.
  ///
  /// In en, this message translates to:
  /// **'Encryption passphrase'**
  String get syncPassphraseTitle;

  /// No description provided for @syncPassphraseBody.
  ///
  /// In en, this message translates to:
  /// **'Choose a passphrase the receiving device will need. Config is encrypted with AES-GCM.'**
  String get syncPassphraseBody;

  /// No description provided for @passphrase.
  ///
  /// In en, this message translates to:
  /// **'Passphrase'**
  String get passphrase;

  /// No description provided for @syncViaQr.
  ///
  /// In en, this message translates to:
  /// **'Encrypted QR code'**
  String get syncViaQr;

  /// No description provided for @syncViaQrSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Scan on the other device (or share the image)'**
  String get syncViaQrSubtitle;

  /// No description provided for @syncViaFile.
  ///
  /// In en, this message translates to:
  /// **'Encrypted file share'**
  String get syncViaFile;

  /// No description provided for @syncViaFileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'System share sheet — works across phones'**
  String get syncViaFileSubtitle;

  /// No description provided for @syncViaNfc.
  ///
  /// In en, this message translates to:
  /// **'NFC tag'**
  String get syncViaNfc;

  /// No description provided for @syncViaNfcSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Write short encrypted payload to a tag'**
  String get syncViaNfcSubtitle;

  /// No description provided for @syncBluetoothNote.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth peer sync is not built in; use file share / Wi‑Fi Direct via the system share sheet.'**
  String get syncBluetoothNote;

  /// No description provided for @syncFailed.
  ///
  /// In en, this message translates to:
  /// **'Sync failed'**
  String get syncFailed;

  /// No description provided for @nfcUnsupported.
  ///
  /// In en, this message translates to:
  /// **'NFC is not available on this device'**
  String get nfcUnsupported;

  /// No description provided for @nfcTooLargeTitle.
  ///
  /// In en, this message translates to:
  /// **'Payload too large for NFC'**
  String get nfcTooLargeTitle;

  /// No description provided for @nfcTooLargeBody.
  ///
  /// In en, this message translates to:
  /// **'Encrypted config exceeds the practical NFC size limit. Use file share or QR instead.'**
  String get nfcTooLargeBody;

  /// No description provided for @nfcHoldTag.
  ///
  /// In en, this message translates to:
  /// **'Hold an NFC tag to the device…'**
  String get nfcHoldTag;

  /// No description provided for @nfcWriteOk.
  ///
  /// In en, this message translates to:
  /// **'Written to NFC tag'**
  String get nfcWriteOk;

  /// No description provided for @nfcFailed.
  ///
  /// In en, this message translates to:
  /// **'NFC failed'**
  String get nfcFailed;

  /// No description provided for @encryptedQrTitle.
  ///
  /// In en, this message translates to:
  /// **'Encrypted QR'**
  String get encryptedQrTitle;

  /// No description provided for @encryptedQrHint.
  ///
  /// In en, this message translates to:
  /// **'Recipient needs the same passphrase to decrypt.'**
  String get encryptedQrHint;

  /// No description provided for @qrTooDenseHint.
  ///
  /// In en, this message translates to:
  /// **'QR is dense — prefer file share if scanning fails.'**
  String get qrTooDenseHint;

  /// No description provided for @qrEncodeFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not encode QR'**
  String get qrEncodeFailed;

  /// No description provided for @shareEncryptedQr.
  ///
  /// In en, this message translates to:
  /// **'Encrypted QR'**
  String get shareEncryptedQr;

  /// No description provided for @shareEncryptedQrSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Passphrase-encrypted server config'**
  String get shareEncryptedQrSubtitle;

  /// No description provided for @shareApp.
  ///
  /// In en, this message translates to:
  /// **'Share app'**
  String get shareApp;

  /// No description provided for @shareAppSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Download page / store link'**
  String get shareAppSubtitle;

  /// No description provided for @shareAppConfirm.
  ///
  /// In en, this message translates to:
  /// **'Share download link?\n{url}'**
  String shareAppConfirm(String url);

  /// No description provided for @shareAppMessage.
  ///
  /// In en, this message translates to:
  /// **'Download NetBridge VPN:'**
  String get shareAppMessage;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
