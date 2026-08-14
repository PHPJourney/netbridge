; NetBridge nbvpn — Windows Server Setup (Inno Setup 6+)
; Build: iscc nbvpn-setup.iss  (or build-setup.ps1)
; Expects staging folder with:
;   nbvpn-windows-amd64.exe  (or set via /DSrcExe=...)
;   install.ps1
;   WINDOWS.md

#ifndef MyAppVersion
  #define MyAppVersion "1.0.0"
#endif
#ifndef SrcDir
  #define SrcDir "."
#endif
#ifndef SrcExe
  #define SrcExe "nbvpn-windows-amd64.exe"
#endif
#ifndef OutputDir
  #define OutputDir "dist"
#endif

[Setup]
AppId={{A8F3C2D1-9B4E-4F21-8C7A-1D2E3F4A5B6C}
AppName=NetBridge nbvpn
AppVersion={#MyAppVersion}
AppPublisher=NetBridge
AppPublisherURL=https://github.com/PHPJourney/netbridge
DefaultDirName={autopf}\NetBridge
DefaultGroupName=NetBridge
DisableProgramGroupPage=yes
LicenseFile=
OutputDir={#OutputDir}
OutputBaseFilename=NetBridge-nbvpn-Setup
Compression=lzma
SolidCompression=yes
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
WizardStyle=modern
SetupLogging=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
Source: "{#SrcDir}\{#SrcExe}"; DestDir: "{app}"; DestName: "nbvpn.exe"; Flags: ignoreversion
Source: "{#SrcDir}\install.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SrcDir}\WINDOWS.md"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist
Source: "{#SrcDir}\setup.bat"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist

[Icons]
Name: "{group}\nbvpn CLI help"; Filename: "{cmd}"; Parameters: "/k ""{app}\nbvpn.exe"" help"
Name: "{group}\Open data folder"; Filename: "{win}\explorer.exe"; Parameters: "%ProgramData%\nbvpn"
Name: "{group}\Uninstall NetBridge nbvpn"; Filename: "{uninstallexe}"

[Run]
; Run elevated install.ps1 after copying binary (firewall, NetNat best-effort, nbvpn install)
Filename: "powershell.exe"; \
  Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\install.ps1"""; \
  StatusMsg: "Configuring nbvpn (firewall, data dir, first peer)…"; \
  Flags: waituntilterminated

; (no custom Pascal code)
