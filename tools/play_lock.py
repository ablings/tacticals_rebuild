"""Shared Play-mode lock for Studio 8ef4e21a (two Claude sessions share one Studio).
Usage: python tools/play_lock.py take <owner>   -> exit 0 if taken, 1 if held by someone else (prints holder)
       python tools/play_lock.py release <owner>
       python tools/play_lock.py status
A lock older than 20 minutes is treated as stale. Always check get_studio_state is Edit before taking Play."""
import json, os, sys, time
P = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'out', 'play.lock')
STALE = 20 * 60
def read():
    try:
        with open(P) as f: return json.load(f)
    except Exception: return None
cmd = sys.argv[1] if len(sys.argv) > 1 else 'status'
owner = sys.argv[2] if len(sys.argv) > 2 else '?'
cur = read()
if cur and time.time() - cur['t'] > STALE: cur = None
if cmd == 'take':
    if cur and cur['owner'] != owner:
        print('held by', cur['owner'], 'since', time.strftime('%H:%M:%S', time.localtime(cur['t']))); sys.exit(1)
    os.makedirs(os.path.dirname(P), exist_ok=True)
    with open(P, 'w') as f: json.dump({'owner': owner, 't': time.time()}, f)
    print('taken by', owner)
elif cmd == 'release':
    if cur and cur['owner'] == owner: os.remove(P); print('released')
    else: print('not held by', owner)
else:
    print(cur or 'free')
