-- StarterPlayerScripts > PickupEffect
-- When CartItemAdded fires, spawns a colored item box at the pickup world position
-- and tweens it into the player's cart basket.

local Players       = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService  = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")

local UITheme = require(ReplicatedStorage:WaitForChild("UITheme"))
local player    = Players.LocalPlayer
local Events    = ReplicatedStorage:WaitForChild("Events", 15)
local CartItemAdded = Events:WaitForChild("CartItemAdded", 15)
local CartCountChanged = Events:WaitForChild("CartCountChanged", 15)
local RequestDropCartItem = Events:WaitForChild("RequestDropCartItem", 15)
local GetCartContents = Events:WaitForChild("GetCartContents", 15)

-- Box colors by item keyword
local ITEM_COLORS = {
	Couch    = Color3.fromRGB(100, 149, 237),
	Loveseat = Color3.fromRGB(100, 149, 237),
	Chair    = Color3.fromRGB(100, 149, 237),
	Bed      = Color3.fromRGB(147, 112, 219),
	Dresser  = Color3.fromRGB(147, 112, 219),
	Night    = Color3.fromRGB(147, 112, 219),
	Table    = Color3.fromRGB(60,  179, 113),
	TV       = Color3.fromRGB(255, 165,   0),
	Console  = Color3.fromRGB(255, 165,   0),
	Cable    = Color3.fromRGB(255, 165,   0),
	Record   = Color3.fromRGB(255, 215,   0),
	Lamp     = Color3.fromRGB(255, 215,   0),
	Rug      = Color3.fromRGB(220,  80,  80),
	Credenza = Color3.fromRGB(205, 133,  63),
	Bathroom = Color3.fromRGB(100, 200, 200),
}
local DEFAULT_COLOR = Color3.fromRGB(180, 180, 180)

local function getBoxColor(itemId: string): Color3
	for keyword, color in pairs(ITEM_COLORS) do
		if itemId:find(keyword) then
			return color
		end
	end
	return DEFAULT_COLOR
end

local function findCartBasketPosition(): Vector3?
	for _, instance in ipairs(CollectionService:GetTagged("PlayerCart")) do
		if not instance:IsA("Model") then continue end
		if instance:GetAttribute("OwnerUserId") ~= player.UserId then continue end
		local body = instance:FindFirstChild("Body")
		if body and body:IsA("BasePart") then
			-- Basket is roughly above and in front of body
			return body.Position + Vector3.new(0, 2, 0)
		end
	end
	return nil
end

-- Creates a small labeled box part in the world
local function makePickupBox(itemId: string, worldPos: Vector3): Part
	local box = Instance.new("Part")
	box.Name       = "PickupBox_" .. itemId
	box.Size       = Vector3.new(1.4, 1.4, 1.4)
	box.CFrame     = CFrame.new(worldPos + Vector3.new(0, 1, 0))
	box.Anchored   = true
	box.CanCollide = false
	box.CastShadow = false
	box.Material   = Enum.Material.SmoothPlastic
	box.Color      = getBoxColor(itemId)
	box.TopSurface = Enum.SurfaceType.Smooth
	box.BottomSurface = Enum.SurfaceType.Smooth

	-- Label on front face
	local sg = Instance.new("SurfaceGui")
	sg.Face           = Enum.NormalId.Front
	sg.AlwaysOnTop    = true
	sg.SizingMode     = Enum.SurfaceGuiSizingMode.FixedSize
	sg.CanvasSize     = Vector2.new(140, 140)
	sg.Parent         = box

	local bg = Instance.new("Frame")
	bg.Size                  = UDim2.fromScale(1, 1)
	bg.BackgroundColor3      = Color3.new(1,1,1)
	bg.BackgroundTransparency = 0.15
	bg.BorderSizePixel       = 0
	bg.Parent                = sg
	Instance.new("UICorner", bg).CornerRadius = UDim.new(0.15, 0)

	local lbl = Instance.new("TextLabel")
	lbl.Size                 = UDim2.fromScale(1, 0.55)
	lbl.Position             = UDim2.fromScale(0, 0.45)
	lbl.BackgroundTransparency = 1
	lbl.TextColor3           = Color3.new(0, 0, 0)
	lbl.TextScaled           = true
	lbl.Font                 = Enum.Font.GothamBold
	lbl.Text                 = itemId:gsub("(%u)", " %1"):gsub("^ ", "")  -- CamelCase → spaces
	lbl.Parent               = bg

	-- Item icon emoji (simple colored square stands in as icon for now)
	local icon = Instance.new("Frame")
	icon.Size                = UDim2.new(0.5, 0, 0.4, 0)
	icon.Position            = UDim2.new(0.25, 0, 0.04, 0)
	icon.BackgroundColor3    = getBoxColor(itemId)
	icon.BorderSizePixel     = 0
	icon.Parent              = bg
	Instance.new("UICorner", icon).CornerRadius = UDim.new(0.2, 0)

	box.Parent = workspace
	return box
