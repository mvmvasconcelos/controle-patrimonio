# Roadmap de Desenvolvimento: Sistema de Controle Patrimonial IFSUL

## Descrição do Sistema

O Sistema de Controle Patrimonial é uma ferramenta focada na **eficiência do trabalho de campo**, desenvolvida em Flutter (Android) com um backend local de suporte (FastAPI + SQLite). O objetivo primário é substituir o processo manual de conferência com planilhas impressas, otimizando a coleta de dados e a posterior atualização no sistema SUAP.

O app funcionará como uma "prancheta digital", permitindo ao usuário escanear itens de forma individual ou em lote, identificar rapidamente inconsistências de localização, editar informações e registrar novos itens não catalogados. A funcionalidade mais importante é a geração de um relatório final, em formato de planilha, que consolida **apenas os itens que sofreram alterações**, destacando as células modificadas para facilitar e agilizar a etapa de atualização manual no SUAP.

No estado atual do projeto, o fluxo **offline por planilha** permanece como prioridade operacional. O backend segue como suporte e evolucao para sincronizacao progressiva (incluindo fotos de itens), sem quebrar o fluxo offline durante a transicao.

---

## Etapas do Desenvolvimento

### Etapa 1: Infraestrutura Local (Base de Operações)

**Objetivo:** Configurar o backend e a base de dados para suportar o sistema.

-   [x] **1.1. Backend FastAPI + SQLite**
    -   [x] **1.1.1.** Configurar o servidor em `128.1.1.49`
    -   [x] **1.1.2.** Criar tabela `patrimonio` com as colunas do SUAP
    -   [x] **1.1.3.** Implementar endpoint `GET /patrimonio` para o app baixar a base de dados completa para uso offline
    -   [x] **1.1.4.** Implementar endpoint `POST /patrimonio/update` para receber e salvar as alterações feitas no app

-   [x] **1.2. Script Inicial de Carga**
    -   [x] **1.2.1.** Desenvolver script para importação inicial do CSV do SUAP para o banco de dados SQLite do servidor

---

### Etapa 2: Estrutura Base do Aplicativo Flutter

**Objetivo:** Criar a estrutura fundamental do app com armazenamento offline.

-   [x] **2.1. Configuração do Banco de Dados Local**
    -   [x] **2.1.1.** Implementar banco de dados local (Hive) para armazenar os dados do patrimônio
    -   [x] **2.1.2.** Garantir funcionamento 100% offline do aplicativo

-   [x] **2.2. Tela Principal**
    -   [x] **2.2.1.** Criar tela principal com dois botões: **"Escaneamento Individual"** e **"Escaneamento em Lotes"**
    -   [x] **2.2.2.** Implementar popup "Deseja informar qual é a sala?" com `input select` antes de iniciar o scanner

---

### Etapa 3: Módulo de Escaneamento

**Objetivo:** Integrar e configurar o scanner de código de barras com feedback adequado.

-   [x] **3.1. Integração do Scanner**
    -   [x] **3.1.1.** Integrar e adaptar o scanner de código de barras (`barcode-scanner`)

-   [x] **3.2. Feedback Sonoro e Háptico**
    -   [x] **3.2.1.** Implementar feedback para sucesso (item novo escaneado)
    -   [x] **3.2.2.** Implementar feedback para duplicado (item já escaneado na sessão atual)
    -   [x] **3.2.3.** Implementar feedback para não encontrado / erro

---

### Etapa 4: Fluxo de Escaneamento Individual

**Objetivo:** Permitir o escaneamento e edição de itens individuais com detecção de inconsistências.

-   [x] **4.1. Modal de Visualização/Edição**
    -   [x] **4.1.1.** Ao escanear/digitar, abrir modal/formulário com os dados principais: `Nº de Patrimônio`, `Descrição`, `Sala`, `Responsável`, `Situação`
    -   [x] **4.1.2.** Permitir a edição dos campos
    -   [x] **4.1.3.** Implementar botão "Atualizar Item" para salvar as alterações

-   [x] **4.2. Destaque de Inconsistências**
    -   [x] **4.2.1.** Se uma sala foi pré-selecionada, destacar o campo "Sala" com uma borda colorida caso o valor seja diferente do esperado

-   [x] **4.3. Lógica para Item Não Encontrado**
    -   [x] **4.3.1.** Exibir mensagem "O Patrimônio não foi encontrado. Tentar novamente ou registrar novo?"
    -   [x] **4.3.2.** Implementar opção "Registrar Novo" que abre o mesmo modal em branco para preenchimento

---

### Etapa 5: Fluxo de Escaneamento em Lotes

**Objetivo:** Permitir escaneamento rápido de múltiplos itens com visualização em lista.

-   [x] **5.1. Scanner Contínuo**
    -   [x] **5.1.1.** Manter o scanner ativo, adicionando cada item escaneado a uma lista interna
    -   [x] **5.1.2.** Ao fechar o scanner, exibir a lista rolável dos itens

-   [x] **5.2. Destaque Visual na Lista**
    -   [x] **5.2.1.** Itens de sala diferente da pré-selecionada devem ter um fundo de cor sutilmente diferente
    -   [x] **5.2.2.** Itens não encontrados no banco de dados devem ter outra cor de destaque

-   [x] **5.3. Interações na Lista**
    -   [x] **5.3.1.** Implementar deslizar para a esquerda para excluir o item da lista (cancela o escaneamento)
    -   [x] **5.3.2.** Implementar tocar ou deslizar para a direita para abrir o modal/formulário de visualização/edição

---

### Etapa 6: Rastreamento de Alterações

