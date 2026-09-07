--!strict
-- StarterPlayerScripts > CartController
-- Client-authoritative cart driving using network ownership and mover constraints.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")

local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
local mouse = player:GetMouse()

-- Lazily fetch the default ControlModule's controls object so we can read the live
-- move vector (on-screen thumbstick) while the rider is PlatformStand'd — under
-- PlatformStand the Humanoid.MoveDirection stays zero, so the cart can't read it.
local controlModule: any = nil
local function getControls()
	if controlModule then return controlModule end
	local ps = player:FindFirstChild("PlayerScripts")
	local pm = ps and ps:FindFirstChild("PlayerModule")
	if pm then
		local ok, mod = pcall(require, pm)
		if ok and mod then
			local ok2, ctrls = pcall(function() return mod:GetControls() end)
			if ok2 then controlModule = ctrls end
		end
	end
	return controlModule
end

local UITheme = require(ReplicatedStorage:WaitForChild("UITheme"))
local UIState = require(ReplicatedStorage:WaitForChild("UIStateManager"))
local ShopTargeting = require(ReplicatedStorage:WaitForChild("ShopTargeting"))
local Events = ReplicatedStorage:WaitForChild("Events", 15) :: Folder
local RequestGrabItem = Events:WaitForChild("RequestGrabItem", 15) :: RemoteEvent
local CartItemAdded = Events:WaitForChild("CartItemAdded", 15) :: RemoteEvent
local CartCountChanged = Events:WaitForChild("CartCountChanged", 15) :: RemoteEvent
local RoundPhaseChanged = Events:WaitForChild("RoundPhaseChanged", 15) :: RemoteEvent
local GetCartContents = Events:WaitForChild("GetCartContents", 15) :: RemoteFunction
local RequestCartDismount = Events:WaitForChild("RequestCartDismount", 15) :: RemoteEvent

local ACTION_FORWARD = "CartForward"
local ACTION_REVERSE = "CartReverse"
local ACTION_LEFT = "CartLeft"
local ACTION_RIGHT = "CartRight"
local ACTION_GRAB = "CartGrab"
local ACTION_HOP_DRIFT = "CartHopDrift"
local ACTION_BOOST = "CartBoost"
local ACTION_PRIORITY = Enum.ContextActionPriority.High.Value

local BOOST_DURATION = 0.4
local BOOST_COOLDOWN = 3.6
local BOOST_SPEED_MULTIPLIER = 1.7
local BOOST_ACCEL_MULTIPLIER = 4.0

local DEFAULT_TUNE = {
	MaxSpeed = 44,
	MaxReverseSpeed = 16,
	TurnRate = 2.9,
	Acceleration = 38,
	BrakeDeceleration = 100,
	CoastDeceleration = 22,
	SideDeceleration = 48,
	SteerSpeed = 9,
}
local MOVING_EPSILON = 0.1
local HIGHLIGHT_DISTANCE = 16
local CART_CAPACITY = 15

type InputState = {
	forward: boolean,
	reverse: boolean,
	left: boolean,
	right: boolean,
}

type CartPhysics = {
	cart: Model,
	body: BasePart,
	handle: BasePart,
	linearVelocity: LinearVelocity,
	angularVelocity: AngularVelocity,
}

-- Wheel sound IDs (from workspace assets)
local SOUND_ROLL_1  = "rbxassetid://9119092591"
local SOUND_ROLL_2  = "rbxassetid://9119092604"
local SOUND_DRIFT   = "rbxassetid://9119092591"  -- roll pitched up for screech

local wheelSounds: {roll1: Sound?, roll2: Sound?, drift: Sound?} = {roll1=nil, roll2=nil, drift=nil}
local rollIndex = 1  -- alternate between roll sounds

local function buildWheelSounds(cartPhysics: CartPhysics)
	for _, s in pairs(wheelSounds) do
		if s then s:Destroy() end
	end
	wheelSounds = {roll1=nil, roll2=nil, drift=nil}

	local function makeSound(name: string, id: string, looped: boolean): Sound
		local s = Instance.new("Sound")
		s.Name = name
		s.SoundId = id
		s.Volume = 0
		s.RollOffMaxDistance = 40
		s.RollOffMinDistance = 3
		s.Looped = looped
		s.Parent = cartPhysics.body
		if looped then
			s.Loaded:Once(function() s:Play() end)
		end
		return s
	end

	wheelSounds.roll1 = makeSound("CartRoll1", SOUND_ROLL_1, true)
	wheelSounds.roll2 = makeSound("CartRoll2", SOUND_ROLL_2, true)
	wheelSounds.drift = makeSound("CartDrift",  SOUND_DRIFT,  true)
end

local function updateWheelSounds(speed: number, drifting: boolean, grounded: boolean)
	local roll1 = wheelSounds.roll1
	local roll2 = wheelSounds.roll2
	local drift = wheelSounds.drift
	if not (roll1 and roll2 and drift) then return end

	-- Crossfade between roll1 (slow) and roll2 (fast) based on speed
	local rollTarget = if grounded then math.clamp(speed / 35, 0, 0.75) else 0
	local speedFrac = math.clamp(speed / 35, 0, 1)
	roll1.Volume = roll1.Volume + (rollTarget * (1 - speedFrac * 0.5) - roll1.Volume) * 0.12
	roll2.Volume = roll2.Volume + (rollTarget * speedFrac * 0.5 - roll2.Volume) * 0.12
	roll1.PlaybackSpeed = math.clamp(0.85 + speed / 100, 0.85, 1.3)
	roll2.PlaybackSpeed = math.clamp(0.9  + speed / 80,  0.9,  1.5)

	-- Drift: pitch roll sound up for screech effect
	local driftTarget = if (drifting and grounded) then math.clamp(speed / 25, 0, 0.9) else 0
	drift.Volume = drift.Volume + (driftTarget - drift.Volume) * 0.18
	drift.PlaybackSpeed = 1.8  -- pitched up = screech
end

