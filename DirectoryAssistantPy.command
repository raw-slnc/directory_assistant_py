#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
PORT="${DA_PORT:-8742}"
HOST="127.0.0.1"
URL="http://localhost:${PORT}"

PID_FILE="$ROOT/.server.pid"
LOG_FILE="$ROOT/.server.log"
export PYTHONDONTWRITEBYTECODE=1
if ! ( : >"$LOG_FILE" ) 2>/dev/null; then
  LOG_FILE="/tmp/DirectoryAssistant-${PORT}-$(id -u).log"
  : >"$LOG_FILE" 2>/dev/null || true
fi
exec >>"$LOG_FILE" 2>&1

step(){ echo "STEP $1 $(date '+%F %T')"; }
open_url(){
  local url="$1"
  open "$url" >/dev/null 2>&1 || {
    echo "open_failed=$url"
    return 0
  }
}

close_launcher_terminal(){
  command -v osascript >/dev/null 2>&1 || return 0
  local tty_path=""
  tty_path="$(tty 2>/dev/null || true)"
  [ -n "$tty_path" ] || return 0
  (
    sleep 0.5
    osascript - "$tty_path" >/dev/null 2>&1 <<'APPLESCRIPT'
on run argv
  set target_tty to item 1 of argv
tell application "Terminal"
  if it is running then
    try
      set tab_count to 0
      repeat with w in windows
        set tab_count to tab_count + (count of tabs of w)
      end repeat
      if tab_count is less than or equal to 1 then
        quit
        return
      end if
      repeat with w in windows
        repeat with t in tabs of w
          try
            if tty of t is target_tty then
              close t
              return
            end if
          end try
        end repeat
      end repeat
    end try
  end if
end tell
end run
APPLESCRIPT
  ) &
}

da_py_payload(){
  cat <<'B64'
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
ZkvUav8XJO6n+h20AAA=
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
  da_py_payload | base64 -D 2>/dev/null | gzip -dc >"$py" 2>/dev/null || true
  if [ ! -s "$py" ]; then
    da_py_payload | base64 -d 2>/dev/null | gzip -dc >"$py" 2>/dev/null || true
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
  command -v curl >/dev/null 2>&1 || return 0
  curl -fsS --max-time 1 "http://${HOST}:${PORT}/api/info" 2>/dev/null || true
}

shutdown_srv(){
  command -v curl >/dev/null 2>&1 || return 0
  curl -fsS --max-time 1 -X POST -H "Content-Type: application/json" -d "{}" "http://${HOST}:${PORT}/api/shutdown" >/dev/null 2>&1 || true
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
  SRV_ROOT="$(printf "%s" "$INFO_JSON" | python3 -B -c 'import sys,json;print(json.load(sys.stdin).get("root_path",""))' 2>/dev/null || true)"
  echo "server_root=$SRV_ROOT"
  if [ -z "$SRV_ROOT" ] || [ "$SRV_ROOT" = "$ROOT" ]; then
    open_url "$URL"
    close_launcher_terminal
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
  open_url "https://www.python.org/downloads/"
  exit 1
fi
nohup python3 -B "$PY" --root "$ROOT" --bind "$HOST" --port "$PORT" --no-open >/dev/null 2>&1 &

if wait_srv; then
  step 5
  open_url "$URL"
  close_launcher_terminal
  exit 0
fi

step 9
echo "failed_to_start=1"
exit 1