**Objetivo:** Registrar todas as modificações feitas nos itens para gerar relatórios precisos.

-   [x] **6.1. Sistema de Tracking no App**
    -   [x] **6.1.1.** Ao clicar em "Atualizar Item", salvar não apenas o novo estado, mas também quais campos foram alterados
    -   [x] **6.1.2.** Armazenar formato de alteração: `campo: 'valor_antigo' -> 'valor_novo'`

---

### Etapa 7: Importação e Exportação de Planilha SUAP

**Objetivo:** Permitir que o app funcione de forma independente do backend, usando a própria planilha exportada do SUAP como base de dados.

-   [x] **7.1. Importação**
    -   [x] **7.1.1.** Suporte a `.csv`, `.xls` e `.xlsx` exportados do SUAP
    -   [x] **7.1.2.** Mapeamento automático de colunas SUAP → modelo interno
    -   [x] **7.1.3.** Preservação de todos os dados brutos originais para exportação fiel
    -   [x] **7.1.4.** Aviso ao sobrescrever dados com modificações pendentes
    -   [x] **7.1.5.** App aparece no menu "Abrir com" / "Compartilhar" do Android para arquivos SUAP

-   [x] **7.2. Listagem do Inventário**
    -   [x] **7.2.1.** Tela de listagem completa com busca por nº, descrição, sala e responsável
    -   [x] **7.2.2.** Filtros por sala e por itens modificados
    -   [x] **7.2.3.** Destaque visual para itens que sofreram alterações

-   [x] **7.3. Exportação**
    -   [x] **7.3.1.** Exportar apenas itens modificados (mesmo formato/colunas do SUAP)
    -   [x] **7.3.2.** Exportar planilha completa com coluna `ATUALIZADO_EM` (preenchida só nos alterados)
    -   [x] **7.3.3.** Células modificadas destacadas em amarelo no `.xlsx`
    -   [x] **7.3.4.** Escolha de formato: `.xlsx` ou `.csv`

---

### Etapa 8: Geração do Relatório de Modificações (Visão App)

**Objetivo:** Interface dedicada para visualizar e exportar as alterações realizadas durante a sessão.

-   [x] **8.1. Tela de Relatórios**
    -   [x] **8.1.1.** Criar nova seção no app para "Relatórios"
    -   [x] **8.1.2.** Implementar botão "Gerar Planilha de Atualização do SUAP"

-   [x] **8.2. Lógica de Geração da Planilha**
    -   [x] **8.2.1.** Coletar todos os itens que foram marcados como modificados
    -   [x] **8.2.2.** Gerar arquivo `.xlsx` com a mesma estrutura e colunas da planilha original do SUAP
    -   [x] **8.2.3.** **Funcionalidade Chave:** Destacar (com cor de fundo) as células específicas que sofreram alteração
    -   [x] **8.2.4.** Permitir que o usuário abra/compartilhe este arquivo

---

### Etapa 9: Histórico de Alterações no Servidor

**Objetivo:** Registrar log de todas as modificações no backend para auditoria. *(Prioridade baixa)*

-   [ ] **9.1. Tabela de Logs**
    -   [ ] **9.1.1.** Criar tabela `historico_alteracoes` no SQLite do servidor

-   [ ] **9.2. Endpoint de Log**
    -   [ ] **9.2.1.** Modificar endpoint `POST /patrimonio/update` no FastAPI para registrar logs
    -   [ ] **9.2.2.** Armazenar: `id_item`, `campo_alterado`, `valor_antigo`, `valor_novo`, `timestamp`

---

### Etapa 10: Funcionalidade de Fotos

**Objetivo:** Permitir registro fotográfico dos itens patrimoniais.

**Status de fechamento:** Concluída e validada em campo (17/04/2026).  
**Documento de referência:** `docs/implementacao_fotos.md`.

-   [x] **10.1. Interface no App**
    -   [x] **10.1.1.** Implementar botão no modal para `tirar foto / escolher da galeria`

-   [x] **10.2. Armazenamento no Servidor**
    -   [x] **10.2.1.** Criar endpoint no FastAPI para receber upload da imagem
    -   [x] **10.2.2.** Persistir foto associada ao item no backend (modelo `fotos_patrimonio`)

-   [x] **10.3. Visualização**
    -   [x] **10.3.1.** Exibir foto do item no modal e na visualização de detalhe
    -   [x] **10.3.2.** Implementar cache/armazenamento local de imagens para visualização offline

---

### Etapa 11: Relatórios Adicionais

**Objetivo:** Fornecer relatórios úteis para gestão administrativa.

-   [ ] **11.1. Relatório de Itens por Sala/Responsável**
    -   [ ] **11.1.1.** Gerar listas simples de itens agrupados por sala
    -   [ ] **11.1.2.** Gerar listas simples de itens agrupados por responsável

-   [ ] **11.2. Relatório de Itens Não Encontrados**
    -   [ ] **11.2.1.** Listar todos os itens de uma sala que não foram escaneados durante uma sessão de "Escaneamento em Lotes"

---

### Etapa 12: Dashboard e Visão Geral

**Objetivo:** Criar interface de visão geral com métricas e estatísticas.

-   [ ] **12.1. Tela Inicial Aprimorada**
    -   [ ] **12.1.1.** Criar dashboard simples com métricas úteis
    -   [ ] **12.1.2.** Exibir "Itens atualizados hoje"
    -   [ ] **12.1.3.** Exibir "Última sincronização com SUAP"
    -   [ ] **12.1.4.** Adicionar outras métricas relevantes para o usuário