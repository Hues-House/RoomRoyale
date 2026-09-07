--!strict
-- StarterPlayerScripts > StoreItemPrompt
-- Displays a single focused shop prompt so hover, click/tap, and keyboard pickup all refer to the same item.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local ShopTargeting = require(ReplicatedStorage:WaitForChild("ShopTargeting"))
local ItemDatabase = require(ReplicatedStorage:WaitForChild("ItemDatabase"))
local UITheme = require(ReplicatedStorage:WaitForChild("UITheme"))

local Events = ReplicatedStorage:WaitForChild("Events", 15)
local RoundPhaseChanged = Events:WaitForChild("RoundPhaseChanged", 15)
local RequestGrabItem = Events:WaitForChild("RequestGrabItem", 15)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local mouse = player:GetMouse()

local PROMPT_SIZE = UDim2.fromOffset(210, 110)
local NORMAL_RING_SIZE = 54
local FOCUS_RING_SIZE = 68

local CATEGORY_EMOJI = {
	Seating = "\u{1F6CB}",
	Bedroom = "\u{1F6CF}",
	Lighting = "\u{1F4A1}",
	Electronics = "\u{1F4FA}",
	Storage = "\u{1F4E6}",
	Rug = "\u{1F9F6}",
	Bathroom = "\u{1F6BF}",
	Decor = "\u{1F33F}",
	Dining = "\u{1FA91}",
	Tables = "\u{1FA91}",
}

local RARITY_COLORS = UITheme.RarityColors

for _, child in ipairs(playerGui:GetChildren()) do
	if child.Name == "StorePromptLayer" or (child.Name == "StorePromptGui" and child:IsA("BillboardGui")) then
		child:Destroy()
	end
end

local promptRefs: {[Instance]: {
	gui: BillboardGui,
	ring: Frame,
	stroke: UIStroke,
	pill: TextLabel,
	detail: TextLabel,
	action: TextLabel,
	emoji: TextLabel,
}} = {}
local trackedClaimSignals: {[Instance]: true} = {}
local focusedItem: Instance? = nil
local focusInRange = false  -- true when the focused item is close enough to grab

-- Single highlight that adorns the whole focused model (instead of per-part
-- ClickDetector hover outlines selecting individual parts).
local focusHighlight = Instance.new("Highlight")
focusHighlight.Name = "ShopFocusHighlight"
focusHighlight.FillColor = Color3.fromRGB(255, 246, 214)
focusHighlight.FillTransparency = 0.78
focusHighlight.OutlineColor = Color3.fromRGB(255, 226, 150)
focusHighlight.OutlineTransparency = 0.1
focusHighlight.DepthMode = Enum.HighlightDepthMode.Occluded
focusHighlight.Enabled = false
focusHighlight.Parent = playerGui

local function setHighlightTarget(item: Instance?)
	if item and item:IsA("Model") then
		focusHighlight.Adornee = item
		focusHighlight.Enabled = true
	elseif item and item:IsA("BasePart") then
		focusHighlight.Adornee = item
		focusHighlight.Enabled = true
	else
		focusHighlight.Adornee = nil
		focusHighlight.Enabled = false
	end
end

local observedPhase = (game.Players.LocalPlayer:GetAttribute("RoundPhase") or "Lobby") or "Lobby"
local isShopPhase = observedPhase == "Shop"

local function getItemData(itemId: string)
	return ItemDatabase.Get and ItemDatabase.Get(itemId) or ItemDatabase[itemId]
end

local function getPromptPart(item: Instance): BasePart?
	if item:IsA("Model") then
		return item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart", true)
	elseif item:IsA("BasePart") then
		return item
	end
	return nil
end

local function shouldUseNearestFallback(): boolean
	return true
end

local function getPickupActionText(): string
	local lastInput = UserInputService:GetLastInputType()
	if UserInputService.TouchEnabled and (lastInput == Enum.UserInputType.Touch or (not UserInputService.KeyboardEnabled and not UserInputService.GamepadEnabled)) then
		return "Tap to grab"
	end
	if string.find(lastInput.Name, "Gamepad", 1, true) then
		return "X to grab"
	end
	if lastInput == Enum.UserInputType.Keyboard or lastInput == Enum.UserInputType.MouseButton1 or lastInput == Enum.UserInputType.MouseButton2 or lastInput == Enum.UserInputType.MouseMovement then
		return "E to grab"
	end
	return "Grab"
end

