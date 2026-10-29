"""Content-addressed web assets, compressed parallel transport, inline first paint."""
from pathlib import Path
import gzip
import shutil
import hashlib
import base64
import json
import brotli

root = Path(__file__).resolve().parent.parent
web = root / "web"
sha = lambda data: hashlib.sha256(data).hexdigest()
wasm = (web / "index.wasm").read_bytes()
runtime_manifest=root/'scripts/web_runtime.json'
if runtime_manifest.is_file():
    expected_runtime=json.loads(runtime_manifest.read_text(encoding='utf-8'))
    assert sha(wasm)==expected_runtime['wasmSha256'], 'Export with the pinned small template before packaging'
engine_js = (web / "index.js").read_bytes()
pack = (web / "index.pck").read_bytes()
engine_id = sha(wasm+engine_js)[:16]
pack_id = sha(pack)[:16]
runtime_base = f"runtime-{engine_id}"
pack_path = f"game-{pack_id}.pck"
boot = "\n;\n".join((root/"scripts"/name).read_text(encoding="utf-8") for name in
                      ("benchmark.js","frame_pacer.js","web_input.js","asset_loader.js","start_game.js"))
boot_name = f"boot-{sha(boot.encode())[:16]}.js"
assets=[]
def asset(name,path,data,mime):
    compressed=gzip.compress(data,compresslevel=9,mtime=0)
    br=brotli.compress(data,quality=9)
    compressed_path=f"{Path(path).stem}-{sha(compressed)[:12]}{Path(path).suffix}.gz"
    br_path=f"{Path(path).stem}-{sha(br)[:12]}{Path(path).suffix}.br"
    (web/path).write_bytes(data)
    (web/compressed_path).write_bytes(compressed)
    (web/br_path).write_bytes(br)
    result={"name":name,"url":path,"gzip":compressed_path,"size":len(data),"gzipSize":len(compressed),
            "hash":sha(data),"gzipHash":sha(compressed),"mime":mime}
    result.update({"brotli":br_path,"brotliSize":len(br),"brotliHash":sha(br)})
    assets.append(result)
    return result
engine=asset("runtime",runtime_base+".wasm",wasm,"application/wasm")
game=asset("game",pack_path,pack,"application/octet-stream")
(web/(runtime_base+".js")).write_bytes(engine_js)
(web/boot_name).write_text(boot,encoding="utf-8")
# Keep exported index.* aliases during the migration so a previously cached
# HTML document can still retrieve its fixed engine/pack paths.
(web/"index.wasm.gz").write_bytes((web/engine['gzip']).read_bytes())
legacy=root/'.tools/legacy-v4'
if legacy.is_dir():
    shutil.copyfile(legacy/'index.js',web/'index.js')
    shutil.copyfile(legacy/'index.wasm.gz',web/'index.wasm.gz')
    (web/'index.wasm').write_bytes(gzip.decompress((legacy/'index.wasm.gz').read_bytes()))
shutil.copyfile(root/"assets/Nunito.ttf",web/"Nunito.ttf")
shutil.copyfile(root/"assets/v4/landscape.webp",web/"landscape.webp")
for source,target in [("web_input.js","word-input.js"),("frame_pacer.js","frame-pacer.js"),("benchmark.js","benchmark.js")]:
    shutil.copyfile(root/"scripts"/source,web/target)
filesizes={a["url"]:a["size"] for a in assets}
replacements={"__INLINE_FONT__":"data:font/woff2;base64,"+base64.b64encode((root/"assets/NunitoUI.woff2").read_bytes()).decode(),
              "__INLINE_LANDSCAPE__":"data:image/webp;base64,"+base64.b64encode((root/"assets/v4/landscape.webp").read_bytes()).decode(),
              "__ASSETS_MANIFEST__":json.dumps(assets,separators=(",",":")),
              "__RUNTIME_BASE__":runtime_base,"__PACK_PATH__":pack_path,"__FILE_SIZES__":json.dumps(filesizes),
              "__RUNTIME_JS__":runtime_base+".js","__BOOT_JS__":boot_name}
html=web/"index.html"
contents=html.read_text(encoding="utf-8")
for key,value in replacements.items(): contents=contents.replace(key,value)
assert not any(key in contents for key in replacements),"Unresolved web shell placeholders"
html.write_text(contents,encoding="utf-8")
keep={a["url"] for a in assets}|{a["gzip"] for a in assets}|{a["brotli"] for a in assets}|{runtime_base+".js",boot_name}
for pattern in ("runtime-*","game-*.pck*","boot-*.js"):
    for old in web.glob(pattern):
        if old.is_file() and old.name not in keep: old.unlink()
(web/".nojekyll").touch()
licenses=["FONT-LICENSE.txt","SYMBOLS-LICENSE.txt","GODOT-LICENSE.txt","GODOT-COPYRIGHT.txt"]
(web/"third-party-licenses.txt").write_text("\n\n".join((root/"assets"/name).read_text(encoding="utf-8") for name in licenses),encoding="utf-8")
metrics={"assets":assets,"htmlBytes":html.stat().st_size,"htmlGzipBytes":len(gzip.compress(contents.encode(),mtime=0)),
         "bootBytes":len(boot.encode()),"runtimeJsBytes":len(engine_js),"firstDownloadCompressedBytes":sum(a["gzipSize"] for a in assets)}
(web/"sizes.json").write_text(json.dumps(metrics,indent=2),encoding="utf-8")
print(f"Engine: {len(wasm):,} bytes raw / {engine['gzipSize']:,} bytes gzip")
print(f"Engine Brotli: {engine['brotliSize']:,} bytes")
print(f"Game pack: {len(pack):,} bytes raw / {game['gzipSize']:,} bytes gzip")
print(f"First paint: inline art/font; HTML gzip {metrics['htmlGzipBytes']:,} bytes")
