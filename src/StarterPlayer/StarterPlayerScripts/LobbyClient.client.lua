-- StarterPlayerScripts > LobbyClient
-- Hub HUD: top-center objective banner (states the game's goal — the first thing a
-- new player needs) + a bottom-center Play / queue button. Landscape-first; the button
-- is anchored bottom-CENTER to stay clear of the mobile control corners (thumbstick
-- bottom-left, jump bottom-right). Reports the REAL round queue (QueueStateChanged +
-- Queue* attributes). The gold ring feeds the same queue.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local UITheme = require(ReplicatedStorage:WaitForChild("UITheme"))
local Events = ReplicatedStorage:WaitForChild("Events", 15)
local QueueStateChanged = Events:WaitForChild("QueueStateChanged", 15)
local RequestJoinQueue = Events:WaitForChild("RequestJoinQueue", 15)
local RequestLeaveQueue = Events:WaitForChild("RequestLeaveQueue", 15)

local inQueue = false
local queueCount = 0

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "LobbyWelcomeGui"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 8
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui
UITheme.ApplySafeArea(screenGui)   -- ScreenInsets = CoreUISafeInsets: clears the Roblox top bar + notch
UITheme.AttachScale(screenGui)     -- shared responsive scale (replaces per-client syncScale)

local insets = UITheme.GetContentInsets()

-- ===== Top-center objective banner (always visible in the hub) =====
local banner = Instance.new("Frame")
banner.Name = "ObjectiveBanner"
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.Size = UDim2.new(0, 230, 0, 72)
banner.Position = UDim2.new(0.5, 0, 0, insets.top)
banner.BackgroundColor3 = UITheme.Color.SurfaceRaised
banner.BackgroundTransparency = 0.06
banner.BorderSizePixel = 0
banner.Visible = false
banner.Parent = screenGui
UITheme.AddCorner(banner, UITheme.Radius.Large)
UITheme.AddStroke(banner, UITheme.Color.Stroke, UITheme.Stroke.Normal, 0.2)

local topAccent = Instance.new("Frame")
topAccent.Name = "TopAccent"
topAccent.AnchorPoint = Vector2.new(0.5, 0)
topAccent.Size = UDim2.new(0, 84, 0, 4)
topAccent.Position = UDim2.new(0.5, 0, 0, 0)
topAccent.BackgroundColor3 = UITheme.Color.WarmPrimary
topAccent.BorderSizePixel = 0
topAccent.Parent = banner
UITheme.AddCorner(topAccent, UITheme.Radius.Pill)

local brandLabel = Instance.new("TextLabel")
brandLabel.Name = "Brand"
brandLabel.BackgroundTransparency = 1
brandLabel.Position = UDim2.new(0, 0, 0, 6)
brandLabel.Size = UDim2.new(1, 0, 0, 22)
brandLabel.Font = UITheme.Font.Heavy
brandLabel.Text = "Room Royale"
brandLabel.TextColor3 = UITheme.Color.TextPrimary
brandLabel.TextSize = 17
brandLabel.Parent = banner

local premiseLabel = Instance.new("TextLabel")
premiseLabel.Name = "Premise"
premiseLabel.BackgroundTransparency = 1
premiseLabel.Position = UDim2.new(0, 8, 0, 29)
premiseLabel.Size = UDim2.new(1, -16, 0, 17)
premiseLabel.Font = UITheme.Font.Medium
premiseLabel.Text = "Decorate · get judged · win Bucks!"
premiseLabel.TextColor3 = UITheme.Color.TextSecondary
premiseLabel.TextScaled = true
premiseLabel.Parent = banner

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "Status"
statusLabel.BackgroundTransparency = 1
statusLabel.Position = UDim2.new(0, 8, 0, 47)
statusLabel.Size = UDim2.new(1, -16, 0, 18)
statusLabel.Font = UITheme.Font.Body
statusLabel.Text = "Queue open — tap Play"
statusLabel.TextColor3 = UITheme.Color.TextMuted
statusLabel.TextScaled = true
statusLabel.Parent = banner

-- ===== Bottom-center primary action (carries queue state) =====
local playButton = Instance.new("TextButton")
playButton.Name = "PlayButton"
playButton.AnchorPoint = Vector2.new(0.5, 1)
playButton.Size = UDim2.new(0, 230, 0, 52)
playButton.Position = UDim2.new(0.5, 0, 1, -insets.bottom)
playButton.BackgroundColor3 = UITheme.Color.WarmPrimary
playButton.BorderSizePixel = 0
playButton.AutoButtonColor = true
playButton.Font = UITheme.Font.Heavy
playButton.TextSize = 20
playButton.TextColor3 = UITheme.Color.TextPrimary
playButton.Text = "Play"
playButton.Visible = false
playButton.Parent = screenGui
UITheme.AddCorner(playButton, UITheme.Radius.Large)
UITheme.AddStroke(playButton, UITheme.Color.WarmSecondary, UITheme.Stroke.Normal, 0.3)
playButton.MouseButton1Click:Connect(function()
	if inQueue then
		if RequestLeaveQueue then RequestLeaveQueue:FireServer() end
	else
		if RequestJoinQueue then RequestJoinQueue:FireServer() end
	end
end)

