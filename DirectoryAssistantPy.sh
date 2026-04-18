#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PORT="${DA_PORT:-8742}"
HOST="127.0.0.1"
URL="http://localhost:${PORT}"

PID_FILE="$ROOT/.server.pid"
LOG_FILE="$ROOT/.server.log"
if ! ( : >"$LOG_FILE" ) 2>/dev/null; then
  LOG_FILE="/tmp/DirectoryAssistant-${PORT}-$(id -u).log"
  : >"$LOG_FILE" 2>/dev/null || true
fi
exec >>"$LOG_FILE" 2>&1

export PYTHONDONTWRITEBYTECODE=1

step(){ echo "STEP $1 $(date '+%F %T')"; }
open_url_fallback(){
  local url="$1"
  # Throttle: avoid opening multiple windows/tabs if double-click launches twice.
  local stamp_root="${XDG_RUNTIME_DIR:-/tmp}"
  local stamp_file="$stamp_root/DirectoryAssistant-${PORT}-$(id -u).last_open"
  local now last
  now="$(date +%s 2>/dev/null || echo 0)"
  last="$(cat "$stamp_file" 2>/dev/null || echo 0)"
  if [ "$now" -gt 0 ] && [ "$last" -gt 0 ] && [ $((now-last)) -lt 3 ]; then
    echo "skip_open_throttle=1"
    return 0
  fi
  echo "$now" >"$stamp_file" 2>/dev/null || true

  if command -v xdg-open >/dev/null 2>&1; then xdg-open "$url" >/dev/null 2>&1 && return 0; fi
  if command -v gio >/dev/null 2>&1; then gio open "$url" >/dev/null 2>&1 && return 0; fi
  if command -v sensible-browser >/dev/null 2>&1; then sensible-browser "$url" >/dev/null 2>&1 && return 0; fi
  if command -v python3 >/dev/null 2>&1; then python3 -B -c "import webbrowser; webbrowser.open('$url',new=1,autoraise=True)" >/dev/null 2>&1 && return 0; fi
  return 1
}

da_py_payload(){
  cat <<'B64'
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
wcyWqNX+L7jAteEdtAAA
B64
}

ensure_da_py(){
  local py="$ROOT/DirectoryAssistant.py"
  if [ -f "$py" ]; then
    if grep -Fq 'DA_VERSION = "2026-04-18.3"' "$py" 2>/dev/null; then
      return 0
    fi
    echo "update_py=1"
  else
    echo "write_py=1"
  fi

  if command -v gzip >/dev/null 2>&1; then
    da_py_payload | base64 -d 2>/dev/null | gzip -dc >"$py" 2>/dev/null || true
    if [ ! -s "$py" ]; then
      da_py_payload | base64 -D 2>/dev/null | gzip -dc >"$py" 2>/dev/null || true
    fi
  fi

  if [ ! -s "$py" ]; then
    echo "write_py_failed=1"
    rm -f "$py" 2>/dev/null || true
    return 1
  fi
  chmod +x "$py" 2>/dev/null || true
  return 0
}

get_info(){
  if command -v curl >/dev/null 2>&1; then
    curl -fsS --max-time 1 "http://${HOST}:${PORT}/api/info" 2>/dev/null || true
  elif command -v wget >/dev/null 2>&1; then
    wget -qO- "http://${HOST}:${PORT}/api/info" 2>/dev/null || true
  elif command -v python3 >/dev/null 2>&1; then
    python3 -B -c "import urllib.request,sys; sys.stdout.write(urllib.request.urlopen('http://${HOST}:${PORT}/api/info',timeout=1).read().decode('utf-8','replace'))" 2>/dev/null || true
  else
    return 0
  fi
}

shutdown_srv(){
  if command -v curl >/dev/null 2>&1; then
    curl -fsS --max-time 1 -X POST -H "Content-Type: application/json" -d "{}" "http://${HOST}:${PORT}/api/shutdown" >/dev/null 2>&1 || true
  elif command -v wget >/dev/null 2>&1; then
    wget -qO- --method=POST --header="Content-Type: application/json" --body-data="{}" "http://${HOST}:${PORT}/api/shutdown" >/dev/null 2>&1 || true
  elif command -v python3 >/dev/null 2>&1; then
    python3 -B -c "import urllib.request; urllib.request.urlopen(urllib.request.Request('http://${HOST}:${PORT}/api/shutdown',data=b'{}',headers={'Content-Type':'application/json'},method='POST'),timeout=1).read()" >/dev/null 2>&1 || true
  fi
}

wait_srv(){
  i=0
  while [ "$i" -lt 25 ]; do
    INFO_JSON="$(get_info)"
    [ -n "$INFO_JSON" ] && return 0
    sleep 0.2
    i=$((i+1))
  done
  return 1
}

step 1
echo "root=$ROOT port=$PORT log=$LOG_FILE"

step 2
INFO_JSON="$(get_info)"
if [ -n "$INFO_JSON" ] && command -v python3 >/dev/null 2>&1; then
  SRV_ROOT="$(printf "%s" "$INFO_JSON" | python3 -B -c "import sys,json;print(json.load(sys.stdin).get('root_path',''))" 2>/dev/null || true)"
  echo "server_root=$SRV_ROOT"
  if [ -z "$SRV_ROOT" ] || [ "$SRV_ROOT" = "$ROOT" ]; then
    step 5
    echo "open_url=$URL"
    open_url_fallback "$URL"
    exit 0
  fi
  shutdown_srv
  sleep 1
fi

step 3
rm -f "$PID_FILE" 2>/dev/null || true

step 4
PY="$ROOT/DirectoryAssistant.py"
if ! ensure_da_py; then
  echo "ensure_da_py_failed=1"
  exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
  echo "python3_not_found=1"
  open_url_fallback "https://www.python.org/downloads/"
  exit 1
fi
if command -v setsid >/dev/null 2>&1; then
  setsid python3 -B "$PY" --root "$ROOT" --bind "$HOST" --port "$PORT" --no-open >/dev/null 2>&1 &
else
  nohup python3 -B "$PY" --root "$ROOT" --bind "$HOST" --port "$PORT" --no-open >/dev/null 2>&1 &
fi

if wait_srv; then
  step 5
  echo "open_url=$URL"
  open_url_fallback "$URL"
  exit 0
fi

step 9
echo "failed_to_start=1"
exit 1
