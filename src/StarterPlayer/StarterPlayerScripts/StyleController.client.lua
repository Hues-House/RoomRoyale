-- StarterPlayerScripts > StyleController
-- Style phase UI:
--   Tab 1: Items   — cart contents as icons; click to enter place mode
--   Tab 2: Walls   — wall zone selector + color swatches → fires SetRoomSurface
--   Tab 3: Floor   — material + color swatches → fires SetRoomSurface
--   Tab 4: Lights  — mood presets → fires SetRoomLighting
-- Clicking a wall/floor surface directly opens the matching design panel.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local UserInputService  = game:GetService("UserInputService")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")

local UITheme = require(ReplicatedStorage:WaitForChild("UITheme"))
local PlacementBridge = require(ReplicatedStorage:WaitForChild("PlacementBridge"))
local ViewportIcon = require(ReplicatedStorage:WaitForChild("ViewportIcon"))
local ItemDatabaseMod = require(ReplicatedStorage:WaitForChild("ItemDatabase"))
local RARITY_COLORS = UITheme.RarityColors

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Events               = ReplicatedStorage:WaitForChild("Events", 15)
local RoundPhaseChanged = Events:WaitForChild("RoundPhaseChanged", 15)
local GetCartContents      = Events:WaitForChild("GetCartContents", 15)
local SetRoomSurface       = Events:WaitForChild("SetRoomSurface", 15)
local SetItemAppearance    = Events:WaitForChild("SetItemAppearance", 15)
local ResetItemAppearance  = Events:WaitForChild("ResetItemAppearance", 15)
local PickupPlacedItem     = Events:WaitForChild("PickupPlacedItem", 15)
local ItemPlaced           = Events:WaitForChild("ItemPlaced", 15)
local OpenSurfacePicker    = Events:WaitForChild("OpenSurfacePicker", 15)
local OpenItemAppearance   = Events:WaitForChild("OpenItemAppearance", 15)
local GetProgressionSnapshot = Events:WaitForChild("GetProgressionSnapshot", 15)  -- owned-collection source for the hub Furniture tab

local SetRoomLighting do
	local ok, ev = pcall(function() return Events:WaitForChild("SetRoomLighting", 3) end)
	if ok and ev then
		SetRoomLighting = ev
	else
		SetRoomLighting = Instance.new("RemoteEvent")
		SetRoomLighting.Name = "SetRoomLighting"
		SetRoomLighting.Parent = Events
	end
end

local WALL_COLORS = {
	Color3.fromRGB(245,240,232), Color3.fromRGB(220,210,195),
	Color3.fromRGB(255,255,255), Color3.fromRGB(30, 30, 30),
	Color3.fromRGB(0,  81, 186), Color3.fromRGB(255,218, 26),
}
local LOCKED_WALL_COLORS = {
	Color3.fromRGB(180, 60, 60), Color3.fromRGB(60, 140, 80),
	Color3.fromRGB(180,120, 60), Color3.fromRGB(100,100,160),
	Color3.fromRGB(200,180,220), Color3.fromRGB(140,200,210),
}
local FLOOR_COLORS = {
	Color3.fromRGB(180,140,100), Color3.fromRGB(140,100, 70),
	Color3.fromRGB(220,215,205), Color3.fromRGB(60, 60, 60),
	Color3.fromRGB(200,180,160), Color3.fromRGB(100,140,120),
}
local LOCKED_FLOOR_COLORS = {
	Color3.fromRGB(80,  60, 50), Color3.fromRGB(220,220,220),
	Color3.fromRGB(160,120,100), Color3.fromRGB(200,160,120),
	Color3.fromRGB(100, 80, 60), Color3.fromRGB(240,230,210),
}
local FLOOR_MATERIALS = {
	{name="Wood",    mat=Enum.Material.WoodPlanks},
	{name="Carpet",  mat=Enum.Material.Fabric},
	{name="Tile",    mat=Enum.Material.SmoothPlastic},
}
local LOCKED_FLOOR_MATERIALS = {
	{name="Concrete", mat=Enum.Material.Concrete},
	{name="Marble",   mat=Enum.Material.Marble},
	{name="Grass",    mat=Enum.Material.Grass},
	{name="Slate",    mat=Enum.Material.Slate},
}
local ITEM_COLORS = {
	Color3.fromRGB(255,255,255), Color3.fromRGB(30, 30, 30),
	Color3.fromRGB(200,180,160), Color3.fromRGB(100,149,237),
	Color3.fromRGB(147,112,219), Color3.fromRGB(60, 140, 80),
}
local ITEM_MATERIALS = {
	{name="Plastic", mat=Enum.Material.SmoothPlastic},
	{name="Wood",    mat=Enum.Material.WoodPlanks},
	{name="Fabric",  mat=Enum.Material.Fabric},
	{name="Metal",   mat=Enum.Material.Metal},
}
local LIGHT_MOODS = {
	{label="Daylight",  emoji="☀️",  ambient=Color3.fromRGB(220,220,210), pointColor=Color3.fromRGB(255,248,220), brightness=1.2},
	{label="Warm",      emoji="🕯️",  ambient=Color3.fromRGB(180,140,90),  pointColor=Color3.fromRGB(255,200,120), brightness=1.5},
	{label="Cool",      emoji="🌙",  ambient=Color3.fromRGB(100,120,180), pointColor=Color3.fromRGB(180,200,255), brightness=1.0},
	{label="Moody",     emoji="🌑",  ambient=Color3.fromRGB(40,35,50),   pointColor=Color3.fromRGB(160,120,200), brightness=0.7},
	{label="Rose",      emoji="🌸",  ambient=Color3.fromRGB(200,140,150), pointColor=Color3.fromRGB(255,180,200), brightness=1.1},
	{label="Studio",    emoji="💡",  ambient=Color3.fromRGB(230,230,230), pointColor=Color3.fromRGB(255,255,255), brightness=1.8},
}

local isStylePhase   = false
local isHousingPhase = (game.Players.LocalPlayer:GetAttribute("RoundPhase") or "Lobby") == "Lobby"
local function isActivePhase(): boolean return isStylePhase or isHousingPhase end

local function findPlayerRoom(): Model?
	local styleRoom = workspace:FindFirstChild("StyleRoom_" .. player.UserId)
	if styleRoom then return styleRoom :: Model end
	local district = workspace:FindFirstChild("HousingDistrict")
	if district then
		local houseRoom = district:FindFirstChild("HouseRoom_" .. player.UserId)
		if houseRoom then return houseRoom :: Model end
	end
	return nil
end
local function findPlacedFolder(): Folder?
	local room = findPlayerRoom()
	if not room then return nil end
	return room:FindFirstChild("PlacedItems") :: Folder?
end

local cartItems: {{itemId:string, itemName:string}} = {}
local selectedFloorMat   = Enum.Material.WoodPlanks
local selectedFloorColor = Color3.fromRGB(180,140,100)
local placedMap: {[string]: string} = {}
local currentlyPlacingId: string? = nil
local lastPointerPosition = Vector2.new(640, 360)
local surfacePromptGuis: {[Instance]: BillboardGui} = {}
local stylePanelVisible = true

local function makeCorner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 8)
	c.Parent = parent
end

local styleGui = Instance.new("ScreenGui")
styleGui.Name = "StyleGui"; styleGui.ResetOnSpawn = false
styleGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
styleGui.Enabled = false; styleGui.Parent = playerGui
UITheme.ApplySafeArea(styleGui)   -- ScreenInsets = CoreUISafeInsets (clears top bar/notch; replaces IgnoreGuiInset)

local styleScale = Instance.new("UIScale"); styleScale.Parent = styleGui

local scrim = Instance.new("Frame")
scrim.Name = "Scrim"; scrim.Size = UDim2.fromScale(1, 1)
scrim.BackgroundColor3 = UITheme.Color.WarmPrimary
scrim.BackgroundTransparency = 1; scrim.BorderSizePixel = 0; scrim.Parent = styleGui

local panel = Instance.new("Frame")
panel.Name = "StylePanel"; panel.AnchorPoint = Vector2.new(1, 0.5)
panel.Size = UDim2.new(0, 360, 0, 500)
panel.Position = UDim2.new(1, -16, 0.5, 0)
panel.BackgroundColor3 = UITheme.Color.SurfaceRaised
panel.BackgroundTransparency = 0.12; panel.BorderSizePixel = 0; panel.Parent = styleGui
makeCorner(panel, 22); UITheme.AddStroke(panel, UITheme.Color.Stroke, 1, 0.88)
local panelSizeConstraint = Instance.new("UISizeConstraint")  -- safety cap on extreme resolutions/aspect ratios
panelSizeConstraint.MinSize = Vector2.new(260, 200); panelSizeConstraint.MaxSize = Vector2.new(460, 640)
panelSizeConstraint.Parent = panel

