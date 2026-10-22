param([Parameter(Mandatory=$true)][string]$ManifestPath)
$ErrorActionPreference='Stop'
. "$PSScriptRoot\..\LucyMcpUpdate.ps1" -Library
$root=Join-Path ([IO.Path]::GetTempPath()) ('lucy-distribution-test-'+[Guid]::NewGuid().ToString('N'))
$install=Join-Path $root 'installed';$data=Join-Path $root 'profile'
[void](New-Item -ItemType Directory -Force -Path $install,$data)
[IO.File]::WriteAllText((Join-Path $install 'app-version.json'),'{"version":"0.0.0"}')
$plan=Prepare-Update $ManifestPath $install $data
$inventory=Test-UpdateInventory $plan.stagePath $plan.version
$sdk=Join-Path $plan.stagePath 'node_modules\@modelcontextprotocol\sdk\dist\esm\client\index.js'
if(!(Test-Path -LiteralPath $sdk)){throw 'SDK client missing from the distribution.'}
Write-Output ('PASS: distribution v'+$plan.version+' extracted and verified: '+@($inventory.files).Count+' files, including the MCP SDK client.')
Write-Output ('Isolated staged package: '+$plan.stagePath)
