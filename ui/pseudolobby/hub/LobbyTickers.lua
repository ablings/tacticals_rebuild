-- Scrolling LED tickers + small status monitors around the lobby (live: armory reset, queues, range best, top wins)
local Players=game:GetService("Players") local RS=game:GetService("ReplicatedStorage") local HttpService=game:GetService("HttpService") local RunService=game:GetService("RunService")
local folder=workspace:WaitForChild("LobbyMap"):WaitForChild("Screens",30) if not folder then return end
local TEAL=Color3.fromRGB(255, 212, 0) local MAG=Color3.fromRGB(236, 232, 218) local VIO=Color3.fromRGB(176,120,255) local GREY=Color3.fromRGB(170,175,185)
local function resetIn() local now=os.time() local nxt=(math.floor(now/86400)+1)*86400 local d=nxt-now return string.format("%02d:%02d:%02d",d//3600,(d%3600)//60,d%60) end
local function queues()
	local ok,t=pcall(HttpService.JSONDecode,HttpService,RS:GetAttribute("MM_Counts") or "{}") if not ok or type(t)~="table" then return nil end
	local n=0 for _,v in pairs(t) do if type(v)=="number" then n+=v elseif type(v)=="table" then for _,w in pairs(v) do if type(w)=="number" then n+=w end end end end return n
end
local function topWins()
	local v=RS:FindFirstChild("LobbyTopWins") if not v then return nil end
	local ok,t=pcall(HttpService.JSONDecode,HttpService,v.Value) if ok and type(t)=="table" and t[1] then return t[1] end
end
local function message()
	local parts={"DAILY ARMORY RESET IN "..resetIn(),"1V1  ·  2V2  ·  3V3 QUEUES OPEN","OPERATORS ONLINE: "..#Players:GetPlayers()}
	local q=queues() if q and q>0 then table.insert(parts,"SEARCHING NOW: "..q) end
	local bt=RS:GetAttribute("RangeBestTime") if bt and bt>0 then table.insert(parts,string.format("REACTION RANGE RECORD %.2fs  ·  %s",bt,RS:GetAttribute("RangeBestName") or "")) else table.insert(parts,"REACTION RANGE: SET THE FIRST RECORD") end
	local tw=topWins() if tw then table.insert(parts,"MOST WINS: "..tostring(tw.n or "?").."  ·  "..tostring(tw.w or 0)) end
	table.insert(parts,"PICK YOUR KIT AT THE GUN WALL")
	return table.concat(parts,"      ◆      ")
end
local tickers,monitors={},{}
for _,m in ipairs(folder:GetChildren()) do
	local f=m:FindFirstChild("Face") if f then
		local g=Instance.new("SurfaceGui") g.Face=Enum.NormalId.Front g.SizingMode=Enum.SurfaceGuiSizingMode.PixelsPerStud g.PixelsPerStud=40 g.LightInfluence=0 g.Brightness=1.5 g.ClipsDescendants=true g.Parent=f
		local bg=Instance.new("Frame",g) bg.Size=UDim2.fromScale(1,1) bg.BackgroundColor3=Color3.fromRGB(8,10,13) bg.BorderSizePixel=0 bg.ClipsDescendants=true
		if m:GetAttribute("Kind")=="Ticker" then
			local t=Instance.new("TextLabel",bg) t.BackgroundTransparency=1 t.Size=UDim2.new(0,0,1,0) t.AutomaticSize=Enum.AutomaticSize.X t.Font=Enum.Font.GothamBold t.TextSize=42 t.TextColor3=TEAL t.TextXAlignment=Enum.TextXAlignment.Left
			table.insert(tickers,{f=f,t=t,x=0,w=g.AbsoluteSize.X})
		else
			local h=Instance.new("TextLabel",bg) h.BackgroundTransparency=1 h.Position=UDim2.fromScale(0.06,0.08) h.Size=UDim2.fromScale(0.88,0.22) h.Font=Enum.Font.GothamBold h.TextScaled=true h.TextColor3=GREY h.TextXAlignment=Enum.TextXAlignment.Left
			local v=Instance.new("TextLabel",bg) v.BackgroundTransparency=1 v.Position=UDim2.fromScale(0.06,0.34) v.Size=UDim2.fromScale(0.88,0.4) v.Font=Enum.Font.GothamBlack v.TextScaled=true v.TextColor3=Color3.new(1,1,1) v.TextXAlignment=Enum.TextXAlignment.Left
			local bar=Instance.new("Frame",bg) bar.Position=UDim2.fromScale(0.06,0.82) bar.Size=UDim2.fromScale(0.25,0.04) bar.BorderSizePixel=0 bar.BackgroundColor3=TEAL
			table.insert(monitors,{f=f,h=h,v=v,bar=bar,i=math.random(1,4)})
		end
	end
end
local CARDS={
	function() return "ARMORY RESET",resetIn(),MAG end,
	function() return "OPERATORS ONLINE",tostring(#Players:GetPlayers()),TEAL end,
	function() local bt=RS:GetAttribute("RangeBestTime") return "RANGE RECORD",(bt and bt>0) and string.format("%.2fs",bt) or "--.--",TEAL end,
	function() local tw=topWins() return "MOST WINS",tw and (tostring(tw.n).." · "..tostring(tw.w)) or "—",VIO end,
}
local cam=workspace.CurrentCamera
local function refreshText() local msg=message() for _,k in ipairs(tickers) do k.t.Text=msg.."      ◆      "..msg end end
refreshText()
task.spawn(function() while true do task.wait(1) refreshText() for _,m in ipairs(monitors) do local h,v,c=CARDS[m.i]() m.h.Text=h m.v.Text=v m.bar.BackgroundColor3=c end end end)
task.spawn(function() while true do task.wait(5) for _,m in ipairs(monitors) do m.i=m.i%#CARDS+1 end end end)
RunService.RenderStepped:Connect(function(dt)
	for _,k in ipairs(tickers) do
		if (cam.CFrame.Position-k.f.Position).Magnitude<140 then
			local half=k.t.TextBounds.X/2 if half<10 then half=2000 end
			k.x=(k.x-dt*90)%half k.t.Position=UDim2.fromOffset(-k.x,0)
		end
	end
end)