local headerCard = Instance.new("Frame")
headerCard.Name = "HeaderCard"; headerCard.Size = UDim2.new(1, -16, 0, 38)
headerCard.Position = UDim2.new(0, 8, 0, 8)
headerCard.BackgroundColor3 = UITheme.Color.WarmSurface
headerCard.BackgroundTransparency = 0.22; headerCard.BorderSizePixel = 0; headerCard.Parent = panel
makeCorner(headerCard, 16)

local headerAccent = Instance.new("Frame")
headerAccent.Size = UDim2.new(0, 4, 1, -18); headerAccent.Position = UDim2.new(0, 8, 0, 9)
headerAccent.BackgroundColor3 = UITheme.Color.Blush; headerAccent.BorderSizePixel = 0; headerAccent.Parent = headerCard
makeCorner(headerAccent, 999)

local headerTitle = Instance.new("TextLabel")
headerTitle.Size = UDim2.new(1, -150, 0, 24); headerTitle.Position = UDim2.new(0, 16, 0, 7)
headerTitle.BackgroundTransparency = 1; headerTitle.Text = "Decorate"
headerTitle.TextColor3 = UITheme.Color.TextPrimary; headerTitle.TextXAlignment = Enum.TextXAlignment.Left
headerTitle.Font = UITheme.Font.Heavy; headerTitle.TextSize = 16; headerTitle.Parent = headerCard

local styleHint = Instance.new("TextLabel")
styleHint.Size = UDim2.new(1, -28, 0, 18); styleHint.Position = UDim2.new(0, 22, 0, 34)
styleHint.BackgroundTransparency = 1; styleHint.TextColor3 = UITheme.Color.TextSecondary
styleHint.TextXAlignment = Enum.TextXAlignment.Left; styleHint.Font = UITheme.Font.Body
styleHint.TextSize = 12; styleHint.Text = ""; styleHint.Visible = false; styleHint.Parent = headerCard  -- one-line header now; hint removed to free vertical space

local itemStatusLabel = Instance.new("TextLabel")
itemStatusLabel.Size = UDim2.new(0, 86, 0, 22); itemStatusLabel.Position = UDim2.new(1, -140, 0, 8)
itemStatusLabel.BackgroundColor3 = UITheme.Color.WarmSurface; itemStatusLabel.BackgroundTransparency = 0.28
itemStatusLabel.BorderSizePixel = 0; itemStatusLabel.TextColor3 = UITheme.Color.TextPrimary
itemStatusLabel.TextXAlignment = Enum.TextXAlignment.Center; itemStatusLabel.Font = UITheme.Font.Bold
itemStatusLabel.TextSize = 12; itemStatusLabel.Text = "Ready 0  |  Room 0"; itemStatusLabel.Parent = headerCard
makeCorner(itemStatusLabel, 999)

-- Close (×) button — lets the player dismiss the panel; the Decorate button is hidden while open.
local closeX = Instance.new("TextButton")
closeX.Name = "CloseX"; closeX.AnchorPoint = Vector2.new(1, 0)
closeX.Size = UDim2.fromOffset(30, 30); closeX.Position = UDim2.new(1, -10, 0, 12)
closeX.BackgroundColor3 = UITheme.Color.Surface; closeX.BackgroundTransparency = 0.1
closeX.BorderSizePixel = 0; closeX.Text = "✕"; closeX.TextColor3 = UITheme.Color.TextPrimary
closeX.Font = UITheme.Font.Bold; closeX.TextSize = 16; closeX.ZIndex = 6; closeX.Parent = panel
makeCorner(closeX, 999)

local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, -16, 0, 36); tabBar.Position = UDim2.new(0, 8, 0, 52)
tabBar.BackgroundColor3 = UITheme.Color.Base; tabBar.BackgroundTransparency = 0.68
tabBar.BorderSizePixel = 0; tabBar.Parent = panel; makeCorner(tabBar, 14)
local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
tabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
tabLayout.Padding = UDim.new(0, 5); tabLayout.Parent = tabBar

local content = Instance.new("Frame")
content.Size = UDim2.new(1, -16, 1, -98); content.Position = UDim2.new(0, 8, 0, 90)
content.BackgroundTransparency = 1; content.BorderSizePixel = 0; content.Parent = panel

local feedbackToast = Instance.new("TextLabel")
feedbackToast.Size = UDim2.new(0, 220, 0, 32); feedbackToast.AnchorPoint = Vector2.new(0.5, 1)
feedbackToast.Position = UDim2.new(0.5, 0, 0, -8)
feedbackToast.BackgroundColor3 = UITheme.Color.CoolSecondary
feedbackToast.BackgroundTransparency = 1; feedbackToast.TextTransparency = 1
feedbackToast.TextColor3 = Color3.new(1,1,1); feedbackToast.Font = UITheme.Font.Bold
feedbackToast.TextSize = 13; feedbackToast.Visible = false; feedbackToast.Parent = panel
makeCorner(feedbackToast, 12)

local customizeToggle = Instance.new("TextButton")
customizeToggle.Name = "CustomizeToggle"; customizeToggle.AnchorPoint = Vector2.new(0, 1)
customizeToggle.Size = UDim2.new(0, 168, 0, 48); customizeToggle.Position = UDim2.new(0.5, 8, 1, -64)
customizeToggle.BackgroundColor3 = UITheme.Color.WarmSurface; customizeToggle.BackgroundTransparency = 0.18
customizeToggle.BorderSizePixel = 0; customizeToggle.Text = "🎨 Customize"
customizeToggle.TextColor3 = UITheme.Color.TextPrimary; customizeToggle.Font = UITheme.Font.Heavy
customizeToggle.TextSize = 18; customizeToggle.Visible = false; customizeToggle.Parent = styleGui
makeCorner(customizeToggle, 999)
UITheme.AddStroke(customizeToggle, UITheme.Color.WarmPrimary, 1.5, 0.22)
-- Bottom-center, stacked ABOVE HousingClient's Decorate button (at 1,-170): staying
-- higher (unscaled -240) means UIScale only widens the gap, never causes overlap.

local tabs: {[string]: {btn: TextButton, page: Frame}} = {}
local activeTab = ""

local function setTab(name)
	activeTab = name
	for tabName, t in pairs(tabs) do
		local isActive = tabName == name
		t.btn.BackgroundColor3 = isActive and UITheme.Color.CoolSecondary or UITheme.Color.SurfaceRaised
		t.btn.BackgroundTransparency = isActive and 0.18 or 0.58
		t.btn.TextColor3 = UITheme.Color.TextPrimary
		local stroke = t.btn:FindFirstChild("TabStroke")
		if stroke and stroke:IsA("UIStroke") then
			stroke.Transparency = isActive and 0.68 or 0.92
		end
		t.page.Visible = isActive
	end
end

-- Items tab only applies to the Style round (the cart). In the hub house it's empty
-- (furniture placement lives in HousingClient's Decorate picker), so hide it there.
local function setItemsTabVisible(show: boolean)
	local t = tabs["Items"]
	if not t then return end
	t.btn.Visible = show
	if not show and activeTab == "Items" then setTab("Walls") end
end

local function addTab(name)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1/4, -4, 1, -6); btn.BackgroundColor3 = UITheme.Color.SurfaceRaised
	btn.BackgroundTransparency = 0.58; btn.BorderSizePixel = 0
	btn.TextColor3 = UITheme.Color.TextPrimary; btn.Font = UITheme.Font.Bold
	btn.TextSize = 13; btn.Text = name; btn.Parent = tabBar; makeCorner(btn, 10)
	local tabStroke = UITheme.AddStroke(btn, UITheme.Color.Stroke, 1, 0.92)
	tabStroke.Name = "TabStroke"
	local page = Instance.new("ScrollingFrame")
	page.Size = UDim2.fromScale(1, 1); page.BackgroundTransparency = 1; page.BorderSizePixel = 0
	page.ScrollBarThickness = 5; page.CanvasSize = UDim2.new(); page.AutomaticCanvasSize = Enum.AutomaticSize.Y
	page.Visible = false; page.Parent = content
	tabs[name] = {btn = btn, page = page}
	btn.MouseButton1Click:Connect(function() setTab(name) end)
	return page
end

