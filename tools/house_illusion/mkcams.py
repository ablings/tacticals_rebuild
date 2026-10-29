import json, math
L = json.load(open('notes/maps/house_layout.json'))
cams = []
OUT = {'W_S_G': (0,-1), 'W_S_U': (0,-1), 'W_N_G': (0,1), 'W_N_U': (0,1), 'W_W': (-1,0), 'W_E_G': (1,0), 'W_E_U': (1,0), 'W_U4': (0,1), 'I_X9_U': (1,0)}
for o in L['openings']:
    if o.get('kind') != 'window' or o.get('frosted') or o.get('interior'): continue
    fl = 0 if o['storey'] == 'G' else 14
    mid = (o['a'] + o['b']) / 2
    ox, oy = OUT[o['wall']]
    if o['axis'] == 'x': wx, wy = mid, o['line']
    else: wx, wy = o['line'], mid
    ex, ey = wx - ox * 3.5, wy - oy * 3.5
    room = o['id'].split('_')[1]
    for tag, h, yaw, pitch in [('st', 4.6, 0, 0), ('swL', 4.6, 40, 0), ('swR', 4.6, -40, 0), ('up', 4.6, 0, 32), ('dn', 4.6, 0, -30), ('cr', 3.3, 0, 0)]:
        pass
        hh = fl + h
        # the tall foyer window: standing and crouched eyes from the landing floor
        a = math.radians(yaw)
        dx = ox * math.cos(a) - oy * math.sin(a); dy = ox * math.sin(a) + oy * math.cos(a)
        D = 40
        at = [ex + dx * D, hh + math.tan(math.radians(pitch)) * D, ey + dy * D]
        cams.append({'name': f"{o['id']}_{tag}", 'area': room, 'eye': [round(ex,2), round(hh,2), round(ey,2)], 'at': [round(v,2) for v in at], 'fov': 70})
# 3v3 spawn rooms: each spawn's slots look toward their room's windows
for name, eye, at in [('SpawnA_3v3_S', [-34.5, 4.6, -19], [-30, 4, -40]), ('SpawnA_3v3_W', [-34.5, 4.6, -19], [-60, 5, -2]),
                      ('SpawnB_3v3_N', [34.5, 4.6, 19], [30, 5, 40]), ('SpawnB_3v3_E', [34.5, 4.6, 19], [60, 5, 12])]:
    cams.append({'name': name, 'area': 'spawn', 'eye': eye, 'at': at, 'fov': 70})
json.dump(cams, open('captures/cams-house-windows.json', 'w'), indent=1)
print(len(cams))