end

-- Boxes are anchored parts with fixed local offsets from cart body.
-- A single RunService connection updates all of them each frame — O(n) CFrame sets, no physics.
local RunService = game:GetService("RunService")

type CartBox = { part: Part, localCF: CFrame }
local cartBoxes: {CartBox} = {}
local cartBody: BasePart? = nil

-- Grid layout: 3 cols x N rows, stacked inside basket
-- Local offsets relative to cart Body part
local BOX_SIZE    = 0.68
local BOX_SPACING = 0.72
local BASKET_Y    = 2.2
-- Two stacks of 3x2 arranged front-to-back in the basket
-- Stack 1 (back, slots 1-6):  Z = -0.5
-- Stack 2 (front, slots 7-10): Z = +0.5
local STACK_BACK  = -0.5
local STACK_FRONT =  0.5

local function getLocalCFForSlot(slotIndex: number): CFrame
	local inStack  = (slotIndex - 1) % 6   -- position within a stack (0-5)
	local stackNum = math.floor((slotIndex - 1) / 6)  -- 0 = back, 1 = front
	local col = inStack % 3
	local row = math.floor(inStack / 3)    -- max 1 (2 rows)
	local x   = (col - 1) * BOX_SPACING
	local y   = BASKET_Y + row * BOX_SPACING
	local z   = stackNum == 0 and STACK_BACK or STACK_FRONT
	return CFrame.new(x, y, z)
end

local function findCartBody(): BasePart?
	for _, inst in ipairs(CollectionService:GetTagged("PlayerCart")) do
		if inst:IsA("Model") and inst:GetAttribute("OwnerUserId") == player.UserId then
			local b = inst:FindFirstChild("Body")
			if b and b:IsA("BasePart") then return b :: BasePart end
		end
	end
	return nil
end

-- Single heartbeat connection keeps all boxes glued to cart
RunService.Heartbeat:Connect(function()
	if #cartBoxes == 0 then return end
	local body = cartBody
	if not (body and body.Parent) then
		body = findCartBody()
		cartBody = body
	end
	if not body then return end
	for _, entry in ipairs(cartBoxes) do
		if entry.part and entry.part.Parent then
			entry.part.CFrame = body.CFrame * entry.localCF
		end
	end
end)

local MAX_ITEMS = 15

-- Inventory UI
local playerGui = player:WaitForChild("PlayerGui")
local invGui = Instance.new("ScreenGui")
invGui.Name = "InventoryGui"
invGui.ResetOnSpawn = false
invGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
invGui.Parent = playerGui

local trayScale = Instance.new("UIScale")
trayScale.Parent = invGui

local ViewportIcon = require(ReplicatedStorage:WaitForChild("ViewportIcon"))
local ItemDatabase = require(ReplicatedStorage:WaitForChild("ItemDatabase"))

