param([string]$JavaHome='C:/Program Files/Java/jdk-25.0.2')
$ErrorActionPreference='Stop'
$projectRoot=$PSScriptRoot
$workspaceRoot=Split-Path $projectRoot -Parent
$toolRoot=Join-Path $workspaceRoot '.android-tools'
$sdkRoot=Join-Path $toolRoot 'sdk'
$buildRoot=Join-Path $projectRoot '.build'
$releaseRoot=Join-Path $projectRoot 'releases'
$signingRoot=Join-Path $projectRoot '.signing'
$java=Join-Path $JavaHome 'bin/java.exe'
$javac=Join-Path $JavaHome 'bin/javac.exe'
$jar=Join-Path $JavaHome 'bin/jar.exe'
$keytool=Join-Path $JavaHome 'bin/keytool.exe'
function Invoke-Checked([string]$Program,[string[]]$Arguments) { & $Program @Arguments; if($LASTEXITCODE -ne 0){throw "$Program failed with code $LASTEXITCODE"} }
function Get-Verified([string]$Url,[string]$Path,[string]$Sha1) {
 if(!(Test-Path -LiteralPath $Path)){Invoke-WebRequest -Uri $Url -OutFile $Path}
 if($Sha1 -and (Get-FileHash -LiteralPath $Path -Algorithm SHA1).Hash.ToLowerInvariant() -ne $Sha1){throw "Checksum mismatch for $Path"}
}
New-Item -ItemType Directory -Force -Path $toolRoot,$buildRoot,$releaseRoot,$signingRoot,(Join-Path $buildRoot 'classes'),(Join-Path $buildRoot 'generated'),(Join-Path $buildRoot 'dex') | Out-Null
Get-Verified 'https://redirector.gvt1.com/edgedl/android/repository/platform-36_r02.zip' (Join-Path $toolRoot 'platform.zip') '2c1a80dd4d9f7d0e6dd336ec603d9b5c55a6f576'
Get-Verified 'https://redirector.gvt1.com/edgedl/android/repository/build-tools_r36_windows.zip' (Join-Path $toolRoot 'build-tools.zip') 'f16ccffd34de8790dede813a6c7d8e2c11a27b50'
if(!(Test-Path (Join-Path $sdkRoot 'platforms/android-36/android.jar'))){Expand-Archive -LiteralPath (Join-Path $toolRoot 'platform.zip') -DestinationPath (Join-Path $sdkRoot 'platforms') -Force}
if(!(Test-Path (Join-Path $sdkRoot 'build-tools/android-16/aapt2.exe'))){Expand-Archive -LiteralPath (Join-Path $toolRoot 'build-tools.zip') -DestinationPath (Join-Path $sdkRoot 'build-tools') -Force}
Get-Verified 'https://repo.maven.apache.org/maven2/com/github/mwiede/jsch/2.28.7/jsch-2.28.7.jar' (Join-Path $toolRoot 'jsch.jar') ''
Get-Verified 'https://repo.maven.apache.org/maven2/org/bouncycastle/bcprov-jdk18on/1.83/bcprov-jdk18on-1.83.jar' (Join-Path $toolRoot 'bcprov.jar') ''
# Remove desktop multi-release variants and signatures before compiling Android bytecode.
Add-Type -AssemblyName System.IO.Compression
foreach($name in @('jsch','bcprov')) {
 $inputArchive=[System.IO.Compression.ZipFile]::OpenRead((Join-Path $toolRoot "$name.jar"))
 $outputFile=Join-Path $buildRoot "$name-android.jar"
 if(Test-Path $outputFile){Remove-Item -LiteralPath $outputFile}
 $outputArchive=[System.IO.Compression.ZipFile]::Open($outputFile,[System.IO.Compression.ZipArchiveMode]::Create)
 try {foreach($entry in $inputArchive.Entries){
  if($entry.FullName.StartsWith('META-INF/versions/') -or $entry.FullName -eq 'module-info.class' -or $entry.FullName -match '^META-INF/.*\.(SF|RSA|DSA)$' -or !$entry.Name){continue}
  $new=$outputArchive.CreateEntry($entry.FullName,[System.IO.Compression.CompressionLevel]::Optimal)
  $src=$entry.Open();$dst=$new.Open();try{$src.CopyTo($dst)}finally{$src.Dispose();$dst.Dispose()}
 }} finally {$outputArchive.Dispose();$inputArchive.Dispose()}
}
$tools=Join-Path $sdkRoot 'build-tools/android-16'
$androidJar=Join-Path $sdkRoot 'platforms/android-36/android.jar'
$mainRoot=Join-Path $projectRoot 'app/src/main'
Invoke-Checked (Join-Path $tools 'aapt2.exe') @('compile','--dir',(Join-Path $mainRoot 'res'),'-o',(Join-Path $buildRoot 'resources.zip'))
Invoke-Checked (Join-Path $tools 'aapt2.exe') @('link','-o',(Join-Path $buildRoot 'unsigned.apk'),'-I',$androidJar,'--manifest',(Join-Path $mainRoot 'AndroidManifest.xml'),'--java',(Join-Path $buildRoot 'generated'),'-A',(Join-Path $mainRoot 'assets'),'--min-sdk-version','26','--target-sdk-version','36','--auto-add-overlay','-R',(Join-Path $buildRoot 'resources.zip'))
$classpath=$androidJar+';'+(Join-Path $buildRoot 'jsch-android.jar')+';'+(Join-Path $buildRoot 'bcprov-android.jar')
$sourceFiles=@(Get-ChildItem -LiteralPath (Join-Path $mainRoot 'java') -Recurse -Filter '*.java' | ForEach-Object {$_.FullName})+@(Get-ChildItem -LiteralPath (Join-Path $buildRoot 'generated') -Recurse -Filter '*.java' | ForEach-Object {$_.FullName})
Invoke-Checked $javac (@('-encoding','UTF-8','-source','8','-target','8','-Xlint:-options','-classpath',$classpath,'-d',(Join-Path $buildRoot 'classes'))+$sourceFiles)
Invoke-Checked $jar @('cf',(Join-Path $buildRoot 'app.jar'),'-C',(Join-Path $buildRoot 'classes'),'.')
Invoke-Checked $java @('-cp',(Join-Path $tools 'lib/d8.jar'),'com.android.tools.r8.D8','--release','--min-api','26','--lib',$androidJar,'--output',(Join-Path $buildRoot 'dex'),(Join-Path $buildRoot 'app.jar'),(Join-Path $buildRoot 'jsch-android.jar'),(Join-Path $buildRoot 'bcprov-android.jar'))
$archive=[System.IO.Compression.ZipFile]::Open((Join-Path $buildRoot 'unsigned.apk'),[System.IO.Compression.ZipArchiveMode]::Update)
try {foreach($dex in (Get-ChildItem (Join-Path $buildRoot 'dex') -Filter '*.dex')) {[System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive,$dex.FullName,$dex.Name,[System.IO.Compression.CompressionLevel]::Optimal)|Out-Null}}finally{$archive.Dispose()}
Invoke-Checked (Join-Path $tools 'zipalign.exe') @('-f','-p','4',(Join-Path $buildRoot 'unsigned.apk'),(Join-Path $buildRoot 'aligned.apk'))
$keystore=Join-Path $signingRoot 'release.p12'
$passwordFile=Join-Path $signingRoot 'password.txt'
if(!(Test-Path -LiteralPath $keystore)) {
 $random=[byte[]]::new(32);[Security.Cryptography.RandomNumberGenerator]::Fill($random)
 [IO.File]::WriteAllText($passwordFile,[Convert]::ToHexString($random))
 Invoke-Checked $keytool @('-genkeypair','-keystore',$keystore,'-storetype','PKCS12','-alias','raywrt','-keyalg','RSA','-keysize','3072','-validity','10000','-dname','CN=Heygoodbye, OU=RayWRT Companion','-storepass:file',$passwordFile,'-keypass:file',$passwordFile)
}
$apk=Join-Path $releaseRoot 'RayWRT-v1-Android-universal.apk'
Invoke-Checked $java @('-jar',(Join-Path $tools 'lib/apksigner.jar'),'sign','--ks',$keystore,'--ks-key-alias','raywrt','--ks-pass',"file:$passwordFile",'--v1-signing-enabled','true','--v2-signing-enabled','true','--v3-signing-enabled','true','--v4-signing-enabled','false','--out',$apk,(Join-Path $buildRoot 'aligned.apk'))
Invoke-Checked $java @('-jar',(Join-Path $tools 'lib/apksigner.jar'),'verify','--verbose',$apk)
Get-Item $apk | Select-Object FullName,Length











