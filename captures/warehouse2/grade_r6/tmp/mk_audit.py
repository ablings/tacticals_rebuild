src = open('tools/wh2_audit.py', encoding='utf-8').read()
src = src.replace('json.dump({"built": r1, **r2}, open(os.path.join(ROOT, "notes", "warehouse2_audit.json"), "w"), indent=1)',
                  'json.dump({"built": r1, **r2}, open(os.path.join(ROOT, "captures", "warehouse2", "grade_r6", "audit_g6.json"), "w"), indent=1)')
src = src.replace('floorP.FilterDescendantsInstances = { map.CollisionProxies, map.CamSkin, map.Props, map.Shootables }',
                  'floorP.FilterDescendantsInstances = { map.CollisionProxies, map.CamSkin, map.Props, map.Shootables, workspace.Warehouse2Exterior }')
start = src.index('local seen, queue, reached = {}, { { -31, -50 } }, 0')
end_ = src.index('return HS:JSONEncode(out)')
flood = src[start:end_]
flood_fn = 'local function runFlood()\n' + flood.replace('out.flood = { reached = reached, bbox = box, outside = outside, capped = reached >= 40000 }', 'return { reached = reached, bbox = box, outside = outside, capped = reached >= 40000 }') + 'end\n'
control = '''out.flood = runFlood()
local door = map.Interactive.Door_S
local sh = door.Shutter
local cs, ccf = sh:GetAttribute("ClosedSize"), sh:GetAttribute("ClosedCFrame")
local h = cs.Y - door:GetAttribute("OpenHeight")
sh.Size = Vector3.new(cs.X, h, cs.Z); sh.CFrame = ccf + Vector3.new(0, (cs.Y - h) / 2, 0)
task.wait(0.2)
local c = runFlood()
out.control = { reached = c.reached, outside = #c.outside, bbox = c.bbox }
sh.Size = cs; sh.CFrame = ccf
'''
src = src[:start] + flood_fn + control + src[end_:]
src = src.replace('''    bad += s["hole"] + len(f["outside"]) + (1 if f["capped"] else 0)''', '''    print("CONTROL (south door rolled up in Play): reached", r2["control"]["reached"], "outside-hall cells (first 20 counted)", r2["control"]["outside"], r2["control"]["bbox"])
    bad += s["hole"] + len(f["outside"]) + (1 if f["capped"] else 0)''')
src = src.replace('ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))', 'ROOT = r"C:/Users/Shadow/Documents/tacticals_rebuild"')
src = src.replace("sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))", "sys.path.insert(0, r'C:/Users/Shadow/Documents/tacticals_rebuild/tools')")
open('captures/warehouse2/grade_r6/tmp/g_audit.py', 'w', encoding='utf-8').write(src)