-- Bottom bar inventory: horizontal slot tray anchored to bottom-center
local invFrame = Instance.new("Frame")
invFrame.Name = "InventoryBar"
invFrame.AnchorPoint = Vector2.new(0.5, 1)
invFrame.Size = UDim2.new(0, 1160, 0, 104)
invFrame.Position = UDim2.new(0.5, 0, 1, -20)
invFrame.BackgroundColor3 = UITheme.Color.SurfaceRaised
invFrame.BackgroundTransparency = 0.46
invFrame.BorderSizePixel = 0
invFrame.Visible = false
invFrame.Parent = invGui
UITheme.AddCorner(invFrame, UITheme.Radius.XLarge)
UITheme.AddStroke(invFrame, UITheme.Color.Stroke, 1, 0.62)

local slotGrid = Instance.new("Frame")
slotGrid.Name = "SlotGrid"
slotGrid.Size = UDim2.new(1, -24, 1, -14)
slotGrid.Position = UDim2.new(0, 12, 0, 7)
slotGrid.BackgroundTransparency = 1
slotGrid.Parent = invFrame

local SLOT_MAX   = 68
local SLOT_GAP   = 8
local TRAY_PAD   = 24
local MAX_ROWS   = 3
local MAX_H_FRAC = 0.34  -- tray never eats more than this share of viewport height

-- A grid rather than a horizontal list, because the tray has to wrap to two rows on a
-- phone. syncTrayLayout drives CellSize and FillDirectionMaxCells from the viewport.
local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.new(0, SLOT_MAX, 0, SLOT_MAX)
gridLayout.CellPadding = UDim2.new(0, SLOT_GAP, 0, SLOT_GAP)
gridLayout.FillDirectionMaxCells = MAX_ITEMS
gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
gridLayout.VerticalAlignment = Enum.VerticalAlignment.Center
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = slotGrid

local pickupToast = Instance.new("TextLabel")
pickupToast.Name = "PickupToast"
pickupToast.AnchorPoint = Vector2.new(0.5, 1)
pickupToast.Size = UDim2.new(0, 280, 0, 44)
pickupToast.Position = UDim2.new(0.5, 0, 1, -196)
pickupToast.BackgroundColor3 = UITheme.Color.SurfaceRaised
pickupToast.BackgroundTransparency = 0.08
pickupToast.BorderSizePixel = 0
pickupToast.Visible = false
pickupToast.TextColor3 = UITheme.Color.TextPrimary
pickupToast.Font = UITheme.Font.Heavy
pickupToast.TextSize = 18
pickupToast.Parent = invGui
UITheme.AddCorner(pickupToast, UITheme.Radius.Large)
UITheme.AddStroke(pickupToast, UITheme.Color.Sage, 1.5, 0.18)

local slots: {TextButton} = {}
local displayedItems: {[number]: {itemId: string, itemName: string}} = {}
for i = 1, MAX_ITEMS do
	local slot = Instance.new("TextButton")
	slot.Name = "Slot_" .. i
	slot.LayoutOrder = i
	slot.Size = UDim2.new(0, SLOT_MAX, 0, SLOT_MAX) -- UIGridLayout overrides this per frame
	slot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	slot.BackgroundTransparency = 0.9
	slot.BorderSizePixel = 0
	slot.AutoButtonColor = false
	slot.Text = ""
	slot.Parent = slotGrid
	UITheme.AddCorner(slot, UDim.new(0, 10))

	-- ViewportFrame placeholder (filled when item is added)
	local vpHolder = Instance.new("Frame")
	vpHolder.Name = "VPHolder"
	-- Relative height so the preview still clears the label when the slot shrinks to
	-- SLOT_MIN on a phone. A fixed 52px overlapped the label below ~64px slots.
	vpHolder.Size = UDim2.new(1, -10, 1, -24)
	vpHolder.Position = UDim2.new(0, 5, 0, 4)
	vpHolder.BackgroundTransparency = 1
	vpHolder.Parent = slot
	UITheme.AddCorner(vpHolder, UDim.new(0, 8))

	local lbl = Instance.new("TextLabel")
	lbl.Name = "Label"
	lbl.Size = UDim2.new(1, -8, 0, 16)
	lbl.Position = UDim2.new(0, 4, 1, -20)
	lbl.BackgroundTransparency = 1
	lbl.Text = ""
	lbl.TextColor3 = UITheme.Color.TextPrimary
	lbl.Font = UITheme.Font.Bold
	lbl.TextSize = 11
	lbl.TextScaled = false
	lbl.TextWrapped = false
	lbl.TextTruncate = Enum.TextTruncate.AtEnd
	lbl.TextXAlignment = Enum.TextXAlignment.Center
	lbl.Parent = slot

	slot.MouseButton1Click:Connect(function()
		if not displayedItems[i] or not invFrame.Visible then
			return
		end
		RequestDropCartItem:FireServer(i)
	end)

	slots[i] = slot
