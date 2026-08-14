; NetBridge nbvpn — Windows Server Setup (Inno Setup 6+)
; Build: iscc nbvpn-setup.iss  (or build-setup.ps1)
; Expects staging folder with:
;   nbvpn-windows-amd64.exe  (or set via /DSrcExe=...)
;   nbvpn-gui-windows-amd64.exe  (optional; DestName nbvpn-gui.exe)
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
#ifndef SrcGuiExe
  #define SrcGuiExe "nbvpn-gui-windows-amd64.exe"
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
; Tell Explorer / new processes to refresh PATH after install/uninstall.
ChangesEnvironment=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
Source: "{#SrcDir}\{#SrcExe}"; DestDir: "{app}"; DestName: "nbvpn.exe"; Flags: ignoreversion
Source: "{#SrcDir}\{#SrcGuiExe}"; DestDir: "{app}"; DestName: "nbvpn-gui.exe"; Flags: ignoreversion skipifsourcedoesntexist
Source: "{#SrcDir}\install.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SrcDir}\WINDOWS.md"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist
Source: "{#SrcDir}\setup.bat"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist

[Icons]
Name: "{group}\NetBridge nbvpn GUI"; Filename: "{app}\nbvpn-gui.exe"; WorkingDir: "{app}"; Check: GuiExists
Name: "{group}\nbvpn CLI help"; Filename: "{cmd}"; Parameters: "/k ""{app}\nbvpn.exe"" help"
Name: "{group}\Open data folder"; Filename: "{win}\explorer.exe"; Parameters: "%ProgramData%\nbvpn"
Name: "{group}\Uninstall NetBridge nbvpn"; Filename: "{uninstallexe}"
Name: "{autodesktop}\NetBridge nbvpn GUI"; Filename: "{app}\nbvpn-gui.exe"; WorkingDir: "{app}"; Tasks: desktopicon; Check: GuiExists

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut for nbvpn GUI"; GroupDescription: "Additional icons:"; Flags: unchecked

; Always add install dir to *system* PATH so `nbvpn` / `nbvpn-gui` resolve in a new terminal.
[Registry]
Root: HKLM; Subkey: "SYSTEM\CurrentControlSet\Control\Session Manager\Environment"; \
  ValueType: expandsz; ValueName: "Path"; ValueData: "{olddata};{app}"; \
  Check: NeedsAddPath(ExpandConstant('{app}')); Flags: preservestringtype

[Run]
; Run elevated install.ps1 after copying binary (firewall, NetNat best-effort, nbvpn install)
Filename: "powershell.exe"; \
  Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\install.ps1"" -InstallDir ""{app}"""; \
  StatusMsg: "Configuring nbvpn (PATH, firewall, data dir, first peer)…"; \
  Flags: waituntilterminated
Filename: "{app}\nbvpn-gui.exe"; Description: "Launch NetBridge nbvpn GUI"; Flags: nowait postinstall skipifsilent; Check: GuiExists

[Code]
function NeedsAddPath(Param: string): Boolean;
var
  OrigPath: string;
begin
  if not RegQueryStringValue(HKEY_LOCAL_MACHINE,
    'SYSTEM\CurrentControlSet\Control\Session Manager\Environment',
    'Path', OrigPath) then
  begin
    Result := True;
    exit;
  end;
  { Case-insensitive path segment check with trailing/leading separators }
  Result := Pos(';' + UpperCase(Param) + ';', ';' + UpperCase(OrigPath) + ';') = 0;
end;

function GuiExists: Boolean;
begin
  Result := FileExists(ExpandConstant('{app}\nbvpn-gui.exe'));
end;
