# Controle de Patrimônio

Sistema para conferir fisicamente os bens de uma instituição a partir do inventário exportado do SUAP, registrando fotos e alterações.

## Language

**Patrimônio**:
O bem físico identificado por um número de tombamento.
_Avoid_: Item, bem, ativo

**Inventário**:
A lista de patrimônios importada do SUAP.
_Avoid_: Planilha, base, lista

**Conferência**:
O ato de escanear ou digitar o número de um patrimônio e marcá-lo como encontrado.
_Avoid_: Leitura, scan, checagem

**Sincronização**:
O envio das alterações feitas sem conexão ao servidor, e o recebimento das alterações de outros usuários.
_Avoid_: Sync, atualização

**Administrador**:
O único papel de acesso: o usuário autenticado tem permissão total.
_Avoid_: Usuário comum, operador

**Sala**:
O local físico onde um patrimônio deve estar, conforme o cadastro. Na conferência, a sala informada pelo usuário é comparada com a do cadastro, e a decisão sobre qualquer divergência é dele.
_Avoid_: Local, localização

**Escaneamento**:
O nome que a interface dá à Conferência, individual ou em lotes.
_Avoid_: Leitura, checagem
