"""[WRAPS] install (2026-10-21): python tools/wraps_install.py <studio_id> [UNDO]
- ReplicatedStorage.Modules.Shared.Config.WrapConfig  <- scripts/wraps/WrapConfig.lua
- ServerScriptService.WrapManager (Script)            <- scripts/wraps/WrapManager.server.lua
- tags every part of ReplicatedStorage.Repository.Weapons / .Melee templates: WrapChannel "A" (body) / "B" (details), WrapSkip (glass)
UNDO removes the two scripts and the tags. Never saves the place."""
import json, os, subprocess, sys, tempfile
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
CLI = os.path.expanduser(r"~\Documents\rivals_practice\mcpcli.py")

def src(rel):
    s = open(os.path.join(ROOT, rel), encoding='utf-8').read()
    assert ']==]' not in s
    return s

LUA = r'''
local UNDO = @@UNDO@@
local RS, SSS = game:GetService("ReplicatedStorage"), game:GetService("ServerScriptService")
local cfgFolder = RS.Modules.Shared.Config
local res = {}
-- details (B): trim / small parts; glass (skip); everything else is the body (A)
local B = { TriggerGuard = 1, Barrel = 1, LeftBarrel = 1, MuzzleBrake = 1, Suppressor = 1, Mag = 1, MagBase = 1, Rail = 1, Vent = 1,
	GasTube = 1, Optic = 1, OpticBase = 1, Scope = 1, ScopeBell = 1, ScopeEye = 1, ScopeMount = 1, ScopeRing = 1, TurretTop = 1,
	TurretSide = 1, BoltArm = 1, BoltKnob = 1, BipodLeg = 1, Hammer = 1, Cylinder = 1, ButtPad = 1, ButtPlate = 1, StockTube = 1,
	StockRail = 1, StockPad = 1, CockingKnob = 1, Tube = 1, Guard = 1, Knob = 1, Rim = 1 }
local SKIP = { Lens = 1, OpticLens = 1, Window = 1 }
local tagged = 0
for _, f in { RS.Repository.Weapons, RS.Repository.Melee } do
	for _, tool in f:GetChildren() do
		local melee = f.Name == "Melee"
		for _, p in tool:GetDescendants() do
			if p:IsA("BasePart") then
				if UNDO then p:SetAttribute("WrapChannel", nil) p:SetAttribute("WrapSkip", nil)
				else
					local skip = SKIP[p.Name] or p.Material == Enum.Material.Glass
					-- (a bat's barrel is its body; a gun's barrel is a detail)
					local isB = B[p.Name] and not (melee and p.Name == "Barrel")
					p:SetAttribute("WrapSkip", skip and true or nil)
					p:SetAttribute("WrapChannel", (not skip) and (isB and "B" or "A") or nil)
				end
				tagged += 1
			end
		end
	end
end
table.insert(res, "parts " .. tagged)
local function put(parent, name, class, source)
	local s = parent:FindFirstChild(name)
	if UNDO then if s then s:Destroy() end return name .. " removed" end
	if s and s.ClassName ~= class then s:Destroy() s = nil end
	s = s or Instance.new(class)
	s.Name = name
	local f, err = loadstring(source)
	assert(f, name .. " would not parse: " .. tostring(err))
	s.Source = source
	s.Parent = parent
	return name .. " ok"
end
table.insert(res, put(cfgFolder, "WrapConfig", "ModuleScript", [==[@@CFG@@]==]))
table.insert(res, put(SSS, "WrapManager", "Script", [==[@@MGR@@]==]))
return (UNDO and "UNDO " or "WRAPS ") .. table.concat(res, " | ")
'''

if __name__ == '__main__':
    if len(sys.argv) < 2: sys.exit(__doc__)
    code = (LUA.replace("@@UNDO@@", "true" if "UNDO" in sys.argv[2:] else "false")
            .replace("@@CFG@@", src('scripts/wraps/WrapConfig.lua')).replace("@@MGR@@", src('scripts/wraps/WrapManager.server.lua')))
    fd, p = tempfile.mkstemp(suffix='.json'); os.close(fd)
    json.dump({"studio_id": sys.argv[1], "datamodel_type": "Edit", "code": code}, open(p, 'w', encoding='utf-8'))
    r = subprocess.run([sys.executable, CLI, 'call', 'execute_luau', p], capture_output=True, text=True, encoding='utf-8',
                       env=dict(os.environ, PYTHONIOENCODING='utf-8', MCP_TIMEOUT='300'))
    os.remove(p)
    print(r.stdout.strip()[-1500:]); print(r.stderr[-800:], file=sys.stderr)