-- ===== State =====
local visibleState = false

local function formatTime(seconds)
	seconds = math.max(0, math.floor(seconds or 0))
	local mins = math.floor(seconds / 60)
	local secs = seconds % 60
	if mins > 0 then
		return string.format("%d:%02d", mins, secs)
	end
	return string.format("%ds", secs)
end

local function setVisible(shouldShow)
	if shouldShow == visibleState then return end
	visibleState = shouldShow
	banner.Visible = shouldShow
	playButton.Visible = shouldShow
end

local function isHub(): boolean
	local phase = player:GetAttribute("RoundPhase")
	return phase == nil or phase == "" or phase == "Lobby"
end

local function updateLobbyCard()
	-- Hide the plaza/queue HUD while decorating inside your own house (avoids overlapping
	-- the Decorate panel). InOwnHouse is set by HousingClient.
	local hub = isHub() and player:GetAttribute("InOwnHouse") ~= true
	setVisible(hub)
	if not hub then return end

	local count = game:GetAttribute("QueueCount")
	if typeof(count) ~= "number" then count = queueCount end
	local countdownActive = game:GetAttribute("QueueCountdownActive") == true
	local countdownRemaining = game:GetAttribute("QueueCountdownRemaining")
	if typeof(countdownRemaining) ~= "number" then countdownRemaining = -1 end

	local readyText = count == 1 and "1 stylist ready" or string.format("%d stylists ready", count)

	if countdownActive and countdownRemaining >= 0 then
		statusLabel.Text = countdownRemaining == 0 and "Round starting now!" or ("Round starts in " .. formatTime(countdownRemaining) .. "  ·  " .. readyText)
	elseif inQueue then
		statusLabel.Text = "You're in the queue — waiting for stylists"
	elseif count > 0 then
		statusLabel.Text = readyText .. " — step in the ring or tap Play"
	else
		statusLabel.Text = "Queue is open — step in the ring or tap Play"
	end

	if inQueue then
		playButton.Text = "Leave queue"
		playButton.BackgroundColor3 = UITheme.Color.Blush
		playButton.TextColor3 = UITheme.Color.TextOnDark
	else
		playButton.Text = "Play"
		playButton.BackgroundColor3 = UITheme.Color.WarmPrimary
		playButton.TextColor3 = UITheme.Color.TextPrimary
	end
end

for _, attrName in ipairs({
	"QueueCount",
	"QueueCountdownActive",
	"QueueCountdownRemaining",
}) do
	game:GetAttributeChangedSignal(attrName):Connect(updateLobbyCard)
end

QueueStateChanged.OnClientEvent:Connect(function(list)
	queueCount = type(list) == "table" and #list or 0
	inQueue = false
	if type(list) == "table" then
		for _, entry in ipairs(list) do
			if entry.userId == player.UserId then
				inQueue = true
				break
			end
		end
	end
	updateLobbyCard()
end)

player:GetAttributeChangedSignal("RoundPhase"):Connect(updateLobbyCard)
player:GetAttributeChangedSignal("InOwnHouse"):Connect(updateLobbyCard)

task.spawn(function()
	task.wait(0.4)
	updateLobbyCard()
end)

-- =========================================================
--  GOLD QUEUE RING — physical join trigger in the hub.
--  Feeds the SAME queue as the Play button.
-- =========================================================
local lastRingTouch = 0
local function tryRingJoin(hit)
	if not RequestJoinQueue then return end
	local character = player.Character
	if not (character and hit and hit:IsDescendantOf(character)) then return end
	if inQueue or not isHub() then return end
	local now = os.clock()
	if now - lastRingTouch < 1.25 then return end
	lastRingTouch = now
	RequestJoinQueue:FireServer()
end

local function hookRingSensor(sensor)
	if not sensor:IsA("BasePart") then return end
	sensor.Touched:Connect(tryRingJoin)
	local ringFolder = sensor.Parent
	local pad = ringFolder and ringFolder:FindFirstChild("GlowPad")
	if pad and pad:IsA("BasePart") then
		TweenService:Create(pad, TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
			Transparency = 0.4,
		}):Play()
	end
end

for _, sensor in ipairs(CollectionService:GetTagged("QueueRingTrigger")) do
	hookRingSensor(sensor)
end
CollectionService:GetInstanceAddedSignal("QueueRingTrigger"):Connect(hookRingSensor)

print("[LobbyClient] Loaded")
