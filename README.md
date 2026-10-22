# Lucy MCP CLI — POC Windows

## Versao e atualizacoes pela pasta corporativa

Esta distribuicao e a **v0.3.2**. A versao fica centralizada em `app-version.json` e aparece no titulo da janela, no status do CLI e nos diagnosticos do adaptador. O historico esta em `CHANGELOG.md`.

A interface permite uma unica janela por usuario, sessao Windows e pasta de dados. Abrir novamente pelo executavel ou atalho traz a janela existente para frente e restaura se estiver minimizada. Isso tambem vale para outra copia da instalacao usando o mesmo perfil. Fechar a janela permite uma nova abertura normal. Essa protecao esta disponivel a partir da v0.3.1; feche janelas de versoes anteriores antes de instalar.

Para instalar esta primeira versao com atualizador, pare a publicacao, feche a interface e extraia o ZIP completo em uma pasta local nova. Abra `LucyMcp.exe` e use Verificar pacote. As configuracoes do mesmo usuario Windows continuam em `%LOCALAPPDATA%\LucyMcpCli`; nao e necessario repetir o onboarding.

Na aba **3. Atualizacoes**, clique Escolher e selecione o arquivo `version.json` na pasta corporativa sincronizada pelo OneDrive/SharePoint. Cada usuario seleciona seu caminho local; a pasta nao precisa ter a mesma localizacao nas outras maquinas. Clique Verificar atualizacoes. Quando houver uma versao maior, leia as notas e use Instalar e reiniciar.

O atualizador copia o ZIP para uma area temporaria, confere SHA-256 do pacote e dos arquivos, encerra a publicacao e substitui somente arquivos diferentes. Configuracoes e tokens ficam fora da instalacao e sao preservados. Se a substituicao falhar, tenta restaurar os arquivos anteriores. A interface reabre ao terminar; clique Iniciar publicacao quando quiser publicar novamente e abra uma nova sessao de teste no Copilot. O processo exige permissao de escrita na pasta local da instalacao.

Mantenha ZIP e manifesto disponiveis offline na pasta sincronizada. Uma copia incompleta sera rejeitada; aguarde a sincronizacao e tente novamente. O resultado fica em `%LOCALAPPDATA%\LucyMcpCli\update-result.json`; backups e arquivos preparados ficam em `updates` nessa mesma pasta e sao retidos nesta versao para diagnostico. A atualizacao depende da confirmacao do usuario. SHA-256 verifica integridade; a origem confiavel e a pasta corporativa, cujo acesso de gravacao deve ficar com os responsaveis pela distribuicao. O pacote nao e assinado.

## Gerar e distribuir uma versao

No repositorio de codigo-fonte, altere a versao em `app-version.json`, `package.json` e na entrada raiz de `package-lock.json`; registre as mudancas no `CHANGELOG.md`. Use versoes numericas como `0.3.1`, `0.4.0` e `1.0.0`; o comparador nao compara texto e nao instala downgrade.

Execute `build.ps1` com Windows PowerShell 5.1. Ele compila o pequeno lancador, exige as dependencias nas versoes fixadas e gera **LucyMcpCli-fixed-portable.zip** mais **version.json**. Caso necessario, informe `-DependencyDirectory` apontando para um `node_modules` completo. O manifesto contem versao, nome relativo do ZIP, hash e notas; o inventario de arquivos vai dentro do ZIP. Nao edite esses hashes manualmente.

Copie os dois arquivos para uma pasta corporativa dedicada: primeiro o ZIP e por ultimo `version.json`. Aguarde a sincronizacao antes de avisar a equipe. Preserve releases anteriores em uma pasta de arquivo separada se desejar historico. Nunca publique config.json, arquivos DPAPI ou a pasta de dados de um usuario.

O codigo-fonte e controlado em Git; o build e reproduzido pelo script e cada release pode receber uma tag `v0.3.0`. Nenhum repositorio remoto e necessario para distribuir pela pasta corporativa. O ZIP inclui as dependencias completas para evitar a instalacao incompleta que causou ERR_MODULE_NOT_FOUND.

## Interface para a equipe

