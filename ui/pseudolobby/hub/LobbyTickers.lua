-- Scrolling LED tickers + small status monitors around the lobby (live: armory reset, queues, range best, top wins)
-- (2026-10-21, RIVALS pass) Rubik ticker in cream with field-green keys (RichText) and the top-wins name in comic yellow (#1 only);
-- the ticker countdown shows hours + minutes so its text (and width) changes once a minute, not every second, and the scroll
-- runs in Scale. Monitors: tan Rubik label, big Oswald number, a tinted flat glyph and a field-green band (was a thin accent
-- bar); a card change pops the content, a changing number counts up.
local Players=game:GetService("Players") local RS=game:GetService("ReplicatedStorage") local HttpService=game:GetService("HttpService") local RunService=game:GetService("RunService") local TS=game:GetService("TweenService")
local folder=workspace:WaitForChild("LobbyMap"):WaitForChild("Screens",30) if not folder then return end
local CREAM=Color3.fromRGB(236,230,210) local TAN=Color3.fromRGB(226,210,172) local GREEN=Color3.fromRGB(141,191,90) local GOLD=Color3.fromRGB(255,212,0) local INK=Color3.fromRGB(10,12,10)
local TITLE=Font.new("rbxasset://fonts/families/Oswald.json",Enum.FontWeight.Bold) local BOLD=Font.new("rbxassetid://12187365977",Enum.FontWeight.Bold)
local ICON={gadget="rbxassetid://122224655406431",matches="rbxassetid://125681613105062",elims="rbxassetid://83789042758416",wins="rbxassetid://120316362189428"}
local SEP="      •      "
local POP=TweenInfo.new(0.35,Enum.EasingStyle.Back,Enum.EasingDirection.Out) local COUNT=TweenInfo.new(0.6,Enum.EasingStyle.Quad,Enum.EasingDirection.Out)
local function left() local now=os.time() local nxt=(math.floor(now/86400)+1)*86400 return nxt-now end
local function resetIn() local d=left() return string.format("%02d:%02d:%02d",d//3600,(d%3600)//60,d%60) end
local function resetHM() local d=left() return string.format("%dH %02dM",d//3600,(d%3600)//60) end
local function esc(s) return (tostring(s):gsub("&","&amp;"):gsub("<","&lt;"):gsub(">","&gt;")) end
local function key(s) return '<font color="#8DBF5A">'..s..'</font>' end
local function queues()
	local ok,t=pcall(HttpService.JSONDecode,HttpService,RS:GetAttribute("MM_Counts") or "{}") if not ok or type(t)~="table" then return nil end
	local n=0 for _,v in pairs(t) do if type(v)=="number" then n+=v elseif type(v)=="table" then for _,w in pairs(v) do if type(w)=="number" then n+=w end end end end return n
end
local function topWins()
	local v=RS:FindFirstChild("LobbyTopWins") if not v then return nil end
	local ok,t=pcall(HttpService.JSONDecode,HttpService,v.Value) if ok and type(t)=="table" and t[1] then return t[1] end
end
local function message()
	local parts={key("DAILY ARMORY RESET IN").." "..resetHM(),"1V1  •  2V2  •  3V3 QUEUES OPEN",key("OPERATORS ONLINE").." "..#Players:GetPlayers()}
	local q=queues() if q and q>0 then table.insert(parts,key("SEARCHING NOW").." "..q) end
	local bt=RS:GetAttribute("RangeBestTime") if bt and bt>0 then table.insert(parts,key("REACTION RANGE RECORD").." "..string.format("%.2fs  •  %s",bt,esc(RS:GetAttribute("RangeBestName") or ""))) else table.insert(parts,key("REACTION RANGE").." SET THE FIRST RECORD") end
	local tw=topWins() if tw then table.insert(parts,key("MOST WINS")..' <font color="#FFD400">'..esc(tw.n or "?").."</font>  •  "..tostring(tw.w or 0)) end
	table.insert(parts,"PICK YOUR KIT AT THE GUN WALL")
	return table.concat(parts,SEP)
end
local tickers,monitors={},{}
for _,m in ipairs(folder:GetChildren()) do
	local f=m:FindFirstChild("Face") if f then
		local g=Instance.new("SurfaceGui") g.Face=Enum.NormalId.Front g.SizingMode=Enum.SurfaceGuiSizingMode.PixelsPerStud g.PixelsPerStud=40 g.LightInfluence=0 g.Brightness=1.3 g.ClipsDescendants=true g.Parent=f
		local bg=Instance.new("Frame",g) bg.Size=UDim2.fromScale(1,1) bg.BackgroundColor3=INK bg.BorderSizePixel=0 bg.ClipsDescendants=true
		if m:GetAttribute("Kind")=="Ticker" then
			local t=Instance.new("TextLabel",bg) t.BackgroundTransparency=1 t.Size=UDim2.fromScale(0,1) t.AutomaticSize=Enum.AutomaticSize.X t.FontFace=BOLD t.RichText=true t.TextSize=42 t.TextColor3=CREAM t.TextXAlignment=Enum.TextXAlignment.Left
			table.insert(tickers,{f=f,bg=bg,t=t,x=0})
		else
			local hold=Instance.new("Frame",bg) hold.AnchorPoint=Vector2.new(0.5,0.5) hold.Position=UDim2.fromScale(0.5,0.5) hold.Size=UDim2.fromScale(1,1) hold.BackgroundTransparency=1
			local sc=Instance.new("UIScale",hold)
			local h=Instance.new("TextLabel",hold) h.BackgroundTransparency=1 h.Position=UDim2.fromScale(0.06,0.08) h.Size=UDim2.fromScale(0.88,0.2) h.FontFace=BOLD h.TextScaled=true h.TextColor3=TAN h.TextXAlignment=Enum.TextXAlignment.Left
			local ic=Instance.new("ImageLabel",hold) ic.BackgroundTransparency=1 ic.Position=UDim2.fromScale(0.06,0.34) ic.Size=UDim2.fromScale(0.22,0.42) ic.ScaleType=Enum.ScaleType.Fit
			local v=Instance.new("TextLabel",hold) v.BackgroundTransparency=1 v.Position=UDim2.fromScale(0.31,0.3) v.Size=UDim2.fromScale(0.63,0.5) v.FontFace=TITLE v.TextScaled=true v.TextColor3=CREAM v.TextXAlignment=Enum.TextXAlignment.Left
			local band=Instance.new("Frame",bg) band.Position=UDim2.fromScale(0,0.88) band.Size=UDim2.fromScale(1,0.12) band.BorderSizePixel=0 band.BackgroundColor3=GREEN
			local ug=Instance.new("UIGradient",band) ug.Rotation=90 ug.Color=ColorSequence.new(Color3.new(1,1,1),Color3.fromRGB(138,163,130))
			local nv=Instance.new("NumberValue")
			local mon={f=f,h=h,v=v,ic=ic,band=band,sc=sc,nv=nv,i=math.random(1,4)}
			nv.Changed:Connect(function(x) if mon.count then v.Text=tostring(math.round(x)) end end)
			table.insert(monitors,mon)
		end
	end
end
-- each card: label, value text, tint, glyph, number (when the value is a plain count, so it can tick up)
local CARDS={
	function() return "ARMORY RESET",resetIn(),CREAM,ICON.gadget end,
	function() local n=#Players:GetPlayers() return "OPERATORS ONLINE",tostring(n),GREEN,ICON.matches,n end,
	function() local bt=RS:GetAttribute("RangeBestTime") return "RANGE RECORD",(bt and bt>0) and string.format("%.2fs",bt) or "--.--",GREEN,ICON.elims end,
	function() local tw=topWins() return "MOST WINS",tw and (tostring(tw.n).." · "..tostring(tw.w)) or "—",GOLD,ICON.wins end,
}
local function show(m)
	local h,v,c,ic,num=CARDS[m.i]()
	if m.last~=m.i then
		m.last=m.i m.count=false m.num=num m.h.Text=h m.v.Text=v m.ic.Image=ic m.ic.ImageColor3=c m.band.BackgroundColor3=c if num then m.nv.Value=num end
		m.sc.Scale=0.9 TS:Create(m.sc,POP,{Scale=1}):Play()
	elseif num and m.num and num~=m.num then
		m.num=num m.count=true TS:Create(m.nv,COUNT,{Value=num}):Play()
	elseif not m.count then m.v.Text=v end
end
local cam=workspace.CurrentCamera
local function refreshText() local msg=message()..SEP local s=msg..msg for _,k in ipairs(tickers) do if k.t.Text~=s then k.t.Text=s end end end -- two equal halves, so the wrap is seamless
refreshText() for _,m in ipairs(monitors) do show(m) end
task.spawn(function() while true do task.wait(1) refreshText() for _,m in ipairs(monitors) do show(m) end end end)
task.spawn(function() while true do task.wait(5) for _,m in ipairs(monitors) do m.i=m.i%#CARDS+1 end end end)
RunService.RenderStepped:Connect(function(dt)
	for _,k in ipairs(tickers) do
		if (cam.CFrame.Position-k.f.Position).Magnitude<140 then
			local half=k.t.TextBounds.X/2 if half<10 then half=2000 end
			local w=k.bg.AbsoluteSize.X
			k.x=(k.x+dt*90)%half if w>0 then k.t.Position=UDim2.fromScale(-k.x/w,0) end
		end
	end
end)
