<!-- 95bdd9af-158e-43ea-944e-6810e5b693a4 49dd9078-6de4-46fa-af79-18d3e98540a8 -->
# Plano de Implementação: Arquitetura ArkTV Core

Este plano detalha a criação de uma arquitetura modular para o ArkTV, separando a lógica de controle do player de vídeo. Vamos criar um serviço de background (daemon) para gerenciar inputs, estados e a comunicação com o `mpv`, tornando o sistema mais robusto e extensível.

## 1. Mapeamento de Controles Externos e Daemon de Input

Criaremos um serviço persistente para capturar e traduzir inputs de diversos dispositivos.

- **Dispositivos Mapeados:**
  - **Primários:** Teclado (setas, mídia keys) e Controles de Gamepad (D-Pad, A/B/X/Y).
  - **Secundário:** Qualquer dispositivo compatível com o subsistema `evdev` do Linux.
- **Implementação:**
  - Criar um script `arktv-input-daemon.sh` que rodará em segundo plano.
  - O daemon usará o comando `libinput debug-events` para escutar eventos de input de forma padronizada, evitando a complexidade de lidar com cada dispositivo individualmente.
  - Um arquivo de configuração, `~/.config/arktv/input.map`, definirá o mapeamento entre os eventos de input e ações lógicas do ArkTV (ex: `KEY_UP: navigate_up`, `BTN_SOUTH: confirm_action`).
  - O daemon irá traduzir essas ações em comandos JSON e enviá-los ao `mpv` via socket.

## 2. Integração com MPV via Socket IPC

Vamos abandonar a simulação de teclas e adotar o método de controle recomendado pela documentação do `mpv`.

- **Implementação:**
  - O script principal `ArkTV.sh` será modificado para iniciar o `mpv` com o parâmetro `--input-ipc-server=/tmp/arktv.socket`. Isso cria um canal de comunicação direto com o player.
  - O `arktv-input-daemon.sh` usará `socat` para escrever comandos JSON no socket. Exemplo:
    ```bash
    echo '{ "command": ["playlist-next"] }' | socat - /tmp/arktv.socket
    ```

  - Esta abordagem permite um controle preciso, assíncrono e a possibilidade de ler o estado do `mpv` (ex: obter o volume atual ou a posição do vídeo).

## 3. Overlays Informativos (OSD) com Lua

Criaremos scripts Lua customizados para exibir informações na tela, controlados pelo nosso daemon.

- **Implementação:**
  - Os scripts ficarão em `~/.config/mpv/scripts/arktv/`.
  - **`playlist-osd.lua`**: Um script para renderizar uma lista de canais navegável na tela. Será ativado por um comando enviado pelo daemon, como `script-message show-playlist`.
  - **`status-osd.lua`**: Um script para exibir informações contextuais, como nome do canal, volume e status (play/pause), ativado por eventos (`file-loaded`) ou comandos diretos.

## 4. Persistência de Dados

Manteremos o estado da aplicação entre as sessões para melhorar a experiência do usuário.

- **Implementação:**
  - O `arktv-input-daemon.sh` será responsável por gerenciar o estado.
  - Um único arquivo JSON em `~/.local/share/arktv/state.json` armazenará informações como:
    - URL da última playlist usada.
    - Índice do último canal assistido.
    - Configurações (ex: modo aleatório).
  - O daemon lerá este arquivo na inicialização e o salvará ao receber um sinal de encerramento ou em ações críticas (como trocar de playlist).

## 5. Hooks de Inicialização com Systemd

Para garantir que o nosso daemon de input esteja sempre ativo, vamos registrá-lo como um serviço do sistema.

- **Implementação:**
  - Criar um arquivo de serviço `arktv-input-daemon.service` em `~/.config/systemd/user/`.
  - O serviço será configurado para iniciar junto com a sessão do usuário.
  - O script `ArkTV.sh` irá apenas iniciar a instância do `mpv`, confiando que o serviço de input já está rodando. Isso simplifica o script principal e torna o sistema mais confiável.
    ```
    [Unit]
    Description=ArkTV Input Daemon
    
    [Service]
    ExecStart=/path/to/arktv-input-daemon.sh
    
    [Install]
    WantedBy=default.target
    ```

  - A gestão do serviço será feita via `systemctl --user enable --now arktv-input-daemon`.

### To-dos

- [ ] Create the `arktv-input-daemon.sh` script and the `input.map` configuration file.
- [ ] Modify `ArkTV.sh` to launch MPV with the IPC socket enabled.
- [ ] Implement the Lua scripts for OSD (`playlist-osd.lua`, `status-osd.lua`).
- [ ] Integrate state management for data persistence into the daemon.
- [ ] Create the systemd service file and document the setup process.