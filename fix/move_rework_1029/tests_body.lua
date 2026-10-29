local RS = game:GetService("ReplicatedStorage")
local out = {}
local function resolve(path)
	local node = game
	for seg in path:gmatch("[^%.]+") do node = node and node:FindFirstChild(seg) end
	return node
end
local mr = RS.Modules.Shared:FindFirstChild("MoveRules")
assert(mr, "MoveRules is not installed")
-- fresh copies (Studio's plugin VM caches require per module instance)
local M = loadstring(mr.Source)()
local cfg = loadstring(RS.Modules.Shared.Config.CoverConfig.Source)()
local passed, failed, lines = SPEC(M, cfg)
-- install checks
local function chk(name, cond)
	if cond then passed += 1 else failed += 1 table.insert(lines, "FAIL install: " .. name) end
end
chk("round stamp " .. ROUND, RS.Modules.Shared.Config.CoverConfig:GetAttribute("MoveRework1029Round") == ROUND)
chk("MoveAction remote", RS.Events.Movement:FindFirstChild("MoveAction") ~= nil)
chk("PeekTime 0.115", cfg.PeekTime == 0.115)
chk("no SilentVaultSlowdown", cfg.SilentVaultSlowdown == nil)
chk("no SilentVaultCoverReach", cfg.SilentVaultCoverReach == nil)
chk("VaultCoverReach kept", cfg.VaultCoverReach == 3)
chk("RevaultReach kept", cfg.RevaultReach ~= nil)
for _, k in { "PeekTurnRate", "PeekTurnSharpness", "PeekSnapSharpness", "PeekFireMaxAngle", "FireBufferTime", "FireFacingTolerance",
	"BlindFacingTolerance", "FacingRecheck", "FacingParallaxStuds", "FaceHoldTime", "FaceReturnRate", "LeanRoll", "LeanShift", "LeanTime", "LeanCameraRoll", "LeanCameraShift", "LeanInputDot",
	"PullUpMaxHeight", "PullUpMinHeight", "PullUpReach", "PullUpStandDepth", "PullUpTime", "PullUpTimePerStud", "VaultNoiseRange" } do
	chk("knob " .. k, type(cfg[k]) == "number")
end
local na = {}
for _, t in TARGET_PATHS do
	local inst = resolve(t[1])
	if not inst then
		chk("script " .. t[1], t[2])
		table.insert(na, t[1]:match("[^%.]+$"))
	else
		local _, n = inst.Source:gsub("%[MOVE1029%]", "")
		chk(t[1]:match("[^%.]+$") .. " has its edits", n >= 1)
	end
end
return ("MOVE1029 tests: %d passed, %d failed%s%s"):format(passed, failed, #na > 0 and (" (n/a here: " .. table.concat(na, ", ") .. ")") or "",
	#lines > 0 and (" | " .. table.concat(lines, " | ")) or "")
