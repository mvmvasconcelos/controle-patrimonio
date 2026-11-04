# Offline e Sincronização do webapp

Implementa a troca do repositório prevista no ADR 0001: as telas continuam usando `WebInventoryRepository`; em produção o `main.dart` injeta `OfflineInventoryRepository` (`lib/services/offline/`), que envolve o repositório HTTP e um cache em Hive (IndexedDB no navegador). Se o navegador negar o armazenamento (modo privativo), o app cai para o repositório HTTP puro, sem offline.

## O que é guardado no navegador

| Box Hive | Conteúdo |
|---|---|
| `offline_entries` | Patrimônios (JSON) |
| `offline_photos` / `offline_photo_index` | Bytes das fotos e índice (pendente ou em cache, tamanho, último uso) |
| `offline_queue` | Fila de pendências em ordem (`update`, `create`, `check`, `upload_photo`, `delete_photo`), cada uma com o horário do cliente |
| `offline_meta` | Nome e papel do último usuário, data da última Sincronização, contador de ids temporários de foto |

**Nunca** são persistidos JWT, token CSRF ou senha. A sessão de 30 dias continua apenas no cookie HttpOnly; o CSRF é obtido do servidor a cada sessão verificada.

## Fluxos

- **Escrita**: com rede e sessão verificada vai direto ao servidor (com `editado_em`). Sem rede, servidor indisponível (rede/5xx) ou sessão expirada, é aplicada ao cache e enfileirada. Se já há pendência para o Patrimônio, a escrita também é enfileirada, preservando a ordem.
- **Leitura**: servidor primeiro; sem rede, lista/busca/filtros/relatório são calculados a partir do cache. Fotos são cacheadas ao listar/ver e ficam disponíveis após recarregar.
- **Recarregar offline**: `restoreSession` não alcança o servidor e usa o último usuário lembrado (sessão "offline", sem CSRF). Após **Sair** esse acesso é revogado, mas o cache e a fila permanecem.
- **Sincronização** (manual pelo botão ou automática ao voltar a rede, ao entrar, após importar e a cada 60 s se houver pendências ou o servidor estiver inalcançável): renova a sessão, envia a fila em ordem e baixa o Inventário completo, preservando Patrimônios com pendências locais.
- **Indicador**: barra com Online/Offline, número de pendências, itens com erro, edições substituídas e aviso de sessão expirada com "Entrar novamente".

## Last-write-wins

Por Patrimônio. O cliente envia `editado_em` (UTC) em `PATCH /patrimonio/{n}`; o servidor guarda o horário da última edição aplicada (`patrimonio_edicoes`). Edição mais antiga é descartada e a resposta traz o estado atual com `edicao_aplicada: false` (o cliente atualiza o cache e mostra o aviso). Horário igual é aplicado (reenvio idempotente). Sem `editado_em` vale o horário do servidor. Horários mais de 5 minutos no futuro são limitados ao horário do servidor, para que um relógio errado não bloqueie edições futuras. A granularidade é o Patrimônio inteiro, não o campo.

A Conferência é idempotente: o primeiro horário registrado é mantido, e `POST .../conferencia` aceita `editado_em` opcional como horário da Conferência. Fotos são aditivas (sem conflito).

## Sessão expirada e falhas

A fila só perde um item quando ele é enviado com sucesso (ou o usuário cancela o upload pendente). Rede, 5xx, 401 e 403 interrompem a Sincronização e mantêm tudo. Rejeições definitivas (404/409/422 etc.) ficam na fila marcadas com erro, contam em "com erro" e não bloqueiam os demais. A fila sobrevive a Sair/Entrar, sessão expirada e recarga da página.

## Limite de armazenamento

Os limites de IndexedDB variam por navegador e por espaço livre em disco (Chrome/Edge: fração grande do disco; Firefox: fração do disco com teto por grupo; Safari: bem menor e pode apagar dados de sites sem uso). Como `navigator.storage.estimate()` não é confiável entre navegadores, o app usa um **orçamento próprio de 100 MB** para fotos (`defaultPhotoBudgetBytes`), independente do navegador.

- Fotos JPEG redimensionadas têm tipicamente algumas centenas de KB (teto do servidor: 5 MB); com 3 fotos por Patrimônio, 100 MB comportam centenas de Patrimônios fotografados.
- Fotos apenas em cache (baixadas do servidor) são descartadas, menos usadas primeiro, para dar lugar a novas.
- Fotos **pendentes nunca são descartadas**. Se uma nova foto offline não couber mesmo após descartar todo o cache, o envio é recusado com `StorageQuotaExceededException` ("Armazenamento do navegador cheio…"), sem alterar a fila nem as outras fotos.
- Erros reais de cota do navegador na escrita (mensagem contendo "quota") recebem o mesmo tratamento.
- Patrimônios e fila são pequenos (JSON) e não entram no orçamento; sem espaço para eles a escrita falha com erro e nada é perdido silenciosamente.

Testes: `test/offline_store_test.dart` (orçamento, descarte, pendentes, erro de cota) e `test/offline_inventory_repository_test.dart` (recusa limpa de foto offline). Usam o orçamento configurável, sem depender da cota real do navegador.

## Limitações conhecidas

- Não há teste automatizado em navegador real com IndexedDB e service worker; a validação cobre Hive na VM, API e build web.
- O cache de fotos cobre as vistas/enviadas neste navegador; não há pré-carga em massa de fotos de todo o Inventário.
- O Inventário é baixado por inteiro a cada Sincronização (páginas de 200).
- Gestão de dados (importar/exportar) exige conexão.
- Dados ficam em claro no navegador após Sair (necessário para preservar a fila); use perfil/dispositivo de confiança.
- Criar Patrimônio offline que já exista no servidor é rejeitado na Sincronização e fica marcado com erro.
- O shell do app offline depende do service worker do Flutter (`flutter_bootstrap.js`), carregado por `web/index.html` (que antes não iniciava o Flutter); o nginx serve `index.html`, `flutter_bootstrap.js` e `flutter_service_worker.js` com `no-cache` para revalidação.
