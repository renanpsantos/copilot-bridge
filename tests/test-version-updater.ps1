$ErrorActionPreference='Stop'
. "$PSScriptRoot\..\LucyMcpUpdate.ps1" -Library
$root=Join-Path ([IO.Path]::GetTempPath()) ('updater-fixture-'+[Guid]::NewGuid().ToString('N'))
$install=Join-Path $root 'installed';$feed=Join-Path $root 'corporate feed';$data=Join-Path $root 'profile'
[void](New-Item -ItemType Directory -Force -Path $install,$feed,$data)
function Make-Release([string]$Version){
 $release=Join-Path $root ('source-'+$Version);[void](New-Item -ItemType Directory -Path $release)
 foreach($name in @('LucyMcp.exe','LucyMcpGui.ps1','LucyMcp.ps1','bridge.mjs','verify-package.mjs','xurrent-bat-transport.mjs','LucyMcpUpdate.ps1','SingleInstance.cs')){
  $text='fixture '+$Version
  if($name -eq 'LucyMcp.ps1'){$text='exit 0'}
  [IO.File]::WriteAllText((Join-Path $release $name),$text)
 }
 if([version]$Version -ge [version]'0.3.4'){[IO.File]::WriteAllText((Join-Path $release 'CopilotBridge.exe'),('launcher '+$Version))}
 Update-Json @{version=$Version} (Join-Path $release 'app-version.json')
 $files=@(Get-ChildItem -LiteralPath $release -File|Sort-Object Name|ForEach-Object{@{path=$_.Name;sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash}})
 Update-Json @{version=$Version;files=$files} (Join-Path $release 'package-files.json')
 $zip=Join-Path $feed ('package-'+$Version+'.zip')
 $archive=[IO.Compression.ZipFile]::Open($zip,[IO.Compression.ZipArchiveMode]::Create)
 try{foreach($f in Get-ChildItem -LiteralPath $release -File){[void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive,$f.FullName,('LucyMcpCli/'+$f.Name),[IO.Compression.CompressionLevel]::Optimal)}}finally{$archive.Dispose()}
 Update-Json @{version=$Version;package=[IO.Path]::GetFileName($zip);sha256=(Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash;release_notes='Fixture release'} (Join-Path $feed 'version.json')
 return $release
}
$old=Make-Release '0.3.0';Copy-Item -Path (Join-Path $old '*') -Destination $install
$new=Make-Release '0.3.4'
[IO.File]::WriteAllText((Join-Path $data 'key.dpapi'),'secret-fixture')
$secretHash=(Get-FileHash -LiteralPath (Join-Path $data 'key.dpapi')).Hash
$info=Get-UpdateInfo (Join-Path $feed 'version.json') $install
if(!$info.available){throw 'New version not detected'}
$plan=Prepare-Update (Join-Path $feed 'version.json') $install $data
$result=Apply-Update $plan -NoRestart
if((Get-Content -Raw (Join-Path $install 'app-version.json')|ConvertFrom-Json).version -ne '0.3.4'){throw 'Version not installed'}
if((Split-Path (Update-Launcher $install) -Leaf) -ne 'CopilotBridge.exe'){throw 'New launcher not selected after migration'}
if((Get-FileHash -LiteralPath (Join-Path $data 'key.dpapi')).Hash -ne $secretHash){throw 'Profile changed'}
if(!(Test-Path -LiteralPath (Join-Path $result.backupPath 'app-version.json'))){throw 'Backup missing'}
Write-Output 'PASS: update applied, backup created and profile preserved.'
[void](Make-Release '0.3.5')
$manifest=Join-Path $feed 'version.json';$bad=Get-Content -Raw $manifest|ConvertFrom-Json;$goodHash=$bad.sha256;$bad.sha256=('0'*64);Update-Json $bad $manifest
$failed=$false;try{Prepare-Update $manifest $install $data|Out-Null}catch{$failed=$true}
if(!$failed){throw 'Invalid ZIP checksum accepted'}
$bad.sha256=$goodHash;Update-Json $bad $manifest
$plan2=Prepare-Update $manifest $install $data
$lockedFile=Join-Path $install 'LucyMcpGui.ps1'
$handle=[IO.File]::Open($lockedFile,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
try{
 $failed=$false;try{Apply-Update $plan2 -NoRestart|Out-Null}catch{$failed=$true}
 if(!$failed){throw 'Locked destination did not reject update'}
}finally{$handle.Dispose()}
foreach($f in Get-ChildItem -LiteralPath $new -File){if((Get-FileHash -LiteralPath (Join-Path $install $f.Name)).Hash -ne (Get-FileHash -LiteralPath $f.FullName).Hash){throw ('Rollback mismatch: '+$f.Name)}}
Write-Output 'PASS: invalid checksum rejected; failed replacement restores the previous files.'
$malicious=Join-Path $feed 'malicious.zip';$archive=[IO.Compression.ZipFile]::Open($malicious,[IO.Compression.ZipArchiveMode]::Create)
try{$e=$archive.CreateEntry('LucyMcpCli/../../escape.txt');$w=New-Object IO.StreamWriter($e.Open());try{$w.Write('bad')}finally{$w.Dispose()}}finally{$archive.Dispose()}
Update-Json @{version='0.4.0';package='malicious.zip';sha256=(Get-FileHash $malicious).Hash} $manifest
$failed=$false;try{Prepare-Update $manifest $install $data|Out-Null}catch{$failed=$true}
if(!$failed -or (Test-Path (Join-Path $root 'escape.txt'))){throw 'ZIP traversal accepted'}
Write-Output 'PASS: ZIP traversal rejected. No real installation, services or network used.'
$legacyCode=& git -C (Join-Path $PSScriptRoot '..') show v0.3.3:LucyMcpUpdate.ps1
if($LASTEXITCODE -ne 0){throw 'Previous updater unavailable for migration test'}
$legacyHelper=Join-Path $root 'legacy-updater.ps1';[IO.File]::WriteAllText($legacyHelper,($legacyCode -join "`r`n"))
$legacyInstall=Join-Path $root 'legacy-install';$legacyData=Join-Path $root 'legacy-profile'
[void](New-Item -ItemType Directory -Path $legacyInstall,$legacyData)
Copy-Item -Path (Join-Path $old '*') -Destination $legacyInstall
[void](Make-Release '0.3.6')
. $legacyHelper -Library
$legacyPlan=Prepare-Update $manifest $legacyInstall $legacyData
[void](Apply-Update $legacyPlan -NoRestart)
if(!(Test-Path (Join-Path $legacyInstall 'CopilotBridge.exe')) -or !(Test-Path (Join-Path $legacyInstall 'LucyMcp.exe'))){throw 'Legacy updater migration failed'}
Write-Output 'PASS: unmodified v0.3.3 updater accepts the new package and installs CopilotBridge.exe with its compatibility launcher.'
