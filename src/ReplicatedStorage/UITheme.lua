-- ReplicatedStorage.UITheme
-- Single source of truth for all UI colors, fonts, and sizing.
-- Warm & cozy: cream/linen backgrounds, antique gold highlights,
-- blush and sage accents — a stylish decorating-competition palette.

local UITheme = {}

-- ============================================================
-- PALETTE
-- ============================================================

UITheme.Color = {
	-- Backgrounds (warm cream / linen)
	Base           = Color3.fromRGB(252, 249, 242),
	Surface        = Color3.fromRGB(245, 240, 230),
	SurfaceRaised  = Color3.fromRGB(255, 253, 248),
	SurfaceHover   = Color3.fromRGB(238, 232, 218),
	Overlay        = Color3.fromRGB( 58,  48,  36),

	-- Primary accent: antique gold
	WarmPrimary    = Color3.fromRGB(212, 167,  82),
	WarmSecondary  = Color3.fromRGB(193, 138,  58),
	WarmSurface    = Color3.fromRGB(255, 245, 222),

	-- Cool accent (dusty blue)
	CoolPrimary    = Color3.fromRGB(120, 152, 168),
	CoolSecondary  = Color3.fromRGB( 88, 126, 148),
	Danger         = Color3.fromRGB(200,  72,  72),

	-- Feature accents
	Blush          = Color3.fromRGB(216, 154, 132),
	BlushDim       = Color3.fromRGB(245, 228, 220),
	Sage           = Color3.fromRGB(140, 166, 134),
	SageDim        = Color3.fromRGB(224, 236, 222),

	-- Legacy aliases
	Neon           = Color3.fromRGB(140, 166, 134),
	NeonDim        = Color3.fromRGB(224, 236, 222),
	RobotPurple    = Color3.fromRGB(168, 140, 180),

	-- Rarity tiers
	Common         = Color3.fromRGB(120, 152, 168),
	Uncommon       = Color3.fromRGB(140, 166, 134),
	Rare           = Color3.fromRGB(212, 167,  82),
	Legendary      = Color3.fromRGB(216, 154, 132),

	-- Text (warm browns)
	TextPrimary    = Color3.fromRGB( 58,  48,  36),
	TextSecondary  = Color3.fromRGB(118, 100,  78),
	TextMuted      = Color3.fromRGB(160, 148, 128),
	TextPositive   = Color3.fromRGB( 88, 148, 108),
	TextOnDark     = Color3.fromRGB(252, 249, 242),

	-- Strokes / dividers
	Stroke         = Color3.fromRGB(210, 200, 182),
	StrokeDim      = Color3.fromRGB(228, 222, 210),

	-- Utility
	Success        = Color3.fromRGB( 88, 168, 118),
	Disabled       = Color3.fromRGB(232, 228, 218),
	DisabledText   = Color3.fromRGB(180, 172, 156),

	-- Phase badge colors
	PhaseLobby     = Color3.fromRGB(168, 156, 136),
	PhaseShop      = Color3.fromRGB(140, 166, 134),
	PhaseStyle     = Color3.fromRGB(216, 154, 132),
	PhaseJudge     = Color3.fromRGB(212, 167,  82),
	PhaseResults   = Color3.fromRGB(120, 152, 168),
}

-- ============================================================
-- TYPOGRAPHY
-- ============================================================

UITheme.Font = {
	Heavy   = Enum.Font.FredokaOne,   -- display headings, big CTAs
	Bold    = Enum.Font.GothamBold,   -- sub-headings, item labels
	Medium  = Enum.Font.GothamMedium, -- body, descriptors
	Body    = Enum.Font.Gotham,       -- fine print, hints
}

-- ============================================================
-- SIZING
-- ============================================================

UITheme.Radius = {
	Small  = UDim.new(0, 10),
	Medium = UDim.new(0, 16),
	Large  = UDim.new(0, 22),
	XLarge = UDim.new(0, 28),
	Pill   = UDim.new(0, 999),
}

UITheme.Stroke = {
	Thin   = 1,
	Normal = 1.5,
}

UITheme.Padding = {
	Small  = UDim.new(0, 8),
	Medium = UDim.new(0, 14),
	Large  = UDim.new(0, 20),
}

-- ============================================================
-- RARITY  (single source of truth — was duplicated & inconsistent across UIs)
-- ============================================================

UITheme.RarityColors = ({
	Common    = UITheme.Color.Common,
	Uncommon  = UITheme.Color.Uncommon,
	Rare      = UITheme.Color.Rare,
	Legendary = UITheme.Color.Legendary,
	Epic      = UITheme.Color.RobotPurple,
}) :: { [string]: Color3 }

-- ============================================================
-- PHASE HELPERS
-- ============================================================

function UITheme.GetPhaseColor(phase)
	local map = {
		Lobby   = UITheme.Color.PhaseLobby,
		Shop    = UITheme.Color.PhaseShop,
		Style   = UITheme.Color.PhaseStyle,
		Judge   = UITheme.Color.PhaseJudge,
		Results = UITheme.Color.PhaseResults,
	}
	return map[phase] or UITheme.Color.PhaseLobby
