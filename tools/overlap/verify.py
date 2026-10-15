import json,subprocess
SB={}
for l in open("sb.txt"):
    f=l.strip().split("|")
    if len(f)>=16: SB[f[1]]=dict(pos=[float(x) for x in f[2:5]],size=[float(x) for x in f[5:8]])
F=json.load(open("fixes.json")); PR=json.load(open("kitprims.json"))
by={}
for f in F: by.setdefault(f[0],[]).append(f)
for q in PR:
    k=q["p"]+"__"+q["m"]
    for (m,ax,anc,kk,t,why) in by.get(k,[]):
        a=anc+(q["lo"][ax]-anc)*kk+t; b=anc+(q["hi"][ax]-anc)*kk+t
        q["lo"][ax],q["hi"][ax]=min(a,b),max(a,b)
json.dump(PR,open("kitprims_fixed.json","w"))
