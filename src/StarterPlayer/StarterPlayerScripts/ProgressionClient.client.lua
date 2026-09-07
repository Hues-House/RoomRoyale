local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local UITheme = require(ReplicatedStorage:WaitForChild("UITheme"))
local ViewportIcon = require(ReplicatedStorage:WaitForChild("ViewportIcon"))
local PlacementBridge = require(ReplicatedStorage:WaitForChild("PlacementBridge"))
local ProgressionConfig = require(ReplicatedStorage:WaitForChild("ProgressionConfig"))

local Events = ReplicatedStorage:WaitForChild("Events", 15)
local GetProgressionSnapshot = Events:WaitForChild("GetProgressionSnapshot", 15)
local ProgressionUpdated = Events:WaitForChild("ProgressionUpdated", 15)
local ProgressionToast = Events:WaitForChild("ProgressionToast", 15)
local RequestPersistentPurchase = Events:WaitForChild("RequestPersistentPurchase", 15)
local RoundPhaseChanged = Events:WaitForChild("RoundPhaseChanged", 15)

local currentSnapshot = nil
local currentPhase = (game.Players.LocalPlayer:GetAttribute("RoundPhase") or "Lobby") or "Lobby"
local pendingButtons = {}

local RARITY_COLORS = UITheme.RarityColors

local gui = Instance.new("ScreenGui")
gui.Name = "ProgressionGui"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui
UITheme.ApplySafeArea(gui)   -- ScreenInsets = CoreUISafeInsets: clears top bar + notch

pcall(function()
	game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
end)

local rootScale = UITheme.AttachScale(gui)  -- shared responsive scale (touch-aware)

local walletCard = Instance.new("Frame")
walletCard.Name = "WalletCard"
walletCard.AnchorPoint = Vector2.new(1, 0)
walletCard.Size = UDim2.new(0, 176, 0, 78)
walletCard.Position = UDim2.new(1, -12, 0, 12)
walletCard.BackgroundColor3 = UITheme.Color.SurfaceRaised
walletCard.BackgroundTransparency = 0.04
walletCard.BorderSizePixel = 0
walletCard.Parent = gui
UITheme.AddCorner(walletCard, UITheme.Radius.XLarge)
UITheme.AddStroke(walletCard, Color3.fromRGB(214, 167, 82), 2.5, 0.1)

local walletTitle = Instance.new("TextLabel")
walletTitle.Size = UDim2.new(1, -24, 0, 20)
walletTitle.Position = UDim2.new(0, 12, 0, 10)
walletTitle.BackgroundTransparency = 1
walletTitle.Text = "STYLE PROGRESSION"
walletTitle.TextColor3 = UITheme.Color.TextSecondary
walletTitle.TextXAlignment = Enum.TextXAlignment.Left
walletTitle.Font = UITheme.Font.Bold
walletTitle.TextSize = 13
walletTitle.Parent = walletCard
walletTitle.Visible = false  -- compact wallet: drop the redundant title

local currencyLabel = Instance.new("TextLabel")
currencyLabel.Size = UDim2.new(0, 96, 0, 34)
currencyLabel.Position = UDim2.new(0, 14, 0, 10)
currencyLabel.BackgroundTransparency = 1
currencyLabel.Text = "120 Bucks"
currencyLabel.TextColor3 = Color3.fromRGB(206, 152, 36)
currencyLabel.TextXAlignment = Enum.TextXAlignment.Left
currencyLabel.Font = UITheme.Font.Heavy
currencyLabel.TextScaled = true
currencyLabel.Parent = walletCard

local levelPill = Instance.new("TextLabel")
levelPill.Size = UDim2.new(0, 48, 0, 28)
levelPill.Position = UDim2.new(1, -60, 0, 13)
levelPill.BackgroundColor3 = Color3.fromRGB(214, 167, 82)
levelPill.BackgroundTransparency = 0.08
levelPill.BorderSizePixel = 0
levelPill.Text = "Lv. 1"
levelPill.TextColor3 = Color3.fromRGB(255, 255, 255)
levelPill.Font = UITheme.Font.Heavy
levelPill.TextSize = 15
levelPill.Parent = walletCard
UITheme.AddCorner(levelPill, UITheme.Radius.Pill)

