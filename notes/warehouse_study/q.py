import json,sys,subprocess,os
code=open(sys.argv[1],encoding='utf-8').read()
a={"code":code,"studio_id":"1def7df9-d52b-46f2-8fb1-44d8a582404e","datamodel_type":"Edit"}
if len(sys.argv)>2: a["datamodel_type"]=sys.argv[2]
open('_args.json','w',encoding='utf-8').write(json.dumps(a))
os.environ.setdefault('MCP_WARMUP','3')
r=subprocess.run([sys.executable,'mcp.py','call','execute_luau','_args.json'],capture_output=True,text=True,encoding='utf-8',errors='replace')
sys.stdout.write(r.stdout); sys.stderr.write(r.stderr[-2000:])
