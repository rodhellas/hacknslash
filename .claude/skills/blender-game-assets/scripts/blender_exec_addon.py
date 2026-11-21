"""Client per l'add-on Blender MCP di ahujasid (porta 9876, quello installato sul PC Windows).

Protocollo diverso da blender_exec.py: JSON senza \0, {"type": "execute_code", "params": {"code": ...}};
la risposta contiene solo lo stdout. Il codice deve assegnare un dict a `result`.

Uso (Python di Blender, quello di sistema su Windows è solo lo stub dello Store):
  "C:/Program Files/Blender Foundation/Blender 5.2/5.2/python/bin/python.exe" blender_exec_addon.py bpy_lib.py tripo_lib.py job.py
Non chiamare read_homefile/open_mainfile nello stesso job che poi usa il contesto: fallo in una chiamata a parte.
"""
import json, socket, sys
files = sys.argv[1:]
code = "\n\n".join(open(f, encoding="utf-8").read() for f in files)
code += "\n\nimport json as _j\nprint('@@RESULT@@' + _j.dumps(result, default=str))\n"
s = socket.create_connection(("127.0.0.1", 9876), timeout=3600)
s.sendall(json.dumps({"type": "execute_code", "params": {"code": code}}).encode("utf-8"))
buf = b""
while True:
    chunk = s.recv(65536)
    if not chunk:
        break
    buf += chunk
    try:
        resp = json.loads(buf.decode("utf-8"))
        break
    except Exception:
        pass
s.close()
if resp.get("status") != "success":
    print(json.dumps(resp, indent=1, ensure_ascii=False)[:6000]); sys.exit(1)
out = resp["result"].get("result", "")
i = out.rfind("@@RESULT@@")
if i > 0:
    print(out[:i])
print(json.dumps(json.loads(out[i + 10:]), indent=1, ensure_ascii=False) if i >= 0 else out)