local isShopPhase = (game.Players.LocalPlayer:GetAttribute("RoundPhase") or "Lobby") == "Shop"
local cartCount = 0
local highlighted: Instance? = nil
local inCart = false
local actionsBound = false
local inputState: InputState = {
	forward = false,
	reverse = false,
	left = false,
	right = false,
}
local hopHeld = false
local hopQueued = false
local lastJumpTime = -math.huge
local driftWindowEnd = -math.huge
local boostActive = false
local boostEnd = -math.huge
local lastBoostTime = -math.huge
local currentCartPhysics: CartPhysics? = nil
local pushAnimationTrack: AnimationTrack? = nil
local pushAnimationObject: Animation? = nil
local animationCharacter: Model? = nil
local suppressedAnimate: LocalScript? = nil
local suppressedAnimateWasDisabled = false

local hudGui = Instance.new("ScreenGui")
hudGui.Name = "CartHUD"
hudGui.ResetOnSpawn = false
hudGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
hudGui.Parent = playerGui

-- Visibility is owned by the centralized UI state manager: the cart HUD shows in
-- the Shop state and hides everywhere else (incl. Placement). Replaces the old
-- manual `cartBadge.Visible = isShopPhase` phase-gating.
UIState.register({ name = "CartHUD", instance = hudGui, visibleIn = { UIState.State.Shop } })

local hudScale = Instance.new("UIScale")
hudScale.Parent = hudGui

-- Compact cart pill: top-left, just icon + count
local cartBadge = Instance.new("Frame")
cartBadge.Name = "CartPill"
cartBadge.Size = UDim2.new(0, 148, 0, 52)
cartBadge.Position = UDim2.new(0, 14, 0, 56)
cartBadge.BackgroundColor3 = UITheme.Color.Overlay
cartBadge.BackgroundTransparency = 0.35
cartBadge.BorderSizePixel = 0
cartBadge.Visible = true  -- HUD-level (ScreenGui) visibility is owned by UIStateManager
cartBadge.Parent = hudGui
UITheme.AddCorner(cartBadge, UITheme.Radius.Pill)

local cartEmoji = Instance.new("TextLabel")
cartEmoji.Name = "CartEmoji"
cartEmoji.Size = UDim2.new(0, 30, 0, 30)
cartEmoji.Position = UDim2.new(0, 10, 0.5, -15)
cartEmoji.BackgroundTransparency = 1
cartEmoji.Text = "\u{1F6D2}" -- shopping cart emoji
cartEmoji.TextSize = 22
cartEmoji.Font = Enum.Font.SourceSans
cartEmoji.Parent = cartBadge

local cartLabel = Instance.new("TextLabel")
cartLabel.Name = "CountLabel"
cartLabel.Size = UDim2.new(0, 76, 0, 28)
cartLabel.Position = UDim2.new(0, 42, 0, 3)
cartLabel.BackgroundTransparency = 1
cartLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
cartLabel.Font = UITheme.Font.Heavy
cartLabel.TextSize = 22
cartLabel.TextXAlignment = Enum.TextXAlignment.Left
cartLabel.Text = "0/15"
cartLabel.Parent = cartBadge

local cartMetaLabel = Instance.new("TextLabel")
cartMetaLabel.Name = "MetaLabel"
cartMetaLabel.Size = UDim2.new(0, 90, 0, 14)
cartMetaLabel.Position = UDim2.new(0, 42, 0, 30)
cartMetaLabel.BackgroundTransparency = 1
cartMetaLabel.TextColor3 = UITheme.Color.TextSecondary
cartMetaLabel.Font = UITheme.Font.Medium
cartMetaLabel.TextSize = 10
cartMetaLabel.TextXAlignment = Enum.TextXAlignment.Left
cartMetaLabel.Text = "15 slots left"
cartMetaLabel.Parent = cartBadge

local cartBarTrack = Instance.new("Frame")
cartBarTrack.Name = "CapacityTrack"
cartBarTrack.Size = UDim2.new(1, -14, 0, 4)
cartBarTrack.Position = UDim2.new(0, 7, 1, -7)
cartBarTrack.BackgroundColor3 = UITheme.Color.Disabled
cartBarTrack.BackgroundTransparency = 0.7
cartBarTrack.BorderSizePixel = 0
cartBarTrack.Parent = cartBadge
UITheme.AddCorner(cartBarTrack, UITheme.Radius.Pill)

local cartBarFill = Instance.new("Frame")
cartBarFill.Name = "CapacityFill"
cartBarFill.Size = UDim2.new(0, 0, 1, 0)
cartBarFill.BackgroundColor3 = UITheme.Color.Sage
cartBarFill.BorderSizePixel = 0
cartBarFill.Parent = cartBarTrack
UITheme.AddCorner(cartBarFill, UITheme.Radius.Pill)

-- Legacy references kept for updateCartHUD compatibility
local cartSubLabel = {Text = ""}
local cartProgressFill = Instance.new("Frame")
cartProgressFill.Parent = nil -- hidden, kept for code compatibility
local shopTipLabel = {Text = ""}

local boostFrame = Instance.new("Frame")
boostFrame.Name = "BoostFrame"
boostFrame.AnchorPoint = Vector2.new(0.5, 1)
boostFrame.Size = UDim2.new(0, 200, 0, 42)
boostFrame.Position = UDim2.new(0.5, 0, 1, -150)
boostFrame.BackgroundColor3 = UITheme.Color.Overlay
boostFrame.BackgroundTransparency = 0.3
boostFrame.BorderSizePixel = 0
boostFrame.Visible = false
boostFrame.Parent = hudGui
UITheme.AddCorner(boostFrame, UITheme.Radius.Pill)

local boostLabel = Instance.new("TextLabel")
boostLabel.Size = UDim2.new(1, -20, 0, 20)
boostLabel.Position = UDim2.new(0, 10, 0, 6)
boostLabel.BackgroundTransparency = 1
boostLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
boostLabel.Font = UITheme.Font.Heavy
boostLabel.TextSize = 15
boostLabel.TextXAlignment = Enum.TextXAlignment.Center
boostLabel.Text = "⚡ BOOST READY"
boostLabel.Parent = boostFrame

local boostSubLabel = Instance.new("TextLabel")
boostSubLabel.Size = UDim2.new(1, -20, 0, 14)
boostSubLabel.Position = UDim2.new(0, 10, 0, 22)
boostSubLabel.BackgroundTransparency = 1
boostSubLabel.TextColor3 = UITheme.Color.TextSecondary
boostSubLabel.Font = UITheme.Font.Medium
boostSubLabel.TextSize = 10
boostSubLabel.TextXAlignment = Enum.TextXAlignment.Center
boostSubLabel.Text = "Shift / Tap"
boostSubLabel.Parent = boostFrame

