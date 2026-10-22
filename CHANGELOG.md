# Historico de versoes

## 0.3.0 - 2026-10-22

- Versao centralizada e exibida na interface, no status e nos logs de inicializacao.
- Verificacao e atualizacao por manifesto em pasta OneDrive/SharePoint sincronizada.
- Validacao SHA-256 do pacote, inventario de arquivos, backup e restauracao em falha de copia.
- Preservacao das configuracoes e tokens do perfil Windows.
- Build reproduzivel com dependencias fixadas em package-lock.json e manifesto de distribuicao.
- Inclui as correcoes anteriores: Xurrent iniciado uma unica vez pelo BAT, normalizacao CRLF e verificacao de dependencias incompletas.

## 0.2.0 e pacotes anteriores sem identificacao

POC com CLI, interface Windows Forms, ngrok e integracao Xurrent. Pacotes anteriores eram substituidos com o mesmo nome e nao mostravam uma versao confiavel na interface.
