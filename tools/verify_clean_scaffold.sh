#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
scaffold="$(mktemp -d)"
trap 'rm -rf -- "$scaffold"' EXIT
tar -C "$root" --exclude=.git --exclude=.godot --exclude=dist --exclude=.manus-logs \
  --exclude=test-output -cf - . | tar -C "$scaffold" -xf -
bash "$scaffold/tools/verify.sh" "$@"
echo "[clean-scaffold] PASS"