Extraia o ZIP inteiro e abra **LucyMcp.exe** com duplo clique. O executavel e um lancador de 5 KB; a interface usa Windows Forms e o Windows PowerShell 5.1 ja disponiveis no Windows, sem Electron ou navegador embutido. O pacote continua incluindo o adaptador Node e suas dependencias. O executavel nao e assinado; a politica de aplicativos da empresa pode exigir liberacao pela TI.

Na aba Configuracao, selecione a pasta da Lucy e localize ou instale ngrok. Use Abrir site / obter token, copie o campo Authtoken e clique Colar. Se ja configurou neste usuario Windows, deixe o campo vazio para manter o token salvo. Se desejar, informe o nome da conexao SAP; este campo permite digitacao e ainda nao consulta automaticamente as conexoes da Lucy. Xurrent e opcional: marque a opcao e selecione a pasta com iniciar-mcp.bat. O link do agente tambem e opcional.

Clique Salvar e continuar. Na aba Publicacao, conecte a VPN manualmente e use Iniciar publicacao. A janela continua responsiva durante a inicializacao. Use Copiar URL, Copiar chave MCP e Abrir Copilot Studio para cadastrar o servidor. A chave copiada contem o prefixo Bearer e nao e o authtoken ngrok. Fechar a janela nao encerra a publicacao: use Parar publicacao antes de fechar quando quiser interromper o acesso. O aplicativo avisa se a publicacao continuara ativa.

O status mostra adaptador, tunel e contagem das ferramentas. Abrir log abre o arquivo da inicializacao. Configuracoes existentes do CLI sao reutilizadas no mesmo perfil Windows; nao precisa repetir onboarding. O atalho setup.cmd tambem abre a interface. LucyMcpGui.cmd e uma alternativa de inicializacao com console para diagnostico; o CLI tradicional continua disponivel para uso avancado.

Se aparecer ERR_MODULE_NOT_FOUND para um arquivo em node_modules, a instalacao esta incompleta ou o arquivo foi removido. Pare a publicacao, feche a interface e extraia o ZIP COMPLETO diretamente numa pasta nova, evitando mover milhares de arquivos depois da extracao. Abra LucyMcp.exe dentro da pasta nova e use Verificar pacote antes de iniciar. Essa verificacao tambem roda automaticamente no start, identifica arquivos obrigatorios ausentes e carrega a arvore real de dependencias sem iniciar Lucy, Xurrent ou tunel. Nao e necessario repetir o onboarding no mesmo usuario Windows. Se o arquivo continuar ausente apos extrair, confirme o historico de protecao com a TI; nao desabilite o antivirus.

Validacao da interface: criacao das tres abas, salvamento em perfil de teste, protecao DPAPI, limpeza do campo token, rejeicao de link Copilot invalido e comando status em segundo plano. O fluxo visual de instalacao ngrok/primeiro start em outro computador ainda requer teste piloto.

Extraia o ZIP inteiro em uma pasta local. Precisa de dLucy instalada e configurada, acesso ao SAP (VPN conectada quando necessario) e conta ngrok. Nao precisa de VM, Node global ou npm: reutiliza o Node da Lucy e inclui as dependencias do adaptador.

## Uso no terminal, na pasta extraida

Para o assistente de texto, execute `lucy-mcp.cmd setup`. Ele mostra uma etapa por tela: apos validar, pressione Enter para continuar e limpar a tela. No CMD, digite A quando solicitado para abrir o site no navegador, sem depender de Ctrl+clique. Copie somente o campo Authtoken, e nao o comando completo do site. Para a equipe, prefira LucyMcp.exe ou setup.cmd, que abrem a interface grafica.

```powershell
.\lucy-mcp.cmd setup
.\lucy-mcp.cmd start
.\lucy-mcp.cmd key
.\lucy-mcp.cmd copilot
.\lucy-mcp.cmd status
.\lucy-mcp.cmd stop
.\lucy-mcp.cmd help
.\lucy-mcp.cmd verify
```

`setup` detecta a Lucy, instala ngrok pela Microsoft Store se ausente, solicita authtoken de forma oculta e gera uma chave propria para o MCP. Se o PATH nao atualizar, abra outro terminal e repita setup. O primeiro start chama setup se necessario.

