# Deploy do webapp

O deploy publica o webapp em `/controle-patrimonio/` e a API sob o mesmo prefixo. Configure `ADMIN_USER`, `ADMIN_PASSWORD` e `JWT_SECRET_KEY` no ambiente de execução, fora do repositório, e mantenha `COOKIE_SECURE=true` quando o acesso ocorrer por HTTPS. O administrador inicial é criado uma única vez no banco persistente; alterações posteriores nas variáveis não trocam a senha existente.

Com as variáveis de ambiente configuradas (no ambiente do serviço ou em um arquivo `.env` local, ignorado pelo Git), execute um comando na raiz do projeto:

```sh
docker-compose up -d --build web backend
```

O serviço web escuta na porta `8090` do host. O proxy HTTPS já existente deve encaminhar `/controle-patrimonio/` para essa porta e preservar o cabeçalho `X-Forwarded-Proto`; a configuração no container encaminha `/controle-patrimonio/api/` ao backend.
