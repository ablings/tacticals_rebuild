"""Tacticals rooms pass 4: Showroom (Kit-menu camera set, y ~400). Training builders kept but OFF (scope change: Training is Parts in Studio).
Own geometry only (bmesh), no RIVALS ids, meshes or images. No new textures (TX_overlay_grid is already uploaded).

Run inside Blender 5.2 (Blender MCP) with kit/rooms4_kit.blend open (never read_homefile):
    g = {"__name__": "__main__"}; exec(open(r"C:/Users/aroki/Documents/tacticals_rebuild/tools/rooms4_kit.py").read(), g)
Reuses tools/rooms3_kit.py (-> rooms2_kit.py -> hub_kit.py): materials, box/prism/lathe/cyl/rod, Wall frames, bandwall, pier3,
plates, wall_light, lamp_box, ring3, floor_grid, room_ceiling, sign_board, props, finalize. Studio coordinates (x east, y up, z north).
Mesh = <piece>__<material>. Pieces: T_* Training visuals (no collision), X_T_* Training collision boxes (one mesh per box: Box
fidelity, CanQuery true, they ARE the cover the CoverController sees), SR_* Showroom (no collision), K_Scale4 / K_Marker4.
"""
import bpy, bmesh, math, os, json, re
from mathutils import Vector, Matrix

_R3 = r"C:/Users/aroki/Documents/tacticals_rebuild/tools/rooms3_kit.py"
exec(open(_R3).read().rsplit('if __name__ == "__main__" or True:', 1)[0], globals())

# RIVALS range plastic, Tacticals warm grey (rivals_style.md: 151,153,163 -> 200,196,186) + TX_overlay_grid 5x5 (black, 0.75)
MATS["range_grey"] = ((200, 196, 186), "hub_concrete_smooth", 12, 0.0, 0.55, False,
                      "SmoothPlastic + Texture TX_overlay_grid 5x5 (Color3 black, Transparency 0.75, all faces)")

# display-table top: plain warm grey satin, no tiling (the Kit menu draws its fake item shadow on it)
MATS["bench_top"] = ((150, 147, 140), None, 10, 0.1, 0.45, False, "SmoothPlastic (warm grey satin, no texture)")

