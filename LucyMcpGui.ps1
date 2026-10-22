param([string]$DataDirectory=(Join-Path $env:LOCALAPPDATA 'LucyMcpCli'),[switch]$SmokeTest,[string]$PreviewPath,[switch]$ValidateGui)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$singleInstance=$null
trap{if($singleInstance){$singleInstance.Dispose()};Write-Error -Message $_.Exception.Message -ErrorAction Continue;[void][Windows.Forms.MessageBox]::Show($_.Exception.Message,'Lucy MCP - falha ao abrir');exit 1}
if(!$SmokeTest){
 Add-Type -Path (Join-Path $PSScriptRoot 'SingleInstance.cs') -ReferencedAssemblies System.Windows.Forms,System.Core
 $singleInstance=New-Object LucySingleInstance($DataDirectory)
 if(!$singleInstance.IsPrimary){try{$singleInstance.ActivateExisting()}finally{$singleInstance.Dispose()};return}
}
[Windows.Forms.Application]::EnableVisualStyles()
. (Join-Path $PSScriptRoot 'LucyMcp.ps1') -Library -DataDirectory $DataDirectory
$script:operation=$null
$script:dirty=$false
$script:updateInfo=$null
$script:updateSource=''
$script:updating=$false
$updateSettingsFile=Join-Path $DataDirectory 'updates.json'
$form=New-Object Windows.Forms.Form
$form.Text='Lucy MCP v'+$appVersion+' | Configuracao e publicacao'
$form.ClientSize=New-Object Drawing.Size(840,710)
$form.MinimumSize=New-Object Drawing.Size(856,749)
$form.StartPosition='CenterScreen'
$form.Font=New-Object Drawing.Font('Segoe UI',10)
$form.BackColor=[Drawing.Color]::FromArgb(245,247,250)
$form.Icon=New-Object Drawing.Icon((Join-Path $PSScriptRoot 'logo.ico'))
$form.AutoScaleMode='Dpi'
function Label-At($parent,$text,$x,$y,$w=750,$h=26){
 $c=New-Object Windows.Forms.Label;$c.Text=$text;$c.SetBounds($x,$y,$w,$h);$parent.Controls.Add($c);return $c
}
function Button-At($parent,$text,$x,$y,$w=120,$h=32){
 $c=New-Object Windows.Forms.Button;$c.Text=$text;$c.SetBounds($x,$y,$w,$h);$parent.Controls.Add($c);return $c
}
function Text-At($parent,$x,$y,$w=570){
 $c=New-Object Windows.Forms.TextBox;$c.SetBounds($x,$y,$w,29);$parent.Controls.Add($c);return $c
}
function Notify($text,[bool]$error=$false){
 [void][Windows.Forms.MessageBox]::Show($form,$text,'Lucy MCP',[Windows.Forms.MessageBoxButtons]::OK,$(if($error){[Windows.Forms.MessageBoxIcon]::Error}else{[Windows.Forms.MessageBoxIcon]::Information}))
}
function Pick-Folder($box){
 $d=New-Object Windows.Forms.FolderBrowserDialog;$d.Description='Selecione a pasta de instalacao ou do projeto'
 if(Test-Path -LiteralPath $box.Text -PathType Container){$d.SelectedPath=$box.Text}
 try{if($d.ShowDialog($form) -eq 'OK'){$box.Text=$d.SelectedPath}}finally{$d.Dispose()}
}
function Pick-File($box){
 $d=New-Object Windows.Forms.OpenFileDialog;$d.Filter='ngrok (ngrok.exe)|ngrok.exe';$d.Title='Localizar ngrok.exe'
 try{if($d.ShowDialog($form) -eq 'OK'){$box.Text=$d.FileName}}finally{$d.Dispose()}
}
$heading=Label-At $form ('Lucy MCP v'+$appVersion) 82 12 500 34
$heading.Font=New-Object Drawing.Font('Segoe UI',19,[Drawing.FontStyle]::Bold)
$logo=New-Object Windows.Forms.PictureBox;$logo.SetBounds(24,12,48,48);$logo.SizeMode='Zoom'
$logo.Image=[Drawing.Image]::FromFile((Join-Path $PSScriptRoot 'logo.png'));$form.Controls.Add($logo)
[void](Label-At $form 'Configure uma vez. Inicie e pare a publicacao sem usar o terminal.' 82 51 738 25)
$form.Add_Disposed({if($logo.Image){$logo.Image.Dispose();$logo.Image=$null}})
$tabs=New-Object Windows.Forms.TabControl;$tabs.SetBounds(18,85,804,555);$tabs.Anchor='Top,Bottom,Left,Right';$form.Controls.Add($tabs)
$setupTab=New-Object Windows.Forms.TabPage;$setupTab.Text='1. Configuracao';$setupTab.BackColor=[Drawing.Color]::White
$runTab=New-Object Windows.Forms.TabPage;$runTab.Text='2. Publicacao e Copilot';$runTab.BackColor=[Drawing.Color]::White
$updateTab=New-Object Windows.Forms.TabPage;$updateTab.Text='3. Atualizacoes';$updateTab.BackColor=[Drawing.Color]::White
$tabs.TabPages.AddRange(@($setupTab,$runTab,$updateTab))
[void](Label-At $setupTab 'Lucy instalada' 20 12)
$lucyBox=Text-At $setupTab 20 38 632
$lucyBrowse=Button-At $setupTab 'Selecionar...' 660 36 110
$lucyBrowse.Add_Click({Pick-Folder $lucyBox})
[void](Label-At $setupTab 'ngrok' 20 77 140)
$ngrokBox=Text-At $setupTab 20 103 500
$ngrokBrowse=Button-At $setupTab 'Localizar...' 528 101 110
$ngrokInstall=Button-At $setupTab 'Instalar ngrok' 646 101 124
$ngrokBrowse.Add_Click({Pick-File $ngrokBox})
[void](Label-At $setupTab 'Authtoken ngrok (cole o token da sua conta)' 20 140 460)
$tokenLink=New-Object Windows.Forms.LinkLabel;$tokenLink.Text='Abrir site / obter token';$tokenLink.SetBounds(548,140,222,25);$setupTab.Controls.Add($tokenLink)
$tokenLink.Add_LinkClicked({Start-Process 'https://dashboard.ngrok.com/get-started/your-authtoken'})
$tokenBox=Text-At $setupTab 20 167 500;$tokenBox.UseSystemPasswordChar=$true
$pasteToken=Button-At $setupTab 'Colar' 528 165 80
$showToken=New-Object Windows.Forms.CheckBox;$showToken.Text='Mostrar';$showToken.SetBounds(628,168,135,26);$setupTab.Controls.Add($showToken)
$showToken.Add_CheckedChanged({$tokenBox.UseSystemPasswordChar=!$showToken.Checked})
$pasteToken.Add_Click({if([Windows.Forms.Clipboard]::ContainsText()){$tokenBox.Text=[Windows.Forms.Clipboard]::GetText().Trim()}})
$tokenHint=Label-At $setupTab 'O token do ngrok e diferente da chave MCP usada no Copilot.' 20 202 750 24
$tokenHint.ForeColor=[Drawing.Color]::DimGray
[void](Label-At $setupTab 'Conexao SAP na Lucy (opcional)' 20 234)
$connectionBox=New-Object Windows.Forms.ComboBox;$connectionBox.DropDownStyle='DropDown';$connectionBox.SetBounds(20,260,750,30);$setupTab.Controls.Add($connectionBox)
$connectionBox.Text=''
[void](Label-At $setupTab 'Deixe vazio para usar o padrao. Copie o nome da conexao na Lucy.' 20 293 750 24)
$xCheck=New-Object Windows.Forms.CheckBox;$xCheck.Text='Incluir MCP Xurrent da extensao Chrome';$xCheck.SetBounds(20,327,600,28);$setupTab.Controls.Add($xCheck)
$xBox=Text-At $setupTab 20 360 632;$xBox.Enabled=$false
$xBrowse=Button-At $setupTab 'Selecionar...' 660 358 110;$xBrowse.Enabled=$false
$xCheck.Add_CheckedChanged({$xBox.Enabled=$xCheck.Checked;$xBrowse.Enabled=$xCheck.Checked})
$xBrowse.Add_Click({Pick-Folder $xBox})
[void](Label-At $setupTab 'Selecione a pasta que contem iniciar-mcp.bat. Mantenha Chrome e Xurrent abertos.' 20 395 750 24)
[void](Label-At $setupTab 'Link do agente Copilot Studio (opcional)' 20 426)
$copilotBox=Text-At $setupTab 20 452 750
$saveButton=Button-At $setupTab 'Salvar e continuar' 565 489 205
$stateLabel=Label-At $runTab 'Adaptador: parado | Tunel: parado' 20 18 750 32
$stateLabel.Font=New-Object Drawing.Font('Segoe UI',12,[Drawing.FontStyle]::Bold)
$countLabel=Label-At $runTab 'Ferramentas: aguardando inicializacao' 20 56 750 28
[void](Label-At $runTab 'Conecte a VPN do cliente antes de iniciar. O aplicativo nao conecta a VPN.' 20 92 750 26)
$startButton=Button-At $runTab 'Iniciar publicacao' 20 130 205 40
$stopButton=Button-At $runTab 'Parar publicacao' 238 130 205 40
$refreshButton=Button-At $runTab 'Atualizar estado' 456 130 170 40
$verifyButton=Button-At $runTab 'Verificar pacote' 638 130 132 40
[void](Label-At $runTab 'Endereco publico MCP' 20 190)
$urlBox=Text-At $runTab 20 220 750;$urlBox.ReadOnly=$true
$copyUrl=Button-At $runTab 'Copiar URL' 20 262 150
$copyKey=Button-At $runTab 'Copiar chave MCP' 180 262 180
$openCopilot=Button-At $runTab 'Abrir Copilot Studio' 370 262 210
$openLog=Button-At $runTab 'Abrir log' 590 262 180
$guide=Label-At $runTab "No Copilot Studio: adicione um servidor MCP com a URL acima.`r`nAutenticacao: Chave de API > Cabecalho > Authorization.`r`nUse Copiar chave MCP e cole o valor completo na conexao.`r`nApos reiniciar a publicacao, abra uma nova sessao de teste." 20 316 750 100
$operationBox=New-Object Windows.Forms.TextBox;$operationBox.Multiline=$true;$operationBox.ReadOnly=$true;$operationBox.ScrollBars='Vertical';$operationBox.SetBounds(20,430,750,80);$runTab.Controls.Add($operationBox)
[void](Label-At $updateTab ('Versao instalada: v'+$appVersion) 20 20 750 32)
[void](Label-At $updateTab 'Selecione o version.json na pasta corporativa sincronizada pelo OneDrive/SharePoint.' 20 66 750 50)
$updateSourceBox=Text-At $updateTab 20 120 600;$updateSourceBox.ReadOnly=$true
$selectSource=Button-At $updateTab 'Escolher...' 634 118 136
$checkUpdate=Button-At $updateTab 'Verificar atualizacoes' 20 176 240 40
$installUpdate=Button-At $updateTab 'Instalar e reiniciar' 276 176 240 40;$installUpdate.Enabled=$false
$updateState=Label-At $updateTab 'Nenhuma verificacao realizada.' 20 238 750 50
$updateNotes=New-Object Windows.Forms.TextBox;$updateNotes.Multiline=$true;$updateNotes.ReadOnly=$true;$updateNotes.ScrollBars='Vertical';$updateNotes.SetBounds(20,305,750,132);$updateTab.Controls.Add($updateNotes)
[void](Label-At $updateTab 'A atualizacao encerra a publicacao. Configuracoes e tokens serao preservados.' 20 454 750 50)
$updateLogButton=Button-At $updateTab 'Abrir resultado da atualizacao' 20 488 315
$footer=Label-At $form 'Pronto para configurar. Nenhuma publicacao e iniciada automaticamente.' 24 650 785 45;$footer.Anchor='Bottom,Left,Right'
$script:formButtons=@($startButton,$stopButton,$saveButton,$ngrokInstall,$verifyButton,$checkUpdate,$selectSource)
function Refresh-State {
 try{
  $state=Read-State;$bp=$null;$np=$null
  if($state){$bp=Owned-Process $state.bridge;$np=Owned-Process $state.ngrok}
  $stateLabel.Text='Adaptador: '+$(if($bp){'ativo'}else{'parado'})+' | Tunel: '+$(if($np){'ativo'}else{'parado'})
  $urlBox.Text=if($np -and $state.url){$state.url}else{''}
  $copyUrl.Enabled=!!$urlBox.Text;$copyKey.Enabled=Test-Path -LiteralPath $keyFile
  if($bp -and (Test-Path -LiteralPath $statusFile)){
   $s=Get-Content -Raw -LiteralPath $statusFile|ConvertFrom-Json
   $countLabel.Text='Ferramentas: '+$s.tools
   if($null -ne $s.xurrentTools){$countLabel.Text+=' (Lucy: '+$s.lucyTools+' | Xurrent: '+$s.xurrentTools+')'}
   $countLabel.ForeColor=if($s.tools -gt 70){[Drawing.Color]::Firebrick}else{[Drawing.Color]::DarkGreen}
   if($s.tools -gt 70){$countLabel.Text+=' - reduza os bundles para ate 70.'}
  }else{$countLabel.Text='Ferramentas: aguardando inicializacao';$countLabel.ForeColor=[Drawing.Color]::DimGray}
  if($script:operation){return}
  $saveButton.Enabled=!$bp;$startButton.Enabled=!$bp;$stopButton.Enabled=!!($bp -or $np)
 }catch{$footer.Text='Nao foi possivel ler o estado: '+$_.Exception.Message}
}
function Find-Ngrok {
 $ng=Get-Command ngrok.exe -ErrorAction SilentlyContinue
 if(!$ng){$ng=Get-Command ngrok -ErrorAction SilentlyContinue}
 if($ng){$ngrokBox.Text=$ng.Source}
 else{
  $alias=Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\ngrok.exe'
  if(Test-Path -LiteralPath $alias){$ngrokBox.Text=$alias}
 }
}
function Save-Settings {
 $state=Read-State
 if($state -and (Owned-Process $state.bridge)){throw 'Pare a publicacao antes de alterar a configuracao.'}
 $root=$lucyBox.Text.Trim().Trim('"')
 $node=Join-Path $root 'resources\runtime\node.exe';$entry=Join-Path $root 'resources\app\index.js'
 if(!(Test-Path -LiteralPath $node -PathType Leaf) -or !(Test-Path -LiteralPath $entry -PathType Leaf)){throw 'Selecione a pasta da Lucy que contem resources\app e resources\runtime.'}
 $ngrok=$ngrokBox.Text.Trim().Trim('"')
 if(!(Test-Path -LiteralPath $ngrok -PathType Leaf)){throw 'Localize ou instale o ngrok antes de continuar.'}
 $url=$copilotBox.Text.Trim();if(!$url){$url='https://copilotstudio.microsoft.com/'}
 $uri=$null
 if(![Uri]::TryCreate($url,[UriKind]::Absolute,[ref]$uri) -or $uri.Scheme -ne 'https' -or $uri.Host -ne 'copilotstudio.microsoft.com'){throw 'Informe um link HTTPS do Copilot Studio ou deixe o campo vazio.'}
 $xp='';if($xCheck.Checked){if(!$xBox.Text.Trim()){throw 'Selecione a pasta do projeto Xurrent.'};$xp=Resolve-XurrentPath $xBox.Text}
 $token=$tokenBox.Text.Trim()
 if(!$token -and !(Test-Path -LiteralPath $tokenFile)){throw 'Cole o Authtoken da sua conta ngrok. Use o link Abrir site / obter token.'}
 if($token -and ($token -match '\s' -or $token -match '^ngrok')){throw 'Cole somente o token, sem o comando completo do site.'}
 Protect-Directory
 if($token){$secure=ConvertTo-SecureString $token -AsPlainText -Force;[IO.File]::WriteAllText($tokenFile,($secure|ConvertFrom-SecureString))}
 if(!(Test-Path -LiteralPath $keyFile)){
  $bytes=New-Object byte[] 32;$rng=[Security.Cryptography.RandomNumberGenerator]::Create()
  try{$rng.GetBytes($bytes)}finally{$rng.Dispose()}
  $secure=ConvertTo-SecureString ([Convert]::ToBase64String($bytes)) -AsPlainText -Force
  [IO.File]::WriteAllText($keyFile,($secure|ConvertFrom-SecureString))
 }
 $port=8086
 if(Test-Path -LiteralPath $configFile){$old=Load-Config;if($old.port){$port=$old.port}}
 Save-Json @{node=$node;script=$entry;ngrok=$ngrok;port=$port;connection=$connectionBox.Text.Trim();copilotUrl=$url;xurrentPath=$xp} $configFile
 [IO.File]::WriteAllText((Join-Path $DataDirectory 'ngrok.yml'),"version: 3`nagent:`n  web_addr: 127.0.0.1:4046`n")
 $script:copilotUrl=$url;$tokenBox.Clear();$tokenHint.Text='Token salvo protegido para este usuario. Deixe vazio para mante-lo.'
 $script:dirty=$false;$footer.Text='Configuracao salva. Conecte a VPN e clique em Iniciar publicacao.'
}
function Begin-Operation([string]$Action){
 if($script:operation){throw 'Aguarde a operacao atual terminar.'}
 Protect-Directory
 $id=[Guid]::NewGuid().ToString('N');$out=Join-Path $DataDirectory ('gui-'+$id+'.out.log');$err=Join-Path $DataDirectory ('gui-'+$id+'.err.log')
 $shell=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
 if($Action -like 'update-*'){
  if(!$script:updateSource){throw 'Escolha o version.json da pasta corporativa.'}
  $requestPath=Join-Path $DataDirectory ('update-request-'+$id+'.json')
  $responsePath=Join-Path $DataDirectory ('update-response-'+$id+'.json')
  $updateAction=if($Action -eq 'update-check'){'check'}else{'prepare'}
  Save-Json @{action=$updateAction;manifestPath=$script:updateSource;installPath=$PSScriptRoot;dataDirectory=$DataDirectory;responsePath=$responsePath} $requestPath
  $arguments=@('-NoProfile','-ExecutionPolicy','Bypass','-File',('"'+(Join-Path $PSScriptRoot 'LucyMcpUpdate.ps1')+'"'),'-RequestPath',('"'+$requestPath+'"'))
 }elseif($Action -eq 'install'){
  if(!(Get-Command winget.exe -ErrorAction SilentlyContinue)){throw 'Winget nao encontrado. Instale ngrok pelo site e use Localizar.'}
  $arguments=@('-NoProfile','-Command','winget.exe install ngrok -s msstore --accept-source-agreements --accept-package-agreements; exit $LASTEXITCODE')
 }else{$arguments=@('-NoProfile','-ExecutionPolicy','Bypass','-File',('"'+(Join-Path $PSScriptRoot 'LucyMcp.ps1')+'"'),$Action,'-DataDirectory',('"'+$DataDirectory+'"'))}
 $proc=Start-Process -FilePath $shell -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $out -RedirectStandardError $err
 $null=$proc.Handle
 $script:operation=@{process=$proc;action=$Action;out=$out;err=$err;response=$responsePath}
 foreach($b in $script:formButtons){$b.Enabled=$false}
 $installUpdate.Enabled=$false
 $footer.Text=if($Action -like 'update-*'){'Verificando e preparando atualizacao. Aguarde...'}elseif($Action -eq 'start'){'Iniciando MCP e tunel. Aguarde; a janela continua disponivel.'}elseif($Action -eq 'stop'){'Encerrando publicacao...'}elseif($Action -eq 'verify'){'Verificando arquivos e dependencias, sem iniciar servicos...'}else{'Instalando ngrok. A Microsoft Store pode solicitar autenticacao.'}
 $operationBox.Text=$footer.Text
}
$saveButton.Add_Click({try{Save-Settings;$tabs.SelectedTab=$runTab;Refresh-State}catch{Notify $_.Exception.Message $true}})
$startButton.Add_Click({try{Save-Settings;$tabs.SelectedTab=$runTab;Begin-Operation 'start'}catch{Notify $_.Exception.Message $true}})
$stopButton.Add_Click({try{Begin-Operation 'stop'}catch{Notify $_.Exception.Message $true}})
$ngrokInstall.Add_Click({try{Begin-Operation 'install'}catch{Notify $_.Exception.Message $true}})
$refreshButton.Add_Click({Refresh-State})
$verifyButton.Add_Click({try{Begin-Operation 'verify'}catch{Notify $_.Exception.Message $true}})
$selectSource.Add_Click({
 $d=New-Object Windows.Forms.OpenFileDialog;$d.Filter='Manifesto de atualizacao (version.json)|version.json';$d.Title='Selecione version.json na pasta sincronizada'
 if($env:OneDriveCommercial -and (Test-Path -LiteralPath $env:OneDriveCommercial)){$d.InitialDirectory=$env:OneDriveCommercial}
 try{if($d.ShowDialog($form) -eq 'OK'){
  Protect-Directory;$script:updateSource=$d.FileName;$updateSourceBox.Text=$script:updateSource
  Save-Json @{manifestPath=$script:updateSource} $updateSettingsFile
  $script:updateInfo=$null;$installUpdate.Enabled=$false;$updateState.Text='Fonte salva. Clique em Verificar atualizacoes.'
 }}finally{$d.Dispose()}
})
$checkUpdate.Add_Click({try{Begin-Operation 'update-check'}catch{Notify $_.Exception.Message $true}})
$installUpdate.Add_Click({try{
 if(!$script:updateInfo.available){throw 'Verifique se ha uma versao nova primeiro.'}
 $confirm=[Windows.Forms.MessageBox]::Show($form,('Instalar v'+$script:updateInfo.version+' da pasta selecionada? A publicacao sera parada e esta janela sera reiniciada.'),'Atualizar Lucy MCP','YesNo','Question')
 if($confirm -eq 'Yes'){Begin-Operation 'update-prepare'}
}catch{Notify $_.Exception.Message $true}})
$updateLogButton.Add_Click({$file=Join-Path $DataDirectory 'update-result.json';if(Test-Path -LiteralPath $file){Start-Process notepad.exe -ArgumentList ('"'+$file+'"')}else{Notify 'Nenhuma atualizacao aplicada ainda.'}})
$copyUrl.Add_Click({if($urlBox.Text){[Windows.Forms.Clipboard]::SetText($urlBox.Text);$footer.Text='URL MCP copiada.'}})
$copyKey.Add_Click({try{[Windows.Forms.Clipboard]::SetText(('Bearer '+(Read-Secret $keyFile)));$footer.Text='Authorization copiado. Cole na conexao do Copilot; nao e o token ngrok.'}catch{Notify $_.Exception.Message $true}})
$openCopilot.Add_Click({Start-Process $copilotUrl})
$openLog.Add_Click({
 $file=Join-Path $DataDirectory 'bridge-error.log'
 if(Test-Path -LiteralPath $file){Start-Process notepad.exe -ArgumentList ('"'+$file+'"')}
 elseif(Test-Path -LiteralPath $DataDirectory){Start-Process explorer.exe -ArgumentList ('"'+$DataDirectory+'"')}
 else{Notify 'Nenhum log foi criado ainda. Salve a configuracao e tente iniciar.'}
})
$lucyBox.Text=Join-Path $env:ProgramFiles 'dLucy';Find-Ngrok
if(Test-Path -LiteralPath $configFile){
 try{
  $cfg=Load-Config;$lucyBox.Text=Split-Path (Split-Path (Split-Path $cfg.script -Parent) -Parent) -Parent
  $ngrokBox.Text=$cfg.ngrok;$connectionBox.Text=$cfg.connection;$copilotBox.Text=$cfg.copilotUrl
  if($cfg.xurrentPath){$xCheck.Checked=$true;$xBox.Text=$cfg.xurrentPath}
  $tabs.SelectedTab=$runTab
 }catch{$footer.Text='Configuracao anterior nao pode ser lida. Preencha os campos para configurar novamente.'}
}
if(Test-Path -LiteralPath $tokenFile){$tokenHint.Text='Ja existe um token salvo. Deixe vazio para manter ou cole outro para substituir.'}
if(Test-Path -LiteralPath $updateSettingsFile){try{$script:updateSource=(Get-Content -Raw -LiteralPath $updateSettingsFile|ConvertFrom-Json).manifestPath;$updateSourceBox.Text=$script:updateSource}catch{}}
if(Test-Path -LiteralPath (Join-Path $DataDirectory 'update-result.json')){
 try{$r=Get-Content -Raw -LiteralPath (Join-Path $DataDirectory 'update-result.json')|ConvertFrom-Json
  if($r.ok){$updateState.Text='Ultima atualizacao concluida: v'+$r.version}else{$updateState.Text='A ultima atualizacao falhou. Abra o resultado para ver a causa.'}
 }catch{}
}
$timer=New-Object Windows.Forms.Timer;$timer.Interval=1000
$timer.Add_Tick({
 try{
 if($singleInstance -and $singleInstance.HasActivation()){$singleInstance.ShowExisting($form)}
 if($script:operation){
  $op=$script:operation
  if($op.process.HasExited){
   $code=$op.process.ExitCode
   $outText=if(Test-Path -LiteralPath $op.out){Get-Content -Raw -LiteralPath $op.out}else{''}
   $errText=if(Test-Path -LiteralPath $op.err){Get-Content -Raw -LiteralPath $op.err}else{''}
   $operationBox.Text=($outText+"`r`n"+$errText).Trim();$operationBox.SelectionStart=$operationBox.TextLength;$operationBox.ScrollToCaret()
   $script:operation=$null;foreach($b in $script:formButtons){$b.Enabled=$true}
   if($code -eq 0){
    $footer.Text='Operacao concluida.'
    if($op.action -eq 'update-check'){
     $response=Get-Content -Raw -LiteralPath $op.response|ConvertFrom-Json
     if(!$response.ok){throw $response.error}
     $script:updateInfo=$response.result;$updateNotes.Text=$script:updateInfo.release_notes
     $installUpdate.Enabled=[bool]$script:updateInfo.available
     $updateState.Text=if($script:updateInfo.available){'Nova versao disponivel: v'+$script:updateInfo.version}else{'Voce ja esta na versao mais recente desta fonte.'}
    }
    if($op.action -eq 'update-prepare'){
     $response=Get-Content -Raw -LiteralPath $op.response|ConvertFrom-Json
     if(!$response.ok){throw $response.error}
     $plan=$response.result
     $applyScript=Join-Path $plan.workPath 'apply-update.ps1'
     Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'LucyMcpUpdate.ps1') -Destination $applyScript
     $applyRequest=Join-Path $plan.workPath 'apply-request.json'
     Save-Json @{action='apply';plan=$plan;guiPid=$PID;guiStarted=(Get-Process -Id $PID).StartTime.ToUniversalTime().Ticks.ToString();responsePath=(Join-Path $plan.workPath 'apply-response.json')} $applyRequest
     $shell=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
     [void](Start-Process -FilePath $shell -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',('"'+$applyScript+'"'),'-RequestPath',('"'+$applyRequest+'"')) -WindowStyle Hidden -PassThru)
     $script:updating=$true;$form.Close()
    }
    if($op.action -eq 'install'){Find-Ngrok;$footer.Text='Instalacao concluida. Se ngrok nao aparecer, feche e abra esta janela.'}
    else{Remove-Item -LiteralPath $op.out,$op.err -ErrorAction SilentlyContinue}
   }else{$footer.Text='A operacao falhou. Consulte o resultado e use Abrir log.';Notify ("Nao foi possivel concluir a operacao.`r`nConsulte o resultado na aba Publicacao ou clique em Abrir log.`r`nSe houver acesso negado ao parar, use o mesmo nivel de permissao usado ao iniciar.") $true}
   $op.process.Dispose()
  }
 }
 Refresh-State
 }catch{
  $script:operation=$null
  foreach($b in $script:formButtons){$b.Enabled=$true}
  $installUpdate.Enabled=$false
  $footer.Text='Falha na operacao: '+$_.Exception.Message
  $updateState.Text=$footer.Text
  Notify $_.Exception.Message $true
 }
})
$form.Add_FormClosing({param($sender,$e)
 if($script:updating){return}
 if($script:operation){$e.Cancel=$true;Notify 'Aguarde a operacao terminar antes de fechar.';return}
 $state=Read-State
 if($state -and ((Owned-Process $state.bridge) -or (Owned-Process $state.ngrok))){
  $choice=[Windows.Forms.MessageBox]::Show($form,'A publicacao continuara ativa ao fechar. Para encerra-la, cancele e use Parar publicacao. Fechar mesmo assim?','Lucy MCP','YesNo','Question')
  if($choice -ne 'Yes'){$e.Cancel=$true}
 }
})
Refresh-State
if($SmokeTest){
 if($ValidateGui){
  # Isolated GUI checks: never use this mode with the real profile directory.
  if($DataDirectory -eq (Join-Path $env:LOCALAPPDATA 'LucyMcpCli')){throw 'Use an isolated DataDirectory for validation.'}
  $fixture=Join-Path $DataDirectory 'fixture-lucy'
  [void](New-Item -ItemType Directory -Force -Path (Join-Path $fixture 'resources\runtime'),(Join-Path $fixture 'resources\app'))
  [IO.File]::WriteAllText((Join-Path $fixture 'resources\runtime\node.exe'),'fixture')
  [IO.File]::WriteAllText((Join-Path $fixture 'resources\app\index.js'),'fixture')
  $fakeNgrok=Join-Path $DataDirectory 'fixture-ngrok.exe';[IO.File]::WriteAllText($fakeNgrok,'fixture')
  $lucyBox.Text=$fixture;$ngrokBox.Text=$fakeNgrok;$tokenBox.Text='test-token-not-valid-for-ngrok';$connectionBox.Text='TEST_CONNECTION';$xCheck.Checked=$false
  $copilotBox.Text='https://copilotstudio.microsoft.com/'
  Save-Settings
  if($tokenBox.Text){throw 'Token textbox was not cleared'}
  if((Read-Secret $tokenFile) -ne 'test-token-not-valid-for-ngrok'){throw 'Token protection roundtrip failed'}
  $savedCfg=Load-Config
  if($savedCfg.connection -ne 'TEST_CONNECTION'){throw 'Connection setting did not persist'}
  $secretBlob=Get-Content -Raw -LiteralPath $tokenFile
  if($secretBlob.Contains('test-token-not-valid-for-ngrok')){throw 'Token stored in plaintext'}
  $copilotBox.Text='https://example.com/'
  $rejected=$false;try{Save-Settings}catch{$rejected=$true}
  if(!$rejected){throw 'Invalid Copilot URL accepted'}
  $copilotBox.Text='https://copilotstudio.microsoft.com/'
  $tabs.SelectedTab=$runTab;$timer.Start();Begin-Operation 'status'
  $deadline=[DateTime]::UtcNow.AddSeconds(20)
  while($script:operation -and [DateTime]::UtcNow -lt $deadline){[Windows.Forms.Application]::DoEvents();Start-Sleep -Milliseconds 100}
  if($script:operation){throw 'Asynchronous CLI operation did not finish'}
  if($operationBox.Text -notlike '*Adaptador:*parado*'){throw 'CLI status output not shown'}
  $testManifest=Join-Path $DataDirectory 'version-test.json'
  [IO.File]::WriteAllText((Join-Path $DataDirectory 'fixture.zip'),'fixture')
  $fixtureVersion=([version]$appVersion).Major.ToString()+'.'+([version]$appVersion).Minor+'.'+(([version]$appVersion).Build+1)
  Save-Json @{version=$fixtureVersion;package='fixture.zip';sha256=('0'*64);release_notes='Fixture update'} $testManifest
  $script:updateSource=$testManifest
  Begin-Operation 'update-check'
  $deadline=[DateTime]::UtcNow.AddSeconds(20)
  while($script:operation -and [DateTime]::UtcNow -lt $deadline){[Windows.Forms.Application]::DoEvents();Start-Sleep -Milliseconds 100}
  if($script:operation -or !$script:updateInfo.available -or !$installUpdate.Enabled){throw 'Asynchronous update check failed'}
  $tabs.SelectedTab=$updateTab
  Write-Output 'GUI update check passed: local manifest discovered and install button enabled.'
  Write-Output 'GUI validation passed: save, DPAPI, token clearing, URL rejection and asynchronous CLI status.'
 }
 if($PreviewPath){$form.Show();[Windows.Forms.Application]::DoEvents();$bitmap=New-Object Drawing.Bitmap($form.Width,$form.Height);try{$form.DrawToBitmap($bitmap,(New-Object Drawing.Rectangle(0,0,$form.Width,$form.Height)));$bitmap.Save($PreviewPath)}finally{$bitmap.Dispose()}}
 $timer.Dispose();$form.Dispose();Write-Output 'GUI constructed successfully. No MCP publication or tunnel started.';return
}
$timer.Start()
try{[void]$form.ShowDialog()}finally{$timer.Stop();$timer.Dispose();$form.Dispose();if($singleInstance){$singleInstance.Dispose()}}
