import json
SB={}
for l in open("sb.txt"):
    f=l.strip().split("|")
    if len(f)>=16: SB[f[1]]=dict(pos=[float(x) for x in f[2:5]],size=[float(x) for x in f[5:8]])
R=json.load(open("zf_vis.json"))
F=[]  # (mesh, axis, anchor, k, t, why)
def scale_anchor(m,ax,anchor,plane,newplane,why):
    k=(newplane-anchor)/(plane-anchor); F.append((m,ax,anchor,k,0.0,why))
def tr(m,ax,t,why): F.append((m,ax,0.0,1.0,t,why))
# 1 hub west wall + Duels door portal: back face -95 -> -94.96, hub face -90 fixed
for m in SB:
    if (m.startswith("H_WallW__") or m.startswith("H_DuelsDoor__")):
        nb=-94.93 if m.startswith("H_DuelsDoor__") else -94.96
        lo=SB[m]["pos"][0]-SB[m]["size"][0]/2
        if abs(lo+95)<0.02: scale_anchor(m,0,-90.0,-95.0,nb,"hub W wall back face z-fought the Duels east cladding at x -95")
# 2 decor shrink toward centre on the opening axis (inner coplanar face moves 0.04 into the opening)
SHRINK={ # mesh: (axis, centre, inner plane |coord| from centre, step)
 "H_TunnelPortal__wall_light":(2,0.0,11.0,0.04),"H_TunnelPortal__band_olive":(2,0.0,11.0,0.07),"H_TunnelPortal__trim_metal":(2,0.0,11.0,0.07),
 "H_GateN__band_olive":(0,0.0,5.7,0.04),"H_GateS__band_olive":(0,0.0,5.7,0.04),
 "H_DuelsDoor__band_olive":(2,0.0,5.8,0.04),
}
for m,(ax,c,p,s) in SHRINK.items(): scale_anchor(m,ax,c,c+p,c+p-s,"coplanar with its wall on the opening side")
json.dump(F,open("fixes.json","w"),indent=0)
for f in F: print(f[0],f[1],round(f[3],6))
def sh(m,ax,p,newp,why="decor flush with its wall: inner face moved into the opening"): scale_anchor(m,ax,0.0,p,newp,why)
def gr(m,ax,p,newp,why="decor flush with its wall ends: grown to stand proud"): scale_anchor(m,ax,0.0,p,newp,why)
for m in ["S_Door__band_olive","A_Door__band_olive"]: gr(m,0,9.8,9.84)
gr("SR_Backdrop__band_olive",0,13.4,13.44)
sh("D_Door__band_olive",2,5.5,5.46); sh("D_Door__trim_metal",2,5.5,5.43)
sh("D_West__band_olive",2,4.5,4.46); sh("D_West__trim_metal",2,4.5,4.43)
tr("D_West__band_olive",0,-0.03,"Pass-side face flush with wall"); tr("D_West__trim_metal",0,-0.06,"Pass-side face flush with wall/band")
sh("D_Pass__band_olive",2,4.5,4.46)
sh("E_Portal__band_olive",2,11.0,10.96); sh("E_Portal__trim_metal",2,11.0,10.93); tr("E_Portal__trim_metal",0,-0.04,"flush with band at x 105")
sh("H_Tunnel__band_olive",2,11.0,10.93); sh("H_Tunnel__door_leaf",2,11.2,11.16)
T=[("H_BaysN__door_leaf",2,-0.04),("H_BaysS__door_leaf",2,0.04),("H_BaysN__label_cream",2,-0.03),("H_BaysS__label_cream",2,0.03),
 ("H_Catwalks__trim_metal",1,0.03),("H_Catwalks__beam_metal",1,-0.04),("H_Skylight__neon_olive",1,0.03),("D_Lines__neon_cream",1,0.03),
 ("D_Lines__neon_olive",1,0.03),("D_Base__wall_dark",1,-0.04),("E_Mouth__wall_light",1,0.04),("E_Mouth__band_olive",1,-0.04),
 ("S_Displays__trim_metal",1,0.03),("H_GateN__trim_metal",1,-0.04),("H_GateS__trim_metal",1,-0.04),("S_Door__trim_metal",1,-0.04),
 ("A_Door__trim_metal",1,-0.04),("D_Door__trim_metal",1,-0.04),("E_Portal__trim_metal",1,-0.04),("D_Pass__band_olive",1,-0.04),
  ("H_Stairs__trim_metal",1,0.03),("E_Lines__neon_cream",1,0.02)]
for m,ax,t in T: tr(m,ax,t,"coplanar face offset")
json.dump(F,open("fixes.json","w"),indent=0)
print(len(F))
