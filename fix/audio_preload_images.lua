-- fix/audio_preload_images.lua [PSEUDOLOBBY] 2026-10-18 (match places): AudioPreloadController preloads every "rbxassetid://"
-- string in every Config module as a Sound. Since the hub's LobbyConfig / LobbyFeaturesConfig / TrainingConfig came over for the
-- after-match lobby, that included image ids (LobbyConfig.PlayArt, icons): 5 "Asset type does not match" warnings per join
-- (found by the UI session). Now: the hub-only config modules are skipped (lobby menus, no gameplay sounds), and so is any key
-- that names an image (Art / Image / Icon / Thumbnail / Emblem / Decal / Texture). Idempotent; UNDO swaps back.
local UNDO = false --@UNDO
local m = game.StarterPlayer.StarterPlayerScripts.Client.Controllers.AudioPreloadController
local TAG = "[PSEUDOLOBBY] images"
local EDITS = {
	{ "\t\tif k ~= \"Animations\" then\n",
		"\t\t-- " .. TAG .. ": image ids are not sounds (preloading them as Sounds warns \"Asset type does not match\")\n"
			.. "\t\tlocal key = tostring(k)\n"
			.. "\t\tif k ~= \"Animations\" and not (key:find(\"Art$\") or key:find(\"Image\") or key:find(\"Icon\") or key:find(\"Thumbnail\")\n"
			.. "\t\t\tor key:find(\"Emblem\") or key:find(\"Decal\") or key:find(\"Texture\")) then\n" },
	{ "\t\tif m:IsA(\"ModuleScript\") then\n\t\t\tlocal ok, t = pcall(require, m)\n",
		"\t\t-- " .. TAG .. ": the hub's menu configs (after-match lobby) hold art, not gameplay sounds\n"
			.. "\t\tif m:IsA(\"ModuleScript\") and not (m.Name == \"LobbyConfig\" or m.Name == \"LobbyFeaturesConfig\" or m.Name == \"TrainingConfig\") then\n"
			.. "\t\t\tlocal ok, t = pcall(require, m)\n" },
}
local s = m.Source
if UNDO then
	for i = #EDITS, 1, -1 do
		local a, b = s:find(EDITS[i][2], 1, true)
		if a then s = s:sub(1, a - 1) .. EDITS[i][1] .. s:sub(b + 1) end
	end
	m.Source = s
	return "undone"
end
local log = {}
for i, e in ipairs(EDITS) do assert(s:find(e[2], 1, true) or s:find(e[1], 1, true), "edit " .. i .. " not found") end
for i, e in ipairs(EDITS) do
	if s:find(e[2], 1, true) then table.insert(log, i .. " already in")
	else local a, b = s:find(e[1], 1, true); s = s:sub(1, a - 1) .. e[2] .. s:sub(b + 1); table.insert(log, i .. " applied") end
end
assert(loadstring(s), "would not parse")
m.Source = s
return "AudioPreloadController: " .. table.concat(log, ", ")
