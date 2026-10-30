-- Client (or Edit): start a frame-time sampler in this VM. MODE=start | mark NAME | report T0 T1 (seconds back) | reset
local RS = game:GetService("RunService")
_G.LAG = _G.LAG or { dt = {}, t = {}, n = 0, marks = {} }
local L = _G.LAG
local mode, a, b = "{{MODE}}", "{{A}}", "{{B}}"
if mode == "start" or mode == "reset" then
  if L.conn then L.conn:Disconnect() end
  L.dt, L.t, L.n, L.marks = {}, {}, 0, {}
  L.conn = RS.RenderStepped:Connect(function(dt)
    L.n += 1; local i = ((L.n - 1) % 30000) + 1; L.dt[i] = dt; L.t[i] = os.clock()
  end)
  return "sampler on, clock " .. os.clock()
elseif mode == "mark" then
  table.insert(L.marks, { a, os.clock() }); return "mark " .. a .. " " .. os.clock()
elseif mode == "report" then
  -- window: from mark A to mark B (names) or last A seconds if A is a number
  local t0, t1
  local function markT(name) for i = #L.marks, 1, -1 do if L.marks[i][1] == name then return L.marks[i][2] end end end
  if tonumber(a) then t1 = os.clock(); t0 = t1 - tonumber(a) else t0 = markT(a); t1 = (b ~= "" and b ~= "{{B}}" and markT(b)) or os.clock() end
  if not t0 then return "no mark " .. a end
  local xs = {}
  for i = 1, math.min(L.n, 30000) do if L.t[i] and L.t[i] >= t0 and L.t[i] <= t1 then table.insert(xs, L.dt[i]) end end
  if #xs < 5 then return "frames " .. #xs end
  local sum = 0; for _, d in xs do sum += d end
  table.sort(xs)
  local p99 = xs[math.max(1, math.floor(#xs * 0.99))]
  local p999 = xs[math.max(1, math.floor(#xs * 0.999))]
  local big = 0; for _, d in xs do if d > 0.05 then big += 1 end end
  return string.format("frames %d over %.1fs | avg %.1f fps (%.2f ms) | 1%%low %.1f fps (p99 %.1f ms) | p99.9 %.1f ms | max %.1f ms | >50ms %d",
    #xs, t1 - t0, #xs / sum, sum / #xs * 1000, 1 / p99, p99 * 1000, p999 * 1000, xs[#xs] * 1000, big)
end
return "?"
