-- StarterPlayerScripts > RoundClient
-- Phase banner HUD: shows current phase, theme name, and countdown timer.
-- Styled with UITheme warm palette and entrance/exit tweens.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TweenService = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local UITheme = require(ReplicatedStorage:WaitForChild("UITheme"))
local Events       = ReplicatedStorage:WaitForChild("Events", 15)
local RoundPhaseChanged = Events:WaitForChild("RoundPhaseChanged", 15)
local TimerTick    = Events:WaitForChild("TimerTick", 15)
local RoundStarted = Events:WaitForChild("RoundStarted", 15)
local RoundEnded   = Events:WaitForChild("RoundEnded", 15)

-- =========================================================
--  PHASE BANNER
-- =========================================================

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PhaseBannerGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- Responsive scale
local bannerScale = Instance.new("UIScale")
bannerScale.Parent = screenGui

local function syncBannerScale()
	local cam = workspace.CurrentCamera
	if not cam then return end
	local minAxis = math.min(cam.ViewportSize.X, cam.ViewportSize.Y)
	bannerScale.Scale = math.clamp(minAxis / 1080, 0.82, 1.02)
end
syncBannerScale()
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(syncBannerScale)
task.defer(function()
	local cam = workspace.CurrentCamera
	if cam then cam:GetPropertyChangedSignal("ViewportSize"):Connect(syncBannerScale) end
end)

-- Banner card: centered top card that clears the Roblox top strip.
local bg = Instance.new("Frame")
bg.Name = "PhaseBanner"
bg.AnchorPoint = Vector2.new(0.5, 0)
bg.Size = UDim2.new(0, 760, 0, 96)
bg.Position = UDim2.new(0.5, 0, 0, -110) -- starts off-screen
bg.BackgroundColor3 = UITheme.Color.SurfaceRaised
bg.BackgroundTransparency = 0.1
bg.BorderSizePixel = 0
bg.ClipsDescendants = true
bg.Parent = screenGui
UITheme.AddCorner(bg, UITheme.Radius.XLarge)
UITheme.AddStroke(bg, UITheme.Color.Stroke, UITheme.Stroke.Thin, 0.82)

local bannerGradient = Instance.new("UIGradient")
bannerGradient.Rotation = 90
bannerGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, UITheme.Color.SurfaceRaised),
	ColorSequenceKeypoint.new(1, UITheme.Color.Surface),
})
bannerGradient.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.02),
	NumberSequenceKeypoint.new(1, 0.22),
})
bannerGradient.Parent = bg

-- Phase-colored accent bar on bottom edge
local accentBar = Instance.new("Frame")
accentBar.Name = "AccentBar"
accentBar.AnchorPoint = Vector2.new(0.5, 1)
accentBar.Size = UDim2.new(1, -24, 0, 4)
accentBar.Position = UDim2.new(0.5, 0, 1, -8)
accentBar.BackgroundColor3 = UITheme.Color.PhaseLobby
accentBar.BackgroundTransparency = 0.04
accentBar.BorderSizePixel = 0
accentBar.Parent = bg
UITheme.AddCorner(accentBar, UITheme.Radius.Pill)

local contentPlate = Instance.new("Frame")
contentPlate.Name = "ContentPlate"
contentPlate.AnchorPoint = Vector2.new(0.5, 0)
contentPlate.Size = UDim2.new(1, -18, 1, -20)
contentPlate.Position = UDim2.new(0.5, 0, 0, 10)
contentPlate.BackgroundColor3 = UITheme.Color.Surface
contentPlate.BackgroundTransparency = 0.3
contentPlate.BorderSizePixel = 0
contentPlate.Parent = bg
UITheme.AddCorner(contentPlate, UITheme.Radius.Large)
UITheme.AddStroke(contentPlate, UITheme.Color.Stroke, UITheme.Stroke.Thin, 0.9)

local centerBlock = Instance.new("Frame")
centerBlock.Name = "CenterBlock"
centerBlock.AnchorPoint = Vector2.new(0.5, 0)
centerBlock.Size = UDim2.new(1, -142, 0, 58)
centerBlock.Position = UDim2.new(0.5, 0, 0, 12)
centerBlock.BackgroundTransparency = 1
centerBlock.Parent = contentPlate