local function updatePromptVisual(item: Instance, isFocused: boolean, inRange: boolean)
	local ref = promptRefs[item]
	if not ref then
		return
	end

	local visible = isShopPhase and item:GetAttribute("Claimed") ~= true and isFocused
	ref.gui.Enabled = visible
	if not visible then
		return
	end

	local ringSize = isFocused and FOCUS_RING_SIZE or NORMAL_RING_SIZE
	ref.ring.Size = UDim2.fromOffset(ringSize, ringSize)
	ref.ring.Position = UDim2.new(0.5, 0, 0, isFocused and -4 or 0)
	ref.ring.BackgroundTransparency = inRange and 0.08 or 0.38
	ref.stroke.Thickness = isFocused and 3.5 or 2
	ref.stroke.Transparency = inRange and 0.02 or 0.26
	ref.pill.BackgroundTransparency = inRange and 0.08 or 0.28
	ref.pill.TextTransparency = inRange and 0 or 0.14
	ref.detail.TextTransparency = inRange and 0.08 or 0.2
	ref.emoji.TextTransparency = inRange and 0 or 0.16
	ref.action.Visible = true
	ref.action.Text = inRange and getPickupActionText() or "Move closer"
	ref.action.BackgroundTransparency = inRange and 0.04 or 0.18
	ref.action.TextTransparency = inRange and 0 or 0.08
	ref.gui.MaxDistance = inRange and (ShopTargeting.DEFAULT_DISTANCE + 18) or (ShopTargeting.DEFAULT_DISTANCE + 22)
	ref.gui.StudsOffset = Vector3.new(0, isFocused and 4.4 or 4.0, 0)
end