local xpTrack = Instance.new("Frame")
xpTrack.Size = UDim2.new(1, -28, 0, 8)
xpTrack.Position = UDim2.new(0, 14, 0, 54)
xpTrack.BackgroundColor3 = UITheme.Color.Disabled
xpTrack.BackgroundTransparency = 0.54
xpTrack.BorderSizePixel = 0
xpTrack.Parent = walletCard
UITheme.AddCorner(xpTrack, UITheme.Radius.Pill)

local xpFill = Instance.new("Frame")
xpFill.Size = UDim2.new(0.2, 0, 1, 0)
xpFill.BackgroundColor3 = UITheme.Color.CoolSecondary
xpFill.BorderSizePixel = 0
xpFill.Parent = xpTrack
UITheme.AddCorner(xpFill, UITheme.Radius.Pill)

local xpLabel = Instance.new("TextLabel")
xpLabel.Size = UDim2.new(1, -24, 0, 18)
xpLabel.Position = UDim2.new(0, 12, 0, 114)
xpLabel.BackgroundTransparency = 1
xpLabel.Text = "0 / 100 XP"
xpLabel.TextColor3 = UITheme.Color.TextSecondary
xpLabel.TextXAlignment = Enum.TextXAlignment.Left
xpLabel.Font = UITheme.Font.Body
xpLabel.TextSize = 13
xpLabel.Parent = walletCard
xpLabel.Visible = false  -- compact wallet: the bar conveys progress without the text

local boutiqueButton = Instance.new("TextButton")
boutiqueButton.Name = "BoutiqueButton"
boutiqueButton.AnchorPoint = Vector2.new(1, 0)
boutiqueButton.Size = UDim2.new(0, 176, 0, 54)
boutiqueButton.Position = UDim2.new(1, -12, 0, 100)
boutiqueButton.BackgroundColor3 = UITheme.Color.WarmSurface
boutiqueButton.BackgroundTransparency = 0.08
boutiqueButton.BorderSizePixel = 0
boutiqueButton.Text = "Boutique"
boutiqueButton.TextColor3 = UITheme.Color.TextPrimary
boutiqueButton.Font = UITheme.Font.Heavy
boutiqueButton.TextSize = 22
boutiqueButton.Parent = gui
UITheme.AddCorner(boutiqueButton, UITheme.Radius.Pill)
UITheme.AddStroke(boutiqueButton, UITheme.Color.WarmPrimary, 1.4, 0.22)

local storePanel = Instance.new("Frame")
storePanel.Name = "BoutiquePanel"
storePanel.AnchorPoint = Vector2.new(1, 0)
storePanel.Size = UDim2.new(0, 428, 0, 516)
storePanel.Position = UDim2.new(1, -12, 0, 100)
storePanel.BackgroundColor3 = UITheme.Color.SurfaceRaised
storePanel.BackgroundTransparency = 0.06
storePanel.BorderSizePixel = 0
storePanel.Visible = false
storePanel.Parent = gui
UITheme.AddCorner(storePanel, UITheme.Radius.XLarge)
UITheme.AddStroke(storePanel, UITheme.Color.Stroke, 1, 0.7)

local storeHeader = Instance.new("TextLabel")
storeHeader.Size = UDim2.new(1, -88, 0, 26)
storeHeader.Position = UDim2.new(0, 16, 0, 16)
storeHeader.BackgroundTransparency = 1
storeHeader.Text = "Rotating Boutique"
storeHeader.TextColor3 = UITheme.Color.TextPrimary
storeHeader.TextXAlignment = Enum.TextXAlignment.Left
storeHeader.Font = UITheme.Font.Heavy
storeHeader.TextSize = 22
storeHeader.Parent = storePanel

