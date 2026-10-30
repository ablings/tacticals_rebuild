-- ReplicatedStorage.Modules.Shared.AnimLib [ANIMFINAL] (2026-10-30, systems session; installed by fix/anim_final_1030.lua)
-- Finds a clip by name in ReplicatedStorage.Repository.AnimationSources and loads it once per Animator.
--   AnimLib.Id(name)                 -> the PublishedId (live), the KeyframeSequence's Studio id (Studio only), or nil
--   AnimLib.First(names)             -> the first name in the list (or a string) that has an id, or nil
--   AnimLib.Clip(logical)            -> AnimFinalConfig.Clips[logical] resolved, or nil
--   AnimLib.Load(animator, name, priority?, looped?) -> AnimationTrack or nil (cached per Animator; a missing clip is nil)
--   AnimLib.GunPrefix(config, clip)  -> the AnimationSourcePrefix that has <prefix><clip>, else the fallback prefix
-- Works on the server too (deaths). Caches are strong tables cleared when the Animator leaves the game (an Instance key in
-- a weak table can vanish while the instance lives).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Lib = {}
local Config = require(script.Parent:WaitForChild("Config"):WaitForChild("AnimFinalConfig"))
Lib.Config = Config

local function sources(): Instance?
	local repo = ReplicatedStorage:FindFirstChild("Repository")
	return repo and repo:FindFirstChild("AnimationSources")
end

function Lib.Source(name: string?): Instance?
	if type(name) ~= "string" or name == "" then return nil end
	local s = sources()
	return s and s:FindFirstChild(name) or nil
end

local studioIds = {} -- [KeyframeSequence] = temporary Studio id
function Lib.Id(name: string?): string?
	local src = Lib.Source(name)
	if not src then return nil end
	local pub = src:GetAttribute("PublishedId")
	if type(pub) == "string" and pub ~= "" then return pub end
	if src:IsA("Animation") and src.AnimationId ~= "" then return src.AnimationId end
	if src:IsA("KeyframeSequence") and RunService:IsStudio() then
		if studioIds[src] then return studioIds[src] end
		local ok, id = pcall(function() return game:GetService("KeyframeSequenceProvider"):RegisterKeyframeSequence(src) end)
		if ok and type(id) == "string" then
			studioIds[src] = id
			src.Destroying:Once(function() studioIds[src] = nil end)
			return id
		end
	end
	return nil
end

function Lib.First(names): string?
	if type(names) == "string" then names = { names } end
	if type(names) ~= "table" then return nil end
	for _, n in names do
		if Lib.Id(n) then return n end
	end
	return nil
end

function Lib.Clip(logical: string): string?
	return Lib.First(Config.Clips[logical])
end

-- every name of a list that exists (idle fidgets)
function Lib.All(names): { string }
	local out = {}
	for _, n in names or {} do
		if Lib.Id(n) and not table.find(out, n) then table.insert(out, n) end
	end
	return out
end

local cache = {} -- [Animator] = { [name] = AnimationTrack | false }
local function bucket(animator: Animator)
	local b = cache[animator]
	if b then return b end
	b = {}
	cache[animator] = b
	local function drop()
		if not animator:IsDescendantOf(game) then cache[animator] = nil end
	end
	animator.Destroying:Once(function() cache[animator] = nil end)
	animator.AncestryChanged:Connect(drop)
	return b
end

function Lib.Load(animator: Animator?, name: string?, priority: Enum.AnimationPriority?, looped: boolean?): AnimationTrack?
	if not animator or type(name) ~= "string" then return nil end
	local b = bucket(animator)
	local t = b[name]
	if t == nil then
		t = false
		local id = Lib.Id(name)
		if id then
			local a = Instance.new("Animation")
			a.AnimationId = id
			local ok, track = pcall(animator.LoadAnimation, animator, a)
			if ok and track then t = track end
		end
		b[name] = t
	end
	if not t then return nil end
	if priority then t.Priority = priority end
	if looped ~= nil then t.Looped = looped end
	return t
end

function Lib.LoadClip(animator: Animator?, logical: string, priority: Enum.AnimationPriority?, looped: boolean?): AnimationTrack?
	return Lib.Load(animator, Lib.Clip(logical), priority, looped)
end

-- the prefix whose set has this clip: the gun's own (AnimationSourcePrefix), else AnimationFallbackPrefix, else the own one
function Lib.GunPrefix(config, clip: string): string
	local own = config and config.AnimationSourcePrefix or ""
	if Lib.Source(own .. clip) then return own end
	local fb = config and config.AnimationFallbackPrefix
	if type(fb) == "string" and Lib.Source(fb .. clip) then return fb end
	return own
end

-- a hit's reaction clip name: the headshot snap when the hit is at the head, else the flinch for the side it came from.
-- dir = the shot's travel direction (shooter -> victim). nil when no clip exists.
function Lib.HitClip(character: Model, position: Vector3, dir: Vector3?): string?
	local head = character:FindFirstChild("Head")
	if head and (position - head.Position).Magnitude <= (Config.Hits.HeadRadius or 1.2) then
		local n = Lib.Clip("HeadSnap")
		if n then return n end
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not dir or dir.Magnitude < 0.01 then return Lib.Clip("FlinchF") end
	local rel = root.CFrame:VectorToObjectSpace(-dir) -- toward the shooter, in the body's space (front = -Z)
	local logical
	if math.abs(rel.Z) >= math.abs(rel.X) then
		logical = rel.Z <= 0 and "FlinchF" or "FlinchB"
	else
		logical = rel.X > 0 and "FlinchR" or "FlinchL"
	end
	return Lib.Clip(logical)
end

-- true at most once per `cd` seconds per key (strong table, pruned of keys that left the game)
local stamps, nStamps = {}, 0
function Lib.Cooldown(key: Instance, cd: number): boolean
	local now = os.clock()
	if stamps[key] and now - stamps[key] < cd then return false end
	if not stamps[key] then nStamps += 1 end
	stamps[key] = now
	if nStamps > 64 then
		for k in stamps do
			if not k:IsDescendantOf(game) then stamps[k] = nil nStamps -= 1 end
		end
	end
	return true
end

function Lib.AnimatorOf(character: Instance?): Animator?
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	return hum and hum:FindFirstChildOfClass("Animator") or nil
end

return Lib
