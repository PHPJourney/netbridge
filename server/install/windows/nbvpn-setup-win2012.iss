; NetBridge nbvpn — Server 2012 / 2012 R2 Setup (Inno Setup 6+)
; Output: NetBridge-nbvpn-Setup-win2012.exe
; Bundles: win2012 CLI + Win32 GUI + WireGuard 0.5.3 MSI + install.ps1
; NOT Fyne, NOT modern WireGuard 1.1 MSI
;
; Build: build-setup-win2012.ps1

#ifndef MyAppVersion
  #define MyAppVersion "1.0.0"
#endif
#ifndef SrcDir
  #define SrcDir "."
#endif
#ifndef SrcExe
  #define SrcExe "nbvpn-windows-amd64-win2012.exe"
#endif
#ifndef SrcGuiExe
  #define SrcGuiExe "nbvpn-gui-win2012.exe"
#endif
#ifndef OutputDir
  #define OutputDir "dist"
#endif

[Setup]
AppId={{B7C2E1A0-8A3D-4E10-9B6F-0C1D2E3F4A5B}
AppName=NetBridge nbvpn (Server 2012)
AppVersion={#MyAppVersion}
AppPublisher=NetBridge
AppPublisherURL=https://github.com/PHPJourney/netbridge
DefaultDirName={autopf}\NetBridge
DefaultGroupName=NetBridge
DisableProgramGroupPage=yes
LicenseFile={#SrcDir}\THIRDPARTY-NOTICE.txt
OutputDir={#OutputDir}
OutputBaseFilename=NetBridge-nbvpn-Setup-win2012
Compression=lzma
SolidCompression=yes
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=6.1
WizardStyle=modern
SetupLogging=yes
ChangesEnvironment=yes
SetupIconFile={#SrcDir}\netbridge.ico
UninstallDisplayIcon={app}\netbridge.ico

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Messages]
WindowsVersionNotSupported=本安装包是服务端 Setup（Server 2012 / 2012 R2 专用，含 WireGuard 0.5.3 + Win32 GUI）。%n%n若您的系统是 Windows 10 / Server 2016+：请改用 NetBridge-nbvpn-Setup.exe（WireGuard 1.1 + Fyne GUI）。%n%n---%nThis is the Server 2012 / 2012 R2 server Setup. On Windows 10 / Server 2016+ use NetBridge-nbvpn-Setup.exe instead.

[Files]
Source: "{#SrcDir}\{#SrcExe}"; DestDir: "{app}"; DestName: "nbvpn.exe"; Flags: ignoreversion
Source: "{#SrcDir}\{#SrcGuiExe}"; DestDir: "{app}"; DestName: "nbvpn-gui.exe"; Flags: ignoreversion
Source: "{#SrcDir}\install.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SrcDir}\Install-WireGuard.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SrcDir}\wireguard-bundle-win2012.json"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SrcDir}\wireguard-bundle-win2012.json"; DestDir: "{app}\vendor\wireguard"; DestName: "wireguard-bundle-win2012.json"; Flags: ignoreversion
Source: "{#SrcDir}\WINDOWS.md"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist
Source: "{#SrcDir}\THIRDPARTY-NOTICE.txt"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist
Source: "{#SrcDir}\netbridge.ico"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SrcDir}\nbvpn-manage.cmd"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist
Source: "{#SrcDir}\nbvpn-open-cmd.cmd"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist
Source: "{#SrcDir}\nbvpn-status.cmd"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist
Source: "{#SrcDir}\README-WIN2012.txt"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist
; REQUIRED: legacy WireGuard 0.5.3 MSI (not 1.1)
Source: "{#SrcDir}\vendor\wireguard\*"; DestDir: "{app}\vendor\wireguard"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
; Prefer staged netbridge.ico (same branding as embedded exe icon) so shortcuts work even if shell caches stale exe icons.
Name: "{group}\NetBridge nbvpn GUI"; Filename: "{app}\nbvpn-gui.exe"; WorkingDir: "{app}"; IconFilename: "{app}\netbridge.ico"
Name: "{group}\NetBridge nbvpn 管理 (菜单)"; Filename: "{app}\nbvpn-manage.cmd"; WorkingDir: "{app}"; IconFilename: "{app}\netbridge.ico"
Name: "{group}\nbvpn 命令提示符"; Filename: "{app}\nbvpn-open-cmd.cmd"; WorkingDir: "{app}"; IconFilename: "{app}\netbridge.ico"
Name: "{group}\打开数据目录"; Filename: "{win}\explorer.exe"; Parameters: "%ProgramData%\nbvpn"; IconFilename: "{app}\netbridge.ico"
Name: "{group}\阅读 2012 说明"; Filename: "{app}\README-WIN2012.txt"
Name: "{group}\卸载 NetBridge nbvpn (2012)"; Filename: "{uninstallexe}"
Name: "{autodesktop}\NetBridge nbvpn GUI"; Filename: "{app}\nbvpn-gui.exe"; WorkingDir: "{app}"; IconFilename: "{app}\netbridge.ico"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "在桌面创建 GUI 快捷方式"; GroupDescription: "附加图标:"; Flags: unchecked

[Registry]
Root: HKLM; Subkey: "SYSTEM\CurrentControlSet\Control\Session Manager\Environment"; \
  ValueType: expandsz; ValueName: "Path"; ValueData: "{olddata};{app}"; \
  Check: NeedsAddPath(ExpandConstant('{app}')); Flags: preservestringtype

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

function IsModernWindowsHost: Boolean;
var
  Ver: TWindowsVersion;
begin
  GetWindowsVersionEx(Ver);
  Result := Ver.Major >= 10;
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
    'install.ps1 失败，退出码 ' + IntToStr(ResultCode) + '。' + #13#10#13#10 +
    '本包会安装历史官方 WireGuard 0.5.3（兼容 2012，不是现代 1.1）。' + #13#10 +
    '日志:' + #13#10 +
    '  %TEMP%\nbvpn-setup-last-error.txt' + #13#10 +
    '  %TEMP%\nbvpn-setup-latest.log' + #13#10;
  if Detail <> '' then
    Result := Result + #13#10 + '--- detail ---' + #13#10 + Detail;
end;

function InitializeSetup(): Boolean;
begin
  Result := True;
  if IsModernWindowsHost then
  begin
    if MsgBox(
      '检测到 Windows 10 / Server 2016+。' + #13#10#13#10 +
      '本安装包是 Server 2012 专用（WireGuard 0.5.3 + Win32 GUI）。' + #13#10 +
      '建议改用 NetBridge-nbvpn-Setup.exe（1.1 + Fyne）。' + #13#10#13#10 +
      '仍要继续安装本 2012 包吗？',
      mbConfirmation, MB_YESNO) = IDNO then
    begin
      Result := False;
    end;
  end;
end;

function ExecInstallPs1(): Boolean;
var
  ResultCode: Integer;
  Params: String;
begin
  { Install legacy WG 0.5.3 via Install-WireGuard.ps1 (PreferLegacy) — do NOT SkipWireGuard. }
  Params := '-NoProfile -ExecutionPolicy Bypass -File "' + ExpandConstant('{app}\install.ps1') +
    '" -InstallDir "' + ExpandConstant('{app}') + '"';
  Log('Running install.ps1 (win2012 + WG 0.5.3): ' + Params);
  if not Exec('powershell.exe', Params, ExpandConstant('{app}'), SW_SHOW, ewWaitUntilTerminated, ResultCode) then
  begin
    MsgBox(
      '无法启动 install.ps1。' + #13#10 +
      '请以管理员打开 PowerShell：' + #13#10 +
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
        'NetBridge install.ps1 failed — Setup aborted.' + #13#10 +
        'See %TEMP%\nbvpn-setup-last-error.txt and %TEMP%\nbvpn-setup-latest.log');
  end;
end;
