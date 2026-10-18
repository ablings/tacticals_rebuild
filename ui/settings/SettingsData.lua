-- SettingsData: every tacticals player setting (RIVALS-style list, our own wording; translated to Tacticals by the UI
-- session 2026-10-16: one gun, no emotes / aim assist / weapon picker, hotkeys are Tacticals' real actions). The lobby SETTINGS
-- screen draws its rows from here and the server checks saves against it (SettingsConfig.Sanitize).
-- Deliberately left out: Field Of View (and its FOV-only child rows) and the Crosshair tab.
-- Row kinds: toggle, slider, dropdown, swatch, keybind. level 0 = full-width top row, 1 (default), 2 = indented child, 3 = grandchild.
-- key = storage key when two rows share a label (defaults to name).
-- A section with title = nil has no header bar.
local pct = function(v) return v .. "%" end
local hex = function(s) return Color3.fromRGB(tonumber(s:sub(2, 3), 16), tonumber(s:sub(4, 5), 16), tonumber(s:sub(6, 7), 16)) end
local PALETTE = { hex("#FFFFFF"), hex("#E54343"), hex("#65FE32"), hex("#03BFFF"), hex("#FFD701"), hex("#C04BFF") }

return {
	tabs = {
		-- Video: every row from Edward's Video-tab captures (ref_12-16, ref_53), in reference order, with
		-- reference names and ranges (Edward 2026-10-10). Descriptions are our own wording.
		-- Ranges marked (guess) are not confirmed yet.
		{ name = "Video", glyph = "🖥", icon = "video", sections = {
			{ title = "Performance", rows = {
				{ kind = "toggle", name = "Optimized Lighting", icon = "lightbulb", value = false, desc = "Uses simpler lighting so the game runs faster on older devices" },
				{ kind = "toggle", name = "Optimized Textures", icon = "texture", value = false, desc = "Swaps detailed surface images for plain colours to save memory" },
			} },
			{ title = "Camera", rows = {
				{ kind = "slider", name = "Sensitivity", icon = "camera", min = 5, max = 400, step = 5, arrow = 50, value = 100, fmt = pct, desc = "How fast the camera turns when you move the mouse or stick" },
				{ kind = "slider", name = "While Aiming", icon = "crosshair", level = 2, min = 5, max = 200, step = 5, arrow = 20, value = 50, fmt = pct, desc = "Camera speed while aiming, as a share of your normal sensitivity" },
				{ kind = "slider", name = "While Scoped", icon = "aim", level = 2, min = 5, max = 200, step = 5, arrow = 20, value = 50, fmt = pct, desc = "Camera speed while looking down a scope, as a share of your normal sensitivity" },
				{ kind = "slider", name = "Horizontal", icon = "arrows_h", level = 2, min = 5, max = 400, step = 5, arrow = 40, value = 100, fmt = pct, desc = "[Advanced] Changes only your left and right camera speed" },
				{ kind = "slider", name = "Vertical", icon = "arrows_v", level = 2, min = 5, max = 400, step = 5, arrow = 40, value = 100, fmt = pct, desc = "[Advanced] Changes only your up and down camera speed" },
				{ kind = "toggle", name = "Inverted X", icon = "arrows_h", level = 2, value = false, desc = "[Advanced] Flips left and right camera movement" },
				{ kind = "toggle", name = "Inverted Y", icon = "arrows_v", level = 2, value = false, desc = "[Advanced] Flips up and down camera movement" },
				{ kind = "toggle", name = "Camera Shake", icon = "damage", value = true, desc = "Shakes the camera on explosions and heavy hits" },
			} },
			{ title = "Interface", rows = {
				{ kind = "toggle", name = "Hide HUD", icon = "eye", value = false, desc = "Hides most of the interface, for clean screenshots and clips. Can also be bound to a hotkey" },
				{ kind = "toggle", name = "Hide Missions", key = "Hide Side Tasks", icon = "checklist", value = false, desc = "Hides the daily missions on the left of the lobby" },
				{ kind = "dropdown", name = "Padded HUD", icon = "padded", options = { "Always On", "Using Controller", "Disabled" }, value = "Using Controller", desc = "Adds space around the screen edges so nothing sits under a TV's border" },
				{ kind = "dropdown", name = "Lobby Data", icon = "window", options = { "Level", "Wins", "Rank", "Streak" }, value = "Level", desc = "Which stat the lobby shows for players: the player list and your nameplate (Rank: their ranked emblem; Streak: their win streak)" },
			} },
			{ title = "Aiming", rows = {
				{ kind = "dropdown", name = "Aim Assist", icon = "inking", options = { "50%", "25%", "Off" }, value = "50%", desc = "Helps touch and controller players track targets. Max 25% in ranked." },
			} },
			{ title = "Social", rows = {
				{ kind = "dropdown", name = "Challenge Requests", icon = "inking", options = { "Everyone", "Friends", "Nobody" }, value = "Everyone", desc = "Who can challenge you to a 1v1 from the lobby (player list or double click)" },
				{ kind = "dropdown", name = "Party Invites", icon = "inking", options = { "Everyone", "Friends", "Nobody" }, value = "Everyone", desc = "Who can invite you to their party" },
			} },
			{ title = "Graphics", rows = {
				{ kind = "toggle", name = "Hide Muzzle Flashes", icon = "muzzle", value = false, desc = "Removes the flash at the end of a gun when it fires" },
			} },
			{ title = "Accessibility", rows = {
				{ kind = "dropdown", name = "Damage Flashing", icon = "person", options = { "Enabled", "Outline", "Disabled" }, value = "Enabled", desc = "Makes players flash when they take damage" },
				{ kind = "swatch", name = "Base Color", icon = "person", level = 2, color = hex("#FF3232"), palette = PALETTE, desc = "The main colour of the damage flash" },
				{ kind = "swatch", name = "Flash Color", icon = "person", level = 2, color = PALETTE[1], palette = PALETTE, desc = "The colour the flash fades to" },
				{ kind = "toggle", name = "Dark Blinds", icon = "dim", value = false, desc = "Makes blinding flashes dark instead of bright. Turn this on if flashing lights bother you" },
			} },
		} },
		-- Audio: from ref_17/18. No section title; Master Volume is a full-width top row (level 0) and the
		-- other volumes hang under it. Arrow steps are a guess (10).
		{ name = "Audio", glyph = "🔊", icon = "audio", sections = {
			{ title = nil, rows = {
				{ kind = "slider", name = "Master Volume", icon = "volume", level = 0, min = 0, max = 100, step = 5, arrow = 10, value = 50, fmt = pct, desc = "Changes the volume of everything at once" },
				{ kind = "slider", name = "SFX Volume", icon = "muzzle", min = 0, max = 100, step = 5, arrow = 10, value = 100, fmt = pct, desc = "Changes the volume of pretty much every other sound" },
			} },
		} },
		-- Game: every row from ref_08-11 in reference order. Ranges were read from the knob positions in the
		-- captures; arrow steps and dropdown options other than the shown value are guesses.
		{ name = "Game", glyph = "🎮", icon = "game", sections = {
			{ title = "Gameplay", rows = {
				{ kind = "toggle", name = "Damage Numbers", icon = "damage", value = true, desc = "Shows how much damage each hit did" },
				{ kind = "swatch", name = "Color", key = "Damage Color", icon = "damage", level = 2, color = hex("#FFFFFF"), palette = PALETTE, desc = "The colour of normal damage numbers" },
				{ kind = "swatch", name = "Critical Color", icon = "damage", level = 2, color = hex("#FF3232"), palette = PALETTE, desc = "The colour of damage numbers for critical hits" },
				{ kind = "toggle", name = "Hide Teammate Display", icon = "emote", value = false, desc = "Hides the teammate panel during matches" },
				{ kind = "toggle", name = "Aiming Animation", icon = "crosshair", value = true, desc = "Plays the animation when you raise your weapon to aim" },
			} },
			{ title = "Interface", rows = {
				{ kind = "dropdown", name = "Gameplay HUD", icon = "window", options = { "Default", "Minimal" }, value = "Default", desc = "Minimal keeps only your ammo and health in a match" },
					{ kind = "dropdown", name = "Shop Hover", icon = "window", options = { "Spotlight", "Off" }, value = "Spotlight", desc = "Dim everything but the shop card you point at" },
			} },
			{ title = "Controls", rows = {
				{ kind = "toggle", name = "Toggle Aim", icon = "aim", value = false, desc = "Tap to start and stop aiming instead of holding. Doesn't change touch controls" },
				{ kind = "toggle", name = "Toggle Crouch", icon = "crouch", value = true, desc = "Tap to crouch and stand. Off: hold to stay crouched" },
				{ kind = "toggle", name = "Toggle Sprint", icon = "sprint", value = false, desc = "Tap to start and stop sprinting instead of holding" },
				{ kind = "toggle", name = "Auto Sprint", icon = "sprint", value = false, desc = "Run by default without holding the sprint button" },
				{ kind = "toggle", name = "Easy Slide", icon = "effects2", value = true, desc = "Slide by crouching while sprinting" },
				{ kind = "toggle", name = "Scroll Equip", icon = "padding", value = true, desc = "Switch between your gun, melee and gadget with the mouse wheel" },
				{ kind = "dropdown", name = "Gun Hand", icon = "crosshair", options = { "Right", "Left" }, value = "Right", desc = "Which hand holds your gun. Peeking from the other side of cover swaps hands while you're on it; leaving cover puts it back here" },
			} },
		} },
		-- Hotkeys: table layout (HotkeysPage). Four binds per action: PC, PC 2, controller, controller 2.
		-- Default binds from Edward's captures (ref_55-58). "" = unbound.
		{ name = "Hotkeys", glyph = "⌨", icon = "hotkeys", hotkeys = true, sections = {
			{ title = nil, rows = {
				{ kind = "bind", name = "Fire", key = "Attack", icon = "damage", value = { "MouseButton1", "", "ButtonR2", "" } },
				{ kind = "bind", name = "Aim", key = "Ability", icon = "aim", value = { "MouseButton2", "", "ButtonL2", "" } },
				{ kind = "bind", name = "Reload", icon = "reset", value = { "R", "", "ButtonX", "" } },
				{ kind = "bind", name = "Shoulder Swap", icon = "arrows_h", value = { "V", "", "DPadDown", "" } },
				{ kind = "bind", name = "Gun Bash", key = "Quick Melee", icon = "effects2", value = { "F", "", "ButtonR1", "" } },
				{ kind = "bind", name = "Throw Gadget", key = "Quick Utility", icon = "particles", value = { "G", "", "ButtonL1", "" } },
			} },
			{ title = nil, rows = {
				{ kind = "bind", name = "Jump / Vault", key = "Jump", icon = "jump", value = { "Space", "", "ButtonA", "" } },
				{ kind = "bind", name = "Sprint", icon = "sprint", value = { "LeftShift", "", "ButtonL3", "" } },
				{ kind = "bind", name = "Crouch", icon = "crouch", value = { "C", "LeftControl", "ButtonR3", "" } },
				{ kind = "bind", name = "Slide", icon = "effects2", value = { "", "", "", "" } },
				{ kind = "bind", name = "Take Cover", icon = "padded", value = { "Q", "", "ButtonB", "" } },
				{ kind = "bind", name = "Dash", icon = "sprint", value = { "E", "", "ButtonY", "" } },
			} },
			{ title = nil, rows = {
				{ kind = "bind", name = "Equip Gun", key = "Equip Primary", icon = "inking", value = { "One", "", "DPadLeft", "" } },
				{ kind = "bind", name = "Equip Melee", icon = "inking", value = { "Two", "", "DPadUp", "" } },
				{ kind = "bind", name = "Equip Gadget", key = "Equip Utility", icon = "particles", value = { "Three", "", "DPadRight", "" } },
				{ kind = "bind", name = "Cycle Weapon", key = "Switch Weapons", icon = "reset", value = { "Z", "", "", "" } },
			} },
			{ title = nil, rows = {
				{ kind = "bind", name = "Free Cursor", icon = "camera", value = { "LeftAlt", "", "", "" } },
				{ kind = "bind", name = "Player List", key = "Open Scoreboard", icon = "leaderboard", value = { "Tab", "", "", "" } },
				{ kind = "bind", name = "Leave Training", icon = "exit", value = { "M", "", "", "" } },
				{ kind = "bind", name = "Hide HUD", icon = "eye", value = { "", "", "", "" } },
			} },
		} },
		-- Touch (2026-10-17, Edward: mobile UI the RIVALS way; ref: notes/ref_mobile 8-16). Layout Editor opens the drag/resize editor;
		-- the layouts themselves are hidden "data" rows (JSON per slot). The joystick is Roblox's own thumbstick.
		{ name = "Touch", glyph = "📱", icon = "touch", sections = {
			{ title = nil, rows = {
				{ kind = "action", name = "Layout Editor", glyph = "▣", level = 0, desc = "Move & resize your touch buttons" },
			} },
			{ title = nil, rows = {
				{ kind = "toggle", name = "Left Handed Mode", glyph = "✋", value = false, desc = "Mirrors the buttons: fire on the left, the joystick on the right" },
				{ kind = "toggle", name = "Opaque Buttons", glyph = "◉", value = true, desc = "Solid dark buttons instead of see-through outlines" },
				{ kind = "slider", name = "Buttons Transparency", glyph = "◐", min = 0, max = 100, step = 5, arrow = 10, value = 50, fmt = pct, desc = "How see-through the touch buttons are" },
				{ kind = "toggle", name = "Buttons Camera Sinking", glyph = "⇩", value = true, desc = "Dragging from a button also turns the camera, so you can aim while you hold it" },
				{ kind = "toggle", name = "Show Weapon Ammo", glyph = "⁞", value = true, desc = "Shows your ammo on the gun button" },
				{ kind = "data", name = "Touch Layout 1" }, { kind = "data", name = "Touch Layout 2" }, { kind = "data", name = "Touch Layout 3" },
				{ kind = "dropdown", name = "Touch Layout Slot", glyph = "▦", options = { "1", "2", "3" }, value = "1", desc = "Which saved button layout you use" },
			} },
			{ title = "Fire", rows = {
				{ kind = "toggle", name = "Double Tap To Attack", glyph = "»", value = true, desc = "Double tap anywhere on the right side of the screen to fire" },
				{ kind = "slider", name = "Double Tap Window", glyph = "»", level = 2, min = 0.1, max = 0.6, step = 0.05, arrow = 0.05, value = 0.25, fmt = function(v) return string.format("%.2f", v) end, desc = "How quick the two taps must be, in seconds" },
				{ kind = "toggle", name = "Enabled", key = "Fire Enabled", glyph = "👁", value = true, desc = "Show this button on your screen" },
				{ kind = "toggle", name = "Custom", key = "Fire Custom", glyph = "⚙", value = false, desc = "[Advanced] Give this button its own transparency instead of the global one" },
				{ kind = "slider", name = "Transparency", key = "Fire Transparency", glyph = "◐", level = 2, showIf = "Fire Custom", min = 0, max = 100, step = 5, arrow = 10, value = 50, fmt = pct, desc = "This button's own transparency" },
				{ kind = "toggle", name = "Camera Sinking", key = "Fire Camera Sinking", glyph = "⇩", level = 2, showIf = "Fire Custom", value = true, desc = "Dragging from this button also turns the camera" },
			} },
			{ title = "Aim", rows = {
				{ kind = "toggle", name = "Enabled", key = "Aim Enabled", glyph = "👁", value = true, desc = "Show this button on your screen" },
				{ kind = "toggle", name = "Custom", key = "Aim Custom", glyph = "⚙", value = false, desc = "[Advanced] Give this button its own transparency instead of the global one" },
				{ kind = "slider", name = "Transparency", key = "Aim Transparency", glyph = "◐", level = 2, showIf = "Aim Custom", min = 0, max = 100, step = 5, arrow = 10, value = 50, fmt = pct, desc = "This button's own transparency" },
				{ kind = "toggle", name = "Camera Sinking", key = "Aim Camera Sinking", glyph = "⇩", level = 2, showIf = "Aim Custom", value = true, desc = "Dragging from this button also turns the camera" },
			} },
			{ title = "Reload", rows = {
				{ kind = "toggle", name = "Enabled", key = "Reload Enabled", glyph = "👁", value = true, desc = "Show this button on your screen" },
				{ kind = "toggle", name = "Custom", key = "Reload Custom", glyph = "⚙", value = false, desc = "[Advanced] Give this button its own transparency instead of the global one" },
				{ kind = "slider", name = "Transparency", key = "Reload Transparency", glyph = "◐", level = 2, showIf = "Reload Custom", min = 0, max = 100, step = 5, arrow = 10, value = 50, fmt = pct, desc = "This button's own transparency" },
				{ kind = "toggle", name = "Camera Sinking", key = "Reload Camera Sinking", glyph = "⇩", level = 2, showIf = "Reload Custom", value = true, desc = "Dragging from this button also turns the camera" },
			} },
			{ title = "Gun Bash", rows = {
				{ kind = "toggle", name = "Enabled", key = "Gun Bash Enabled", glyph = "👁", value = true, desc = "Show this button on your screen" },
				{ kind = "toggle", name = "Custom", key = "Gun Bash Custom", glyph = "⚙", value = false, desc = "[Advanced] Give this button its own transparency instead of the global one" },
				{ kind = "slider", name = "Transparency", key = "Gun Bash Transparency", glyph = "◐", level = 2, showIf = "Gun Bash Custom", min = 0, max = 100, step = 5, arrow = 10, value = 50, fmt = pct, desc = "This button's own transparency" },
				{ kind = "toggle", name = "Camera Sinking", key = "Gun Bash Camera Sinking", glyph = "⇩", level = 2, showIf = "Gun Bash Custom", value = true, desc = "Dragging from this button also turns the camera" },
			} },
			{ title = "Throw Gadget", rows = {
				{ kind = "toggle", name = "Enabled", key = "Throw Gadget Enabled", glyph = "👁", value = true, desc = "Show this button on your screen" },
				{ kind = "toggle", name = "Custom", key = "Throw Gadget Custom", glyph = "⚙", value = false, desc = "[Advanced] Give this button its own transparency instead of the global one" },
				{ kind = "slider", name = "Transparency", key = "Throw Gadget Transparency", glyph = "◐", level = 2, showIf = "Throw Gadget Custom", min = 0, max = 100, step = 5, arrow = 10, value = 50, fmt = pct, desc = "This button's own transparency" },
				{ kind = "toggle", name = "Camera Sinking", key = "Throw Gadget Camera Sinking", glyph = "⇩", level = 2, showIf = "Throw Gadget Custom", value = true, desc = "Dragging from this button also turns the camera" },
			} },
			{ title = "Jump", rows = {
				{ kind = "toggle", name = "Auto Jump", glyph = "⬆", value = false, desc = "Jump over small ledges automatically while you walk into them" },
				{ kind = "toggle", name = "Enabled", key = "Jump Enabled", glyph = "👁", value = true, desc = "Show this button on your screen" },
				{ kind = "toggle", name = "Custom", key = "Jump Custom", glyph = "⚙", value = false, desc = "[Advanced] Give this button its own transparency instead of the global one" },
				{ kind = "slider", name = "Transparency", key = "Jump Transparency", glyph = "◐", level = 2, showIf = "Jump Custom", min = 0, max = 100, step = 5, arrow = 10, value = 50, fmt = pct, desc = "This button's own transparency" },
				{ kind = "toggle", name = "Camera Sinking", key = "Jump Camera Sinking", glyph = "⇩", level = 2, showIf = "Jump Custom", value = true, desc = "Dragging from this button also turns the camera" },
			} },
			{ title = "Crouch", rows = {
				{ kind = "toggle", name = "Enabled", key = "Crouch Enabled", glyph = "👁", value = true, desc = "Show this button on your screen" },
				{ kind = "toggle", name = "Custom", key = "Crouch Custom", glyph = "⚙", value = false, desc = "[Advanced] Give this button its own transparency instead of the global one" },
				{ kind = "slider", name = "Transparency", key = "Crouch Transparency", glyph = "◐", level = 2, showIf = "Crouch Custom", min = 0, max = 100, step = 5, arrow = 10, value = 50, fmt = pct, desc = "This button's own transparency" },
				{ kind = "toggle", name = "Camera Sinking", key = "Crouch Camera Sinking", glyph = "⇩", level = 2, showIf = "Crouch Custom", value = true, desc = "Dragging from this button also turns the camera" },
			} },
			{ title = "Slide", rows = {
				{ kind = "toggle", name = "Enabled", key = "Slide Enabled", glyph = "👁", value = false, desc = "Show this button on your screen" },
				{ kind = "toggle", name = "Custom", key = "Slide Custom", glyph = "⚙", value = false, desc = "[Advanced] Give this button its own transparency instead of the global one" },
				{ kind = "slider", name = "Transparency", key = "Slide Transparency", glyph = "◐", level = 2, showIf = "Slide Custom", min = 0, max = 100, step = 5, arrow = 10, value = 50, fmt = pct, desc = "This button's own transparency" },
				{ kind = "toggle", name = "Camera Sinking", key = "Slide Camera Sinking", glyph = "⇩", level = 2, showIf = "Slide Custom", value = true, desc = "Dragging from this button also turns the camera" },
			} },
			{ title = "Take Cover", rows = {
				{ kind = "toggle", name = "Enabled", key = "Take Cover Enabled", glyph = "👁", value = true, desc = "Show this button on your screen" },
				{ kind = "toggle", name = "Custom", key = "Take Cover Custom", glyph = "⚙", value = false, desc = "[Advanced] Give this button its own transparency instead of the global one" },
				{ kind = "slider", name = "Transparency", key = "Take Cover Transparency", glyph = "◐", level = 2, showIf = "Take Cover Custom", min = 0, max = 100, step = 5, arrow = 10, value = 50, fmt = pct, desc = "This button's own transparency" },
				{ kind = "toggle", name = "Camera Sinking", key = "Take Cover Camera Sinking", glyph = "⇩", level = 2, showIf = "Take Cover Custom", value = true, desc = "Dragging from this button also turns the camera" },
			} },
			{ title = "Dash", rows = {
				{ kind = "toggle", name = "Enabled", key = "Dash Enabled", glyph = "👁", value = true, desc = "Show this button on your screen" },
				{ kind = "toggle", name = "Custom", key = "Dash Custom", glyph = "⚙", value = false, desc = "[Advanced] Give this button its own transparency instead of the global one" },
				{ kind = "slider", name = "Transparency", key = "Dash Transparency", glyph = "◐", level = 2, showIf = "Dash Custom", min = 0, max = 100, step = 5, arrow = 10, value = 50, fmt = pct, desc = "This button's own transparency" },
				{ kind = "toggle", name = "Camera Sinking", key = "Dash Camera Sinking", glyph = "⇩", level = 2, showIf = "Dash Custom", value = true, desc = "Dragging from this button also turns the camera" },
			} },
			{ title = "Equip Gun", rows = {
				{ kind = "toggle", name = "Enabled", key = "Equip Gun Enabled", glyph = "👁", value = true, desc = "Show this button on your screen" },
				{ kind = "toggle", name = "Custom", key = "Equip Gun Custom", glyph = "⚙", value = false, desc = "[Advanced] Give this button its own transparency instead of the global one" },
				{ kind = "slider", name = "Transparency", key = "Equip Gun Transparency", glyph = "◐", level = 2, showIf = "Equip Gun Custom", min = 0, max = 100, step = 5, arrow = 10, value = 50, fmt = pct, desc = "This button's own transparency" },
				{ kind = "toggle", name = "Camera Sinking", key = "Equip Gun Camera Sinking", glyph = "⇩", level = 2, showIf = "Equip Gun Custom", value = true, desc = "Dragging from this button also turns the camera" },
			} },
			{ title = "Equip Melee", rows = {
				{ kind = "toggle", name = "Enabled", key = "Equip Melee Enabled", glyph = "👁", value = true, desc = "Show this button on your screen" },
				{ kind = "toggle", name = "Custom", key = "Equip Melee Custom", glyph = "⚙", value = false, desc = "[Advanced] Give this button its own transparency instead of the global one" },
				{ kind = "slider", name = "Transparency", key = "Equip Melee Transparency", glyph = "◐", level = 2, showIf = "Equip Melee Custom", min = 0, max = 100, step = 5, arrow = 10, value = 50, fmt = pct, desc = "This button's own transparency" },
				{ kind = "toggle", name = "Camera Sinking", key = "Equip Melee Camera Sinking", glyph = "⇩", level = 2, showIf = "Equip Melee Custom", value = true, desc = "Dragging from this button also turns the camera" },
			} },
			{ title = "Equip Gadget", rows = {
				{ kind = "toggle", name = "Enabled", key = "Equip Gadget Enabled", glyph = "👁", value = true, desc = "Show this button on your screen" },
				{ kind = "toggle", name = "Custom", key = "Equip Gadget Custom", glyph = "⚙", value = false, desc = "[Advanced] Give this button its own transparency instead of the global one" },
				{ kind = "slider", name = "Transparency", key = "Equip Gadget Transparency", glyph = "◐", level = 2, showIf = "Equip Gadget Custom", min = 0, max = 100, step = 5, arrow = 10, value = 50, fmt = pct, desc = "This button's own transparency" },
				{ kind = "toggle", name = "Camera Sinking", key = "Equip Gadget Camera Sinking", glyph = "⇩", level = 2, showIf = "Equip Gadget Custom", value = true, desc = "Dragging from this button also turns the camera" },
			} },
			{ title = "Shoulder Swap", rows = {
				{ kind = "toggle", name = "Enabled", key = "Shoulder Swap Enabled", glyph = "👁", value = true, desc = "Show this button on your screen" },
				{ kind = "toggle", name = "Custom", key = "Shoulder Swap Custom", glyph = "⚙", value = false, desc = "[Advanced] Give this button its own transparency instead of the global one" },
				{ kind = "slider", name = "Transparency", key = "Shoulder Swap Transparency", glyph = "◐", level = 2, showIf = "Shoulder Swap Custom", min = 0, max = 100, step = 5, arrow = 10, value = 50, fmt = pct, desc = "This button's own transparency" },
				{ kind = "toggle", name = "Camera Sinking", key = "Shoulder Swap Camera Sinking", glyph = "⇩", level = 2, showIf = "Shoulder Swap Custom", value = true, desc = "Dragging from this button also turns the camera" },
			} },
			{ title = "Open Scoreboard", rows = {
				{ kind = "toggle", name = "Enabled", key = "Open Scoreboard Enabled", glyph = "👁", value = true, desc = "Show this button on your screen" },
				{ kind = "toggle", name = "Custom", key = "Open Scoreboard Custom", glyph = "⚙", value = false, desc = "[Advanced] Give this button its own transparency instead of the global one" },
				{ kind = "slider", name = "Transparency", key = "Open Scoreboard Transparency", glyph = "◐", level = 2, showIf = "Open Scoreboard Custom", min = 0, max = 100, step = 5, arrow = 10, value = 50, fmt = pct, desc = "This button's own transparency" },
				{ kind = "toggle", name = "Camera Sinking", key = "Open Scoreboard Camera Sinking", glyph = "⇩", level = 2, showIf = "Open Scoreboard Custom", value = true, desc = "Dragging from this button also turns the camera" },
			} },
		} },
		-- Account: from ref_59. Dropdown option lists other than the shown value are a guess.
		{ name = "Account", glyph = "☻", icon = "account", sections = {
			{ title = "Notifications", rows = {
				{ kind = "dropdown", name = "Delivery Mode", icon = "inking", options = { "Instant", "Disabled" }, value = "Instant", desc = "Whether lobby messages (rewards, matches found) pop up at the top of the screen" },
			} },
		} },
	},
	-- Parked rows (UI session 2026-10-16): Tacticals has nothing behind them yet (no wraps, inking style, music, finishers
	-- with sound, quick-attack variants, gamepad camera / prompts; walking is Roblox's own WASD). Not shown, not saved
	-- (Sanitize only knows tabs). Move a row back into its tab when the system it controls exists.
	parked = {
		{ kind = "toggle", name = "Optimized Wraps", icon = "wraps", value = false, desc = "Hides other players' weapon wraps for better performance. You still see your own" },
		{ kind = "toggle", name = "Weapon Inking", icon = "inking", value = true, desc = "Draws a dark cartoon outline around weapons" },
		{ kind = "slider", name = "Music Volume", icon = "music", min = 0, max = 100, step = 5, arrow = 10, value = 50, fmt = pct, desc = "Changes the volume of the lobby and match music" },
		{ kind = "slider", name = "Finisher Volume", icon = "effects", min = 0, max = 100, step = 5, arrow = 10, value = 100, fmt = pct, desc = "Changes the volume of finishing moves" },
		{ kind = "toggle", name = "Mute Other Finishers", icon = "mute", level = 2, value = false, desc = "Only your own finishers make a sound" },
		{ kind = "toggle", name = "Easy Gun Bash", key = "Easy Quick Attack", icon = "effects2", value = true, desc = "Gun bash with a single press, even while aiming" },
		{ kind = "toggle", name = "Bash Keeps Aim", key = "Quick Attack Keeping", icon = "inking", value = true, desc = "Go straight back to aiming after a gun bash" },
		{ kind = "slider", name = "Keep Window", icon = "inking", level = 2, min = 0, max = 1, step = 0.05, arrow = 0.05, value = 0.25, fmt = function(v) return string.format("%.2f", v) end, desc = "[Advanced] How long, in seconds, after a bash you stay ready to aim again. At 0 you always do" },
		{ kind = "slider", name = "Joystick Deadzone", icon = "padded", min = 0, max = 100, step = 5, arrow = 5, value = 25, fmt = pct, desc = "How far a stick must move before it counts" },
		{ kind = "dropdown", name = "Control Scheme", icon = "keyboard", options = { "Automatic", "Keyboard", "Controller", "Touch" }, value = "Automatic", desc = "Which button prompts the game shows. Automatic follows what you last touched" },
		{ kind = "bind", name = "Walk Forward", icon = "tri_up", value = { "W", "Up", "", "" } },
		{ kind = "bind", name = "Walk Backward", icon = "tri_down", value = { "S", "Down", "", "" } },
		{ kind = "bind", name = "Strafe Left", icon = "tri_left", value = { "A", "", "", "" } },
		{ kind = "bind", name = "Strafe Right", icon = "tri_right", value = { "D", "", "", "" } },
	},
}