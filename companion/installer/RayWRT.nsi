Unicode true
!include "MUI2.nsh"
!include "LogicLib.nsh"
!include "x64.nsh"
!ifndef RELEASE
 !define RELEASE "..\releases\final-v1-release"
!endif
!ifdef TESTMODE
 !define ID "RayWRT-Installer-Test"
 OutFile "..\..\.android-tools\RayWRT-test-setup.exe"
!else
 !define ID "RayWRT"
 OutFile "..\releases\RayWRT-v1-Windows-x64-Setup.exe"
!endif
Name "RayWRT"
Caption "RayWRT v1 Setup"
InstallDir "$LOCALAPPDATA\Programs\${ID}"
InstallDirRegKey HKCU "Software\${ID}" "InstallDir"
RequestExecutionLevel user
SetCompressor /SOLID lzma
SetCompressorDictSize 32
BrandingText "RayWRT — Router Configure"
VIProductVersion "1.0.3.0"
VIAddVersionKey "ProductName" "RayWRT Setup"
VIAddVersionKey "FileDescription" "RayWRT v1 Installer"
VIAddVersionKey "FileVersion" "1.0.3"
VIAddVersionKey "LegalCopyright" "Heygoodbye"
!define MUI_ICON "..\Assets\RayWRT.ico"
!define MUI_UNICON "..\Assets\RayWRT.ico"
!define MUI_ABORTWARNING
!define MUI_WELCOMEPAGE_TITLE "Install RayWRT v1"
!define MUI_WELCOMEPAGE_TEXT "Router Configure by Heygoodbye.$\r$\n$\r$\nThis installer adds RayWRT and an uninstaller for your Windows account. Close RayWRT before updating an existing installation."
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "${RELEASE}\LICENSE.txt"
!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!define MUI_FINISHPAGE_RUN "$INSTDIR\RayWRT.exe"
!define MUI_FINISHPAGE_RUN_NOTCHECKED
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_UNPAGE_FINISH
!insertmacro MUI_LANGUAGE "English"

Function .onInit
 ${IfNot} ${RunningX64}
  MessageBox MB_ICONSTOP "RayWRT requires 64-bit Windows."
  Abort
 ${EndIf}
 SetShellVarContext current
FunctionEnd

Section "RayWRT (required)" Main
 SectionIn RO
 SetOutPath "$INSTDIR"
 File "${RELEASE}\RayWRT.exe"
 File "${RELEASE}\README.md"
 File "${RELEASE}\LICENSE.txt"
 File "${RELEASE}\LICENSE.BouncyCastle.md"
 File "${RELEASE}\LICENSE.SSH.NET.txt"
 File "${RELEASE}\LICENSE.NET.txt"
 File "${RELEASE}\LICENSE.Microsoft.Extensions.txt"
 File "${RELEASE}\ThirdPartyNotices.NET.txt"
 WriteUninstaller "$INSTDIR\uninstall.exe"
 CreateDirectory "$SMPROGRAMS\${ID}"
 CreateShortcut "$SMPROGRAMS\${ID}\RayWRT.lnk" "$INSTDIR\RayWRT.exe"
 CreateShortcut "$SMPROGRAMS\${ID}\Uninstall RayWRT.lnk" "$INSTDIR\uninstall.exe"
 WriteRegStr HKCU "Software\${ID}" "InstallDir" "$INSTDIR"
 WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\${ID}" "DisplayName" "${ID}"
 WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\${ID}" "DisplayVersion" "1"
 WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\${ID}" "Publisher" "Heygoodbye"
 WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\${ID}" "URLInfoAbout" "https://github.com/Heygoodbye"
 WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\${ID}" "DisplayIcon" "$INSTDIR\RayWRT.exe"
 WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\${ID}" "UninstallString" '$\"$INSTDIR\uninstall.exe$\"'
 WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\${ID}" "QuietUninstallString" '$\"$INSTDIR\uninstall.exe$\" /S'
 WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\${ID}" "NoModify" 1
 WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\${ID}" "NoRepair" 1
 WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\${ID}" "EstimatedSize" 74000
SectionEnd
Section /o "Desktop shortcut" Desktop
 CreateShortcut "$DESKTOP\${ID}.lnk" "$INSTDIR\RayWRT.exe"
SectionEnd

Function un.onInit
 SetShellVarContext current
FunctionEnd
Section "Uninstall"
 Delete "$INSTDIR\RayWRT.exe"
 Delete "$INSTDIR\README.md"
 Delete "$INSTDIR\LICENSE.txt"
 Delete "$INSTDIR\LICENSE.BouncyCastle.md"
 Delete "$INSTDIR\LICENSE.SSH.NET.txt"
 Delete "$INSTDIR\LICENSE.NET.txt"
 Delete "$INSTDIR\LICENSE.Microsoft.Extensions.txt"
 Delete "$INSTDIR\ThirdPartyNotices.NET.txt"
 Delete "$INSTDIR\uninstall.exe"
 Delete "$SMPROGRAMS\${ID}\RayWRT.lnk"
 Delete "$SMPROGRAMS\${ID}\Uninstall RayWRT.lnk"
 RMDir "$SMPROGRAMS\${ID}"
 Delete "$DESKTOP\${ID}.lnk"
 DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\${ID}"
 DeleteRegKey HKCU "Software\${ID}"
 ; Remove only an empty app folder; preserve user settings and unrelated files.
 RMDir "$INSTDIR"
SectionEnd