end

function UITheme.GetPhaseTextColor(phase)
	if phase == "Judge" then
		return UITheme.Color.TextPrimary
	end
	return UITheme.Color.TextOnDark
end

-- ============================================================
-- RARITY HELPERS
-- ============================================================

function UITheme.GetRarityColor(tier)
	return UITheme.Color[tier] or UITheme.Color.Common
end

function UITheme.GetTripColor(locationKey)
	local map = {
		CozyCottage     = UITheme.Color.Uncommon,
		SuburbanHouse   = UITheme.Color.Common,
		OldLibrary      = UITheme.Color.CoolPrimary,
		BeachHouse      = Color3.fromRGB(148, 196, 188),
		VintageBoutique = UITheme.Color.Blush,
		SpookyMansion   = UITheme.Color.RobotPurple,
	}
	return map[locationKey] or UITheme.Color.CoolPrimary
end

-- ============================================================
-- COMPONENT FACTORIES
-- Thin wrappers that stamp out pre-themed instances.
-- Pass parent=nil to build detached, then reparent.
-- ============================================================

function UITheme.AddCorner(instance, radiusEnum)
	local c = Instance.new("UICorner")
	c.CornerRadius = radiusEnum or UITheme.Radius.Medium
	c.Parent = instance
	return c
end

function UITheme.AddStroke(instance, color, thickness, transparency)
	local s = Instance.new("UIStroke")
	s.Color        = color        or UITheme.Color.Stroke
	s.Thickness    = thickness    or UITheme.Stroke.Normal
	s.Transparency = transparency or 0.15
	s.Parent = instance
	return s
end

function UITheme.AddPadding(instance, paddingEnum)
	local p = Instance.new("UIPadding")
	local pad = paddingEnum or UITheme.Padding.Medium
	p.PaddingTop    = pad
	p.PaddingBottom = pad
	p.PaddingLeft   = pad
	p.PaddingRight  = pad
	p.Parent = instance
	return p
end

function UITheme.MakePanel(parent, name)
	local f = Instance.new("Frame")
	f.Name             = name or "Panel"
	f.BackgroundColor3 = UITheme.Color.Surface
	f.BorderSizePixel  = 0
	f.Parent           = parent
	UITheme.AddCorner(f, UITheme.Radius.Large)
	UITheme.AddStroke(f)
	return f
end

function UITheme.MakeLabel(parent, text, fontKey, colorKey)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Text       = text or ""
	l.Font       = UITheme.Font[fontKey  or "Body"]
	l.TextColor3 = UITheme.Color[colorKey or "TextPrimary"]
	l.TextScaled = true
	l.Parent     = parent
	return l
end

function UITheme.MakeCard(parent, name)
	local f = Instance.new("Frame")
	f.Name             = name or "Card"
	f.BackgroundColor3 = UITheme.Color.SurfaceRaised
	f.BorderSizePixel  = 0
	f.Parent           = parent
	UITheme.AddCorner(f, UITheme.Radius.Large)
	UITheme.AddStroke(f, UITheme.Color.Stroke, UITheme.Stroke.Thin, 0.3)
	return f
end

function UITheme.MakeButton(parent, text, bgColorKey)
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = UITheme.Color[bgColorKey or "WarmPrimary"]
	b.BorderSizePixel  = 0
	b.Text             = text or ""
	b.TextColor3       = UITheme.Color.TextPrimary
	b.TextScaled       = true
	b.Font             = UITheme.Font.Heavy
	b.AutoButtonColor  = true
	b.Parent           = parent
	UITheme.AddCorner(b, UITheme.Radius.Medium)
	return b
end

-- ============================================================
-- RESPONSIVE / MOBILE  (centralized — was copy-pasted per HUD script)
-- ============================================================

local UserInputService = game:GetService("UserInputService")
local GuiService       = game:GetService("GuiService")

UITheme.Scale = {
	Base = 1080,  -- viewport min-axis that maps to scale 1.0
	Min  = 0.72,  -- readability floor on small phones
	Max  = 1.0,   -- never grow past the design size
}

-- Comfortable minimum touch target in pixels (mobile-friendly).
UITheme.TouchTarget = 44

-- Keyed off the ABSENCE of a mouse, not the absence of a keyboard. A phone or tablet
-- with a paired keyboard reports KeyboardEnabled = true while Roblox still renders the
-- on-screen thumbstick and jump button, so the old predicate sent those devices down
-- the desktop branch and hid their touch controls. A touchscreen laptop has a mouse
-- and correctly stays on the desktop branch.
function UITheme.IsTouch(): boolean
	return UserInputService.TouchEnabled and not UserInputService.MouseEnabled
end