end

local itemCount = 0
local toastTicket = 0
local rebuildNonce = 0
local REBUILD_DEBOUNCE = 0.15

-- Forward declaration: rebuildInventoryFromServer is defined later but referenced
-- here by debouncedRebuild. Without this, the closure captures a nil global and
-- the debounced rebuild silently does nothing (slots never fill after pickup).
local rebuildInventoryFromServer

local function debouncedRebuild()
	rebuildNonce += 1
	local nonce = rebuildNonce
	task.delay(REBUILD_DEBOUNCE, function()
		if rebuildNonce == nonce and invFrame.Visible then
			rebuildInventoryFromServer()
		end
	end)
end

-- Largest square slot that fits MAX_ITEMS into a width x height box at `rows` rows.
local function slotFor(boxW: number, boxH: number, rows: number): (number, number)
	local perRow = math.ceil(MAX_ITEMS / rows)
	local byWidth  = math.floor((boxW - TRAY_PAD - (perRow - 1) * SLOT_GAP) / perRow)
	local byHeight = math.floor((boxH - 20 - (rows - 1) * SLOT_GAP) / rows)
	return math.min(byWidth, byHeight, SLOT_MAX), perRow
end

-- The tray was a fixed 1160px behind a 0.82 scale floor, so it demanded ~950px and
-- clipped slots off both edges of every phone. It is now solved against the viewport.
-- Two placements are tried and the one giving the largest slot wins: sitting on the
-- bottom edge between the on-screen control corners, or lifted clear above them using
-- the full content width. Phones land on lifted, tablets and desktop on bottom. The old
-- bespoke scaler shrank the tray on small screens while UITheme.GetUIScale grows every
-- other HUD element, so it is deleted rather than inverted.
local function syncTrayLayout()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	trayScale.Scale = 1
	local insets = UITheme.GetContentInsets()
	local corner = UITheme.ControlCornerInset()
	local fullW  = UITheme.ContentWidth()
	local maxH   = camera.ViewportSize.Y * MAX_H_FRAC
	if fullW <= 0 then
		return
	end

	-- Clearing the GRAB/BOOST band is a constraint on the search, not a check after it.
	-- Ranking purely by slot size picked a layout that sat under those buttons.
	local viewportX  = camera.ViewportSize.X
	local bandLeft   = UITheme.ActionBandLeft()
	local bandBottom = UITheme.ActionBandBottom()
	local bandTop    = UITheme.ActionBandTop()

	local best, fallback
	for _, placement in ipairs({
		{ width = fullW - corner * 2, lift = 0 },
		{ width = fullW,             lift = corner },
	}) do
		for rows = 1, MAX_ROWS do
			local slot, perRow = slotFor(placement.width, maxH, rows)
			if slot > 0 then
				local cand = { slot = slot, rows = rows, perRow = perRow, lift = placement.lift }
				cand.width  = perRow * slot + (perRow - 1) * SLOT_GAP + TRAY_PAD
				cand.height = rows * slot + (rows - 1) * SLOT_GAP + 20
				local bottom = insets.bottom + placement.lift
				local clears = (viewportX * 0.5 + cand.width * 0.5) <= bandLeft
					or (bottom + cand.height) <= bandBottom
					or bottom >= bandTop
				if clears and (not best or slot > best.slot) then
					best = cand
				end
				if not fallback or slot > fallback.slot then
					fallback = cand
				end
			end
		end
	end
	-- On the tightest viewports nothing clears the band. Prefer a slightly small slot to
	-- a tray sitting under the action buttons.
	best = best or fallback
	if not best then
		return
	end

	gridLayout.CellSize = UDim2.new(0, best.slot, 0, best.slot)
	gridLayout.FillDirectionMaxCells = best.perRow
	invFrame.Size = UDim2.new(0, best.width, 0, best.height)
	invFrame.Position = UDim2.new(0.5, 0, 1, -(insets.bottom + best.lift))
