# Serviço systemd do ArkTV Input Daemon

Este guia explica como instalar o daemon de entrada do ArkTV como um serviço de usuário (`systemd --user`). O serviço garante que o mapeamento de controles fique ativo assim que a sessão iniciar.

## 1. Instalar o script do daemon

1. Copie o script `scripts/arktv-input-daemon.sh` para um local acessível no `PATH` do usuário:

   ```bash
   install -Dm755 scripts/arktv-input-daemon.sh ~/.local/bin/arktv-input-daemon.sh
   ```

2. Certifique-se de que o arquivo de mapeamento exista em `~/.config/arktv/input.map`. O script já fornece um exemplo inicial.

## 2. Instalar a unidade systemd

1. Copie a unidade fornecida para o diretório de serviços do usuário:

   ```bash
   install -Dm644 systemd/arktv-input-daemon.service ~/.config/systemd/user/arktv-input-daemon.service
   ```

2. Recarregue o `systemd --user` para reconhecer a nova unidade:

   ```bash
   systemctl --user daemon-reload
   ```

3. Habilite e inicie o serviço:

   ```bash
   systemctl --user enable --now arktv-input-daemon.service
   ```

## 3. Variáveis de ambiente suportadas

A unidade define variáveis de ambiente que podem ser customizadas conforme necessário:

- `ARKTV_INPUT_CONFIG`: caminho para o arquivo de mapeamento (`~/.config/arktv/input.map`).
- `ARKTV_IPC_SOCKET`: localização do socket IPC do `mpv` (padrão `/tmp/arktv.socket`).
- `ARKTV_RUNTIME_DIR`: diretório onde o daemon grava arquivos temporários e o estado.
- `ARKTV_STATE_FILE`: arquivo JSON onde o daemon persiste estado.

Você pode editar a unidade antes de habilitar o serviço para apontar para caminhos personalizados ou adicionar opções extras.

## 4. Verificação

Para verificar o status do serviço:

```bash
systemctl --user status arktv-input-daemon.service
```

Os logs do daemon aparecem no `journal` do usuário:

```bash
journalctl --user -u arktv-input-daemon.service -f
```
