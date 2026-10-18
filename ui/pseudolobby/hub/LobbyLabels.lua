-- Floating station labels (fade with distance, gentle bob) + NPC speech bubbles
local Players=game:GetService("Players") local RunService=game:GetService("RunService") local PPS=game:GetService("ProximityPromptService") local TS=game:GetService("TweenService")
local plr=Players.LocalPlayer
local map=workspace:WaitForChild("LobbyMap") local folder=map:WaitForChild("Labels",30)
local ACC={Teal=Color3.fromRGB(138, 156, 74),Magenta=Color3.fromRGB(236, 232, 218),Violet=Color3.fromRGB(176,120,255)}
local labels={}
if folder then for _,a in ipairs(folder:GetChildren()) do
	local bb=Instance.new("BillboardGui") bb.Size=UDim2.fromScale(9,2.4) bb.LightInfluence=0 bb.AlwaysOnTop=false bb.Adornee=a bb.MaxDistance=a:GetAttribute("Dist")+10 bb.Parent=a
	local acc=ACC[a:GetAttribute("Accent")] or ACC.Teal
	local t=Instance.new("TextLabel",bb) t.BackgroundTransparency=1 t.Size=UDim2.fromScale(1,0.58) t.Font=Enum.Font.GothamBlack t.TextScaled=true t.TextColor3=Color3.new(1,1,1) t.Text=a:GetAttribute("Title")
	local st=Instance.new("UIStroke",t) st.Thickness=2 st.Transparency=0.4 st.Color=Color3.fromRGB(8,10,14)
	local bar=Instance.new("Frame",bb) bar.Position=UDim2.fromScale(0.35,0.6) bar.Size=UDim2.fromScale(0.3,0.035) bar.BorderSizePixel=0 bar.BackgroundColor3=acc
	local s=Instance.new("TextLabel",bb) s.BackgroundTransparency=1 s.Position=UDim2.fromScale(0,0.68) s.Size=UDim2.fromScale(1,0.3) s.Font=Enum.Font.GothamBold s.TextScaled=true s.TextColor3=acc s.Text=a:GetAttribute("Sub")
	labels[#labels+1]={a=a,bb=bb,t=t,s=s,bar=bar,st=st,base=a.Position,d=a:GetAttribute("Dist"),ph=math.random()*6}
end end
RunService.RenderStepped:Connect(function()
	local cam=workspace.CurrentCamera local cp=cam.CFrame.Position local tt=os.clock()
	for _,l in ipairs(labels) do
		local dist=(cp-l.base).Magnitude
		local f=math.clamp((dist-(l.d-12))/12,0,1) -- 0 visible .. 1 hidden
		local near=math.clamp((6-dist)/3,0,1) -- fade if you stand right under it
		local tr=math.max(f,near)
		l.t.TextTransparency=tr l.s.TextTransparency=tr l.bar.BackgroundTransparency=tr l.st.Transparency=0.4+0.6*tr
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
	local bb=Instance.new("BillboardGui") bb.Size=UDim2.fromOffset(260,70) bb.StudsOffset=Vector3.new(0,3.2,0) bb.LightInfluence=0 bb.MaxDistance=40 bb.Adornee=head bb.Parent=head
	local fr=Instance.new("Frame",bb) fr.Size=UDim2.fromScale(1,1) fr.BackgroundColor3=Color3.fromRGB(12,14,18) fr.BackgroundTransparency=0.15
	Instance.new("UICorner",fr).CornerRadius=UDim.new(0,10)
	local sk=Instance.new("UIStroke",fr) sk.Color=Color3.fromRGB(138, 156, 74) sk.Thickness=1.5 sk.Transparency=0.3
	local tl=Instance.new("TextLabel",fr) tl.BackgroundTransparency=1 tl.Size=UDim2.new(1,-20,1,-12) tl.Position=UDim2.fromOffset(10,6) tl.TextWrapped=true tl.TextScaled=true tl.Font=Enum.Font.GothamMedium tl.TextColor3=Color3.new(1,1,1)
	local line=lines[math.random(1,#lines)] tl.Text=""
	bubbles[npc]=bb
	task.spawn(function() for i=1,#line do if not bb.Parent then return end tl.Text=string.sub(line,1,i) task.wait(0.018) end end)
	task.delay(4.5,function() if bubbles[npc]==bb then TS:Create(fr,TweenInfo.new(0.3),{BackgroundTransparency=1}):Play() TS:Create(tl,TweenInfo.new(0.3),{TextTransparency=1}):Play() sk.Transparency=1 task.wait(0.35) bb:Destroy() bubbles[npc]=nil end end)
end)
