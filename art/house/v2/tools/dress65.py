"""1965 House: places the loose 1965 dressing, test dummies, drapes, posters, cobwebs, sand and the wear layer in layout
plan coordinates for build_house.py (all art: no collision; nothing here moves a wall, opening, door, window or cover box).
Masters come from house_furniture.blend (build_furniture_1965.py: D65_*). Returns objects linked into the House collection
plus a JSON list (house_dressing65.json) the builder can use for walk blockers."""
import json, math, os, random
import bpy, bmesh
from mathutils import Vector, Matrix
import shell65 as S65

ROT_FACE = {"S": 0.0, "E": 90.0, "N": 180.0, "W": -90.0, None: 0.0}
DRAPE = {"FY": "Gold", "LR": "Mustard", "DR": "Green", "MB": "Green", "BR2": "Gold", "BR3": "Mustard", "BH": "Green"}


def load_masters(path, names):
    with bpy.data.libraries.load(path, link=False) as (src, dst):
        dst.objects = [n for n in src.objects if n in names]
    return {o.name: o for o in dst.objects if o is not None}


class Placer:
    def __init__(s, LAY, coll, inside_any, room_rects, rooms):
        s.LAY, s.coll, s.inside_any = LAY, coll, inside_any
        s.room_rects, s.rooms = room_rects, rooms
        s.F = {f["id"]: f for f in LAY["furniture"]}
        s.D = {d["id"]: d for d in LAY["dressing"]}
        s.out, s.log = [], []
        s.occ = []      # (x0, x1, y0, y1, z0, z1) of furniture + dressing + what we place on the floor
        for f in LAY["furniture"]:
            s.occ.append((f["x0"], f["x1"], f["y0"], f["y1"], f["z0"], f["z1"]))
        for d in LAY["dressing"]:
            if d.get("box"):
                x0, x1, y0, y1 = d["box"]
                s.occ.append((x0, x1, y0, y1, d["z"], d["z"] + d["size"][1]))

    def put(s, master, name, x, y, z, rot=0.0, scale=(1, 1, 1), tilt=0.0, note="", blocker=None):
        ob = bpy.data.objects.new(name, master.data)
        ob.location = (x, y, z)
        ob.rotation_euler = (0.0, math.radians(tilt), math.radians(rot))
        ob.scale = scale
        ob["atlas"] = master.get("atlas", "D65")
        s.coll.objects.link(ob)
        s.out.append(ob)
        e = dict(name=name, master=master.name, at=[round(x, 3), round(y, 3), round(z, 3)], rot_z=round(rot, 1), note=note)
        if blocker:
            e["blocker_xy_r"] = blocker
        s.log.append(e)
        return ob

    def furn_top(s, fid, lx=0.0, ly=0.0):
        """plan point on top of a furniture box, from a local (Blender, pivot-relative) offset"""
        f = s.F[fid]
        cx, cy = (f["x0"] + f["x1"]) / 2, (f["y0"] + f["y1"]) / 2
        r = math.radians(ROT_FACE.get(f["face"], 0.0))
        return cx + lx * math.cos(r) - ly * math.sin(r), cy + lx * math.sin(r) + ly * math.cos(r), f["z1"], ROT_FACE.get(f["face"], 0.0)

    def floor_free(s, x, y, z, r):
        for (x0, x1, y0, y1, z0, z1) in s.occ:
            if z0 - 0.5 <= z <= z1 and x0 - r <= x <= x1 + r and y0 - r <= y <= y1 + r:
                return False
        # inside the house, in a room, not in a wall
        for dx, dy in ((r, 0), (-r, 0), (0, r), (0, -r), (0, 0)):
            if s.inside_any(Vector((x + dx, y + dy, z + 0.3))):
                return False
        return True

    def near_free(s, x, y, z, r, rng, tries=200):
        for k in range(tries):
            d = 0.0 if k == 0 else 0.3 + k * 0.05
            a = rng.uniform(0, 2 * math.pi)
            px, py = x + d * math.cos(a), y + d * math.sin(a)
            if s.floor_free(px, py, z, r):
                s.occ.append((px - r, px + r, py - r, py + r, z, z + 0.5))
                return px, py
        return None


