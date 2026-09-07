-- StarterPlayerScripts -> PlacementController
-- =========================================================
--  Handles client-side item placement:
--    - Ghost model preview (green = valid, red = invalid)
--    - Grid snapping with configurable size
--    - Home plot boundary enforcement
--    - Overlap detection
--    - Rotation (R key / mobile button)
--    - Surface normal alignment (optional, off by default)
--    - Mobile touch support
--    - Proper cleanup on exit / character respawn
-- =========================================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")

local ItemDB        = require(ReplicatedStorage:WaitForChild("ItemDatabase"))
local UITheme       = require(ReplicatedStorage:WaitForChild("UITheme"))
local PlacementBridge = require(ReplicatedStorage:WaitForChild("PlacementBridge"))
local UIState        = require(ReplicatedStorage:WaitForChild("UIStateManager"))

-- =========================================================
--  CONFIG
-- =========================================================

local GRID_SIZE          = 1       -- studs; set 0 to disable snapping
local MAX_PLACE_DISTANCE = 25      -- studs from player; matches server check
local ALIGN_TO_SURFACE   = false   -- if true, ghost tilts to match surface normal
local WALL_NORMAL_MAX_Y  = 0.8     -- wall-mounted items allow slightly messy wall normals
local GHOST_VALID_COLOR  = UITheme.Color.TextPositive
local GHOST_INVALID_COLOR = UITheme.Color.Danger
local GHOST_TRANSPARENCY = 0.45
local CHAR_TRANSPARENCY  = 0.70    -- character alpha while in build mode

-- =========================================================
--  REFERENCES
-- =========================================================

local player    = Players.LocalPlayer
local camera    = workspace.CurrentCamera

-- Item assets live in ReplicatedStorage.ItemAssets and are the canonical placement source.
local ItemAssets = ReplicatedStorage:WaitForChild("ItemAssets", 10)
if not ItemAssets then
	warn("PlacementController: ReplicatedStorage.ItemAssets not found. Placement disabled.")
end

local Events         = ReplicatedStorage:WaitForChild("Events")
local PlaceItemEvent = Events:WaitForChild("PlaceItem", 10)
local RoundPhaseChanged = Events:WaitForChild("RoundPhaseChanged", 10)

local function GetOrCreateBindable(name)
	local existing = Events:FindFirstChild(name)
	if existing and existing:IsA("BindableEvent") then
		return existing
	end
	local bindable = Instance.new("BindableEvent")
	bindable.Name = name
	bindable.Parent = Events
	return bindable
end

local BuildModeClientEvent = GetOrCreateBindable("BuildModeClient")

-- =========================================================
--  STATE
-- =========================================================

local isBuildMode     = false
local isStylePhase    = (game.Players.LocalPlayer:GetAttribute("RoundPhase") or "Lobby") == "Style"
local isHousingPhase  = (game.Players.LocalPlayer:GetAttribute("RoundPhase") or "Lobby") == "Lobby"
local ghostModel      = nil
local currentRotation = 0   -- degrees, Y axis only
local heldItemId      = nil
local placementValid  = false
local renderConnection = nil  -- retained for readability; BindToRenderStep uses a named binding
local lastValidPlacementCF = nil
player:SetAttribute("IsBuildMode", false)

-- =========================================================
--  HELPERS
-- =========================================================