local boostBarTrack = Instance.new("Frame")
boostBarTrack.Size = UDim2.new(1, -20, 0, 4)
boostBarTrack.Position = UDim2.new(0, 10, 1, -8)
boostBarTrack.BackgroundColor3 = UITheme.Color.Disabled
boostBarTrack.BackgroundTransparency = 0.84
boostBarTrack.BorderSizePixel = 0
boostBarTrack.Parent = boostFrame
UITheme.AddCorner(boostBarTrack, UITheme.Radius.Pill)

local boostBarFill = Instance.new("Frame")
boostBarFill.Size = UDim2.new(1, 0, 1, 0)
boostBarFill.BackgroundColor3 = UITheme.Color.WarmPrimary
boostBarFill.BorderSizePixel = 0
boostBarFill.Parent = boostBarTrack
UITheme.AddCorner(boostBarFill, UITheme.Radius.Pill)

-- Legacy grab hint removed: shop grab state is shown via StoreItemPrompt BillboardGui

-- Assigned further down, once the touch buttons exist. Their position depends on
-- hudScale, so it has to be recomputed every time the scale changes.
local syncTouchButtonPositions: (() -> ())? = nil

local function syncHudScale()
	-- Centralized responsive scale: gentle shrink on small desktop windows,
	-- scale UP on touch for readable, thumb-sized controls (UITheme).
	hudScale.Scale = UITheme.GetUIScale()
	if syncTouchButtonPositions then syncTouchButtonPositions() end
end

local lastCartCount = 0

local function bounceCartPill()
	-- Juicy scale bounce on the cart pill
	local scale = cartBadge:FindFirstChildOfClass("UIScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Parent = cartBadge
	end
	scale.Scale = 1.15
	TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1,
	}):Play()
end

local function updateCartHUD()
	local isFull = cartCount >= CART_CAPACITY
	local nearlyFull = cartCount >= (CART_CAPACITY - 2) and not isFull
	local remaining = math.max(CART_CAPACITY - cartCount, 0)
	local fillFrac = math.clamp(cartCount / CART_CAPACITY, 0, 1)

	cartLabel.Text = string.format("%d/%d", cartCount, CART_CAPACITY)
	cartMetaLabel.Text = isFull and "\u{2728} Cart full!" or string.format("%d slots left", remaining)

	-- Color states
	local bgColor = isFull and UITheme.Color.BlushDim or (nearlyFull and UITheme.Color.WarmSurface or UITheme.Color.Overlay)
	local bgTrans = isFull and 0.15 or (nearlyFull and 0.25 or 0.35)
	local textColor = isFull and UITheme.Color.Blush or (nearlyFull and UITheme.Color.WarmPrimary or Color3.fromRGB(255, 255, 255))

	TweenService:Create(cartBadge, TweenInfo.new(0.25), {
		BackgroundColor3 = bgColor,
		BackgroundTransparency = bgTrans,
	}):Play()
	cartLabel.TextColor3 = textColor
	cartMetaLabel.TextColor3 = isFull and UITheme.Color.Blush or (nearlyFull and UITheme.Color.WarmPrimary or UITheme.Color.TextSecondary)
	cartEmoji.TextColor3 = textColor

	TweenService:Create(cartBarFill, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.new(fillFrac, 0, 1, 0),
		BackgroundColor3 = isFull and UITheme.Color.Blush or (nearlyFull and UITheme.Color.WarmPrimary or UITheme.Color.Sage),
	}):Play()

	-- Bounce when count actually increases
	if cartCount > lastCartCount and cartCount > 0 then
		bounceCartPill()
	end
	lastCartCount = cartCount
end

syncHudScale()
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(syncHudScale)
task.defer(function()
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(syncHudScale)
	end
end)

local function horizontal(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

local function flatUnit(vector: Vector3): Vector3
	local flat = horizontal(vector)
	if flat.Magnitude < 0.001 then
		return Vector3.zAxis
	end
	return flat.Unit
end

local function moveTowards(current: number, target: number, maxDelta: number): number
	if current < target then
		return math.min(current + maxDelta, target)
	end
	if current > target then
		return math.max(current - maxDelta, target)
	end
	return target
end

local function isCartGrounded(cartPhysics: CartPhysics, groundProbeDistance: number): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { cartPhysics.cart, player.Character }

	local origin = cartPhysics.body.Position
	local result = workspace:Raycast(origin, Vector3.new(0, -groundProbeDistance, 0), params)
	return result ~= nil
end

local function getCharacter(): Model?
	return player.Character
end

local function getHumanoid(character: Model?): Humanoid?
	if not character then
		return nil
	end
	return character:FindFirstChildOfClass("Humanoid")
end

local function stopOtherMovementTracks(character: Model)
	local humanoid = getHumanoid(character)
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return
	end

	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		if track ~= pushAnimationTrack and track.Priority.Value <= Enum.AnimationPriority.Movement.Value then
			track:Stop(0.1)
		end
	end
end

local function setDefaultAnimateSuppressed(shouldSuppress: boolean)
	if shouldSuppress then
		local character = getCharacter()
		if not character then
			return
		end

		local animate = character:FindFirstChild("Animate")
		if not (animate and animate:IsA("LocalScript")) then
			return
		end

		if suppressedAnimate ~= animate then
			suppressedAnimate = animate
			suppressedAnimateWasDisabled = animate.Disabled
		end
		animate.Disabled = true
		stopOtherMovementTracks(character)
		return
	end

	if suppressedAnimate and suppressedAnimate.Parent then
		suppressedAnimate.Disabled = suppressedAnimateWasDisabled
	end
	suppressedAnimate = nil
	suppressedAnimateWasDisabled = false
end

local function enforceCartAnimationSuppression()
	if not inCart then
		return
	end
	setDefaultAnimateSuppressed(true)
	local character = getCharacter()
	if character then
		stopOtherMovementTracks(character)
	end
end

-- Effects: sparks (drift) and dust (driving) parented to cart body
local sparkEmitters: {ParticleEmitter} = {}
local dustEmitters: {ParticleEmitter} = {}
local effectsBuilt = false

local function buildEffects(cartPhysics: CartPhysics)
	-- Clear old emitters
	for _, e in ipairs(sparkEmitters) do e:Destroy() end
	for _, e in ipairs(dustEmitters) do e:Destroy() end
	table.clear(sparkEmitters)
	table.clear(dustEmitters)

	local body = cartPhysics.body
	local cart = cartPhysics.cart

	-- Tire positions measured live from body-local space. Y=0.15 puts emission above floor.
	local wheelOffsets = {
		Vector3.new( 0.96, 0.15,  1.51),
		Vector3.new(-0.96, 0.15,  1.51),
		Vector3.new(-1.33, 0.15, -1.49),
		Vector3.new( 1.32, 0.15, -1.49),
	}

	for _, offset in ipairs(wheelOffsets) do
		local att = Instance.new("Attachment")
		att.Position = offset
		att.Parent = body

		-- Spark emitter (drift)
		local spark = Instance.new("ParticleEmitter")
		spark.Texture = "" -- default Roblox sparkle texture, always works
		spark.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 220, 80)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 120, 20)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 180, 180)),
		})
		spark.LightEmission = 1
		spark.LightInfluence = 0
		spark.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.4),
			NumberSequenceKeypoint.new(1, 0),
		})
		spark.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(1, 1),
		})
		spark.Speed = NumberRange.new(8, 18)
		spark.SpreadAngle = Vector2.new(70, 20)
		spark.Lifetime = NumberRange.new(0.15, 0.35)
		spark.Rate = 0
		spark.RotSpeed = NumberRange.new(-180, 180)
		spark.Rotation = NumberRange.new(0, 360)
		spark.Enabled = true
		spark.Parent = att
		table.insert(sparkEmitters, spark)

		-- Dust emitter (driving)
		local dust = Instance.new("ParticleEmitter")
		dust.Texture = "rbxassetid://3845808160" -- official Roblox smoke texture from creator docs
		dust.Color = ColorSequence.new(Color3.fromRGB(200, 190, 175))
		dust.LightEmission = 0
		dust.LightInfluence = 0.5
		dust.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(0.5, 0.45),
			NumberSequenceKeypoint.new(1, 0),
		})
		dust.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(0.7, 0.6),
			NumberSequenceKeypoint.new(1, 1),
		})
		dust.Speed = NumberRange.new(3, 7)
		dust.SpreadAngle = Vector2.new(40, 15)
		dust.Lifetime = NumberRange.new(0.5, 1.2)
		dust.Rate = 0
		dust.Enabled = true
		dust.Parent = att
		table.insert(dustEmitters, dust)
	end