local itemPage = addTab("Items")
tabs["Items"].btn.Text = "Furniture"  -- internal key stays "Items"; label reads "Furniture"
local itemGrid = Instance.new("UIGridLayout")
-- Scale-based cells: 2 columns (0.47 width each + 0.04 padding + 0.47 = 0.98 of the page).
-- The engine handles column division + wrapping, so no manual AbsoluteSize math (the
-- source of the old race/overlap). Cell HEIGHT stays fixed so card internals are predictable.
itemGrid.CellSize = UDim2.new(0.47, 0, 0, 132); itemGrid.CellPadding = UDim2.new(0.04, 0, 0, 10)
itemGrid.HorizontalAlignment = Enum.HorizontalAlignment.Center
itemGrid.SortOrder = Enum.SortOrder.LayoutOrder; itemGrid.Parent = itemPage

-- Graceful empty state (new players own no furniture yet): fills the panel instead
-- of leaving a big empty slab, and points players at the boutique.
local emptyState = Instance.new("Frame")
emptyState.Name = "EmptyState"; emptyState.Size = UDim2.fromScale(1, 1)
emptyState.BackgroundTransparency = 1; emptyState.ZIndex = 5
emptyState.Visible = false; emptyState.Parent = content
local emptyLayout = Instance.new("UIListLayout")
emptyLayout.FillDirection = Enum.FillDirection.Vertical
emptyLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
emptyLayout.VerticalAlignment = Enum.VerticalAlignment.Center
emptyLayout.Padding = UDim.new(0, 8); emptyLayout.Parent = emptyState
local emptyIcon = Instance.new("TextLabel")
emptyIcon.Size = UDim2.new(0, 60, 0, 60); emptyIcon.BackgroundTransparency = 1
emptyIcon.Text = "🛋️"; emptyIcon.TextScaled = true; emptyIcon.ZIndex = 5
emptyIcon.LayoutOrder = 1; emptyIcon.Parent = emptyState
local emptyTitle = Instance.new("TextLabel")
emptyTitle.Size = UDim2.new(1, -24, 0, 26); emptyTitle.BackgroundTransparency = 1
emptyTitle.Font = UITheme.Font.Heavy; emptyTitle.TextSize = 18; emptyTitle.ZIndex = 5
emptyTitle.TextColor3 = UITheme.Color.TextPrimary; emptyTitle.Text = "Your room's empty"
emptyTitle.LayoutOrder = 2; emptyTitle.Parent = emptyState
local emptyHint = Instance.new("TextLabel")
emptyHint.Size = UDim2.new(1, -36, 0, 40); emptyHint.BackgroundTransparency = 1
emptyHint.Font = UITheme.Font.Body; emptyHint.TextSize = 13; emptyHint.ZIndex = 5
emptyHint.TextColor3 = UITheme.Color.TextSecondary; emptyHint.TextWrapped = true
emptyHint.TextXAlignment = Enum.TextXAlignment.Center
emptyHint.Text = "Buy furniture from the boutique to start decorating!"
emptyHint.LayoutOrder = 3; emptyHint.Parent = emptyState

local function humanizeItemName(itemId: string): string
	local pretty = itemId:gsub("(%l)(%u)", "%1 %2"); pretty = pretty:gsub("_", " "); return pretty
end
local function getItemInfo(itemId: string)
	local data = ItemDatabaseMod.Get and ItemDatabaseMod.Get(itemId) or ItemDatabaseMod[itemId]
	local displayName = data and data.Name or humanizeItemName(itemId)
	local category = data and data.Category or "Decor"
	return data, displayName, category
end
local function findPlacedItemModel(itemName: string): Model?
	local placed = findPlacedFolder()
	local item = placed and placed:FindFirstChild(itemName)
	if item and item:IsA("Model") then return item end; return nil
end
local function resolvePlacedItemInfo(itemName: string)
	local itemModel = findPlacedItemModel(itemName)
	local itemId = itemModel and itemModel:GetAttribute("ItemId") or itemName:match("^(.-)_placed_") or itemName
	local _, displayName, category = getItemInfo(itemId)
	return itemModel, itemId, displayName, category
end
local function getViewportSize(): Vector2
	return workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
end
local function clampCardPosition(screenPos: Vector2, cardSize: Vector2): UDim2
	local viewport = getViewportSize(); local margin = 16
	-- The popup gui is UIScale'd, so its Position offsets are in UNSCALED coords while the card
	-- RENDERS at cardSize * scale. Convert the screen point + viewport bounds into that unscaled
	-- space (divide by scale) so the scaled-up popup never clips off the edge on mobile.
	local scale = styleScale.Scale > 0 and styleScale.Scale or 1
	local maxX = math.max(margin, viewport.X / scale - cardSize.X - margin)
	local maxY = math.max(margin, viewport.Y / scale - cardSize.Y - margin)
	local x = math.clamp(screenPos.X / scale + 18, margin, maxX)
	local y = math.clamp(screenPos.Y / scale - (cardSize.Y * 0.35), margin, maxY)
	return UDim2.fromOffset(math.floor(x), math.floor(y))
end
local function syncStyleScale()
	-- Shared touch-aware scaler (scales UP on phones for readability, per UITheme).
	styleScale.Scale = UITheme.GetUIScale()
end
local PANEL_W = 340          -- design width; styleScale (UIScale) is the single responsive factor
local PANEL_H = 520          -- design height (capped per-device below)
local PANEL_COMPACT_H = 250  -- empty Furniture tab = compact card (header + tabs + empty state)
local function updatePanelLayout()
	local cam = workspace.CurrentCamera
	local viewport = cam and cam.ViewportSize or Vector2.new(1280, 720)
	local scale = styleScale.Scale > 0 and styleScale.Scale or 1
	-- Width: cap the RENDERED width to ~42% of the screen so the rail never dominates a phone,
	-- then divide the scale back out (avoids the old viewport*0.30 × UIScale double-scale).
	local w = math.clamp(math.floor(math.min(PANEL_W, (viewport.X * 0.42) / scale)), 240, PANEL_W)
	local h = PANEL_H
	if activeTab == "Items" and #cartItems == 0 then h = math.min(h, PANEL_COMPACT_H) end
	if UITheme.IsTouch() then
		local insets = UITheme.GetContentInsets()
		-- Use the FULL right column (top safe area → just above the bottom-right jump button) so
		-- the content shows without scrolling. ~96 clears the jump button height.
		local vReserve = 96
		local availH = viewport.Y - insets.top - vReserve
		h = math.clamp(math.floor(availH / scale), 200, 600)
		panel.Size = UDim2.fromOffset(w, h)
		panel.AnchorPoint = Vector2.new(1, 0)
		panel.Position = UDim2.new(1, -insets.right, 0, insets.top)
	else
		panel.Size = UDim2.fromOffset(w, h)
		panel.AnchorPoint = Vector2.new(1, 0.5)
		panel.Position = UDim2.new(1, -16, 0.5, 0)
	end
end
local function countPlacedItems(): number
	local total = 0; for _ in pairs(placedMap) do total += 1 end; return total
end
local function showPickupFeedback(text: string, color: Color3?)
	feedbackToast.Visible = true; feedbackToast.Text = text
	feedbackToast.BackgroundColor3 = color or UITheme.Color.CoolSecondary
	feedbackToast.BackgroundTransparency = 0.1; feedbackToast.TextTransparency = 0
	feedbackToast.Position = UDim2.new(0.5, 0, 0, -10)
	TweenService:Create(feedbackToast, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0, -18)}):Play()
	task.delay(0.55, function()
		if not feedbackToast.Parent then return end
		local fade = TweenService:Create(feedbackToast, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			BackgroundTransparency=1, TextTransparency=1, Position=UDim2.new(0.5, 0, 0, -24)})
		fade:Play(); fade.Completed:Connect(function() if feedbackToast.Parent then feedbackToast.Visible = false end end)
	end)
end