-- Set transparency on all visible character parts
local function SetCharTransparency(alpha)
	local char = player.Character
	if not char then return end
	for _, part in ipairs(char:GetDescendants()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			part.LocalTransparencyModifier = alpha
		end
	end
end

local function IsPlaceableItem(itemId)
	local data = itemId and ItemDB[itemId]
	return data ~= nil and data.Type == "Furniture"
end

-- Returns the item the player intends to place (set externally by CartController)
local heldItemIdOverride = nil

function PlacementController_SetItem(itemId)
	heldItemIdOverride = itemId
end

-- Wire PlacementBridge AFTER function is defined
PlacementBridge.SetItem.Event:Connect(function(itemId)
	print("[PlacementController] SetItem received:", itemId)
	PlacementController_SetItem(itemId)
end)

PlacementBridge.Toggle.Event:Connect(function(action)
	print("[PlacementController] Toggle received:", action)
	BuildModeClientEvent:Fire(action)
end)

local function GetHeldItemId()
	return heldItemIdOverride
end

-- Get the player's active plot boundary (style room OR house)
local function GetHomePlot()
	return workspace:FindFirstChild("StyleRoom_" .. player.UserId .. "_Plot")
		or workspace:FindFirstChild("HouseRoom_" .. player.UserId .. "_Plot")
		or workspace:FindFirstChild("HomePlotDefault")
end

-- Returns true if worldPos is inside the plot boundary
local function IsInsidePlot(worldPos)
	local plot = GetHomePlot()
	if not plot then return true end  -- no plot = no restriction

	local localPos = plot.CFrame:PointToObjectSpace(worldPos)
	local halfSize = plot.Size / 2
	return math.abs(localPos.X) <= halfSize.X
		and math.abs(localPos.Z) <= halfSize.Z
end

local function GetPlacementBounds(instance)
	if not instance then
		return nil, nil
	end
	if instance:IsA("BasePart") then
		return instance.CFrame, instance.Size
	end
	if instance:IsA("Model") then
		if instance.PrimaryPart then
			return instance.PrimaryPart.CFrame, instance:GetExtentsSize()
		end
		local boxCF, boxSize = instance:GetBoundingBox()
		return boxCF, boxSize
	end
	return nil, nil
end

-- Floor placement should stay forgiving. We only block obvious collisions with
-- other player-placed decor and ignore starter built-ins so the home loop stays usable.
local function HasBlockingOverlap(placementSurface)
	if not ghostModel then return false end

	local ghostCF = ghostModel:GetPivot()
	local ghostSize = ghostModel:GetExtentsSize()
	local room = workspace:FindFirstChild("StyleRoom_" .. player.UserId)
	local houseFolder = (room and room:FindFirstChild("PlacedItems"))
		or (function()
			local hr = workspace:FindFirstChild("HouseRoom_" .. player.UserId)
			return hr and hr:FindFirstChild("PlacedItems")
		end)()
	if not houseFolder then return false end

	for _, child in ipairs(houseFolder:GetChildren()) do
		if child:GetAttribute("PlacementBlocker") == false then
			continue
		end

		local childSurface = child:GetAttribute("PlacementSurface")
		if type(childSurface) ~= "string" or childSurface == "" then
			childSurface = child:GetAttribute("PlacementCategory") == "WallMounted" and "Wall" or "Floor"
		end
		if placementSurface ~= childSurface then
			continue
		end

		local otherCF, otherSize = GetPlacementBounds(child)
		if not (otherCF and otherSize) then
			continue
		end

		local delta = ghostCF.Position - otherCF.Position
		local combined = (ghostSize + otherSize) / 2
		local xOverlap = math.abs(delta.X) < math.max(0.1, combined.X - 0.35)
		local zOverlap = math.abs(delta.Z) < math.max(0.1, combined.Z - 0.35)
		local yOverlap

		if placementSurface == "Floor" then
			yOverlap = math.abs(delta.Y) < math.max(0.45, math.min(ghostSize.Y, otherSize.Y) * 0.6)
		else
			yOverlap = math.abs(delta.Y) < math.max(0.2, combined.Y - 0.2)
		end

		if xOverlap and yOverlap and zOverlap then
			return true
		end
	end

	return false
end

-- Snap a value to the nearest grid increment
local function Snap(v)
	if GRID_SIZE <= 0 then return v end
	return math.round(v / GRID_SIZE) * GRID_SIZE
end

local function GetPlacementSurfaceForItem(itemId)
	if ItemDB.GetPlacementSurface then
		return ItemDB.GetPlacementSurface(itemId)
	end
	return ItemDB.IsWallMounted(itemId) and "Wall" or "Floor"
end

-- Lowest world-space point of a model/part, robust to tilted child parts
-- (yaw-invariant, so it can be measured at any current rotation).
local function LowestWorldY(instance)
	local minY = math.huge
	local function consider(p)
		local cf, sz = p.CFrame, p.Size
		local hy = 0.5 * (math.abs(cf.RightVector.Y) * sz.X
			+ math.abs(cf.UpVector.Y) * sz.Y
			+ math.abs(cf.LookVector.Y) * sz.Z)
		minY = math.min(minY, cf.Position.Y - hy)
	end
	if instance:IsA("BasePart") then consider(instance) end
	for _, p in ipairs(instance:GetDescendants()) do
		if p:IsA("BasePart") then consider(p) end
	end
	return minY
end

local function GetFloorPlacementCFrame(worldPos)
	if not ghostModel then
		return CFrame.new(worldPos)
	end
	local snapped = Vector3.new(Snap(worldPos.X), worldPos.Y, Snap(worldPos.Z))
	local placeCF = CFrame.new(snapped) * CFrame.Angles(0, math.rad(currentRotation), 0)
	-- Ground by the model's true lowest point so items rest on the floor instead of
	-- floating or sinking. (A model's pivot is not always at its bounding-box centre,
	-- which made the old half-extents lift mis-place many assets.)
	local pivotY = ghostModel:GetPivot().Position.Y
	local pivotToBottom = pivotY - LowestWorldY(ghostModel)
	return placeCF + Vector3.new(0, pivotToBottom, 0)
end

local function GetFallbackFloorResult(params)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	local origin = root.Position + (root.CFrame.LookVector * 8) + Vector3.new(0, 8, 0)
	return workspace:Raycast(origin, Vector3.new(0, -30, 0), params)
end

local function EvaluateFloorPlacement(hitPosition)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	local placeCF = GetFloorPlacementCFrame(hitPosition)
	local validationPoint = Vector3.new(placeCF.Position.X, hitPosition.Y, placeCF.Position.Z)
	local distFromPlayer = (root.Position - validationPoint).Magnitude
	local inPlot = IsInsidePlot(validationPoint)
	local previousPivot = ghostModel and ghostModel:GetPivot()
	if ghostModel then
		ghostModel:PivotTo(placeCF)
	end
	local noOverlap = not HasBlockingOverlap("Floor")
	if ghostModel and previousPivot then
		ghostModel:PivotTo(previousPivot)
	end
	local inRange = distFromPlayer <= MAX_PLACE_DISTANCE
	return {
		placeCF = placeCF,
		validationPoint = validationPoint,
		valid = inPlot and noOverlap and inRange,
	}
end

local function GetSnappedSurfaceNormal(result)
	local hitInstance = result and result.Instance
	local normal = result and result.Normal
	if not (hitInstance and normal and hitInstance:IsA("BasePart")) then
		return normal
	end

	local localNormal = hitInstance.CFrame:VectorToObjectSpace(normal)
	local ax = math.abs(localNormal.X)
	local ay = math.abs(localNormal.Y)
	local az = math.abs(localNormal.Z)
	local snappedLocal

	if ax >= ay and ax >= az then
		snappedLocal = Vector3.new(localNormal.X >= 0 and 1 or -1, 0, 0)
	elseif ay >= az then
		snappedLocal = Vector3.new(0, localNormal.Y >= 0 and 1 or -1, 0)
	else
		snappedLocal = Vector3.new(0, 0, localNormal.Z >= 0 and 1 or -1)
	end

	return hitInstance.CFrame:VectorToWorldSpace(snappedLocal).Unit
end

local function SupportsWallPlacement(normal)
	return normal and math.abs(normal.Y) <= WALL_NORMAL_MAX_Y
end

local function SupportsCeilingPlacement(normal)
	return normal and normal.Y <= -0.82
end

local function IsInsidePlayerHome(instance)
	if not instance then return false end
	local styleRoom = workspace:FindFirstChild("StyleRoom_" .. player.UserId)
	local houseRoom = workspace:FindFirstChild("HouseRoom_"  .. player.UserId)
	return (styleRoom ~= nil and instance:IsDescendantOf(styleRoom))
		or (houseRoom  ~= nil and instance:IsDescendantOf(houseRoom))
end

local function IsLikelyWallSurface(hitInstance, normal)
	if SupportsWallPlacement(normal) then
		return true
	end
	if not (hitInstance and hitInstance:IsA("BasePart") and IsInsidePlayerHome(hitInstance)) then
		return false
	end
	if hitInstance:GetAttribute("SurfaceType") == "Wall" then
		return true
	end
	local thickness = math.min(hitInstance.Size.X, hitInstance.Size.Z)
	return hitInstance.Size.Y >= 2 and thickness <= 2.5
end

local function IsLikelyCeilingSurface(hitInstance, normal)
	if not (hitInstance and hitInstance:IsA("BasePart") and IsInsidePlayerHome(hitInstance)) then
		return false
	end
	if hitInstance:GetAttribute("SurfaceType") == "Ceiling" then
		return true
	end
	return SupportsCeilingPlacement(normal)
end

-- =========================================================
--  GHOST COLOR  (valid = green, invalid = red)
-- =========================================================

local function SetGhostColor(valid)
	if not ghostModel then return end
	local color = valid and GHOST_VALID_COLOR or GHOST_INVALID_COLOR
	for _, part in ipairs(ghostModel:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Color        = color
			part.Transparency = GHOST_TRANSPARENCY
		end
	end
end

-- =========================================================
--  GHOST UPDATE  (runs every RenderStep while in build mode)
-- =========================================================

local function UpdateGhost()
	if not ghostModel then return end

	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	-- On touch there's no cursor: aim from SCREEN-CENTER (player aims with the camera /
	-- movement) so the ghost no longer snaps to wherever the player last tapped (e.g. the
	-- Place button). Desktop keeps the mouse cursor.
	local screenPoint
	if UITheme.IsTouch() then
		local vp = camera.ViewportSize
		screenPoint = Vector2.new(vp.X * 0.5, vp.Y * 0.5)
	else
		screenPoint = UserInputService:GetMouseLocation()
	end
	local ray = camera:ScreenPointToRay(screenPoint.X, screenPoint.Y)

	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { player.Character, ghostModel }
	params.FilterType = Enum.RaycastFilterType.Exclude

	local result = workspace:Raycast(ray.Origin, ray.Direction * 150, params)
	local placementSurface = GetPlacementSurfaceForItem(heldItemId)

	if placementSurface == "Wall" then
		if not result then
			placementValid = false
			SetGhostColor(false)
			return
		end
		local hit = result.Position
		local normal = GetSnappedSurfaceNormal(result)
		local surfaceValid = IsLikelyWallSurface(result.Instance, normal)
		local depth = math.max(0.2, ghostModel:GetExtentsSize().Z)
		local outward = normal.Unit
		local wallUp = Vector3.yAxis
		local wallRight = wallUp:Cross(-outward)
		if wallRight.Magnitude < 0.05 then
			wallRight = Vector3.xAxis
		else
			wallRight = wallRight.Unit
		end
		wallUp = (-outward):Cross(wallRight).Unit
		local placeCF = CFrame.fromMatrix(hit + (outward * (depth * 0.5)), wallRight, wallUp, -outward) * CFrame.Angles(0, 0, math.rad(currentRotation))
		ghostModel:PivotTo(placeCF)
		local validationPoint = placeCF.Position
		local distFromPlayer = (root.Position - validationPoint).Magnitude
		local inPlot = IsInsidePlayerHome(result.Instance)
		local noOverlap = surfaceValid and not HasBlockingOverlap("Wall")
		local inRange = distFromPlayer <= MAX_PLACE_DISTANCE
		placementValid = surfaceValid and inPlot and noOverlap and inRange
		if placementValid then
			lastValidPlacementCF = placeCF
		end
		SetGhostColor(placementValid)
		return
	elseif placementSurface == "Ceiling" then
		if not result then
			placementValid = false
			SetGhostColor(false)
			return
		end
		local hit = result.Position
		local normal = GetSnappedSurfaceNormal(result)
		local surfaceValid = IsLikelyCeilingSurface(result.Instance, normal)
		local extents = ghostModel:GetExtentsSize()
		local placeCF = CFrame.new(hit + (normal.Unit * (extents.Y * 0.5))) * CFrame.Angles(0, math.rad(currentRotation), 0)
		ghostModel:PivotTo(placeCF)
		local validationPoint = placeCF.Position
		local distFromPlayer = (root.Position - validationPoint).Magnitude
		local inPlot = IsInsidePlayerHome(result.Instance)
		local noOverlap = surfaceValid and not HasBlockingOverlap("Ceiling")
		local inRange = distFromPlayer <= MAX_PLACE_DISTANCE
		placementValid = surfaceValid and inPlot and noOverlap and inRange
		if placementValid then
			lastValidPlacementCF = placeCF
		end
		SetGhostColor(placementValid)
		return
	end

	local chosen = nil
	if result then
		chosen = EvaluateFloorPlacement(result.Position)
	end
	if (not chosen) or (not chosen.valid) then
		local fallbackResult = GetFallbackFloorResult(params)
		if fallbackResult then
			local fallback = EvaluateFloorPlacement(fallbackResult.Position)
			if fallback and fallback.valid then
				chosen = fallback
			end
		end
	end
	if (not chosen) and lastValidPlacementCF then
		ghostModel:PivotTo(lastValidPlacementCF)
		placementValid = true
		SetGhostColor(true)
		return
	end
	if not chosen then
		placementValid = false
		SetGhostColor(false)
		return
	end

	ghostModel:PivotTo(chosen.placeCF)
	placementValid = chosen.valid
	if placementValid then
		lastValidPlacementCF = chosen.placeCF
	end
	SetGhostColor(placementValid)
end

-- =========================================================
--  ENTER BUILD MODE
-- =========================================================

local function EnterBuildMode(itemIdOverride: string?)
	if isBuildMode then return end
	-- Style phase always allows build; in the hub (Lobby) only inside your own house,
	-- so build mode never starts out in the plaza (Placement state == valid context).
	if not isStylePhase and not (isHousingPhase and player:GetAttribute("InOwnHouse") == true) then
		return
	end
	if not ItemAssets then
		warn("PlacementController: ItemAssets not available.")
		return
	end

	if itemIdOverride then
		PlacementController_SetItem(itemIdOverride)
	end
	local itemId = GetHeldItemId()
	if not itemId then
		-- Silently ignore  player pressed B with empty hands
		return
	end

	local source = ItemAssets:FindFirstChild(itemId)
	if not source then
		warn("PlacementController: '" .. itemId .. "' not found in ItemAssets.")
		return
	end

	heldItemId    = itemId
	currentRotation = 0

	-- Build ghost
	ghostModel = source:Clone()
	ghostModel.Name = "Ghost_" .. itemId

	for _, part in ipairs(ghostModel:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanCollide   = false
			part.Anchored     = true
			part.Transparency = GHOST_TRANSPARENCY
			part.Color        = GHOST_VALID_COLOR
		end
		-- Remove any scripts, prompts, sounds from ghost
		if part:IsA("Script") or part:IsA("LocalScript")
			or part:IsA("ProximityPrompt") or part:IsA("Sound") then
			part:Destroy()
		end
	end

	ghostModel.Parent = workspace
	isBuildMode       = true
	lastValidPlacementCF = nil
	player:SetAttribute("IsBuildMode", true)

	SetCharTransparency(CHAR_TRANSPARENCY)
	UpdateGhost()

	-- Start render loop only while in build mode
	RunService:BindToRenderStep(
		"PlacementGhost",
		Enum.RenderPriority.Last.Value,
		UpdateGhost
	)
	renderConnection = true
end

-- =========================================================
--  EXIT BUILD MODE
-- =========================================================

local function ExitBuildMode()
	if not isBuildMode then return end

	isBuildMode    = false
	placementValid = false

	if ghostModel then
		ghostModel:Destroy()
		ghostModel = nil
	end

	heldItemId = nil
	player:SetAttribute("IsBuildMode", false)

	SetCharTransparency(0)

	if renderConnection then
		RunService:UnbindFromRenderStep("PlacementGhost")
		renderConnection = nil
	end
	lastValidPlacementCF = nil
end

-- =========================================================
--  CONFIRM PLACEMENT
-- =========================================================

-- Housing placement fires HousePlaceSave instead of PlaceItemEvent
local function ConfirmPlacement()
	if not isBuildMode or not ghostModel then return end
	if not placementValid then
		SetGhostColor(false)
		task.delay(0.15, function()
			if ghostModel then SetGhostColor(false) end
		end)
		return
	end

	local placeCFrame = ghostModel:GetPivot()
	local Events2 = ReplicatedStorage:FindFirstChild("Events")

	if isHousingPhase then
		-- Housing: fire HousePlaceSave with a generated placement ID
		local HousePlaceSave = Events2 and Events2:FindFirstChild("HousePlaceSave")
		if HousePlaceSave then
			local placementId = tostring(os.clock()):gsub("%.", "") .. tostring(player.UserId)
			HousePlaceSave:FireServer(heldItemId, placeCFrame, placementId)
		end
	else
		if PlaceItemEvent then
			PlaceItemEvent:FireServer(heldItemId, placeCFrame)
		end
	end

	SetGhostColor(true)
	task.delay(0.1, function()
		ExitBuildMode()
	end)
end

-- =========================================================
--  ROTATION
-- =========================================================

local function Rotate(degrees)
	if not isBuildMode then return end
	currentRotation = (currentRotation + degrees) % 360
end

BuildModeClientEvent.Event:Connect(function(action)
	if action ~= "cancel" and not isStylePhase and not isHousingPhase then
		return
	end
	if action == "toggle" then
		if isBuildMode then
			ExitBuildMode()
		else
			EnterBuildMode()
		end
	elseif action == "enter" then
		if isBuildMode then
			ExitBuildMode()
		end
		EnterBuildMode()
	elseif action == "confirm" then
		ConfirmPlacement()
	elseif action == "cancel" then
		ExitBuildMode()
	elseif action == "rotate" then
		Rotate(90)
	end
end)

-- =========================================================
--  INPUT  KEYBOARD / GAMEPAD
-- =========================================================

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	-- Toggle build mode
	if input.KeyCode == Enum.KeyCode.B or input.KeyCode == Enum.KeyCode.ButtonX then
		if isBuildMode then
			ExitBuildMode()
		else
			EnterBuildMode()
		end
		return
	end

	if not isBuildMode then return end

	-- Rotate
	if input.KeyCode == Enum.KeyCode.R then
		Rotate(90)
	end

	-- Confirm placement
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		ConfirmPlacement()
	end

	-- Cancel
	if input.KeyCode == Enum.KeyCode.Escape
		or input.KeyCode == Enum.KeyCode.ButtonB then
		ExitBuildMode()
	end
end)

-- Gamepad right bumper to rotate
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if not isBuildMode then return end
	if input.KeyCode == Enum.KeyCode.ButtonR1 then
		Rotate(90)
	end
	if input.KeyCode == Enum.KeyCode.ButtonA then
		ConfirmPlacement()
	end
end)

