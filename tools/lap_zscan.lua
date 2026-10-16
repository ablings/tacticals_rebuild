-- tools/lap_zscan.lua (CLIENT, Play): for every lap stop, cast rays through a 64x40 pixel grid (FOV 70) and flag pixels whose
-- first two visible hits lie on the same plane (gap <= 0.012 along the ray, same facing) but belong to different parts:
-- the coplanar faces that z-fight. Parts with CanQuery off must have been made queryable first (lap session did that).
local STOPS = __STOPS__
local rp = RaycastParams.new(); rp.FilterType = Enum.RaycastFilterType.Exclude
local base = {game.Players.LocalPlayer.Character}
local cam = workspace.CurrentCamera
local agg = {}
local function vis(p) return p.Transparency < 0.95 and p.LocalTransparencyModifier < 1 end
for si, s in ipairs(STOPS) do
	local cf = CFrame.lookAt(s[2], s[3])
	local tanv = math.tan(math.rad(35)); local aspect = 1284 / 793
	for iy = 0, 39 do
		for ix = 0, 63 do
			local u = ((ix + 0.5) / 64 * 2 - 1) * tanv * aspect
			local v = (1 - (iy + 0.5) / 40 * 2) * tanv
			local dir = (cf.LookVector + cf.RightVector * u + cf.UpVector * v).Unit
			local ex = table.clone(base)
			rp.FilterDescendantsInstances = ex
			local h1 = workspace:Raycast(s[2], dir * 400, rp)
			local guard = 0
			while h1 and not vis(h1.Instance) and guard < 4 do table.insert(ex, h1.Instance); rp.FilterDescendantsInstances = ex; h1 = workspace:Raycast(s[2], dir * 400, rp); guard += 1 end
			if h1 then
				table.insert(ex, h1.Instance); rp.FilterDescendantsInstances = ex
				local h2 = workspace:Raycast(h1.Position - dir * 0.05, dir * 0.1, rp)
				if h2 and vis(h2.Instance) and h2.Instance ~= h1.Instance and h1.Normal:Dot(h2.Normal) > 0.99 then
					local gap = (h2.Position - h1.Position):Dot(dir)
					if math.abs(gap) <= 0.012 then
						local a, b = h1.Instance:GetFullName():gsub("Workspace.LobbyMap.", ""), h2.Instance:GetFullName():gsub("Workspace.LobbyMap.", "")
						if a > b then a, b = b, a end
						local k = a .. " | " .. b
						local e = agg[k] or {n = 0, stops = {}, at = h1.Position}
						e.n += 1; e.stops[s[1]] = true; agg[k] = e
					end
				end
			end
		end
		if iy % 10 == 0 then task.wait() end
	end
end
local l = {}
for k, e in pairs(agg) do
	local st = {} for n in pairs(e.stops) do table.insert(st, n) end
	table.insert(l, {e.n, string.format("%4d px  %s  at (%.1f,%.1f,%.1f)  [%s]", e.n, k, e.at.X, e.at.Y, e.at.Z, table.concat(st, ",", 1, math.min(#st, 4)))})
end
table.sort(l, function(x, y) return x[1] > y[1] end)
local o = {} for _, x in ipairs(l) do table.insert(o, x[2]) end
return #l .. " coplanar pairs\n" .. table.concat(o, "\n")