local function refreshItemTab()
	for _, child in ipairs(itemPage:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end
	-- Cell size is Scale-based on itemGrid (set at creation), so no AbsoluteSize math here.
	-- Card internals key off the FIXED cell height (132), so they're width-agnostic.
	local placedCount = countPlacedItems()
	itemStatusLabel.Text = string.format("Ready %d  |  Room %d", math.max(#cartItems - placedCount, 0), placedCount)
	if emptyState then emptyState.Visible = (activeTab == "Items") and (#cartItems == 0) end
	for i, item in ipairs(cartItems) do
		local data, displayName = getItemInfo(item.itemId)
		local rarityColor = (data and RARITY_COLORS[data.Rarity]) or RARITY_COLORS.Common
		local capturedId = item.itemId
		local isPlaced = placedMap[capturedId] ~= nil; local isMoving = currentlyPlacingId == capturedId
		local btn = Instance.new("TextButton")
		btn.LayoutOrder = i  -- UIGridLayout sets Size from CellSize
		btn.BackgroundColor3 = isPlaced and UITheme.Color.SageDim or UITheme.Color.Surface
		btn.BackgroundTransparency = isPlaced and 0.14 or 0.24
		btn.BorderSizePixel = 0; btn.Text = ""; btn.Parent = itemPage
		makeCorner(btn, 14); UITheme.AddStroke(btn, rarityColor, 1.5, 0.4)
		local vpHolder = Instance.new("Frame")
		vpHolder.Size = UDim2.fromOffset(60, 60); vpHolder.AnchorPoint = Vector2.new(0.5, 0); vpHolder.Position = UDim2.new(0.5, 0, 0, 8)
		vpHolder.BackgroundColor3 = UITheme.Color.Surface; vpHolder.BackgroundTransparency = 0.18
		vpHolder.BorderSizePixel = 0; vpHolder.Parent = btn; makeCorner(vpHolder, 12)
		ViewportIcon.Fill(vpHolder, item.itemId)
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1, -10, 0, 30); lbl.Position = UDim2.new(0, 5, 0, 72); lbl.BackgroundTransparency = 1
		lbl.TextColor3 = UITheme.Color.TextPrimary; lbl.TextWrapped = true; lbl.TextSize = 13
		lbl.Font = UITheme.Font.Bold; lbl.TextXAlignment = Enum.TextXAlignment.Center
		lbl.TextYAlignment = Enum.TextYAlignment.Top; lbl.TextTruncate = Enum.TextTruncate.AtEnd
		lbl.Text = displayName; lbl.Parent = btn
		local status = Instance.new("TextLabel")
		status.Size = UDim2.new(1, -14, 0, 22); status.AnchorPoint = Vector2.new(0.5, 1); status.Position = UDim2.new(0.5, 0, 1, -6)
		status.BorderSizePixel = 0; status.Font = UITheme.Font.Bold; status.TextSize = 12
		status.TextColor3 = UITheme.Color.TextOnDark; status.Parent = btn; makeCorner(status, 999)
		if isMoving then status.BackgroundColor3 = UITheme.Color.WarmPrimary; status.Text = "🔄 Moving"
		elseif isPlaced then status.BackgroundColor3 = UITheme.Color.Sage; status.Text = "✓ Room"
		else status.BackgroundColor3 = UITheme.Color.CoolSecondary; status.Text = "📦 Place" end
		btn.MouseButton1Click:Connect(function()
			if placedMap[capturedId] then PickupPlacedItem:FireServer(placedMap[capturedId])
			else currentlyPlacingId = capturedId; PlacementBridge.SetItem:Fire(capturedId)
				PlacementBridge.Toggle:Fire("enter"); task.defer(refreshItemTab) end
		end)
	end
	updatePanelLayout()  -- refit panel height (compact when empty); itemPage AutomaticCanvasSize=Y drives the canvas
end

-- Phase-aware Furniture source: a Style round shows your CART; the hub house shows your
-- OWNED collection. Both normalize to the same {itemId,itemName} list + placement path.
local function loadFurnitureForPhase()
	if isStylePhase then
		local ok, result = pcall(function() return GetCartContents:InvokeServer() end)
		cartItems = (ok and type(result) == "table") and result or {}
	elseif isHousingPhase then
		local ok, snap = pcall(function() return GetProgressionSnapshot:InvokeServer() end)
		local entries = (ok and type(snap) == "table" and snap.collectionEntries) or {}
		cartItems = {}
		if type(entries) == "table" then
			for _, e in ipairs(entries) do
				if type(e) == "table" and type(e.itemId) == "string" then
					table.insert(cartItems, { itemId = e.itemId, itemName = e.name or e.itemId })
				end
			end
		end
		-- Reflect items already placed in the house so cards read "✓ Room".
		placedMap = {}
		local placed = findPlacedFolder()
		if placed then
			for _, child in ipairs(placed:GetChildren()) do
				local id = child:GetAttribute("ItemId")
				if type(id) == "string" then placedMap[id] = child.Name end
			end
		end
	else
		cartItems = {}
	end
	refreshItemTab()
end

syncStyleScale(); updatePanelLayout()
local currentCamera = workspace.CurrentCamera
if currentCamera then
	currentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		syncStyleScale(); updatePanelLayout(); if styleGui.Enabled then refreshItemTab() end
	end)
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function() syncStyleScale(); updatePanelLayout() end)
-- (removed) content AbsoluteSize -> refreshItemTab: the Furniture grid is now Scale-based,
-- so it no longer needs to rebuild on panel resize (that listener could also feedback-loop).
-- On tab switch into/out of Items, toggle the empty state + refit the panel height.
itemPage:GetPropertyChangedSignal("Visible"):Connect(function()
	emptyState.Visible = (activeTab == "Items") and (#cartItems == 0)
	updatePanelLayout()
end)

ItemPlaced.OnClientEvent:Connect(function(itemId: string, placedName: string)
	placedMap[itemId] = placedName; currentlyPlacingId = nil
	showPickupFeedback("Placed " .. humanizeItemName(itemId), UITheme.Color.Sage); refreshItemTab()
end)
PickupPlacedItem.OnClientEvent:Connect(function(itemId: string)
	placedMap[itemId] = nil; currentlyPlacingId = itemId
	showPickupFeedback("Moving " .. humanizeItemName(itemId), UITheme.Color.WarmPrimary); refreshItemTab()
	if isActivePhase() then task.defer(function()
		if not isActivePhase() then return end
		PlacementBridge.SetItem:Fire(itemId); PlacementBridge.Toggle:Fire("enter"); task.defer(refreshItemTab)
	end) end
end)

local function buildSwatchGrid(page, colors, onPick)
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0, 44, 0, 44); grid.CellPadding = UDim2.new(0, 8, 0, 8)
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Left
	grid.SortOrder = Enum.SortOrder.LayoutOrder; grid.Parent = page
	for index, color in ipairs(colors) do
		local btn = Instance.new("TextButton")
		btn.LayoutOrder = index; btn.Size = UDim2.new(0,44,0,44); btn.BackgroundColor3 = color
		btn.BorderSizePixel = 0; btn.Text = ""; btn.Parent = page; makeCorner(btn, 10)
		UITheme.AddStroke(btn, UITheme.Color.TextPrimary, 1, 0.28)
		local c = color; btn.MouseButton1Click:Connect(function() onPick(c) end)
	end
end
local function makeSectionLabel(parent: Instance, text: string, y: number)
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1,0,0,22); lbl.Position = UDim2.new(0,0,0,y); lbl.BackgroundTransparency = 1
	lbl.Text = text; lbl.TextColor3 = UITheme.Color.TextSecondary; lbl.Font = UITheme.Font.Bold
	lbl.TextSize = 13; lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.Parent = parent
	return lbl
end
local function buildLockedSwatchGrid(page: Instance, colors, y: number)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1,0,0,96); frame.Position = UDim2.new(0,0,0,y); frame.BackgroundTransparency = 1; frame.Parent = page
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0,40,0,40); grid.CellPadding = UDim2.new(0,8,0,8)
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Left
	grid.SortOrder = Enum.SortOrder.LayoutOrder; grid.Parent = frame
	for index, color in ipairs(colors) do
		local swatch = Instance.new("Frame")
		swatch.LayoutOrder = index; swatch.Size = UDim2.new(0,40,0,40); swatch.BackgroundColor3 = color
		swatch.BackgroundTransparency = 0.2; swatch.BorderSizePixel = 0; swatch.Parent = frame
		makeCorner(swatch, 10); UITheme.AddStroke(swatch, UITheme.Color.Stroke, 1, 0.82)
		local veil = Instance.new("Frame")
		veil.Size = UDim2.fromScale(1,1); veil.BackgroundColor3 = UITheme.Color.Base
		veil.BackgroundTransparency = 0.45; veil.BorderSizePixel = 0; veil.Parent = swatch; makeCorner(veil, 10)
		local lock = Instance.new("TextLabel")
		lock.Size = UDim2.fromScale(1,1); lock.BackgroundTransparency = 1; lock.Text = "🔒"
		lock.TextColor3 = UITheme.Color.TextMuted; lock.Font = UITheme.Font.Bold; lock.TextSize = 14; lock.Parent = swatch
	end
