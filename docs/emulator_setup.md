# Guia Completo: Emulador Android Remoto com Docker

Este documento serve como um guia mestre para configurar e utilizar um Emulador Android rodando no Windows (Local) conectado a um ambiente de desenvolvimento Flutter no Linux (Remoto/Docker).

## 1. Visão Geral da Arquitetura

O objetivo é permitir que o container Docker (onde o Flutter roda) se comunique com o Emulador no seu Windows.

*   **Local (Windows)**: Roda o Emulador Android e o Cliente SSH.
*   **Remoto (Linux)**: Roda o Docker e um Proxy Python.
*   **Conexão**: Um túnel SSH reverso encaminha a porta do emulador (5555) para o Linux (na porta 5557), e o Proxy Python distribui isso para o Docker.

## 2. O Que Foi Instalado/Criado

Para que isso funcione, adicionamos os seguintes arquivos ao projeto:

1.  **`tools/android-sdk/`**:
    *   Contém os binários do `adb` para Linux.
    *   *Uso*: Útil para debug no servidor (host), mas o Docker usa seu próprio ADB interno.
2.  **`scripts/adb_proxy.py`**:
    *   Um script Python simples que cria uma "ponte" de rede.
    *   *Motivo*: O Docker não consegue acessar diretamente o túnel SSH (localhost) do servidor. O proxy escuta em `0.0.0.0:5556` (acessível ao Docker) e repassa para `localhost:5557` (Túnel).
3.  **`emulador.sh`**:
    *   Script facilitador para rodar no Linux. Ele usa `docker-compose exec` para garantir que usamos o container persistente (mantendo a autorização do ADB).

## 3. Configuração Inicial (Setup)

### A. No Computador Local (Windows)

1.  **Emulador Android**:
    *   Instale o Android Studio e crie um dispositivo virtual (AVD).
    *   Inicie o emulador.
    *   **Ativar Debug USB**:
        *   No emulador, vá em `Settings` > `System` > `About emulated device`.
        *   Clique 7 vezes em `Build number` para ativar o modo desenvolvedor.
        *   Volte, vá em `System` > `Developer options`.
        *   Ative **USB debugging**.

2.  **Configuração SSH (VS Code)**:
    *   Precisamos encaminhar a porta do emulador (5555) para o servidor.
    *   Abra o arquivo de configuração SSH (`~/.ssh/config` ou via VS Code `Remote-SSH: Open Configuration File`).
    *   Adicione a linha `RemoteForward` ao seu host:

    ```ssh
    Host nome-do-seu-servidor
        HostName 128.1.1.49
        User seu-usuario
        # Encaminha a porta 5557 do servidor para a 5555 do seu Windows (IP 127.0.0.1)
        RemoteForward 5557 127.0.0.1:5555
    ```

3.  **Reconectar**:
    *   Após editar o config, desconecte e reconecte o VS Code (Reload Window) para ativar o túnel.

### B. No Servidor Remoto (Linux)

1.  **Dependências**:
    *   Certifique-se de que o `python3` está instalado.
    *   Certifique-se de que o `docker` e `docker-compose` estão instalados.

2.  **Docker Compose**:
    *   O `docker-compose.yml` deve permitir comunicação com o host. Adicione `extra_hosts` ao serviço do flutter:
    ```yaml
    services:
      flutter:
        ...
        extra_hosts:
          - "host.docker.internal:host-gateway"
    ```

## 4. Modo de Uso (Dia a Dia)

Sempre que for programar, siga estes passos:

### Passo 1: Conectar e Rodar
O script `emulador.sh` agora faz tudo: inicia o proxy (se necessário) e conecta o container.

```bash
./emulador.sh
```

*   **Atenção**: Na primeira vez, olhe para o Emulador no Windows. Vai aparecer uma janela **"Allow USB Debugging?"**. Marque "Always allow" e clique em **Allow**.
*   Se o script disser `device`, está conectado!
*   Se disser `unauthorized`, você não aceitou a janela a tempo. Rode o script de novo.

### Passo 2: Rodar o App
Agora é só usar o Flutter normalmente via Docker:
```bash
docker-compose exec -T flutter sh -lc "flutter run"
```

> Se o container `flutter` nao estiver rodando, suba antes com:
> `docker-compose up -d flutter`

## 5. Solução de Problemas

*   **Erro "Connection refused" no script**:
    *   O proxy não está rodando. Rode o Passo 1 novamente.
    *   Verifique se tem algum processo python rodando: `ps aux | grep python`.

*   **Erro "Connection refused" no Proxy (logs)**:
    *   O túnel SSH caiu ou não foi criado.
    *   Verifique seu `~/.ssh/config` no Windows (deve usar porta 5557 -> 127.0.0.1:5555).
    *   Reconecte o SSH (Close Window -> Open Window se necessário).

*   **Dispositivo "Unauthorized" ou "Offline"**:
    *   Você precisa aceitar a permissão no Emulador.
    *   Se estiver em loop "offline": O script `emulador.sh` deve usar `docker-compose exec` (não `run`). Verifique se o container `flutter` está rodando (`docker-compose ps`).