def wall_spot(segs, rid, width, zb, ztop, occ, avoid, rng, tries=200):
    """a free spot on a wall piece of room rid for something width wide from zb to ztop above the floor"""
    cand = [s for s in segs if s["rid"] == rid and not s["feature"] and s["u1"] - s["u0"] > width + 0.8]
    for _ in range(tries):
        if not cand:
            return None
        s = rng.choice(cand)
        z0, z1 = s["floor"] + zb, s["floor"] + ztop
        if s["z0"] > z0 + 1e-3 or s["z1"] < z1 - 1e-3:
            continue
        u = rng.uniform(s["u0"] + 0.4 + width / 2, s["u1"] - 0.4 - width / 2)
        ax, sg = s["ax"], s["sg"]
        p = Vector((0, 0, (z0 + z1) / 2)); p[1 - ax] = u; p[ax] = s["plane"] + sg * 0.6
        bad = False
        for (x0, x1, y0, y1, zz0, zz1) in occ:          # nothing tall standing in front of it
            if x0 - width / 2 <= p.x <= x1 + width / 2 and y0 - 0.2 <= p.y <= y1 + 0.2 and zz1 > z0 - 0.2 and zz0 < z1:
                bad = True; break
            if x0 - 0.2 <= p.x <= x1 + 0.2 and y0 - width / 2 <= p.y <= y1 + width / 2 and zz1 > z0 - 0.2 and zz0 < z1:
                bad = True; break
        if bad or any((p - q).length < r_ + width / 2 + 0.3 for q, r_ in avoid):
            continue
        n = Vector((0, 0, 0)); n[ax] = sg
        rot = {(0, 1): -90.0 + 180.0, (0, -1): -90.0, (1, 1): 180.0, (1, -1): 0.0}[(ax, sg)]
        # local -Y must point along the inward normal n: n = +x -> 90, -x -> -90, +y -> 180, -y -> 0
        rot = {(0, 1): 90.0, (0, -1): -90.0, (1, 1): 180.0, (1, -1): 0.0}[(ax, sg)]
        base = Vector((0, 0, z0)); base[1 - ax] = u; base[ax] = s["plane"]
        avoid.append((p, width / 2))
        return base, rot, s
    return None