end

local function setSparkEmitters(on: boolean)
	for _, e in ipairs(sparkEmitters) do
		e.Rate = if on then 80 else 0
	end
end

local function setDustRate(rate: number)
	for _, e in ipairs(dustEmitters) do
		e.Rate = rate
	end
end

local function resetInputState()
	inputState.forward = false
	inputState.reverse = false
	inputState.left = false
	inputState.right = false
	hopHeld = false
	hopQueued = false
end

local function hasForwardDriveIntent(): boolean
	local keyboardIntent = UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up)
	local gamepadIntent = UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonR2)
	return (inputState.forward or keyboardIntent or gamepadIntent) and not inputState.reverse
end

local function clearHighlight()
	if highlighted then
		local existingSelection = highlighted:FindFirstChild("CartFocusSelection")
		if existingSelection then
			existingSelection:Destroy()
		end
		local existingHighlight = highlighted:FindFirstChild("CartFocusHighlight")
		if existingHighlight then
			existingHighlight:Destroy()
		end
		highlighted = nil
	end
end

local function setHighlight(item: Instance?, isOn: boolean)
	if not item then
		return
	end

	local existingSelection = item:FindFirstChild("CartFocusSelection")
	local existingHighlight = item:FindFirstChild("CartFocusHighlight")
	if isOn and not existingSelection then
		local selectionBox = Instance.new("SelectionBox")
		selectionBox.Name = "CartFocusSelection"
		if item:IsA("Model") or item:IsA("BasePart") then
			selectionBox.Adornee = item
		end
		selectionBox.Color3 = UITheme.Color.Sage
		selectionBox.SurfaceColor3 = UITheme.Color.Sage
		selectionBox.SurfaceTransparency = 0.9
		selectionBox.LineThickness = 0.08
		selectionBox.Parent = item

		local highlight = Instance.new("Highlight")
		highlight.Name = "CartFocusHighlight"
		highlight.Adornee = item
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		highlight.FillColor = UITheme.Color.Sage
		highlight.FillTransparency = 0.82
		highlight.OutlineColor = UITheme.Color.WarmPrimary
		highlight.OutlineTransparency = 0.18
		highlight.Parent = item
	elseif not isOn then
		if existingSelection then
			existingSelection:Destroy()
		end
		if existingHighlight then
			existingHighlight:Destroy()
		end
	end
end

local function getFocusedStoreItem(): (Instance?, boolean)
	local allowNearestFallback = true
	return ShopTargeting.GetShopFocusTarget(player, mouse.Target, HIGHLIGHT_DISTANCE, allowNearestFallback)
end

local function resolvePushAnimationId(character: Model): string?
	local configured = script:GetAttribute("PushAnimationId")
	if typeof(configured) == "string" and configured ~= "" then
		return configured
	end

	local shared = ReplicatedStorage:GetAttribute("CartPushAnimationId")
	if typeof(shared) == "string" and shared ~= "" then
		return shared
	end

	local animate = character:FindFirstChild("Animate")
	if animate then
		local walkFolder = animate:FindFirstChild("walk")
		local walkAnimation = walkFolder and walkFolder:FindFirstChild("WalkAnim")
		if walkAnimation and walkAnimation:IsA("Animation") and walkAnimation.AnimationId ~= "" then
			return walkAnimation.AnimationId
		end
	end

	return nil
end

local function resetPushAnimation()
	if pushAnimationTrack then
		pushAnimationTrack:Stop(0.12)
		pushAnimationTrack:Destroy()
		pushAnimationTrack = nil
	end
	if pushAnimationObject then
		pushAnimationObject:Destroy()
		pushAnimationObject = nil
	end
	animationCharacter = nil
end

