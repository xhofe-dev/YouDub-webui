#!/bin/bash
set -euo pipefail

cd /app

mkdir -p "${WORKFOLDER:-./workfolder}" "${MODEL_CACHE_DIR:-./data/modelscope}"

uvicorn backend.app.main:app --host 0.0.0.0 --port 8000 &
API_PID=$!

npm --prefix apps/web run start -- --hostname 0.0.0.0 --port 3000 &
WEB_PID=$!

term() {
  kill "$API_PID" "$WEB_PID" 2>/dev/null || true
  wait "$API_PID" "$WEB_PID" 2>/dev/null || true
}
trap term INT TERM

# Exit when either process dies (bash wait -n).
wait -n "$API_PID" "$WEB_PID"
status=$?
term
exit "$status"
