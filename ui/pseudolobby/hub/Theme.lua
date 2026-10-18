-- Theme: tacticals' token set. Layout and component shapes follow the RIVALS-style Kit (ported from
-- rivals_practice); colours and fonts are the military skybase look: gunmetal panels, olive drab,
-- olive signal colour (pass 34: no amber), bone-white text. Components read colours/fonts from here, never literals.
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
	green = hex("#8A9C4A"),       -- "on" state: olive (pass 34, was amber)
	red = hex("#D6403A"),
	redDark = hex("#9E2620"),
	badge = hex("#D6403A"),
	gold = hex("#ECE8DA"),
	blue = hex("#8FA64A"),        -- secondary accent: olive
	disabled = hex("#575B4E"),
	olive = hex("#6B7A3A"),
	amber = hex("#8A9C4A"),     -- (pass 34: no amber; kept as a name)
}

-- vertical gradients, top -> bottom
Theme.gradient = {
	robux = { hex("#D6FF6E"), hex("#7DF632") },   -- Robux purchases keep Roblox green
	key = { hex("#9DB05A"), hex("#5B6E2C") },     -- olive: play / buy / claim (pass 34)
	blue = { hex("#4A5142"), hex("#23271F") },    -- gunmetal: secondary actions (pass 34)
	red = { hex("#F06A5E"), hex("#B3281F") },
	grey = { hex("#A9AC9F"), hex("#6C7064") },
	gun = { hex("#2E322A"), hex("#151813") },      -- close / neutral (pass 34)
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

Theme.corner = 3
Theme.blur = 24 -- BlurEffect size behind menus
Theme.design = Vector2.new(1920, 1080) -- design canvas; screens lay out in these pixels

return Theme
