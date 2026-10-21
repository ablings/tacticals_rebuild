-- fix/streaming.lua [STREAM] 2026-10-21, Edward: "loading on mobile for some reason is so slow" -> "do both" (quick fixes + streaming).
-- The lobby replicated its whole map (7,645 parts, 1,109 unique meshes) before game.Loaded, which is most of a phone's join time.
-- With StreamingEnabled the client gets what's around the spawn first and the rest streams in while you play (the map spans ~800
-- studs, under the default target radius, so it all arrives within seconds on a PC).
-- What client code reaches from anywhere stays loaded (ModelStreamingMode Persistent):
--   * LobbyMap.Duels pad models (To Pads teleport, PadBoards / PadUI read their Holo parts)
--   * LobbyMap.Heli (LobbyUIController hooks HeliTrigger)
--   * LobbyMap.Showroom (the Kit / Armory camera): a Folder, so it becomes a Model with the same name, children, attributes, tags
-- One-time client scans that must also catch parts streamed in later: ui/pseudolobby/hub/LobbyFX.lua and
-- ui/settings/SettingsEffectsController.lua ([STREAM], deployed by ui/deploy_ui.py).
-- Lobby working copy only (the match places are small). Idempotent; UNDO = true puts everything back.
local UNDO = false --@UNDO
local CS = game:GetService("CollectionService")
local map = workspace:FindFirstChild("LobbyMap")
assert(map, "no LobbyMap: run this in the lobby working copy")
local res = {}

workspace.StreamingEnabled = not UNDO
table.insert(res, "StreamingEnabled=" .. tostring(workspace.StreamingEnabled))

local pinned = {}
local duels = map:FindFirstChild("Duels")
for _, m in (duels and duels:GetChildren() or {}) do if m:IsA("Model") then table.insert(pinned, m) end end
if map:FindFirstChild("Heli") and map.Heli:IsA("Model") then table.insert(pinned, map.Heli) end

-- Showroom Folder <-> Model
local sr = map:FindFirstChild("Showroom")
local function swapContainer(old, className)
	local new = Instance.new(className)
	new.Name = old.Name
	for k, v in old:GetAttributes() do new:SetAttribute(k, v) end
	for _, t in CS:GetTags(old) do CS:AddTag(new, t) end
	for _, c in old:GetChildren() do c.Parent = new end
	new.Parent = old.Parent
	old:Destroy()
	return new
end
if sr then
	if not UNDO and sr:IsA("Folder") then sr = swapContainer(sr, "Model") table.insert(res, "Showroom Folder->Model")
	elseif UNDO and sr:IsA("Model") then sr = swapContainer(sr, "Folder") table.insert(res, "Showroom Model->Folder") end
	if sr:IsA("Model") then table.insert(pinned, sr) end
end

for _, m in pinned do
	m.ModelStreamingMode = UNDO and Enum.ModelStreamingMode.Default or Enum.ModelStreamingMode.Persistent
end
table.insert(res, #pinned .. " models " .. (UNDO and "Default" or "Persistent"))
return (UNDO and "UNDO " or "STREAM ") .. table.concat(res, " | ")
