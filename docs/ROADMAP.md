# Roadmap de Desenvolvimento: Sistema de Controle Patrimonial IFSUL

## Descrição do Sistema

O Sistema de Controle Patrimonial é uma ferramenta focada na **eficiência do trabalho de campo**, desenvolvida em Flutter (Android) com um backend local de suporte (FastAPI + SQLite). O objetivo primário é substituir o processo manual de conferência com planilhas impressas, otimizando a coleta de dados e a posterior atualização no sistema SUAP.

O app funcionará como uma "prancheta digital", permitindo ao usuário escanear itens de forma individual ou em lote, identificar rapidamente inconsistências de localização, editar informações e registrar novos itens não catalogados. A funcionalidade mais importante é a geração de um relatório final, em formato de planilha, que consolida **apenas os itens que sofreram alterações**, destacando as células modificadas para facilitar e agilizar a etapa de atualização manual no SUAP.

---

## Fases do Desenvolvimento

### Fase 1: MVP - A Prancheta Digital em Ação

**Objetivo:** Entregar as funcionalidades essenciais de escaneamento e edição, replicando e melhorando o fluxo de trabalho de inventário em campo.

-   [ ] **1. Infraestrutura Local (Base de Operações)**
    -   [ ] **1.1. Backend Simples (FastAPI + SQLite):**
        -   [ ] Configurar o servidor em `128.1.1.49`.
        -   [ ] Endpoint `GET /patrimonio`: Para o app baixar a base de dados completa para uso offline.
        -   [ ] Endpoint `POST /patrimonio/update`: Para receber e salvar as alterações feitas no app.
        -   [ ] Tabela `patrimonio` com as colunas do SUAP.
    -   [ ] **1.2. Script Inicial de Carga:**
        -   [ ] Desenvolver um script simples para uma única importação inicial do CSV do SUAP para o banco de dados SQLite do servidor.

-   [ ] **2. Aplicativo Flutter (O Coração do Sistema)**
    -   [ ] **2.1. Estrutura e Dados Offline:**
        -   [ ] Implementar banco de dados local (Hive) para armazenar os dados do patrimônio e garantir funcionamento 100% offline.
        -   [ ] Criar tela principal com os dois botões: **"Escaneamento Individual"** e **"Escaneamento em Lotes"**.
        -   [ ] Implementar o popup "Deseja informar qual é a sala?" com `input select` antes de iniciar o scanner.
    -   [ ] **2.2. Módulo de Escaneamento (Baseado no `barcode-scanner`):**
        -   [ ] Integrar e adaptar o scanner de código de barras.
        -   [ ] Implementar **feedback sonoro e háptico** com variações para:
            -   Sucesso (item novo escaneado).
            -   Duplicado (item já escaneado na sessão atual).
            -   Não encontrado / Erro.
    -   [ ] **2.3. Fluxo de "Escaneamento Individual":**
        -   [ ] Ao escanear/digitar, abrir um modal/formulário com os dados principais: `Nº de Patrimônio`, `Descrição`, `Sala`, `Responsável`, `Situação`.
        -   [ ] **Destaque de Inconsistência:** Se uma sala foi pré-selecionada, destacar o campo "Sala" com uma borda colorida caso o valor seja diferente do esperado.
        -   [ ] Permitir a edição dos campos e salvar com um botão "Atualizar Item".
        -   [ ] **Lógica para Item Não Encontrado:** Exibir a mensagem "O Patrimônio não foi encontrado. Tentar novamente ou registrar novo?". A opção "Registrar Novo" abre o mesmo modal em branco para preenchimento.
    -   [ ] **2.4. Fluxo de "Escaneamento em Lotes":**
        -   [ ] Manter o scanner ativo, adicionando cada item escaneado a uma lista interna.
        -   [ ] Ao fechar o scanner, exibir a lista rolável dos itens.
        -   [ ] **Destaque Visual na Lista:**
            -   Itens de sala diferente da pré-selecionada devem ter um fundo de cor sutilmente diferente.
            -   Itens não encontrados no banco de dados devem ter outra cor de destaque.
        -   [ ] **Interações na Lista:**
            -   Deslizar para a esquerda: Exclui o item da lista (cancela o escaneamento).
            -   Tocar ou deslizar para a direita: Abre o mesmo modal/formulário do "Escaneamento Individual" para visualização/edição.

---

### Fase 2: Fechamento do Ciclo e Consolidação de Dados

**Objetivo:** Implementar a funcionalidade mais crítica para o usuário: a geração do relatório para atualização do SUAP, e registrar o histórico de modificações.

-   [ ] **1. Geração do Relatório de Modificações**
    -   [ ] **1.1. Rastreamento de Alterações no App:**
        -   [ ] Ao clicar em "Atualizar Item", o app deve salvar não apenas o novo estado, mas também quais campos foram alterados (ex: `sala: 'B101' -> 'B102'`).
    -   [ ] **1.2. Tela de Relatórios no App:**
        -   [ ] Criar uma nova seção no app para "Relatórios".
        -   [ ] Botão: "Gerar Planilha de Atualização do SUAP".
    -   [ ] **1.3. Lógica de Geração da Planilha:**
        -   [ ] A função deve coletar todos os itens que foram marcados como modificados.
        -   [ ] Gerar um arquivo (CSV ou Excel - `.xlsx`) com a **mesma estrutura e colunas da planilha original do SUAP**.
        -   [ ] **Funcionalidade Chave:** Na planilha gerada, **destacar (com cor de fundo) as células específicas que sofreram alteração**, tornando a atualização manual no SUAP extremamente visual e rápida.
        -   [ ] Permitir que o usuário exporte/compartilhe este arquivo.

-   [ ] **2. Histórico de Alterações no Servidor**
    -   [ ] **2.1. Tabela de Logs:** Criar a tabela `historico_alteracoes` no SQLite do servidor.
    -   [ ] **2.2. Endpoint de Log:** Modificar o endpoint `POST /patrimonio/update` no FastAPI para que, além de atualizar o item, ele registre um novo log com: `id_item`, `campo_alterado`, `valor_antigo`, `valor_novo`, `timestamp`.

---

### Fase 3: Aprimoramentos e Gestão de Multimídia

**Objetivo:** Adicionar funcionalidades de valor agregado como gestão de fotos e relatórios secundários.

-   [ ] **1. Funcionalidade Completa de Fotos**
    -   [ ] **1.1. Interface no App:**
        -   [ ] Implementar a lógica do botão no modal para `tirar foto / escolher da galeria`.
    -   [ ] **1.2. Armazenamento no Servidor:**
        -   [ ] Criar um endpoint no FastAPI para receber o upload da imagem.
        -   [ ] Salvar a imagem em uma pasta no servidor local, associando seu caminho ao item de patrimônio.
    -   [ ] **1.3. Visualização:**
        -   [ ] Exibir a foto do item no modal, buscando-a do servidor quando online.
        -   [ ] Implementar cache de imagens no app para visualização offline.

-   [ ] **2. Relatórios Adicionais**
    -   [ ] **2.1. Relatório de Itens por Sala/Responsável:** Gerar listas simples, úteis para conferências administrativas.
    -   [ ] **2.2. Relatório de Itens Não Encontrados:** Listar todos os itens de uma sala que não foram escaneados durante uma sessão de "Escaneamento em Lotes".

-   [ ] **3. Dashboard e Visão Geral**
    -   [ ] **3.1. Tela Inicial Aprimorada:** Criar um dashboard simples com métricas úteis (Ex: "Itens atualizados hoje: 15", "Última sincronização com SUAP: dd/mm/aaaa").