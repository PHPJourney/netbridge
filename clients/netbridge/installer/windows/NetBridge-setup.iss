; NetBridge Windows client — Inno Setup 6+
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
WizardStyle=modern
UninstallDisplayIcon={app}\netbridge.exe

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

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
