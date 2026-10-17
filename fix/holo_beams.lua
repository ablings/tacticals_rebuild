-- fix/holo_beams.lua (2026-10-17 overnight glitch pass; overnight_report item 4, notes/particles.md "Pre-existing bug"):
-- the 6 duel-pad Holo beams rendered outside the Duels hall because their Attachments' local Position held WORLD
-- coordinates (beams at double the pad position; the 1v1 ones also kept the pre-rooms3 x -92.8). Each beam now runs
-- straight up under its Holo: from the pad floor (world y 20.7) to just under the hologram (world y 23.5), at the Holo's x/z.
-- The original local positions are kept in attribute HB_OrigPos. Idempotent.
-- `python tools/run_luau.py fix/holo_beams.lua UNDO` puts them back.
local UNDO = false --@UNDO
local FLOOR_Y, TOP_Y = 20.7, 23.5
local log = {}
for _, pad in workspace.LobbyMap.Duels:GetChildren() do
	local holo = pad:FindFirstChild("Holo")
	local beam = holo and holo:FindFirstChildWhichIsA("Beam", true)
	if beam and beam.Attachment0 and beam.Attachment1 and holo:IsA("BasePart") then
		for i, att in { beam.Attachment0, beam.Attachment1 } do
			if UNDO then
				local o = att:GetAttribute("HB_OrigPos")
				if typeof(o) == "Vector3" then att.Position = o; att:SetAttribute("HB_OrigPos", nil) end
			else
				if att:GetAttribute("HB_OrigPos") == nil then att:SetAttribute("HB_OrigPos", att.Position) end
				local y = i == 1 and FLOOR_Y or TOP_Y
				att.Position = att.Parent.CFrame:PointToObjectSpace(Vector3.new(holo.Position.X, y, holo.Position.Z))
			end
		end
		table.insert(log, ("%s beam %s -> %s"):format(pad.Name, tostring(beam.Attachment0.WorldPosition), tostring(beam.Attachment1.WorldPosition)))
	end
end
return (UNDO and "UNDO\n" or "") .. table.concat(log, "\n")
