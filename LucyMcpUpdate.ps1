param([string]$RequestPath,[switch]$Library)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.IO.Compression
function Update-Version([string]$Text){
 if($Text -notmatch '^v?(\d+)\.(\d+)(?:\.(\d+))?$'){throw 'Versao invalida no manifesto. Use major.minor.patch.'}
 $patch=if($Matches[3]){[int]$Matches[3]}else{0}
 return New-Object Version([int]$Matches[1],[int]$Matches[2],$patch)
}
function Update-Json($Value,[string]$Path){[IO.File]::WriteAllText($Path,($Value|ConvertTo-Json -Depth 12))}
function Update-Launcher([string]$InstallPath){
 foreach($name in @('CopilotBridge.exe','LucyMcp.exe')){
  $launcher=Join-Path $InstallPath $name
  if(Test-Path -LiteralPath $launcher -PathType Leaf){return $launcher}
 }
 throw 'Executavel do Copilot Bridge nao encontrado na instalacao.'
}
function Update-RemoteUri([string]$Url){
 $uri=$null
 if(![Uri]::TryCreate($Url,[UriKind]::Absolute,[ref]$uri) -or $uri.Scheme -ne 'https' -or $uri.UserInfo -or !$uri.IsDefaultPort){throw 'Fonte remota invalida. Use HTTPS do repositorio copilot-bridge.'}
 $valid=($uri.Host -eq 'github.com' -and $uri.AbsolutePath.StartsWith('/renanpsantos/copilot-bridge/',[StringComparison]::OrdinalIgnoreCase)) -or ($uri.Host -eq 'raw.githubusercontent.com' -and $uri.AbsolutePath.StartsWith('/renanpsantos/copilot-bridge/',[StringComparison]::OrdinalIgnoreCase))
 if(!$valid){throw 'A fonte remota deve pertencer ao repositorio renanpsantos/copilot-bridge.'}
 return $uri
}
function Receive-UpdateRemote([string]$Url,[string]$Destination,[long]$MaxBytes){
 $uri=Update-RemoteUri $Url
 [Net.ServicePointManager]::SecurityProtocol=[Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
 for($redirect=0;$redirect -le 8;$redirect++){
  $request=[Net.HttpWebRequest]::Create($uri);$request.AllowAutoRedirect=$false;$request.Timeout=30000;$request.ReadWriteTimeout=30000;$request.UserAgent='LucyMcp-Updater'
  $response=$null
  try{$response=$request.GetResponse()}catch{throw 'Nao foi possivel baixar a atualizacao do GitHub. Confira a internet e a disponibilidade da release.'}
  try{
   if([int]$response.StatusCode -in @(301,302,303,307,308)){
    $uri=New-Object Uri($uri,$response.Headers['Location'])
    if($uri.Scheme -ne 'https' -or $uri.UserInfo -or !$uri.IsDefaultPort -or $uri.Host -notin @('github.com','raw.githubusercontent.com','release-assets.githubusercontent.com','objects.githubusercontent.com')){throw 'Redirecionamento de download nao autorizado.'}
    continue
   }
   if($response.ContentLength -gt $MaxBytes){throw 'Download excede o tamanho permitido.'}
   $inputStream=$response.GetResponseStream()
   $outputStream=if($Destination){[IO.File]::Create($Destination)}else{New-Object IO.MemoryStream}
   try{
    $buffer=New-Object byte[] 65536;$total=0L
    while(($read=$inputStream.Read($buffer,0,$buffer.Length)) -gt 0){$total+=$read;if($total -gt $MaxBytes){throw 'Download excede o tamanho permitido.'};$outputStream.Write($buffer,0,$read)}
    if(!$Destination){return [Text.Encoding]::UTF8.GetString($outputStream.ToArray()).TrimStart([char]0xfeff)}
   }finally{$inputStream.Dispose();$outputStream.Dispose()}
   return
  }finally{$response.Dispose()}
 }
 throw 'Quantidade excessiva de redirecionamentos no download.'
}
function Update-ChildPath([string]$Root,[string]$Relative){
 $relativePath=$Relative.Replace('\','/')
 if(!$relativePath -or $relativePath -match '[:\x00-\x1f]' -or $relativePath.StartsWith('/') -or @($relativePath.Split('/')|Where-Object {$_ -eq '..' -or $_ -eq '.'}).Count){throw 'Caminho inseguro dentro do pacote.'}
 $base=[IO.Path]::GetFullPath($Root).TrimEnd('\')+'\'
 $target=[IO.Path]::GetFullPath((Join-Path $Root $relativePath.Replace('/','\')))
 if(!$target.StartsWith($base,[StringComparison]::OrdinalIgnoreCase)){throw 'Arquivo fora da pasta permitida.'}
 return $target
}
function Get-UpdateInfo([string]$ManifestPath,[string]$InstallPath){
 $remote=$ManifestPath -match '^https?://'
 if($remote){$manifest=(Receive-UpdateRemote $ManifestPath '' 1048576)|ConvertFrom-Json}else{
  $manifestFile=Get-Item -LiteralPath $ManifestPath -ErrorAction Stop
  if($manifestFile.PSIsContainer -or $manifestFile.Length -gt 1048576){throw 'Selecione um version.json valido na pasta corporativa sincronizada.'}
  $manifest=Get-Content -Raw -LiteralPath $manifestFile.FullName|ConvertFrom-Json
  $ManifestPath=$manifestFile.FullName
 }
 $latest=Update-Version $manifest.version
 $installed=(Get-Content -Raw -LiteralPath (Join-Path $InstallPath 'app-version.json')|ConvertFrom-Json).version
 $current=Update-Version $installed
 if($manifest.sha256 -notmatch '^[a-fA-F0-9]{64}$'){throw 'Manifesto sem SHA-256 valido do ZIP.'}
 if(!$manifest.package -or $manifest.package -notmatch '\.zip$'){throw 'Manifesto sem nome de pacote ZIP.'}
 if($remote){
  if($manifest.package -ne 'LucyMcpCli-fixed-portable.zip'){throw 'Nome de pacote remoto invalido.'}
  $downloadUrl=if($manifest.download_url){[string]$manifest.download_url}else{(New-Object Uri((Update-RemoteUri $ManifestPath),$manifest.package)).AbsoluteUri}
  $zip=(Update-RemoteUri $downloadUrl).AbsoluteUri
 }else{$zip=Update-ChildPath $manifestFile.DirectoryName $manifest.package}
 return [pscustomobject]@{version=$manifest.version;current=$installed;available=($latest -gt $current);release_notes=[string]$manifest.release_notes;sha256=$manifest.sha256;packagePath=$zip;manifestPath=$ManifestPath;remote=$remote}
}
function Test-UpdateInventory([string]$StagePath,[string]$ExpectedVersion){
 $inventory=Get-Content -Raw -LiteralPath (Join-Path $StagePath 'package-files.json')|ConvertFrom-Json
 if((Update-Version $inventory.version) -ne (Update-Version $ExpectedVersion)){throw 'Versao do inventario difere do manifesto.'}
 $metadata=Get-Content -Raw -LiteralPath (Join-Path $StagePath 'app-version.json')|ConvertFrom-Json
 if((Update-Version $metadata.version) -ne (Update-Version $ExpectedVersion)){throw 'Versao do aplicativo difere do manifesto.'}
 $files=@($inventory.files)
 if(!$files.Count -or $files.Count -gt 15000){throw 'Quantidade invalida de arquivos no inventario.'}
 $seen=@{}
 foreach($file in $files){
  $name=[string]$file.path
  if($seen.ContainsKey($name)){throw 'Arquivo repetido no inventario.'};$seen[$name]=$true
  $target=Update-ChildPath $StagePath $name
  if($name -match '(^|/)(config\.json|key\.dpapi|ngrok\.dpapi|processes\.json|\.git)(/|$)'){throw 'Pacote contem dados de usuario ou repositorio.'}
  if($file.sha256 -notmatch '^[a-fA-F0-9]{64}$' -or !(Test-Path -LiteralPath $target -PathType Leaf)){throw ('Arquivo ausente ou invalido no pacote: '+$name)}
  if((Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -ne $file.sha256){throw ('Integridade do arquivo invalida: '+$name)}
 }
 foreach($required in @('LucyMcp.exe','LucyMcpGui.ps1','LucyMcp.ps1','bridge.mjs','app-version.json','verify-package.mjs','xurrent-bat-transport.mjs','LucyMcpUpdate.ps1','SingleInstance.cs')){
  if(!$seen.ContainsKey($required)){throw ('Pacote incompleto: '+$required)}
 }
 if((Update-Version $ExpectedVersion) -ge [version]'0.3.4' -and !$seen.ContainsKey('CopilotBridge.exe')){throw 'Pacote incompleto: CopilotBridge.exe'}
 foreach($file in Get-ChildItem -LiteralPath $StagePath -File -Recurse){
  $name=$file.FullName.Substring($StagePath.TrimEnd('\').Length+1).Replace('\','/')
  if($name -ne 'package-files.json' -and !$seen.ContainsKey($name)){throw ('Arquivo nao inventariado: '+$name)}
 }
 return $inventory
}
function Prepare-Update([string]$ManifestPath,[string]$InstallPath,[string]$DataDirectory){
 $info=Get-UpdateInfo $ManifestPath $InstallPath
 if(!$info.available){throw 'Nao ha versao mais nova para instalar.'}
 if(!$info.remote){$zipInfo=Get-Item -LiteralPath $info.packagePath;if($zipInfo.Length -gt 104857600){throw 'Pacote excede o limite de 100 MB.'}}
 $updates=Join-Path $DataDirectory 'updates';[void](New-Item -ItemType Directory -Force -Path $updates)
 $work=Join-Path $updates ([Guid]::NewGuid().ToString('N'));[void](New-Item -ItemType Directory -Path $work)
 $cachedZip=Join-Path $work 'package.zip'
 if($info.remote){Receive-UpdateRemote $info.packagePath $cachedZip 104857600}else{Copy-Item -LiteralPath $zipInfo.FullName -Destination $cachedZip}
 if((Get-FileHash -LiteralPath $cachedZip -Algorithm SHA256).Hash -ne $info.sha256){throw 'SHA-256 do ZIP nao confere. A copia sincronizada pode estar incompleta; aguarde a sincronizacao e tente de novo.'}
 $extract=Join-Path $work 'extracted';[void](New-Item -ItemType Directory -Path $extract)
 $archive=[IO.Compression.ZipFile]::OpenRead($cachedZip)
 try{
  if($archive.Entries.Count -gt 16000){throw 'Pacote com arquivos demais.'}
  $seen=@{};$size=0L
  foreach($entry in $archive.Entries){
   $name=$entry.FullName.Replace('\','/')
   if(!$name.StartsWith('LucyMcpCli/',[StringComparison]::Ordinal)){throw 'Estrutura inesperada no ZIP.'}
   $size+=$entry.Length;if($size -gt 524288000){throw 'Conteudo descompactado excede 500 MB.'}
   $trimmed=$name.TrimEnd('/');if(!$trimmed){continue}
   $target=Update-ChildPath $extract $trimmed
   if($seen.ContainsKey($target)){throw 'Caminho duplicado no ZIP.'};$seen[$target]=$true
   if((($entry.ExternalAttributes -shr 16) -band 61440) -eq 40960){throw 'Links simbolicos nao sao permitidos no ZIP.'}
   if($name.EndsWith('/')){[void](New-Item -ItemType Directory -Force -Path $target);continue}
   [void](New-Item -ItemType Directory -Force -Path (Split-Path $target -Parent))
   [IO.Compression.ZipFileExtensions]::ExtractToFile($entry,$target,$false)
  }
 }finally{$archive.Dispose()}
 $stage=Join-Path $extract 'LucyMcpCli'
 [void](Test-UpdateInventory $stage $info.version)
 return @{version=$info.version;stagePath=$stage;workPath=$work;installPath=[IO.Path]::GetFullPath($InstallPath);dataDirectory=[IO.Path]::GetFullPath($DataDirectory)}
}
function Apply-Update($Plan,[int]$GuiPid=0,[string]$GuiStarted='', [switch]$NoRestart){
 $install=[IO.Path]::GetFullPath($Plan.installPath).TrimEnd('\')
 $stage=[IO.Path]::GetFullPath($Plan.stagePath).TrimEnd('\')
 $data=[IO.Path]::GetFullPath($Plan.dataDirectory).TrimEnd('\')
 $updates=[IO.Path]::GetFullPath((Join-Path $data 'updates')).TrimEnd('\')+'\'
 $work=[IO.Path]::GetFullPath($Plan.workPath).TrimEnd('\')
 if(!$work.StartsWith($updates,[StringComparison]::OrdinalIgnoreCase) -or $stage -ne (Join-Path $work 'extracted\LucyMcpCli') -or $stage.StartsWith($install+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Area temporaria de atualizacao invalida.'}
 if($data -eq $install -or $data.StartsWith($install+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'A pasta de dados deve estar fora da instalacao.'}
 if(!(Test-Path -LiteralPath (Join-Path $install 'LucyMcp.ps1'))){throw 'Pasta de instalacao invalida.'}
 [void](Update-Launcher $install)
 $inventory=Test-UpdateInventory $stage $Plan.version
 if($GuiPid){
  $deadline=[DateTime]::UtcNow.AddSeconds(45)
  do{
   $gui=Get-Process -Id $GuiPid -ErrorAction SilentlyContinue
   if(!$gui -or $gui.StartTime.ToUniversalTime().Ticks.ToString() -ne $GuiStarted){break}
   if([DateTime]::UtcNow -gt $deadline){throw 'A janela anterior nao encerrou. Atualizacao cancelada.'}
   Start-Sleep -Milliseconds 300
  }while($true)
 }
 $shell=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
 $stopOutput=& $shell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $install 'LucyMcp.ps1') stop -DataDirectory $data 2>&1
 if($LASTEXITCODE -ne 0){throw 'Nao foi possivel parar a publicacao. Use o mesmo nivel de permissao de quem iniciou e tente novamente.'}
 $backup=Join-Path $Plan.workPath 'backup';[void](New-Item -ItemType Directory -Path $backup -Force)
 $changed=New-Object Collections.Generic.List[object]
 try{
  $files=@($inventory.files)+@([pscustomobject]@{path='package-files.json';sha256=(Get-FileHash -LiteralPath (Join-Path $stage 'package-files.json') -Algorithm SHA256).Hash})
  foreach($file in $files){
   $dest=Update-ChildPath $install $file.path;$src=Update-ChildPath $stage $file.path
   $hadOld=Test-Path -LiteralPath $dest -PathType Leaf
   if($hadOld -and (Get-FileHash -LiteralPath $dest -Algorithm SHA256).Hash -eq $file.sha256){continue}
   $save=Update-ChildPath $backup $file.path
   if($hadOld){[void](New-Item -ItemType Directory -Force -Path (Split-Path $save -Parent));Copy-Item -LiteralPath $dest -Destination $save}
   $changed.Add(@{destination=$dest;backup=$save;hadOld=$hadOld})
   [void](New-Item -ItemType Directory -Force -Path (Split-Path $dest -Parent))
   Copy-Item -LiteralPath $src -Destination $dest -Force
   if((Get-FileHash -LiteralPath $dest -Algorithm SHA256).Hash -ne $file.sha256){throw 'Integridade invalida apos substituir arquivo.'}
  }
 }catch{
  $originalError=$_;$rollbackErrors=@()
  for($i=$changed.Count-1;$i -ge 0;$i--){
   $item=$changed[$i]
   try{if($item.hadOld){
    $alreadyRestored=(Test-Path -LiteralPath $item.destination) -and ((Get-FileHash -LiteralPath $item.destination -Algorithm SHA256).Hash -eq (Get-FileHash -LiteralPath $item.backup -Algorithm SHA256).Hash)
    if(!$alreadyRestored){Copy-Item -LiteralPath $item.backup -Destination $item.destination -Force}
   }else{if(Test-Path -LiteralPath $item.destination){Remove-Item -LiteralPath $item.destination -Force}}}catch{$rollbackErrors+=$_.Exception.Message}
  }
  if($rollbackErrors.Count){throw ('Falha na atualizacao e restauracao parcial. Backup: '+$backup+'. '+$originalError.Exception.Message)}
  throw ('Atualizacao cancelada; arquivos anteriores restaurados. '+$originalError.Exception.Message)
 }
 Update-Json @{ok=$true;version=$Plan.version;changedFiles=$changed.Count;backupPath=$backup;time=[DateTime]::UtcNow.ToString('o')} (Join-Path $data 'update-result.json')
 if(!$NoRestart){Start-Process -FilePath (Update-Launcher $install) -WindowStyle Hidden}
 return @{changedFiles=$changed.Count;backupPath=$backup}
}
if($Library){return}
$request=$null
try{
 $request=Get-Content -Raw -LiteralPath $RequestPath|ConvertFrom-Json
 switch($request.action){
  'check' {$result=Get-UpdateInfo $request.manifestPath $request.installPath}
  'prepare' {$result=Prepare-Update $request.manifestPath $request.installPath $request.dataDirectory}
  'apply' {$result=Apply-Update $request.plan $request.guiPid $request.guiStarted}
  default {throw 'Acao de atualizacao invalida.'}
 }
 Update-Json @{ok=$true;result=$result} $request.responsePath
 Write-Output 'Atualizacao: operacao concluida.'
}catch{
 if($request){
  Update-Json @{ok=$false;error=$_.Exception.Message} $request.responsePath
  if($request.action -eq 'apply'){
   Update-Json @{ok=$false;error=$_.Exception.Message;time=[DateTime]::UtcNow.ToString('o')} (Join-Path $request.plan.dataDirectory 'update-result.json')
   try{Start-Process -FilePath (Update-Launcher $request.plan.installPath) -WindowStyle Hidden}catch{Write-Output 'Abra CopilotBridge.exe manualmente para conferir o resultado.'}
  }
 }
 Write-Output ('Atualizacao falhou: '+$_.Exception.Message)
 exit 1
}
