param([string]$ManifestPath='https://github.com/renanpsantos/copilot-bridge/releases/download/v0.3.2/version.json')
$ErrorActionPreference='Stop'
. "$PSScriptRoot\..\LucyMcpUpdate.ps1" -Library
foreach($bad in @('http://github.com/renanpsantos/copilot-bridge/version.json','https://example.com/version.json','https://github.com/another/repository/version.json','https://user:pass@github.com/renanpsantos/copilot-bridge/version.json')){
 $rejected=$false;try{[void](Update-RemoteUri $bad)}catch{$rejected=$true}
 if(!$rejected){throw 'Untrusted URL accepted'}
}
$root=Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) ('work\gh-'+[Guid]::NewGuid().ToString('N').Substring(0,8))
$install=Join-Path $root 'app';$data=Join-Path $root 'data'
[void](New-Item -ItemType Directory -Force -Path $install,$data)
[IO.File]::WriteAllText((Join-Path $install 'app-version.json'),'{"version":"0.0.0"}')
$info=Get-UpdateInfo $ManifestPath $install
if(!$info.remote -or !$info.available){throw 'Remote version check failed'}
$plan=Prepare-Update $ManifestPath $install $data
if(!(Test-Path -LiteralPath (Join-Path $plan.stagePath 'node_modules\@modelcontextprotocol\sdk\dist\esm\client\index.js'))){throw 'Downloaded package missing SDK'}
Write-Output ('PASS: anonymous HTTPS manifest and ZIP download, SHA-256, full inventory and SDK verified for v'+$plan.version+'.')
Write-Output 'PASS: HTTP, external repositories and embedded credentials rejected. No installed application or services changed.'