end
local function buildMaterialRow(page: Instance, entries, y: number, onPick, isLocked: boolean?)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1,0,0,40); row.Position = UDim2.new(0,0,0,y); row.BackgroundTransparency = 1; row.Parent = page
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal; layout.Padding = UDim.new(0,6); layout.Parent = row
	for _, entry in ipairs(entries) do
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0,74,1,0); btn.BackgroundColor3 = UITheme.Color.SurfaceRaised
		btn.BackgroundTransparency = isLocked and 0.3 or 0.08; btn.BorderSizePixel = 0
		btn.TextColor3 = UITheme.Color.TextPrimary; btn.Font = UITheme.Font.Bold; btn.TextSize = 13
		btn.Text = isLocked and (entry.name .. " 🔒") or entry.name; btn.Parent = row
		btn.AutoButtonColor = not isLocked; btn.Active = not isLocked; makeCorner(btn, 10)
		UITheme.AddStroke(btn, UITheme.Color.Stroke, 1, isLocked and 0.88 or 0.68)
		if not isLocked and onPick then
			local captured = entry.mat; btn.MouseButton1Click:Connect(function() onPick(captured) end)
		end
	end
	return row
end

local wallPage = addTab("Walls")
local selectedWall = "all"
local wallBtns = {}
makeSectionLabel(wallPage, "Wall zone", 0)
local wallSelectRow = Instance.new("Frame")
wallSelectRow.Size = UDim2.new(1,0,0,34); wallSelectRow.Position = UDim2.new(0,0,0,24)
wallSelectRow.BackgroundTransparency = 1; wallSelectRow.Parent = wallPage
local wsLayout = Instance.new("UIListLayout")
wsLayout.FillDirection = Enum.FillDirection.Horizontal; wsLayout.Padding = UDim.new(0,5); wsLayout.Parent = wallSelectRow
for _, w in ipairs({"All", "Back", "Left", "Right"}) do
	local wb = Instance.new("TextButton")
	wb.Size = UDim2.new(0,74,1,0)
	wb.BackgroundColor3 = w == "All" and UITheme.Color.CoolSecondary or UITheme.Color.SurfaceRaised
	wb.BackgroundTransparency = 0.14; wb.BorderSizePixel = 0; wb.TextColor3 = UITheme.Color.TextPrimary
	wb.Font = UITheme.Font.Bold; wb.TextSize = 13; wb.Text = w; wb.Parent = wallSelectRow
	makeCorner(wb, 10); wallBtns[w] = wb
	local captured = w:lower()
	wb.MouseButton1Click:Connect(function()
		selectedWall = captured
		for name, b in pairs(wallBtns) do
			local active = name:lower() == captured
			b.BackgroundColor3 = active and UITheme.Color.CoolSecondary or UITheme.Color.SurfaceRaised
			b.BackgroundTransparency = active and 0.06 or 0.18; b.Text = active and ("\xe2\x97\x8f " .. name) or name
		end
	end)
end
makeSectionLabel(wallPage, "Colors", 66)
local wallSwatchFrame = Instance.new("Frame")
wallSwatchFrame.Size = UDim2.new(1,0,0,104); wallSwatchFrame.Position = UDim2.new(0,0,0,90)
wallSwatchFrame.BackgroundTransparency = 1; wallSwatchFrame.Parent = wallPage
buildSwatchGrid(wallSwatchFrame, WALL_COLORS, function(color)
	local surface = selectedWall == "all" and "wall" or ("wall_" .. selectedWall)
	SetRoomSurface:FireServer(surface, color, Enum.Material.SmoothPlastic)
end)
makeSectionLabel(wallPage, "More — coming soon", 202)
buildLockedSwatchGrid(wallPage, LOCKED_WALL_COLORS, 224)
wallPage.CanvasSize = UDim2.new(0, 0, 0, 330)

local floorPage = addTab("Floor")
makeSectionLabel(floorPage, "Colors", 0)
local floorSwatchFrame = Instance.new("Frame")
floorSwatchFrame.Size = UDim2.new(1,0,0,104); floorSwatchFrame.Position = UDim2.new(0,0,0,24)
floorSwatchFrame.BackgroundTransparency = 1; floorSwatchFrame.Parent = floorPage
buildSwatchGrid(floorSwatchFrame, FLOOR_COLORS, function(color)
	selectedFloorColor = color; SetRoomSurface:FireServer("floor", color, selectedFloorMat)
end)
makeSectionLabel(floorPage, "More — coming soon", 136)
buildLockedSwatchGrid(floorPage, LOCKED_FLOOR_COLORS, 158)
makeSectionLabel(floorPage, "Floor type", 266)
buildMaterialRow(floorPage, FLOOR_MATERIALS, 290, function(mat)
	selectedFloorMat = mat; SetRoomSurface:FireServer("floor", selectedFloorColor, mat)
end, false)
makeSectionLabel(floorPage, "More types — coming soon", 338)
buildMaterialRow(floorPage, LOCKED_FLOOR_MATERIALS, 362, nil, true)
floorPage.CanvasSize = UDim2.new(0, 0, 0, 410)

local lightsPage = addTab("Lights")
makeSectionLabel(lightsPage, "Mood presets", 0)
local moodGrid = Instance.new("Frame")
moodGrid.Size = UDim2.new(1,0,0,220); moodGrid.Position = UDim2.new(0,0,0,24)
moodGrid.BackgroundTransparency = 1; moodGrid.Parent = lightsPage
local moodLayout = Instance.new("UIGridLayout")
moodLayout.CellSize = UDim2.new(0.5,-4,0,64); moodLayout.CellPadding = UDim2.fromOffset(8,8)
moodLayout.SortOrder = Enum.SortOrder.LayoutOrder; moodLayout.Parent = moodGrid
for i, mood in ipairs(LIGHT_MOODS) do
	local btn = Instance.new("TextButton")
	btn.LayoutOrder = i; btn.Size = UDim2.new(0.5,-4,0,64)
	btn.BackgroundColor3 = mood.ambient; btn.BackgroundTransparency = 0.08
	btn.BorderSizePixel = 0; btn.Text = ""; btn.Parent = moodGrid; makeCorner(btn, 14)
	UITheme.AddStroke(btn, UITheme.Color.Stroke, 1, 0.72)
	local emojiLbl = Instance.new("TextLabel")
	emojiLbl.Size = UDim2.new(1,0,0,30); emojiLbl.Position = UDim2.new(0,0,0,6)
	emojiLbl.BackgroundTransparency = 1; emojiLbl.Text = mood.emoji
	emojiLbl.Font = UITheme.Font.Bold; emojiLbl.TextSize = 22; emojiLbl.Parent = btn
	local nameLbl = Instance.new("TextLabel")
	nameLbl.Size = UDim2.new(1,-8,0,20); nameLbl.Position = UDim2.new(0,4,1,-24)
	nameLbl.BackgroundTransparency = 1; nameLbl.Text = mood.label
	nameLbl.TextColor3 = UITheme.Color.TextPrimary; nameLbl.Font = UITheme.Font.Bold
	nameLbl.TextSize = 13; nameLbl.Parent = btn
	local captured = mood
	btn.MouseButton1Click:Connect(function()
		SetRoomLighting:FireServer(captured.ambient, captured.pointColor, captured.brightness)
		showPickupFeedback(captured.emoji .. " " .. captured.label, captured.ambient)
	end)
end
makeSectionLabel(lightsPage, "Ambient tones — coming soon", 252)
local ambientNote = Instance.new("TextLabel")
ambientNote.Size = UDim2.new(1,0,0,36); ambientNote.Position = UDim2.new(0,0,0,276)
ambientNote.BackgroundTransparency = 1; ambientNote.Text = "Full color wheel & intensity slider coming soon."
ambientNote.TextColor3 = UITheme.Color.TextMuted; ambientNote.Font = UITheme.Font.Body
ambientNote.TextSize = 12; ambientNote.TextWrapped = true; ambientNote.TextXAlignment = Enum.TextXAlignment.Left
ambientNote.Parent = lightsPage
lightsPage.CanvasSize = UDim2.new(0, 0, 0, 320)

local MATERIAL_LABELS = {
	Wood="🪵 Wood", Carpet="🧶 Fabric", Tile="✨ Plastic",
	Plastic="✨ Plastic", Fabric="🧶 Fabric", Metal="🔩 Metal",
}
-- Popups live in their OWN ScreenGui with a high DisplayOrder so they always render ABOVE
-- the panel (and the rest of the HUD), regardless of sibling ZIndex ordering.
local popupGui = Instance.new("ScreenGui")
popupGui.Name = "StylePopupGui"; popupGui.ResetOnSpawn = false
popupGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling; popupGui.DisplayOrder = 50
popupGui.Parent = playerGui
UITheme.ApplySafeArea(popupGui)  -- popup uses a fit-to-screen scale (positionPopup), NOT scale-up, so it never overflows short landscape screens