-- Single responsive scale factor, driven by the smaller viewport axis. Touch devices
-- (phones/tablets) get LARGER UI than desktop — Roblox guidance is ~1.3-1.5x on mobile
-- for readability and 44px+ touch targets, the OPPOSITE of shrinking on small screens.
function UITheme.GetUIScale(): number
	local cam = workspace.CurrentCamera
	if not cam then return UITheme.Scale.Max end
	local minAxis = math.min(cam.ViewportSize.X, cam.ViewportSize.Y)
	if UITheme.IsTouch() then
		-- Scale UP for touch; anchored to a ~640 short-axis reference, capped for big tablets.
		return math.clamp(minAxis / 640, 1.12, 1.5)
	end
	-- Desktop: the design size, gently shrinking only on small windows.
	return math.clamp(minAxis / UITheme.Scale.Base, UITheme.Scale.Min, UITheme.Scale.Max)
end

-- Keep a UIScale synced to the viewport. Replaces the per-client syncScale
-- boilerplate. Reconnects if the CurrentCamera changes.
function UITheme.BindScale(scaleInstance: UIScale): UIScale
	local conns: {RBXScriptConnection} = {}
	local function apply()
		scaleInstance.Scale = UITheme.GetUIScale()
	end
	local function rebind()
		for _, c in ipairs(conns) do c:Disconnect() end
		table.clear(conns)
		local cam = workspace.CurrentCamera
		if cam then
			table.insert(conns, cam:GetPropertyChangedSignal("ViewportSize"):Connect(apply))
		end
		apply()
	end
	rebind()
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(rebind)
	return scaleInstance
end

-- Make + parent a viewport-bound UIScale in one call.
function UITheme.AttachScale(parent: Instance): UIScale
	local s = Instance.new("UIScale")
	s.Parent = parent
	return UITheme.BindScale(s)
end

-- Apply the Roblox-recommended safe area so descendants stay clear of the top bar
-- and device notches. Call on every interactive ScreenGui (per Roblox docs,
-- ScreenInsets = CoreUISafeInsets is recommended for interactive UI).
function UITheme.ApplySafeArea(screenGui: ScreenGui)
	pcall(function()
		screenGui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	end)
end

-- Mobile on-screen controls occupy the bottom-LEFT (thumbstick) and bottom-RIGHT
-- (jump) corners. CoreUISafeInsets does NOT reserve these (they are game controls),
-- so keep interactive UI out of both corners and anchor primary actions
-- bottom-CENTER between them. Returns the px size of each bottom corner to avoid.
-- Proportional to the short axis rather than a flat 150, which was 40% of the height on
-- a small landscape phone and pushed bottom UI into the middle of the screen.
function UITheme.ControlCornerInset(): number
	if not UITheme.IsTouch() then return 0 end
	local cam = workspace.CurrentCamera
	local minAxis = cam and math.min(cam.ViewportSize.X, cam.ViewportSize.Y) or 640
	return math.floor(math.clamp(minAxis * 0.32, 90, 150))
end

-- Vertical clearance for anything anchored to the bottom edge, folding the content
-- margin together with the on-screen control corners. Bottom-anchored interactive UI
-- should offset by this instead of picking its own number, which is how the place ended
-- up with three different reserves (150, 90 and effectively 0) for the same jump button.
function UITheme.BottomSafeOffset(): number
	return UITheme.GetContentInsets().bottom + UITheme.ControlCornerInset()
end

-- Usable width for a full-bleed element inside the content margins. Bottom-anchored
-- callers clear the control corners vertically via BottomSafeOffset, so the corners do
-- not also need subtracting here.
function UITheme.ContentWidth(): number
	local cam = workspace.CurrentCamera
	if not cam then return 0 end
	local insets = UITheme.GetContentInsets()
	return cam.ViewportSize.X - (insets.left + insets.right)
end

-- The cart action buttons (GRAB / BOOST) sit in a band above the bottom-right control
-- corner during Shop. CartController positions them from these, and any other
-- bottom-anchored surface uses them to avoid being covered. Previously both sides
-- guessed independently and disagreed, which is how GRAB ended up on the jump button.
UITheme.ActionButtonSize = 108

-- No touch special-case: ControlCornerInset is already 0 off touch, so this stays a
-- sane small offset there. Returning 0 collapsed the buttons onto the bottom edge and
-- pushed BOOST off-screen.
function UITheme.ActionBandBottom(): number
	return UITheme.ControlCornerInset() + UITheme.GetContentInsets().bottom + 18 * UITheme.GetUIScale()
end

function UITheme.ActionBandTop(): number
	return UITheme.ActionBandBottom() + UITheme.ActionButtonSize * UITheme.GetUIScale()
end

-- Left edge of the action band, in screen pixels. Infinite off touch so a width test
-- against it always passes.
function UITheme.ActionBandLeft(): number
	local cam = workspace.CurrentCamera
	if not UITheme.IsTouch() or not cam then return math.huge end
	return cam.ViewportSize.X - (22 + UITheme.ActionButtonSize) * UITheme.GetUIScale()
end

-- General content margins inside the safe area (small — the top bar/notch is already
-- handled by ApplySafeArea/CoreUISafeInsets). Edges widen slightly on touch.
function UITheme.GetContentInsets(): {top: number, bottom: number, left: number, right: number}
	if UITheme.IsTouch() then
		return { top = 10, bottom = 10, left = 16, right = 16 }
	end
	return { top = 10, bottom = 10, left = 12, right = 12 }
end

return UITheme