`help` lista os comandos e exemplos quando precisar consultar o uso.

## MCP Xurrent da extensao Chrome

Opcional: o CLI pode publicar Lucy e Xurrent pelo mesmo endpoint `/mcp` e pela mesma chave. O projeto Xurrent precisa estar instalado em cada computador; ele nao acompanha este ZIP. Sua pasta pode variar entre usuarios. O setup pergunta a pasta que contem `iniciar-mcp.bat`, e a configuracao fica salva somente neste computador.

Para habilitar numa instalacao ja configurada:

```powershell
.\lucy-mcp.cmd stop
.\lucy-mcp.cmd xurrent -XurrentPath "C:\Projetos\chrome-xurrent-extension"
.\lucy-mcp.cmd start
.\lucy-mcp.cmd status
```

Tambem pode informar a pasta diretamente no start, com a publicacao parada:

```powershell
.\lucy-mcp.cmd start -XurrentPath "C:\Projetos\chrome-xurrent-extension"
```

O start usa uma unica instancia Xurrent, iniciada pelo `iniciar-mcp.bat`, e conversa por stdio com essa mesma instancia. Nao inicia um segundo server.js. Um transporte leve separa banners do BAT das mensagens JSON-RPC. Uma copia temporaria de execucao na pasta de dados normaliza as quebras de linha para CRLF e preserva o diretorio original referenciado por `%~dp0`; o projeto original nao e alterado. O stop encerra a arvore BAT/servidor criada por este adaptador. Se outro agente ja ocupa a porta 9595, a compatibilidade depende da versao do projeto: versoes antigas sem modo Worker exigem encerrar a outra instancia Xurrent antes do start. O CLI nao encerra automaticamente servidores pertencentes a outros agentes.

Teste de regressao: BAT com banners e quebras LF, projeto em pasta com espacos, uma unica inicializacao de servidor, initialize/list/call e parada sem processo filho escutando. O teste usou servidores ficticios locais; nao consultou SAP nem chamados e nao publicou ngrok.

Dependencias: o Node distribuido com a Lucy e incluido no PATH do BAT. Se `mcp-server/node_modules` ainda nao estiver instalado, e necessario npm disponivel no computador; o proprio BAT executa `npm install`. A primeira inicializacao pode levar ate 150 segundos. A porta WebSocket continua em loopback: somente o endpoint HTTP autenticado e publicado. Chrome com a extensao habilitada e a sessao Xurrent autenticada precisam continuar abertos; o start nao faz login no site.

As ferramentas recebem prefixo para evitar conflito: `xurrent_check_chrome_connection`, `xurrent_get_ticket_metadata` e `xurrent_get_xurrent_ticket`. Atualize o catalogo no Copilot Studio depois de ativar. O status separa a quantidade Lucy/Xurrent e avisa quando o total excede 70. Com 64 ferramentas Lucy e 3 Xurrent, o total esperado e 67, dependendo dos bundles ativos.

Para desabilitar, execute stop, depois `lucy-mcp.cmd xurrent -XurrentPath ""` (ou apenas `xurrent` e Enter na pergunta), e start novamente. A publicacao usa as permissoes da sessao Chrome deste usuario. Downloads de anexos e gravacao local continuam sendo opcoes das ferramentas Xurrent.

`start` mostra o endereco HTTPS completo com `/mcp`, quantidade de ferramentas e link para o Copilot Studio. `key` copia `Bearer CHAVE` diretamente para a area de transferencia, sem imprimi-lo. A area de transferencia pode participar de historico/sincronizacao do Windows; limpe-a depois de colar na conexao.

No Copilot Studio: Ferramentas > Adicionar ferramenta > Nova ferramenta > MCP. Use a URL exibida, autenticacao API key, tipo Header e nome `Authorization`. Crie uma conexao e cole o valor copiado por key. Atualize ferramentas se o catalogo mudar. O setup permite informar o link de um agente existente; copilot abre esse link, ou o portal se nao configurado. Selecionar/criar/editar o agente e responsabilidade do usuario.

## Validacao desta versao