-- =========================================================
--  MOBILE BUTTONS
-- =========================================================

local isTouchDevice = true  -- show on-screen Place/Rotate/Cancel on desktop too (verifiable everywhere; harmless alongside click/R/Esc)

if isTouchDevice then
	local mobileGui = Instance.new("ScreenGui")
	mobileGui.Name = "PlacementMobileGui"
	mobileGui.ResetOnSpawn = false
	mobileGui.IgnoreGuiInset = true
	mobileGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	mobileGui.Parent = player:WaitForChild("PlayerGui")
	UITheme.AttachScale(mobileGui)

	local CORNER = 150  -- thumbstick / jump corner reserve (px); buttons sit ABOVE it

	local function makeMobileButton(name: string, icon: string, caption: string, colorKey: string, size: number, anchor: Vector2, pos: UDim2, callback): TextButton
		local btn = Instance.new("TextButton")
		btn.Name = name
		btn.AnchorPoint = anchor
		btn.Position = pos
		btn.Size = UDim2.new(0, size, 0, size)
		btn.BackgroundColor3 = UITheme.Color[colorKey]
		btn.BackgroundTransparency = 0.06
		btn.Text = ""
		btn.AutoButtonColor = true
		btn.BorderSizePixel = 0
		btn.ZIndex = 12
		btn.Parent = mobileGui
		UITheme.AddCorner(btn, UITheme.Radius.Large)
		UITheme.AddStroke(btn, UITheme.Color.SurfaceRaised, 2, 0.35)

		local iconLabel = Instance.new("TextLabel")
		iconLabel.BackgroundTransparency = 1
		iconLabel.Size = UDim2.new(1, 0, 0.56, 0)
		iconLabel.Position = UDim2.new(0, 0, 0.07, 0)
		iconLabel.Font = Enum.Font.SourceSansSemibold
		iconLabel.Text = icon
		iconLabel.TextColor3 = UITheme.Color.TextOnDark
		iconLabel.TextScaled = true
		iconLabel.ZIndex = 13
		iconLabel.Parent = btn

		local capLabel = Instance.new("TextLabel")
		capLabel.BackgroundTransparency = 1
		capLabel.Size = UDim2.new(1, -8, 0.30, 0)
		capLabel.Position = UDim2.new(0, 4, 0.65, 0)
		capLabel.Font = UITheme.Font.Heavy
		capLabel.Text = caption
		capLabel.TextColor3 = UITheme.Color.TextOnDark
		capLabel.TextScaled = true
		capLabel.ZIndex = 13
		capLabel.Parent = btn

		btn.Activated:Connect(callback)
		return btn
	end

	-- Place: primary, bottom-RIGHT, raised above the jump button.
	makeMobileButton("PlaceBtn", "\u{2713}", "PLACE", "WarmPrimary", 108, Vector2.new(1, 1), UDim2.new(1, -24, 1, -(CORNER + 18)), function()
		ConfirmPlacement()
	end)
	-- Rotate: bottom-LEFT, raised above the thumbstick.
	makeMobileButton("RotateBtn", "\u{1F504}", "ROTATE", "Sage", 92, Vector2.new(0, 1), UDim2.new(0, 24, 1, -(CORNER + 18)), function()
		Rotate(90)
	end)
	-- Cancel: bottom-LEFT, beside Rotate.
	makeMobileButton("CancelBtn", "X", "CANCEL", "Danger", 92, Vector2.new(0, 1), UDim2.new(0, 128, 1, -(CORNER + 18)), function()
		ExitBuildMode()
	end)

	-- Visibility owned by the state manager: the HUD is enabled only in Placement.
	UIState.register({ name = "PlacementHUD", instance = mobileGui, visibleIn = { UIState.State.Placement } })
end

-- =========================================================
--  CLEANUP ON CHARACTER RESPAWN
--  If player dies mid-placement, exit cleanly
-- =========================================================

player.CharacterAdded:Connect(function()
	if isBuildMode then
		ExitBuildMode()
	end
	-- Ensure transparency is reset on new character
	SetCharTransparency(0)
end)

game.Players.LocalPlayer:GetAttributeChangedSignal("RoundPhase"):Connect(function()
	local phase = game.Players.LocalPlayer:GetAttribute("RoundPhase") or "Lobby"
	isStylePhase  = phase == "Style"
	isHousingPhase = phase == "Lobby"
	if not isStylePhase and not isHousingPhase and isBuildMode then
		ExitBuildMode()
	end
end)

print(" PlacementController loaded")