def make_range_grey():
    m = make_material("range_grey")
    if m.get("grid"):
        return m
    nt = m.node_tree; N = nt.nodes; L = nt.links
    bsdf = N.get("Principled BSDF")
    src = bsdf.inputs["Base Color"].links[0].from_socket if bsdf.inputs["Base Color"].links else None
    uv = N.new("ShaderNodeTexCoord"); mp = N.new("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (UV_STUDS / 5.0,) * 3
    ig = N.new("ShaderNodeTexImage"); ig.image = get_img(TEX + "hub_overlay_grid.png")
    L.new(uv.outputs["UV"], mp.inputs["Vector"]); L.new(mp.outputs["Vector"], ig.inputs["Vector"])
    mx = N.new("ShaderNodeMix"); mx.data_type = "RGBA"; mx.blend_type = "MIX"
    fac = N.new("ShaderNodeMath"); fac.operation = "MULTIPLY"; fac.inputs[1].default_value = 0.35
    L.new(ig.outputs["Alpha"], fac.inputs[0]); L.new(fac.outputs[0], mx.inputs["Factor"])
    if src:
        L.new(src, mx.inputs[6])
    mx.inputs[7].default_value = (0.0, 0.0, 0.0, 1)
    L.new(mx.outputs[2], bsdf.inputs["Base Color"])
    m["grid"] = 1
    return m

# ================================================================== TRAINING (survey: layout.md, scan/slice_training.json)
FY = 600.0                      # floor top (TrainingManager FLOOR_Y = 600)
WX, WZ = 86.0, 119.0            # inner wall faces (floor 172 x 238)
TRAIN = dict(base=FY, body_top=618.5, dark=(618.5, 620.5), upper=(620.5, 620.5), corn=(632.0, 636.0), top=636.0,
             prof=[(0.0, 632.0), (0.7, 633.4), (1.6, 634.6), (2.4, 635.4), (2.4, 636.0)])
PIER_Z = [-WZ + 17.0 * k for k in range(1, 14)]               # long walls (x = +-86): bays 17 wide, pier on z 0
PIER_X = [-WX + (2 * WX / 12.0) * k for k in range(1, 12)]     # end walls (z = +-119): pier on x 0
# divider windows (sill top 603.4 as surveyed, head 609.9 = band top), 5 wide
WIN_XE = [-78.0, -68.0, -58.0, -28.0, -18.0]
WIN_XW = [18.0, 28.0, 58.0, 68.0, 78.0]
WIN_ZN = [20.0, 30.0, 40.0, 80.0, 90.0, 100.0, 110.0]
WIN_ZS = [-110.0, -100.0, -90.0, -80.0, -40.0, -30.0, -20.0]
SILL, HEAD, DTOP, DT = 603.4, 609.9, 622.0, 1.2
ARRIVE = [(-10, -110), (-15, -110), (-72, -10), (-77, -10), (15, 110), (10, 110), (77, 10), (72, 10),
          (15, -110), (10, -110), (77, -10), (72, -10), (-10, 110), (-15, 110), (-72, 10), (-77, 10)]
LIGHTS = [(x, z) for x in (-56.0, 0.0, 56.0) for z in (-80.0, -27.0, 27.0, 80.0)]   # Training.Light parts (y 633)

# cover layout = the surveyed Arena parts (blocks / pillars / walls from the y604 ray slice, low walls from the 2-stud scan):
# (original part name, kind, x0, x1, z0, z1, top). The X_T_<name> clip box is exactly this box.
COVER = [
    ('A_Block1', 'Block', -40.0, -35.0, -69.0, -65.0, 607.0), ('A_Block2', 'Block', -50.0, -45.0, -53.0, -49.0, 607.0),
    ('A_Block3', 'Block', -14.0, -9.0, -84.0, -80.0, 607.0), ('A_Block4', 'Block', -76.0, -71.0, -38.0, -34.0, 607.0),
    ('A_Block5', 'Block', -76.0, -71.0, -95.0, -91.0, 607.0), ('A_Block6', 'Block', -14.0, -9.0, -27.0, -23.0, 607.0),
    ('A_Block7', 'Block', -36.0, -31.0, -104.0, -100.0, 607.0), ('A_Block8', 'Block', -54.0, -49.0, -18.0, -14.0, 607.0),
    ('A_Block9', 'Block', -28.0, -23.0, -95.0, -91.0, 607.0), ('A_Block10', 'Block', -62.0, -57.0, -27.0, -23.0, 607.0),
    ('A_LowWall11', 'LowWall', -21.5, -16.5, -103.2, -100.8, 603.4), ('A_LowWall12', 'LowWall', -67.5, -62.5, -17.2, -14.8, 603.4),
    ('A_LowWall13', 'LowWall', -33.5, -28.5, -79.2, -76.8, 603.4), ('A_LowWall14', 'LowWall', -57.5, -52.5, -41.2, -38.8, 603.4),
    ('A_LowWall15', 'LowWall', -63.5, -58.5, -85.2, -82.8, 603.4), ('A_LowWall16', 'LowWall', -27.5, -22.5, -35.2, -32.8, 603.4),
    ('A_LowWall17', 'LowWall', -41.5, -36.5, -91.2, -88.8, 603.4), ('A_LowWall18', 'LowWall', -49.5, -44.5, -29.2, -26.8, 603.4),
    ('A_LowWall19', 'LowWall', -19.5, -14.5, -55.6, -54.4, 603.4), ('A_LowWall20', 'LowWall', -71.5, -66.5, -63.6, -62.4, 603.4),
    ('A_LowWall21', 'LowWall', -17.5, -12.5, -71.6, -70.4, 603.4), ('A_LowWall22', 'LowWall', -71.5, -66.5, -47.6, -46.4, 603.4),
    ('A_Pillar23', 'Pillar', -16.0, -11.0, -105.5, -100.5, 622.0), ('A_Pillar24', 'Pillar', -74.0, -69.0, -17.5, -12.5, 622.0),
    ('A_Pillar25', 'Pillar', -27.0, -22.0, -80.5, -75.5, 622.0), ('A_Pillar26', 'Pillar', -63.0, -58.0, -80.5, -75.5, 622.0),
    ('A_Pillar27', 'Pillar', -27.0, -22.0, -42.5, -37.5, 622.0), ('A_Pillar28', 'Pillar', -63.0, -58.0, -42.5, -37.5, 622.0),
    ('A_Wall29', 'Wall', -31.5, -21.5, -54.5, -51.5, 612.0), ('A_Wall30', 'Wall', -63.5, -53.5, -66.5, -63.5, 612.0),
    ('A_Wall31', 'Wall', -64.5, -54.5, -109.5, -106.5, 612.0), ('A_Wall32', 'Wall', -30.5, -20.5, -11.5, -8.5, 612.0),
    ('B_Block1', 'Block', 37.0, 42.0, 67.0, 71.0, 607.0), ('B_Block2', 'Block', 47.0, 52.0, 51.0, 55.0, 607.0),
    ('B_Block3', 'Block', 11.0, 16.0, 82.0, 86.0, 607.0), ('B_Block4', 'Block', 73.0, 78.0, 36.0, 40.0, 607.0),
    ('B_Block5', 'Block', 73.0, 78.0, 93.0, 97.0, 607.0), ('B_Block6', 'Block', 11.0, 16.0, 25.0, 29.0, 607.0),
    ('B_Block7', 'Block', 33.0, 38.0, 102.0, 106.0, 607.0), ('B_Block8', 'Block', 51.0, 56.0, 16.0, 20.0, 607.0),
    ('B_Block9', 'Block', 25.0, 30.0, 93.0, 97.0, 607.0), ('B_Block10', 'Block', 59.0, 64.0, 25.0, 29.0, 607.0),
    ('B_LowWall11', 'LowWall', 18.5, 23.5, 102.8, 105.2, 603.4), ('B_LowWall12', 'LowWall', 64.5, 69.5, 16.8, 19.2, 603.4),
    ('B_LowWall13', 'LowWall', 30.5, 35.5, 78.8, 81.2, 603.4), ('B_LowWall14', 'LowWall', 54.5, 59.5, 40.8, 43.2, 603.4),
    ('B_LowWall15', 'LowWall', 60.5, 65.5, 84.8, 87.2, 603.4), ('B_LowWall16', 'LowWall', 24.5, 29.5, 34.8, 37.2, 603.4),
    ('B_LowWall17', 'LowWall', 38.5, 43.5, 90.8, 93.2, 603.4), ('B_LowWall18', 'LowWall', 46.5, 51.5, 28.8, 31.2, 603.4),
    ('B_LowWall19', 'LowWall', 16.5, 21.5, 56.4, 57.6, 603.4), ('B_LowWall20', 'LowWall', 68.5, 73.5, 64.4, 65.6, 603.4),
    ('B_LowWall21', 'LowWall', 14.5, 19.5, 72.4, 73.6, 603.4), ('B_LowWall22', 'LowWall', 68.5, 73.5, 48.4, 49.6, 603.4),
    ('B_Pillar23', 'Pillar', 13.0, 18.0, 102.5, 107.5, 622.0), ('B_Pillar24', 'Pillar', 71.0, 76.0, 14.5, 19.5, 622.0),
    ('B_Pillar25', 'Pillar', 24.0, 29.0, 77.5, 82.5, 622.0), ('B_Pillar26', 'Pillar', 60.0, 65.0, 77.5, 82.5, 622.0),
    ('B_Pillar27', 'Pillar', 24.0, 29.0, 39.5, 44.5, 622.0), ('B_Pillar28', 'Pillar', 60.0, 65.0, 39.5, 44.5, 622.0),
    ('B_Wall29', 'Wall', 23.5, 33.5, 53.5, 56.5, 612.0), ('B_Wall30', 'Wall', 55.5, 65.5, 65.5, 68.5, 612.0),
    ('B_Wall31', 'Wall', 56.5, 66.5, 108.5, 111.5, 612.0), ('B_Wall32', 'Wall', 22.5, 32.5, 10.5, 13.5, 612.0),
    ('C_Block1', 'Block', 37.0, 42.0, -69.0, -65.0, 607.0), ('C_Block2', 'Block', 47.0, 52.0, -53.0, -49.0, 607.0),
    ('C_Block3', 'Block', 11.0, 16.0, -84.0, -80.0, 607.0), ('C_Block4', 'Block', 73.0, 78.0, -38.0, -34.0, 607.0),
    ('C_Block5', 'Block', 73.0, 78.0, -95.0, -91.0, 607.0), ('C_Block6', 'Block', 11.0, 16.0, -27.0, -23.0, 607.0),
    ('C_Block7', 'Block', 33.0, 38.0, -104.0, -100.0, 607.0), ('C_Block8', 'Block', 51.0, 56.0, -18.0, -14.0, 607.0),
    ('C_Block9', 'Block', 25.0, 30.0, -95.0, -91.0, 607.0), ('C_Block10', 'Block', 59.0, 64.0, -27.0, -23.0, 607.0),
    ('C_LowWall11', 'LowWall', 18.5, 23.5, -103.2, -100.8, 603.4), ('C_LowWall12', 'LowWall', 64.5, 69.5, -17.2, -14.8, 603.4),
    ('C_LowWall13', 'LowWall', 30.5, 35.5, -79.2, -76.8, 603.4), ('C_LowWall14', 'LowWall', 54.5, 59.5, -41.2, -38.8, 603.4),
    ('C_LowWall15', 'LowWall', 60.5, 65.5, -85.2, -82.8, 603.4), ('C_LowWall16', 'LowWall', 24.5, 29.5, -35.2, -32.8, 603.4),
    ('C_LowWall17', 'LowWall', 38.5, 43.5, -91.2, -88.8, 603.4), ('C_LowWall18', 'LowWall', 46.5, 51.5, -29.2, -26.8, 603.4),
    ('C_LowWall19', 'LowWall', 16.5, 21.5, -55.6, -54.4, 603.4), ('C_LowWall20', 'LowWall', 68.5, 73.5, -63.6, -62.4, 603.4),
    ('C_LowWall21', 'LowWall', 14.5, 19.5, -71.6, -70.4, 603.4), ('C_LowWall22', 'LowWall', 68.5, 73.5, -47.6, -46.4, 603.4),
    ('C_Pillar23', 'Pillar', 13.0, 18.0, -105.5, -100.5, 622.0), ('C_Pillar24', 'Pillar', 71.0, 76.0, -17.5, -12.5, 622.0),
    ('C_Pillar25', 'Pillar', 24.0, 29.0, -80.5, -75.5, 622.0), ('C_Pillar26', 'Pillar', 60.0, 65.0, -80.5, -75.5, 622.0),
    ('C_Pillar27', 'Pillar', 24.0, 29.0, -42.5, -37.5, 622.0), ('C_Pillar28', 'Pillar', 60.0, 65.0, -42.5, -37.5, 622.0),
    ('C_Wall29', 'Wall', 23.5, 33.5, -54.5, -51.5, 612.0), ('C_Wall30', 'Wall', 55.5, 65.5, -66.5, -63.5, 612.0),
    ('C_Wall31', 'Wall', 56.5, 66.5, -109.5, -106.5, 612.0), ('C_Wall32', 'Wall', 22.5, 32.5, -11.5, -8.5, 612.0),
    ('D_Block1', 'Block', -40.0, -35.0, 67.0, 71.0, 607.0), ('D_Block2', 'Block', -50.0, -45.0, 51.0, 55.0, 607.0),
    ('D_Block3', 'Block', -14.0, -9.0, 82.0, 86.0, 607.0), ('D_Block4', 'Block', -76.0, -71.0, 36.0, 40.0, 607.0),
    ('D_Block5', 'Block', -76.0, -71.0, 93.0, 97.0, 607.0), ('D_Block6', 'Block', -14.0, -9.0, 25.0, 29.0, 607.0),
    ('D_Block7', 'Block', -36.0, -31.0, 102.0, 106.0, 607.0), ('D_Block8', 'Block', -54.0, -49.0, 16.0, 20.0, 607.0),
    ('D_Block9', 'Block', -28.0, -23.0, 93.0, 97.0, 607.0), ('D_Block10', 'Block', -62.0, -57.0, 25.0, 29.0, 607.0),
    ('D_LowWall11', 'LowWall', -21.5, -16.5, 102.8, 105.2, 603.4), ('D_LowWall12', 'LowWall', -67.5, -62.5, 16.8, 19.2, 603.4),
    ('D_LowWall13', 'LowWall', -33.5, -28.5, 78.8, 81.2, 603.4), ('D_LowWall14', 'LowWall', -57.5, -52.5, 40.8, 43.2, 603.4),
    ('D_LowWall15', 'LowWall', -63.5, -58.5, 84.8, 87.2, 603.4), ('D_LowWall16', 'LowWall', -27.5, -22.5, 34.8, 37.2, 603.4),
    ('D_LowWall17', 'LowWall', -41.5, -36.5, 90.8, 93.2, 603.4), ('D_LowWall18', 'LowWall', -49.5, -44.5, 28.8, 31.2, 603.4),
    ('D_LowWall19', 'LowWall', -19.5, -14.5, 56.4, 57.6, 603.4), ('D_LowWall20', 'LowWall', -71.5, -66.5, 64.4, 65.6, 603.4),
    ('D_LowWall21', 'LowWall', -17.5, -12.5, 72.4, 73.6, 603.4), ('D_LowWall22', 'LowWall', -71.5, -66.5, 48.4, 49.6, 603.4),
    ('D_Pillar23', 'Pillar', -16.0, -11.0, 102.5, 107.5, 622.0), ('D_Pillar24', 'Pillar', -74.0, -69.0, 14.5, 19.5, 622.0),
    ('D_Pillar25', 'Pillar', -27.0, -22.0, 77.5, 82.5, 622.0), ('D_Pillar26', 'Pillar', -63.0, -58.0, 77.5, 82.5, 622.0),
    ('D_Pillar27', 'Pillar', -27.0, -22.0, 39.5, 44.5, 622.0), ('D_Pillar28', 'Pillar', -63.0, -58.0, 39.5, 44.5, 622.0),
    ('D_Wall29', 'Wall', -31.5, -21.5, 53.5, 56.5, 612.0), ('D_Wall30', 'Wall', -63.5, -53.5, 65.5, 68.5, 612.0),
    ('D_Wall31', 'Wall', -64.5, -54.5, 108.5, 111.5, 612.0), ('D_Wall32', 'Wall', -30.5, -20.5, 10.5, 13.5, 612.0),
]
REPLACES = {}   # X_ piece -> original Arena part(s) it stands in for

def xbox(name, x0, x1, y0, y1, z0, z1, replaces=None):
    piece = "X_T_" + name
    box(piece, "clip", x0, x1, y0, y1, z0, z1, 0.0)
    REPLACES[piece] = replaces or ""

# ------------------------------------------------------------------ perimeter walls (banded, sky windows in the upper zone)
def upper_bay(W, P, a, b):
    """Ribbed upper zone 620.5-632 of one bay with a real opening to the sky (glass mid-wall, frame, mullions, transom)."""
    T = 2.0; y0, y1 = 620.5, 632.0; oy0, oy1 = 621.7, 630.8
    sa, sb = a + 2.4, b - 2.4
    W.box(P, "wall_upper", a, sa, y0, y1, -T, 0.0, 0.1)
    W.box(P, "wall_upper", sb, b, y0, y1, -T, 0.0, 0.1)
    W.box(P, "wall_upper", sa, sb, y0, oy0, -T, 0.0, 0.08)
    W.box(P, "wall_upper", sa, sb, oy1, y1, -T, 0.0, 0.08)
    G = "T_Windows"
    W.box(G, "trim_metal", sa - 0.5, sb + 0.5, oy0 - 0.5, oy0, -T, 0.55, 0.1)       # sill
    W.box(G, "trim_metal", sa - 0.5, sb + 0.5, oy1, oy1 + 0.45, -T, 0.45, 0.1)      # head
    W.box(G, "trim_metal", sa - 0.5, sa, oy0, oy1, -T, 0.45, 0.1)
    W.box(G, "trim_metal", sb, sb + 0.5, oy0, oy1, -T, 0.45, 0.1)
    n = max(2, int(round((sb - sa) / 4.2)))
    for i in range(1, n):
        s = sa + (sb - sa) * i / n
        W.box(G, "beam_metal", s - 0.2, s + 0.2, oy0, oy1, -1.4, 0.15, 0.04)
    W.box(G, "beam_metal", sa, sb, 626.05, 626.35, -1.4, 0.1, 0.03)
    W.box(G, "glass", sa, sb, oy0, oy1, -1.05, -0.95, 0.0)

def target_panel(W, s):
    """Wall-mounted steel target with bullet trap (RIVALS-plain: cream plate, dark frame, olive hit lamp)."""
    P = "T_Targets"
    W.prism(P, "dark_metal", [(0.0, FY), (1.7, FY), (0.3, FY + 3.2), (0.0, FY + 3.2)], s - 1.8, s + 1.8)   # sloped trap
    W.box(P, "trim_metal", s - 1.9, s + 1.9, FY + 3.2, FY + 3.5, 0.0, 0.8, 0.06)
    W.box(P, "beam_metal", s - 0.15, s + 0.15, FY + 3.5, FY + 4.0, 0.2, 0.5, 0.03)
    W.box(P, "dark_metal", s - 1.35, s + 1.35, FY + 3.95, FY + 7.45, 0.45, 0.6, 0.05)
    W.box(P, "label_cream", s - 1.15, s + 1.15, FY + 4.15, FY + 7.25, 0.6, 0.68, 0.03)
    W.box(P, "dark_metal", s - 0.75, s + 0.75, FY + 5.55, FY + 5.85, 0.68, 0.72, 0.0)
    W.box(P, "dark_metal", s - 0.15, s + 0.15, FY + 4.95, FY + 6.45, 0.68, 0.72, 0.0)
    W.box(P, "neon_olive", s - 0.25, s + 0.25, FY + 7.7, FY + 8.0, 0.25, 0.45, 0.02)
    W.box(P, "label_cream", s - 1.0, s + 1.0, FY + 2.0, FY + 2.6, 1.0, 1.05, 0.0) if False else None

def build_t_walls():
    P = "T_Walls"; Pi = "T_Piers"; L = "T_Lights"
    sets = [(Wall("z", -WX, +1), -WZ, WZ, PIER_Z, True), (Wall("z", WX, -1), -WZ, WZ, PIER_Z, True),
            (Wall("x", -WZ, +1), -WX, WX, PIER_X, False), (Wall("x", WZ, -1), -WX, WX, PIER_X, False)]
    for (W, s0, s1, piers, longw) in sets:
        bandwall(W, P, s0 - 2.0, s1 + 2.0, TRAIN)
        edges = [s0] + piers + [s1]
        for i in range(len(edges) - 1):
            a, b = edges[i], edges[i + 1]
            upper_bay(W, P, a, b)
            plates(W, P, a + (0.2 if i == 0 else 1.1), b - (0.2 if i == len(edges) - 2 else 1.1), 610.6, 617.9, 0.0, 0.3,
                   cols=3 if (b - a) > 15 else 2)
            plates(W, P, a + (0.2 if i == 0 else 1.1), b - (0.2 if i == len(edges) - 2 else 1.1), 601.4, 606.4, 0.3, 0.5, cols=2)
            c = (a + b) / 2
            if longw and 20.0 < abs(c) < 100.0 and int(abs(c)) % 34 in (25, 8):
                target_panel(W, c)
        for s in piers:
            pier3(W, Pi, s, FY, 636.0, light_y=FY + 14.2, lights=L)
            W.box(Pi, "label_cream", s - 0.7, s + 0.7, FY + 10.6, FY + 11.4, 1.2, 1.32, 0.03)   # bay number plate
    # corner fills
    for sx in (-1, 1):
        for sz in (-1, 1):
            xa, xb = sorted((sx * (WX - 0.4), sx * (WX + 2.0))); za, zb = sorted((sz * (WZ - 0.4), sz * (WZ + 2.0)))
            box(P, "wall_light", xa, xb, FY, 632.0, za, zb, 0.2, 2)
            box(P, "band_olive", xa - 0.1, xb + 0.1, FY + 7.1, FY + 9.9, za - 0.1, zb + 0.1, 0.08)

# ------------------------------------------------------------------ dividers (2.4 thick, top 622, shoot-through windows)
def build_div(W, s0, s1, wins, tag, hub_end):
    P = "T_Div"; L = "T_Lights"
    hw = 2.5
    ops = sorted([(c - hw, c + hw) for c in wins])
    # solid stretches between openings
    cuts = [s0] + [v for o in ops for v in o] + [s1]
    segs = [(cuts[2 * i], cuts[2 * i + 1]) for i in range(len(cuts) // 2)]
    for k, (a, b) in enumerate(segs):
        xbox(f"Div_{tag}_Seg{k + 1}", *_wbox(W, a, b, FY, DTOP, -DT, DT), replaces=f"Div_{tag}")
        W.box(P, "wall_body", a, b, FY + 10.0, 618.5, -1.0, 1.0, 0.1)
        W.box(P, "wall_kick", a, b, FY, FY + 7.0, -1.15, 1.15, 0.12)
        W.box(P, "trim_metal", a, b, FY, FY + 0.8, -1.2, 1.2, 0.08)
        W.box(P, "band_olive", a, b, FY + 7.1, HEAD, -1.18, 1.18, 0.1)
        W.box(P, "trim_metal", a, b, FY + 6.85, FY + 7.15, -1.22, 1.22, 0.05)
        if b - a > 6.0:
            for d0, d1 in ((-1.15, -1.0), (1.0, 1.15)):
                for (pa, pb) in ((a + 0.6, (a + b) / 2 - 0.12), ((a + b) / 2 + 0.12, b - 0.6)):
                    if pb - pa > 1.0:
                        W.box(P, "wall_plate", pa, pb, 611.0, 617.8, d0, d1, 0.08)
    for k, (a, b) in enumerate(ops):
        xbox(f"Div_{tag}_Sill{k + 1}", *_wbox(W, a, b, FY, SILL, -DT, DT), replaces=f"Div_{tag}_Sill{k + 1}")
        xbox(f"Div_{tag}_Head{k + 1}", *_wbox(W, a, b, HEAD, DTOP, -DT, DT), replaces=f"Div_{tag}")
        W.box(P, "wall_kick", a, b, FY, SILL - 0.25, -1.15, 1.15, 0.12)
        W.box(P, "trim_metal", a, b, FY, FY + 0.8, -1.2, 1.2, 0.08)
        W.box(P, "trim_metal", a - 0.1, b + 0.1, SILL - 0.25, SILL - 0.04, -1.22, 1.22, 0.05)
        W.box("T_Lines", "hazard", a, b, SILL - 0.05, SILL, -1.1, 1.1, 0.0)
        W.box(P, "wall_body", a, b, HEAD, 618.5, -1.0, 1.0, 0.1)
        W.box(P, "trim_metal", a - 0.1, b + 0.1, HEAD, HEAD + 0.3, -1.22, 1.22, 0.05)
        for s in (a, b):   # jamb liners
            sa, sb = (s, s + 0.22) if s == a else (s - 0.22, s)
            W.box(P, "trim_metal", sa, sb, SILL - 0.04, HEAD, -1.22, 1.22, 0.03)
        for sg in (-1, 1):  # hazard floor strip each side (vault spot)
            da, db = sorted((sg * 1.5, sg * 2.4))
            W.box("T_Lines", "hazard", a, b, FY, FY + 0.06, da, db, 0.0)
    # continuous upper layers
    W.box(P, "trim_metal", s0, s1, HEAD - 0.05, HEAD + 0.25, -1.22, 1.22, 0.05) if False else None
    W.box(P, "wall_dark", s0, s1, 618.5, 620.6, -1.1, 1.1, 0.1)
    W.box(P, "trim_light", s0, s1, 620.4, 620.8, -1.2, 1.2, 0.05)
    W.box(P, "wall_body", s0, s1, 620.8, 621.4, -1.0, 1.0, 0.06)
    W.box(P, "trim_metal", s0, s1, 621.4, DTOP, -1.3, 1.3, 0.1)
    W.box("T_Lines", "neon_olive", s0, s1, 621.0, 621.25, -1.16, 1.16, 0.0)
    # hub-end pier with a capsule light facing the hub
    he = hub_end; sg = 1 if he > 0 else -1
    a, b = sorted((he, he + sg * 1.9))
    W.box(P, "wall_light", a, b, FY, DTOP + 0.6, -1.5, 1.5, 0.25, 2)
    W.box(P, "trim_metal", a - 0.05, b + 0.05, FY, FY + 1.6, -1.6, 1.6, 0.1)
    W.box(P, "band_olive", a - 0.03, b + 0.03, FY + 7.1, FY + 9.9, -1.56, 1.56, 0.08)
    if W.along == "x":
        Wf = Wall("z", he, -sg)
    else:
        Wf = Wall("x", he, -sg)
    wall_light(Wf, 0.0, 0.0, FY + 14.2, piece=L)

def _wbox(W, s0, s1, y0, y1, d0, d1):
    a = W.p(s0, y0, d0); b = W.p(s1, y1, d1)
    return (min(a[0], b[0]), max(a[0], b[0]), y0, y1, min(a[2], b[2]), max(a[2], b[2]))

def build_t_dividers():
    WXd = Wall("x", 0.0, +1); WZd = Wall("z", 0.0, +1)
    build_div(WXd, -WX, -10.0, WIN_XE, "X_E", -10.0)
    build_div(WXd, 10.0, WX, WIN_XW, "X_W", 10.0)
    build_div(WZd, -WZ, -10.0, WIN_ZS, "Z_S", -10.0)
    build_div(WZd, 10.0, WZ, WIN_ZN, "Z_N", 10.0)

# ------------------------------------------------------------------ hub gantry + TRAINING sign (HubBeam z -12..12 at x 0, top 623.2)
def build_t_hub():
    H = "T_Hub"; L = "T_Lights"
    box(H, "beam_metal", -0.25, 0.25, 621.4, 622.9, -12.0, 12.0, 0.04)           # web
    for (y0, y1) in ((621.1, 621.4), (622.9, 623.2)):
        box(H, "beam_metal", -0.9, 0.9, y0, y1, -12.0, 12.0, 0.06)               # flanges
    for z in (-9.0, -4.5, 0.0, 4.5, 9.0):
        box(H, "beam_metal", -0.8, 0.8, 621.4, 622.9, z - 0.1, z + 0.1, 0.02)
    box(H, "sign_board", -0.6, 0.6, 623.4, 628.8, -8.0, 8.0, 0.15, 2)
    box(H, "trim_metal", -0.75, 0.75, 623.2, 623.5, -8.2, 8.2, 0.05)
    for sg in (-1, 1):
        x0, x1 = sorted((sg * 0.6, sg * 0.72))
        e = 0.22
        for (y0, y1, z0, z1) in ((623.4, 623.4 + e, -8.0, 8.0), (628.8 - e, 628.8, -8.0, 8.0), (623.4, 628.8, -8.0, -8.0 + e), (623.4, 628.8, 8.0 - e, 8.0)):
            box("T_Signs", "neon_olive", x0, x1, y0, y1, z0, z1, 0.0)
        xa, xb = sorted((sg * 0.6, sg * 0.66))
        box("T_Signs", "label_cream", xa, xb, 624.3, 627.9, -6.6, 6.6, 0.0)
    for z in (-6.0, 6.0):
        rod(H, "dark_metal", (0, 628.8, z), (0, 636.0, z), 0.12, 8)
        box(H, "trim_metal", -0.4, 0.4, 628.8, 629.1, z - 0.4, z + 0.4, 0.04)
    for z in (-10.5, 10.5):
        lamp_box(L, 0.0, 620.3, z, 1.2, 1.6)
        box(H, "dark_metal", -0.1, 0.1, 621.0, 621.1, z - 0.5, z + 0.5, 0.0)

# ------------------------------------------------------------------ floor, lines, arrivals, centre medallion
def build_t_floor():
    F = "T_Floor"; Ln = "T_Lines"
    xs = [-WX + 2.5 + (2 * WX - 5.0) * i / 12 for i in range(13)]
    zs = [-WZ + 2.5 + (2 * WZ - 5.0) * i / 14 for i in range(15)]
    floor_grid(F, -WX, WX, -WZ, WZ, xs, zs, FY)
    # centre medallion (old HubRing): dark disc, metal ring with ticks, olive Neon ring broken on the divider lines, cream inner ring
    lathe(F, "floor_border", [(0.0, -0.3), (8.4, -0.3), (8.4, 0.03), (0.0, 0.03)], seg=96, y0=FY)
    lathe(F, "plate_metal", [(4.0, -0.2), (5.8, -0.2), (5.8, 0.05), (4.0, 0.05)], seg=96, y0=FY)
    cyl(F, "disc_center", 0.0, 0.0, 2.6, FY - 0.2, FY + 0.06, seg=48, bev=0.05)
    ring3(Ln, "neon_olive", 0.0, 0.0, 8.8, 9.15, FY, gaps_deg=(0, 90, 180, 270), half_gap=9)
    ring3(Ln, "neon_cream", 0.0, 0.0, 6.4, 6.65, FY, gaps_deg=(45, 135, 225, 315), half_gap=10)
    for k in range(32):
        a = math.radians(11.25 * k); ca, sa = math.cos(a), math.sin(a)
        r0, r1, w = 4.3, 5.5 if k % 4 == 0 else 5.0, 0.07
        pts = [(r0 * ca - w * sa, FY + 0.05, r0 * sa + w * ca), (r1 * ca - w * sa, FY + 0.05, r1 * sa + w * ca),
               (r1 * ca + w * sa, FY + 0.05, r1 * sa - w * ca), (r0 * ca + w * sa, FY + 0.05, r0 * sa - w * ca)]
        prism(F, "dark_metal", pts, (0, 0.03, 0))
    # quadrant plates (A/B/C/D by SurfaceGui) on the floor next to the hub
    for (qx, qz) in ((-16.5, -16.5), (16.5, 16.5), (16.5, -16.5), (-16.5, 16.5)):
        box(F, "dark_metal", qx - 2.3, qx + 2.3, FY - 0.1, FY + 0.05, qz - 2.3, qz + 2.3, 0.04)
        box("T_Signs", "label_cream", qx - 1.9, qx + 1.9, FY + 0.05, FY + 0.09, qz - 1.9, qz + 1.9, 0.0)
    # arrival pads: dark disc + olive Neon ring + cream arrow toward the room centre; firing line + label plate per pair
    for (x, z) in ARRIVE:
        lathe(F, "case_dark", [(0.0, -0.1), (1.8, -0.1), (1.8, 0.04), (0.0, 0.04)], cx=x, cz=z, seg=32, y0=FY)
        ring3(Ln, "neon_olive", x, z, 1.95, 2.2, FY, gaps_deg=(45, 135, 225, 315), half_gap=12, seg=48)
        if abs(z) > 100:
            sz = -1 if z > 0 else 1
            tri = [(x - 0.7, FY + 0.06, z + sz * 0.4), (x, FY + 0.06, z + sz * 1.4), (x + 0.7, FY + 0.06, z + sz * 0.4), (x, FY + 0.06, z + sz * 0.8)]
        else:
            sx = -1 if x > 0 else 1
            tri = [(x + sx * 0.4, FY + 0.06, z - 0.7), (x + sx * 1.4, FY + 0.06, z), (x + sx * 0.4, FY + 0.06, z + 0.7), (x + sx * 0.8, FY + 0.06, z)]
        prism(Ln, "neon_cream", tri, (0, 0.04, 0))
    for sx in (-1, 1):
        for sz in (-1, 1):
            # end-wall pairs (x +-10/15, z +-110): firing line toward the room, label plate against the wall
            xa, xb = sorted((sx * 7.0, sx * 18.0))
            box(Ln, "neon_cream", xa, xb, FY - 0.4, FY + 0.07, sz * 106.6 - 0.19, sz * 106.6 + 0.19, 0.0)
            box("T_Signs", "label_cream", sx * 12.5 - 2.2, sx * 12.5 + 2.2, FY + 0.03, FY + 0.07, sz * 114.0 - 0.6, sz * 114.0 + 0.6, 0.0)
            # side-wall pairs (x +-72/77, z +-10)
            za, zb = sorted((sz * 6.5, sz * 13.5))
            box(Ln, "neon_cream", sx * 68.4 - 0.19, sx * 68.4 + 0.19, FY - 0.4, FY + 0.07, za, zb, 0.0)
            box("T_Signs", "label_cream", sx * 81.5 - 0.6, sx * 81.5 + 0.6, FY + 0.03, FY + 0.07, sz * 10.0 - 2.2, sz * 10.0 + 2.2, 0.0)
    # perimeter walkway lines (cream, inside the border) along the long walls, broken at the arrival pairs
    for sx in (-1, 1):
        for (za, zb) in ((-WZ + 4.0, -15.0), (15.0, WZ - 4.0)):
            box(Ln, "neon_cream", sx * (WX - 4.2) - 0.19, sx * (WX - 4.2) + 0.19, FY - 0.4, FY + 0.07, za, zb, 0.0)

# ------------------------------------------------------------------ ceiling (slab 636-637.5), beams, lamp troughs, 12 flood fixtures
def build_t_ceiling():
    room_ceiling("T_Ceiling", "T_Lights", -WX, WX, -WZ, WZ, 636.0, [-28.0, 28.0], [-106.0, -53.5, 0.0, 53.5, 106.0], 3.0, [-56.0, 0.0, 56.0])
    L = "T_Lights"
    for (x, z) in LIGHTS:      # homes of the Training.Light parts (y ~633)
        lamp_box(L, x, 633.2, z, 3.2, 1.8)
        for dx in (-1.2, 1.2):
            rod(L, "dark_metal", (x + dx, 633.9, z), (x + dx, 635.3, z), 0.07, 6)
    # floating underside skirt under the floor slab (seen only through the upper windows from nowhere: keep it thin)
    box("T_Base", "wall_dark", -WX - 2.0, WX + 2.0, FY - 4.0, FY - 1.0, -WZ - 2.0, WZ + 2.0, 0.15)
    for sz in (-1, 1):
        z0, z1 = sorted((sz * (WZ + 2.0), sz * (WZ + 2.3)))
        box("T_Base", "band_olive", -WX - 2.0, WX + 2.0, FY - 3.0, FY - 2.0, z0, z1, 0.05)

# ------------------------------------------------------------------ cover pieces (visual; the X_T_ boxes collide)
def crate_rect(P, x0, x1, y0, y1, z0, z1, mat="crate_green", k=0):
    f = 0.3
    box(P, mat, x0 + 0.12, x1 - 0.12, y0 + 0.1, y1 - 0.1, z0 + 0.12, z1 - 0.12, 0.08)
    for (xa, xb) in ((x0, x0 + f), (x1 - f, x1)):
        for (za, zb) in ((z0, z0 + f), (z1 - f, z1)):
            box(P, "dark_metal", xa, xb, y0, y1, za, zb, 0.06)
    for (ya, yb) in ((y0, y0 + f), (y1 - f, y1)):
        box(P, "dark_metal", x0, x1, ya, yb, z0, z0 + f, 0.06); box(P, "dark_metal", x0, x1, ya, yb, z1 - f, z1, 0.06)
        box(P, "dark_metal", x0, x0 + f, ya, yb, z0 + f, z1 - f, 0.06); box(P, "dark_metal", x1 - f, x1, ya, yb, z0 + f, z1 - f, 0.06)
    ym = (y0 + y1) / 2
    for (za, zb, zs) in ((z0 + 0.04, z0 + 0.14, z0), (z1 - 0.14, z1 - 0.04, z1)):
        box(P, mat, x0 + 0.55, x1 - 0.55, y0 + 0.5, ym - 0.12, za, zb, 0.03)
        box(P, mat, x0 + 0.55, x1 - 0.55, ym + 0.12, y1 - 0.5, za, zb, 0.03)
        box(P, "dark_metal", x0 + f, x1 - f, ym - 0.1, ym + 0.1, za - 0.02, zb + 0.02, 0.02)
        box(P, "label_cream", x0 + 0.9, x0 + 2.5, y1 - 1.05, y1 - 0.6, min(za, zb) - 0.03, max(za, zb) + 0.03, 0.0)
    for (xa, xb) in ((x0 - 0.02, x0 + 0.08), (x1 - 0.08, x1 + 0.02)):   # handles on the ends
        box(P, "dark_metal", xa, xb, ym + 0.2, ym + 0.45, (z0 + z1) / 2 - 0.7, (z0 + z1) / 2 + 0.7, 0.03)

def hard_case(P, x0, x1, y0, y1, z0, z1):
    ym = y0 + (y1 - y0) * 0.58
    box(P, "case_dark", x0 + 0.05, x1 - 0.05, y0, ym, z0 + 0.05, z1 - 0.05, 0.22, 2)
    box(P, "case_dark", x0 + 0.08, x1 - 0.08, ym, y1, z0 + 0.08, z1 - 0.08, 0.3, 2)
    box(P, "dark_metal", x0, x1, ym - 0.12, ym + 0.12, z0, z1, 0.04)
    for t in (0.22, 0.5, 0.78):
        x = x0 + (x1 - x0) * t
        box(P, "case_dark", x - 0.14, x + 0.14, y1 - 0.06, y1, z0 + 0.4, z1 - 0.4, 0.04)
    for t in (0.25, 0.75):
        x = x0 + (x1 - x0) * t
        for (za, zb) in ((z0 - 0.02, z0 + 0.1), (z1 - 0.1, z1 + 0.02)):
            box(P, "drum_olive", x - 0.3, x + 0.3, ym - 0.45, ym + 0.35, za, zb, 0.04)
    for (za, zb) in ((z0 + 0.02, z0 + 0.08), (z1 - 0.08, z1 - 0.02)):
        box(P, "label_cream", (x0 + x1) / 2 - 0.8, (x0 + x1) / 2 + 0.8, y0 + 0.8, y0 + 1.25, za, zb, 0.0)

def cover_block(P, c, k):
    _, _, x0, x1, z0, z1, top = c
    crate_rect(P, x0, x1, FY, FY + 3.6, z0, z1, "crate_green", k)
    if k % 2 == 0:
        crate_rect(P, x0 + 0.0, x1 - 0.0, FY + 3.6, top, z0, z1, "crate_green", k)
    else:
        hard_case(P, x0, x1, FY + 3.6, top, z0, z1)

def cover_pillar(P, c, k):
    _, _, x0, x1, z0, z1, top = c
    box(P, "trim_metal", x0, x1, FY, FY + 1.6, z0, z1, 0.12)
    poly = chamfer_poly([(x0 + 0.15, FY + 1.6, z0 + 0.15), (x1 - 0.15, FY + 1.6, z0 + 0.15), (x1 - 0.15, FY + 1.6, z1 - 0.15), (x0 + 0.15, FY + 1.6, z1 - 0.15)], 0.45)
    prism(P, "wall_light", poly[::-1], (0, top - 1.9 - FY - 1.6, 0))
    box(P, "band_olive", x0 + 0.02, x1 - 0.02, FY + 7.1, FY + 9.9, z0 + 0.02, z1 - 0.02, 0.1)
    for y in (FY + 6.85, FY + 9.85):
        box(P, "trim_metal", x0, x1, y, y + 0.3, z0, z1, 0.05)
    box(P, "wall_dark", x0 + 0.08, x1 - 0.08, 618.0, 619.2, z0 + 0.08, z1 - 0.08, 0.08)
    box(P, "trim_metal", x0, x1, top - 1.9, top - 1.2, z0, z1, 0.1)
    box(P, "wall_dark", x0 + 0.1, x1 - 0.1, top - 1.2, top, z0 + 0.1, z1 - 0.1, 0.12)
    xm, zm = (x0 + x1) / 2, (z0 + z1) / 2
    for zf, sg in ((z0, -1), (z1, 1)):     # number plates (SurfaceGui A1..D6)
        za, zb = sorted((zf, zf + sg * 0.06))
        box(P, "label_cream", xm - 1.1, xm + 1.1, FY + 10.6, FY + 11.8, za, zb, 0.02)
    for xf, sg in ((x0, -1), (x1, 1)):     # capsule lights on the x faces
        wall_light(Wall("z", xf, sg), zm, 0.0, FY + 14.2, piece="T_Lights")

def cover_wall(P, c, k):
    _, _, x0, x1, z0, z1, top = c
    xm = (x0 + x1) / 2
    box(P, "trim_metal", x0, x1, FY, FY + 0.8, z0, z1, 0.1)
    for (a, b) in ((x0 + 0.05, xm - 0.1), (xm + 0.1, x1 - 0.05)):
        box(P, "range_grey", a, b, FY + 0.8, top - 0.6, z0 + 0.12, z1 - 0.12, 0.15, 2)
    box(P, "dark_metal", xm - 0.12, xm + 0.12, FY + 0.8, top - 0.6, z0 + 0.25, z1 - 0.25, 0.02)
    box(P, "band_olive", x0 + 0.08, x1 - 0.08, FY + 7.1, FY + 9.9, z0 + 0.06, z1 - 0.06, 0.08)
    for y in (FY + 6.85, FY + 9.85):
        box(P, "trim_metal", x0 + 0.04, x1 - 0.04, y, y + 0.3, z0 + 0.03, z1 - 0.03, 0.05)
    box(P, "trim_metal", x0, x1, top - 0.6, top, z0, z1, 0.1)
    for x in (x0 + 2.0, x1 - 2.0):          # lifting eyes
        box(P, "dark_metal", x - 0.35, x + 0.35, top - 0.05, top + 0.0, (z0 + z1) / 2 - 0.35, (z0 + z1) / 2 + 0.35, 0.02)
    for zf, sg in ((z0, -1), (z1, 1)):
        za, zb = sorted((zf + sg * (-0.12), zf + sg * (-0.06)))
        box(P, "label_cream", xm - 3.6, xm - 1.4, FY + 3.2, FY + 4.0, za, zb, 0.0)
        for xx in (x0 + 1.1, x1 - 1.1):     # forklift pockets
            box(P, "void", xx - 0.6, xx + 0.6, FY + 0.15, FY + 0.6, min(za, zb) - 0.02, max(za, zb), 0.0)

def cover_low(P, c, k):
    _, _, x0, x1, z0, z1, top = c
    t = z1 - z0; zc = (z0 + z1) / 2
    if t > 2.0:      # concrete jersey barriers, two 2.5 units end to end, hazard cap strip
        xm = (x0 + x1) / 2
        for (a, b) in ((x0, xm - 0.06), (xm + 0.06, x1)):
            pts = [(a, FY, z0), (a, FY, z1), (a, FY + 0.4, z1), (a, FY + 1.15, zc + 0.3 * t), (a, top - 0.15, zc + 0.24 * t),
                   (a, top, zc + 0.19 * t), (a, top, zc - 0.19 * t), (a, top - 0.15, zc - 0.24 * t), (a, FY + 1.15, zc - 0.3 * t), (a, FY + 0.4, z0)]
            prism(P, "wall_light", pts, (b - a, 0, 0))
            box(P, "hazard", a + 0.15, b - 0.15, top - 0.03, top + 0.01, zc - 0.17 * t, zc + 0.17 * t, 0.0)
            box(P, "dark_metal", a + 0.3, b - 0.3, FY, FY + 0.12, z0 - 0.02, z1 + 0.02, 0.02)
            box(P, "label_cream", (a + b) / 2 - 0.5, (a + b) / 2 + 0.5, FY + 0.6, FY + 0.95, z0 - 0.03, z0 + 0.02, 0.0)
        box(P, "trim_metal", xm - 0.25, xm + 0.25, top - 0.9, top - 0.1, zc - 0.22 * t, zc + 0.22 * t, 0.04)   # joint pin plate
    else:            # steel shield barrier: frame, corrugated infill, olive stripe, runners
        box(P, "trim_metal", x0, x0 + 0.3, FY, top, z0 + 0.1, z1 - 0.1, 0.06)
        box(P, "trim_metal", x1 - 0.3, x1, FY, top, z0 + 0.1, z1 - 0.1, 0.06)
        box(P, "trim_metal", x0, x1, top - 0.3, top, z0 + 0.1, z1 - 0.1, 0.06)
        box(P, "door_leaf", x0 + 0.3, x1 - 0.3, FY + 0.4, top - 0.3, z0 + 0.3, z1 - 0.3, 0.05)
        box(P, "band_olive", x0 + 0.3, x1 - 0.3, FY + 2.0, FY + 2.45, z0 + 0.25, z1 - 0.25, 0.03)
        for xx in (x0 + 0.15, x1 - 0.15):
            box(P, "dark_metal", xx - 0.3, xx + 0.3, FY, FY + 0.25, z0, z1, 0.04)
        box(P, "label_cream", (x0 + x1) / 2 - 0.6, (x0 + x1) / 2 + 0.6, FY + 1.0, FY + 1.4, z0 + 0.24, z1 - 0.24, 0.0)

def build_t_cover():
    fn = {"Block": cover_block, "Pillar": cover_pillar, "Wall": cover_wall, "LowWall": cover_low}
    for k, c in enumerate(COVER):
        name, kind, x0, x1, z0, z1, top = c
        xbox(name, x0, x1, FY, top, z0, z1, replaces=name)
        fn[kind]("T_Cover" + name[0], c, k)

# ================================================================== SHOWROOM (Kit menu camera set; never walked)
SY = 400.0
CAMP = (0.0, 407.5, -5.0); DISP = (0.0, 406.0, 8.0)   # CameraPoint / DisplayPoint (survey; camera looks at the item, FOV 40)
BENCH = (-8.0, 8.0, 5.0, 12.0, 404.2)                  # BenchTop x / z footprint and top (fake-shadow plane)
SRS = dict(base=SY, body_top=416.0, dark=(416.0, 418.0), upper=(418.0, 423.0), corn=(423.0, 427.0), top=427.0,
           prof=[(0.0, 423.0), (0.6, 424.2), (1.4, 425.4), (2.0, 426.2), (2.0, 427.0)])

def shifted(dy, fn, piece, *a, **k):
    """Run a floor-0 helper (rooms2 wall_rack etc.) into a temp piece, lift it by dy, merge into piece."""
    fn(a[0], "__TMP", *a[1:], **k)          # helpers take (W, piece, ...)
    for key in [kk for kk in ACC if kk[0] == "__TMP"]:
        bm = ACC.pop(key)
        bmesh.ops.translate(bm, verts=bm.verts, vec=(0.0, dy, 0.0))
        me = bpy.data.meshes.new("__tmp"); bm.to_mesh(me); bm.free()
        acc(piece, key[1]).from_mesh(me)
        bpy.data.meshes.remove(me)

def pendant(piece, x, y, z):
    lathe(piece, "trim_metal", [(0.25, 1.1), (0.45, 1.0), (0.95, 0.15), (1.0, 0.0), (0.88, 0.0), (0.38, 0.9), (0.2, 1.1)], cx=x, cz=z, seg=32, y0=y)
    cyl(piece, "neon_lamp", x, z, 0.82, y + 0.02, y + 0.12, seg=32, bev=0.0)
    rod(piece, "dark_metal", (x, y + 1.1, z), (x, 427.0, z), 0.05, 6)
    cyl(piece, "dark_metal", x, z, 0.3, 426.6, 427.0, seg=12, bev=0.03)

def build_showroom():
    F = "SR_Floor"; B = "SR_Backdrop"; St = "SR_Stage"; L = "SR_Lights"; Sh = "SR_Shell"; Pr = "SR_Props"
    floor_grid(F, -31.0, 31.0, -19.0, 35.0, [-28.5, -19.0, -9.5, 0.0, 9.5, 19.0, 28.5], [-16.5, -7.0, 2.0, 11.0, 20.0, 32.5], SY)
    # dais under the bench: metal disc, olive Neon halo on it, cream Neon ring on the floor round it
    lathe(St, "plate_metal", [(0.0, 0.0), (10.3, 0.0), (10.5, 0.12), (10.5, 0.25), (10.35, 0.35), (0.0, 0.35)], cx=0.0, cz=8.5, seg=96, y0=SY)
    ring3(St, "neon_olive", 0.0, 8.5, 9.2, 9.45, SY + 0.35, gaps_deg=(0, 180), half_gap=6)
    ring3("SR_Lines", "neon_cream", 0.0, 8.5, 10.7, 10.95, SY, gaps_deg=(90, 270), half_gap=10)
    # bench (table top = BenchTop top 404.2, flat for the fake shadow)
    bx0, bx1, bz0, bz1, btop = BENCH
    box(St, "bench_top", bx0, bx1, btop - 0.55, btop, bz0, bz1, 0.12, 2)
    box(St, "trim_metal", bx0 - 0.1, bx1 + 0.1, btop - 0.75, btop - 0.5, bz0 - 0.1, bz1 + 0.1, 0.06)
    box(St, "neon_cream", bx0 + 0.4, bx1 - 0.4, btop - 0.9, btop - 0.78, bz0 + 0.0, bz0 + 0.1, 0.0)     # underglow, front
    box(St, "wall_kick", bx0 + 0.6, bx1 - 0.6, SY + 0.95, btop - 0.75, bz0 + 0.6, bz1 - 0.6, 0.15, 2)
    box(St, "band_olive", bx0 + 0.5, bx1 - 0.5, SY + 1.9, SY + 2.5, bz0 + 0.5, bz1 - 0.5, 0.06)
    box(St, "trim_metal", bx0 + 0.3, bx1 - 0.3, SY + 0.35, SY + 0.95, bz0 + 0.3, bz1 - 0.3, 0.1)
    for x in (-3.7, 3.7):
        box(St, "dark_metal", x - 0.08, x + 0.08, SY + 0.95, btop - 0.75, bz0 + 0.55, bz0 + 0.62, 0.0)
    box("SR_Signs", "label_cream", -2.2, 2.2, SY + 2.8, SY + 3.3, bz0 + 0.55, bz0 + 0.6, 0.0)
    # backdrop wall (face z 33): banded wings + central display bay x -13..13
    Wb = Wall("x", 33.0, -1)
    for (a, b) in ((-33.0, -13.0), (13.0, 33.0)):
        bandwall(Wb, B, a, b, SRS)
        plates(Wb, B, a + (2.0 if a < 0 else 0.2), b - (0.2 if a < 0 else 2.0), 410.6, 415.6, 0.0, 0.3, cols=2)
    for sg in (-1, 1):
        a, b = sorted((sg * 11.0, sg * 13.4))
        Wb.box(B, "wall_light", a, b, SY, 424.0, -2.0, 1.4, 0.25, 2)
        Wb.box(B, "trim_metal", a - 0.05, b + 0.05, SY, SY + 1.6, -2.0, 1.6, 0.1)
        Wb.box(B, "band_olive", a - 0.03, b + 0.03, SY + 7.1, SY + 9.9, -2.0, 1.55, 0.08)
        wall_light(Wb, sg * 12.2, 1.4, SY + 14.2, piece=L)
        a2, b2 = sorted((sg * 9.4, sg * 10.4))       # vertical light slot
        Wb.box(B, "trim_metal", a2, b2, SY + 0.9, 417.2, -0.6, -0.35, 0.04)
        a3, b3 = sorted((sg * 9.65, sg * 10.15))
        Wb.box(L, "neon_lamp", a3, b3, SY + 1.2, 416.9, -0.35, -0.27, 0.0)
        for s in (sg * 16.0, sg * 30.0):
            pier3(Wb, B, s, SY, 424.0, light_y=None) if abs(s) < 29 else None
    Wb.box(B, "sign_board", -11.0, 11.0, SY, 419.0, -2.0, -0.6, 0.1)       # recessed dark back panel
    for i in range(5):                                                      # 2 x 4 display tiles (RIVALS display-wall rhythm)
        for j in range(9):
            s0 = -9.2 + i * 3.7; y0 = SY + 0.7 + j * 1.85
            Wb.box(B, "beam_metal", s0 + 0.06, s0 + 3.64, y0 + 0.06, y0 + 1.79, -0.6, -0.48, 0.04)
    Wb.box(B, "wall_light", -13.4, 13.4, 419.0, 424.0, -2.0, 1.4, 0.25, 2)  # header
    Wb.box(B, "band_olive", -13.4, 13.4, 419.8, 421.4, -2.0, 1.55, 0.08)
    Wb.box(L, "neon_olive", -11.0, 11.0, SY, SY + 0.22, -0.6, -0.4, 0.0)    # floor cove line in the bay
    for (a, b, c, d) in ((-11.0, 11.0, 418.75, 419.0), (-11.0, -10.75, SY, 419.0), (10.75, 11.0, SY, 419.0)):
        Wb.box(L, "neon_olive", a, b, c, d, 0.0, 0.12, 0.0)
    sign_board("SR_Signs", Wb, -6.0, 6.0, 412.4, 414.8, d=-0.48)
    Wb.box("SR_Signs", "label_cream", -4.8, 4.8, 412.85, 414.35, 0.3, 0.36, 0.0)
    # racks + kit either side (frame edges)
    for (s0, s1) in ((14.6, 21.6), (-21.6, -14.6)):
        shifted(SY, wall_rack, Pr, Wb, s0, s1)
    prop_longcase(Pr, -18.2, SY, 27.6, True); ammo_can(Pr, -19.6, SY + 2.3, 27.6); ammo_can(Pr, -17.6, SY + 2.3, 27.8)
    prop_crate(Pr, 18.4, SY, 27.6, 3.0); prop_crate(Pr, 21.6, SY, 27.9, 3.0); ammo_can(Pr, 18.4, SY + 3.0, 27.6, False)
    # side and front walls (never in frame at FOV 40 but close the set for the 70 deg captures)
    for (W, s0, s1, ps) in ((Wall("z", -31.0, +1), -19.0, 35.0, [0.0, 18.0]), (Wall("z", 31.0, -1), -19.0, 35.0, [0.0, 18.0]),
                            (Wall("x", -19.0, +1), -33.0, 33.0, [-16.0, 0.0, 16.0])):
        bandwall(W, Sh, s0, s1, SRS)
        for s in ps:
            pier3(W, Sh, s, SY, 424.0, light_y=SY + 14.2, lights=L)
    room_ceiling("SR_Ceiling", L, -31.0, 31.0, -19.0, 35.0, 427.0, [-12.0, 12.0], [8.0, 22.0], 1.8, [-21.0, 21.0])
    # light homes: Pendant1-4, Fill, KeyLight (the Parts stay; these are their fixtures)
    for (x, y, z) in ((4.0, 413.5, 8.5), (-4.0, 413.5, 8.5), (-20.0, 413.5, 12.0), (20.0, 413.5, 11.0)):
        pendant(L, x, y, z)
    lamp_box(L, 0.0, 418.6, 18.0, 3.0, 1.2)
    rod(L, "dark_metal", (0.0, 419.3, 18.0), (0.0, 427.0, 18.0), 0.06, 6)
    lamp_box(L, -3.0, 414.8, -1.0, 1.4, 1.4)
    rod(L, "dark_metal", (-3.0, 415.5, -1.0), (-3.0, 427.0, -1.0), 0.06, 6)

# ------------------------------------------------------------------ markers
def build_markers4():
    box("K_Scale4", "label_cream", -5, 5, 115, 125, -5, 5, 0.0)
    box("K_Marker4", "neon_olive", 15, 25, 115, 117, -1, 1, 0.0)
    box("K_Marker4", "neon_olive", 15, 17, 117, 123, -1, 1, 0.0)
    box("K_Marker4", "neon_olive", 15, 17, 115, 117, 1, 5, 0.0)

# ------------------------------------------------------------------ collections, manifest
def coll_for(piece):
    if piece.startswith("K_"):
        return "R4_Markers"
    if piece.startswith("X_"):
        return "R4_Clip"
    if piece.startswith("SR_"):
        return "R4_Showroom"
    if piece.startswith("T_Cover"):
        return "R4_Cover"
    return "R4_Training"

def manifest4(stats):
    out = []
    for st in stats:
        mat = st["material"]; piece = st["piece"]
        base, var = studio_fields(mat) if mat not in ("clip", "range_grey", "bench_top") else ("SmoothPlastic", "")
        e = dict(st)
        e["rgb_kit"] = list(st["rgb"])
        e["rgb"] = list(STUDIO_RGB3.get(mat, st["rgb"]))
        e["material_studio"] = base
        e["variant"] = var
        e["variant_folder"] = "MaterialService.TacHub1" if var else ""
        is_clip = piece.startswith("X_")
        e["can_collide"] = is_clip
        e["can_query"] = is_clip            # training clip boxes ARE the cover + bullet blockers
        e["can_touch"] = False
        e["not_cover"] = not is_clip        # every visual mesh gets the NotCover attribute
        e["collision_fidelity"] = "Box"
        e["cast_shadow"] = not (mat.startswith("neon") or mat in ("glass", "clip"))
        e["transparency"] = 0.6 if mat == "glass" else (1.0 if mat == "clip" else 0.0)
        e["texture_overlay"] = {"hazard": "TX_hazard_stripe 4x1 Top", "range_grey": "TX_overlay_grid 5x5 black T0.75 all faces"}.get(mat, "")
        e["replaces"] = REPLACES.get(piece, "")
        e["area"] = "Showroom" if piece.startswith("SR_") else ("Marker" if piece.startswith("K_") else "Training")
        out.append(e)
    return out

R4_COLLS = ("R4_Training", "R4_Cover", "R4_Showroom", "R4_Markers", "R4_Clip")
def clear_rooms4():
    for cn in R4_COLLS:
        c = bpy.data.collections.get(cn)
        if c:
            for ob in list(c.objects):
                me = ob.data
                bpy.data.objects.remove(ob, do_unlink=True)
                if me and me.users == 0:
                    bpy.data.meshes.remove(me)

# 2026-10-15 scope change (Edward): Training is built Parts-first in Studio by another agent (RIVALS' range is Parts).
# The T_* / X_T_* builders above stay as a reference (BUILD_TRAINING = True builds them into R4_Training/R4_Cover/R4_Clip),
# but rooms4.fbx is the SHOWROOM only.
BUILD_TRAINING = False

def build_rooms4():
    clear_rooms4()
    ACC.clear(); REPLACES.clear()
    if BUILD_TRAINING:
        make_range_grey()
        build_t_walls(); build_t_dividers(); build_t_hub(); build_t_floor(); build_t_ceiling(); build_t_cover()
    build_showroom(); build_markers4()
    stats = finalize()
    man = manifest4(stats)
    with open(KIT + "rooms4_manifest.json", "w") as f:
        json.dump(man, f, indent=1)
    return man

if __name__ == "__main__" or True:
    MAN = build_rooms4()
