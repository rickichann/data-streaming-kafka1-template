#!/usr/bin/env bash
set -euo pipefail

CONNECT_URL="${CONNECT_URL:-http://localhost:8083}"

usage() {
  cat <<EOF
Usage:
  $0 deploy <connector.json>
  $0 status <connector.json | connector-name>
  $0 delete <connector.json | connector-name>
  $0 config <connector.json | connector-name>
  $0 restart <connector.json | connector-name>
  $0 pause <connector.json | connector-name>
  $0 resume <connector.json | connector-name>
  $0 list

Env:
  CONNECT_URL  (default: http://localhost:8083)
EOF
}

check_jq() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "❌ jq is not installed."
    echo "Install it:"
    echo "  Ubuntu: sudo apt install jq"
    echo "  MacOS : brew install jq"
    exit 1
  fi
}

wait_for_connect() {
  echo "⏳ Waiting for Kafka Connect at $CONNECT_URL ..."
  until curl -sS "$CONNECT_URL/connectors" >/dev/null 2>&1; do
    sleep 2
  done
  echo "✅ Kafka Connect is ready"
}

is_file() {
  [ -f "$1" ]
}

validate_json_file() {
  local f="$1"
  if [ ! -f "$f" ]; then
    echo "❌ File not found: $f"
    exit 1
  fi
  if ! jq empty "$f" >/dev/null 2>&1; then
    echo "❌ Invalid JSON format: $f"
    exit 1
  fi
}

get_connector_name() {
  local input="$1"
  if is_file "$input"; then
    validate_json_file "$input"
    local name
    name="$(jq -r '.name // empty' "$input")"
    if [ -z "$name" ]; then
      echo "❌ JSON must contain top-level field: \"name\""
      exit 1
    fi
    echo "$name"
  else
    echo "$input"
  fi
}

http_status() {
  # usage: http_status <method> <url> [data-file]
  local method="$1"
  local url="$2"
  local data_file="${3:-}"

  if [ -n "$data_file" ]; then
    curl -sS -o /dev/null -w "%{http_code}" -X "$method" \
      -H "Content-Type: application/json" \
      --data @"$data_file" \
      "$url"
  else
    curl -sS -o /dev/null -w "%{http_code}" -X "$method" "$url"
  fi
}

deploy_connector() {
  local config_file="$1"
  validate_json_file "$config_file"

  local name
  name="$(jq -r '.name // empty' "$config_file")"
  if [ -z "$name" ]; then
    echo "❌ JSON must contain top-level field: \"name\""
    exit 1
  fi
  if [ "$(jq -r '.config // empty | type' "$config_file")" = "null" ] || [ -z "$(jq -r '.config // empty' "$config_file")" ]; then
    echo "❌ JSON must contain top-level field: \"config\""
    exit 1
  fi

  wait_for_connect
  echo "🚀 Deploying connector: $name"

  local code
  code="$(http_status POST "$CONNECT_URL/connectors" "$config_file")"

  if [ "$code" = "201" ]; then
    echo "✅ Connector created"
  else
    # Update existing
    echo "🔁 Connector exists (or POST returned $code). Updating config..."
    local tmp="/tmp/${name}-config-only.json"
    jq '.config' "$config_file" > "$tmp"

    local put_code
    put_code="$(http_status PUT "$CONNECT_URL/connectors/$name/config" "$tmp")"
    if [ "$put_code" != "200" ]; then
      echo "❌ Update failed (HTTP $put_code). Response:"
      curl -sS -X PUT "$CONNECT_URL/connectors/$name/config" -H "Content-Type: application/json" --data @"$tmp"
      echo
      exit 1
    fi
    echo "✅ Connector updated"
  fi

  show_status "$name"
}

show_status() {
  local input="$1"
  local name
  name="$(get_connector_name "$input")"

  wait_for_connect
  echo "📊 Status for connector: $name"

  local code
  code="$(http_status GET "$CONNECT_URL/connectors/$name/status")"
  if [ "$code" != "200" ]; then
    echo "❌ Connector not found or status unavailable (HTTP $code)"
    exit 1
  fi

  curl -sS "$CONNECT_URL/connectors/$name/status" | jq
}