end

local function humanizeItem(itemId: string): string
	return itemId:gsub("(%u)", " %1"):gsub("^ ", "")
end

local function shortItemLabel(itemId: string): string
	local human = humanizeItem(itemId)
	if #human <= 12 then
		return human
	end
	return itemId:match("^%u?%l+") or human:sub(1, 12)
end

local function updateCountLabel()
	-- Count is now shown in CartController's cart pill; no separate label needed
end

local function fillSlot(slot: GuiObject, itemId: string)
	local vpHolder = slot:FindFirstChild("VPHolder")
	local lbl = slot:FindFirstChild("Label")

	-- Fill ViewportFrame with 3D model icon
	if vpHolder then
		ViewportIcon.Fill(vpHolder, itemId)
	end

	if lbl and lbl:IsA("TextLabel") then
		lbl.Text = shortItemLabel(itemId)
	end

	slot.BackgroundTransparency = 0.42
	if slot:IsA("TextButton") then
		slot.Active = true
		slot.AutoButtonColor = true
	end
end

local function pulseSlot(slot: GuiObject)
	-- Juicy scale bounce on slot
	local scale = slot:FindFirstChildOfClass("UIScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Parent = slot
	end
	scale.Scale = 1.25
	slot.BackgroundTransparency = 0.1
	slot.BackgroundColor3 = UITheme.Color.WarmSurface

	TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1,
	}):Play()
	TweenService:Create(slot, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0.42,
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
	}):Play()
end

local function clearInventoryUI()
	displayedItems = {}
	for _, slot in ipairs(slots) do
		local vpHolder = slot:FindFirstChild("VPHolder")
		if vpHolder then
			local vp = vpHolder:FindFirstChild("ItemViewport")
			if vp then vp:Destroy() end
		end
		local lbl = slot:FindFirstChild("Label")
		if lbl and lbl:IsA("TextLabel") then
			lbl.Text = ""
		end
		slot.Active = false
		slot.AutoButtonColor = false
		slot.BackgroundTransparency = 0.82
	end
	itemCount = 0
	updateCountLabel()
end

local function spawnCartBox(itemId: string, slotIndex: number)
	local body = findCartBody()
	if not body then return end
	cartBody = body

	local localCF = getLocalCFForSlot(slotIndex)

	local box = Instance.new("Part")
	box.Name          = "CartBox_" .. slotIndex
	box.Size          = Vector3.new(BOX_SIZE, BOX_SIZE, BOX_SIZE)
	box.CFrame        = body.CFrame * localCF
	box.Anchored      = true
	box.CanCollide    = false
	box.CastShadow    = false
	box.Material      = Enum.Material.SmoothPlastic
	box.Color         = getBoxColor(itemId)
	box.TopSurface    = Enum.SurfaceType.Smooth
	box.BottomSurface = Enum.SurfaceType.Smooth
	box.Parent        = workspace

	table.insert(cartBoxes, { part = box, localCF = localCF })
end

local function clearCartBoxes()
	for _, entry in ipairs(cartBoxes) do
		if entry.part and entry.part.Parent then entry.part:Destroy() end
	end
	cartBoxes = {}
	cartBody = nil
end

