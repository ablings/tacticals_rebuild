"""Place split installers (notes/place_split.md).
  python tools/split_build.py place <studio_id> Tutorial|Matchmaking|Ranked|Test   convert an opened match-place COPY into that kind
  python tools/split_build.py place <studio_id> UNDO                           put it back
  python tools/split_build.py lobby <studio_id> [UNDO]                         lobby routing ([SPLIT] edits)
  python tools/split_build.py embed                                            only refresh the embedded PlaceKind source
Copies scripts/split/PlaceKind.lua into fix/split_place_install.lua (between --@EMBED_BEGIN / --@EMBED_END), sets the --@KIND /
--@UNDO lines in a temp copy and runs it through the stdio MCP bridge (rivals_practice/mcpcli.py). Never saves the place."""
import json, os, re, subprocess, sys, tempfile
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
CLI = os.path.expanduser(r"~\Documents\rivals_practice\mcpcli.py")
FORBIDDEN = ("dcee58ac", "82b89850")  # sandbox / RIVALS replica: never

def embed():
    p = os.path.join(ROOT, 'fix', 'split_place_install.lua')
    src = open(p, encoding='utf-8').read()
    mod = open(os.path.join(ROOT, 'scripts', 'split', 'PlaceKind.lua'), encoding='utf-8').read()
    assert ']==]' not in mod
    block = 'local PLACEKIND_SRC = [==[\n' + mod + ']==]\n'
    new = re.sub(r'(--@EMBED_BEGIN[^\n]*\n).*?(--@EMBED_END)', lambda m: m.group(1) + block + m.group(2), src, flags=re.S)
    if new != src:
        open(p, 'w', encoding='utf-8', newline='\n').write(new)
    return new

def run(sid, code):
    if any(sid.startswith(f) for f in FORBIDDEN):
        sys.exit('refused: ' + sid + ' is not one of ours')
    fd, path = tempfile.mkstemp(suffix='.json'); os.close(fd)
    json.dump({"studio_id": sid, "datamodel_type": "Edit", "code": code}, open(path, 'w', encoding='utf-8'))
    r = subprocess.run([sys.executable, CLI, 'call', 'execute_luau', path], capture_output=True, text=True, encoding='utf-8',
                       env=dict(os.environ, PYTHONIOENCODING='utf-8', MCP_TIMEOUT='300'))
    os.remove(path)
    print(r.stdout); print(r.stderr[-2000:], file=sys.stderr)
    return r.returncode

if __name__ == '__main__':
    a = sys.argv[1:]
    if not a or a[0] not in ('place', 'lobby', 'embed'):
        sys.exit(__doc__)
    if a[0] == 'embed':
        embed(); print('embedded'); sys.exit(0)
    sid, rest = a[1], a[2:]
    undo = 'UNDO' in rest
    if a[0] == 'place':
        code = embed()
        if not undo:
            kind = next((k for k in rest if k in ('Tutorial', 'Matchmaking', 'Ranked', 'Test')), None)
            if not kind:
                sys.exit('give a kind: Tutorial | Matchmaking | Ranked | Test (or UNDO)')
            code = re.sub(r'^local KIND = "\w+" --@KIND', f'local KIND = "{kind}" --@KIND', code, flags=re.M)
    else:
        code = open(os.path.join(ROOT, 'fix', 'split_lobby_install.lua'), encoding='utf-8').read()
    if undo:
        code = re.sub(r'^local UNDO = false --@UNDO', 'local UNDO = true --@UNDO', code, flags=re.M)
    sys.exit(run(sid, code))
