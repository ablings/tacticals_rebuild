-- no_panel_prompts.lua : no world prompt opens the Shop / Kit panels any more. Edward 2026-10-16: "no shop or anything is
-- going to be made, so just remove that mechanic for now" (then approved the counter / gun wall / dais prompts too).
-- a) The Outfitter NPC (NPCs.NPC_Quartermaster, Shop) and the Armory NPC (NPCs.NPC_Supply) become dialogue-only.
-- b) Interact.Shop_Counter (Shop), Interact.GunWall_Kit and Interact.Armory_Dais (Kit): prompt hidden (Enabled false, original
--    in attribute NoPanel_Orig) and flagged NPC_OpensPanel = false as well. The panels' UI code and the Showroom stay intact.
-- Tacticals_rebuild.rbxl ONLY.
-- How: LobbyUIController (client) opens the panel named by a prompt's OpenPanel attribute on PromptTriggered. One marked
-- line there now also requires the prompt attribute NPC_OpensPanel ~= false (missing = old behaviour), and the two NPC
-- prompts get NPC_OpensPanel = false. Their OpenPanel and TalkLines attributes are left as they are, so LobbyLabels still
-- shows the speech bubble and setting NPC_OpensPanel back to true (or deleting it) restores the panel.
-- Untouched: NPC_DuelsOfficer (still opens Play). Was fix/npc_dialogue_only.lua (renamed; same backup and flag).
-- Idempotent. UNDO reverts the marked line in place. Original controller source also backed up once in ServerStorage._RebuildRemoved.NPC_LobbyUIController_Orig.
-- UNDO: python tools/run_luau.py fix/no_panel_prompts.lua UNDO
local UNDO = false --@UNDO

local SS = game:GetService("ServerStorage")
local LM = workspace.LobbyMap
local ctrl = game.StarterPlayer.StarterPlayerScripts.Client.Controllers.LobbyUIController
local store = SS:FindFirstChild("_RebuildRemoved")
local BAK = "NPC_LobbyUIController_Orig"
local NPCS = {"NPC_Quartermaster", "NPC_Supply"}
local INTERACT = {"Shop_Counter", "GunWall_Kit", "Armory_Dais"}
local PATTR = "NoPanel_Orig"
local MARK = "-- [NPC] dialogue-only (Edward 2026-10-16)"
local OLD = '\t\tif id and id ~= "" then\n\t\t\tLobbyUI.Open(id)'
local NEW = '\t\t' .. MARK .. ': a prompt with NPC_OpensPanel = false keeps its talk lines but opens no panel\n'
	.. '\t\tif id and id ~= "" and prompt:GetAttribute("NPC_OpensPanel") ~= false then\n\t\t\tLobbyUI.Open(id)'
local log = {}
local function say(...) local t = {} for _, v in ipairs({...}) do table.insert(t, tostring(v)) end table.insert(log, table.concat(t, " ")) end

local function prompt(name)
	local n = LM.NPCs:FindFirstChild(name)
	local hrp = n and n:FindFirstChild("HumanoidRootPart")
	return hrp and hrp:FindFirstChildWhichIsA("ProximityPrompt")
end

if UNDO then
	-- reverse the marked edit in place (keeps any later edits by other sessions); the full backup is only a fallback
	local bak = store and store:FindFirstChild(BAK)
	local src = ctrl.Source
	local a, b = src:find(NEW, 1, true)
	if a then
		ctrl.Source = src:sub(1, a - 1) .. OLD .. src:sub(b + 1)
		if bak then bak:Destroy() end
		say("LobbyUIController: marked line reverted in place")
	elseif src:find(MARK, 1, true) and bak then
		ctrl.Source = bak.Source; bak:Destroy(); say("LobbyUIController: marked line edited by hand, full backup restored")
	else say("LobbyUIController not patched: left as is") end
	for _, n in ipairs(NPCS) do
		local p = prompt(n)
		if p and p:GetAttribute("NPC_OpensPanel") ~= nil then p:SetAttribute("NPC_OpensPanel", nil); say(n, "NPC_OpensPanel cleared") end
	end
	for _, n in ipairs(INTERACT) do
		local h = LM.Interact:FindFirstChild(n)
		local p = h and h:FindFirstChildWhichIsA("ProximityPrompt", true)
		if p then
			local o = p:GetAttribute(PATTR)
			if o ~= nil then p.Enabled = o; p:SetAttribute(PATTR, nil) end
			p:SetAttribute("NPC_OpensPanel", nil); say(n, "prompt restored, Enabled =", p.Enabled)
		end
	end
	return "UNDO no_panel_prompts:\n" .. table.concat(log, "\n")
end

local src = ctrl.Source
if src:find(MARK, 1, true) then
	say("LobbyUIController already patched")
else
	local a, b = src:find(OLD, 1, true)
	if not a then return "ERROR anchor not found in LobbyUIController: nothing changed" end
	if not store then store = Instance.new("Folder"); store.Name = "_RebuildRemoved"; store.Parent = SS end
	if not store:FindFirstChild(BAK) then local bak = ctrl:Clone(); bak.Name = BAK; bak.Parent = store end
	ctrl.Source = src:sub(1, a - 1) .. NEW .. src:sub(b + 1)
	say("LobbyUIController patched (1 line + 1 comment line)")
end
for _, n in ipairs(NPCS) do
	local p = prompt(n)
	if p then
		p:SetAttribute("NPC_OpensPanel", false)
		say(n, "NPC_OpensPanel = false; OpenPanel kept =", p:GetAttribute("OpenPanel"), "; TalkLines kept:", p:GetAttribute("TalkLines") ~= nil)
	else say("WARN no prompt on", n) end
end
for _, n in ipairs(INTERACT) do
	local h = LM.Interact:FindFirstChild(n)
	local p = h and h:FindFirstChildWhichIsA("ProximityPrompt", true)
	if p then
		if p:GetAttribute(PATTR) == nil then p:SetAttribute(PATTR, p.Enabled) end
		p.Enabled = false
		p:SetAttribute("NPC_OpensPanel", false)
		say(n, "prompt hidden (Enabled false), OpenPanel kept =", p:GetAttribute("OpenPanel"))
	else say("WARN no prompt on Interact." .. n) end
end
return table.concat(log, "\n")
