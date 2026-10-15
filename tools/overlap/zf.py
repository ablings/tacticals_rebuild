import json, collections, sys
PR=json.load(open("kitprims.json"))
S={}
for l in open("sb.txt"):
    f=l.strip().split("|")
    if len(f)>=16: S[f[1]]=dict(col=f[13],mat=f[14],var=f[15],T=float(f[8]))
B=[]
for q in PR:
    if q["t"]!="box": continue
    k=q["p"]+"__"+q["m"]
    if q["p"].startswith("K_") or q["m"]=="clip": continue
    st=S.get(k)
    if not st or st["T"]>=1: continue
    lo,hi=list(q["lo"]),list(q["hi"])
    if q["p"].startswith("SR_Stage"): lo[1]+=0.2; hi[1]+=0.2
    B.append(dict(k=k,p=q["p"],m=q["m"],lo=lo,hi=hi,bev=min(q["bev"],min(hi[i]-lo[i] for i in range(3))*0.45),look=(st["col"],st["mat"],st["var"])))
print("boxes",len(B))
EPS=float(sys.argv[1]) if len(sys.argv)>1 else 0.03
def inside(pt,b,m=1e-4):
    return all(b["lo"][i]+m<pt[i]<b["hi"][i]-m for i in range(3))
# spatial grid for occlusion
G=collections.defaultdict(list); CS=8.0
for idx,b in enumerate(B):
    for gx in range(int(b["lo"][0]//CS),int(b["hi"][0]//CS)+1):
        for gy in range(int(b["lo"][1]//CS),int(b["hi"][1]//CS)+1):
            for gz in range(int(b["lo"][2]//CS),int(b["hi"][2]//CS)+1):
                G[(gx,gy,gz)].append(idx)
def occluded(pt,skip):
    for idx in G.get(tuple(int(pt[i]//CS) for i in range(3)),[]):
        if idx in skip: continue
        if inside(pt,B[idx]): return True
    return False
res=[]
for ax in range(3):
    o=[i for i in range(3) if i!=ax]
    for side in (0,1):
        key="lo" if side==0 else "hi"
        bins=collections.defaultdict(list)
        for idx,b in enumerate(B): bins[round(b[key][ax]/0.1)].append(idx)
        for bk,lst in bins.items():
            cand=lst+bins.get(bk+1,[])
            for ii,a in enumerate(lst):
                A=B[a]
                for c in cand:
                    if c<=a and c in lst: continue
                    C=B[c]
                    if A["k"]==C["k"]: continue
                    d=abs(A[key][ax]-C[key][ax])
                    if d>EPS: continue
                    r0=[max(A["lo"][j]+A["bev"],C["lo"][j]+C["bev"]) for j in o]; r1=[min(A["hi"][j]-A["bev"],C["hi"][j]-C["bev"]) for j in o]
                    if r0[0]>=r1[0]-0.01 or r0[1]>=r1[1]-0.01: continue
                    area=(r1[0]-r0[0])*(r1[1]-r0[1])
                    # sample 5 points of the overlap, offset outward
                    vis=0
                    for (u,v) in ((0.5,0.5),(0.1,0.1),(0.9,0.1),(0.1,0.9),(0.9,0.9)):
                        pt=[0,0,0]; pt[ax]=max(A[key][ax],C[key][ax])+0.03 if side else min(A[key][ax],C[key][ax])-0.03
                        pt[o[0]]=r0[0]+(r1[0]-r0[0])*u; pt[o[1]]=r0[1]+(r1[1]-r0[1])*v
                        if not occluded(pt,{a,c}): vis+=1
                    if vis==0: continue
                    same=A["look"]==C["look"]
                    res.append(dict(ax="xyz"[ax]+("+" if side else "-"),plane=round(A[key][ax],3),d=round(d,3),a=A["k"],b=C["k"],
                        ra=[round(x,2) for x in r0],rb=[round(x,2) for x in r1],area=round(area,2),vis=vis,same=same,
                        alo=[round(x,2) for x in A["lo"]],ahi=[round(x,2) for x in A["hi"]],blo=[round(x,2) for x in C["lo"]],bhi=[round(x,2) for x in C["hi"]]))
json.dump(res,open("zf.json","w"),indent=0)
print("pairs",len(res),"diff look",sum(1 for r in res if not r["same"]))
agg=collections.Counter()
for r in res:
    if r["same"]: continue
    agg[(r["a"],r["b"])]+=r["area"]
for (a,b),v in sorted(agg.items(),key=lambda t:-t[1])[:150]: print(round(v,1),a,b)
