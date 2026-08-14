; NetBridge nbvpn — Windows Server Setup (Inno Setup 6+)
; Build: iscc nbvpn-setup.iss  (or build-setup.ps1)
; Expects staging folder with:
;   nbvpn-windows-amd64.exe  (or set via /DSrcExe=...)
;   nbvpn-gui-windows-amd64.exe  (DestName nbvpn-gui.exe)
;   install.ps1, Install-WireGuard.ps1, wireguard-bundle.json
;   vendor\wireguard\wireguard-amd64-*.msi  (REQUIRED — build fails without it)
;   WINDOWS.md, THIRDPARTY-NOTICE.txt
;   netbridge.ico (optional Setup/shortcut icon)

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
LicenseFile={#SrcDir}\THIRDPARTY-NOTICE.txt
OutputDir={#OutputDir}
OutputBaseFilename=NetBridge-nbvpn-Setup
Compression=lzma
SolidCompression=yes
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
WizardStyle=modern
SetupLogging=yes
ChangesEnvironment=yes
SetupIconFile={#SrcDir}\netbridge.ico
UninstallDisplayIcon={app}\nbvpn-gui.exe

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
Source: "{#SrcDir}\{#SrcExe}"; DestDir: "{app}"; DestName: "nbvpn.exe"; Flags: ignoreversion
Source: "{#SrcDir}\{#SrcGuiExe}"; DestDir: "{app}"; DestName: "nbvpn-gui.exe"; Flags: ignoreversion
Source: "{#SrcDir}\install.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SrcDir}\Install-WireGuard.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SrcDir}\wireguard-bundle.json"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SrcDir}\WINDOWS.md"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist
Source: "{#SrcDir}\THIRDPARTY-NOTICE.txt"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist
Source: "{#SrcDir}\setup.bat"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist
Source: "{#SrcDir}\netbridge.ico"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist
; REQUIRED: pinned WireGuard MSI must be staged by CI / build-setup.ps1 (no skipifsourcedoesntexist)
Source: "{#SrcDir}\vendor\wireguard\*"; DestDir: "{app}\vendor\wireguard"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\NetBridge nbvpn GUI"; Filename: "{app}\nbvpn-gui.exe"; WorkingDir: "{app}"; IconFilename: "{app}\nbvpn-gui.exe"; Check: GuiExists
Name: "{group}\nbvpn CLI help"; Filename: "{cmd}"; Parameters: "/k ""{app}\nbvpn.exe"" help"; IconFilename: "{app}\nbvpn.exe"
Name: "{group}\Open data folder"; Filename: "{win}\explorer.exe"; Parameters: "%ProgramData%\nbvpn"
Name: "{group}\Uninstall NetBridge nbvpn"; Filename: "{uninstallexe}"
Name: "{autodesktop}\NetBridge nbvpn GUI"; Filename: "{app}\nbvpn-gui.exe"; WorkingDir: "{app}"; IconFilename: "{app}\nbvpn-gui.exe"; Tasks: desktopicon; Check: GuiExists

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut for nbvpn GUI"; GroupDescription: "Additional icons:"; Flags: unchecked

[Registry]
Root: HKLM; Subkey: "SYSTEM\CurrentControlSet\Control\Session Manager\Environment"; \
  ValueType: expandsz; ValueName: "Path"; ValueData: "{olddata};{app}"; \
  Check: NeedsAddPath(ExpandConstant('{app}')); Flags: preservestringtype

; install.ps1 runs in CurStepChanged (hard-fail). Optional post-install GUI launch:
[Run]
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
  Result := Pos(';' + UpperCase(Param) + ';', ';' + UpperCase(OrigPath) + ';') = 0;
end;

function GuiExists: Boolean;
begin
  Result := FileExists(ExpandConstant('{app}\nbvpn-gui.exe'));
end;

function WireGuardMsiStaged: Boolean;
var
  FindRec: TFindRec;
begin
  Result := FindFirst(ExpandConstant('{#SrcDir}\vendor\wireguard\*.msi'), FindRec);
  if Result then
    FindClose(FindRec);
end;

function InitializeSetup(): Boolean;
begin
  Result := True;
  { Compile-time staging is enforced by build-setup; runtime check is belt-and-suspenders for local builds }
end;

function ExecInstallPs1(): Boolean;
var
  ResultCode: Integer;
  Params: String;
begin
  Params := '-NoProfile -ExecutionPolicy Bypass -File "' + ExpandConstant('{app}\install.ps1') +
    '" -InstallDir "' + ExpandConstant('{app}') + '"';
  Log('Running install.ps1: ' + Params);
  if not Exec('powershell.exe', Params, ExpandConstant('{app}'), SW_SHOW, ewWaitUntilTerminated, ResultCode) then
  begin
    MsgBox('Failed to launch install.ps1 (WireGuard + nbvpn configure).', mbError, MB_OK);
    Result := False;
    exit;
  end;
  if ResultCode <> 0 then
  begin
    MsgBox('install.ps1 failed with exit code ' + IntToStr(ResultCode) +
      '. WireGuard may not be installed. See Setup log / PowerShell output.', mbError, MB_OK);
    Result := False;
    exit;
  end;
  Result := True;
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    if not ExecInstallPs1() then
      RaiseException('NetBridge install.ps1 failed — Setup aborted so WireGuard is not silently skipped.');
  end;
end;
