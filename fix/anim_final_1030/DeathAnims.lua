-- ServerScriptService.Shared.DeathAnims [ANIMFINAL] (2026-10-30, systems session; installed by fix/anim_final_1030.lua)
-- Deaths by hit direction and cover state. PlayerRegistry (players) and BotManager (bots) call DeathAnims.Play on Died
-- BEFORE their ragdoll; it plays the death clip on the body's Animator (the server plays it: everyone sees it) and returns
-- how long to wait before the ragdoll takes over (0 = at once, the old behaviour, e.g. no clip made yet).
--   headshot kill (LastHitZone Head, a gun)  -> DeathHeadshot
--   explosion kill (AnimFinalConfig.Hits.StaggerKinds) -> DeathExplosion
--   in cover (character attribute CoverState) -> DeathSide (a wall at your back: crumple)
--   else by the hit's direction relative to the body's facing: from the front -> DeathFromFront (thrown back),
--   from behind -> DeathFromBehind (falls forward), from a side -> DeathSide
-- The hit's direction: humanoid attribute LastHitFrom (Vector3, set where the damage is applied), else the attacker's root.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DeathAnims = {}

local function lib()
	local shared = ReplicatedStorage:FindFirstChild("Modules") and ReplicatedStorage.Modules:FindFirstChild("Shared")
	local m = shared and shared:FindFirstChild("AnimLib")
	if not m then return nil end
	local ok, L = pcall(require, m)
	return ok and L or nil
end

local function attackerPos(hum: Humanoid): Vector3?
	local from = hum:GetAttribute("LastHitFrom")
	if typeof(from) == "Vector3" then return from end
	local id = hum:GetAttribute("LastAttacker")
	if type(id) == "number" and id ~= 0 then
		local p = Players:GetPlayerByUserId(id)
		local r = p and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if r then return r.Position end
	end
	return nil
end

-- which logical clip (pure: testable)
function DeathAnims.Pick(info): string
	-- info = { kind, zone, coverState, rel = Vector3 (the attacker in the body's object space) or nil }
	local AF = info.config
	if info.kind == "Gun" and info.zone == "Head" then return "DeathHeadshot" end
	if info.kind and AF.Hits.StaggerKinds[info.kind] then return "DeathExplosion" end
	if info.coverState ~= nil and info.coverState ~= "None" then return "DeathSide" end
	local rel = info.rel
	if not rel or rel.Magnitude < 0.01 then return "DeathAny" end
	local flat = Vector3.new(rel.X, 0, rel.Z)
	if flat.Magnitude < 0.01 then return "DeathAny" end
	local ang = math.deg(math.acos(math.clamp(-flat.Unit.Z, -1, 1))) -- 0 = straight in front
	if ang <= AF.Death.SideAngle then return "DeathFromFront" end
	if ang >= 180 - AF.Death.SideAngle then return "DeathFromBehind" end
	return "DeathSide"
end

function DeathAnims.Play(character: Model, hum: Humanoid): number
	local L = lib()
	if not L then return 0 end
	local AF = L.Config
	if AF.Enabled == false or not AF.Death or not AF.Death.Enabled then return 0 end
	if not Players:GetPlayerFromCharacter(character) and not AF.Death.Bots then return 0 end
	local root = character:FindFirstChild("HumanoidRootPart")
	local animator = hum:FindFirstChildOfClass("Animator")
	if not root or not animator then return 0 end
	local from = attackerPos(hum)
	local logical = DeathAnims.Pick({
		config = AF,
		kind = hum:GetAttribute("LastAttackKind"),
		zone = hum:GetAttribute("LastHitZone"),
		coverState = character:GetAttribute("CoverState"),
		rel = from and root.CFrame:PointToObjectSpace(from) or nil,
	})
	local name = L.Clip(logical) or L.Clip("DeathAny")
	if not name then return 0 end
	-- every other track stops: the death owns the body
	for _, t in animator:GetPlayingAnimationTracks() do
		pcall(function() t:Stop(0.1) end)
	end
	local track = L.Load(animator, name, Enum.AnimationPriority.Action4, false)
	if not track then return 0 end
	track:Play(AF.Death.FadeIn or 0.05)
	character:SetAttribute("DeathClip", name)
	local at = AF.Death.RagdollAt[name] or AF.Death.RagdollDelay or 0
	return math.clamp(at, 0, AF.Death.MaxDelay or 1.2)
end

return DeathAnims
