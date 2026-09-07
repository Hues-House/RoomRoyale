--!strict
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local UITheme = require(ReplicatedStorage:WaitForChild("UITheme"))
local ShopTargeting = require(ReplicatedStorage:WaitForChild("ShopTargeting"))
local Events = ReplicatedStorage:WaitForChild("Events", 15)
local RequestGrabItem = Events:WaitForChild("RequestGrabItem", 15) :: RemoteEvent

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local mouse = player:GetMouse()

type PromptCard = {
	Root: Frame,
	KeyBubble: TextLabel,
	ActionLabel: TextLabel,
	ObjectLabel: TextLabel,
	ProgressTrack: Frame,
	ProgressFill: Frame,
}

local function createPromptCard(parent: Instance, name: string): PromptCard
	local card = Instance.new("Frame")
	card.Name = name
	card.BackgroundColor3 = UITheme.Color.Surface
	card.BackgroundTransparency = 0.12
	card.BorderSizePixel = 0
	card.Visible = false
	card.Parent = parent
	UITheme.AddCorner(card, UITheme.Radius.Pill)
	UITheme.AddStroke(card, UITheme.Color.Stroke, 1, 0.82)

	local shine = Instance.new("UIGradient")
	shine.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(235, 242, 255)),
	})
	shine.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.78),
		NumberSequenceKeypoint.new(0.45, 0.58),
		NumberSequenceKeypoint.new(1, 0.8),
	})
	shine.Rotation = 90
	shine.Parent = card

	local keyBubble = Instance.new("TextLabel")
	keyBubble.Name = "KeyBubble"
	keyBubble.Size = UDim2.new(0, 42, 0, 42)
	keyBubble.Position = UDim2.new(0, 10, 0.5, -21)
	keyBubble.BackgroundColor3 = UITheme.Color.Success
	keyBubble.BackgroundTransparency = 0.1
	keyBubble.BorderSizePixel = 0
	keyBubble.TextColor3 = Color3.new(1, 1, 1)
	keyBubble.Font = UITheme.Font.Heavy
	keyBubble.TextSize = 17
	keyBubble.Parent = card
	UITheme.AddCorner(keyBubble, UITheme.Radius.Pill)

	local actionLabel = Instance.new("TextLabel")
	actionLabel.Name = "ActionLabel"
	actionLabel.Size = UDim2.new(1, -70, 0, 22)
	actionLabel.Position = UDim2.new(0, 60, 0, 10)
	actionLabel.BackgroundTransparency = 1
	actionLabel.TextColor3 = UITheme.Color.TextPrimary
	actionLabel.TextXAlignment = Enum.TextXAlignment.Left
	actionLabel.Font = UITheme.Font.Bold
	actionLabel.TextSize = 17
	actionLabel.Text = "Grab"
	actionLabel.Parent = card

	local objectLabel = Instance.new("TextLabel")
	objectLabel.Name = "ObjectLabel"
	objectLabel.Size = UDim2.new(1, -70, 0, 18)
	objectLabel.Position = UDim2.new(0, 60, 0, 30)
	objectLabel.BackgroundTransparency = 1
	objectLabel.TextColor3 = UITheme.Color.TextSecondary
	objectLabel.TextXAlignment = Enum.TextXAlignment.Left
	objectLabel.Font = UITheme.Font.Medium
	objectLabel.TextSize = 13
	objectLabel.Text = "Nearest find"
	objectLabel.TextTruncate = Enum.TextTruncate.AtEnd
	objectLabel.Parent = card

	local progressTrack = Instance.new("Frame")
	progressTrack.Name = "ProgressTrack"
	progressTrack.Size = UDim2.new(1, -14, 0, 4)
	progressTrack.Position = UDim2.new(0, 7, 1, -7)
	progressTrack.BackgroundColor3 = Color3.new(1, 1, 1)
	progressTrack.BackgroundTransparency = 0.88
	progressTrack.BorderSizePixel = 0
	progressTrack.Parent = card
	UITheme.AddCorner(progressTrack, UITheme.Radius.Pill)

	local progressFill = Instance.new("Frame")
	progressFill.Name = "ProgressFill"
	progressFill.Size = UDim2.new(0, 0, 1, 0)
	progressFill.BackgroundColor3 = UITheme.Color.WarmPrimary
	progressFill.BorderSizePixel = 0
	progressFill.Parent = progressTrack
	UITheme.AddCorner(progressFill, UITheme.Radius.Pill)

	return {
		Root = card,
		KeyBubble = keyBubble,
		ActionLabel = actionLabel,
		ObjectLabel = objectLabel,
		ProgressTrack = progressTrack,
		ProgressFill = progressFill,
	}
