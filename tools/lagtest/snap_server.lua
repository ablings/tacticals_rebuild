local S = game:GetService("Stats")
local out = { label = "{{LABEL}}" }
out.memTotal = math.floor(S:GetTotalMemoryUsageMb())
local mem = {}
for _, tag in Enum.DeveloperMemoryTag:GetEnumItems() do
  local ok, v = pcall(function() return S:GetMemoryUsageMbForTag(tag) end)
  if ok and v and v >= 1 then mem[tag.Name] = math.floor(v * 10) / 10 end
end
out.mem = mem
out.recvKbps = math.floor(S.DataReceiveKbps * 10) / 10
out.sendKbps = math.floor(S.DataSendKbps * 10) / 10
out.physSend = math.floor(S.PhysicsSendKbps * 10) / 10
out.heartbeatMs = math.floor(S.HeartbeatTimeMs * 100) / 100
out.physicsMs = math.floor(S.PhysicsStepTimeMs * 100) / 100
out.instances, out.primitives, out.moving, out.contacts = S.InstanceCount, S.PrimitivesCount, S.MovingPrimitivesCount, S.ContactsCount
out.players = #game:GetService("Players"):GetPlayers()
out.state = game:GetService("ReplicatedStorage"):GetAttribute("MatchState")
local ws = S:FindFirstChild("Workspace")
local hb = ws and ws:FindFirstChild("Heartbeat"); out.heartbeatHz = hb and hb:GetValue()
return game:GetService("HttpService"):JSONEncode(out)
