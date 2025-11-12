# Controle de Patrimônio IFSul Câmpus Venâncio Aires

O Sistema de Controle Patrimonial é uma ferramenta focada na **eficiência do trabalho de campo**, desenvolvida em Flutter (Android) com um backend local de suporte (FastAPI + SQLite). O objetivo primário é substituir o processo manual de conferência com planilhas impressas, otimizando a coleta de dados e a posterior atualização no sistema SUAP.

O app funcionará como uma "prancheta digital", permitindo ao usuário escanear itens de forma individual ou em lote, identificar rapidamente inconsistências de localização, editar informações e registrar novos itens não catalogados. A funcionalidade mais importante é a geração de um relatório final, em formato de planilha, que consolida **apenas os itens que sofreram alterações**, destacando as células modificadas para facilitar e agilizar a etapa de atualização manual no SUAP.

O sistema contém um scanner que lê as etiquetas de patrimônio e puxa as informações do banco de dados. O banco de dados é feito em cima do arquivo csv extraído do SUAP.

## Informações sobre scripts:
O script ./start.sh inicializa os containers.
O script ./update-deps.sh atualiza as dependências.
O script ./compila.sh compila o apk, fazendo o versionamento.
O scirpt ./share.sh cria um server http temporário para baixar e atualizar o app.
