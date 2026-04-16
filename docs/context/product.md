# Contexto de Produto

> "Medir duas vezes, cortar uma vez."

## Visao
O app **Controle Patrimonial** funciona como uma "prancheta digital" para substituir planilhas impressas no inventario patrimonial do IFSUL. Os pilares sao **agilidade**, **confiabilidade offline** e **reducao de erros** no trabalho de campo.

## Estado Atual do Produto (Abril/2026)
1. O fluxo principal em producao e **planilha + operacao offline**.
2. O backend existe como infraestrutura de suporte, mas **ainda nao e obrigatorio** no fluxo MVP de campo.
3. O produto esta migrando para um modelo hibrido com:
   - sincronizacao seletiva com backend
   - suporte a fotos de itens e futura sincronizacao de imagens
4. Durante essa transicao, pode haver coexistencia temporaria de partes offline-first e partes sync-ready.

## Proposta de Valor
1. **Velocidade**: escaneamento em lote para conferir muitos itens rapidamente.
2. **Confiabilidade**: operacao offline durante a conferencia, com sincronizacao apenas quando fizer sentido.
3. **Precisao**: foco em identificar inconsistencias e diferencas reais, nao apenas listar patrimonio.

## Persona
- **Papel**: Servidor(a) do IFSUL responsavel por patrimonio/inventario.
- **Contexto**: deslocamento entre salas, laboratorios e setores, com conectividade instavel.
- **Dores**:
  - planilhas impressas ficam desatualizadas rapidamente
  - digitacao manual posterior no SUAP e propensa a erro
  - dificuldade de verificar visualmente se o item pertence ao local atual

## Funcionalidades-Chave
1. **Offline-First (prioridade atual)**: importar planilha do SUAP -> trabalhar offline -> exportar alteracoes.
2. **Escaneamento inteligente**:
   - **Individual**: validacao e edicao detalhada de um item.
   - **Em lote**: leitura continua para validacao rapida por ambiente.
3. **Destaque de inconsistencias**:
   - alerta quando item escaneado diverge da sala esperada/cadastrada
   - alerta quando item nao existe na base local
4. **Rastreamento de alteracoes (delta)**:
   - captura `original` vs `atual`
   - permite gerar relatorio objetivo para atualizacao no SUAP

## Evolucao Planejada (Curto Prazo)
1. Introduzir sincronizacao assistida pelo backend sem quebrar o fluxo offline atual.
2. Implementar armazenamento de fotos por item e definir politica de sincronizacao quando online.
3. Manter importacao/exportacao por planilha como fallback seguro durante a migracao.

## Linguagem de Dominio
- **Patrimonio**: item com numero unico (codigo de barras), descricao, situacao e localizacao.
- **Sessao de escaneamento**: periodo de trabalho em um ambiente (ex.: laboratorio/sala).
- **Inconsistencia**: divergencia entre realidade fisica e base de dados.
- **Sincronizacao**: envio/recebimento de dados com backend conforme politica do fluxo.