local popup = Instance.new("Frame")
popup.Name = "ItemPopup"; popup.Size = UDim2.fromOffset(360, 340)
popup.AnchorPoint = Vector2.new(0, 0); popup.Position = UDim2.fromOffset(0, 0)
popup.BackgroundColor3 = UITheme.Color.SurfaceRaised; popup.BackgroundTransparency = 0.10
popup.BorderSizePixel = 0; popup.Visible = false; popup.ZIndex = 20; popup.Parent = popupGui
makeCorner(popup, 20); UITheme.AddStroke(popup, UITheme.Color.Stroke, 1.5, 0.22)
local popupScale = Instance.new("UIScale"); popupScale.Parent = popup  -- fit-to-screen scale, set by positionPopup

local popupIconHolder = Instance.new("Frame")
popupIconHolder.Size = UDim2.fromOffset(52, 52); popupIconHolder.Position = UDim2.fromOffset(14, 14)
popupIconHolder.BackgroundColor3 = UITheme.Color.WarmSurface; popupIconHolder.BackgroundTransparency = 0.08
popupIconHolder.BorderSizePixel = 0; popupIconHolder.Parent = popup; makeCorner(popupIconHolder, 14)
local popupEmojiLabel = Instance.new("TextLabel")
popupEmojiLabel.Size = UDim2.fromScale(1, 1); popupEmojiLabel.BackgroundTransparency = 1
popupEmojiLabel.Text = "🎨"; popupEmojiLabel.TextColor3 = UITheme.Color.TextPrimary
popupEmojiLabel.Font = UITheme.Font.Bold; popupEmojiLabel.TextSize = 24; popupEmojiLabel.Parent = popupIconHolder
local popupTitle = Instance.new("TextLabel")
popupTitle.Size = UDim2.new(1,-122,0,28); popupTitle.Position = UDim2.fromOffset(74, 12)
popupTitle.BackgroundTransparency = 1; popupTitle.Text = "Customize"
popupTitle.TextColor3 = UITheme.Color.TextPrimary; popupTitle.TextXAlignment = Enum.TextXAlignment.Left
popupTitle.Font = UITheme.Font.Heavy; popupTitle.TextSize = 20; popupTitle.Parent = popup
local popupSubtitle = Instance.new("TextLabel")
popupSubtitle.Size = UDim2.new(1,-122,0,18); popupSubtitle.Position = UDim2.fromOffset(74, 40)
popupSubtitle.BackgroundTransparency = 1; popupSubtitle.Text = "Pick a color or finish."
popupSubtitle.TextColor3 = UITheme.Color.TextSecondary; popupSubtitle.TextXAlignment = Enum.TextXAlignment.Left
popupSubtitle.Font = UITheme.Font.Body; popupSubtitle.TextSize = 12; popupSubtitle.Parent = popup
local popupColorTitle = Instance.new("TextLabel")
popupColorTitle.Size = UDim2.new(1,-28,0,20); popupColorTitle.Position = UDim2.fromOffset(14, 76)
popupColorTitle.BackgroundTransparency = 1; popupColorTitle.Text = "🎨 Color"
popupColorTitle.TextColor3 = UITheme.Color.TextSecondary; popupColorTitle.TextXAlignment = Enum.TextXAlignment.Left
popupColorTitle.Font = UITheme.Font.Bold; popupColorTitle.TextSize = 13; popupColorTitle.Parent = popup
local popupColorGrid = Instance.new("Frame")
popupColorGrid.Size = UDim2.new(1,-28,0,100); popupColorGrid.Position = UDim2.fromOffset(14, 100)
popupColorGrid.BackgroundTransparency = 1; popupColorGrid.Parent = popup
local popupColorLayout = Instance.new("UIGridLayout")
popupColorLayout.CellSize = UDim2.fromOffset(40,40); popupColorLayout.CellPadding = UDim2.fromOffset(8,8)
popupColorLayout.SortOrder = Enum.SortOrder.LayoutOrder; popupColorLayout.Parent = popupColorGrid
local popupMaterialTitle = Instance.new("TextLabel")
popupMaterialTitle.Size = UDim2.new(1,-28,0,20); popupMaterialTitle.Position = UDim2.fromOffset(14, 208)
popupMaterialTitle.BackgroundTransparency = 1; popupMaterialTitle.Text = "🧱 Material"
popupMaterialTitle.TextColor3 = UITheme.Color.TextSecondary; popupMaterialTitle.TextXAlignment = Enum.TextXAlignment.Left
popupMaterialTitle.Font = UITheme.Font.Bold; popupMaterialTitle.TextSize = 13; popupMaterialTitle.Parent = popup
local popupMaterialGrid = Instance.new("Frame")
popupMaterialGrid.Size = UDim2.new(1,-28,0,80); popupMaterialGrid.Position = UDim2.fromOffset(14, 230)
popupMaterialGrid.BackgroundTransparency = 1; popupMaterialGrid.Parent = popup
local popupMaterialLayout = Instance.new("UIGridLayout")
popupMaterialLayout.CellSize = UDim2.fromOffset(148,38); popupMaterialLayout.CellPadding = UDim2.fromOffset(8,8)
popupMaterialLayout.SortOrder = Enum.SortOrder.LayoutOrder; popupMaterialLayout.Parent = popupMaterialGrid
local resetBtn = Instance.new("TextButton")
resetBtn.Size = UDim2.fromOffset(106,38); resetBtn.Position = UDim2.new(0,14,1,-52)
resetBtn.BackgroundColor3 = UITheme.Color.Surface; resetBtn.BackgroundTransparency = 0.04
resetBtn.BorderSizePixel = 0; resetBtn.TextColor3 = UITheme.Color.TextPrimary
resetBtn.Font = UITheme.Font.Bold; resetBtn.TextSize = 14; resetBtn.Text = "↺ Reset"
resetBtn.Parent = popup; makeCorner(resetBtn, 10)
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.fromOffset(106,38); closeBtn.Position = UDim2.new(1,-120,1,-52)
closeBtn.BackgroundColor3 = UITheme.Color.Blush; closeBtn.BorderSizePixel = 0
closeBtn.TextColor3 = UITheme.Color.TextOnDark; closeBtn.Font = UITheme.Font.Bold
closeBtn.TextSize = 14; closeBtn.Text = "✓ Done"; closeBtn.Parent = popup; makeCorner(closeBtn, 10)
local popupX = Instance.new("TextButton")
popupX.Name = "CloseX"; popupX.AnchorPoint = Vector2.new(1, 0)
popupX.Size = UDim2.fromOffset(34, 34); popupX.Position = UDim2.new(1, -12, 0, 12)
popupX.BackgroundColor3 = UITheme.Color.Surface; popupX.BackgroundTransparency = 0.1
popupX.Text = "✕"; popupX.TextColor3 = UITheme.Color.TextPrimary
popupX.Font = UITheme.Font.Heavy; popupX.TextSize = 18; popupX.BorderSizePixel = 0
popupX.ZIndex = 22; popupX.Parent = popup; makeCorner(popupX, 999)
UITheme.AddStroke(popupX, UITheme.Color.Stroke, 1, 0.4)

local currentPopupItem = ""; local currentPopupSurface = ""; local currentPopupMode = ""
local currentPopupColor = ITEM_COLORS[1]

local function syncWallSelectionButtons(surfaceType: string)
	selectedWall = surfaceType
	for name, b in pairs(wallBtns) do
		local active = name:lower() == surfaceType or (surfaceType == "all" and name == "All")
		b.BackgroundColor3 = active and UITheme.Color.CoolSecondary or UITheme.Color.SurfaceRaised
		b.BackgroundTransparency = active and 0.06 or 0.18
		b.Text = active and ("● " .. name) or name
	end
end
local function rememberPointerPosition(position: Vector2?)
	if position then lastPointerPosition = Vector2.new(position.X, position.Y); return end
	local mousePos = UserInputService:GetMouseLocation()
	lastPointerPosition = Vector2.new(mousePos.X, mousePos.Y)
end
local function clearPopupSection(container: Instance)
	for _, child in ipairs(container:GetChildren()) do
		if not child:IsA("UIGridLayout") and not child:IsA("UIListLayout") then child:Destroy() end
	end
