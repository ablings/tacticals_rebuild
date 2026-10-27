"""Warehouse (Tacticals tutorial map) geometry in plan coordinates.
Plan coords: e = -(x - CX)  (east positive, matches the map's own Wall_E naming and a Studio top view with +Z up),
             n = z - CZ     (north positive). Heights are above the floor top (y 0.4)."""
import json, os
H=os.path.dirname(os.path.abspath(__file__))
D=json.load(open(os.path.join(H,'warehouse_dump.json'),encoding='utf-8'))
CX,CZ,FY=-84.2,7.5,0.4
def plan(p):
    x,y,z=p['pos']; sx,sy,sz=p['size']
    return dict(name=p['name'],e=-(x-CX),n=z-CZ,w=sx,d=sz,h=y+sy/2-FY,bot=y-sy/2-FY)
KIND={'P':'pillar','C':'block','W':'wall','L':'low'}
pieces=[]
for p in D['proxies']:
    nm=p['name'][5:]
    if nm[0] in KIND and nm[1:].isdigit():
        q=plan(p); q['kind']=KIND[nm[0]]; q['id']=nm; pieces.append(q)
barrels=[]
for p in D['shootables']:
    if p['name']=='Body': q=plan(p); q['kind']='barrel'; q['id']=p['parent']; barrels.append(q)
camskin=[plan(p) for p in D['camskin']]
spawns={p['name']:dict(e=-(p['pos'][0]-CX),n=p['pos'][2]-CZ,yaw=p['rot'][1]) for p in D['spawns']}
HALF_W,HALF_L=40.5,57.0   # inside faces: 81 x 114
CEIL=18.0

# What-if (analysis only, the map is never changed): WH_WHATIF=<json> moves pieces {"L05": [e, n], ...}
if os.environ.get('WH_WHATIF'):
    _mv = json.load(open(os.environ['WH_WHATIF']))
    for q in pieces:
        if q['id'] in _mv: q['e'], q['n'] = _mv[q['id']]
