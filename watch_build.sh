#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_SCRIPT="$ROOT_DIR/templates/build.sh"

if [[ ! -x "$BUILD_SCRIPT" ]]; then
  echo "Could not find executable build script at: $BUILD_SCRIPT" >&2
  exit 1
fi

if ! command -v inotifywait >/dev/null 2>&1; then
  echo "watch_build.sh requires inotifywait (inotify-tools)." >&2
  echo "Install it, then re-run this script." >&2
  exit 1
fi

run_build() {
  echo
  echo "[$(date +'%H:%M:%S')] Running templates/build.sh ..."
  if "$BUILD_SCRIPT"; then
    echo "[$(date +'%H:%M:%S')] Build OK"
  else
    echo "[$(date +'%H:%M:%S')] Build FAILED (waiting for next change)"
  fi
}

echo "Watching source files for changes..."
echo "Press Ctrl+C to stop."

# First build immediately.
run_build

inotifywait -m -r \
  -e close_write,create,delete,move \
  --format '%w%f' \
  --exclude '(/templates/partials/index/|/templates/posts/.*\.(pdf|svg|aux|log|out|toc)$)' \
  "$ROOT_DIR/templates" "$ROOT_DIR/styles" "$ROOT_DIR/style.css" \
| while read -r changed_path; do
    echo
    echo "[$(date +'%H:%M:%S')] Change detected: $changed_path"
    run_build
  done