end
local function getPopupSize(): Vector2
	return Vector2.new(popup.Size.X.Offset, popup.Size.Y.Offset)
end
local function positionPopup(screenPos: Vector2?)
	-- Center + scale DOWN to fit the viewport so the popup (and its close buttons) is
	-- always fully on-screen, even on short landscape phones. screenPos intentionally ignored.
	local cam = workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
	local w = math.max(popup.Size.X.Offset, 1)
	local h = math.max(popup.Size.Y.Offset, 1)
	popupScale.Scale = math.clamp(math.min(1.1, (vp.X * 0.94) / w, (vp.Y * 0.92) / h), 0.55, 1.1)
	popup.AnchorPoint = Vector2.new(0.5, 0.5)
	popup.Position = UDim2.fromScale(0.5, 0.5)
end
local function setPopupEmoji(emoji: string, accentColor: Color3)
	local ev = popupIconHolder:FindFirstChild("ItemViewport"); if ev then ev:Destroy() end
	popupIconHolder.BackgroundColor3 = accentColor; popupEmojiLabel.Text = emoji; popupEmojiLabel.Visible = true
end
local function setPopupItemIcon(itemId: string, category: string)
	popupIconHolder.BackgroundColor3 = UITheme.Color.WarmSurface
	popupEmojiLabel.Text = ViewportIcon.GetEmoji(category); popupEmojiLabel.Visible = false
	local viewport = ViewportIcon.Fill(popupIconHolder, itemId)
	if not viewport then popupEmojiLabel.Visible = true end
end
local function makePopupSwatch(container: Instance, color: Color3, onClick)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.fromOffset(36,36); btn.BackgroundColor3 = color
	btn.BorderSizePixel = 0; btn.Text = ""; btn.Parent = container; makeCorner(btn, 10)
	UITheme.AddStroke(btn, UITheme.Color.TextPrimary, 1.5, 0.28); btn.MouseButton1Click:Connect(onClick)
end
local function makePopupMaterialButton(container: Instance, text: string, onClick)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.fromOffset(136,36); btn.BackgroundColor3 = UITheme.Color.Surface
	btn.BackgroundTransparency = 0.06; btn.BorderSizePixel = 0; btn.Text = text
	btn.TextColor3 = UITheme.Color.TextPrimary; btn.Font = UITheme.Font.Bold; btn.TextSize = 13; btn.Parent = container
	makeCorner(btn, 10); UITheme.AddStroke(btn, UITheme.Color.Stroke, 1, 0.28); btn.MouseButton1Click:Connect(onClick)
end
local function hidePopup()
	popup.Visible = false; currentPopupItem = ""; currentPopupSurface = ""; currentPopupMode = ""
end
local function openItemPopup(itemName: string, screenPos: Vector2?)
	local _, itemId, displayName, category = resolvePlacedItemInfo(itemName)
	currentPopupItem = itemName; currentPopupSurface = ""; currentPopupMode = "item"
	currentPopupColor = ITEM_COLORS[1]
	popup.Size = UDim2.fromOffset(360, 340)
	resetBtn.Visible = true; popupMaterialTitle.Visible = true; popupMaterialGrid.Visible = true
	popupColorTitle.Text = "🎨 Color"; popupMaterialTitle.Text = "🧱 Material"
	popupTitle.Text = displayName; popupSubtitle.Text = "Tap a color, then a finish."
	setPopupItemIcon(itemId, category)
	clearPopupSection(popupColorGrid)
	for _, color in ipairs(ITEM_COLORS) do
		local chosenColor = color
		makePopupSwatch(popupColorGrid, chosenColor, function()
			currentPopupColor = chosenColor; SetItemAppearance:FireServer(itemName, chosenColor)
		end)
	end
	clearPopupSection(popupMaterialGrid)
	for _, materialEntry in ipairs(ITEM_MATERIALS) do
		local label = MATERIAL_LABELS[materialEntry.name] or ("✨ " .. materialEntry.name)
		local chosenMaterial = materialEntry.mat
		makePopupMaterialButton(popupMaterialGrid, label, function()
			SetItemAppearance:FireServer(itemName, currentPopupColor, chosenMaterial)
		end)
	end
	positionPopup(screenPos); popup.Visible = true
end
local function openSurfacePopup(surfaceType: string, screenPos: Vector2?)
	currentPopupItem = ""; currentPopupMode = "surface"; currentPopupSurface = surfaceType
	local isFloor = surfaceType == "floor"
	local wallLabel = surfaceType == "all" and "All walls"
		or ((surfaceType:sub(1,1):upper() .. surfaceType:sub(2)) .. " wall")
	popup.Size = UDim2.fromOffset(360, isFloor and 310 or 248)
	resetBtn.Visible = false; popupMaterialTitle.Visible = isFloor; popupMaterialGrid.Visible = isFloor
	popupColorTitle.Text = isFloor and "🎨 Color" or "🖌️ Color"
	popupMaterialTitle.Text = "🧱 Material"
	popupTitle.Text = isFloor and "Change Floor" or "Paint Wall"
	popupSubtitle.Text = isFloor and "Pick a tone and texture for the floor."
		or (wallLabel .. " • Tap a shade.")
	setPopupEmoji(isFloor and "🪵" or "🖌️", isFloor and UITheme.Color.WarmSurface or UITheme.Color.BlushDim)
	if not isFloor then syncWallSelectionButtons(surfaceType) end
	clearPopupSection(popupColorGrid)
	for _, color in ipairs(isFloor and FLOOR_COLORS or WALL_COLORS) do
		local chosenColor = color
		makePopupSwatch(popupColorGrid, chosenColor, function()
			if isFloor then
				selectedFloorColor = chosenColor; SetRoomSurface:FireServer("floor", chosenColor, selectedFloorMat)
			else
				local surfaceKey = surfaceType == "all" and "wall" or ("wall_" .. surfaceType)
				SetRoomSurface:FireServer(surfaceKey, chosenColor, Enum.Material.SmoothPlastic)
			end
		end)
	end
	clearPopupSection(popupMaterialGrid)
	if isFloor then
		for _, materialEntry in ipairs(FLOOR_MATERIALS) do
			local label = MATERIAL_LABELS[materialEntry.name] or ("✨ " .. materialEntry.name)
			local chosenMaterial = materialEntry.mat
			makePopupMaterialButton(popupMaterialGrid, label, function()
				selectedFloorMat = chosenMaterial; SetRoomSurface:FireServer("floor", selectedFloorColor, chosenMaterial)
			end)
		end
	end
	positionPopup(screenPos); popup.Visible = true
end
resetBtn.MouseButton1Click:Connect(function()
	if currentPopupItem ~= "" then ResetItemAppearance:FireServer(currentPopupItem) end
end)
closeBtn.MouseButton1Click:Connect(hidePopup)
popupX.MouseButton1Click:Connect(hidePopup)

local function clearSurfacePromptGuis()
	for _, gui in pairs(surfacePromptGuis) do if gui and gui.Parent then gui:Destroy() end end
	table.clear(surfacePromptGuis)
end
local function addSurfacePromptGui(part: BasePart, emoji: string, label: string)
	local gui = Instance.new("BillboardGui")
	gui.Name = "SurfacePromptGui"; gui.Size = UDim2.fromOffset(116, 46)
	gui.StudsOffsetWorldSpace = Vector3.new(0, math.max(3, (part.Size.Y*0.5)+1.2), 0)
	gui.AlwaysOnTop = true; gui.MaxDistance = 14; gui.LightInfluence = 0
	gui.Adornee = part; gui.Parent = part
	local bubble = Instance.new("Frame")
	bubble.Size = UDim2.fromOffset(38,38); bubble.Position = UDim2.fromOffset(38,0)
	bubble.BackgroundColor3 = UITheme.Color.SurfaceRaised; bubble.BackgroundTransparency = 0.06
	bubble.BorderSizePixel = 0; bubble.Parent = gui; makeCorner(bubble, 18)
	UITheme.AddStroke(bubble, UITheme.Color.WarmPrimary, 1.5, 0.18)
	local emojiLabel = Instance.new("TextLabel")
	emojiLabel.Size = UDim2.fromScale(1,1); emojiLabel.BackgroundTransparency = 1
	emojiLabel.Text = emoji; emojiLabel.TextColor3 = UITheme.Color.TextPrimary
	emojiLabel.Font = UITheme.Font.Bold; emojiLabel.TextSize = 20; emojiLabel.Parent = bubble
	local pill = Instance.new("TextLabel")
	pill.Size = UDim2.fromOffset(116,18); pill.Position = UDim2.fromOffset(0,28)
	pill.BackgroundColor3 = UITheme.Color.TextPrimary; pill.BackgroundTransparency = 0.14
	pill.BorderSizePixel = 0; pill.Text = label; pill.TextColor3 = UITheme.Color.TextOnDark
	pill.Font = UITheme.Font.Bold; pill.TextSize = 10; pill.Parent = gui; makeCorner(pill, 8)
	surfacePromptGuis[part] = gui