end

local gui = Instance.new("ScreenGui")
gui.Name = "PromptGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local billboardGui = Instance.new("BillboardGui")
billboardGui.Name = "ShopPromptGui"
billboardGui.Size = UDim2.fromOffset(264, 62)
billboardGui.LightInfluence = 0
billboardGui.MaxDistance = 30
billboardGui.AlwaysOnTop = false
billboardGui.Enabled = false
billboardGui.Parent = playerGui

local screenCard = createPromptCard(gui, "Root")
local root = screenCard.Root
root.AnchorPoint = Vector2.new(0.5, 1)
root.Size = UDim2.new(0, 264, 0, 62)
root.Position = UDim2.new(0.5, 0, 1, -124)

local keyBubble = screenCard.KeyBubble
local actionLabel = screenCard.ActionLabel
local objectLabel = screenCard.ObjectLabel
local progressTrack = screenCard.ProgressTrack
local progressFill = screenCard.ProgressFill

local shopCard = createPromptCard(billboardGui, "ShopRoot")
local shopRoot = shopCard.Root
shopRoot.Size = UDim2.fromScale(1, 1)
shopRoot.BackgroundTransparency = 0.3
shopRoot.Visible = false

local shopKeyBubble = shopCard.KeyBubble
local shopActionLabel = shopCard.ActionLabel
local shopObjectLabel = shopCard.ObjectLabel
local shopProgressTrack = shopCard.ProgressTrack

local shownPrompts: {[ProximityPrompt]: {inputType: Enum.ProximityPromptInputType, order: number}} = {}
local orderCounter = 0
local activePrompt: ProximityPrompt? = nil
local activeInputType = Enum.ProximityPromptInputType.Keyboard
local holdTween: Tween? = nil

-- Touch trigger: Custom-style ProximityPrompts have NO native tap button on mobile, so the
-- on-screen prompt card was untappable ("Tap" prompts did nothing). Overlay a transparent
-- button on the card and fire the active prompt programmatically.
local promptTapButton = Instance.new("TextButton")
promptTapButton.Name = "TapTrigger"; promptTapButton.Size = UDim2.fromScale(1, 1)
promptTapButton.BackgroundTransparency = 1; promptTapButton.Text = ""; promptTapButton.ZIndex = 50
promptTapButton.Parent = root
promptTapButton.Activated:Connect(function()
	local prompt = activePrompt
	if not (prompt and prompt.Parent) then return end
	prompt:InputHoldBegin()
	if prompt.HoldDuration > 0 then task.wait(prompt.HoldDuration) end
	prompt:InputHoldEnd()
end)

local function stopHoldTween()
	if holdTween then
		holdTween:Cancel()
		holdTween = nil
	end
	progressFill.Size = UDim2.new(0, 0, 1, 0)
end

local function getKeyText(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType): string
	if inputType == Enum.ProximityPromptInputType.Touch or UserInputService.TouchEnabled then
		return "Tap"
	end
	if inputType == Enum.ProximityPromptInputType.Gamepad then
		return "A"
	end
	local keyCode = prompt.KeyboardKeyCode
	if keyCode == Enum.KeyCode.Unknown then
		return "E"
	end
	local name = keyCode.Name
	if #name <= 4 then
		return string.upper(name)
	end
	return name:sub(1, 1):upper() .. name:sub(2, 3)
