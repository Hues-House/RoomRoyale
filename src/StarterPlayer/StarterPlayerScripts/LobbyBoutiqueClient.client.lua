--!strict
-- StarterPlayerScripts > LobbyBoutiqueClient
-- Handles the in-world lobby boutique and queue circle on the client side:
--   - Proximity prompt purchase flow on boutique pedestals
--   - Billboard refresh when any player buys an item (LobbyBoutiqueRefresh)
--   - Slow item rotation tween for display items
-- NOTE: queue circle glow/billboard visuals were removed — their driver event
-- (LobbyQueueChanged) no longer exists on the server. Reintroduce alongside a
-- server event if queue-ring feedback is wanted again.

local Players           = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")
local UITheme           = require(ReplicatedStorage:WaitForChild("UITheme"))

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Events = ReplicatedStorage:WaitForChild("Events", 15)
local LobbyBoutiqueRefresh = Events:WaitForChild("LobbyBoutiqueRefresh", 15) :: RemoteEvent
local RequestLobbyPurchase = Events:WaitForChild("RequestLobbyPurchase", 15) :: RemoteFunction
local RoundPhaseChanged = Events:WaitForChild("RoundPhaseChanged",         15) :: RemoteEvent

local currentPhase = (game.Players.LocalPlayer:GetAttribute("RoundPhase") or "Lobby") or "Lobby"
local purchaseInProgress = false

-- =========================================================
--  PURCHASE TOAST
-- =========================================================

local toastGui = Instance.new("ScreenGui")
toastGui.Name = "LobbyBoutiqueToastGui"
toastGui.ResetOnSpawn = false
toastGui.IgnoreGuiInset = true
toastGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
toastGui.DisplayOrder = 30  -- render purchase toasts ABOVE the lobby card (DisplayOrder 8)
toastGui.Parent = playerGui

local function showToast(message: string, isSuccess: boolean)
	local toast = Instance.new("Frame")
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.Size = UDim2.fromOffset(320, 56)
	toast.Position = UDim2.new(0.5, 0, 0, -70)
	toast.BackgroundColor3 = Color3.fromRGB(255, 253, 248)
	toast.BackgroundTransparency = 0.06
	toast.BorderSizePixel = 0
	toast.Parent = toastGui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = toast
	local stroke = Instance.new("UIStroke")
	stroke.Color = isSuccess and Color3.fromRGB(88, 168, 118) or Color3.fromRGB(200, 72, 72)
	stroke.Thickness = 2
	stroke.Transparency = 0.18
	stroke.Parent = toast

	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(0, 5, 1, -14)
	bar.Position = UDim2.fromOffset(8, 7)
	bar.BackgroundColor3 = stroke.Color
	bar.BorderSizePixel = 0
	bar.Parent = toast
	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(1, 0)
	barCorner.Parent = bar

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -28, 1, -10)
	label.Position = UDim2.fromOffset(20, 5)
	label.BackgroundTransparency = 1
	label.Text = message
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = Color3.fromRGB(58, 48, 36)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 15
	label.Parent = toast

	-- Slide in from top
	TweenService:Create(toast, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0, 282),  -- below the (taller, Join-button) lobby card
	}):Play()

	task.delay(2.8, function()
		if not toast.Parent then return end
		TweenService:Create(toast, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(0.5, 0, 0, -70),
		}):Play()
		task.delay(0.24, function()
			if toast.Parent then toast:Destroy() end
		end)
	end)
end

-- =========================================================
--  PROMPT PURCHASE HANDLER
-- =========================================================

ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, triggeringPlayer: Player)
	if triggeringPlayer ~= player then return end
	if currentPhase ~= "Lobby" then return end

	local part = prompt.Parent
	if not (part and CollectionService:HasTag(part, "LobbyBoutiqueItem")) then return end

	local entryId = part:GetAttribute("BoutiqueEntryId")
	if not entryId or typeof(entryId) ~= "string" then return end
	if purchaseInProgress then return end

	purchaseInProgress = true
	prompt.Enabled = false

	local ok, result = pcall(function()
		return RequestLobbyPurchase:InvokeServer(entryId)
	end)

	purchaseInProgress = false

	if ok and type(result) == "table" then
		if result.success then
			showToast("✨ Added to your collection!", true)
			-- Billboard will refresh via LobbyBoutiqueRefresh event
		elseif result.pending then
			showToast(result.message or "Complete the purchase to unlock it.", true)
			prompt.Enabled = true
		else
			showToast(result.message or "Purchase failed.", false)
			prompt.Enabled = true
		end
	else
		showToast("Something went wrong. Try again.", false)
		prompt.Enabled = true
	end
end)

-- =========================================================
--  BILLBOARD REFRESH (server fires this when any player buys)
-- =========================================================

local RARITY_COLORS = UITheme.RarityColors

