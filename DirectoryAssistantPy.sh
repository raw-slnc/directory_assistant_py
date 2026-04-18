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
B64
}

ensure_da_py(){
  local py="$ROOT/DirectoryAssistant.py"
  if [ -f "$py" ]; then
    if grep -Fq 'DA_VERSION = "2026-04-18.2"' "$py" 2>/dev/null; then
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
