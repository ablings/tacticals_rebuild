-- mech_dive_install.lua : the jump dive starts only from a real jump (Edward 2026-10-16: "the dive mechanic also works when
-- vaulting; it should only be when jumping").
-- CoverController.onJumpKey dived on ANY two Space presses within Config.DiveDoubleTap (0.35 s): Space that started a vault
-- then Space again dove out of the vault (JumpDive even cut the vault short on purpose), and so did two taps in cover or a tap
-- whose hop was refused (shot lock / not grounded) - dives with no jump at all.
-- Now the double tap also needs: a real hop started by onJumpKey within the double-tap window (lastHopAt), no vault in
-- progress, and controller.IsHopping() (still in the air from it: hop lock or Jumping / Freefall). Dash (E move) already
-- blocked the dive (`not move`); a slide has no jump of its own, so Space there hops first and the dive after it is a jump dive.
-- Three marked edits ("-- [MECH] dive only from jump (Edward 2026-10-16)"): a new local, the double-tap condition, and the hop
-- stamping lastHopAt. Works in both places (lobby Tacticals_rebuild.rbxl and the match place, whose CoverController has the
-- EAutoRush tutorial line: untouched, the anchors are elsewhere).
-- CoverController is the UI session's [SET] file: merge the same 3 edits into its source copy (ui/set/CoverController.lua).
-- Idempotent. Backup once: ServerStorage._RebuildRemoved.MECH_CoverController_Orig. UNDO reverts the marked edits in place.
-- Lobby:  python tools/run_luau.py fix/mech_dive_install.lua [UNDO]
-- Match:  same code through mcpcli.py with studio 331cb3a0 (run_luau.py is hard-wired to the lobby).
local UNDO = false --@UNDO

local SS = game:GetService("ServerStorage")
local ctrl = game.StarterPlayer.StarterPlayerScripts.Client.Controllers.CoverController
local BAK = "MECH_CoverController_Orig"
local MARK = "-- [MECH] dive only from jump (Edward 2026-10-16)"

local EDITS = {
	{
		old = "local lastSpaceAt = 0 -- double-tap Space = jump dive\n",
		new = "local lastSpaceAt = 0 -- double-tap Space = jump dive\n"
			.. "local lastHopAt = 0 " .. MARK .. ": when onJumpKey last started a real hop\n",
	},
	{
		old = "\tif doubleTap and isAlive() and not dive and not move and controller.JumpDive() then\n",
		new = "\t" .. MARK .. ": the first tap must have been a real hop and you're still in the air from it\n"
			.. "\t-- (never out of a vault, from cover or off the ground)\n"
			.. "\tlocal fromJump = now - lastHopAt < (Config.DiveDoubleTap or 0.35) and not vault and controller.IsHopping()\n"
			.. "\tif doubleTap and fromJump and isAlive() and not dive and not move and controller.JumpDive() then\n",
	},
	{
		old = "\thopLockUntil = os.clock() + 0.2\n",
		new = "\thopLockUntil = os.clock() + 0.2\n"
			.. "\tlastHopAt = os.clock() " .. MARK .. "\n",
	},
}

local function plainCount(s, p)
	local n, i = 0, 1
	while true do
		local a, b = s:find(p, i, true)
		if not a then return n end
		n += 1; i = b + 1
	end
end
local function replaceOnce(s, a, b)
	local i, j = s:find(a, 1, true)
	return s:sub(1, i - 1) .. b .. s:sub(j + 1)
end

local store = SS:FindFirstChild("_RebuildRemoved")
local src = ctrl.Source

if UNDO then
	local n = 0
	for _, e in EDITS do
		if plainCount(src, e.new) == 1 then src = replaceOnce(src, e.new, e.old); n += 1 end
	end
	local bak = store and store:FindFirstChild(BAK)
	if n == #EDITS then
		ctrl.Source = src
		if bak then bak:Destroy() end
		return "UNDO mech_dive: 3 marked edits reverted in place"
	elseif src:find(MARK, 1, true) and bak then
		ctrl.Source = bak.Source; bak:Destroy()
		return "UNDO mech_dive: marked edits changed by hand, full backup restored"
	elseif n > 0 then
		ctrl.Source = src
		return "UNDO mech_dive: " .. n .. " of 3 edits reverted (others not found)"
	end
	return "UNDO mech_dive: not patched, left as is"
end

if src:find(MARK, 1, true) then
	local ok = 0
	for _, e in EDITS do if plainCount(src, e.new) == 1 then ok += 1 end end
	return "mech_dive: already patched (" .. ok .. "/3 marked edits present)"
end
for i, e in EDITS do
	local c = plainCount(src, e.old)
	if c ~= 1 then return "ERROR mech_dive: anchor " .. i .. " found " .. c .. " times: nothing changed" end
end
if not store then store = Instance.new("Folder"); store.Name = "_RebuildRemoved"; store.Parent = SS end
if not store:FindFirstChild(BAK) then
	local bak = ctrl:Clone(); bak.Name = BAK; bak.Parent = store
end
for _, e in EDITS do src = replaceOnce(src, e.old, e.new) end
ctrl.Source = src
return "mech_dive: CoverController patched (3 marked edits); backup " .. BAK
