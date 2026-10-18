-- Theme: tacticals' token set. Layout and component shapes follow the RIVALS-style Kit (ported from
-- rivals_practice); colours and fonts are the military skybase look: gunmetal panels, olive drab,
-- amber signal colour, bone-white text. Components read colours/fonts from here, never literals.
local Theme = {}

local function hex(s)
	return Color3.fromRGB(tonumber(s:sub(2, 3), 16), tonumber(s:sub(4, 5), 16), tonumber(s:sub(6, 7), 16))
end
Theme.hex = hex

Theme.color = {
	text = hex("#ECE8DA"),        -- bone white
	textDim = hex("#A7AD98"),     -- field grey
	textDark = hex("#11130E"),
	panel = hex("#0C0E0B"),       -- gunmetal, drawn see-through
	panelRaised = hex("#1D211A"),
	scrim = hex("#0A0D08"),
	white = hex("#F1EDE0"),       -- light controls (boxes, selected tabs)
	control = hex("#E4E0D2"),
	track = hex("#4A5038"),       -- olive drab slider track
	green = hex("#E8AC30"),       -- "on" state: amber
	red = hex("#D6403A"),
	redDark = hex("#9E2620"),
	badge = hex("#D6403A"),
	gold = hex("#E8AC30"),
	blue = hex("#8FA64A"),        -- secondary accent: olive
	disabled = hex("#575B4E"),
	olive = hex("#6B7A3A"),
	amber = hex("#E8AC30"),
}

-- vertical gradients, top -> bottom
Theme.gradient = {
	robux = { hex("#D6FF6E"), hex("#7DF632") },   -- Robux purchases keep Roblox green
	key = { hex("#FFE08A"), hex("#E09A18") },     -- amber: play / buy / claim
	blue = { hex("#B9CC7A"), hex("#5E7230") },    -- olive: secondary actions
	red = { hex("#F06A5E"), hex("#B3281F") },
	grey = { hex("#A9AC9F"), hex("#6C7064") },
}

-- Headings in Oswald (condensed, stencil-like); labels and body copy in Rubik (cloud font
-- 12187365977) at the weights the practice screens were tuned to.
local RUBIK = "rbxassetid://12187365977"
local OSWALD = "rbxasset://fonts/families/Oswald.json"
Theme.font = {
	display = Font.new(OSWALD, Enum.FontWeight.Bold),
	heavy = Font.new(RUBIK, Enum.FontWeight.SemiBold),
	bold = Font.new(RUBIK, Enum.FontWeight.SemiBold),
	medium = Font.new(RUBIK, Enum.FontWeight.Medium),
	chunky = Font.new(OSWALD, Enum.FontWeight.Bold), -- button words
}

-- panel transparencies (the lobby shows through, blurred)
Theme.alpha = { panel = 0.42, header = 0.25, bar = 0, scrim = 0.3 }

Theme.corner = 6
Theme.blur = 24 -- BlurEffect size behind menus
Theme.design = Vector2.new(1920, 1080) -- design canvas; screens lay out in these pixels

return Theme
