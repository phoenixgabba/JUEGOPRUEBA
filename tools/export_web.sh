#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
godot="${GODOT:-godot}"
if [[ "$("$godot" --version 2>/dev/null)" != 4.7.2.stable.* ]]; then
  echo "Use Godot 4.7.2 stable and its matching Web export template." >&2
  exit 1
fi
stage="$(mktemp -d)"
trap 'rm -rf -- "$stage"' EXIT
mkdir -p "$stage/pruebas"
"$godot" --headless --editor --import --quit
"$godot" --headless --export-release Web "$stage/index.html"
"$godot" --headless --export-release "Web Pruebas" "$stage/pruebas/index.html"
for file in index.js index.wasm index.audio.worklet.js index.audio.position.worklet.js; do
  cmp "$stage/$file" "$stage/pruebas/$file"
done
python3 - "$stage" <<'PY'
from hashlib import sha256
from pathlib import Path
import re
import shutil
import sys

stage = Path(sys.argv[1])
docs = Path("docs")
game_pack = stage / "index.pck"
practice = stage / "pruebas"
practice_pack = practice / "index.pck"
name = "pruebas-" + sha256(practice_pack.read_bytes()).hexdigest()[:10] + ".pck"
assert game_pack.read_bytes() != practice_pack.read_bytes()
shell = (practice / "index.html").read_text()
shell = shell.replace('"index.pck"', f'"{name}"')
shell = shell.replace("engine.startGame({ onProgress })",
                      f'engine.startGame({{ onProgress, mainPack: "{name}" }})')
assert f'"{name}":{practice_pack.stat().st_size}' in shell
assert f'mainPack: "{name}"' in shell
prod_shell = (stage / "index.html").read_text()
assert f'"index.pck":{game_pack.stat().st_size}' in prod_shell
assert f'"index.wasm":{(stage / "index.wasm").stat().st_size}' in prod_shell

for file in stage.glob("index.*"):
    shutil.copyfile(file, docs / file.name)
shutil.copyfile(practice_pack, docs / name)
(docs / "pruebas.html").write_text(shell)
for old in docs.glob("pruebas-*.pck"):
    if old.name != name and re.fullmatch(r"pruebas-[a-f0-9]{10}\.pck", old.name):
        old.unlink()
PY
