-- [ADMIN] StarterPlayerScripts/AdminFeedback (LocalScript): the chat side of the admin framework (notes/admin_framework.md).
-- Sends ";cmd ..." (and the old "/scissors" etc.) to the server, and shows the replies as system lines in chat.
-- It decides nothing: the server checks every command and the caller's level. Original: ServerStorage._RebuildRemoved.ADMIN_AdminFeedback_Orig.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local feedback = ReplicatedStorage:WaitForChild("AdminFeedback")
local request = ReplicatedStorage:WaitForChild("AdminRequest")

local function hook(cmd: Instance)
	if not cmd:IsA("TextChatCommand") then return end
	cmd.Triggered:Connect(function(_source, text: string)
		request:FireServer(text)
	end)
end
local folder = TextChatService:WaitForChild("AdminCommands")
for _, cmd in folder:GetChildren() do hook(cmd) end
folder.ChildAdded:Connect(hook)

local function escape(s: string): string
	return (string.gsub(string.gsub(string.gsub(s, "&", "&amp;"), "<", "&lt;"), ">", "&gt;"))
end

-- kind: true = done (olive), false = error (red), "info" = plain output (cream), "announce" = a server message
local COLOURS = { ok = "#B5C77A", bad = "#FF7060", info = "#ECE8DA", announce = "#8A9C4A" }
local channel
feedback.OnClientEvent:Connect(function(msg: string, kind)
	channel = channel or TextChatService:WaitForChild("TextChannels"):WaitForChild("RBXSystem")
	local key = kind == true and "ok" or (kind == false and "bad") or (kind == "announce" and "announce") or "info"
	local tag = key == "announce" and "[Server]" or "[Admin]"
	channel:DisplaySystemMessage(('<font color="%s"><b>%s</b> %s</font>'):format(COLOURS[key], tag, escape(tostring(msg))))
end)
