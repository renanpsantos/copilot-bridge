param(
 [string]$OutputDirectory=(Join-Path (Split-Path $PSScriptRoot -Parent) 'outputs'),
 [string]$DependencyDirectory=(Join-Path $PSScriptRoot 'node_modules')
)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.IO.Compression
$source=$PSScriptRoot
$metadata=Get-Content -Raw -LiteralPath (Join-Path $source 'app-version.json')|ConvertFrom-Json
if($metadata.version -notmatch '^\d+\.\d+\.\d+$'){throw 'app-version.json deve usar major.minor.patch.'}
$package=Get-Content -Raw -LiteralPath (Join-Path $source 'package.json')|ConvertFrom-Json
$lockText=Get-Content -Raw -LiteralPath (Join-Path $source 'package-lock.json')
$lockMatch=[regex]::Match($lockText,'(?s)"":\s*\{.*?"version":\s*"([^"]+)"')
if($package.version -ne $metadata.version -or !$lockMatch.Success -or $lockMatch.Groups[1].Value -ne $metadata.version){throw 'Sincronize package.json e package-lock.json com app-version.json.'}
foreach($dependency in @('@modelcontextprotocol\sdk','express')){
 $installed=Get-Content -Raw -LiteralPath (Join-Path $DependencyDirectory ($dependency+'\package.json'))|ConvertFrom-Json
 $name=$dependency.Replace('\','/')
 if($installed.version -ne $package.dependencies.$name){throw ('Dependencia nao corresponde ao lock: '+$name)}
}
$compiler=Join-Path $env:SystemRoot 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if(!(Test-Path -LiteralPath $compiler)){$compiler=Join-Path $env:SystemRoot 'Microsoft.NET\Framework\v4.0.30319\csc.exe'}
Push-Location $source
try{
 & $compiler /nologo /target:winexe /reference:System.Windows.Forms.dll /win32icon:logo.ico /out:CopilotBridge.exe GuiLauncher.cs
 if($LASTEXITCODE -ne 0){throw 'Falha ao compilar CopilotBridge.exe.'}
 & $compiler /nologo /target:winexe /reference:System.Windows.Forms.dll /win32icon:logo.ico /out:LucyMcp.exe LegacyLauncher.cs
 if($LASTEXITCODE -ne 0){throw 'Falha ao compilar o iniciador de compatibilidade.'}
}finally{Pop-Location}
$files=New-Object Collections.Generic.List[object]
foreach($file in Get-ChildItem -LiteralPath $source -File){
 if($file.Name -in @('package-files.json','version.json','build.ps1','generate-logo.ps1','.gitignore')){continue}
 if($file.Extension -notin @('.ps1','.mjs','.cmd','.exe','.json','.md','.cs','.png','.ico','.svg')){continue}
 if($file.Name -in @('config.json','processes.json')){throw 'Dados pessoais encontrados na pasta fonte.'}
 $files.Add(@{path=$file.Name;source=$file.FullName;sha256=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash})
}
$depRoot=[IO.Path]::GetFullPath($DependencyDirectory).TrimEnd('\')
foreach($file in Get-ChildItem -LiteralPath $depRoot -File -Recurse -Force){
 if($file.Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Dependencias com links nao sao suportadas no build portatil.'}
 $relative='node_modules/'+$file.FullName.Substring($depRoot.Length+1).Replace('\','/')
 $files.Add(@{path=$relative;source=$file.FullName;sha256=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash})
}
[void](New-Item -ItemType Directory -Force -Path $OutputDirectory)
$work=Join-Path ([IO.Path]::GetTempPath()) ('lucy-mcp-build-'+[Guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $work)
$inventory=Join-Path $work 'package-files.json'
$entries=@($files|ForEach-Object {@{path=$_.path;sha256=$_.sha256}})
[IO.File]::WriteAllText($inventory,(@{version=$metadata.version;files=$entries}|ConvertTo-Json -Depth 6))
$zipPath=Join-Path $work 'LucyMcpCli-fixed-portable.zip'
$archive=[IO.Compression.ZipFile]::Open($zipPath,[IO.Compression.ZipArchiveMode]::Create)
try{
 foreach($file in $files){[void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive,$file.source,('LucyMcpCli/'+$file.path),[IO.Compression.CompressionLevel]::Optimal)}
 [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive,$inventory,'LucyMcpCli/package-files.json',[IO.Compression.CompressionLevel]::Optimal)
}finally{$archive.Dispose()}
$manifest=@{version=$metadata.version;package='LucyMcpCli-fixed-portable.zip';sha256=(Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash;release_notes=$metadata.release_notes;built_at=[DateTime]::UtcNow.ToString('o')}
$manifest.download_url='https://github.com/renanpsantos/copilot-bridge/releases/download/v'+$metadata.version+'/'+$manifest.package
# Copy the package first, then the manifest, also when publishing to a sync folder.
Copy-Item -LiteralPath $zipPath -Destination (Join-Path $OutputDirectory $manifest.package) -Force
[IO.File]::WriteAllText((Join-Path $OutputDirectory 'version.json'),($manifest|ConvertTo-Json -Depth 5))
Write-Output ('Build v'+$metadata.version+' concluido: '+$files.Count+' arquivos inventariados.')
Write-Output (Join-Path $OutputDirectory 'version.json')