local storeSubtitle = Instance.new("TextLabel")
storeSubtitle.Size = UDim2.new(1, -28, 0, 18)
storeSubtitle.Position = UDim2.new(0, 16, 0, 44)
storeSubtitle.BackgroundTransparency = 1
storeSubtitle.Text = "Fresh picks rotate daily. Own them once, style them forever."
storeSubtitle.TextColor3 = UITheme.Color.TextSecondary
storeSubtitle.TextXAlignment = Enum.TextXAlignment.Left
storeSubtitle.Font = UITheme.Font.Body
storeSubtitle.TextSize = 12
storeSubtitle.Parent = storePanel

local closeStoreButton = Instance.new("TextButton")
closeStoreButton.Size = UDim2.new(0, 34, 0, 34)
closeStoreButton.Position = UDim2.new(1, -50, 0, 14)
closeStoreButton.BackgroundColor3 = UITheme.Color.Surface
closeStoreButton.BackgroundTransparency = 0.08
closeStoreButton.BorderSizePixel = 0
closeStoreButton.Text = "X"
closeStoreButton.TextColor3 = UITheme.Color.TextPrimary
closeStoreButton.Font = UITheme.Font.Heavy
closeStoreButton.TextSize = 16
closeStoreButton.Parent = storePanel
UITheme.AddCorner(closeStoreButton, UITheme.Radius.Pill)

local storeScroller = Instance.new("ScrollingFrame")
storeScroller.Size = UDim2.new(1, -20, 1, -84)
storeScroller.Position = UDim2.new(0, 10, 0, 72)
storeScroller.BackgroundTransparency = 1
storeScroller.BorderSizePixel = 0
storeScroller.ScrollBarThickness = 6
storeScroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
storeScroller.CanvasSize = UDim2.new()
storeScroller.Parent = storePanel

local storeLayout = Instance.new("UIListLayout")
storeLayout.Padding = UDim.new(0, 10)
storeLayout.Parent = storeScroller

local collectionPanel = Instance.new("Frame")
collectionPanel.Name = "CollectionPanel"
collectionPanel.AnchorPoint = Vector2.new(0, 0.5)
collectionPanel.Size = UDim2.new(0, 252, 0, 404)
collectionPanel.Position = UDim2.new(0, 18, 0.58, 0)
collectionPanel.BackgroundColor3 = UITheme.Color.SurfaceRaised
collectionPanel.BackgroundTransparency = 0.08
collectionPanel.BorderSizePixel = 0
collectionPanel.Visible = false
collectionPanel.Parent = gui
UITheme.AddCorner(collectionPanel, UITheme.Radius.XLarge)
UITheme.AddStroke(collectionPanel, UITheme.Color.Stroke, 1, 0.72)

local collectionTitle = Instance.new("TextLabel")
collectionTitle.Size = UDim2.new(1, -24, 0, 24)
collectionTitle.Position = UDim2.new(0, 12, 0, 12)
collectionTitle.BackgroundTransparency = 1
collectionTitle.Text = "Owned Collection"
collectionTitle.TextColor3 = UITheme.Color.TextPrimary
collectionTitle.TextXAlignment = Enum.TextXAlignment.Left
collectionTitle.Font = UITheme.Font.Heavy
collectionTitle.TextSize = 20
collectionTitle.Parent = collectionPanel

local collectionSubtitle = Instance.new("TextLabel")
collectionSubtitle.Size = UDim2.new(1, -24, 0, 16)
collectionSubtitle.Position = UDim2.new(0, 12, 0, 36)
collectionSubtitle.BackgroundTransparency = 1
collectionSubtitle.Text = "Tap any owned piece to place it in your room."
collectionSubtitle.TextColor3 = UITheme.Color.TextSecondary
collectionSubtitle.TextXAlignment = Enum.TextXAlignment.Left
collectionSubtitle.Font = UITheme.Font.Body
collectionSubtitle.TextSize = 11
collectionSubtitle.Parent = collectionPanel

