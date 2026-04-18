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
+9Su7PfRfOj3uUnJbIla7X8D8/9HpYiwAAA=
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
