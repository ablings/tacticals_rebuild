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
	green = hex("#6FA544"),       -- "on" state (name kept): field green
	red = hex("#FF4D3A"),
	redDark = hex("#C22E1E"),
	badge = hex("#FF4D3A"),
	gold = hex("#FFD400"),        -- (2026-10-21, Edward Q1) the comic yellow now ONLY marks #1 / rank-1 highlights
	blue = hex("#6FA544"),
	disabled = hex("#4A4F5C"),
	olive = hex("#8DBF5A"),       -- (2026-10-21, Edward Q1) done / ready = field green (was the yellow accent; name kept)
	amber = hex("#ECE6D2"),       -- (2026-10-21, Edward Q1) labels / icons = cream (was the yellow; amber is tutorial-only)
	ink = hex("#111114"),
	teamUs = hex("#E2D2AC"),
	teamThem = hex("#6E8C62"),
	-- (2026-10-21, RIVALS three-qualities pass) the lobby's own named tokens; screens move onto these instead of the
	-- olive / gold / amber aliases (which are the comic yellow)
	field = hex("#8DBF5A"),       -- primary / "go" / done: field green
	fieldDark = hex("#4C7A2E"),
	done = hex("#8DBF5A"),        -- claimed, complete, owned
	cream = hex("#ECE6D2"),       -- flat icons, words on dark plates
	tan = hex("#E2D2AC"),         -- secondary edges / labels (= teamUs)
	plate = hex("#181A15"),       -- dark plate behind secondary buttons
}

-- vertical gradients, top -> bottom
Theme.gradient = {
	robux = { hex("#8DBF5A"), hex("#4C7A2E") },   -- (lobby revamp Phase B, Edward OK: no neon lime) Robux buys = the field-green primary
	key = { hex("#8DBF5A"), hex("#4C7A2E") },     -- primary: play / buy / claim (2026-10-20, Edward: field green, the lobby's olive-lime family)
	blue = { hex("#2B3142"), hex("#161A24") },    -- secondary actions (dark navy)
	red = { hex("#FF6A4D"), hex("#C52A1A") },
	grey = { hex("#B5B9C4"), hex("#7A7F8C") },
	gun = { hex("#22262F"), hex("#101217") },      -- close / neutral
	yellow = { hex("#FFE14D"), hex("#F2B600") },  -- the accent as a fill (black text on it)
}

-- Headings in Oswald (condensed, stencil-like); labels and body copy in Rubik (cloud font 12187365977). (2026-10-21, Edward:
-- Gotham / Montserrat is THE "AI-generated UI" font, so the brief Phase B switch to Montserrat was reverted the same day.)
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