local collectionScroller = Instance.new("ScrollingFrame")
collectionScroller.Size = UDim2.new(1, -16, 1, -72)
collectionScroller.Position = UDim2.new(0, 8, 0, 62)
collectionScroller.BackgroundTransparency = 1
collectionScroller.BorderSizePixel = 0
collectionScroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
collectionScroller.CanvasSize = UDim2.new()
collectionScroller.ScrollBarThickness = 6
collectionScroller.Parent = collectionPanel

local collectionLayout = Instance.new("UIListLayout")
collectionLayout.Padding = UDim.new(0, 8)
collectionLayout.Parent = collectionScroller

local toastHolder = Instance.new("Frame")
toastHolder.AnchorPoint = Vector2.new(1, 1)
toastHolder.Size = UDim2.new(0, 312, 0, 240)
toastHolder.Position = UDim2.new(1, -18, 1, -18)
toastHolder.BackgroundTransparency = 1
toastHolder.Parent = gui

local toastLayout = Instance.new("UIListLayout")
toastLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
toastLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
toastLayout.Padding = UDim.new(0, 8)
toastLayout.Parent = toastHolder

local function humanizeNumber(value)
	return tostring(math.max(0, math.floor(tonumber(value) or 0)))
end

local function updateScale()
	-- AttachScale already keeps rootScale synced; this stays for any explicit callers
	-- and now uses the shared, touch-aware formula.
	rootScale.Scale = UITheme.GetUIScale()
end

local function makeToast(text: string, accent: Color3)
	local toast = Instance.new("Frame")
	toast.Size = UDim2.fromOffset(300, 54)
	toast.BackgroundColor3 = UITheme.Color.SurfaceRaised
	toast.BackgroundTransparency = 0.06
	toast.BorderSizePixel = 0
	toast.Parent = toastHolder
	UITheme.AddCorner(toast, UITheme.Radius.Large)
	UITheme.AddStroke(toast, accent, 1.5, 0.2)

	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(0, 6, 1, -14)
	bar.Position = UDim2.new(0, 8, 0, 7)
	bar.BackgroundColor3 = accent
	bar.BorderSizePixel = 0
	bar.Parent = toast
	UITheme.AddCorner(bar, UITheme.Radius.Pill)

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -28, 1, -12)
	label.Position = UDim2.new(0, 20, 0, 6)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextColor3 = UITheme.Color.TextPrimary
	label.Font = UITheme.Font.Bold
	label.TextSize = 14
	label.Parent = toast

	local scale = Instance.new("UIScale")
	scale.Scale = 0.9
	scale.Parent = toast

	TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(toast, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 0.02 }):Play()

	task.delay(2.6, function()
		if not toast.Parent then
			return
		end
		TweenService:Create(toast, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			BackgroundTransparency = 1,
		}):Play()
		TweenService:Create(label, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			TextTransparency = 1,
		}):Play()
		task.delay(0.2, function()
			if toast.Parent then
				toast:Destroy()
			end
		end)
	end)
end

local function clearChildrenExceptLayouts(container: Instance)
	for _, child in ipairs(container:GetChildren()) do
		if not child:IsA("UIListLayout") and not child:IsA("UIGridLayout") then
			child:Destroy()
		end
	end
end

local function updateWallet(snapshot)
	currentSnapshot = snapshot
	currencyLabel.Text = string.format("%s Bucks", humanizeNumber(snapshot.currency))
	levelPill.Text = string.format("Lv. %d", snapshot.level or 1)
	xpLabel.Text = string.format("%s / %s XP", humanizeNumber(snapshot.xpIntoLevel), humanizeNumber(snapshot.xpForNextLevel))
	local progress = 0
	if (snapshot.xpForNextLevel or 0) > 0 then
		progress = math.clamp((snapshot.xpIntoLevel or 0) / snapshot.xpForNextLevel, 0, 1)
	end
	TweenService:Create(xpFill, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.new(progress, 0, 1, 0),
	}):Play()
end

