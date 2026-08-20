; NetBridge Windows client — Inno Setup 6+
; Encoding: UTF-8 with BOM required for Chinese AppName/Icons (Inno 6 Unicode).
; Build from CI after: flutter build windows --release
; /DSrcDir=... path to build\windows\x64\runner\Release
; /DOutputDir=...

#ifndef MyAppVersion
  #define MyAppVersion "1.0.0"
#endif
#ifndef SrcDir
  #define SrcDir "..\..\build\windows\x64\runner\Release"
#endif
#ifndef OutputDir
  #define OutputDir "..\..\dist"
#endif

[Setup]
AppId={{B7E1D904-5C2A-4A8F-9E11-6F7A8B9C0D1E}
AppName=网桥 VPN (NetBridge)
AppVerName=网桥 VPN (NetBridge) {#MyAppVersion}
AppVersion={#MyAppVersion}
AppPublisher=NetBridge
AppPublisherURL=https://github.com/PHPJourney/netbridge
DefaultDirName={autopf}\NetBridge Client
DefaultGroupName=NetBridge
DisableProgramGroupPage=yes
OutputDir={#OutputDir}
OutputBaseFilename=NetBridge-windows-setup
Compression=lzma
SolidCompression=yes
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
; Flutter Windows client needs Win10+ APIs — refuse Server 2012 before install
MinVersion=10.0
WizardStyle=modern
UninstallDisplayIcon={app}\netbridge.exe

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

; MinVersion aborts before InitializeSetup — override stock English box.
; This is the *client* installer (AppName 网桥 VPN), not the server nbvpn Setup.
[Messages]
WindowsVersionNotSupported=本安装包是「网桥 VPN」客户端，仅支持 Windows 10 及以上，不能在 Server 2012 / 2012 R2 上安装。%n%n若您要在 Server 2012 / 2012 R2 上部署服务端节点：请勿使用本客户端 Setup，也勿使用 NetBridge-nbvpn-Setup.exe。请从 GitHub Releases（v0.1.8+）下载并双击：%n  • NetBridge-nbvpn-Setup-win2012.exe%n装好后用开始菜单「NetBridge nbvpn 管理」。%n%n---%nThis is the NetBridge *client* Setup (Windows 10+ only). On Server 2012 / 2012 R2 deploy with NetBridge-nbvpn-Setup-win2012.exe from Releases v0.1.8+.

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop shortcut"; GroupDescription: "Additional icons:"; Flags: unchecked

[Files]
Source: "{#SrcDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\网桥 VPN"; Filename: "{app}\netbridge.exe"
Name: "{group}\Uninstall 网桥 VPN"; Filename: "{uninstallexe}"
Name: "{autodesktop}\网桥 VPN"; Filename: "{app}\netbridge.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\netbridge.exe"; Description: "Launch NetBridge"; Flags: nowait postinstall skipifsilent