Integracao Xurrent validada localmente com o projeto informado: 64 ferramentas Lucy + 3 Xurrent = 67, bloqueio HTTP 401 sem chave, encaminhamento do diagnostico Xurrent e parada dos subprocessos. A extensao Chrome nao estava pronta para responder ao diagnostico; nenhuma request/ticket foi consultada e nenhum tunel foi publicado durante esse teste. Consulta real de chamados pelo Copilot ainda precisa ser validada com Chrome/extensao/sessao ativos.

Testado no Windows PowerShell 5.1, com o Node distribuido na Lucy: start local sem tunel, catalogo completo de 99 ferramentas, diagnostico lucy_info, rejeicao de chave ausente/incorreta, bloqueio de override de ambiente SAP, stop e status. Nenhuma operacao de escrita SAP foi executada. O caminho ngrok + Copilot foi validado no adaptador anterior; a instalacao inicial em outro computador e o start automatico do ngrok neste pacote ainda precisam de teste piloto. Pacote nao assinado; atualizacao assistida disponivel na aba Atualizacoes.

## Ambiente

```powershell
.\lucy-mcp.cmd stop
.\lucy-mcp.cmd connection -Connection DSB_GL_EVENTS_DEV
.\lucy-mcp.cmd start
```

O adaptador publica TODAS as ferramentas anunciadas pela Lucy, inclusive operacoes de escrita. Nao implementa modo somente leitura. Permissoes, guardrails e credenciais existentes da Lucy/SAP continuam em vigor. Ferramentas com parametro `connection` recebem o ambiente configurado e nao aceitam outro. Ferramentas sem esse parametro preservam o comportamento da Lucy, incluindo outros dominios (ALM, arquivos locais, geracao de projetos). Portanto esta configuracao NAO constitui isolamento completo por cliente e nao substitui autorizacao por usuario. Uma chave compartilhada nao identifica o consultor.

O CLI nao conecta, desconecta nem configura VPN. Nao troca globalmente o ambiente da interface Lucy ao iniciar. Conecte a VPN manualmente e confirme o acesso ao ambiente escolhido. Todos com a chave e URL podem executar as ferramentas com as credenciais desta instalacao; distribua somente a equipe autorizada.

## Dados locais e parada

Quando o adaptador nao inicia, a mensagem mostra o caminho completo de `bridge-error.log`. O log identifica a etapa (Lucy ou Xurrent) e inclui as ultimas linhas de stderr apenas da inicializacao, com redacao de formatos comuns de credenciais. Revise o conteudo antes de compartilhar. A saida de erro posterior a inicializacao continua descartada.

Configuracao e estado em `%LOCALAPPDATA%\LucyMcpCli`. Authtoken e chave protegidos com DPAPI do usuario Windows, alem de ACL na pasta. Nao sao incluidos no ZIP. A chave MCP e enviada ao ngrok no uso do endpoint HTTPS; o fornecedor termina TLS.

O adaptador escuta apenas em loopback, valida Host/Origin, exige Bearer em todas as requisicoes, limita sessoes e expira sessoes ociosas. Ngrok reescreve Host e desabilita inspecao local de trafego. Logs do subprocesso Lucy sao descartados para evitar registrar credenciais. Não protege contra outros processos maliciosos rodando como o mesmo usuario.

`stop` encerra somente processos registrados por este CLI, conferindo PID e horario de inicio. O ngrok para primeiro; o adaptador fecha a Lucy filha depois. A instancia anterior da Lucy, a VPN e outros tuneis nao sao encerrados. Evite fechar o Windows/forcar encerramento durante start/stop.

Se ja houver um tunel usando o mesmo dominio ngrok, pare-o antes. VPNs corporativas podem impedir o tunel; valide do Copilot Studio. Atualizacoes da Lucy podem exigir repetir setup/revalidar o pacote.

## Teste local sem publicar

```powershell
.\lucy-mcp.cmd start -NoTunnel
.\lucy-mcp.cmd stop
```

CLI usa porta local 8086 e API local ngrok 4046. Não interfere no teste anterior da porta 8085. Este pacote e uma POC nao assinada; restricoes de execucao/instalacao da empresa continuam aplicaveis.