local function requestPurchase(entryId: string, purchaseType: string)
	local button = pendingButtons[entryId]
	if button then
		button.AutoButtonColor = false
		button.Text = "Working..."
	end
	local ok, result = pcall(function()
		return RequestPersistentPurchase:InvokeServer(entryId, purchaseType)
	end)
	if button and button.Parent then
		button.AutoButtonColor = true
	end
	if not ok or type(result) ~= "table" then
		makeToast("The boutique could not complete that purchase.", UITheme.Color.Danger)
		return
	end
	if result.snapshot then
		updateWallet(result.snapshot)
		if result.snapshot.rotationEntries then
			currentSnapshot = result.snapshot
		end
	end
	makeToast(result.message or (result.success and "Purchase complete" or "Purchase failed"), result.success and UITheme.Color.TextPositive or UITheme.Color.Danger)
	if currentSnapshot then
		currentSnapshot = result.snapshot or currentSnapshot
	end
	if currentSnapshot then
		-- Rebuild after the current frame so stale buttons are gone first.
		task.defer(function()
			if currentSnapshot then
				updateWallet(currentSnapshot)
			end
		end)
	end
end

local function rebuildStore(snapshot)
	clearChildrenExceptLayouts(storeScroller)
	table.clear(pendingButtons)
	for _, entry in ipairs(snapshot.rotationEntries or {}) do
		local card = Instance.new("Frame")
		card.Name = "StoreCard_" .. tostring(entry.entryId)
		card.Size = UDim2.new(1, -8, 0, 114)
		card.BackgroundColor3 = UITheme.Color.Surface
		card.BackgroundTransparency = 0.1
		card.BorderSizePixel = 0
		card.Parent = storeScroller
		UITheme.AddCorner(card, UITheme.Radius.Large)
		UITheme.AddStroke(card, UITheme.Color.Stroke, 1, 0.78)

		local iconHolder = Instance.new("Frame")
		iconHolder.Size = UDim2.fromOffset(78, 78)
		iconHolder.Position = UDim2.fromOffset(14, 18)
		iconHolder.BackgroundColor3 = UITheme.Color.WarmSurface
		iconHolder.BackgroundTransparency = 0.08
		iconHolder.BorderSizePixel = 0
		iconHolder.Parent = card
		UITheme.AddCorner(iconHolder, UITheme.Radius.Large)
		ViewportIcon.Fill(iconHolder, entry.itemId)

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(1, -192, 0, 24)
		nameLabel.Position = UDim2.fromOffset(104, 14)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = entry.name or entry.itemId
		nameLabel.TextColor3 = UITheme.Color.TextPrimary
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Font = UITheme.Font.Heavy
		nameLabel.TextSize = 16
		nameLabel.Parent = card

		local metaLabel = Instance.new("TextLabel")
		metaLabel.Size = UDim2.new(1, -192, 0, 18)
		metaLabel.Position = UDim2.fromOffset(104, 38)
		metaLabel.BackgroundTransparency = 1
		metaLabel.Text = string.format("%s • %s • Lv.%d", entry.rarity or "Common", entry.theme or "Neutral", entry.levelRequired or 1)
		metaLabel.TextColor3 = RARITY_COLORS[entry.rarity or "Common"] or UITheme.Color.TextSecondary
		metaLabel.TextXAlignment = Enum.TextXAlignment.Left
		metaLabel.Font = UITheme.Font.Bold
		metaLabel.TextSize = 11
		metaLabel.Parent = card

		local descLabel = Instance.new("TextLabel")
		descLabel.Size = UDim2.new(1, -192, 0, 34)
		descLabel.Position = UDim2.fromOffset(104, 56)
		descLabel.BackgroundTransparency = 1
		descLabel.TextWrapped = true
		descLabel.Text = entry.description or ""
		descLabel.TextColor3 = UITheme.Color.TextSecondary
		descLabel.TextXAlignment = Enum.TextXAlignment.Left
		descLabel.TextYAlignment = Enum.TextYAlignment.Top
		descLabel.Font = UITheme.Font.Body
		descLabel.TextSize = 11
		descLabel.Parent = card

		local buyButton = Instance.new("TextButton")
		buyButton.Name = "BuyButton"
		buyButton.Size = UDim2.fromOffset(86, 34)
		buyButton.Position = UDim2.new(1, -98, 0, 40)
		buyButton.BackgroundColor3 = entry.owned and UITheme.Color.SurfaceRaised or UITheme.Color.CoolSecondary
		buyButton.BackgroundTransparency = entry.owned and 0.2 or 0.04
		buyButton.BorderSizePixel = 0
		buyButton.TextColor3 = entry.owned and UITheme.Color.TextSecondary or UITheme.Color.TextOnDark
		buyButton.Font = UITheme.Font.Heavy
		buyButton.TextSize = 13
		buyButton.Text = entry.owned and "Owned" or (entry.purchaseType == "Coins" and string.format("%d", entry.currencyPrice or 0) or string.format("R$ %d", entry.robuxPrice or 0))
		buyButton.Parent = card
		UITheme.AddCorner(buyButton, UITheme.Radius.Pill)

		if not entry.owned then
			pendingButtons[entry.entryId] = buyButton
			buyButton.MouseButton1Click:Connect(function()
				requestPurchase(entry.entryId, entry.purchaseType)
			end)
		else
			buyButton.AutoButtonColor = false
		end
	end
