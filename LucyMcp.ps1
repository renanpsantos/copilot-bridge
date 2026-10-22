param(
 [ValidateSet('setup','start','stop','status','connection','key','copilot','help','xurrent','verify')][string]$Action='status',
 [string]$Connection,
 [string]$XurrentPath,
 [string]$DataDirectory=(Join-Path $env:LOCALAPPDATA 'LucyMcpCli'),
 [switch]$NoTunnel,
 [switch]$Library
)
$ErrorActionPreference='Stop'
$appVersion=(Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot 'app-version.json')|ConvertFrom-Json).version
# Also support direct invocation from a process inheriting PowerShell 7 modules.
if($PSVersionTable.PSEdition -eq 'Desktop'){
 $env:PSModulePath=(Join-Path $PSHOME 'Modules')+';'+(Join-Path $env:ProgramFiles 'WindowsPowerShell\Modules')
 Import-Module (Join-Path $PSHOME 'Modules\Microsoft.PowerShell.Security\Microsoft.PowerShell.Security.psd1') -ErrorAction Stop
}
$configFile=Join-Path $DataDirectory 'config.json'
$stateFile=Join-Path $DataDirectory 'processes.json'
$statusFile=Join-Path $DataDirectory 'bridge-status.json'
$stopFile=Join-Path $DataDirectory 'stop'
$keyFile=Join-Path $DataDirectory 'key.dpapi'
$tokenFile=Join-Path $DataDirectory 'ngrok.dpapi'
$copilotUrl='https://copilotstudio.microsoft.com/'
if(Test-Path -LiteralPath $configFile){
 try{$saved=Get-Content -Raw -LiteralPath $configFile|ConvertFrom-Json;if($saved.copilotUrl){$parsed=[Uri]$saved.copilotUrl;if($parsed.Scheme -eq 'https' -and $parsed.Host -eq 'copilotstudio.microsoft.com'){$copilotUrl=$parsed.AbsoluteUri}}}catch{}
}

