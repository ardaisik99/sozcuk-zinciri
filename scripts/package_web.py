"""Prepare static Pages assets; no Python dependency beyond stdlib."""
from pathlib import Path
import gzip
import shutil

root = Path(__file__).resolve().parent.parent
web = root / "web"
for name in ("mascot.webp", "Nunito.ttf"):
    shutil.copyfile(root / "assets" / name, web / name)
(web / ".nojekyll").touch()
licenses = ["FONT-LICENSE.txt", "SYMBOLS-LICENSE.txt", "GODOT-LICENSE.txt"]
(web / "third-party-licenses.txt").write_text("\n\n".join((root / "assets" / name).read_text(encoding="utf-8") for name in licenses), encoding="utf-8")
wasm = web / "index.wasm"
compressed = gzip.compress(wasm.read_bytes(), compresslevel=9, mtime=0)
(web / "index.wasm.gz").write_bytes(compressed)
print(f"Engine: {wasm.stat().st_size:,} bytes raw / {len(compressed):,} bytes gzip")
print(f"Game pack: {(web / 'index.pck').stat().st_size:,} bytes")