end

local function isShopStorePrompt(prompt: ProximityPrompt): boolean
	if (game.Players.LocalPlayer:GetAttribute("RoundPhase") or "Lobby") ~= "Shop" then
		return false
	end
	return ShopTargeting.ResolveStoreItem(prompt.Parent) ~= nil
end

local function isSuppressedPrompt(prompt: ProximityPrompt): boolean
	if isShopStorePrompt(prompt) then
		return true
	end
	if (game.Players.LocalPlayer:GetAttribute("RoundPhase") or "Lobby") ~= "Style" then
		return false
	end
	return prompt.ActionText == "Paint" or prompt.ActionText == "Tint"
end

local function updatePromptLayout(objectVisible: boolean)
	local phase = (game.Players.LocalPlayer:GetAttribute("RoundPhase") or "Lobby")
	local yOffset = -92
	if phase == "Shop" then
		yOffset = -222
	elseif phase == "Style" then
		yOffset = -96
	elseif phase == "Judge" then
		yOffset = -84
	end
	root.Position = UDim2.new(0.5, 0, 1, yOffset)
	root.Size = UDim2.new(0, objectVisible and 264 or 204, 0, 62)
end

local function hideShopPrompt()
	shopRoot.Visible = false
	billboardGui.Enabled = false
	billboardGui.Adornee = nil
end

local function getShopPromptAdornee(item: Instance): BasePart?
	if item:IsA("BasePart") then
		return item
	end
	if item:IsA("Model") then
		if item.PrimaryPart then
			return item.PrimaryPart
		end
		for _, desc in ipairs(item:GetDescendants()) do
			if desc:IsA("BasePart") then
				return desc
			end
		end
	end
	return nil
end

local function getShopPromptOffset(item: Instance, adornee: BasePart): number
	local verticalOffset = 2.35
	if item:IsA("Model") then
		verticalOffset += math.clamp(item:GetExtentsSize().Y * 0.5, 0.7, 4)
	else
		verticalOffset += math.clamp(adornee.Size.Y * 0.5, 0.7, 4)
	end
	return verticalOffset
end

local function shouldUseNearestShopFallback(): boolean
	local lastInput = UserInputService:GetLastInputType()
	if string.find(lastInput.Name, "Gamepad", 1, true) then
		return true
	end
	if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
		return true
	end
	return not UserInputService.MouseEnabled and UserInputService.GamepadEnabled
end

local function getShopPromptTarget(): (Instance?, boolean)
	return ShopTargeting.GetShopFocusTarget(player, mouse.Target, ShopTargeting.DEFAULT_DISTANCE, shouldUseNearestShopFallback())
end

local function getShopInputText(): string
	local lastInput = UserInputService:GetLastInputType()
	if UserInputService.TouchEnabled and (lastInput == Enum.UserInputType.Touch or (not UserInputService.KeyboardEnabled and not UserInputService.GamepadEnabled)) then
		return "Tap"
	end
	if string.find(lastInput.Name, "Gamepad", 1, true) then
		return "X"
	end
	return "E"
end

local function applyShopPrompt(item: Instance, inRange: boolean)
	local adornee = getShopPromptAdornee(item)
	if not adornee then
		hideShopPrompt()
		return
	end
	shopKeyBubble.Text = getShopInputText()
	shopKeyBubble.BackgroundColor3 = inRange and UITheme.Color.Success or UITheme.Color.DisabledText
	shopKeyBubble.TextColor3 = inRange and Color3.new(1, 1, 1) or UITheme.Color.TextPrimary
	shopActionLabel.Text = inRange and "Pick Up" or "Move Closer"
	shopObjectLabel.Text = ShopTargeting.GetDisplayName(item)
	shopObjectLabel.Visible = true
	shopProgressTrack.Visible = false
	stopHoldTween()
	billboardGui.Adornee = adornee
	billboardGui.StudsOffsetWorldSpace = Vector3.new(0, getShopPromptOffset(item, adornee), 0)
	billboardGui.Enabled = true
	shopRoot.Visible = true
	root.Visible = false
