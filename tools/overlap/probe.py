"""probe.py cam_x,y,z look_x,y,z [grid N] : cast rays through an N x N grid of the 70-deg view (screen 1284x793) and report hits.
or probe.py cam look u,v u,v ... with u,v pixel coords"""
import sys, json, subprocess, os, tempfile
cam=[float(a) for a in sys.argv[1].split(",")]; look=[float(a) for a in sys.argv[2].split(",")]
pts=[]
for a in sys.argv[3:]:
    u,v=a.split(","); pts.append([float(u),float(v)])
code=r'''
local cam=Vector3.new(%s) local look=Vector3.new(%s)
local px=%s
local cf=CFrame.lookAt(cam,look)
local W,H=1284,793
local fov=math.rad(70)
local th=math.tan(fov/2)
local changed={}
for _,d in workspace:GetDescendants() do if d:IsA("BasePart") and d.Transparency<0.99 and not d.CanQuery then d.CanQuery=true table.insert(changed,d) end end
local rp=RaycastParams.new() rp.FilterType=Enum.RaycastFilterType.Exclude
local out={}
for _,p in px do
  local x=(p[1]/W*2-1)*th*W/H local y=(1-p[2]/H*2)*th
  local dir=(cf.LookVector+cf.RightVector*x+cf.UpVector*y).Unit
  local excl={} local s={}
  for k=1,4 do
    rp.FilterDescendantsInstances=excl
    local r=workspace:Raycast(cam,dir*400,rp)
    if not r then break end
    local i=r.Instance
    if i.Transparency<0.99 then table.insert(s,string.format("%%s[%%s] d%%.2f n(%%.0f,%%.0f,%%.0f) at(%%.2f,%%.2f,%%.2f)",i:GetFullName():gsub("Workspace.LobbyMap.",""),i.Material.Name,r.Distance,r.Normal.X,r.Normal.Y,r.Normal.Z,r.Position.X,r.Position.Y,r.Position.Z)) end
    table.insert(excl,i)
  end
  table.insert(out,string.format("(%%d,%%d): ",p[1],p[2])..table.concat(s," || "))
end
for _,d in changed do d.CanQuery=false end
return table.concat(out,"\n")
'''%(",".join(map(str,cam)),",".join(map(str,look)),"{"+",".join("{%g,%g}"%(u,v) for u,v in pts)+"}")
fd,path=tempfile.mkstemp(suffix=".lua",dir="."); os.close(fd)
open(path,"w").write(code)
r=subprocess.run([sys.executable,"rl.py",path],capture_output=True,text=True,encoding="utf-8")
print(r.stdout.replace("\r","")); print(r.stderr[-500:]); os.remove(path)
