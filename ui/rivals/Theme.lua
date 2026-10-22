-- Theme: the RIVALS-style token set (wiki: RIVALS UI - Design System). Values measured from the
-- un-dimmed captures (ref_21+). Components read colours/fonts from here, never literals.
local Theme = {}

local function hex(s)
	return Color3.fromRGB(tonumber(s:sub(2, 3), 16), tonumber(s:sub(4, 5), 16), tonumber(s:sub(6, 7), 16))
end
Theme.hex = hex

Theme.color = {
	text = hex("#FFFFFF"),
	textDim = hex("#BDB8C2"),
	textDark = hex("#000000"),
	panel = hex("#0B080C"),
	panelRaised = hex("#1B131C"),
	scrim = hex("#140C1C"),
	white = hex("#FFFFFF"),
	control = hex("#F2F2F2"),
	track = hex("#4E4752"),
	green = hex("#65FE32"),
	red = hex("#E54343"),
	redDark = hex("#B32222"),
	badge = hex("#FF3233"),
	gold = hex("#FFD701"),
	blue = hex("#03BFFF"),
	disabled = hex("#585357"),
}

-- vertical gradients, top -> bottom
Theme.gradient = {
	robux = { hex("#D6FF6E"), hex("#7DF632") },
	key = { hex("#FFFDB5"), hex("#EFCF0F") },
	blue = { hex("#B8EDFF"), hex("#0365FF") },
	red = { hex("#FF6B6B"), hex("#D42A2A") },
	grey = { hex("#B5B5B5"), hex("#7A7A7A") },
}

-- RIVALS settings use Rubik (Roblox cloud font, Creator Store asset 12187365977), matched against
-- ref_53 letter by letter: section headers = Bold at 61, labels/values = SemiBold, descriptions = Medium.
local RUBIK = "rbxassetid://12187365977"
Theme.font = {
	display = Font.new(RUBIK, Enum.FontWeight.ExtraBold), -- section headers at 61. ref_53 stem/cap 0.286 sits between Bold 0.271 and ExtraBold 0.322; Edward reads it as the bolder one
	heavy = Font.new(RUBIK, Enum.FontWeight.SemiBold), -- row labels, detail title, tab labels, values
	bold = Font.new(RUBIK, Enum.FontWeight.SemiBold),
	medium = Font.new(RUBIK, Enum.FontWeight.Medium), -- descriptions, hints
	chunky = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular), -- button words (Join, Verify)
}

-- panel transparencies (the lobby shows through, blurred)
-- measured on ref_53 by inside/outside brightness: headers transparency ~0.28, rows ~0.45
Theme.alpha = { panel = 0.45, header = 0.28, bar = 0, scrim = 0.3 } -- scrim: 0.12 too dark, 0.6 too see-through, 0.38 still a touch light (Edward)

Theme.corner = 8
Theme.blur = 24 -- BlurEffect size behind menus
Theme.design = Vector2.new(1920, 1080) -- design canvas; screens lay out in these pixels

return Theme
