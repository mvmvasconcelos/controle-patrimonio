# Instrucoes para Agentes - Controle de Patrimonio

> [!IMPORTANT]
> Este ambiente roda em host Linux remoto com Docker. Nao execute `flutter` nem `python` diretamente no host. Use sempre os containers do projeto.

## 1. Fonte da Verdade e Contexto

Antes de iniciar qualquer tarefa, leia e considere:
1. `docs/context/product.md`
2. `docs/context/tech_stack.md`
3. `docs/ROADMAP.md`
4. `docs/implementacao_fotos.md` (quando o assunto envolver fotos/sincronizacao)

Referencias rapidas de ambiente:
- Host interno: `128.1.1.49`
- Host externo: `ifva.duckdns.org`
- Backend local: `http://127.0.0.1:6090/api/v1/`
- Servico Flutter no Docker Compose: `flutter` (nao usar `builder` sem confirmar)

## 2. Regras de Execucao em Container

### Padrao preferencial (container persistente)
1. Subir servicos quando necessario:
    - `docker-compose up -d flutter backend`
2. Executar comandos com `exec`:
    - Flutter: `docker-compose exec -T flutter sh -lc "<COMANDO>"`
    - Backend: `docker-compose exec -T backend sh -lc "<COMANDO>"`

### Fallback (comando isolado)
Quando o servico nao estiver rodando e fizer sentido executar de forma efemera:
- Flutter: `docker-compose run --rm -w /app flutter sh -lc "<COMANDO>"`
- Backend: `docker-compose run --rm -w /backend backend sh -lc "<COMANDO>"`

Regras gerais:
- Nunca executar `flutter` ou `python` diretamente no shell do host.
- Sempre usar caminhos absolutos para edicoes de arquivo.
- Comandos de `git` podem rodar no host.

## 3. Fluxo de Trabalho

### 3.1 Inicio de tarefa
Quando o usuario iniciar algo como "vamos comecar o item X do roadmap":
1. Pergunte antes de criar documento de detalhamento da tarefa.
2. Apos confirmacao, criar o documento da tarefa com:
    - objetivo
    - passos tecnicos
    - criterios de aceitacao
    - status: `[ ] Desenvolvido [ ] Testado [ ] Validado`

### 3.2 Sessao
- Ao receber "comecar sessao": localizar e ler o arquivo de sessao mais recente e resumir contexto.
- Ao receber "encerrar sessao": criar resumo e registrar em `sessao_DD-MM-YY.md`.

### 3.3 Conclusao de tarefa
Quando o usuario confirmar tarefa concluida e validada:
1. Atualizar item correspondente no `docs/ROADMAP.md`.
2. Arquivar documento da tarefa em `docs/archives`.
3. Arquivar arquivos de sessao relacionados em `docs/archives`.
4. Confirmar no chat a conclusao e arquivamento.

## 4. Protocolo Tecnico

### Planejamento
1. Ler contexto e arquivos relevantes antes de propor mudancas.
2. Se necessario, atualizar plano de implementacao com:
    - objetivo
    - arquivos impactados
    - comandos de verificacao em Docker

### Execucao
1. Fazer mudancas atomicas e coesas.
2. Rodar analise/lint com frequencia:
    - `docker-compose exec -T flutter sh -lc "flutter analyze"`

### Verificacao
1. Rodar testes pertinentes:
    - `docker-compose exec -T flutter sh -lc "flutter test"`
2. Validar build quando aplicavel:
    - `docker-compose exec -T flutter sh -lc "flutter build apk --debug"`

## 5. Qualidade e Seguranca

- Nao expor segredos/senhas/chaves em codigo ou documentacao.
- Priorizar codigo legivel, manutenivel e com comentarios apenas quando necessario.
- Sempre considerar impacto em testes e regressao.
- Mudancas devem ser pequenas, logicas e prontas para versionamento.

## 6. Comunicacao

- Respostas objetivas e focadas na tarefa atual.
- Ser proativo ao identificar lacunas de configuracao/dependencias.
- Apontar arquivos e pontos exatos para revisao do usuario.
- Idioma padrao: portugues (PT-BR), salvo solicitacao contraria.
