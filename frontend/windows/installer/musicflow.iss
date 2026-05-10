#define MyAppName "MusicFlow"
#define MyAppPublisher "MusicFlow"
#define MyAppExeName "musicflow.exe"
#ifndef MyAppVersion
#define MyAppVersion "1.0.0"
#endif
#ifndef MySourceDir
#define MySourceDir "..\\build\\windows\\x64\\runner\\Release"
#endif
#ifndef MyOutputDir
#define MyOutputDir ".."
#endif
#ifndef MyOutputBaseFilename
#define MyOutputBaseFilename "MusicFlow-Setup"
#endif

[Setup]
AppId={{6C980FE0-12F1-4A1A-9E8F-3B5C1F1AF520}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir={#MyOutputDir}
OutputBaseFilename={#MyOutputBaseFilename}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
PrivilegesRequired=lowest
SetupIconFile={#SourcePath}\..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}

[Tasks]
Name: "desktopicon"; Description: "创建桌面快捷方式"; GroupDescription: "附加任务："; Flags: unchecked

[Files]
Source: "{#MySourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "启动 {#MyAppName}"; Flags: nowait postinstall skipifsilent