local function ensurePushAnimation(): AnimationTrack?
	local character = getCharacter()
	if not character then
		resetPushAnimation()
		return nil
	end

	if pushAnimationTrack and animationCharacter == character then
		return pushAnimationTrack
	end

	resetPushAnimation()

	local humanoid = getHumanoid(character)
	if not humanoid then
		return nil
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return nil
	end

	local animationId = resolvePushAnimationId(character)
	if not animationId then
		return nil
	end

	local animation = Instance.new("Animation")
	animation.Name = "CartPushAnimation"
	animation.AnimationId = animationId

	local track = animator:LoadAnimation(animation)
	track.Name = "CartPushTrack"
	track.Priority = Enum.AnimationPriority.Action
	track.Looped = true

	pushAnimationObject = animation
	pushAnimationTrack = track
	animationCharacter = character
	return track
end

local function setPushAnimationPlaying(shouldPlay: boolean, speedScale: number)
	if not shouldPlay then
		if pushAnimationTrack then
			pushAnimationTrack:Stop(0.12)
			pushAnimationTrack.TimePosition = 0
		end
		return
	end

	local track = ensurePushAnimation()
	if not track then
		return
	end

	if not track.IsPlaying then
		track:Play(0.12, 1, speedScale)
	else
		track:AdjustSpeed(speedScale)
	end
end

local function findOwnedCart(): CartPhysics?
	for _, instance in ipairs(CollectionService:GetTagged("PlayerCart")) do
		if not instance:IsA("Model") then
			continue
		end
		if instance:GetAttribute("OwnerUserId") ~= player.UserId then
			continue
		end

		local body = instance:FindFirstChild("Body")
		local handle = instance:FindFirstChild("Handle")
		local linearVelocity = body and body:FindFirstChild("CartLinearVelocity")
		local angularVelocity = body and body:FindFirstChild("CartAngularVelocity")
		if body and body:IsA("BasePart") and handle and handle:IsA("BasePart") and linearVelocity and linearVelocity:IsA("LinearVelocity") and angularVelocity and angularVelocity:IsA("AngularVelocity") then
			return {
				cart = instance,
				body = body,
				handle = handle,
				linearVelocity = linearVelocity,
				angularVelocity = angularVelocity,
			}
		end
	end

	return nil
end

local function refreshCartPhysics()
	if currentCartPhysics and currentCartPhysics.cart.Parent and currentCartPhysics.body.Parent then
		return
	end
	currentCartPhysics = findOwnedCart()
end

local function clearCartForces()
	if currentCartPhysics and currentCartPhysics.cart.Parent and currentCartPhysics.body.Parent then
		currentCartPhysics.linearVelocity.VectorVelocity = Vector3.zero
		currentCartPhysics.angularVelocity.AngularVelocity = Vector3.zero
	end
end

local function refreshCartCount()
	local ok, contents = pcall(function()
		return GetCartContents:InvokeServer()
	end)
	if ok and type(contents) == "table" then
		cartCount = #contents
		updateCartHUD()
	end
end

local function actionEnabled(): boolean
	return isShopPhase and inCart
end

local function onForwardAction(_: string, state: Enum.UserInputState): Enum.ContextActionResult
	if not actionEnabled() then
		return Enum.ContextActionResult.Pass
	end
	inputState.forward = state == Enum.UserInputState.Begin
	if state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		inputState.forward = false
	end
	return Enum.ContextActionResult.Sink
end

local function onReverseAction(_: string, state: Enum.UserInputState): Enum.ContextActionResult
	if not actionEnabled() then
		return Enum.ContextActionResult.Pass
	end
	inputState.reverse = state == Enum.UserInputState.Begin
	if state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		inputState.reverse = false
	end
	return Enum.ContextActionResult.Sink
end

local function onLeftAction(_: string, state: Enum.UserInputState): Enum.ContextActionResult
	if not actionEnabled() then
		return Enum.ContextActionResult.Pass
	end
	inputState.left = state == Enum.UserInputState.Begin
	if state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		inputState.left = false
	end
	return Enum.ContextActionResult.Sink
end

local function onRightAction(_: string, state: Enum.UserInputState): Enum.ContextActionResult
	if not actionEnabled() then
		return Enum.ContextActionResult.Pass
	end
	inputState.right = state == Enum.UserInputState.Begin
	if state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		inputState.right = false
	end
	return Enum.ContextActionResult.Sink
end

local function onGrabAction(_: string, state: Enum.UserInputState): Enum.ContextActionResult
	if not actionEnabled() then
		return Enum.ContextActionResult.Pass
	end
	if state == Enum.UserInputState.Begin and cartCount < CART_CAPACITY then
		local target, inRange = getFocusedStoreItem()
		if target and inRange then
			RequestGrabItem:FireServer()
		end
	end
	return Enum.ContextActionResult.Sink
end

local function onHopDriftAction(_: string, state: Enum.UserInputState): Enum.ContextActionResult
	if not actionEnabled() then
		return Enum.ContextActionResult.Pass
	end
	if state == Enum.UserInputState.Begin then
		hopHeld = true
		hopQueued = true
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		hopHeld = false
		hopQueued = false
	end
	return Enum.ContextActionResult.Sink
end

local function onBoostAction(_: string, state: Enum.UserInputState): Enum.ContextActionResult
	if not actionEnabled() then
		return Enum.ContextActionResult.Pass
	end
	local now = os.clock()
	if state == Enum.UserInputState.Begin then
		if (now - lastBoostTime) >= BOOST_COOLDOWN and not boostActive then
			boostActive = true
			boostEnd = now + BOOST_DURATION
			lastBoostTime = now
		end
	end
	return Enum.ContextActionResult.Sink
end

