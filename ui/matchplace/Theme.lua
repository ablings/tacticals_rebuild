-- Theme: tacticals' token set. Layout and component shapes follow the RIVALS-style Kit (ported from
-- rivals_practice); colours and fonts are the military skybase look: gunmetal panels, olive drab,
-- olive signal colour (pass 34: no amber), bone-white text. Components read colours/fonts from here, never literals.
local Theme = {}

local function hex(s)
	return Color3.fromRGB(tonumber(s:sub(2, 3), 16), tonumber(s:sub(4, 5), 16), tonumber(s:sub(6, 7), 16))
end
Theme.hex = hex

-- (2026-10-20, Edward: "the green ... is just ugly") palette for style D "Comic Ink", from game-UI colour practice:
-- 60/30/10 = dark see-through charcoal-navy panels / white + black ink / ONE vivid accent (comic yellow);
-- primary buttons bright blue (white text stays readable); teams blue vs orange (the colourblind-safe pair); no olive, no green.
Theme.color = {
	text = hex("#FFFFFF"),
	textDim = hex("#C3C7D4"),
	textDark = hex("#111114"),
	panel = hex("#0E1016"),       -- charcoal-navy, drawn see-through
	panelRaised = hex("#1B1F2A"),
	scrim = hex("#07080C"),
	white = hex("#FFFFFF"),       -- light controls (boxes, selected tabs)
	control = hex("#EEF0F5"),
	track = hex("#2A3040"),       -- slider track
	green = hex("#3A9BFF"),       -- "on" state (name kept): blue
	red = hex("#FF4D3A"),
	redDark = hex("#C22E1E"),
	badge = hex("#FF4D3A"),
	gold = hex("#FFD400"),        -- the accent: comic yellow
	blue = hex("#3A9BFF"),
	disabled = hex("#4A4F5C"),
	olive = hex("#FFD400"),       -- (name kept for old code: now the yellow accent)
	amber = hex("#FFD400"),
	ink = hex("#111114"),
	teamUs = hex("#7EE878"),
	teamThem = hex("#FF8076"),
}

-- vertical gradients, top -> bottom
Theme.gradient = {
	robux = { hex("#D6FF6E"), hex("#7DF632") },   -- Robux purchases keep Roblox green
	key = { hex("#5AB2FF"), hex("#1E63D6") },     -- primary: play / buy / claim (blue)
	blue = { hex("#2B3142"), hex("#161A24") },    -- secondary actions (dark navy)
	red = { hex("#FF6A4D"), hex("#C52A1A") },
	grey = { hex("#B5B9C4"), hex("#7A7F8C") },
	gun = { hex("#22262F"), hex("#101217") },      -- close / neutral
	yellow = { hex("#FFE14D"), hex("#F2B600") },  -- the accent as a fill (black text on it)
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
