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
MinVersion=10.0
WizardStyle=modern
SetupLogging=yes
ChangesEnvironment=yes
SetupIconFile={#SrcDir}\netbridge.ico
UninstallDisplayIcon={app}\nbvpn-gui.exe

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

; MinVersion=10.0 aborts BEFORE InitializeSetup — override the stock English box
; ("This program does not support the version of Windows...") with a clear zh+en path.
[Messages]
WindowsVersionNotSupported=本安装包是服务端 Setup（NetBridge nbvpn），仅支持 Windows 10 / Server 2016 及以上，不能在 Server 2012 / 2012 R2 上运行。%n%n若您的系统是 Server 2012 / 2012 R2：请勿双击本 Setup 或客户端「网桥 VPN」Setup。请从 GitHub Releases（v0.1.7+）下载：%n  • nbvpn-windows-amd64-win2012.exe%n  • install.ps1%n放到同一文件夹后，以管理员打开 PowerShell：%n  .\nbvpn-windows-amd64-win2012.exe version%n  powershell -ExecutionPolicy Bypass -File .\install.ps1 -SkipWireGuard%n%n说明：无 Fyne GUI；官方 WireGuard 1.1 MSI 不支持 2012（仅导出配置 / dry-run）。%n%n---%nThis is the *server* Setup (NetBridge nbvpn), Win10 / Server 2016+. On Server 2012 / 2012 R2 do not use this Setup — download nbvpn-windows-amd64-win2012.exe + install.ps1 from Releases v0.1.7+, then elevated PowerShell (-SkipWireGuard).

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
Name: "{group}\Open Setup logs (TEMP)"; Filename: "{win}\explorer.exe"; Parameters: "%TEMP%"
Name: "{group}\Uninstall NetBridge nbvpn"; Filename: "{uninstallexe}"
Name: "{autodesktop}\NetBridge nbvpn GUI"; Filename: "{app}\nbvpn-gui.exe"; WorkingDir: "{app}"; IconFilename: "{app}\nbvpn-gui.exe"; Tasks: desktopicon; Check: GuiExists

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut for nbvpn GUI"; GroupDescription: "Additional icons:"; Flags: unchecked

[Registry]
Root: HKLM; Subkey: "SYSTEM\CurrentControlSet\Control\Session Manager\Environment"; \
  ValueType: expandsz; ValueName: "Path"; ValueData: "{olddata};{app}"; \
  Check: NeedsAddPath(ExpandConstant('{app}')); Flags: preservestringtype

; Do NOT auto-launch GUI after install (Fyne/CGO historically needed runtime DLLs → CreateProcess 14001).
; User can start from Start Menu after a successful configure step.
[Run]
; intentionally empty — launch GUI manually from Start Menu

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

function IsLegacyWindowsHost: Boolean;
var
  Ver: TWindowsVersion;
begin
  GetWindowsVersionEx(Ver);
  { Server 2012 / 2012 R2 = 6.2 / 6.3; Win10 / Server 2016+ = 10.0 }
  Result := Ver.Major < 10;
end;

function ReadTextFileLimited(const FileName: string; MaxChars: Integer): string;
var
  Lines: TArrayOfString;
  i: Integer;
  Acc: string;
begin
  Result := '';
  if not FileExists(FileName) then
    exit;
  if not LoadStringsFromFile(FileName, Lines) then
    exit;
  Acc := '';
  for i := 0 to GetArrayLength(Lines) - 1 do
  begin
    if Acc <> '' then
      Acc := Acc + #13#10;
    Acc := Acc + Lines[i];
    if Length(Acc) >= MaxChars then
    begin
      Acc := Copy(Acc, 1, MaxChars) + #13#10 + '…(truncated)';
      break;
    end;
  end;
  Result := Acc;
end;

function TempSetupErrorPath: string;
begin
  Result := ExpandConstant('{%TEMP}\nbvpn-setup-last-error.txt');
end;

function TempSetupLogPath: string;
begin
  Result := ExpandConstant('{%TEMP}\nbvpn-setup-latest.log');
end;

function FormatInstallFailureMessage(ResultCode: Integer): string;
var
  Detail: string;
begin
  Detail := ReadTextFileLimited(TempSetupErrorPath, 1200);
  if Detail = '' then
    Detail := ReadTextFileLimited(TempSetupLogPath, 800);
  Result :=
    'install.ps1 failed with exit code ' + IntToStr(ResultCode) + '.' + #13#10#13#10 +
    'This is often WireGuard MSI install, wrong OS binary, or nbvpn configure — ' +
    'not a silent skip.' + #13#10#13#10 +
    'Logs:' + #13#10 +
    '  %TEMP%\nbvpn-setup-last-error.txt' + #13#10 +
    '  %TEMP%\nbvpn-setup-latest.log' + #13#10 +
    '  %TEMP%\nbvpn-wireguard-msiexec.log' + #13#10 +
    '  %ProgramData%\nbvpn\wireguard-msiexec.log' + #13#10 +
    '  Setup log (this wizard)' + #13#10;
  if Detail <> '' then
    Result := Result + #13#10 + '--- detail ---' + #13#10 + Detail;
end;

function InitializeSetup(): Boolean;
begin
  Result := True;
  { Backup if MinVersion is ever lowered — primary refuse is [Messages] WindowsVersionNotSupported }
  if IsLegacyWindowsHost then
  begin
    MsgBox(
      '本安装包仅支持 Windows 10 / Windows Server 2016+。' + #13#10#13#10 +
      'Server 2012 / 2012 R2 请改用：' + #13#10 +
      '  • nbvpn-windows-amd64-win2012.exe' + #13#10 +
      '  • install.ps1' + #13#10 +
      '管理员执行：powershell -ExecutionPolicy Bypass -File .\install.ps1 -SkipWireGuard' + #13#10#13#10 +
      '无 Fyne GUI；官方 WireGuard 1.1 不支持 2012。' + #13#10 +
      'Setup 将退出，避免半安装。',
      mbError, MB_OK);
    Result := False;
  end;
end;

function ExecInstallPs1(): Boolean;
var
  ResultCode: Integer;
  Params: String;
begin
  Params := '-NoProfile -ExecutionPolicy Bypass -File "' + ExpandConstant('{app}\install.ps1') +
    '" -InstallDir "' + ExpandConstant('{app}') + '"';
  Log('Running install.ps1: ' + Params);
  Log('Working dir: ' + ExpandConstant('{app}'));
  if not Exec('powershell.exe', Params, ExpandConstant('{app}'), SW_SHOW, ewWaitUntilTerminated, ResultCode) then
  begin
    MsgBox(
      'Failed to launch install.ps1 (WireGuard + nbvpn configure).' + #13#10 +
      'Run elevated PowerShell:' + #13#10 +
      '  powershell -ExecutionPolicy Bypass -File "' + ExpandConstant('{app}\install.ps1') + '"',
      mbError, MB_OK);
    Result := False;
    exit;
  end;
  if ResultCode <> 0 then
  begin
    MsgBox(FormatInstallFailureMessage(ResultCode), mbError, MB_OK);
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
      RaiseException(
        'NetBridge install.ps1 failed — Setup aborted so WireGuard is not silently skipped.' + #13#10 +
        'See %TEMP%\nbvpn-setup-last-error.txt and %TEMP%\nbvpn-setup-latest.log');
  end;
end;
