# Webapp offline-first substitui o APK

O APK Android deixa de ser suportado; o produto passa a ser um webapp Flutter em `/controle-patrimonio/`, sem compatibilidade com o app antigo (Hive local, sqflite, atualização de APK). O backend (FastAPI/SQLite) é a fonte de verdade e o navegador mantém um cache offline em IndexedDB (Hive) para salas sem cobertura. As telas acessam os dados por um repositório único, para que o offline seja troca de implementação. Conflitos seguem last-write-wins por patrimônio.
