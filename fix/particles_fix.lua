--[[ fix/particles_fix.lua : remove the particle effects RIVALS doesn't have (Edward 2026-10-15).
Tacticals_rebuild.rbxl (LOCAL copy) only. Report + inventory: notes/particles.md.
Rule (RIVALS: 388 ParticleEmitters + 94 Beams, every one bound to a purpose, no ambient particles):
  KEEP purpose-bound FX (queue pad holograms, the spawn-disc hologram, featured displays, Training dummy hit FX / extras,
  fixture light beams, exfil heli FX, weapon/gadget/explosion/prop FX created by gameplay scripts).
  REMOVE ambient FX (dust/motes, steam, random sparks, arcs, thrusters, free-floating god-ray shafts, the Duels sky beam).
Idempotent: originals kept in attributes PFX_OrigEnabled (per effect) and PFX_Tags (per tagged host); LobbyFX source backed up as
ServerStorage._RebuildRemoved.PFX_LobbyFX_Orig. Script edits are marked [PFX] and gated by workspace attribute PFX_AmbientFX
(absent/false = ambient pulses + sparks off). UNDO = true puts everything back.
Runner: python tools/run_luau.py fix/particles_fix.lua [UNDO]
]]
local UNDO = false --@UNDO
local CS = game:GetService("CollectionService")
local LM = workspace:WaitForChild("LobbyMap")
local FX = LM:WaitForChild("FX")
local log = {}
local function say(...) local t = {} for i = 1, select("#", ...) do t[i] = tostring((select(i, ...))) end table.insert(log, table.concat(t, " ")) end
local FXCLASS = {ParticleEmitter = true, Beam = true, Trail = true, Fire = true, Smoke = true, Sparkles = true}

-- removal targets: every effect under LobbyMap.FX except the spawn-disc hologram, plus the free-standing Duels sky beam
local function isRemoveTarget(d)
	if d:IsDescendantOf(FX) then
		local h = FX:FindFirstChild("Hologram")
		return not (h and d:IsDescendantOf(h))
	end
	local sky = LM:FindFirstChild("Duels") and LM.Duels:FindFirstChild("SkyBeam")
	return sky ~= nil and d:IsDescendantOf(sky)
end
local UNTAG = {"LobbySpark"} -- hosts of removed effects lose these tags so LobbyFX can't Emit() them

-- LobbyFX edits (plain-text find/replace; each new line carries [PFX])
local EDITS = {
	{'local map = workspace:WaitForChild("LobbyMap"); local FX = map:WaitForChild("FX")\n',
	 'local map = workspace:WaitForChild("LobbyMap"); local FX = map:WaitForChild("FX")\n'
	 .. 'local PFX_AMBIENT = workspace:GetAttribute("PFX_AmbientFX") == true -- [PFX] RIVALS has no ambient FX: walkway pulses + spark bursts only if workspace.PFX_AmbientFX = true (fix/particles_fix.lua)\n'},
	-- (block comments: these lines continue after the edit point, a line comment would swallow the rest)
	{'for _, z in {-6, 6} do for _, dir in {1, -1} do',
	 'for _, z in (PFX_AMBIENT and {-6, 6} or {}) --[[ [PFX] no floor pulses unless PFX_AmbientFX ]] do for _, dir in {1, -1} do'},
	{'local list = CSvc:GetTagged("LobbySpark")',
	 'local list = PFX_AMBIENT and CSvc:GetTagged("LobbySpark") or {} --[[ [PFX] no spark bursts unless PFX_AmbientFX ]]'},
}

local lobbyFX = game.StarterPlayer.StarterPlayerScripts:FindFirstChild("LobbyFX")
local store = game.ServerStorage:FindFirstChild("_RebuildRemoved")
if not store then store = Instance.new("Folder"); store.Name = "_RebuildRemoved"; store.Parent = game.ServerStorage end

if UNDO then
	local n, t = 0, 0
	for _, d in workspace:GetDescendants() do
		if FXCLASS[d.ClassName] and d:GetAttribute("PFX_OrigEnabled") ~= nil then
			d.Enabled = d:GetAttribute("PFX_OrigEnabled"); d:SetAttribute("PFX_OrigEnabled", nil); d:SetAttribute("PFX_Removed", nil); n += 1
		end
		local tags = d:GetAttribute("PFX_Tags")
		if tags then for tag in tags:gmatch("[^,]+") do CS:AddTag(d, tag); t += 1 end d:SetAttribute("PFX_Tags", nil) end
	end
	local bak = store:FindFirstChild("PFX_LobbyFX_Orig")
	if bak and lobbyFX then lobbyFX.Source = bak.Source; bak:Destroy(); say("UNDO: LobbyFX source restored") end
	workspace:SetAttribute("PFX_AmbientFX", nil)
	say("UNDO: restored", n, "effects,", t, "tags")
	return table.concat(log, "\n")
end

-- 1. effects
local removed, kept, unknown = 0, 0, {}
for _, d in workspace:GetDescendants() do
	if FXCLASS[d.ClassName] then
		if isRemoveTarget(d) then
			if d:GetAttribute("PFX_OrigEnabled") == nil then d:SetAttribute("PFX_OrigEnabled", d.Enabled) end
			d:SetAttribute("PFX_Removed", true)
			d.Enabled = false
			if d:IsA("ParticleEmitter") then d:Clear() end
			removed += 1
			-- host (parent part / attachment's part) loses its LobbyFX tags
			local host = d.Parent
			for _ = 1, 2 do
				if host and host ~= FX then
					local had = {}
					for _, tag in UNTAG do if CS:HasTag(host, tag) then table.insert(had, tag); CS:RemoveTag(host, tag) end end
					if #had > 0 then
						local prev = host:GetAttribute("PFX_Tags")
						host:SetAttribute("PFX_Tags", prev and (prev .. "," .. table.concat(had, ",")) or table.concat(had, ","))
						say("untagged", host:GetFullName(), table.concat(had, ","))
					end
					host = host.Parent
				end
			end
		else
			kept += 1
			if not (d:IsDescendantOf(LM.Duels) or (FX:FindFirstChild("Hologram") and d:IsDescendantOf(FX.Hologram))) then
				table.insert(unknown, d:GetFullName())
			end
		end
	end
end
say("effects: removed", removed, "kept", kept)
if #unknown > 0 then say("UNCLASSIFIED (kept, review):", table.concat(unknown, "; ")) end

-- 2. LobbyFX runtime ambience (floor pulses + spark bursts)
if lobbyFX then
	local src = lobbyFX.Source
	if src:find("[PFX]", 1, true) then
		say("LobbyFX already patched")
	else
		if not store:FindFirstChild("PFX_LobbyFX_Orig") then
			local bak = lobbyFX:Clone(); bak.Name = "PFX_LobbyFX_Orig"; bak.Disabled = true; bak.Parent = store
		end
		local ok = 0
		for _, e in EDITS do
			local a, b = src:find(e[1], 1, true)
			if a then src = src:sub(1, a - 1) .. e[2] .. src:sub(b + 1); ok += 1 else say("EDIT NOT FOUND:", e[1]:sub(1, 60)) end
		end
		if ok == #EDITS then lobbyFX.Source = src; say("LobbyFX patched:", ok, "edits") else say("LobbyFX NOT patched (", ok, "/", #EDITS, ")") end
	end
end
workspace:SetAttribute("PFX_AmbientFX", false)
return table.concat(log, "\n")
