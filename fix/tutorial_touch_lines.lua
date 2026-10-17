-- fix/tutorial_touch_lines.lua (2026-10-17, UI session's mobile pass): on touch devices the tutorial banner said
-- "Press [Q] ..." etc. TutorialConfig gets Touch / Touch2 / Touch3 (same keys as Lines / Lines2 / Lines3, button names as
-- the touch HUD shows them) and TutorialConfig.ForTouch(text); TutorialController.showLine swaps the text on touch-only
-- devices (TouchEnabled and no keyboard, or player attribute _ForceTouch in Studio). Tagged "[TOUCH]". Match place only.
-- Idempotent. `python tools/run_luau.py`-style: run in the match place through execute_luau; UNDO restores both scripts.
local UNDO = false --@UNDO
local cfg = game.ReplicatedStorage.Modules.Shared.Config.TutorialConfig
local tc = game.StarterPlayer.StarterPlayerScripts.Client.Controllers.TutorialController
local TAG = "[TOUCH]"

local TOUCH = [==[
-- [TOUCH] 2026-10-17: the same lines for touch-only players (button names as the touch HUD shows them).
-- Keys match Lines / Lines2 / Lines3; a line with no touch version is shown as is.
TutorialConfig.Touch = {
	EscapeCover = "Tap Take Cover to step out of cover.",
	TakeCover = "Tap Take Cover again to hide behind the pillar.",
	Rush = "Look at the glowing crate and tap Dash to run to it.",
	Slide = "Run with the stick, then tap Crouch to slide!",
	ToWall = "Look at the glowing wall and tap Dash to run to it.",
	Vault = "Tap Jump to jump over the wall.",
	AimShoot = "Now get him! Hold Aim, then tap Fire (or double tap the screen).",
}
TutorialConfig.Touch2 = {
	Crouch = "Tap Crouch to crouch. Crouch-walking is almost silent, but he can hear you walk and sprint.",
	Loud = "Get to the highlighted cover - fast! Run with the stick and tap Dash.",
	HeardYou = "He heard you rush in! Rushing is LOUD. From now on, tap Dash while standing still to sneak to cover. It's slower, but much quieter.",
	SilentVault = "Slip over the low wall without a sound: tap Jump. As you land, look at the short box by the pillar and tap Dash - you'll sneak into it quietly.",
	Flash1 = "He's holding the wall. Flash him: hold Throw Gadget, aim at the marker in front of him, and let go.",
	SlipPast = "He's blinded and falling back to that pillar. Follow him! Tap Dash to get to the opposite side of the pillar.",
	Flash2 = "He's right around the corner. Hold Throw Gadget and bank your last flash off the wall to the right so it drops onto the marker on his side of the pillar.",
	Sneak1 = "Watch his head. When he looks away, aim at the highlighted cover and tap Dash to sneak there - slow, crouched and silent.",
	Sneak2 = "The eye above him fills up while he can see you. Tap Dash to sneak to the next cover and stay out of his view. (Real players don't have an eye!)",
	Guard = "He's stopped to guard. Throw a flashbang so it pops in front of his face: hold Throw Gadget, aim the arc at the marker, let go.",
	Blinded = "He's blinded and facing away! Push the stick left to loop around the pillar, then tap the melee circle or Gun Bash. One hit does it.",
}
TutorialConfig.Touch3 = {
	Slide = "Now move! Run with the stick, then tap Crouch to SLIDE toward that crate - and tap Take Cover while you're sliding to drop straight into cover behind it.",
	Frag = "He barely made it - he's burning behind the far short wall. Finish him: hold Throw Gadget and lob a frag over it, onto the marker.",
}
-- the touch version of a line (by its PC text), or the line itself
function TutorialConfig.ForTouch(text)
	for _, pair in { { TutorialConfig.Lines, TutorialConfig.Touch }, { TutorialConfig.Lines2, TutorialConfig.Touch2 }, { TutorialConfig.Lines3, TutorialConfig.Touch3 } } do
		local pc, touch = pair[1], pair[2]
		if pc and touch then
			for key, line in pc do
				if line == text and touch[key] then return touch[key] end
			end
		end
	end
	return text
end

return TutorialConfig
]==]

local SHOW_OLD = "local function showLine(text: string, key: string?)\n\tgui.Enabled = true\n"
local SHOW_NEW = "local function showLine(text: string, key: string?)\n\tgui.Enabled = true\n"
	.. "\t-- [TOUCH] touch-only players get the button names instead of keys (TutorialConfig.ForTouch)\n"
	.. "\tdo\n"
	.. "\t\tlocal uis = game:GetService(\"UserInputService\")\n"
	.. "\t\tlocal touchOnly = (uis.TouchEnabled and not uis.KeyboardEnabled) or game:GetService(\"Players\").LocalPlayer:GetAttribute(\"_ForceTouch\") == true\n"
	.. "\t\tif touchOnly and Config.ForTouch then text = Config.ForTouch(text) end\n"
	.. "\tend\n"

local src, tsrc = cfg.Source, tc.Source
if UNDO then
	local i = src:find("-- [TOUCH] 2026-10-17", 1, true)
	if i then
		src = src:sub(1, i - 1):gsub("%s+$", "") .. "\n\nreturn TutorialConfig\n"
		src = src:gsub("local TutorialConfig = {", "return {", 1):gsub("\n\nreturn TutorialConfig\n$", "\n")
		cfg.Source = src
	end
	local a, b = tsrc:find(SHOW_NEW, 1, true)
	if a then tc.Source = tsrc:sub(1, a - 1) .. SHOW_OLD .. tsrc:sub(b + 1) end
	return "undone"
end

local log = {}
if not src:find(TAG, 1, true) then
	local a = src:find("\nreturn {\n", 1, true)
	assert(a, "return { not found")
	src = src:sub(1, a) .. "local TutorialConfig = {\n" .. src:sub(a + #"\nreturn {\n")
	src = src:gsub("%s+$", "") .. "\n\n" .. TOUCH
	local f, err = loadstring(src)
	assert(f, "config syntax: " .. tostring(err))
	cfg.Source = src
	table.insert(log, "TutorialConfig: Touch tables + ForTouch")
else
	table.insert(log, "TutorialConfig already has [TOUCH]")
end
if not tsrc:find(SHOW_NEW, 1, true) then
	local a, b = tsrc:find(SHOW_OLD, 1, true)
	assert(a, "showLine start not found")
	tsrc = tsrc:sub(1, a - 1) .. SHOW_NEW .. tsrc:sub(b + 1)
	local f, err = loadstring(tsrc)
	assert(f, "controller syntax: " .. tostring(err))
	tc.Source = tsrc
	table.insert(log, "TutorialController.showLine swaps text on touch")
else
	table.insert(log, "TutorialController already patched")
end
return table.concat(log, "\n")
