"""Fail CI on Godot script assertions/errors as well as process exit codes."""
import subprocess
import sys
from pathlib import Path

root = Path(__file__).resolve().parent.parent
godot = sys.argv[1] if len(sys.argv) > 1 else "godot"
commands = [[godot,"--headless","--path",str(root),"--script",script]
            for script in ("tests/test_state.gd","tests/test_flows.gd")]
commands += [["node","--check",str(root/"scripts"/file)]
             for file in ("web_input.js","frame_pacer.js","benchmark.js","asset_loader.js","start_game.js")]
commands += [["node",str(root/script)] for script in ("tests/test_frame_pacer.cjs","tests/test_asset_loader.cjs")]
for command in commands:
    try:
        result = subprocess.run(command,cwd=root,stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT,text=True,encoding="utf-8",errors="replace",timeout=30)
    except subprocess.TimeoutExpired as failure:
        print(f"FAIL: timed out: {command}")
        print(failure.stdout)
        sys.exit(1)
    print(result.stdout,end="")
    if result.returncode or any(marker in result.stdout for marker in ("SCRIPT ERROR:","ERROR:","Assertion failed")):
        sys.exit(1)
print("PASS: all project checks.")
