import json,sys,subprocess,os,shutil,hashlib
SID="1def7df9-d52b-46f2-8fb1-44d8a582404e"; CX,CZ,FY=-84.2,7.5,0.4
def call(tool,args):
    open('_a.json','w').write(json.dumps(args))
    env=dict(os.environ,MCP_WARMUP='3',PYTHONIOENCODING='utf-8')
    r=subprocess.run([sys.executable,'mcp.py','call',tool,'_a.json'],capture_output=True,text=True,encoding='utf-8',errors='replace',env=env)
    return r.stdout+r.stderr[-500:]
def w(e,h,n): return (CX-e, FY+h, CZ+n)
cams=json.load(open(sys.argv[1]))
os.makedirs('caps',exist_ok=True)
for c in cams:
    p=w(*c['eye']); t=w(*c['at'])
    code=f"""local cam=workspace.CurrentCamera cam.CameraType=Enum.CameraType.Scriptable cam.FieldOfView={c.get('fov',70)}
cam.CFrame=CFrame.lookAt(Vector3.new({p[0]},{p[1]},{p[2]}),Vector3.new({t[0]},{t[1]},{t[2]})) cam.Focus=CFrame.new({t[0]},{t[1]},{t[2]}) game.Selection:Set({{}}) return 'ok'"""
    print(c['name'],call('execute_luau',{"code":code,"studio_id":SID,"datamodel_type":"Edit"}).strip()[:80])
    hs=[]
    for k in range(4):
        out=call('screen_capture',{"studio_id":SID,"capture_id":c['name']})
        img=[l.split(' ',1)[1] for l in out.splitlines() if l.startswith('IMAGE')]
        if not img: print('  no image',out[:300]); break
        h=hashlib.md5(open(img[0],'rb').read()).hexdigest(); hs.append(h)
        shutil.copy(img[0],f"caps/{c['name']}.png")
        if len(hs)>=2 and hs[-1]==hs[-2]: break
    print('  frames',len(hs),'stable' if len(hs)>=2 and hs[-1]==hs[-2] else 'UNSTABLE')
