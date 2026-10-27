"""Minimal stdio MCP client for StudioMCP.exe (used when the Roblox_Studio MCP is not loaded in the session).
import sys; sys.stdout.reconfigure(encoding="utf-8", errors="replace")
Usage:
  python mcpcli.py list
  python mcpcli.py call <tool> '<json args>'     (args may also be a path to a .json file)
Writes image results to out/<capture_id or tool>_<n>.png and prints text results."""
import json, os, subprocess, sys, base64, threading, queue, time, glob

LOCAL = os.environ.get("LOCALAPPDATA")
exe = os.environ.get("STUDIO_MCP_EXE")
for p in ([] if exe else glob.glob(os.path.join(LOCAL, "Roblox", "Versions", "*", "StudioMCP.exe"))):
    exe = p
cmd = [exe] if exe else ["cmd.exe", "/c", os.path.join(LOCAL, "Roblox", "mcp.bat")]

proc = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, bufsize=0)
q = queue.Queue()
def reader():
    for line in proc.stdout:
        q.put(line)
threading.Thread(target=reader, daemon=True).start()
_id = 0
def send(method, params=None, notify=False):
    global _id
    msg = {"jsonrpc": "2.0", "method": method}
    if params is not None: msg["params"] = params
    if not notify:
        _id += 1; msg["id"] = _id
    proc.stdin.write((json.dumps(msg) + "\n").encode()); proc.stdin.flush()
    return None if notify else _id
def recv(rid, timeout=120):
    t0 = time.time()
    while time.time() - t0 < timeout:
        try:
            line = q.get(timeout=1)
        except queue.Empty:
            if proc.poll() is not None:
                sys.exit("server exited: " + proc.stderr.read().decode(errors="replace"))
            continue
        line = line.strip()
        if not line: continue
        try: m = json.loads(line)
        except Exception: continue
        if m.get("id") == rid: return m
    sys.exit("timeout waiting for response")

rid = send("initialize", {"protocolVersion": "2024-11-05", "capabilities": {}, "clientInfo": {"name": "mcpcli", "version": "0.1"}})
init = recv(rid)
send("notifications/initialized", {}, notify=True)
what = sys.argv[1] if len(sys.argv) > 1 else "list"
time.sleep(float(os.environ.get("MCP_WARMUP", "4")))
if what == "list":
    r = recv(send("tools/list", {}))
    for t in r["result"]["tools"]:
        print(t["name"], "-", t.get("description", "")[:200].replace("\n", " "))
        print("   ", json.dumps(t.get("inputSchema", {}).get("properties", {}))[:600])
else:
    tool = sys.argv[2]
    a = sys.argv[3] if len(sys.argv) > 3 else "{}"
    if os.path.isfile(a): a = open(a, encoding="utf-8").read()
    args = json.loads(a)
    r = recv(send("tools/call", {"name": tool, "arguments": args}), timeout=float(os.environ.get("MCP_TIMEOUT", "180")))
    if "error" in r:
        print("ERROR", json.dumps(r["error"])); sys.exit(1)
    res = r["result"]
    n = 0
    for c in res.get("content", []):
        if c.get("type") == "text":
            print(c["text"])
        elif c.get("type") == "image":
            n += 1
            name = args.get("capture_id") or tool
            path = os.path.join("out", f"{name}_{n}.png")
            os.makedirs("out", exist_ok=True)
            open(path, "wb").write(base64.b64decode(c["data"]))
            print("IMAGE", path)
    if res.get("isError"): print("isError=true"); sys.exit(1)
proc.stdin.close()