-- Phase name centered in the open safe area.
local phaseLabel = Instance.new("TextLabel")
phaseLabel.Name = "PhaseLabel"
phaseLabel.AnchorPoint = Vector2.new(0.5, 0)
phaseLabel.Size = UDim2.new(1, 0, 0, 42)
phaseLabel.Position = UDim2.new(0.5, 0, 0, 12)
phaseLabel.BackgroundTransparency = 1
phaseLabel.TextColor3 = UITheme.Color.TextPrimary
phaseLabel.Font = UITheme.Font.Heavy
phaseLabel.TextSize = 31
phaseLabel.TextStrokeColor3 = Color3.fromRGB(255, 248, 236)
phaseLabel.TextStrokeTransparency = 0.76
phaseLabel.TextXAlignment = Enum.TextXAlignment.Center
phaseLabel.Text = "LOBBY"
phaseLabel.Parent = centerBlock

-- Timer (right aligned, kept out of the title's visual center)
local timerLabel = Instance.new("TextLabel")
timerLabel.Name = "TimerLabel"
timerLabel.Size = UDim2.new(0, 108, 0, 28)
timerLabel.Position = UDim2.new(1, -118, 0, 20)
timerLabel.BackgroundTransparency = 1
timerLabel.TextColor3 = UITheme.Color.TextPrimary
timerLabel.Font = UITheme.Font.Heavy
timerLabel.TextSize = 20
timerLabel.TextStrokeColor3 = Color3.fromRGB(255, 248, 236)
timerLabel.TextStrokeTransparency = 0.82
timerLabel.TextXAlignment = Enum.TextXAlignment.Right
timerLabel.Text = "Waiting..."
timerLabel.Parent = contentPlate

-- Theme subtitle row ("Farmhouse - Warm rustic textures")
local themeSubtitle = Instance.new("TextLabel")
themeSubtitle.Name = "ThemeSubtitle"
themeSubtitle.AnchorPoint = Vector2.new(0.5, 0)
themeSubtitle.Size = UDim2.new(1, -36, 0, 24)
themeSubtitle.Position = UDim2.new(0.5, 0, 0, 38)
themeSubtitle.BackgroundTransparency = 1
themeSubtitle.TextColor3 = UITheme.Color.TextSecondary
themeSubtitle.Font = UITheme.Font.Body
themeSubtitle.TextSize = 17
themeSubtitle.TextStrokeColor3 = Color3.fromRGB(255, 252, 244)
themeSubtitle.TextStrokeTransparency = 0.9
themeSubtitle.TextXAlignment = Enum.TextXAlignment.Center
themeSubtitle.TextWrapped = true
themeSubtitle.Text = ""
themeSubtitle.Parent = centerBlock

-- Timer progress bar runs edge-to-edge beneath the content block.
local timerTrack = Instance.new("Frame")
timerTrack.Name = "TimerTrack"
timerTrack.Size = UDim2.new(1, -24, 0, 4)
timerTrack.Position = UDim2.new(0, 12, 1, -10)
timerTrack.BackgroundColor3 = UITheme.Color.Disabled
timerTrack.BackgroundTransparency = 0.46
timerTrack.BorderSizePixel = 0
timerTrack.Parent = bg
UITheme.AddCorner(timerTrack, UITheme.Radius.Pill)

local timerFill = Instance.new("Frame")
timerFill.Name = "TimerFill"
timerFill.Size = UDim2.new(1, 0, 1, 0)
timerFill.BackgroundColor3 = UITheme.Color.WarmPrimary
timerFill.BorderSizePixel = 0
timerFill.Parent = timerTrack
UITheme.AddCorner(timerFill, UITheme.Radius.Pill)

local PHASE_LAYOUTS = {
	Lobby = {
		showY = 52,
		size = UDim2.new(0, 620, 0, 88),
		contentPlateSize = UDim2.new(1, -18, 1, -18),
		contentPlatePos = UDim2.new(0.5, 0, 0, 8),
		centerBlockSize = UDim2.new(1, -124, 0, 52),
		centerBlockPos = UDim2.new(0.5, 0, 0, 14),
		phaseY = 8,
		timerY = 18,
		subtitleY = 34,
		trackY = -8,
	},
	Shop = {
		showY = 52,
		size = UDim2.new(0, 760, 0, 96),
		contentPlateSize = UDim2.new(1, -18, 1, -20),
		contentPlatePos = UDim2.new(0.5, 0, 0, 10),
		centerBlockSize = UDim2.new(1, -142, 0, 58),
		centerBlockPos = UDim2.new(0.5, 0, 0, 12),
		phaseY = 12,
		timerY = 20,
		subtitleY = 38,
		trackY = -10,
	},
	Default = {
		showY = 52,
		size = UDim2.new(0, 760, 0, 96),
		contentPlateSize = UDim2.new(1, -18, 1, -20),
		contentPlatePos = UDim2.new(0.5, 0, 0, 10),
		centerBlockSize = UDim2.new(1, -142, 0, 58),
		centerBlockPos = UDim2.new(0.5, 0, 0, 12),
		phaseY = 12,
		timerY = 20,
		subtitleY = 38,
		trackY = -10,
	},
}

local currentShowPos = UDim2.new(0.5, 0, 0, PHASE_LAYOUTS.Default.showY)
local BANNER_HIDE_POS = UDim2.new(0.5, 0, 0, -110)
local bannerVisible = false
local bannerHasShownOnce = false

local function getPhaseLayout(phase: string?)
	if phase == "Lobby" then
		return PHASE_LAYOUTS.Lobby
	end
	if phase == "Shop" then
		return PHASE_LAYOUTS.Shop
	end
	return PHASE_LAYOUTS.Default
end

local function getBannerShowPos(phase: string?): UDim2
	local layout = getPhaseLayout(phase)
	return UDim2.new(0.5, 0, 0, layout.showY)
end

local function applyBannerLayout(phase: string, instant: boolean?)
	local layout = getPhaseLayout(phase)
	currentShowPos = UDim2.new(0.5, 0, 0, layout.showY)

	local tweenInfo = TweenInfo.new(instant and 0 or 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(bg, tweenInfo, {
		Size = layout.size,
	}):Play()
	-- Position is managed by showBanner/hideBanner, not here.
	-- If banner is currently visible, update its position to the new showY.
	if bannerVisible then
		TweenService:Create(bg, tweenInfo, {
			Position = currentShowPos,
		}):Play()
	end
	TweenService:Create(contentPlate, tweenInfo, {
		Size = layout.contentPlateSize,
		Position = layout.contentPlatePos,
	}):Play()
	TweenService:Create(centerBlock, tweenInfo, {
		Size = layout.centerBlockSize,
		Position = layout.centerBlockPos,
	}):Play()
	TweenService:Create(phaseLabel, tweenInfo, {
		Position = UDim2.new(0.5, 0, 0, layout.phaseY),
	}):Play()
	TweenService:Create(timerLabel, tweenInfo, {
		Position = UDim2.new(1, -118, 0, layout.timerY),
	}):Play()
	TweenService:Create(themeSubtitle, tweenInfo, {
		Position = UDim2.new(0.5, 0, 0, layout.subtitleY),
	}):Play()
	TweenService:Create(timerTrack, tweenInfo, {
		Position = UDim2.new(0, 12, 1, layout.trackY),
	}):Play()
	TweenService:Create(accentBar, tweenInfo, {
		Position = UDim2.new(0.5, 0, 1, layout.trackY + 2),
	}):Play()
end

local function showBanner()
	if bannerVisible then return end
	bannerVisible = true
	bannerHasShownOnce = true
	TweenService:Create(bg, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = currentShowPos,
	}):Play()
end

local function hideBanner()
	if not bannerVisible then return end
	bannerVisible = false
	TweenService:Create(bg, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = BANNER_HIDE_POS,
	}):Play()