def place_all(P, masters, segs, LAY, openings, frames_hang, rng_seed=65):
    rng = random.Random(rng_seed)
    M = masters
    occ = P.occ
    avoid = [(Vector((d["x"], d["y"], d["z"] + d["size"][1] / 2)), max(d["size"][0], d["size"][1]) / 2) for d in frames_hang]
    # ---------------- test dummies (seated in the furniture, one leaning at the north counter: never in a doorway or arch)
    x, y, z, r = P.furn_top("LR_SofaStair", -3.3, 1.4)
    P.put(M["D65_Dummy_SitA"], "Dummy_LR_Sofa", x, y, 1.93, r, note="seated on the ambush sofa's left seat")
    f = P.F["DR_Table"]
    cy = (f["y0"] + f["y1"]) / 2
    P.put(M["D65_Dummy_SitB"], "Dummy_DR_1", f["x0"] + (f["x1"] - f["x0"]) * 0.25, cy + 2.35, 1.87, 0.0, note="at the dining table")
    P.put(M["D65_Dummy_SitC"], "Dummy_DR_2", f["x0"] + (f["x1"] - f["x0"]) * 0.75 - 2.1, cy - 2.35, 1.87, 180.0, note="at the dining table")
    x, y, z, r = P.furn_top("KT_Bench", 1.5, -0.45)
    P.put(M["D65_Dummy_SitD"], "Dummy_KT_Booth", x, y, 2.1, r, note="in the diner booth")
    x, y, z, r = P.furn_top("BR2_Bed", 3.25, -1.5)
    P.put(M["D65_Dummy_SitE"], "Dummy_BR2_Bed", x, y, P.F["BR2_Bed"]["z0"] + 2.4, r + 90.0, note="sitting on the bed's edge")
    cn = P.F["KT_CounterN"]
    P.put(M["D65_Dummy_Lean"], "Dummy_KT_Counter", cn["x0"] + 1.6, cn["y0"] - 1.1, 0.0, 180.0,
          note="standing, leaning on the north counter (behind spawn B's look direction)", blocker=[cn["x0"] + 1.6, cn["y0"] - 1.4, 0.9])
    # ---------------- things on furniture tops
    x, y, z, r = P.furn_top("FY_Console", 0.6, 0.2); P.put(M["D65_Phone"], "Phone_FY", x, y, z, r)
    P.put(M["D65_Radio"], "Radio_KT", cn["x1"] - 6.0, (cn["y0"] + cn["y1"]) / 2 + 0.3, cn["z1"], 0.0)
    x, y, z, r = P.furn_top("KT_CounterE", 0.0, 0.2); P.put(M["D65_Canisters"], "Canisters_KT", x, y, z, r)
    x, y, z, r = P.furn_top("KT_Island", -2.5, 0.8); P.put(M["D65_CakeDome"], "Cake_KT", x, y, z, r)
    x, y, z, r = P.furn_top("BR2_Dresser", 1.2, 0.1); P.put(M["D65_RecordPlayer"], "RecordPlayer_BR2", x, y, z, r)
    x, y, z, r = P.furn_top("BR3_Dresser", -1.6, 0.2); P.put(M["D65_TinRocket"], "TinRocket_BR3", x, y, z, r)
    n1 = P.D.get("MB_Night1")
    if n1:
        P.put(M["D65_Radio"], "Radio_MB", n1["x"], n1["y"], n1["z"] + n1["size"][1], ROT_FACE.get(n1["face"], 0.0) + 15.0)
    # ---------------- on the floor (free spots near a hint; small pieces have no blocker, the bigger ones list one)
    for name, mname, room_hint, r_, z in (("Papers_LR", "D65_Papers", "LR_Coffee", 1.8, 0.0), ("Papers_BR2", "D65_Papers", "BR2_Desk", 1.8, 14.0),
                                          ("Papers_MB", "D65_Papers", "MB_Bed", 1.8, 14.0), ("Plates_DR", "D65_BrokenPlates", "DR_Sideboard", 1.1, 0.0),
                                          ("Plates_KT", "D65_BrokenPlates", "KT_Island", 1.1, 0.0), ("LampDown_MB", "D65_LampKnocked", "MB_FloorLamp", 2.2, 14.0),
                                          ("ChairDown_DR", "D65_ChairKnocked", "DR_Cabinet", 1.8, 0.0)):
        h = P.D.get(room_hint) or P.F.get(room_hint)
        hx = h["x"] if "x" in h else (h["x0"] + h["x1"]) / 2
        hy = h["y"] if "y" in h else (h["y0"] + h["y1"]) / 2
        spot = P.near_free(hx, hy, z, r_, rng)
        if spot:
            big = mname in ("D65_LampKnocked", "D65_ChairKnocked")
            P.put(M[mname], name, spot[0], spot[1], z, rng.uniform(0, 360), note="on the floor",
                  blocker=[round(spot[0], 2), round(spot[1], 2), r_] if big else None)
    # ---------------- sand: drifts inside the outer doors and under four windows
    for d in LAY["doors"]:
        if d["id"] in ("Door_Front", "Door_Back"):
            ca, cb = d["opening"]
            line = -30.0 if d["id"] == "Door_Front" else 30.0
            yy = line + (1.0 if line < 0 else -1.0)
            P.put(M["D65_SandDrift"], "Sand_" + d["id"], (ca + cb) / 2, yy, 0.0, 0.0 if line < 0 else 180.0, note="inside the door")
    for wid in ("Win_LR_W", "Win_DR_E", "Win_BH_N", "Win_BR3_W"):
        op = openings[wid]
        tin = op["t1"] if op["line"] < 0 else op["t0"]
        si = 1.0 if tin > (op["t0"] + op["t1"]) / 2 else -1.0
        u = (op["a"] + op["b"]) / 2
        fz = 0.0 if op["z0"] < 13 else 14.0
        if op["axis"] == "x":
            px, py, rot = u, tin + si * 0.75, (0.0 if si > 0 else 180.0)
        else:
            px, py, rot = tin + si * 0.75, u, (-90.0 if si > 0 else 90.0)
        if P.floor_free(px, py, fz, 0.6):
            P.put(M["D65_SandDriftSmall"], "Sand_" + wid, px, py, fz, rot, note="blown in under the window")
    # ---------------- cobwebs in ceiling corners (both walls present)
    n_web = 0
    for rid, rm in P.rooms.items():
        if rid in ("EN",):
            continue
        cz = 26.0 if (rm["storey"] == "U" or rid == "FY") else 13.0
        for r in P.room_rects(rm):
            for (cx_, cy_, rot) in ((r["x0"], r["y0"], 0.0), (r["x1"], r["y0"], 90.0), (r["x1"], r["y1"], 180.0), (r["x0"], r["y1"], -90.0)):
                sx = 1 if rot in (0.0, -90.0) else -1
                sy = 1 if rot in (0.0, 90.0) else -1
                if not (P.inside_any(Vector((cx_ - sx * 0.3, cy_ + sy * 1.0, cz - 0.7))) and P.inside_any(Vector((cx_ + sx * 1.0, cy_ - sy * 0.3, cz - 0.7)))):
                    continue
                if rng.random() < 0.45:
                    P.put(M["D65_Cobweb"], f"Cobweb_{rid}_{n_web}", cx_ + sx * 0.02, cy_ + sy * 0.02, cz - 0.02, rot)
                    n_web += 1
    # ---------------- posters, calendar, notice, clipboard, pennant on walls (some tilted)
    hang = (("D65_Calendar", "Calendar_KT", "KT", 1.4, 4.8, 6.9, 3.0), ("D65_Poster_Kitchen", "Poster_KT", "KT", 2.4, 5.0, 8.2, -2.0),
            ("D65_Poster_Travel", "Poster_BR2", "BR2", 2.4, 4.6, 7.8, 4.0), ("D65_Notice", "Notice_BH", "BH", 1.8, 4.6, 6.4, 0.0),
            ("D65_Clipboard", "Clipboard_MR", "MR", 0.9, 4.2, 5.4, 0.0), ("D65_Pennant", "Pennant_BR3", "BR3", 3.0, 6.0, 7.5, -5.0),
            ("D65_Calendar", "Calendar_MR", "MR", 1.4, 4.8, 6.9, 2.0), ("D65_Poster_Travel", "Poster_LD", "LD", 2.4, 4.6, 7.8, -3.0))
    for mname, name, rid, w, zb, zt, tilt in hang:
        spot = wall_spot(segs, rid, w, zb, zt, occ, avoid, rng)
        if spot:
            base, rot, s = spot
            P.put(M[mname], name, base.x, base.y, base.z, rot, tilt=tilt, note=f"on the {rid} wall")
    # ---------------- drapes pulled to the sides of the windows (never across the opening), brass rods above
    for wid, op in openings.items():
        rid = wid.split("_")[1]
        if op.get("frosted") or op.get("interior") or rid not in DRAPE:
            continue
        tin = op["t1"] if op["line"] < 0 else op["t0"]
        si = 1.0 if tin > (op["t0"] + op["t1"]) / 2 else -1.0
        fz = 0.0 if op["z0"] < 13 else 14.0
        if wid == "Win_FY_S":
            fz = 14.0     # the feature window sits high in the double-height foyer: drapes from the gallery level
        top = op["z1"] + 0.35
        h = top - fz - 0.05
        ax = op["axis"]
        rot = {("x", 1.0): 180.0, ("x", -1.0): 0.0, ("y", 1.0): 90.0, ("y", -1.0): -90.0}[(ax, si)]
        m = M["D65_Drape_" + DRAPE[rid]]
        n_side = 0
        for side, u in (("A", op["a"] - 0.7), ("B", op["b"] + 0.7)):
            # the wall must be there behind the panel (not another opening / a corner), nothing standing in front of it
            probe = Vector((u, (op["t0"] + op["t1"]) / 2, fz + h / 2)) if ax == "x" else Vector(((op["t0"] + op["t1"]) / 2, u, fz + h / 2))
            probe2 = probe.copy(); probe2.z = fz + 1.0
            if not (P.inside_any(probe) and P.inside_any(probe2)):
                continue
            px, py = (u, tin + si * 0.02) if ax == "x" else (tin + si * 0.02, u)
            fx, fy = (u, tin + si * 0.45) if ax == "x" else (tin + si * 0.45, u)
            if any(x0 - 0.55 <= fx <= x1 + 0.55 and y0 - 0.55 <= fy <= y1 + 0.55 and zz1 > fz + 0.3 and zz0 < top for (x0, x1, y0, y1, zz0, zz1) in occ):
                continue
            P.put(m, f"Drape_{wid}_{side}", px, py, fz + 0.05, rot, scale=(1, 1, h / 8.0), note="pulled to the side of the window")
            n_side += 1
        if n_side:
            u = (op["a"] + op["b"]) / 2
            L = (op["b"] - op["a"]) + 2.6
            px, py = (u, tin + si * 0.02) if ax == "x" else (tin + si * 0.02, u)
            P.put(M["D65_DrapeRod"], f"DrapeRod_{wid}", px, py, top - 0.1, rot, scale=(L, 1, 1))
    return P.out, P.log