end
local function refreshSurfacePromptGuis()
	-- Persistent billboard labels removed: painting now uses native Default-style
	-- ProximityPrompts on the room surfaces (visible only when the player is near).
	clearSurfacePromptGuis()
end

local function getSurfaceKeyFromPart(part: BasePart): string?
	local surfAttr = part:GetAttribute("SurfaceType")
	if surfAttr == "Floor" then return "floor" end
	if surfAttr ~= "Wall" then return nil end
	local n = part.Name
	if n == "WallBack" then return "back"
	elseif n == "WallLeft" then return "left"
	elseif n == "WallRight" then return "right"
	end
	return "all"
end
local function checkSurfaceClick(screenPos: Vector2): boolean
	local camera = workspace.CurrentCamera; if not camera then return false end
	local ray = camera:ScreenPointToRay(screenPos.X, screenPos.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character }
	local result = workspace:Raycast(ray.Origin, ray.Direction * 120, params)
	if not result then return false end
	local room = findPlayerRoom()
	if not room or not result.Instance:IsDescendantOf(room) then return false end
	local surfKey = getSurfaceKeyFromPart(result.Instance)
	if not surfKey then return false end
	if surfKey == "floor" then setTab("Floor")
	else setTab("Walls"); syncWallSelectionButtons(surfKey) end
	panel.Visible = true; stylePanelVisible = true
	openSurfacePopup(surfKey, screenPos); return true
end
local function checkItemClick(screenPos: Vector2?)
	if not isActivePhase() then return end
	-- Don't treat a placement-confirm click as an item/surface click.
	-- PlacementController owns MouseButton1 while in build mode.
	if player:GetAttribute("IsBuildMode") then return end
	local placed = findPlacedFolder(); if not placed then return end
	rememberPointerPosition(screenPos)
	local camera = workspace.CurrentCamera; if not camera then return end
	local ray = camera:ScreenPointToRay(lastPointerPosition.X, lastPointerPosition.Y)
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { player.Character }
	params.FilterType = Enum.RaycastFilterType.Exclude
	local result = workspace:Raycast(ray.Origin, ray.Direction * 100, params)
	if not result then return end
	local hit = result.Instance
	local item = hit:FindFirstAncestorWhichIsA("Model")
	if item and item.Parent == placed then openItemPopup(item.Name, lastPointerPosition); return end
	-- Click-to-paint removed: surface painting is via the [E] Paint proximity prompts only.
end

UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch then
		rememberPointerPosition(Vector2.new(input.Position.X, input.Position.Y))
	end
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		rememberPointerPosition(Vector2.new(input.Position.X, input.Position.Y))
		task.delay(0.05, function() checkItemClick(lastPointerPosition) end)
	end
end)
customizeToggle.MouseButton1Click:Connect(function()
	stylePanelVisible = not stylePanelVisible; panel.Visible = stylePanelVisible
	customizeToggle.Visible = not stylePanelVisible  -- hide the Decorate button while the panel is open
	if stylePanelVisible then updatePanelLayout() end  -- re-fit/position for the current viewport on open
end)
closeX.MouseButton1Click:Connect(function()
	stylePanelVisible = false; panel.Visible = false
	customizeToggle.Visible = isActivePhase() and (isStylePhase or (player:GetAttribute("InOwnHouse") == true))
end)

OpenItemAppearance.OnClientEvent:Connect(function(itemName: string)
	if not isActivePhase() then return end; openItemPopup(itemName, lastPointerPosition)
end)
OpenSurfacePicker.OnClientEvent:Connect(function(surfaceType: string)
	if not isActivePhase() then return end
	-- The server sends long-form surface keys ("wall_back"), but openSurfacePopup
	-- expects the short form ("back") and re-adds the "wall_" prefix itself. Without
	-- this, "wall_back" became "wall_wall_back" and the server fell back to painting
	-- ALL walls. Normalize to the short form so only the chosen wall is painted.
	if type(surfaceType) == "string" then
		if surfaceType == "wall" or surfaceType == "wall_all" then
			surfaceType = "all"
		else
			surfaceType = (surfaceType:gsub("^wall_", ""))
		end
	end
	styleGui.Enabled = true; scrim.Visible = false; panel.Visible = stylePanelVisible
	openSurfacePopup(surfaceType, lastPointerPosition)
end)

local function onHousingPhaseStart()
	isHousingPhase = true; stylePanelVisible = false
	-- Unified panel: the Furniture tab is now active in the hub too (your owned collection).
	setItemsTabVisible(true); loadFurnitureForPhase(); setTab("Items"); customizeToggle.Text = "✏️ Decorate"
	styleGui.Enabled = true; scrim.Visible = false; panel.Visible = false
	customizeToggle.Visible = (player:GetAttribute("InOwnHouse") == true)
	task.delay(0.8, function() if isHousingPhase then refreshSurfacePromptGuis() end end)
end
local function onHousingPhaseEnd()
	isHousingPhase = false; styleGui.Enabled = false; hidePopup(); customizeToggle.Visible = false
	clearSurfacePromptGuis(); PlacementBridge.Toggle:Fire("cancel")
end
local function onStylePhaseStart()
	isStylePhase = true; placedMap = {}; currentlyPlacingId = nil; stylePanelVisible = true
	setItemsTabVisible(true); customizeToggle.Text = "🎨 Customize"
	loadFurnitureForPhase(); setTab("Items")
	styleGui.Enabled = true; scrim.Visible = false; panel.Visible = stylePanelVisible; customizeToggle.Visible = true
	refreshSurfacePromptGuis()
	task.delay(0.6, function() if isStylePhase then refreshSurfacePromptGuis() end end)
end
local function onStylePhaseEnd()
	isStylePhase = false; scrim.Visible = false; styleGui.Enabled = false
	hidePopup(); customizeToggle.Visible = false; clearSurfacePromptGuis()
	cartItems = {}; placedMap = {}; currentlyPlacingId = nil; PlacementBridge.Toggle:Fire("cancel")
end
game.Players.LocalPlayer:GetAttributeChangedSignal("RoundPhase"):Connect(function()
	local phase = game.Players.LocalPlayer:GetAttribute("RoundPhase") or "Lobby"
	if phase == "Style" then if isHousingPhase then onHousingPhaseEnd() end; onStylePhaseStart(); return end
	if phase == "Lobby" then if isStylePhase then onStylePhaseEnd() end; onHousingPhaseStart(); return end
	if isStylePhase then onStylePhaseEnd() end; if isHousingPhase then onHousingPhaseEnd() end
end)
if (game.Players.LocalPlayer:GetAttribute("RoundPhase") or "Lobby") == "Style" then onStylePhaseStart()
elseif (game.Players.LocalPlayer:GetAttribute("RoundPhase") or "Lobby") == "Lobby" then onHousingPhaseStart() end

-- In the hub, only show the Paint Room button when actually inside your own house
-- (HousingClient sets InOwnHouse). Avoids an orphan button out in the plaza.
player:GetAttributeChangedSignal("InOwnHouse"):Connect(function()
	if not isHousingPhase then return end
	local inHouse = player:GetAttribute("InOwnHouse") == true
	customizeToggle.Visible = inHouse and not stylePanelVisible
	if inHouse then loadFurnitureForPhase() else panel.Visible = false; stylePanelVisible = false end
end)

-- Build-mode handoff (Option A): while placing furniture, yield the screen — hide the panel
-- + Decorate button so the room view and the (left-side) Place/Rotate/Cancel controls are
-- clear; restore + refresh on exit. Paint swatches never enter build mode, so the panel
-- stays open for them. IsBuildMode is maintained by PlacementController.
player:GetAttributeChangedSignal("IsBuildMode"):Connect(function()
	if not isActivePhase() then return end
	if player:GetAttribute("IsBuildMode") == true then
		panel.Visible = false
		customizeToggle.Visible = false
	else
		panel.Visible = stylePanelVisible
		customizeToggle.Visible = (not stylePanelVisible) and (isStylePhase or (player:GetAttribute("InOwnHouse") == true))
		loadFurnitureForPhase()  -- refresh placed/▢ status after placing or moving
	end
end)

print("[StyleController] Loaded")