function rebuildInventoryFromServer()
	local ok, contents = pcall(function()
		return GetCartContents:InvokeServer()
	end)
	if not ok or type(contents) ~= "table" then
		return
	end

	clearInventoryUI()
	clearCartBoxes()
	itemCount = #contents
	updateCountLabel()

	for index, entry in ipairs(contents) do
		local itemId = typeof(entry) == "table" and entry.itemId or nil
		local itemName = typeof(entry) == "table" and entry.itemName or itemId
		if type(itemId) == "string" and slots[index] then
			displayedItems[index] = {
				itemId = itemId,
				itemName = type(itemName) == "string" and itemName or itemId,
			}
			fillSlot(slots[index], itemId)
			spawnCartBox(itemId, index)
		end
	end
end

local function showPickupToast(text: string)
	toastTicket += 1
	local ticket = toastTicket
	pickupToast.Text = text
	pickupToast.Visible = true
	pickupToast.TextTransparency = 0
	pickupToast.BackgroundTransparency = 0.25
	pickupToast.Position = UDim2.new(0.5, 0, 1, -162)

	-- Pop up with bounce
	local toastScale = pickupToast:FindFirstChildOfClass("UIScale")
	if not toastScale then
		toastScale = Instance.new("UIScale")
		toastScale.Parent = pickupToast
	end
	toastScale.Scale = 0.7

	TweenService:Create(toastScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1,
	}):Play()
	TweenService:Create(pickupToast, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 1, -178),
	}):Play()

	task.delay(1.2, function()
		if ticket ~= toastTicket or not pickupToast.Parent then
			return
		end
		TweenService:Create(pickupToast, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			TextTransparency = 1,
			BackgroundTransparency = 1,
			Position = UDim2.new(0.5, 0, 1, -158),
		}):Play()
		task.delay(0.22, function()
			if ticket == toastTicket and pickupToast.Parent then
				pickupToast.Visible = false
			end
		end)
	end)
end

local RoundPhaseChanged = Events:WaitForChild("RoundPhaseChanged", 15)
game.Players.LocalPlayer:GetAttributeChangedSignal("RoundPhase"):Connect(function()
	local phase = game.Players.LocalPlayer:GetAttribute("RoundPhase") or "Lobby"
	if phase == "Shop" then
		invFrame.Visible = true
		task.defer(rebuildInventoryFromServer)
	else
		invFrame.Visible = false
		pickupToast.Visible = false
		clearInventoryUI()
		clearCartBoxes()
	end
end)

CartCountChanged.OnClientEvent:Connect(function()
	if invFrame.Visible then
		debouncedRebuild()
	end
end)

syncTrayLayout()
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(syncTrayLayout)
task.defer(function()
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(syncTrayLayout)
	end
	if (game.Players.LocalPlayer:GetAttribute("RoundPhase") or "Lobby") == "Shop" then
		invFrame.Visible = true
		rebuildInventoryFromServer()
	end
end)

CartItemAdded.OnClientEvent:Connect(function(itemId: string, _itemName: string, total: number, worldPos: Vector3?)
	if not worldPos then return end
	itemCount = total
	updateCountLabel()

	local basketPos = findCartBasketPosition()
	if not basketPos then
		showPickupToast("+ " .. humanizeItem(itemId))
		debouncedRebuild()
		return
	end

	local flyBox = makePickupBox(itemId, worldPos)
	local popTween = TweenService:Create(flyBox,
		TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ CFrame = CFrame.new(worldPos + Vector3.new(0, 2.5, 0)), Size = Vector3.new(1.8, 1.8, 1.8) }
	)
	popTween:Play()
	popTween.Completed:Wait()

	local flyTween = TweenService:Create(flyBox,
		TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ CFrame = CFrame.new(basketPos), Size = Vector3.new(0.5, 0.5, 0.5), Transparency = 0.5 }
	)
	flyTween:Play()
	flyTween.Completed:Wait()
	flyBox:Destroy()

	showPickupToast("+ " .. humanizeItem(itemId))
	-- CartCountChanged also fires for this pickup, so use debounced rebuild
	-- to avoid double round-trips.
	debouncedRebuild()
end)