end

local currentPhaseDuration = 0
local currentPhaseRemaining = 0

-- Phase → badge color
local PHASE_COLORS = {
	Lobby   = UITheme.Color.PhaseLobby,
	Shop    = UITheme.Color.PhaseShop,
	Style   = UITheme.Color.PhaseStyle,
	Judge   = UITheme.Color.PhaseJudge,
	Results = UITheme.Color.PhaseResults,
}

-- =========================================================
--  EVENT HANDLERS
-- =========================================================

local function getSharedThemeAttribute(name)
	local value = ReplicatedStorage:GetAttribute(name)
	if value ~= nil then
		return value
	end
	return game:GetAttribute(name)
end

local function getRoundThemeLabel()
	local label = getSharedThemeAttribute("RoundThemeLabel")
	if type(label) == "string" and label ~= "" then
		return label
	end
	return nil
end

-- formatPhaseTimer removed: timer label is now standalone right-aligned

local PHASE_EMOJIS = {
	Lobby   = "",
	Shop    = "\u{1F6D2}",   -- shopping cart
	Style   = "\u{2728}",    -- sparkles
	Judge   = "\u{2B50}",    -- star
	Results = "\u{1F3C6}",   -- trophy
}

local function applyPhase(phase)
	local phaseColor = PHASE_COLORS[phase] or UITheme.Color.PhaseLobby

	applyBannerLayout(phase, not bannerHasShownOnce)

	-- Accent bar color
	TweenService:Create(accentBar, TweenInfo.new(0.3), {
		BackgroundColor3 = phaseColor,
	}):Play()

	-- Timer fill color matches phase
	timerFill.BackgroundColor3 = phaseColor

	-- Phase label
	local themeLabel = getRoundThemeLabel()
	local emoji = PHASE_EMOJIS[phase] or ""
	if (phase == "Shop" or phase == "Style") and themeLabel then
		phaseLabel.Text = emoji .. " " .. string.upper(themeLabel)
	else
		phaseLabel.Text = emoji .. " " .. phase:upper()
	end

	-- Theme subtitle
	local hint = getSharedThemeAttribute("RoundThemeHint")
	local prompt = getSharedThemeAttribute("RoundThemePrompt")
	if (phase == "Shop" or phase == "Style" or phase == "Judge") and themeLabel then
		if type(prompt) == "string" and prompt ~= "" then
			themeSubtitle.Text = prompt
		elseif type(hint) == "string" and hint ~= "" then
			themeSubtitle.Text = hint
		else
			themeSubtitle.Text = ""
		end
	else
		themeSubtitle.Text = phase == "Lobby" and "Waiting for players..." or ""
	end

	-- Timer text
	timerLabel.Text = "..."

	-- Reset timer bar
	currentPhaseDuration = 0
	currentPhaseRemaining = 0
	timerFill.Size = UDim2.new(1, 0, 1, 0)

	-- Banner only earns its keep inside a round — the lobby status strip owns the hub.
	if phase == "Lobby" then
		hideBanner()
	else
		showBanner()
	end