function Protect-Directory {
 New-Item -ItemType Directory -Force -Path $DataDirectory | Out-Null
 $dir=Get-Item -LiteralPath $DataDirectory
 # Read/write DACL only: setup must not require access to the audit SACL.
 if($PSVersionTable.PSEdition -eq 'Desktop'){
  $acl=$dir.GetAccessControl([Security.AccessControl.AccessControlSections]::Access)
 }else{
  $acl=[IO.FileSystemAclExtensions]::GetAccessControl($dir,[Security.AccessControl.AccessControlSections]::Access)
 }
 $acl.SetAccessRuleProtection($true,$false)
 $sid=[Security.Principal.WindowsIdentity]::GetCurrent().User
 $rule=New-Object Security.AccessControl.FileSystemAccessRule($sid,'FullControl','ContainerInherit,ObjectInherit','None','Allow')
 $acl.SetAccessRule($rule)
 if($PSVersionTable.PSEdition -eq 'Desktop'){$dir.SetAccessControl($acl)}else{[IO.FileSystemAclExtensions]::SetAccessControl($dir,$acl)}
}
function Save-Json($value,$file) { [IO.File]::WriteAllText($file,($value|ConvertTo-Json -Depth 8)) }
function Show-Link([string]$Label,[string]$Url) {
 if($env:WT_SESSION -or $env:TERM_PROGRAM){
  $esc=[char]27
  Write-Host ("  $esc]8;;$Url$esc\$Label$esc]8;;$esc\")
 }else{Write-Host ('  '+$Label)}
 Write-Host ('  '+$Url)
}
function Show-SetupStep([int]$Number,[string]$Title) {
 Clear-Host
 Write-Host 'LUCY MCP - CONFIGURACAO GUIADA'
 Write-Host ("[$Number/5] $Title")
 Write-Host ''
}
function Complete-SetupStep([string]$Message) {
 Write-Host ''
 Write-Host $Message -ForegroundColor Green
 [void](Read-Host 'Pressione Enter para a proxima etapa')
}
function Offer-Browser([string]$Url) {
 $choice=Read-Host 'Digite A para abrir no navegador, ou Enter para continuar'
 if($choice -match '^[aA]$'){Start-Process $Url}
}
function Show-CopilotInstructions {
 Write-Host ''
 Write-Host 'CONFIGURAR NO COPILOT STUDIO'
 Show-Link 'Abrir Copilot Studio / agente' $copilotUrl
 Write-Host '  1. Entre em Ferramentas > Adicionar ferramenta > Nova ferramenta > MCP.'
 Write-Host '  2. Informe um nome e cole a URL MCP exibida pelo comando start.'
 Write-Host '  3. Selecione Chave de API > Cabecalho > Authorization.'
 Write-Host '  4. Execute lucy-mcp.cmd key para copiar o valor de autenticacao.'
 Write-Host '  5. Crie uma nova conexao e cole o valor completo copiado (Bearer + chave).'
 Write-Host '  6. Adicione ao agente e atualize a lista de ferramentas.'
 Write-Host '  O authtoken do ngrok NAO deve ser colado nessa conexao.'
 Write-Host '  Para abrir o site pelo CLI: lucy-mcp.cmd copilot'
}
function Load-Config {
 if(!(Test-Path -LiteralPath $configFile)){throw 'Execute setup primeiro.'}
 return Get-Content -Raw -LiteralPath $configFile | ConvertFrom-Json
}
function Test-Package([string]$NodePath){
 try{
 $required=@('app-version.json','SingleInstance.cs','bridge.mjs','xurrent-bat-transport.mjs','verify-package.mjs',
  'node_modules\express\index.js',
  'node_modules\@modelcontextprotocol\sdk\dist\esm\client\index.js',
  'node_modules\@modelcontextprotocol\sdk\dist\esm\client\stdio.js',
  'node_modules\@modelcontextprotocol\sdk\dist\esm\server\index.js',
  'node_modules\@modelcontextprotocol\sdk\dist\esm\server\streamableHttp.js',
  'node_modules\@modelcontextprotocol\sdk\dist\esm\types.js')
 foreach($relative in $required){
  $file=Join-Path $PSScriptRoot $relative
  if(!(Test-Path -LiteralPath $file -PathType Leaf)){
   throw ('Instalacao incompleta. Arquivo ausente: '+$file+'. Extraia o ZIP inteiro diretamente na pasta de destino. Nao copie apenas os arquivos da interface; preserve node_modules.')
  }
 }
 if(!(Test-Path -LiteralPath $NodePath -PathType Leaf)){throw 'Runtime Node da Lucy nao encontrado. Revise a pasta da Lucy na configuracao.'}
 $result=& $NodePath (Join-Path $PSScriptRoot 'verify-package.mjs')
 if($LASTEXITCODE -ne 0){throw ('Falha ao carregar dependencias do adaptador: '+($result -join ' ')+'. Extraia novamente o pacote completo.')}
 }catch{
  $failure=$_
  try{Protect-Directory;[IO.File]::WriteAllText((Join-Path $DataDirectory 'bridge-error.log'),('Falha na verificacao do pacote: '+$failure.Exception.Message))}catch{}
  throw $failure
 }
}
function Resolve-XurrentPath([string]$Folder) {
 if([string]::IsNullOrWhiteSpace($Folder)){return ''}
 $resolved=(Resolve-Path -LiteralPath $Folder.Trim().Trim('"')).ProviderPath
 if($resolved -match '[%!^"\r\n]'){throw 'Use uma pasta sem os caracteres %, !, ^ ou aspas.'}
 if(!(Test-Path -LiteralPath (Join-Path $resolved 'iniciar-mcp.bat') -PathType Leaf) -or !(Test-Path -LiteralPath (Join-Path $resolved 'mcp-server\server.js') -PathType Leaf)){
  throw 'Informe a pasta do projeto que contem iniciar-mcp.bat e mcp-server\server.js.'
 }
 if(!(Test-Path -LiteralPath (Join-Path $resolved 'mcp-server\node_modules\@modelcontextprotocol\sdk\package.json')) -or !(Test-Path -LiteralPath (Join-Path $resolved 'mcp-server\node_modules\ws\package.json'))){
  if(!(Get-Command npm.cmd -ErrorAction SilentlyContinue)){throw 'Dependencias Xurrent ausentes. Instale Node.js com npm e execute iniciar-mcp.bat uma vez para instalar as dependencias.'}
 }
 return $resolved
}
function Set-XurrentPath($cfg,[string]$Folder) {
 $resolved=Resolve-XurrentPath $Folder
 $cfg|Add-Member -NotePropertyName xurrentPath -NotePropertyValue $resolved -Force
 Save-Json $cfg $configFile
}
function Read-Secret($file) {
 $secure=Get-Content -Raw -LiteralPath $file | ConvertTo-SecureString
 $ptr=[Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
 try{return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)}finally{[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)}
}
function Owned-Process($record) {
 if(!$record){return $null}
 $proc=Get-Process -Id $record.pid -ErrorAction SilentlyContinue
 if($proc -and $proc.StartTime.ToUniversalTime().Ticks.ToString() -eq $record.started){return $proc}
 return $null
}
function Record-Process($proc) { return @{pid=$proc.Id;started=$proc.StartTime.ToUniversalTime().Ticks.ToString()} }
function Read-State {
 if(Test-Path -LiteralPath $stateFile){return Get-Content -Raw -LiteralPath $stateFile | ConvertFrom-Json}
 return $null
}
function Stop-Owned {
 $state=Read-State
 if(!$state){Write-Host 'Nenhuma execucao registrada.';return}
 $ng=Owned-Process $state.ngrok
 if($ng){
  try{Stop-Process -Id $ng.Id -ErrorAction Stop}
  catch{Write-Warning 'Nao foi possivel encerrar o ngrok. A parada do adaptador local continuara.'}
 }
 $bridge=Owned-Process $state.bridge
 if($bridge){
  [IO.File]::WriteAllText($stopFile,'stop')
  for($i=0;$i -lt 20;$i++){if(!(Owned-Process $state.bridge)){break};Start-Sleep -Milliseconds 500}
  if(Owned-Process $state.bridge){
   # Only this CLI's verified process tree, never other Lucy/Node instances.
   & taskkill.exe /PID $bridge.Id /T /F | Out-Null
  }
 }
 $remainingNg=Owned-Process $state.ngrok
 $remainingBridge=Owned-Process $state.bridge
 if($remainingNg -or $remainingBridge){
  # Keep ownership records so an elevated retry can finish stopping these processes.
  throw 'Parada incompleta. Abra o CMD como administrador com o mesmo usuario Windows e execute lucy-mcp.cmd stop novamente. O registro dos processos foi preservado.'
 }
 Remove-Item -LiteralPath $stateFile -Force -ErrorAction SilentlyContinue
 Write-Host 'Publicacao parada. VPN e Lucy existente continuam sob seu controle.'
}
function Show-Status {
 Write-Host ('Lucy MCP v'+$appVersion)
 $state=Read-State
 $bridge=if($state){Owned-Process $state.bridge}else{$null}
 $ng=if($state){Owned-Process $state.ngrok}else{$null}
 Write-Host ('Adaptador: '+$(if($bridge){'ativo'}else{'parado'}))
 Write-Host ('Tunel: '+$(if($ng){'ativo'}else{'parado'}))
 if($bridge -and (Test-Path -LiteralPath $statusFile)){
  $s=Get-Content -Raw -LiteralPath $statusFile|ConvertFrom-Json
  Write-Host ('Ferramentas anunciadas: '+$s.tools)
  if($null -ne $s.xurrentTools){Write-Host ('Lucy: '+$s.lucyTools+' | Xurrent: '+$s.xurrentTools)}
  if($s.tools -gt 70){Write-Warning 'Catalogo acima de 70 ferramentas. Reduza os bundles na Lucy antes de usar no Copilot Studio.'}
  Write-Host ('Ambiente configurado: '+$(if($s.connection){$s.connection}else{'padrao da Lucy'}))
 }
 if($ng -and $state.url){Show-Link 'URL MCP publica (copie para o Copilot Studio)' $state.url}
 Show-Link 'Copilot Studio' $copilotUrl
}

if($Library){return}
switch($Action){
 'help' {
  Write-Host 'LUCY MCP - COMANDOS'
  Write-Host ''
  Write-Host '  lucy-mcp.cmd setup       Configurar Lucy, ngrok e ambiente SAP.'
  Write-Host '  lucy-mcp.cmd start       Iniciar adaptador e publicacao HTTPS.'
  Write-Host '  lucy-mcp.cmd stop        Encerrar a publicacao iniciada pelo CLI.'
  Write-Host '  lucy-mcp.cmd status      Mostrar estado, ambiente e URL publica.'
  Write-Host '  lucy-mcp.cmd connection  Selecionar outro ambiente (execute stop antes).'
  Write-Host '  lucy-mcp.cmd key         Copiar Bearer + chave MCP para colar na conexao.'
  Write-Host '  lucy-mcp.cmd copilot     Abrir o agente ou portal no navegador.'
  Write-Host '  lucy-mcp.cmd help        Mostrar esta ajuda.'
  Write-Host '  lucy-mcp.cmd xurrent     Configurar a pasta do projeto Xurrent (stop antes).'
  Write-Host '  lucy-mcp.cmd verify      Verificar arquivos e dependencias sem iniciar servicos.'
  Write-Host ''
  Write-Host 'EXEMPLOS'
  Write-Host '  lucy-mcp.cmd start -NoTunnel'
  Write-Host '    Testar o adaptador localmente, sem publicar na internet.'
  Write-Host '  lucy-mcp.cmd connection -Connection DSB_GL_EVENTS_DEV'
  Write-Host '    Selecionar a conexao pelo nome configurado na Lucy.'
  Write-Host '  lucy-mcp.cmd start -XurrentPath "C:\Projetos\chrome-xurrent-extension"'
  Write-Host '    Salvar a pasta deste computador e iniciar tambem iniciar-mcp.bat.'
  Write-Host ''
  Write-Host 'Conecte a VPN manualmente antes do start.'
  Write-Host 'O authtoken do ngrok e diferente da chave MCP copiada pelo comando key.'
  Write-Host 'Sem comando, o CLI mostra status. Para configurar com duplo clique, use setup.cmd.'
 }
 'setup' {
  $state=Read-State
  if($state -and (Owned-Process $state.bridge)){throw 'Pare o adaptador antes de executar setup.'}
  Protect-Directory
  Show-SetupStep 1 'Localizar a Lucy'
  Write-Host 'Este assistente prepara a publicacao. A VPN deve ser conectada por voce.'
  Write-Host 'Tenha a Lucy instalada e o ambiente SAP configurado antes de continuar.'
  Write-Host 'No CMD, use a opcao A para abrir os sites no navegador.'
  Write-Host ''
  $root=Join-Path $env:ProgramFiles 'dLucy'
  if(!(Test-Path -LiteralPath (Join-Path $root 'resources\app\index.js'))){
   Write-Host 'Lucy nao encontrada na pasta padrao. Informe a pasta que contem resources.'
   $root=Read-Host 'Pasta de instalacao da dLucy'
  }
  $node=Join-Path $root 'resources\runtime\node.exe'
  $script=Join-Path $root 'resources\app\index.js'
  if(!(Test-Path -LiteralPath $node) -or !(Test-Path -LiteralPath $script)){throw 'Instalacao da Lucy nao encontrada.'}
  Write-Host ('Lucy encontrada: '+$root)
  Write-Host 'As demais dependencias do adaptador ja acompanham este pacote.'
  Complete-SetupStep 'Etapa 1 concluida: Lucy localizada.'
  Show-SetupStep 2 'Preparar o ngrok'
  Write-Host 'O ngrok cria o endereco HTTPS para o Copilot acessar o MCP deste computador.'
  $ng=Get-Command ngrok -ErrorAction SilentlyContinue
  if(!$ng){
   Write-Host 'Instalando ngrok pela Microsoft Store...'
   & winget.exe install ngrok -s msstore --accept-source-agreements --accept-package-agreements
   if($LASTEXITCODE -ne 0){Show-Link 'Instalar ngrok para Windows' 'https://ngrok.com/download/windows';Offer-Browser 'https://ngrok.com/download/windows';throw 'Instalacao do ngrok falhou. Instale pela Store e repita setup.'}
   $ng=Get-Command ngrok -ErrorAction SilentlyContinue
   if(!$ng){throw 'Abra outro CMD para atualizar o PATH e execute lucy-mcp.cmd setup novamente.'}
  }
  Write-Host 'ngrok instalado.'
  if(!(Test-Path -LiteralPath $keyFile)){
   $bytes=New-Object byte[] 32
   $rng=[Security.Cryptography.RandomNumberGenerator]::Create();$rng.GetBytes($bytes);$rng.Dispose()
   $secure=ConvertTo-SecureString ([Convert]::ToBase64String($bytes)) -AsPlainText -Force
   [IO.File]::WriteAllText($keyFile,($secure|ConvertFrom-SecureString))
  }
  Complete-SetupStep 'Etapa 2 concluida: ngrok instalado.'
  Show-SetupStep 3 'Obter o authtoken da sua conta ngrok'
  Show-Link 'ngrok - Your Authtoken' 'https://dashboard.ngrok.com/get-started/your-authtoken'
  Write-Host 'Entre na sua conta ngrok. Se ainda nao tem conta, crie uma no site.'
  Write-Host 'Na pagina Your Authtoken, copie o valor do campo Authtoken usando Copy.'
  Write-Host 'Copie somente o token, nao o comando ngrok config add-authtoken.'
  Write-Host 'Esse token conecta o tunel a SUA conta; ele e diferente da chave do MCP.'
  if(!(Test-Path -LiteralPath $tokenFile)){
   Offer-Browser 'https://dashboard.ngrok.com/get-started/your-authtoken'
   do{
    $token=Read-Host 'Cole aqui somente o Authtoken e pressione Enter (entrada oculta)' -AsSecureString
    if($token.Length -eq 0){Write-Host 'Nenhum token recebido. Copie o campo Authtoken no site e tente novamente.'}
   }while($token.Length -eq 0)
   [IO.File]::WriteAllText($tokenFile,($token|ConvertFrom-SecureString))
   Write-Host 'Authtoken salvo protegido para este usuario Windows. A validade sera verificada no start.'
  }else{Write-Host 'Ja existe um authtoken salvo neste computador; ele sera mantido.'}
  Complete-SetupStep 'Etapa 3 concluida: authtoken salvo (validade verificada no start).'
  Show-SetupStep 4 'Selecionar o ambiente SAP'
  Write-Host 'Abra a Lucy e copie o NOME da conexao do ambiente que deseja usar.'
  Write-Host 'Exemplo: DSB_GL_EVENTS_DEV. Nao informe IP, usuario SAP ou senha aqui.'
  Write-Host 'Enter sem nome usa o comportamento padrao da Lucy.'
  if(!$Connection){$Connection=Read-Host 'Nome da conexao SAP na Lucy (vazio = padrao da Lucy)'}
  Complete-SetupStep 'Etapa 4 concluida: ambiente selecionado.'
  Show-SetupStep 5 'Escolher o acesso ao Copilot Studio'
  Show-Link 'Copilot Studio - criar ou editar seu agente' $copilotUrl
  Write-Host 'Se ja tem um agente, abra-o no navegador e copie a URL da barra de enderecos.'
  Write-Host 'Cole esse link abaixo para que o comando copilot abra diretamente o agente.'
  Write-Host 'Se ainda nao criou o agente, pressione Enter para usar a pagina inicial.'
  Offer-Browser $copilotUrl
  $agentUrl=Read-Host 'Link do agente no Copilot Studio (opcional; Enter = portal)'
  if($agentUrl){$parsed=[Uri]$agentUrl;if($parsed.Scheme -ne 'https' -or $parsed.Host -ne 'copilotstudio.microsoft.com'){throw 'Use um link HTTPS do Copilot Studio.'};$copilotUrl=$parsed.AbsoluteUri}
  Clear-Host
  Write-Host 'OPCIONAL - MCP XURRENT'
  Write-Host 'Informe a pasta que contem iniciar-mcp.bat. Ela pode ser diferente em cada computador.'
  Write-Host 'O start executara esse BAT e adicionara as ferramentas Xurrent ao mesmo endpoint MCP.'
  Write-Host 'Mantenha Chrome, extensao Xurrent e sessao corporativa abertos.'
  if(!$XurrentPath){$XurrentPath=Read-Host 'Pasta do projeto Xurrent (Enter = somente Lucy)'}
  $resolvedXurrent=Resolve-XurrentPath $XurrentPath
  Save-Json @{node=$node;script=$script;ngrok=$ng.Source;port=8086;connection=$Connection;copilotUrl=$copilotUrl;xurrentPath=$resolvedXurrent} $configFile
  [IO.File]::WriteAllText((Join-Path $DataDirectory 'ngrok.yml'),"version: 3`nagent:`n  web_addr: 127.0.0.1:4046`n")
  Clear-Host
  Write-Host 'CONFIGURACAO CONCLUIDA'
  Write-Host '1. Conecte a VPN que permite acessar o ambiente SAP escolhido.'
  Write-Host '2. Encerre outro ngrok que esteja usando o mesmo dominio, se houver.'
  Write-Host '3. Execute: lucy-mcp.cmd start'
  Write-Host '4. O start mostrara a URL publica completa para cadastrar no Copilot Studio.'
  Write-Host '5. Execute: lucy-mcp.cmd key para copiar a autenticacao da conexao.'
  Write-Host 'Para encerrar a publicacao: lucy-mcp.cmd stop'
  Write-Host 'Todas as ferramentas da Lucy serao disponibilizadas, inclusive escrita permitida por Lucy/SAP.'
  Write-Host 'Para abrir seu agente no navegador: lucy-mcp.cmd copilot'
  Write-Host 'As instrucoes de cadastro no Copilot serao exibidas pelo start.'
  Write-Host 'Para listar todos os comandos: lucy-mcp.cmd help'
 }
 'start' {
  if(!(Test-Path -LiteralPath $configFile)){& $PSCommandPath -Action setup -DataDirectory $DataDirectory -Connection $Connection -XurrentPath $XurrentPath}
  $cfg=Load-Config;$state=Read-State
  if($XurrentPath){
   if($state -and (Owned-Process $state.bridge)){throw 'Execute stop antes de alterar a pasta do Xurrent.'}
   Set-XurrentPath $cfg $XurrentPath
  }
  if($state -and (Owned-Process $state.bridge)){Show-Status;break}
  if($state){Stop-Owned}
  Test-Package $cfg.node
  $portCheck=New-Object Net.Sockets.TcpListener([Net.IPAddress]::Loopback,[int]$cfg.port)
  try{$portCheck.Start()}finally{$portCheck.Stop()}
  Remove-Item -LiteralPath $stopFile,$statusFile -Force -ErrorAction SilentlyContinue
  $oldKey=$env:LUCY_MCP_KEY
  try{
   $env:LUCY_MCP_KEY=Read-Secret $keyFile
   $bridge=Start-Process -FilePath $cfg.node -ArgumentList @(('"'+(Join-Path $PSScriptRoot 'bridge.mjs')+'"'),('"'+$configFile+'"')) -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $DataDirectory 'bridge.log') -RedirectStandardError (Join-Path $DataDirectory 'bridge-error.log')
  }finally{$env:LUCY_MCP_KEY=$oldKey}
  $state=@{bridge=(Record-Process $bridge);ngrok=$null;url=$null}
  Save-Json $state $stateFile
  try{
   $ready=$false
   $readyTimeout=if($cfg.xurrentPath){150}else{60}
   for($i=0;$i -lt $readyTimeout;$i++){
    if($bridge.HasExited){throw ('O adaptador MCP nao iniciou. Log: '+(Join-Path $DataDirectory 'bridge-error.log'))}
    if(Test-Path -LiteralPath $statusFile){$s=Get-Content -Raw -LiteralPath $statusFile|ConvertFrom-Json;if($s.ready){$ready=$true;break}}
    Start-Sleep -Seconds 1
   }
   if(!$ready){throw ('Timeout ao iniciar o adaptador MCP. Log: '+(Join-Path $DataDirectory 'bridge-error.log'))}
   if(!$NoTunnel){
    $oldToken=$env:NGROK_AUTHTOKEN
    try{
     $env:NGROK_AUTHTOKEN=Read-Secret $tokenFile
     $ng=Start-Process -FilePath $cfg.ngrok -ArgumentList @('http',('http://127.0.0.1:'+$cfg.port),('--host-header=127.0.0.1:'+$cfg.port),'--inspect=false','--config',('"'+(Join-Path $DataDirectory 'ngrok.yml')+'"')) -WindowStyle Hidden -PassThru
    }finally{$env:NGROK_AUTHTOKEN=$oldToken}
    $state.ngrok=Record-Process $ng;Save-Json $state $stateFile
    for($i=0;$i -lt 30;$i++){
     if($ng.HasExited){throw 'Ngrok encerrou. Verifique conta, token, VPN e possivel tunel ja ativo.'}
     try{
      $api=Invoke-RestMethod -Uri 'http://127.0.0.1:4046/api/tunnels' -TimeoutSec 2
      $t=$api.tunnels|Where-Object {$_.public_url -like 'https://*' -and $_.config.addr -match (':'+$cfg.port+'/?$')}|Select-Object -First 1
      if($t){$state.url=$t.public_url.TrimEnd('/')+'/mcp';break}
     }catch{}
     Start-Sleep -Seconds 1
    }
    if(!$state.url){throw 'Nao foi possivel obter URL publica do ngrok.'}
    Save-Json $state $stateFile
   }
   Show-Status
   Show-CopilotInstructions
   Write-Host 'Todas as ferramentas anunciadas pela Lucy estao disponiveis, incluindo escrita permitida pela Lucy/SAP.'
  }catch{Stop-Owned;throw}
 }
 'stop' {Stop-Owned}
 'verify' {
  $node=Join-Path $env:ProgramFiles 'dLucy\resources\runtime\node.exe'
  if(Test-Path -LiteralPath $configFile){$node=(Load-Config).node}
  Test-Package $node
  Write-Host 'Instalacao verificada. Arquivos e dependencias do adaptador carregados; nenhum servico iniciado.'
 }
 'xurrent' {
  $cfg=Load-Config;$state=Read-State
  if($state -and (Owned-Process $state.bridge)){throw 'Execute stop antes de mudar a configuracao Xurrent.'}
  if(!$PSBoundParameters.ContainsKey('XurrentPath')){$XurrentPath=Read-Host 'Pasta com iniciar-mcp.bat (Enter = desabilitar Xurrent)'}
  Set-XurrentPath $cfg $XurrentPath
  Write-Host 'Configuracao Xurrent salva para este computador. Execute start.'
 }
 'status' {Show-Status}
 'connection' {
  $cfg=Load-Config;$state=Read-State
  if($state -and (Owned-Process $state.bridge)){throw 'Execute stop antes de mudar de ambiente.'}
  if(!$Connection){$Connection=Read-Host 'Nome da conexao SAP (vazio = padrao da Lucy)'}
  $cfg.connection=$Connection;Save-Json $cfg $configFile
  Write-Host 'Ambiente configurado. Execute start.'
 }
 'key' {
  $value='Bearer '+(Read-Secret $keyFile)
  Set-Clipboard -Value $value
  Write-Host 'Authorization copiado para a area de transferencia. Cole apenas na conexao do Copilot Studio.'
  $value=$null
 }
 'copilot' {Start-Process $copilotUrl}
}
