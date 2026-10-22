# Historico de versoes

## 0.3.3 - 2026-10-22

- Atualizacao direta pelo GitHub publico, sem conta ou token dos N1.
- Manifesto da ultima release e download do ZIP por HTTPS, com limites de tamanho e validacao SHA-256.
- Opcao Usar GitHub na interface; a pasta corporativa continua disponivel.

## 0.3.2 - 2026-10-22

- Logo de conexao no cabecalho e icone da janela, da barra de tarefas e do executavel.
- Recursos locais leves; nao adiciona dependencias para mostrar o logo.

## 0.3.1 - 2026-10-22

- Uma unica interface por usuario, sessao Windows e pasta de dados, mesmo abrindo de outra pasta de instalacao.
- Segunda abertura restaura a janela minimizada e solicita foco para a janela existente.
- Fechar a interface libera a instancia para abrir normalmente depois; encerramento inesperado nao deixa arquivo de bloqueio.

## 0.3.0 - 2026-10-22

- Versao centralizada e exibida na interface, no status e nos logs de inicializacao.
- Verificacao e atualizacao por manifesto em pasta OneDrive/SharePoint sincronizada.
- Validacao SHA-256 do pacote, inventario de arquivos, backup e restauracao em falha de copia.
- Preservacao das configuracoes e tokens do perfil Windows.
- Build reproduzivel com dependencias fixadas em package-lock.json e manifesto de distribuicao.
- Inclui as correcoes anteriores: Xurrent iniciado uma unica vez pelo BAT, normalizacao CRLF e verificacao de dependencias incompletas.

## 0.2.0 e pacotes anteriores sem identificacao

POC com CLI, interface Windows Forms, ngrok e integracao Xurrent. Pacotes anteriores eram substituidos com o mesmo nome e nao mostravam uma versao confiavel na interface.