local function addPrompt(item: Instance)
	if promptRefs[item] then
		return
	end

	local itemId = tostring(item:GetAttribute("ItemId") or item.Name)
	local data = getItemData(itemId)
	local category = data and data.Category or "Decor"
	local rarity = data and data.Rarity or "Common"
	local theme = data and data.Theme or "Neutral"
	local displayName = data and data.Name or ShopTargeting.GetDisplayName(item)
	local emoji = CATEGORY_EMOJI[category] or "\u{1F4E6}"
	local ringColor = RARITY_COLORS[rarity] or RARITY_COLORS.Common
	local promptPart = getPromptPart(item)
	if not promptPart then
		return
	end

	local bb = Instance.new("BillboardGui")
	bb.Name = "StorePromptGui"
	bb.Size = UDim2.fromOffset(176, 116)
	bb.StudsOffset = Vector3.new(0, 4.0, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = ShopTargeting.DEFAULT_DISTANCE + 12
	bb.LightInfluence = 0
	bb.Adornee = promptPart
	bb.Enabled = false
	bb.Parent = playerGui

	local action = Instance.new("TextLabel")
	action.Size = UDim2.fromOffset(96, 18)
	action.AnchorPoint = Vector2.new(0.5, 1)
	action.Position = UDim2.new(0.5, 0, 0, -10)
	action.BackgroundColor3 = ringColor
	action.BackgroundTransparency = 0.1
	action.BorderSizePixel = 0
	action.Text = getPickupActionText()
	action.TextColor3 = Color3.fromRGB(255, 255, 255)
	action.Font = Enum.Font.GothamBold
	action.TextSize = 11
	action.Visible = false
	action.Parent = bb
	local actionCorner = Instance.new("UICorner")
	actionCorner.CornerRadius = UDim.new(0, 8)
	actionCorner.Parent = action

	local ring = Instance.new("Frame")
	ring.Size = UDim2.fromOffset(NORMAL_RING_SIZE, NORMAL_RING_SIZE)
	ring.AnchorPoint = Vector2.new(0.5, 0)
	ring.Position = UDim2.new(0.5, 0, 0, 0)
	ring.BackgroundColor3 = ringColor
	ring.BackgroundTransparency = 0.12
	ring.BorderSizePixel = 0
	ring.Parent = bb
	local ringCorner = Instance.new("UICorner")
	ringCorner.CornerRadius = UDim.new(0.5, 0)
	ringCorner.Parent = ring

	local stroke = Instance.new("UIStroke")
	stroke.Color = ringColor
	stroke.Thickness = 2
	stroke.Transparency = 0.04
	stroke.Parent = ring

	local emojiLabel = Instance.new("TextLabel")
	emojiLabel.Size = UDim2.fromScale(1, 1)
	emojiLabel.BackgroundTransparency = 1
	emojiLabel.Text = emoji
	emojiLabel.TextSize = 20
	emojiLabel.Font = Enum.Font.SourceSans
	emojiLabel.Parent = ring

	local pill = Instance.new("TextLabel")
	pill.Size = UDim2.fromOffset(156, 20)
	pill.Position = UDim2.fromOffset(0, 40)
	pill.BackgroundColor3 = ringColor
	pill.BackgroundTransparency = 0.12
	pill.BorderSizePixel = 0
	pill.Text = displayName
	pill.TextColor3 = Color3.fromRGB(255, 255, 255)
	pill.Font = Enum.Font.GothamBold
	pill.TextSize = 11
	pill.TextTruncate = Enum.TextTruncate.AtEnd
	pill.Parent = bb
	local pillCorner = Instance.new("UICorner")
	pillCorner.CornerRadius = UDim.new(0, 7)
	pillCorner.Parent = pill

	local detail = Instance.new("TextLabel")
	detail.Size = UDim2.fromOffset(156, 16)
	detail.Position = UDim2.fromOffset(0, 62)
	detail.BackgroundTransparency = 1
	detail.Text = string.format("%s  •  %s", rarity, theme)
	detail.TextColor3 = Color3.fromRGB(248, 245, 238)
	detail.TextTransparency = 0.08
	detail.Font = Enum.Font.GothamMedium
	detail.TextSize = 10
	detail.TextTruncate = Enum.TextTruncate.AtEnd
	detail.Parent = bb

	promptRefs[item] = {
		gui = bb,
		ring = ring,
		stroke = stroke,
		pill = pill,
		detail = detail,
		action = action,
		emoji = emojiLabel,
	}
end

local function removePrompt(item: Instance)
	local ref = promptRefs[item]
	if ref then
		ref.gui:Destroy()
		promptRefs[item] = nil
	end
	trackedClaimSignals[item] = nil
	if focusedItem == item then
		focusedItem = nil
	end
end

local function trackClaimed(item: Instance)
	item:GetAttributeChangedSignal("Claimed"):Connect(function()
		if item:GetAttribute("Claimed") then
			removePrompt(item)
		end
	end)
end

local function syncStorePrompts()
	for _, item in ipairs(ShopTargeting.GetAllStoreItems()) do
		if item:GetAttribute("Claimed") ~= true then
			addPrompt(item)
			if not trackedClaimSignals[item] then
				trackedClaimSignals[item] = true
				trackClaimed(item)
			end
		end
	end
	for item in pairs(promptRefs) do
		if not ShopTargeting.IsStoreItemAvailable(item) then
			removePrompt(item)
		end
	end
end

syncStorePrompts()
Workspace.ChildAdded:Connect(function()
	task.defer(syncStorePrompts)
end)
Workspace.ChildRemoved:Connect(function(child)
	if promptRefs[child] then
		removePrompt(child)
	end
end)

local function updateObservedPhase(phase: string?)
	if type(phase) == "string" and phase ~= "" then
		observedPhase = phase
	end
	isShopPhase = observedPhase == "Shop"
	if not isShopPhase then
		focusedItem = nil
		setHighlightTarget(nil)
		-- Hide all prompts when leaving Shop
		for item in pairs(promptRefs) do
			updatePromptVisual(item, false, false)
		end
	end
end

game.Players.LocalPlayer:GetAttributeChangedSignal("RoundPhase"):Connect(function()
	updateObservedPhase((game.Players.LocalPlayer:GetAttribute("RoundPhase") or "Lobby"))
end)

RunService.RenderStepped:Connect(function()
	isShopPhase = observedPhase == "Shop"
	local nextFocus, inRange = ShopTargeting.GetShopFocusTarget(player, mouse.Target, ShopTargeting.DEFAULT_DISTANCE, shouldUseNearestFallback())
	if not isShopPhase then
		nextFocus = nil
	end

	if focusedItem ~= nextFocus then
		if focusedItem then
			updatePromptVisual(focusedItem, false, false)
		end
		focusedItem = nextFocus
		setHighlightTarget(isShopPhase and focusedItem or nil)
	end
	focusInRange = (focusedItem ~= nil) and inRange == true

	for item in pairs(promptRefs) do
		updatePromptVisual(item, item == focusedItem, item == focusedItem and inRange)
	end
end)

-- =========================================================
--  KEYBOARD / GAMEPAD PICKUP
--  Click & tap are handled server-side via ClickDetector.
--  This adds the key/button path the prompt UI advertises
--  ("E to grab" / "X to grab") so all input methods work.
-- =========================================================

local function tryGrabFocused()
	if not isShopPhase then return end
	if not focusedItem or not focusInRange then return end
	if focusedItem:GetAttribute("Claimed") == true then return end
	-- Fire with no argument so the server uses its own authoritative
	-- findNearestStoreItem(player). This avoids any instance-identity
	-- mismatch between the client's focused item and the server's view,
	-- and matches the keyboard-grab path the server already supports.
	RequestGrabItem:FireServer()
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.ButtonX then
		tryGrabFocused()
	end
end)

print("[StoreItemPrompt] Loaded")
