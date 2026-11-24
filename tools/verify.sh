#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
if [[ $# -gt 1 || ( $# -eq 1 && "$1" != "--export" ) ]]; then
  echo "Usage: tools/verify.sh [--export]" >&2
  exit 2
fi
scratch="$(mktemp -d)"
trap 'rm -rf -- "$scratch"' EXIT
export XDG_DATA_HOME="$scratch/data"
export XDG_CONFIG_HOME="$scratch/config"
export XDG_CACHE_HOME="$scratch/cache"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
run() {
  local expected="$1"
  shift
  timeout 120 "${GODOT:-godot}" --headless "$@" >"$scratch/godot.log" 2>&1 || {
    cat "$scratch/godot.log"
    return 1
  }
  if grep -Eq '(^|[[:space:]])(ERROR:|SCRIPT ERROR:)' "$scratch/godot.log" ||
      ! grep -Fq "$expected" "$scratch/godot.log"; then
    cat "$scratch/godot.log"
    return 1
  fi
  grep -F "$expected" "$scratch/godot.log"
}
run 'Godot Engine' --editor --import --quit
run '[acampada-tests] PASS:' --script test/camp_test.gd
run '[day-two] PASS:' --script test/day_two_test.gd
if [[ "${1:-}" == --export ]]; then
  for pack in docs/index.pck docs/pruebas-*.pck; do
    run 'Godot Engine' --main-pack "$pack" --quit-after 10
  done
fi
