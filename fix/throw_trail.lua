-- fix/throw_trail.lua [TTRAIL] 2026-10-21 (Edward via the main PC: "throw feel like RIVALS" - a thin WHITE streak trail behind a thrown
-- gadget). Hooks GadgetManager's throwGravity ([RTHROW]), which every held throw goes through (frag / smoke / flash via throwGrenade,
-- sticky / thrown landmine via shared.TacThrowGravity): a white Trail between two attachments across the part, on until it first touches
-- something (when the low gravity ends), then it stops emitting and fades out. Rolls get none. Run after fix/rivals_throw.lua.
-- Both places. Idempotent; UNDO = true swaps back.
local UNDO = false --@UNDO
local GM = game:GetService("ServerScriptService"):FindFirstChild("GadgetManager", true)

local function patch(inst, edits)
	local s = inst.Source
	local out = {}
	for i, e in edits do
		local old, new = e[1], e[2]
		if UNDO then old, new = new, old end
		if s:find(new, 1, true) then table.insert(out, i .. "=") else
			local a, b = s:find(old, 1, true)
			assert(a, inst.Name .. " edit " .. i .. ": anchor not found")
			assert(not s:find(old, b + 1, true), inst.Name .. " edit " .. i .. ": anchor not unique")
			s = s:sub(1, a - 1) .. new .. s:sub(b + 1)
			table.insert(out, i .. "+")
		end
	end
	local f, err = loadstring(s)
	assert(f, inst.Name .. " would not parse: " .. tostring(err))
	if inst.Source ~= s then inst.Source = s end
	return inst.Name .. " " .. table.concat(out, " ")
end

return (UNDO and "UNDO " or "TTRAIL ") .. patch(GM, {
	{ "\tvf.Parent = part\n\tlocal conn\n",
	  "\tvf.Parent = part\n"
	  .. "\t-- [TTRAIL] RIVALS: a thin white streak behind the throw, until it first lands\n"
	  .. "\tlocal a0, a1 = Instance.new(\"Attachment\"), Instance.new(\"Attachment\")\n"
	  .. "\ta0.Position, a1.Position = Vector3.new(0, 0.12, 0), Vector3.new(0, -0.12, 0)\n"
	  .. "\ta0.Parent, a1.Parent = part, part\n"
	  .. "\tlocal trail = Instance.new(\"Trail\")\n"
	  .. "\ttrail.Name = \"ThrowTrail\"\n"
	  .. "\ttrail.Attachment0, trail.Attachment1 = a0, a1\n"
	  .. "\ttrail.Color = ColorSequence.new(Color3.new(1, 1, 1))\n"
	  .. "\ttrail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) })\n"
	  .. "\ttrail.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.2) })\n"
	  .. "\ttrail.Lifetime = 0.22\n"
	  .. "\ttrail.MinLength = 0.05\n"
	  .. "\ttrail.FaceCamera = true\n"
	  .. "\ttrail.LightEmission = 0.6\n"
	  .. "\ttrail.Parent = part\n"
	  .. "\tlocal conn\n" },
	{ "\t\tif vf.Parent then vf:Destroy() end\n\tend)\n",
	  "\t\tif vf.Parent then vf:Destroy() end\n"
	  .. "\t\ttrail.Enabled = false -- [TTRAIL] the streak ends where it lands\n"
	  .. "\tend)\n" },
})
