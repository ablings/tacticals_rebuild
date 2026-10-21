-- fix/hub_settings_save.lua [HUBSETTINGS] 2026-10-20 (hub only): LobbyManager.SaveSettings re-applies the saved settings as
-- server-set Setting_* attributes (ServerScriptService.HubSettingsBridge -> shared.SettingsApply), like the match places.
-- Idempotent; UNDO swaps back.
local UNDO = false --@UNDO
local m = game:GetService("ServerScriptService"):FindFirstChild("LobbyManager", true)
local old = "\tPlayerStore.Set(player, { \"Settings\" }, SettingsConfig.Sanitize(settings))\n\treturn { ok = true } -- silent (no toast)\n"
local new = "\tPlayerStore.Set(player, { \"Settings\" }, SettingsConfig.Sanitize(settings))\n"
	.. "\tif shared.SettingsApply then task.spawn(shared.SettingsApply, player) end -- [HUBSETTINGS] others see the change\n"
	.. "\treturn { ok = true } -- silent (no toast)\n"
local s = m.Source
if UNDO then old, new = new, old end
if s:find(new, 1, true) then return UNDO and "already undone" or "already" end
local a, b = s:find(old, 1, true)
if not a then return "anchor not found (already patched another way?)" end
s = s:sub(1, a - 1) .. new .. s:sub(b + 1)
assert(loadstring(s), "would not parse")
m.Source = s
return "ok"