delete_connector() {
  local input="$1"
  local name
  name="$(get_connector_name "$input")"

  wait_for_connect
  echo "🗑 Deleting connector: $name"

  local code
  code="$(http_status DELETE "$CONNECT_URL/connectors/$name")"
  if [ "$code" = "204" ]; then
    echo "✅ Connector deleted"
  else
    echo "❌ Failed to delete connector (HTTP $code). Maybe it doesn't exist?"
    exit 1
  fi
}

list_connectors() {
  wait_for_connect
  echo "📋 Connectors:"
  curl -sS "$CONNECT_URL/connectors" | jq
}

show_config() {
  local input="$1"
  local name
  name="$(get_connector_name "$input")"

  wait_for_connect
  echo "🧾 Config for connector: $name"
  local code
  code="$(http_status GET "$CONNECT_URL/connectors/$name/config")"
  if [ "$code" != "200" ]; then
    echo "❌ Connector not found (HTTP $code)"
    exit 1
  fi
  curl -sS "$CONNECT_URL/connectors/$name/config" | jq
}

restart_connector() {
  local input="$1"
  local name
  name="$(get_connector_name "$input")"

  wait_for_connect
  echo "🔄 Restarting connector (and tasks): $name"

  # restart connector + tasks
  local code
  code="$(http_status POST "$CONNECT_URL/connectors/$name/restart?includeTasks=true&onlyFailed=false")"
  if [ "$code" != "204" ]; then
    echo "❌ Restart failed (HTTP $code). Response:"
    curl -sS -X POST "$CONNECT_URL/connectors/$name/restart?includeTasks=true&onlyFailed=false"
    echo
    exit 1
  fi
  echo "✅ Restart requested"
  show_status "$name"
}

pause_connector() {
  local input="$1"
  local name
  name="$(get_connector_name "$input")"

  wait_for_connect
  echo "⏸ Pausing connector: $name"

  local code
  code="$(http_status PUT "$CONNECT_URL/connectors/$name/pause")"
  if [ "$code" != "202" ] && [ "$code" != "204" ]; then
    echo "❌ Pause failed (HTTP $code)"
    exit 1
  fi
  echo "✅ Paused"
  show_status "$name"
}

resume_connector() {
  local input="$1"
  local name
  name="$(get_connector_name "$input")"

  wait_for_connect
  echo "▶️ Resuming connector: $name"

  local code
  code="$(http_status PUT "$CONNECT_URL/connectors/$name/resume")"
  if [ "$code" != "202" ] && [ "$code" != "204" ]; then
    echo "❌ Resume failed (HTTP $code)"
    exit 1
  fi
  echo "✅ Resumed"
  show_status "$name"
}

main() {
  check_jq

  if [ "$#" -lt 1 ]; then
    usage
    exit 1
  fi

  local cmd="$1"
  local arg="${2:-}"

  case "$cmd" in
    deploy)
      [ -n "$arg" ] || { usage; exit 1; }
      deploy_connector "$arg"
      ;;
    status)
      [ -n "$arg" ] || { usage; exit 1; }
      show_status "$arg"
      ;;
    delete)
      [ -n "$arg" ] || { usage; exit 1; }
      delete_connector "$arg"
      ;;
    config)
      [ -n "$arg" ] || { usage; exit 1; }
      show_config "$arg"
      ;;
    restart)
      [ -n "$arg" ] || { usage; exit 1; }
      restart_connector "$arg"
      ;;
    pause)
      [ -n "$arg" ] || { usage; exit 1; }
      pause_connector "$arg"
      ;;
    resume)
      [ -n "$arg" ] || { usage; exit 1; }
      resume_connector "$arg"
      ;;
    list)
      list_connectors
      ;;
    -h|--help|help)
      usage
      ;;
    *)
      echo "❌ Unknown command: $cmd"
      usage
      exit 1
      ;;
  esac
}

main "$@"