end

local function rebuildCollection(snapshot)
	clearChildrenExceptLayouts(collectionScroller)
	local entries = snapshot.collectionEntries or {}
	collectionPanel.Visible = currentPhase == "Style" and #entries > 0
	for index, entry in ipairs(entries) do
		if index > ProgressionConfig.MaxCollectionEntries then
			break
		end
		local card = Instance.new("TextButton")
		card.Name = "CollectionCard_" .. tostring(entry.itemId)
		card.Size = UDim2.new(1, -6, 0, 76)
		card.BackgroundColor3 = UITheme.Color.Surface
		card.BackgroundTransparency = 0.08
		card.BorderSizePixel = 0
		card.Text = ""
		card.Parent = collectionScroller
		UITheme.AddCorner(card, UITheme.Radius.Large)
		UITheme.AddStroke(card, UITheme.Color.Stroke, 1, 0.78)

		local iconHolder = Instance.new("Frame")
		iconHolder.Size = UDim2.fromOffset(58, 58)
		iconHolder.Position = UDim2.fromOffset(9, 9)
		iconHolder.BackgroundColor3 = UITheme.Color.WarmSurface
		iconHolder.BackgroundTransparency = 0.08
		iconHolder.BorderSizePixel = 0
		iconHolder.Parent = card
		UITheme.AddCorner(iconHolder, UITheme.Radius.Large)
		ViewportIcon.Fill(iconHolder, entry.itemId)

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(1, -138, 0, 22)
		nameLabel.Position = UDim2.fromOffset(76, 10)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = entry.name or entry.itemId
		nameLabel.TextColor3 = UITheme.Color.TextPrimary
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Font = UITheme.Font.Bold
		nameLabel.TextSize = 14
		nameLabel.Parent = card

		local metaLabel = Instance.new("TextLabel")
		metaLabel.Size = UDim2.new(1, -138, 0, 18)
		metaLabel.Position = UDim2.fromOffset(76, 32)
		metaLabel.BackgroundTransparency = 1
		metaLabel.Text = string.format("%s • %s", entry.rarity or "Common", entry.theme or "Neutral")
		metaLabel.TextColor3 = RARITY_COLORS[entry.rarity or "Common"] or UITheme.Color.TextSecondary
		metaLabel.TextXAlignment = Enum.TextXAlignment.Left
		metaLabel.Font = UITheme.Font.Body
		metaLabel.TextSize = 11
		metaLabel.Parent = card

		local placeLabel = Instance.new("TextLabel")
		placeLabel.Size = UDim2.new(0, 54, 0, 26)
		placeLabel.Position = UDim2.new(1, -66, 0.5, -13)
		placeLabel.BackgroundColor3 = UITheme.Color.CoolSecondary
		placeLabel.BackgroundTransparency = 0.08
		placeLabel.BorderSizePixel = 0
		placeLabel.Text = "Place"
		placeLabel.TextColor3 = UITheme.Color.TextOnDark
		placeLabel.Font = UITheme.Font.Heavy
		placeLabel.TextSize = 12
		placeLabel.Parent = card
		UITheme.AddCorner(placeLabel, UITheme.Radius.Pill)

		card.MouseButton1Click:Connect(function()
			PlacementBridge.Toggle:Fire("cancel")
			PlacementBridge.SetItem:Fire(entry.itemId)
			PlacementBridge.Toggle:Fire("enter")
			makeToast(string.format("Placing %s", entry.name or entry.itemId), UITheme.Color.CoolSecondary)
		end)
	end