local function refreshBillboardForEntry(entryId: string, buyerUserId: number)
	for _, part in ipairs(workspace:GetDescendants()) do
		if not part:IsA("BasePart") then continue end
		if not CollectionService:HasTag(part, "LobbyBoutiqueItem") then continue end
		if part:GetAttribute("BoutiqueEntryId") ~= entryId then continue end

		local bb = part:FindFirstChild("PedestalBillboard")
		if not bb then continue end

		-- Update price label to reflect the purchase
		local priceLabel = bb:FindFirstChild("Price", true)
		if priceLabel and priceLabel:IsA("TextLabel") then
			if buyerUserId == player.UserId then
				priceLabel.Text = "✓ In your collection"
				priceLabel.TextColor3 = Color3.fromRGB(88, 168, 118)
			else
				-- Someone else bought it — just note it
				local buyer = Players:GetPlayerByUserId(buyerUserId)
				local name = buyer and buyer.DisplayName or "Someone"
				priceLabel.Text = name .. " just bought this!"
				priceLabel.TextColor3 = Color3.fromRGB(120, 152, 168)
				-- Reset after 3s
				task.delay(3, function()
					if priceLabel and priceLabel.Parent then
						local attr = part:GetAttribute("BoutiqueEntryId")
						local price = part:GetAttribute("BoutiquePrice")
						if price then
							priceLabel.Text = string.format("✨ %d Style Bucks", price)
							priceLabel.TextColor3 = Color3.fromRGB(212, 167, 82)
						end
					end
				end)
			end
		end

		-- Update stroke color and disable prompt for the buyer
		local stroke = bb:FindFirstChildOfClass("UIStroke", true)
		if buyerUserId == player.UserId and stroke then
			stroke.Color = Color3.fromRGB(88, 168, 118)
			stroke.Transparency = 0.22
		end

		-- Disable prompt for the purchasing player
		if buyerUserId == player.UserId then
			local prompt = part:FindFirstChildOfClass("ProximityPrompt")
			if prompt then prompt.Enabled = false end
		end
	end
end

LobbyBoutiqueRefresh.OnClientEvent:Connect(function(entryId: string, buyerUserId: number)
	refreshBillboardForEntry(entryId, buyerUserId)
end)

-- =========================================================
--  DISPLAY ITEM ROTATION
-- =========================================================
-- Slowly rotate display items on pedestals so they feel alive.
-- We track them by CollectionService tag on the pedestal top part,
-- then find sibling DisplayItem models.

type RotatingItem = { instance: Model | BasePart, basePos: Vector3 }
local rotatingItems: {RotatingItem} = {}
local rotationAngle = 0

local function rebuildRotationList()
	table.clear(rotatingItems)
	for _, part in ipairs(workspace:GetDescendants()) do
		if part:IsA("BasePart") and CollectionService:HasTag(part, "LobbyBoutiqueItem") then
			local folder = part.Parent
			if folder then
				local display = folder:FindFirstChild("DisplayItem")
				if display then
					local basePos: Vector3
					if display:IsA("Model") then
						local p = display:GetPivot().Position
						basePos = p
					elseif display:IsA("BasePart") then
						basePos = (display :: BasePart).Position
					else
						continue
					end
					table.insert(rotatingItems, { instance = display :: Model | BasePart, basePos = basePos })
				end
			end
		end
	end
end

-- Rebuild once geometry exists, and whenever LobbyArea changes
task.delay(2, rebuildRotationList)
workspace.DescendantAdded:Connect(function(desc)
	if desc.Name == "LobbyArea" then
		task.delay(1, rebuildRotationList)
	end
end)
workspace.DescendantRemoving:Connect(function(desc)
	if desc.Name == "LobbyArea" then
		table.clear(rotatingItems)
	end
end)

local ROTATION_SPEED = 28  -- degrees per second

RunService.Heartbeat:Connect(function(dt)
	if currentPhase ~= "Lobby" then return end
	rotationAngle = (rotationAngle + ROTATION_SPEED * dt) % 360
	local rad = math.rad(rotationAngle)
	for _, entry in ipairs(rotatingItems) do
		local item = entry.instance
		if not item.Parent then continue end
		local cf = CFrame.new(entry.basePos) * CFrame.Angles(0, rad, 0)
		if item:IsA("Model") then
			item:PivotTo(cf)
		elseif item:IsA("BasePart") then
			(item :: BasePart).CFrame = cf
		end
	end
end)

-- Phase tracking
game.Players.LocalPlayer:GetAttributeChangedSignal("RoundPhase"):Connect(function()
	local phase = game.Players.LocalPlayer:GetAttribute("RoundPhase") or "Lobby"
	currentPhase = phase
	if phase ~= "Lobby" then
		table.clear(rotatingItems)
	end
end)

print("[LobbyBoutiqueClient] Loaded")
