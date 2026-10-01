# RayWRT Windows installer

`companion/releases/setup.exe` installs RayWRT v1.0 for the current Windows user under `%LOCALAPPDATA%\Programs\RayWRT` by default. It adds Start menu shortcuts, an optional desktop shortcut, an Installed Apps entry and `uninstall.exe` in the installation folder.

Run uninstall.exe or use Windows Settings > Apps > Installed apps > RayWRT > Uninstall. The uninstaller removes only installed files and shortcuts; saved router fingerprints and any unrelated files remain. Close RayWRT before updating or uninstalling.

The installer contains the final Windows v1.0 payload based on v1.1.7. It is unsigned because a trusted Windows code-signing certificate is not configured.

Build with NSIS 3.12: `makensis RayWRT.nsi` from this folder. The script uses an explicit file list to exclude settings, debug symbols and test captures. Compile with `/DTESTMODE` to use an isolated test registry key and shortcut names, then run test-installer.ps1. The test checks install, reinstall, shortcuts, payload integrity, uninstaller and settings preservation.