end

local function chooseActivePrompt()
	local topPrompt: ProximityPrompt? = nil
	local topOrder = -1
	for prompt, info in pairs(shownPrompts) do
		if prompt.Parent and info.order > topOrder then
			topPrompt = prompt
			topOrder = info.order
		end
	end
	activePrompt = topPrompt
	if activePrompt then
		activeInputType = shownPrompts[activePrompt].inputType
		root.Visible = true
	else
		root.Visible = false
		stopHoldTween()
	end
end

local function updatePromptVisuals()
	if (game.Players.LocalPlayer:GetAttribute("RoundPhase") or "Lobby") == "Shop" then
		local shopItem, inRange = getShopPromptTarget()
		if shopItem then
			applyShopPrompt(shopItem, inRange)
			return
		end
		hideShopPrompt()
	end

	if not activePrompt then
		root.Visible = false
		return
	end
	local prompt = activePrompt
	if isSuppressedPrompt(prompt) then
		root.Visible = false
		return
	end
	keyBubble.Text = getKeyText(prompt, activeInputType)
	keyBubble.BackgroundColor3 = UITheme.Color.Success
	keyBubble.TextColor3 = Color3.new(1, 1, 1)
	actionLabel.Text = prompt.ActionText ~= "" and prompt.ActionText or "Use"
	objectLabel.Text = prompt.ObjectText ~= "" and prompt.ObjectText or ""
	objectLabel.Visible = objectLabel.Text ~= ""
	updatePromptLayout(objectLabel.Visible)
	progressTrack.Visible = prompt.HoldDuration > 0
	if not progressTrack.Visible then
		stopHoldTween()
	end
end

ProximityPromptService.PromptShown:Connect(function(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType)
	if prompt.Style ~= Enum.ProximityPromptStyle.Custom or isSuppressedPrompt(prompt) then
		return
	end
	orderCounter += 1
	shownPrompts[prompt] = {inputType = inputType, order = orderCounter}
	chooseActivePrompt()
	updatePromptVisuals()
end)

ProximityPromptService.PromptHidden:Connect(function(prompt: ProximityPrompt)
	shownPrompts[prompt] = nil
	if activePrompt == prompt then
		stopHoldTween()
	end
	chooseActivePrompt()
	updatePromptVisuals()
end)

ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt: ProximityPrompt)
	if prompt ~= activePrompt or prompt.HoldDuration <= 0 then
		return
	end
	stopHoldTween()
	holdTween = TweenService:Create(progressFill, TweenInfo.new(prompt.HoldDuration, Enum.EasingStyle.Linear), {
		Size = UDim2.new(1, 0, 1, 0),
	})
	holdTween:Play()
end)

ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt: ProximityPrompt)
	if prompt == activePrompt then
		stopHoldTween()
	end
end)

UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed or (game.Players.LocalPlayer:GetAttribute("RoundPhase") or "Lobby") ~= "Shop" then
		return
	end
	local character = player.Character
	if character and character:GetAttribute("InCart") == true then
		return
	end
	local isKeyboardGrab = input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.E
	local isGamepadGrab = input.UserInputType == Enum.UserInputType.Gamepad1 and input.KeyCode == Enum.KeyCode.ButtonX
	if not isKeyboardGrab and not isGamepadGrab then
		return
	end
	local shopItem, inRange = getShopPromptTarget()
	if shopItem and inRange then
		RequestGrabItem:FireServer(shopItem)
	end
end)

RunService.RenderStepped:Connect(function()
	if (game.Players.LocalPlayer:GetAttribute("RoundPhase") or "Lobby") == "Shop" then
		updatePromptVisuals()
		return
	end
	hideShopPrompt()
	if activePrompt and activePrompt.Parent then
		updatePromptVisuals()
	elseif root.Visible then
		root.Visible = false
		stopHoldTween()
	end
end)