local function setActionsBound(shouldBind: boolean)
	if shouldBind == actionsBound then
		return
	end

	actionsBound = shouldBind
	if shouldBind then
		ContextActionService:BindActionAtPriority(ACTION_FORWARD, onForwardAction, false, ACTION_PRIORITY, Enum.KeyCode.W, Enum.KeyCode.Up, Enum.KeyCode.ButtonR2)
		ContextActionService:BindActionAtPriority(ACTION_REVERSE, onReverseAction, false, ACTION_PRIORITY, Enum.KeyCode.S, Enum.KeyCode.Down, Enum.KeyCode.ButtonL2)
		ContextActionService:BindActionAtPriority(ACTION_LEFT, onLeftAction, false, ACTION_PRIORITY, Enum.KeyCode.A, Enum.KeyCode.Left, Enum.KeyCode.DPadLeft)
		ContextActionService:BindActionAtPriority(ACTION_RIGHT, onRightAction, false, ACTION_PRIORITY, Enum.KeyCode.D, Enum.KeyCode.Right, Enum.KeyCode.DPadRight)
		ContextActionService:BindActionAtPriority(ACTION_GRAB, onGrabAction, false, ACTION_PRIORITY, Enum.KeyCode.E, Enum.KeyCode.ButtonX)
		ContextActionService:BindActionAtPriority(ACTION_HOP_DRIFT, onHopDriftAction, false, ACTION_PRIORITY, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
		ContextActionService:BindActionAtPriority(ACTION_BOOST, onBoostAction, false, ACTION_PRIORITY, Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift, Enum.KeyCode.ButtonY)

		return
	end

	ContextActionService:UnbindAction(ACTION_FORWARD)
	ContextActionService:UnbindAction(ACTION_REVERSE)
	ContextActionService:UnbindAction(ACTION_LEFT)
	ContextActionService:UnbindAction(ACTION_RIGHT)
	ContextActionService:UnbindAction(ACTION_GRAB)
	ContextActionService:UnbindAction(ACTION_HOP_DRIFT)
	ContextActionService:UnbindAction(ACTION_BOOST)
	boostActive = false
	resetInputState()
end

-- ============================================================
-- TOUCH CONTROLS  (deliberate thumb-zone HUD; replaces the ~8 stray default
-- ContextAction touch buttons). On touch, DRIVING is the analog thumbstick
-- (see Heartbeat). These are the action buttons: Grab, Boost, Get Off.
-- Kept clear of the bottom-left thumbstick and bottom-right jump corners.
-- ============================================================

local touchControls = Instance.new("Frame")
touchControls.Name = "TouchControls"
touchControls.BackgroundTransparency = 1
touchControls.Size = UDim2.new(1, 0, 1, 0)
touchControls.Visible = false
touchControls.Parent = hudGui

local function makeTouchButton(name: string, icon: string, caption: string, colorKey: string, size: number, pos: UDim2): TextButton
	local btn = Instance.new("TextButton")
	btn.Name = name
	btn.AnchorPoint = Vector2.new(1, 1)
	btn.Position = pos
	btn.Size = UDim2.new(0, size, 0, size)
	btn.BackgroundColor3 = UITheme.Color[colorKey]
	btn.BackgroundTransparency = 0.06
	btn.AutoButtonColor = true
	btn.Text = ""
	btn.Parent = touchControls
	UITheme.AddCorner(btn, UITheme.Radius.Large)
	UITheme.AddStroke(btn, UITheme.Color.SurfaceRaised, 2, 0.35)

	local iconLabel = Instance.new("TextLabel")
	iconLabel.Name = "Icon"
	iconLabel.BackgroundTransparency = 1
	iconLabel.Size = UDim2.new(1, 0, 0.56, 0)
	iconLabel.Position = UDim2.new(0, 0, 0.07, 0)
	iconLabel.Font = Enum.Font.SourceSansSemibold
	iconLabel.Text = icon
	iconLabel.TextColor3 = UITheme.Color.TextOnDark
	iconLabel.TextScaled = true
	iconLabel.Parent = btn

	local capLabel = Instance.new("TextLabel")
	capLabel.Name = "Caption"
	capLabel.BackgroundTransparency = 1
	capLabel.Size = UDim2.new(1, -8, 0.30, 0)
	capLabel.Position = UDim2.new(0, 4, 0.65, 0)
	capLabel.Font = UITheme.Font.Heavy
	capLabel.Text = caption
	capLabel.TextColor3 = UITheme.Color.TextOnDark
	capLabel.TextScaled = true
	capLabel.Parent = btn

	return btn
end

local grabBtn  = makeTouchButton("GrabBtn",  "\u{1F6D2}", "GRAB",    "WarmPrimary", 108, UDim2.new(1, -22,  1, -108))
local boostBtn = makeTouchButton("BoostBtn", "\u{26A1}",  "BOOST",   "Sage",        90,  UDim2.new(1, -146, 1, -104))

-- Bottom clearance comes from UITheme.ActionBandBottom so that this script and anything
-- else anchored to the bottom agree on one screen region. Offsets are divided by hudScale
-- because these buttons sit inside a scaled ScreenGui: the old flat 90 rendered at about
-- 121px on a phone against a ~128px jump corner, putting GRAB under the jump button,
-- which is the one control a player needs most during Shop.
syncTouchButtonPositions = function()
	local scale = hudScale.Scale
	if scale <= 0 then return end
	local lift = UITheme.ActionBandBottom() / scale
	grabBtn.Position  = UDim2.new(1, -22,  1, -math.floor(lift))
	boostBtn.Position = UDim2.new(1, -146, 1, -math.floor(lift) + 4)
end
syncTouchButtonPositions()

grabBtn.Activated:Connect(function()
	if not (isShopPhase and inCart) then return end
	if cartCount >= CART_CAPACITY then return end
	local target, inRange = getFocusedStoreItem()
	if target and inRange then
		RequestGrabItem:FireServer()
	end
end)

boostBtn.Activated:Connect(function()
	if not (isShopPhase and inCart) then return end
	local now = os.clock()
	if (now - lastBoostTime) >= BOOST_COOLDOWN and not boostActive then
		boostActive = true
		boostEnd = now + BOOST_DURATION
		lastBoostTime = now
	end
end)

local function updateTouchControls()
	touchControls.Visible = UITheme.IsTouch() and isShopPhase and inCart
end

local function refreshInCart(character: Model)
	inCart = isShopPhase and character:GetAttribute("InCart") == true
	setActionsBound(inCart)
	updateTouchControls()
	if inCart then
		resetInputState()
		setPushAnimationPlaying(false, 1)
		setDefaultAnimateSuppressed(true)
		enforceCartAnimationSuppression()
		currentCartPhysics = nil
		effectsBuilt = false
		refreshCartPhysics()
		task.delay(0.2, function()
			if not effectsBuilt then
				refreshCartPhysics()
				if currentCartPhysics then
					buildEffects(currentCartPhysics)
					buildWheelSounds(currentCartPhysics)
					effectsBuilt = true
				end
			end
		end)
		refreshCartCount()
		updateCartHUD()
	else
		setDefaultAnimateSuppressed(false)
		clearCartForces()
		clearHighlight()
		setPushAnimationPlaying(false, 1)
		updateCartHUD()
	end
end

local function bindCharacter(character: Model)
	setDefaultAnimateSuppressed(false)
	resetPushAnimation()
	character:SetAttribute("InCart", character:GetAttribute("InCart") == true)
	refreshInCart(character)
	character:GetAttributeChangedSignal("InCart"):Connect(function()
		refreshInCart(character)
	end)
end

CartItemAdded.OnClientEvent:Connect(function(_: string, _itemName: string, total: number, _worldPos: Vector3?)
	cartCount = total
	updateCartHUD()
end)

CartCountChanged.OnClientEvent:Connect(function(total: number)
	cartCount = total
	updateCartHUD()
end)

game.Players.LocalPlayer:GetAttributeChangedSignal("RoundPhase"):Connect(function()
	local phase = game.Players.LocalPlayer:GetAttribute("RoundPhase") or "Lobby"
	isShopPhase = phase == "Shop"
	cartBadge.Visible = isShopPhase
	if not isShopPhase then
		cartCount = 0
		updateCartHUD()
		clearCartForces()
		clearHighlight()
		setDefaultAnimateSuppressed(false)
		setPushAnimationPlaying(false, 1)
		setActionsBound(false)
		boostFrame.Visible = false
		inCart = false
		updateTouchControls()
		return
	end

	local character = getCharacter()
	if character then
		refreshInCart(character)
	end
end)

CollectionService:GetInstanceAddedSignal("PlayerCart"):Connect(function(instance: Instance)
	if not (instance:IsA("Model") and instance:GetAttribute("OwnerUserId") == player.UserId) then return end
	currentCartPhysics = nil
	effectsBuilt = false
	refreshCartPhysics()
	-- Build effects immediately, don't wait for actionEnabled() gate in Heartbeat
	if currentCartPhysics and not effectsBuilt then
		buildEffects(currentCartPhysics)
		effectsBuilt = true
	end
end)

CollectionService:GetInstanceRemovedSignal("PlayerCart"):Connect(function(instance: Instance)
	if currentCartPhysics and instance == currentCartPhysics.cart then
		currentCartPhysics = nil
		setPushAnimationPlaying(false, 1)
	end
end)

if player.Character then
	bindCharacter(player.Character)
end
player.CharacterAdded:Connect(bindCharacter)

RunService.Heartbeat:Connect(function(deltaTime: number)
	if not actionEnabled() then
		clearHighlight()
		resetInputState()
		setPushAnimationPlaying(false, 1)
		return
	end

	refreshCartPhysics()
	if not currentCartPhysics then
		resetInputState()
		setPushAnimationPlaying(false, 1)
		return
	end

	enforceCartAnimationSuppression()

	-- Build effects and sounds lazily the first frame cart physics are confirmed live
	if not effectsBuilt then
		buildEffects(currentCartPhysics)
		buildWheelSounds(currentCartPhysics)
		effectsBuilt = true
	end

	local throttle = 0
	if inputState.forward then
		throttle += 1
	end
	if inputState.reverse then
		throttle -= 1
	end

	local steer = 0
	if inputState.right then
		steer += 1
	end
	if inputState.left then
		steer -= 1
	end

	local body = currentCartPhysics.body
	local handle = currentCartPhysics.handle
	local cart = currentCartPhysics.cart
	local forward = flatUnit(body.Position - handle.Position)
	local right = Vector3.yAxis:Cross(forward)
	if right.Magnitude < 0.001 then
		right = flatUnit(body.CFrame.RightVector)
	else
		right = right.Unit
	end

	-- Touch driving: read the active controller's move vector (the on-screen
	-- thumbstick) directly from the ControlModule. Humanoid.MoveDirection can't be
	-- used because the rider is PlatformStand'd while mounted (it stays zero, verified).
	-- GetMoveVector is controller-local: -Z = forward/back (throttle), +X = steer.
	-- This is the entire mobile drive scheme; there are no on-screen movement buttons.
	if UITheme.IsTouch() then
		local controls = getControls()
		if controls then
			local mv = controls:GetMoveVector()
			if math.abs(mv.Z) > 0.2 then
				throttle = if mv.Z < 0 then 1 else -1
			end
			if math.abs(mv.X) > 0.2 then
				steer = if mv.X > 0 then 1 else -1
			end
		end
	end

	local flatVelocity = horizontal(body.AssemblyLinearVelocity)
	local forwardSpeed = forward:Dot(flatVelocity)
	local sideSpeed = right:Dot(flatVelocity)

	local maxSpeed = (cart:GetAttribute("MaxSpeed") :: number?) or DEFAULT_TUNE.MaxSpeed
	local maxReverseSpeed = (cart:GetAttribute("MaxReverseSpeed") :: number?) or DEFAULT_TUNE.MaxReverseSpeed
	local turnRate = (cart:GetAttribute("TurnRate") :: number?) or DEFAULT_TUNE.TurnRate
	local driftTurnRate = (cart:GetAttribute("DriftTurnRate") :: number?) or (turnRate * 1.5)
	local acceleration = (cart:GetAttribute("Acceleration") :: number?) or DEFAULT_TUNE.Acceleration
	local brakeDeceleration = (cart:GetAttribute("BrakeDeceleration") :: number?) or DEFAULT_TUNE.BrakeDeceleration
	local coastDeceleration = (cart:GetAttribute("CoastDeceleration") :: number?) or DEFAULT_TUNE.CoastDeceleration
	local sideDeceleration = (cart:GetAttribute("SideDeceleration") :: number?) or DEFAULT_TUNE.SideDeceleration
	local driftSideDeceleration = (cart:GetAttribute("DriftSideDeceleration") :: number?) or (sideDeceleration * 0.2)
	local steerSpeed = (cart:GetAttribute("SteerSpeed") :: number?) or DEFAULT_TUNE.SteerSpeed
	local jumpImpulse = (cart:GetAttribute("JumpImpulse") :: number?) or 24
	local jumpCooldown = (cart:GetAttribute("JumpCooldown") :: number?) or 0.7
	local groundProbeDistance = (cart:GetAttribute("GroundProbeDistance") :: number?) or 1.35
	local driftMinSpeed = (cart:GetAttribute("DriftMinSpeed") :: number?) or 10

	local now = os.clock()

	-- Expire boost
	if boostActive and now > boostEnd then
		boostActive = false
	end

	-- Sync boost state to cart attribute so server-side CartCollision can read it
	if currentCartPhysics then
		currentCartPhysics.cart:SetAttribute("IsBoosting", boostActive)
	end

	-- Update boost HUD
	local boostCooldownLeft = math.max(BOOST_COOLDOWN - (now - lastBoostTime), 0)
	if boostActive then
		boostFrame.Visible = true
		boostFrame.BackgroundColor3 = UITheme.Color.WarmSecondary
		boostLabel.TextColor3 = UITheme.Color.TextOnDark
		boostLabel.Text = "⚡ Boosting"
		boostSubLabel.Text = string.format("%.1fs of speed", math.max(boostEnd - now, 0))
		boostBarFill.BackgroundColor3 = UITheme.Color.WarmPrimary
		boostBarFill.Size = UDim2.new(math.clamp((boostEnd - now) / BOOST_DURATION, 0, 1), 0, 1, 0)
	elseif boostCooldownLeft > 0 then
		boostFrame.Visible = inCart
		boostFrame.BackgroundColor3 = UITheme.Color.Surface
		boostLabel.TextColor3 = UITheme.Color.CoolPrimary
		boostLabel.Text = "⚡ Boost cooling"
		boostSubLabel.Text = string.format("%.1fs to ready", boostCooldownLeft)
		boostBarFill.BackgroundColor3 = UITheme.Color.CoolPrimary
		boostBarFill.Size = UDim2.new(math.clamp(1 - (boostCooldownLeft / BOOST_COOLDOWN), 0, 1), 0, 1, 0)
	else
		boostFrame.Visible = inCart
		boostFrame.BackgroundColor3 = UITheme.Color.SageDim
		boostLabel.TextColor3 = UITheme.Color.Sage
		boostLabel.Text = "⚡ Boost ready"
		local lastInputName = UserInputService:GetLastInputType().Name
		boostSubLabel.Text = UserInputService.TouchEnabled and "Tap Boost" or (string.find(lastInputName, "Gamepad", 1, true) and "Press Y" or "Press Shift")
		boostBarFill.BackgroundColor3 = UITheme.Color.Success
		boostBarFill.Size = UDim2.new(1, 0, 1, 0)
	end

	local grounded = isCartGrounded(currentCartPhysics, groundProbeDistance)
	if hopQueued and grounded and (now - lastJumpTime) >= jumpCooldown then
		body.AssemblyLinearVelocity += Vector3.new(0, jumpImpulse, 0)
		lastJumpTime = now
		driftWindowEnd = now + 0.8
		hopQueued = false
		grounded = false
	end

	-- Drift: hold space + steer at speed. No hop required — just hold and turn.
	local drifting = hopHeld and math.abs(steer) > 0 and math.abs(forwardSpeed) >= driftMinSpeed

	-- Apply boost multipliers
	local activeMaxSpeed = if boostActive then maxSpeed * BOOST_SPEED_MULTIPLIER else maxSpeed
	local activeAcceleration = if boostActive then acceleration * BOOST_ACCEL_MULTIPLIER else acceleration

	local targetForwardSpeed = 0
	if throttle > 0 then
		targetForwardSpeed = activeMaxSpeed
		if drifting then
			-- During drift don't force forward speed — let momentum carry it.
			-- Only gently nudge toward max so throttle still feels connected.
			forwardSpeed = moveTowards(forwardSpeed, targetForwardSpeed, activeAcceleration * 0.25 * deltaTime)
		else
			forwardSpeed = moveTowards(forwardSpeed, targetForwardSpeed, activeAcceleration * deltaTime)
		end
	elseif throttle < 0 then
		targetForwardSpeed = -maxReverseSpeed
		local deceleration = if forwardSpeed > 0 then brakeDeceleration else acceleration
		forwardSpeed = moveTowards(forwardSpeed, targetForwardSpeed, deceleration * deltaTime)
	else
		local coastRate = if drifting then coastDeceleration * 0.06 else coastDeceleration
		forwardSpeed = moveTowards(forwardSpeed, 0, coastRate * deltaTime)
	end

	local lateralDeceleration = if drifting then driftSideDeceleration else sideDeceleration
	sideSpeed = moveTowards(sideSpeed, 0, lateralDeceleration * deltaTime)

	-- During drift, blend strongly with actual momentum — cart carries its direction of travel.
	local targetVelocity = forward * forwardSpeed + right * sideSpeed
	if drifting then
		targetVelocity = targetVelocity:Lerp(flatVelocity, 0.82)
	end
	currentCartPhysics.linearVelocity.VectorVelocity = targetVelocity

	-- Effects
	local speed = flatVelocity.Magnitude
	setSparkEmitters(drifting and grounded)
	local dustRate = if (grounded and speed > 2) then math.clamp(speed * 1.8, 4, 28) else 0
	setDustRate(dustRate)
	updateWheelSounds(speed, drifting, grounded)

	local steerScale = math.clamp(math.abs(forwardSpeed) / steerSpeed, 0.2, 1)
	local activeTurnRate = if drifting then driftTurnRate else turnRate
	local yawRate = steer * activeTurnRate * steerScale
	currentCartPhysics.angularVelocity.AngularVelocity = Vector3.new(0, -yawRate, 0)

	local actualForwardSpeed = forward:Dot(flatVelocity)
	local pushSpeed = math.max(actualForwardSpeed, 0)
	local shouldPlayPush = grounded and inCart and throttle > 0 and (hasForwardDriveIntent() or (UITheme.IsTouch() and throttle > 0)) and pushSpeed > 3 and flatVelocity.Magnitude > 3.25
	local animationSpeed = math.clamp(0.85 + (pushSpeed / math.max(maxSpeed, 1)) * 0.95, 0.85, 1.65)
	if shouldPlayPush then
		setPushAnimationPlaying(true, animationSpeed)
	else
		setPushAnimationPlaying(false, 1)
		enforceCartAnimationSuppression()
	end

	local focusedTarget, focusedInRange = getFocusedStoreItem()
	if focusedTarget ~= highlighted then
		setHighlight(highlighted, false)
		highlighted = focusedTarget
		setHighlight(highlighted, true)
	end
	updateCartHUD()
end)
