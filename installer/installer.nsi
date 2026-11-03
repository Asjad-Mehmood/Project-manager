; Installer for Project Folder Manager (Flutter Windows build).
; Per user, no administrator rights: installs to %LOCALAPPDATA%\ProjectFolderManager, adds Start menu
; and desktop shortcuts and an entry in Settings -> Apps. Silent with /S (the self-updater uses
; /S /UPDATE and the program is opened again afterwards).
; Uninstall also removes the program's settings and index from AppData.
Unicode true
!ifndef VERSION
  !define VERSION "2.3.9"
!endif
!ifndef SOURCE
  !define SOURCE "..\build\windows\x64\runner\Release"
!endif
!define APP "Project Folder Manager"
!define EXE "ProjectFolderManager.exe"
!define KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\ProjectFolderManager"

Name "${APP}"
OutFile "ProjectFolderManager-Setup.exe"
InstallDir "$LOCALAPPDATA\ProjectFolderManager"
InstallDirRegKey HKCU "Software\ProjectFolderManager" "InstallDir"
RequestExecutionLevel user
SetCompressor /SOLID lzma
ShowInstDetails show

!include "MUI2.nsh"
!include "FileFunc.nsh"
!define MUI_ICON "icon.ico"
!define MUI_UNICON "icon.ico"
!define MUI_ABORTWARNING
!define MUI_FINISHPAGE_RUN "$INSTDIR\${EXE}"
!define MUI_FINISHPAGE_RUN_TEXT "Open ${APP} now"

!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "English"

VIProductVersion "${VERSION}.0"
VIAddVersionKey "ProductName" "${APP}"
VIAddVersionKey "CompanyName" "Excel to KML"
VIAddVersionKey "FileDescription" "${APP} installer"
VIAddVersionKey "FileVersion" "${VERSION}"
VIAddVersionKey "ProductVersion" "${VERSION}"
VIAddVersionKey "LegalCopyright" "Copyright (c) 2026 Asjad Mehmood"

Section "Install"
  ; Windows will not overwrite a running program, so close it first
  nsExec::Exec 'taskkill /F /IM "${EXE}"'
  Sleep 800

  SetOutPath "$INSTDIR"
  ; the old files go first, so nothing from an earlier version is left behind
  RMDir /r "$INSTDIR\data"
  File /r "${SOURCE}\*.*"
  File "icon.ico"

  WriteRegStr HKCU "Software\ProjectFolderManager" "InstallDir" "$INSTDIR"
  WriteUninstaller "$INSTDIR\Uninstall.exe"

  CreateDirectory "$SMPROGRAMS\${APP}"
  CreateShortcut "$SMPROGRAMS\${APP}\${APP}.lnk" "$INSTDIR\${EXE}" "" "$INSTDIR\icon.ico"
  CreateShortcut "$DESKTOP\${APP}.lnk" "$INSTDIR\${EXE}" "" "$INSTDIR\icon.ico"

  WriteRegStr HKCU "${KEY}" "DisplayName" "${APP}"
  WriteRegStr HKCU "${KEY}" "DisplayVersion" "${VERSION}"
  WriteRegStr HKCU "${KEY}" "Publisher" "Excel to KML"
  WriteRegStr HKCU "${KEY}" "URLInfoAbout" "https://www.exceltokml.com/project-folder-manager"
  WriteRegStr HKCU "${KEY}" "DisplayIcon" "$INSTDIR\icon.ico"
  WriteRegStr HKCU "${KEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKCU "${KEY}" "UninstallString" '"$INSTDIR\Uninstall.exe"'
  WriteRegStr HKCU "${KEY}" "QuietUninstallString" '"$INSTDIR\Uninstall.exe" /S'
  WriteRegDWORD HKCU "${KEY}" "NoModify" 1
  WriteRegDWORD HKCU "${KEY}" "NoRepair" 1
  ${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2
  IntFmt $0 "0x%08X" $0
  WriteRegDWORD HKCU "${KEY}" "EstimatedSize" "$0"

  ; started by the self-updater: open the new version again
  ${GetParameters} $R0
  ${GetOptions} $R0 "/UPDATE" $R1
  IfErrors +2 0
    Exec '"$INSTDIR\${EXE}"'
SectionEnd

Section "Uninstall"
  nsExec::Exec 'taskkill /F /IM "${EXE}"'
  Sleep 500
  Delete "$DESKTOP\${APP}.lnk"
  RMDir /r "$SMPROGRAMS\${APP}"
  RMDir /r "$INSTDIR"
  ; the settings and the index; "Excel to KML" goes too when nothing else of ours is in it
  RMDir /r "$APPDATA\Excel to KML\Project Folder Manager"
  RMDir "$APPDATA\Excel to KML"
  RMDir /r "$LOCALAPPDATA\Excel to KML\Project Folder Manager"
  RMDir "$LOCALAPPDATA\Excel to KML"
  DeleteRegKey HKCU "${KEY}"
  DeleteRegKey HKCU "Software\ProjectFolderManager"
SectionEnd
