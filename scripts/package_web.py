"""Prepare static Pages assets; no Python dependency beyond stdlib."""
from pathlib import Path
import gzip
import shutil
import hashlib

root = Path(__file__).resolve().parent.parent
web = root / "web"
for legacy in ("mascot.webp", "mascot.webp.import"):
    old = web / legacy
    if old.is_file(): old.unlink()
shutil.copyfile(root / "assets" / "Nunito.ttf", web / "Nunito.ttf")
for name in ("splash.webp", "logo_dark.webp"):
    shutil.copyfile(root / "assets" / "v2" / name, web / name)
shutil.copyfile(root / "scripts" / "web_input.js", web / "word-input.js")
shutil.copyfile(root / "scripts" / "benchmark.js", web / "benchmark.js")
shutil.copyfile(root / "scripts" / "frame_pacer.js", web / "frame-pacer.js")
build_id = hashlib.sha256((web / "index.pck").read_bytes()).hexdigest()[:12]
html = web / "index.html"
html.write_text(html.read_text(encoding="utf-8").replace("__BUILD_ID__",build_id),encoding="utf-8")
(web / ".nojekyll").touch()
licenses = ["FONT-LICENSE.txt", "SYMBOLS-LICENSE.txt", "GODOT-LICENSE.txt"]
(web / "third-party-licenses.txt").write_text("\n\n".join((root / "assets" / name).read_text(encoding="utf-8") for name in licenses), encoding="utf-8")
wasm = web / "index.wasm"
compressed = gzip.compress(wasm.read_bytes(), compresslevel=9, mtime=0)
(web / "index.wasm.gz").write_bytes(compressed)
print(f"Engine: {wasm.stat().st_size:,} bytes raw / {len(compressed):,} bytes gzip")
print(f"Game pack: {(web / 'index.pck').stat().st_size:,} bytes")