def wear_mesh(name, quads, coll, img_path):
    """one mesh of wear quads with UVs into the 4 x 4 wear atlas; base-colour-only alpha material (Studio: TextureID)"""
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    for item in quads:
        q, cell = item[0], item[1]
        uvc = item[2] if len(item) > 2 else [(0, 0), (1, 0), (1, 1), (0, 1)]
        vs = [bm.verts.new(p) for p in q]
        f = bm.faces.new(vs)
        for l, c in zip(f.loops, uvc):
            l[uv].uv = S65._cell_uv(cell, c)
    bm.normal_update()
    bmesh.ops.triangulate(bm, faces=bm.faces[:], quad_method="BEAUTY", ngon_method="BEAUTY")
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me); bm.free()
    ob = bpy.data.objects.new(name, me)
    coll.objects.link(ob)
    m = bpy.data.materials.get("T_Wear65")
    if m is None:
        m = bpy.data.materials.new("T_Wear65")
        m.use_nodes = True
        nt = m.node_tree
        bs = nt.nodes.get("Principled BSDF")
        im = bpy.data.images.load(img_path, check_existing=True)
        t = nt.nodes.new("ShaderNodeTexImage"); t.image = im
        nt.links.new(t.outputs["Color"], bs.inputs["Base Color"])
        nt.links.new(t.outputs["Alpha"], bs.inputs["Alpha"])
        bs.inputs["Roughness"].default_value = 0.9
        try:
            m.blend_method = "BLEND"
        except Exception:
            pass
        m.use_backface_culling = True
    me.materials.append(m)
    ob["open_shell"] = True
    ob["wear"] = True
    return ob
