-- Floating station labels (fade with distance, gentle bob) + NPC speech bubbles
-- (2026-10-21, RIVALS pass) Oswald title / Rubik sub with a thick dark text stroke, a chunky field-green bar on a darker lip
-- (was a thin accent line), accents remapped to our palette; bubbles are a square near-black plate with a lip and a tail
-- (no rounded corners or hairline stroke), sized in studs (Scale), and pop in.
local Players=game:GetService("Players") local RunService=game:GetService("RunService") local PPS=game:GetService("ProximityPromptService") local TS=game:GetService("TweenService")
local plr=Players.LocalPlayer
local map=workspace:WaitForChild("LobbyMap") local folder=map:WaitForChild("Labels",30)
local TITLE=Font.new("rbxassetid://12187365977",Enum.FontWeight.Bold) local BOLD=Font.new("rbxassetid://12187365977",Enum.FontWeight.Bold) local BODY=Font.new("rbxassetid://12187365977",Enum.FontWeight.Medium)
local CREAM=Color3.fromRGB(236,230,210) local INK=Color3.fromRGB(10,12,10) local LIP=Color3.fromRGB(4,5,4)
local ACC={Teal=Color3.fromRGB(141,191,90),Magenta=CREAM,Violet=Color3.fromRGB(226,210,172)} -- attribute names kept from the map
local ACCLIP={Teal=Color3.fromRGB(76,122,46),Magenta=Color3.fromRGB(150,140,112),Violet=Color3.fromRGB(150,132,92)}
local labels={}
if folder then for _,a in ipairs(folder:GetChildren()) do
	local bb=Instance.new("BillboardGui") bb.Size=UDim2.fromScale(9,2.4) bb.LightInfluence=0 bb.AlwaysOnTop=false bb.Adornee=a bb.MaxDistance=a:GetAttribute("Dist")+10 bb.Parent=a
	local key=ACC[a:GetAttribute("Accent")] and a:GetAttribute("Accent") or "Teal" local acc=ACC[key]
	local t=Instance.new("TextLabel",bb) t.BackgroundTransparency=1 t.Size=UDim2.fromScale(1,0.58) t.FontFace=TITLE t.TextScaled=true t.TextColor3=CREAM t.Text=a:GetAttribute("Title")
	local st=Instance.new("UIStroke",t) st.Thickness=3 st.Transparency=0.2 st.Color=INK
	local lip=Instance.new("Frame",bb) lip.Position=UDim2.fromScale(0.41,0.625) lip.Size=UDim2.fromScale(0.18,0.06) lip.BorderSizePixel=0 lip.BackgroundColor3=ACCLIP[key]
	local bar=Instance.new("Frame",bb) bar.Position=UDim2.fromScale(0.41,0.6) bar.Size=UDim2.fromScale(0.18,0.06) bar.BorderSizePixel=0 bar.BackgroundColor3=acc
	local s=Instance.new("TextLabel",bb) s.BackgroundTransparency=1 s.Position=UDim2.fromScale(0,0.7) s.Size=UDim2.fromScale(1,0.28) s.FontFace=BOLD s.TextScaled=true s.TextColor3=acc s.Text=a:GetAttribute("Sub")
	local ss=Instance.new("UIStroke",s) ss.Thickness=2.5 ss.Transparency=0.25 ss.Color=INK
	labels[#labels+1]={a=a,bb=bb,t=t,s=s,bar=bar,lip=lip,st=st,ss=ss,base=a.Position,d=a:GetAttribute("Dist"),ph=math.random()*6}
end end
RunService.RenderStepped:Connect(function()
	local cam=workspace.CurrentCamera local cp=cam.CFrame.Position local tt=os.clock()
	for _,l in ipairs(labels) do
		local dist=(cp-l.base).Magnitude
		local f=math.clamp((dist-(l.d-12))/12,0,1) -- 0 visible .. 1 hidden
		local near=math.clamp((6-dist)/3,0,1) -- fade if you stand right under it
		local tr=math.max(f,near)
		l.t.TextTransparency=tr l.s.TextTransparency=tr l.bar.BackgroundTransparency=tr l.lip.BackgroundTransparency=tr l.st.Transparency=0.2+0.8*tr l.ss.Transparency=0.25+0.75*tr
		if tr<1 then l.bb.StudsOffsetWorldSpace=Vector3.new(0,math.sin(tt*1.4+l.ph)*0.15,0) end
	end
end)
-- NPC speech bubbles
local bubbles={}
PPS.PromptTriggered:Connect(function(prompt,who)
	if who~=plr then return end
	local raw=prompt:GetAttribute("TalkLines") if not raw then return end
	local lines=string.split(raw,"|") local host=prompt.Parent
	local npc=host.Parent local head=npc:FindFirstChild("Head") or host
	local old=bubbles[npc] if old then old:Destroy() end
	local bb=Instance.new("BillboardGui") bb.Size=UDim2.fromScale(6.5,1.9) bb.StudsOffset=Vector3.new(0,3.2,0) bb.LightInfluence=0 bb.MaxDistance=40 bb.Adornee=head bb.Parent=head
	local hold=Instance.new("Frame",bb) hold.AnchorPoint=Vector2.new(0.5,1) hold.Position=UDim2.fromScale(0.5,1) hold.Size=UDim2.fromScale(1,1) hold.BackgroundTransparency=1
	local sc=Instance.new("UIScale",hold) sc.Scale=0.8 TS:Create(sc,TweenInfo.new(0.3,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=1}):Play()
	local tail=Instance.new("Frame",hold) tail.AnchorPoint=Vector2.new(0.5,0.5) tail.Position=UDim2.fromScale(0.5,0.8) tail.Size=UDim2.fromScale(0.07,0.07) tail.SizeConstraint=Enum.SizeConstraint.RelativeXX tail.Rotation=45 tail.BorderSizePixel=0 tail.BackgroundColor3=INK tail.BackgroundTransparency=0.1
	local lip=Instance.new("Frame",hold) lip.Position=UDim2.fromScale(0,0.08) lip.Size=UDim2.fromScale(1,0.72) lip.BorderSizePixel=0 lip.BackgroundColor3=LIP lip.BackgroundTransparency=0.1
	local fr=Instance.new("Frame",hold) fr.Size=UDim2.fromScale(1,0.74) fr.BorderSizePixel=0 fr.BackgroundColor3=INK fr.BackgroundTransparency=0.1
	local tl=Instance.new("TextLabel",fr) tl.BackgroundTransparency=1 tl.Size=UDim2.fromScale(0.92,0.8) tl.Position=UDim2.fromScale(0.04,0.1) tl.TextWrapped=true tl.TextScaled=true tl.FontFace=BODY tl.TextColor3=CREAM
	local line=lines[math.random(1,#lines)] tl.Text=""
	bubbles[npc]=bb
	task.spawn(function() for i=1,#line do if not bb.Parent then return end tl.Text=string.sub(line,1,i) task.wait(0.018) end end)
	task.delay(4.5,function() if bubbles[npc]==bb then local ti=TweenInfo.new(0.3) for _,g in {fr,lip,tail} do TS:Create(g,ti,{BackgroundTransparency=1}):Play() end TS:Create(tl,ti,{TextTransparency=1}):Play() task.wait(0.35) bb:Destroy() bubbles[npc]=nil end end)
end)