end

-- Apply whatever phase the server is already in when we connect
-- (handles late-joining or slow client load)
task.spawn(function()
	local currentPhase = (game.Players.LocalPlayer:GetAttribute("RoundPhase") or "Lobby")
	if currentPhase then
		applyPhase(currentPhase)
	else
		-- Wait for the attribute to be set
		game.Players.LocalPlayer:GetAttributeChangedSignal("RoundPhase"):Wait()
		applyPhase((game.Players.LocalPlayer:GetAttribute("RoundPhase") or "Lobby"))
	end
end)

game.Players.LocalPlayer:GetAttributeChangedSignal("RoundPhase"):Connect(function()
	local phase = game.Players.LocalPlayer:GetAttribute("RoundPhase") or "Lobby"
	applyPhase(phase)
	print(string.format("[RoundClient] Phase → %s", phase))
end)

local function refreshThemePhaseBadge()
	local actual = (game.Players.LocalPlayer:GetAttribute("RoundPhase") or "Lobby")
	if actual then
		applyPhase(actual)
	end
end

game:GetAttributeChangedSignal("RoundThemeLabel"):Connect(refreshThemePhaseBadge)
ReplicatedStorage:GetAttributeChangedSignal("RoundThemeLabel"):Connect(refreshThemePhaseBadge)

TimerTick.OnClientEvent:Connect(function(phase, remaining)
	-- Track duration for progress bar
	if currentPhaseDuration == 0 or remaining > currentPhaseDuration then
		currentPhaseDuration = remaining + 1
	end
	currentPhaseRemaining = remaining

	local mins = math.floor(remaining / 60)
	local secs = remaining % 60
	local timeText
	if mins > 0 then
		timeText = string.format("%d:%02d", mins, secs)
	else
		timeText = string.format("%ds", secs)
	end
	timerLabel.Text = timeText

	-- Animate progress bar
	local frac = if currentPhaseDuration > 0 then math.clamp(remaining / currentPhaseDuration, 0, 1) else 1
	TweenService:Create(timerFill, TweenInfo.new(0.9, Enum.EasingStyle.Linear), {
		Size = UDim2.new(frac, 0, 1, 0),
	}):Play()

	-- Pulse accent bar when low time
	if remaining <= 5 and remaining > 0 then
		TweenService:Create(accentBar, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true), {
			BackgroundTransparency = 0.5,
		}):Play()
	end
end)

RoundStarted.OnClientEvent:Connect(function(roundNumber, players)
	print(string.format("[RoundClient] Round %d started — %d player(s)", roundNumber, #players))
end)

RoundEnded.OnClientEvent:Connect(function(roundNumber)
	timerLabel.Text = ""
	themeSubtitle.Text = "Round " .. roundNumber .. " complete!"
	timerFill.Size = UDim2.new(0, 0, 1, 0)
	print(string.format("[RoundClient] Round %d ended", roundNumber))

	-- Slide banner out after a brief pause
	task.delay(3, function()
		local phase = (game.Players.LocalPlayer:GetAttribute("RoundPhase") or "Lobby")
		if phase == "Results" then
			hideBanner()
		end
	end)
end)

print("[RoundClient] Loaded")