end

local function applySnapshot(snapshot)
	if type(snapshot) ~= "table" then
		return
	end
	currentSnapshot = snapshot
	updateWallet(snapshot)
	rebuildStore(snapshot)
	rebuildCollection(snapshot)
end

local function refreshVisibility()
	-- During Lobby, the LobbyClient hub owns boutique/collection — hide the floating button and panel.
	-- During Style, the collection panel is still useful for quick reference.
	-- During Judge/Results, hide everything.
	local isLobby = currentPhase == "Lobby"
	local isJudgeOrResults = currentPhase == "Judge" or currentPhase == "Results"
	boutiqueButton.Visible = not isLobby and not isJudgeOrResults and currentPhase ~= "Style" and currentPhase ~= "Shop"  -- hide during the round Shop (focused cart minigame); collided with the cart buttons
	collectionPanel.Visible = currentPhase == "Style" and currentSnapshot ~= nil and #(currentSnapshot.collectionEntries or {}) > 0
	if (isLobby or isJudgeOrResults or currentPhase == "Style") and storePanel.Visible then
		storePanel.Visible = false
	end
	-- Wallet hides only while decorating inside your own house (the Decorate panel needs the
	-- top-right space); otherwise it stays visible in all phases.
	walletCard.Visible = not (player:GetAttribute("InOwnHouse") == true) and currentPhase ~= "Shop"
end

boutiqueButton.MouseButton1Click:Connect(function()
	storePanel.Visible = not storePanel.Visible
end)

closeStoreButton.MouseButton1Click:Connect(function()
	storePanel.Visible = false
end)

player:GetAttributeChangedSignal("InOwnHouse"):Connect(refreshVisibility)
ProgressionUpdated.OnClientEvent:Connect(applySnapshot)

ProgressionToast.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then
		return
	end
	if payload.kind == "currency" then
		makeToast(string.format("+%d %s", payload.currency or 0, ProgressionConfig.CurrencyName), UITheme.Color.TextPositive)
	elseif payload.kind == "roundRewards" then
		makeToast(string.format("Round rewards: +%d Bucks, +%d XP", payload.currency or 0, payload.xp or 0), UITheme.Color.WarmPrimary)
	elseif payload.kind == "purchase" then
		makeToast(payload.message or "Added to collection", UITheme.Color.CoolSecondary)
	elseif payload.kind == "purchaseSpent" then
		makeToast(string.format("Spent %d Bucks", payload.currency or 0), UITheme.Color.WarmPrimary)
	end
end)

game.Players.LocalPlayer:GetAttributeChangedSignal("RoundPhase"):Connect(function()
	local phase = game.Players.LocalPlayer:GetAttribute("RoundPhase") or "Lobby"
	currentPhase = phase
	refreshVisibility()
	if currentSnapshot then
		rebuildCollection(currentSnapshot)
	end
end)

game.Players.LocalPlayer:GetAttributeChangedSignal("RoundPhase"):Connect(function()
	currentPhase = (game.Players.LocalPlayer:GetAttribute("RoundPhase") or "Lobby") or currentPhase
	refreshVisibility()
	if currentSnapshot then
		rebuildCollection(currentSnapshot)
	end
end)

updateScale()
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(updateScale)

task.defer(function()
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end
	local ok, snapshot = pcall(function()
		return GetProgressionSnapshot:InvokeServer()
	end)
	if ok and type(snapshot) == "table" then
		applySnapshot(snapshot)
	end
	refreshVisibility()
end)
