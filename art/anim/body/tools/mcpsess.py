"""mcpsess.py: one persistent StudioMCP stdio session for many calls (anim-body tools). Based on roblox_kits/tools/mcpcli.py.
  s = Session(studio_id); s.luau(code) -> text; s.capture(path, cam, look) -> path"""
import base64, glob, json, os, queue, subprocess, threading, time


class Session:
    def __init__(self, sid):
        self.sid = sid
        local = os.environ.get("LOCALAPPDATA")
        exe = None
        for p in glob.glob(os.path.join(local, "Roblox", "Versions", "*", "StudioMCP.exe")):
            exe = p
        cmd = [exe] if exe else ["cmd.exe", "/c", os.path.join(local, "Roblox", "mcp.bat")]
        self.proc = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, bufsize=0)
        self.q = queue.Queue()
        threading.Thread(target=self._read, daemon=True).start()
        self._id = 0
        self.recv(self.send("initialize", {"protocolVersion": "2024-11-05", "capabilities": {},
                                           "clientInfo": {"name": "anim-body", "version": "0.1"}}))
        self.send("notifications/initialized", {}, notify=True)
        time.sleep(3)
        self.recv(self.send("tools/list", {}), 30)

    def _read(self):
        for line in self.proc.stdout:
            self.q.put(line)

    def send(self, method, params=None, notify=False):
        msg = {"jsonrpc": "2.0", "method": method}
        if params is not None:
            msg["params"] = params
        if not notify:
            self._id += 1
            msg["id"] = self._id
        self.proc.stdin.write((json.dumps(msg) + "\n").encode())
        self.proc.stdin.flush()
        return None if notify else self._id

    def recv(self, rid, timeout=300):
        t0 = time.time()
        while time.time() - t0 < timeout:
            try:
                line = self.q.get(timeout=1)
            except queue.Empty:
                if self.proc.poll() is not None:
                    raise RuntimeError("server exited")
                continue
            try:
                m = json.loads(line.strip())
            except Exception:
                continue
            if m.get("id") == rid:
                return m
        raise TimeoutError("mcp timeout")

    def call(self, tool, args):
        args = dict(args, studio_id=self.sid)
        for _ in range(5):
            r = self.recv(self.send("tools/call", {"name": tool, "arguments": args}))
            txt = json.dumps(r)
            if len(txt) < 400 and ("Unable to reach Roblox Studio" in txt or "No Roblox Studio instances" in txt):
                time.sleep(3)
                continue
            return r
        return r

    def luau(self, code, dm="Edit"):
        r = self.call("execute_luau", {"code": code, "datamodel_type": dm})
        if "error" in r:
            return "ERROR " + json.dumps(r["error"])
        return "\n".join(c.get("text", "") for c in r["result"].get("content", []) if c.get("type") == "text")

    def capture(self, path, cam, look):
        r = self.call("screen_capture", {"capture_id": "ab", "camera_position": list(cam), "look_at_position": list(look)})
        for c in r.get("result", {}).get("content", []):
            if c.get("type") == "image":
                os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
                open(path, "wb").write(base64.b64decode(c["data"]))
                return path
        return None

    def close(self):
        try:
            self.proc.stdin.close()
            self.proc.terminate()
        except Exception:
            pass
