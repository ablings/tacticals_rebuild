-- grid_lib: world-aligned Texture offsets. A texture's (0,0) is the face's top-left corner seen from outside; U runs right, V runs
-- down. Lines sit at u = 5k - OffsetStudsU, so to put them on the world lattice (anchor + 5k) the offset is s * (origin - anchor)
-- mod tile, where s is the sign of the face axis along its world axis. TOP_UP / BOTTOM_UP: which local axis is "up" in the image.
local TOP_UP, BOTTOM_UP = Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) -- Top: tested 2026-10-26 (grid_test, out/arena_lookdev/gt_top); Bottom: by symmetry, untested
local FACES = {
	Top = { Vector3.new(0, 1, 0), TOP_UP }, Bottom = { Vector3.new(0, -1, 0), BOTTOM_UP },
	Front = { Vector3.new(0, 0, -1), Vector3.new(0, 1, 0) }, Back = { Vector3.new(0, 0, 1), Vector3.new(0, 1, 0) },
	Left = { Vector3.new(-1, 0, 0), Vector3.new(0, 1, 0) }, Right = { Vector3.new(1, 0, 0), Vector3.new(0, 1, 0) },
}
local function worldOffsets(p, faceName, anchor, tile)
	local f = FACES[faceName]
	local n, up = f[1], f[2]
	local right = (-n):Cross(up)
	local h = p.Size / 2
	local function half(v) return math.abs(v.X * h.X) + math.abs(v.Y * h.Y) + math.abs(v.Z * h.Z) end
	local o = p.CFrame:PointToWorldSpace(n * half(n) + up * half(up) - right * half(right))
	local function off(dirL)
		local d = p.CFrame:VectorToWorldSpace(dirL)
		for _, ax in { "X", "Y", "Z" } do
			if math.abs(d[ax]) > 0.999 then
				local s = d[ax] > 0 and 1 or -1
				local v = (s * (o[ax] - anchor[ax])) % tile
				if math.abs(v - tile) < 1e-3 or math.abs(v) < 1e-3 then v = 0 end
				return v
			end
		end
		return 0 -- face axis not on a world axis (diagonal / slope): leave it
	end
	return off(right), off(-up)
end
