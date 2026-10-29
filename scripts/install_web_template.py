"""Install this game's checksum-pinned runtime into the ignored tools folder."""
from pathlib import Path
import hashlib
import json
import urllib.request
import zipfile

root=Path(__file__).resolve().parent.parent
manifest=json.loads((root/'scripts/web_runtime.json').read_text(encoding='utf-8'))
destination=root/'.tools/lean-web-release.zip'
destination.parent.mkdir(exist_ok=True)
valid=lambda p:p.is_file() and hashlib.sha256(p.read_bytes()).hexdigest()==manifest['sha256']
if not valid(destination):
    temporary=destination.with_suffix('.download')
    with urllib.request.urlopen(manifest['url'],timeout=120) as response:
        temporary.write_bytes(response.read())
    if not valid(temporary):
        temporary.unlink(missing_ok=True)
        raise RuntimeError('Godot runtime checksum mismatch')
    temporary.replace(destination)
print(f'Verified Godot {manifest["godot"]} lean web template: {destination.stat().st_size:,} bytes')

# Previously cached v4 HTML may still request fixed index.* paths. Retain
# its official runtime separately so old pack bytecode remains compatible.
compatibility=root/'.tools/legacy-v4-runtime.zip'
if not compatibility.is_file() or hashlib.sha256(compatibility.read_bytes()).hexdigest()!=manifest['compatibilitySha256']:
    with urllib.request.urlopen(manifest['compatibilityUrl'],timeout=120) as response:
        payload=response.read()
    if hashlib.sha256(payload).hexdigest()!=manifest['compatibilitySha256']:
        raise RuntimeError('Compatibility runtime checksum mismatch')
    compatibility.write_bytes(payload)
with zipfile.ZipFile(compatibility) as archive:
    folder=root/'.tools/legacy-v4'
    folder.mkdir(exist_ok=True)
    for name in ['index.js','index.wasm.gz']: (folder/name).write_bytes(archive.read(name))
