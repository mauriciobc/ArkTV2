#!/usr/bin/env bash

set -euo pipefail

CONFIG_FILE="${ARKTV_INPUT_CONFIG:-$HOME/.config/arktv/input.map}"
MPV_SOCKET="${ARKTV_IPC_SOCKET:-/tmp/arktv.socket}"
STATE_DIR="${ARKTV_RUNTIME_DIR:-$HOME/.local/share/arktv}"
STATE_FILE="$STATE_DIR/state.json"
LOG_TAG="arktv-input-daemon"

mkdir -p "${STATE_DIR}" >/dev/null 2>&1

declare -A ACTION_MAP
STATE_SHUFFLE="false"
STATE_LAST_COMMAND="none"

log() {
  printf '[%s] %s\n' "$LOG_TAG" "$1" >&2
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    log "Comando obrigatório não encontrado: $1"
    exit 1
  fi
}

load_mapping() {
  ACTION_MAP=()
  if [[ ! -f "$CONFIG_FILE" ]]; then
    log "Arquivo de configuração não encontrado: $CONFIG_FILE"
    exit 1
  fi

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    line="${line%%*( )}"
    line="${line##*( )}"
    [[ -z "$line" ]] && continue

    key="${line%%:*}"
    action="${line#*:}"
    key="${key// /}"
    action="${action// /}"
    ACTION_MAP["$key"]="$action"
  done <"$CONFIG_FILE"

  log "Carregado mapa de ${#ACTION_MAP[@]} entradas a partir de $CONFIG_FILE"
}

send_ipc_command() {
  local payload="$1"

  if [[ ! -S "$MPV_SOCKET" ]]; then
    log "Socket do MPV não disponível: $MPV_SOCKET"
    return 1
  fi

  printf '%s\n' "$payload" | socat - UNIX-CONNECT:"$MPV_SOCKET" >/dev/null 2>&1 || {
    log "Falha ao enviar comando para o MPV"
    return 1
  }
}

load_state() {
  STATE_SHUFFLE="false"
  STATE_LAST_COMMAND="none"

  if [[ -f "$STATE_FILE" ]]; then
    local parsed
    if parsed=$(python3 - "$STATE_FILE" <<'PY'
import json
import sys

path = sys.argv[1]
try:
    with open(path, 'r', encoding='utf-8') as handle:
        data = json.load(handle)
except Exception:
    data = {}

shuffle = 'true' if data.get('shuffle', False) else 'false'
last_command = data.get('last_command', 'none')
print(shuffle)
print(last_command)
PY
    ); then
      IFS=$'\n' read -r STATE_SHUFFLE STATE_LAST_COMMAND <<<"$parsed"
    fi
  fi
}

save_state() {
  local escaped_command
  escaped_command=$(printf '%s' "$STATE_LAST_COMMAND" | sed 's/"/\\"/g')

  cat <<EOF >"$STATE_FILE"
{
  "shuffle": ${STATE_SHUFFLE:-false},
  "last_command": "$escaped_command",
  "updated_at": "$(date --iso-8601=seconds)"
}
EOF
}

record_action() {
  local action="$1"
  STATE_LAST_COMMAND="$action"
  save_state
}

toggle_shuffle_state() {
  if [[ "$STATE_SHUFFLE" == "true" ]]; then
      if send_ipc_command '{"command":["playlist-unshuffle"]}'; then
          STATE_SHUFFLE="false"
          send_ipc_command '{"command":["show-text","Modo aleatório desligado",2000,1]}'
      else
          log "Falha ao desativar aleatório"
          return
      fi
  else
      if send_ipc_command '{"command":["playlist-shuffle"]}'; then
          STATE_SHUFFLE="true"
          send_ipc_command '{"command":["show-text","Modo aleatório ligado",2000,1]}'
      else
          log "Falha ao ativar aleatório"
          return
      fi
  fi

  record_action "toggle_shuffle"
  send_ipc_command '{"command":["script-message","arktv-overlay","status"]}'
}

dispatch_action() {
  local action="$1"

  case "$action" in
    navigate_up)
      send_ipc_command '{"command":["script-message","arktv-navigation","up"]}'
      ;;
    navigate_down)
      send_ipc_command '{"command":["script-message","arktv-navigation","down"]}'
      ;;
    navigate_left)
      send_ipc_command '{"command":["script-message","arktv-navigation","left"]}'
      ;;
    navigate_right)
      send_ipc_command '{"command":["script-message","arktv-navigation","right"]}'
      ;;
    confirm_action)
      send_ipc_command '{"command":["script-message","arktv-navigation","confirm"]}'
      ;;
    back_action)
      send_ipc_command '{"command":["script-message","arktv-navigation","back"]}'
      ;;
    play_pause)
      send_ipc_command '{"command":["cycle","pause"]}'
      record_action "$action"
      ;;
    show_playlist)
      send_ipc_command '{"command":["script-message","arktv-overlay","toggle-playlist"]}'
      record_action "$action"
      ;;
    show_status)
      send_ipc_command '{"command":["script-message","arktv-overlay","status"]}'
      record_action "$action"
      ;;
    volume_up)
      send_ipc_command '{"command":["add","volume",2]}'
      record_action "$action"
      ;;
    volume_down)
      send_ipc_command '{"command":["add","volume",-2]}'
      record_action "$action"
      ;;
    next_channel)
      send_ipc_command '{"command":["playlist-next"]}'
      record_action "$action"
      ;;
    prev_channel)
      send_ipc_command '{"command":["playlist-prev"]}'
      record_action "$action"
      ;;
    toggle_shuffle)
      toggle_shuffle_state
      ;;
    reload_playlist)
      send_ipc_command '{"command":["script-message","arktv-overlay","reload-playlist"]}'
      record_action "$action"
      ;;
    *)
      log "Ação desconhecida: $action"
      ;;
  esac
}

process_event_line() {
  local line="$1"

  if [[ "$line" =~ KEYBOARD_KEY[[:space:]]+.+\(([^)]+)\)[[:space:]]+pressed ]]; then
    local key_name
    key_name="${BASH_REMATCH[1]}"
    emit_action "$key_name"
  elif [[ "$line" =~ SWITCH_TOGGLE[[:space:]]+.+\(([^)]+)\)[[:space:]]+state[[:space:]]+1 ]]; then
    local key_name
    key_name="${BASH_REMATCH[1]}"
    emit_action "$key_name"
  elif [[ "$line" =~ POINTER_BUTTON[[:space:]]+.+\(([^)]+)\)[[:space:]]+pressed ]]; then
    local key_name
    key_name="${BASH_REMATCH[1]}"
    emit_action "$key_name"
  fi
}

emit_action() {
  local key_name="$1"
  local action="${ACTION_MAP[$key_name]:-}"

  if [[ -z "$action" ]]; then
    log "Evento não mapeado: $key_name"
    return
  fi

  dispatch_action "$action"
}

main_loop() {
  log "Iniciando captura de eventos com libinput"
  libinput debug-events --verbose | while IFS= read -r line; do
    process_event_line "$line"
  done
}

trap 'log "Encerrando daemon"; exit 0' INT TERM

require_command libinput
require_command socat
require_command python3

load_mapping
load_state
main_loop
