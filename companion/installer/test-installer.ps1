$ErrorActionPreference='Stop'
$workspace=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$testRoot=Join-Path $workspace '.android-tools/installer-test'
$setup=Join-Path $workspace '.android-tools/RayWRT-test-setup.exe'
$key='HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\RayWRT-Installer-Test'
if(Test-Path $key){throw 'Previous test installation exists; inspect before running.'}
$p=Start-Process -FilePath $setup -ArgumentList @('/S',('/D='+$testRoot)) -WindowStyle Hidden -PassThru
$p.WaitForExit();if($p.ExitCode -ne 0){throw 'Installer failed.'}
$exe=Join-Path $testRoot 'RayWRT.exe'
if((Get-FileHash $exe).Hash -ne (Get-FileHash (Join-Path $workspace 'companion/releases/final-v1.0.0/RayWRT.exe')).Hash){throw 'Installed app hash mismatch.'}
$uninstall=Join-Path $testRoot 'uninstall.exe'
if(!(Test-Path $uninstall)){throw 'Uninstaller missing.'}
$entry=Get-ItemProperty $key
if($entry.DisplayVersion -ne '1.0.0' -or $entry.UninstallString -notlike '*uninstall.exe*'){throw 'Installed Apps registration failed.'}
$shortcut=Join-Path ([Environment]::GetFolderPath('Programs')) 'RayWRT-Installer-Test/RayWRT.lnk'
if(!(Test-Path $shortcut)){throw 'Start menu shortcut missing.'}
$wsh=New-Object -ComObject WScript.Shell
if($wsh.CreateShortcut($shortcut).TargetPath -ne $exe){throw 'Shortcut target incorrect.'}
$settings=Join-Path $testRoot 'router-settings.json'
Set-Content -LiteralPath $settings -Value '{}' -Encoding utf8
$p=Start-Process -FilePath $setup -ArgumentList @('/S',('/D='+$testRoot)) -WindowStyle Hidden -PassThru
$p.WaitForExit();if($p.ExitCode -ne 0 -or !(Test-Path $settings)){throw 'Reinstall failed or settings removed.'}
$p=Start-Process -FilePath $uninstall -ArgumentList '/S' -WindowStyle Hidden -PassThru
$p.WaitForExit()
$deadline=(Get-Date).AddSeconds(20)
while((Test-Path $exe) -and (Get-Date) -lt $deadline){Start-Sleep -Milliseconds 200}
if((Test-Path $exe) -or (Test-Path $key) -or (Test-Path $shortcut)){throw 'Uninstall left installed app, registry entry or shortcuts.'}
if(!(Test-Path $settings)){throw 'Uninstall removed user settings.'}
Write-Output 'PASS: install payload hash, uninstall.exe, registry, Start menu shortcut, reinstall, uninstall and settings preservation.'
