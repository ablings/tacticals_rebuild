import json,collections
from vol import VOL, where
exec(open("zf.py").read().split("res=[]")[0].replace("print(\"boxes\",len(B))",""))
HOME={"H_Gate":["Hub","CorrN","CorrS"],"H_Tunnel":["Hub","Tunnel"],"H_DuelsDoor":["Hub","Duels"],"H_":["Hub"],
 "C_CorrN":["CorrN"],"C_CorrS":["CorrS"],"S_Door":["CorrN","Shop"],"A_Door":["CorrS","Armory"],"S_":["Shop"],"A_":["Armory"],
 "D_Door":["Duels"],"D_West":["Duels","Pass"],"D_Pass":["Pass","Deck"],"D_Deck":["Deck","Pass"],"D_Lines":["Duels","Pass","Deck"],"D_Base":["Deck","Pass"],"D_":["Duels"],
 "E_Portal":["Tunnel","Hangar"],"E_Mouth":["Hangar","Pad"],"E_Floor":["Hangar","Pad","Tunnel"],"E_Lines":["Hangar","Pad","Tunnel"],"E_Ceiling":["Hangar"],
 "E_Helipad":["Pad"],"E_PadWalls":["Pad"],"E_Rail":["Pad"],"E_Gear":["Pad","Hangar"],"E_":["Hangar"],"SR_":["Showroom"]}
def home(p):
    best=None
    for k,v in HOME.items():
        if p.startswith(k) and (best is None or len(k)>len(best[0])): best=(k,v)
    return best[1] if best else []
res=collections.defaultdict(lambda: collections.Counter())
ex=collections.defaultdict(list)
for idx,b in enumerate(B):
    hm=home(b["p"])
    for ax in range(3):
        o=[i for i in range(3) if i!=ax]
        for side in (0,1):
            for u in (0.1,0.3,0.5,0.7,0.9):
                for v in (0.1,0.3,0.5,0.7,0.9):
                    pt=[0,0,0]; pt[ax]=(b["hi"][ax]+0.03) if side else (b["lo"][ax]-0.03)
                    pt[o[0]]=b["lo"][o[0]]+(b["hi"][o[0]]-b["lo"][o[0]])*u; pt[o[1]]=b["lo"][o[1]]+(b["hi"][o[1]]-b["lo"][o[1]])*v
                    w=where(pt)
                    if not w or w in hm: continue
                    if occluded(pt,{idx}): continue
                    res[b["k"]][w]+=1
                    if len(ex[(b["k"],w)])<2: ex[(b["k"],w)].append([round(x,2) for x in pt])
for k,c in sorted(res.items()):
    for w,n in c.items(): print(k,w,n,ex[(k,w)])
