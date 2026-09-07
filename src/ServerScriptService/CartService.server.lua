--!strict
-- ServerScriptService > CartService
-- Spawns player-owned carts, mounts characters with weld + IK, grants network ownership,
-- and keeps all cart item pickup validation on the server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")

local Events = ReplicatedStorage:WaitForChild("Events", 15) :: Folder
local CartTemplate = ServerStorage:WaitForChild("CartTemplate", 15) :: Model
local ItemAssets = ReplicatedStorage:WaitForChild("ItemAssets", 15) :: Folder

-- Mount offset relative to handle position:
-- Z=+1.4 stands player behind the handle (handle faces +Z away from cart)
-- Y=-0.5 lowers player from handle height to standing height
local HANDLE_MOUNT_OFFSET = CFrame.new(0, -2.45, 2.1)
local SPAWN_CLEARANCE = 0.2
local LEFT_GRIP_POSITION = Vector3.new(0.94, -0.16, 0.02)
local RIGHT_GRIP_POSITION = Vector3.new(-0.94, -0.16, 0.02)
local GRAB_DISTANCE = 16
local SPAWN_CENTER = Vector3.new(0, 0, 205)  -- last-resort fallback only (see getCartSpawnPosition)
local SPAWN_OFFSETS = {
	Vector3.new(0, 0, 8),
	Vector3.new(0, 0, -8),
	Vector3.new(8, 0, 0),
	Vector3.new(-8, 0, 0),
	Vector3.new(8, 0, 8),
	Vector3.new(-8, 0, -8),
	Vector3.new(8, 0, -8),
	Vector3.new(-8, 0, 8),
}

local CART_TUNE = {
	MaxSpeed = 44,
	MaxReverseSpeed = 16,
	TurnRate = 2.9,
	DriftTurnRate = 3.4,
	Acceleration = 38,
	BrakeDeceleration = 100,
	CoastDeceleration = 22,
	SideDeceleration = 48,
	DriftSideDeceleration = 2,
	SteerSpeed = 9,
	JumpImpulse = 24,
	JumpCooldown = 0.7,
	GroundProbeDistance = 1.35,
	DriftMinSpeed = 14,
}

local CART_CAPACITY = 15
local CART_DISPLAY_SCALE = 0.24
local CART_DISPLAY_TARGET_EXTENT = 1.2
local CART_DISPLAY_LIMIT = 5
local CART_DISPLAY_OFFSETS = {
	Vector3.new(0, 1.6, -0.25),
	Vector3.new(0.65, 1.45, -0.55),
	Vector3.new(-0.65, 1.45, -0.55),
	Vector3.new(0.45, 1.3, -0.95),
	Vector3.new(-0.45, 1.3, -0.95),
}
local LOOSE_ITEM_POP_FORCE = 14
local LOOSE_ITEM_POP_UP = 20

type CartItem = {
	itemId: string,
	itemName: string,
}

type SavedPartState = {
	massless: boolean,
	canCollide: boolean,
}

type HumanoidStateSetting = {
	state: Enum.HumanoidStateType,
	enabled: boolean,
}

type RiderState = {
	character: Model,
	humanoid: Humanoid,
	root: BasePart,
	body: BasePart,
	prompt: ProximityPrompt?,
	driverWeld: Weld?,
	leftIK: IKControl?,
	rightIK: IKControl?,
	walkSpeed: number,
	jumpPower: number,
	jumpHeight: number,
	useJumpPower: boolean,
	autoRotate: boolean,
	platformStand: boolean,
	seatedEnabled: boolean,
	stateSettings: {HumanoidStateSetting},
	partState: {[BasePart]: SavedPartState}?,
}

local cartContents: {[number]: {CartItem}} = {}
local cartModels: {[number]: Model} = {}
local riderStates: {[number]: RiderState} = {}

local spawnIndex = 0
local rebuildCartDisplay: (Player) -> ()

local function ensureChild(parent: Instance, name: string, className: string): Instance
	local existing = parent:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return existing
	end
	if existing then
		existing:Destroy()
	end

	local created = Instance.new(className)
	created.Name = name
	created.Parent = parent
	return created
end

local CartItemAdded = ensureChild(Events, "CartItemAdded", "RemoteEvent") :: RemoteEvent
local CartCountChanged = ensureChild(Events, "CartCountChanged", "RemoteEvent") :: RemoteEvent
local CartFullNotify = ensureChild(Events, "CartFullNotify", "RemoteEvent") :: RemoteEvent
local RequestGrabItem = ensureChild(Events, "RequestGrabItem", "RemoteEvent") :: RemoteEvent
local RequestDropCartItem = ensureChild(Events, "RequestDropCartItem", "RemoteEvent") :: RemoteEvent
local GetCartContents = ensureChild(Events, "GetCartContents", "RemoteFunction") :: RemoteFunction
local RequestCartDismount = ensureChild(Events, "RequestCartDismount", "RemoteEvent") :: RemoteEvent
local RagdollReattach = ensureChild(Events, "RagdollReattach", "BindableEvent") :: BindableEvent
local EjectFromCart = ensureChild(Events, "EjectFromCart", "BindableEvent") :: BindableEvent
local KnockLooseCartItem = ensureChild(Events, "KnockLooseCartItem", "BindableEvent") :: BindableEvent
local GetCartContentsServer = ensureChild(Events, "GetCartContentsServer", "BindableFunction") :: BindableFunction

local function nextOffset(): Vector3
	spawnIndex = (spawnIndex % #SPAWN_OFFSETS) + 1
	return SPAWN_OFFSETS[spawnIndex]
end

local function getWheelSpawnLift(cart: Model, body: BasePart, wheelsFolder: Folder): number
	-- Measure in local space relative to the body so template world position doesn't matter.
	-- Find the lowest wheel extent expressed as an offset from body center.
	local lowestLocalY = math.huge
	for _, descendant in ipairs(wheelsFolder:GetDescendants()) do
		if descendant:IsA("BasePart") then
			-- Convert wheel center into body-local space, then subtract half height
			local localCenter = body.CFrame:PointToObjectSpace(descendant.Position)
			local localBottom = localCenter.Y - (descendant.Size.Y * 0.5)
			lowestLocalY = math.min(lowestLocalY, localBottom)
		end
	end

	if lowestLocalY == math.huge then
		return 1
	end

	-- If lowestLocalY is positive, wheels are above body center — no lift needed.
	-- If negative, wheels hang below body center — lift by that amount.
	return math.max(0, -lowestLocalY)
end

local function getPivotForBodyTarget(cart: Model, targetBodyCFrame: CFrame): CFrame
	local body = cart.PrimaryPart
	if not (body and body:IsA("BasePart")) then
		return targetBodyCFrame
	end

	local bodyFromPivot = cart:GetPivot():ToObjectSpace(body.CFrame)
	return targetBodyCFrame * bodyFromPivot:Inverse()
end

local function getCharacterRoot(character: Model): BasePart?
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function horizontalUnit(vector: Vector3): Vector3
	local flat = Vector3.new(vector.X, 0, vector.Z)
	if flat.Magnitude < 0.001 then
		return Vector3.zAxis
	end
	return flat.Unit
end

local function getDriverMountCFrame(character: Model, humanoid: Humanoid, root: BasePart, body: BasePart, handle: BasePart): CFrame
	local behindDirection = horizontalUnit(handle.Position - body.Position)
	local rootOffset = HANDLE_MOUNT_OFFSET.Position
	local rootPosition = handle.Position + behindDirection * rootOffset.Z + Vector3.new(rootOffset.X, 0, 0)

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { character, body.Parent, body }
	local rayOrigin = rootPosition + Vector3.new(0, 8, 0)
	local rayResult = workspace:Raycast(rayOrigin, Vector3.new(0, -32, 0), raycastParams)
	local footToRootHeight = humanoid.HipHeight + (root.Size.Y * 0.5)
	local groundY = if rayResult then rayResult.Position.Y else (handle.Position.Y + rootOffset.Y - footToRootHeight)
	rootPosition = Vector3.new(rootPosition.X, groundY + footToRootHeight + 0.05, rootPosition.Z)

	local lookTarget = Vector3.new(handle.Position.X, rootPosition.Y, handle.Position.Z)
	local rootWorldCFrame = CFrame.lookAt(rootPosition, lookTarget, Vector3.yAxis)
	return body.CFrame:ToObjectSpace(rootWorldCFrame)
end

local function createHandIK(character: Model, humanoid: Humanoid, chainRootName: string, endEffectorName: string, targetAttachment: Attachment, controlName: string): IKControl?
	local chainRoot = character:FindFirstChild(chainRootName, true)
	local endEffector = character:FindFirstChild(endEffectorName, true)
	if not (chainRoot and chainRoot:IsA("BasePart") and endEffector and endEffector:IsA("BasePart")) then
		return nil
	end

	local control = Instance.new("IKControl")
	control.Name = controlName
	control.Type = Enum.IKControlType.Transform
	control.ChainRoot = chainRoot
	control.EndEffector = endEffector
	control.Target = targetAttachment
	control.Weight = 1
	control.SmoothTime = 0.05
	control.Parent = humanoid
	return control
end

local function setCharacterCartPhysics(riderState: RiderState, enabled: boolean)
	if enabled then
		local savedState: {[BasePart]: SavedPartState} = {}
		for _, descendant in ipairs(riderState.character:GetDescendants()) do
			if descendant:IsA("BasePart") then
				savedState[descendant] = {
					massless = descendant.Massless,
					canCollide = descendant.CanCollide,
				}
				descendant.Massless = true
				descendant.CanCollide = false
			end
		end
		riderState.partState = savedState
		return
	end

	for part, saved in pairs(riderState.partState or {}) do
		if part.Parent then
			part.Massless = saved.massless
			part.CanCollide = saved.canCollide
		end
	end
	riderState.partState = nil
end

local function setCartControls(body: BasePart, linearVelocity: Vector3, angularVelocity: Vector3)
	local linear = body:FindFirstChild("CartLinearVelocity")
	if linear and linear:IsA("LinearVelocity") then
		linear.VectorVelocity = linearVelocity
	end

	local angular = body:FindFirstChild("CartAngularVelocity")
	if angular and angular:IsA("AngularVelocity") then
		angular.AngularVelocity = angularVelocity
	end
end

local function detachPlayer(player: Player)
	local riderState = riderStates[player.UserId]
	if not riderState then
		return
	end

	if riderState.leftIK then
		riderState.leftIK:Destroy()
	end
	if riderState.rightIK then
		riderState.rightIK:Destroy()
	end
	if riderState.driverWeld then
		riderState.driverWeld:Destroy()
	end

	setCharacterCartPhysics(riderState, false)
	setCartControls(riderState.body, Vector3.zero, Vector3.zero)
	pcall(function()
		riderState.body:SetNetworkOwner(player)
	end)

	if riderState.humanoid.Parent then
		riderState.humanoid.UseJumpPower = riderState.useJumpPower
		riderState.humanoid.WalkSpeed = riderState.walkSpeed
		riderState.humanoid.JumpPower = riderState.jumpPower
		riderState.humanoid.JumpHeight = riderState.jumpHeight
		riderState.humanoid.AutoRotate = riderState.autoRotate
		riderState.humanoid.PlatformStand = riderState.platformStand
		riderState.humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, riderState.seatedEnabled)
		for _, stateSetting in ipairs(riderState.stateSettings) do
			riderState.humanoid:SetStateEnabled(stateSetting.state, stateSetting.enabled)
		end
		riderState.humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end

	if riderState.character.Parent then
		riderState.character:SetAttribute("InCart", false)
	end

	if riderState.prompt and riderState.prompt.Parent then
		riderState.prompt.Enabled = true
	end

	riderStates[player.UserId] = nil
end

local function attachPlayerToCart(player: Player, cart: Model)
	if riderStates[player.UserId] then
		return
	end

	local character = player.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = getCharacterRoot(character)
	local body = cart:FindFirstChild("Body")
	local handle = cart:FindFirstChild("Handle")
	local cartSeat = cart:FindFirstChild("CartSeat")
	local prompt = if cartSeat and cartSeat:IsA("BasePart") then cartSeat:FindFirstChildOfClass("ProximityPrompt") else nil
	if not (humanoid and root and body and body:IsA("BasePart") and handle and handle:IsA("BasePart")) then
		return
	end

	local driverMount = ensureChild(body, "DriverMount", "Attachment") :: Attachment
	driverMount.CFrame = getDriverMountCFrame(character, humanoid, root, body, handle)

	local leftGrip = ensureChild(handle, "LeftGrip", "Attachment") :: Attachment
	-- R15 LeftGripAttachment local CFrame = rotate -90deg on X (Axis=1,0,0 SecAxis=0,0,-1)
	leftGrip.CFrame = CFrame.new(LEFT_GRIP_POSITION) * CFrame.Angles(-math.pi/2, math.pi, 0)

	local rightGrip = ensureChild(handle, "RightGrip", "Attachment") :: Attachment
	rightGrip.CFrame = CFrame.new(RIGHT_GRIP_POSITION) * CFrame.Angles(-math.pi/2, math.pi, 0)

	local riderState: RiderState = {
		character = character,
		humanoid = humanoid,
		root = root,
		body = body,
		prompt = prompt,
		driverWeld = nil,
		leftIK = nil,
		rightIK = nil,
		walkSpeed = humanoid.WalkSpeed,
		jumpPower = humanoid.JumpPower,
		jumpHeight = humanoid.JumpHeight,
		useJumpPower = humanoid.UseJumpPower,
		autoRotate = humanoid.AutoRotate,
		platformStand = humanoid.PlatformStand,
		seatedEnabled = humanoid:GetStateEnabled(Enum.HumanoidStateType.Seated),
		stateSettings = {},
		partState = nil,
	}

	setCharacterCartPhysics(riderState, true)

	humanoid.WalkSpeed = 0
	humanoid.AutoRotate = false
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
	humanoid.Sit = false
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	riderState.stateSettings = {
		{ state = Enum.HumanoidStateType.Running, enabled = humanoid:GetStateEnabled(Enum.HumanoidStateType.Running) },
		{ state = Enum.HumanoidStateType.RunningNoPhysics, enabled = humanoid:GetStateEnabled(Enum.HumanoidStateType.RunningNoPhysics) },
		{ state = Enum.HumanoidStateType.Jumping, enabled = humanoid:GetStateEnabled(Enum.HumanoidStateType.Jumping) },
		{ state = Enum.HumanoidStateType.Freefall, enabled = humanoid:GetStateEnabled(Enum.HumanoidStateType.Freefall) },
		{ state = Enum.HumanoidStateType.FallingDown, enabled = humanoid:GetStateEnabled(Enum.HumanoidStateType.FallingDown) },
		{ state = Enum.HumanoidStateType.GettingUp, enabled = humanoid:GetStateEnabled(Enum.HumanoidStateType.GettingUp) },
		{ state = Enum.HumanoidStateType.Climbing, enabled = humanoid:GetStateEnabled(Enum.HumanoidStateType.Climbing) },
		{ state = Enum.HumanoidStateType.Swimming, enabled = humanoid:GetStateEnabled(Enum.HumanoidStateType.Swimming) },
	}
	for _, stateSetting in ipairs(riderState.stateSettings) do
		humanoid:SetStateEnabled(stateSetting.state, false)
	end
	humanoid.PlatformStand = true
	humanoid:ChangeState(Enum.HumanoidStateType.Physics)

	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	root.CFrame = body.CFrame * driverMount.CFrame

	local driverWeld = Instance.new("Weld")
	driverWeld.Name = "DriverWeld"
	driverWeld.Part0 = body
	driverWeld.Part1 = root
	driverWeld.C0 = driverMount.CFrame
	driverWeld.Parent = body
	riderState.driverWeld = driverWeld

	riderState.leftIK = createHandIK(character, humanoid, "LeftUpperArm", "LeftHand", leftGrip, "CartLeftHandIK")
	riderState.rightIK = createHandIK(character, humanoid, "RightUpperArm", "RightHand", rightGrip, "CartRightHandIK")

	character:SetAttribute("InCart", true)
	riderStates[player.UserId] = riderState

	if prompt then
		prompt.Enabled = false
	end

	pcall(function()
		body:SetNetworkOwner(player)
	end)
end

local function configureCartModel(player: Player, cart: Model): BasePart?
	local body = cart:FindFirstChild("Body")
	local handle = cart:FindFirstChild("Handle")
	local cartSeat = cart:FindFirstChild("CartSeat")
	local wheelsFolder = cart:FindFirstChild("Wheels")
	if not (body and body:IsA("BasePart") and handle and handle:IsA("BasePart") and cartSeat and cartSeat:IsA("BasePart") and wheelsFolder and wheelsFolder:IsA("Folder")) then
		return nil
	end

	CollectionService:AddTag(cart, "PlayerCart")
	cart:SetAttribute("OwnerUserId", player.UserId)
	for attributeName, value in pairs(CART_TUNE) do
		cart:SetAttribute(attributeName, value)
	end

	body.CanCollide = false
	body.RootPriority = 127
	body.AssemblyLinearVelocity = Vector3.zero
	body.AssemblyAngularVelocity = Vector3.zero
	body.CustomPhysicalProperties = PhysicalProperties.new(2, 0.1, 0.8, 1, 1)

	for _, descendant in ipairs(cart:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.CustomPhysicalProperties = PhysicalProperties.new(2, 0.1, 0.8, 1, 1)
			if descendant:IsDescendantOf(wheelsFolder) then
				descendant.CanCollide = true
				descendant.CanTouch = true
				descendant.Massless = false
				-- Zero friction so wheels don't fight the drive constraints
				descendant.CustomPhysicalProperties = PhysicalProperties.new(2, 0, 0, 0, 0)
			elseif descendant == body then
				descendant.CanCollide = false
				descendant.CanTouch = false
				descendant.Massless = false
			else
				descendant.CanCollide = false
				descendant.CanTouch = false
				descendant.Massless = true
			end
		end
	end

	cartSeat.CanTouch = false
	cartSeat.Transparency = 1

	local prompt = cartSeat:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Parent = cartSeat
	end
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.ActionText = "Drive"
	prompt.ObjectText = "Your cart"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 9
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
	prompt.Enabled = true
	prompt.Triggered:Connect(function(triggeringPlayer: Player)
		if triggeringPlayer == player then
			attachPlayerToCart(player, cart)
		end
	end)

	for _, name in ipairs({ "DriveAttachment", "CartLinearVelocity", "CartAngularVelocity", "UprightLock" }) do
		local existing = body:FindFirstChild(name)
		if existing then
			existing:Destroy()
		end
	end

	local driveAttachment = Instance.new("Attachment")
	driveAttachment.Name = "DriveAttachment"
	driveAttachment.Axis = Vector3.yAxis
	driveAttachment.Position = Vector3.new(0, -0.95, 0)
	driveAttachment.Parent = body

	local linearVelocity = Instance.new("LinearVelocity")
	linearVelocity.Name = "CartLinearVelocity"
	linearVelocity.Attachment0 = driveAttachment
	linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
	linearVelocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	linearVelocity.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	linearVelocity.MaxAxesForce = Vector3.new(110000, 0, 110000)
	linearVelocity.VectorVelocity = Vector3.zero
	linearVelocity.Parent = body

	local angularVelocity = Instance.new("AngularVelocity")
	angularVelocity.Name = "CartAngularVelocity"
	angularVelocity.Attachment0 = driveAttachment
	angularVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
	angularVelocity.MaxTorque = 90000
	angularVelocity.AngularVelocity = Vector3.zero
	angularVelocity.Parent = body

	local uprightLock = Instance.new("AlignOrientation")
	uprightLock.Name = "UprightLock"
	uprightLock.Mode = Enum.OrientationAlignmentMode.OneAttachment
	uprightLock.Attachment0 = driveAttachment
	uprightLock.AlignType = Enum.AlignType.Parallel
	uprightLock.PrimaryAxisOnly = true
	uprightLock.PrimaryAxis = Vector3.yAxis
	uprightLock.RigidityEnabled = true
	uprightLock.Parent = body

	local existingBumper = body:FindFirstChild("CartBumper")
	if existingBumper then existingBumper:Destroy() end

	pcall(function()
		body:SetNetworkOwner(player)
	end)

	return body
end

-- The player is teleported into their lobby's store before the cart spawns, so place the
-- cart under their feet. This lands it in the correct store (slot 0 OR an offset clone)
-- with no cross-script lookup, and replaces the old fixed SPAWN_CENTER (which pointed at
-- the plaza, ~4000 studs from the offshore showroom).
local function getCartSpawnPosition(player: Player): Vector3
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		local rp = RaycastParams.new()
		rp.FilterType = Enum.RaycastFilterType.Exclude
		rp.FilterDescendantsInstances = { char }
		local hit = workspace:Raycast(root.Position + Vector3.new(0, 2, 0), Vector3.new(0, -24, 0), rp)
		local y = hit and hit.Position.Y or (root.Position.Y - 3)
		return Vector3.new(root.Position.X, y, root.Position.Z)
	end
	-- Fallback: the canonical store entry pad (never the stale plaza SPAWN_CENTER).
	local sr = workspace:FindFirstChild("TheShowroom")
	local pad = sr and sr:FindFirstChild("ShopEntryPad")
	if pad and pad:IsA("BasePart") then
		return pad.Position + Vector3.new(0, 0, 8)
	end
	return SPAWN_CENTER
end

local function spawnCartForPlayer(player: Player)
	local existing = cartModels[player.UserId]
	if existing and existing.Parent then
		attachPlayerToCart(player, existing)
		return
	end

	local character = player.Character
	if not character then
		return
	end

	local cart = CartTemplate:Clone()
	cart.Name = string.format("Cart_%d", player.UserId)

	local wheelsFolder = cart:FindFirstChild("Wheels")
	if not (wheelsFolder and wheelsFolder:IsA("Folder")) then
		cart:Destroy()
		return
	end

	local body = cart.PrimaryPart
	if not (body and body:IsA("BasePart")) then
		cart:Destroy()
		return
	end

	local spawnPosition = getCartSpawnPosition(player) + nextOffset()
	-- Spawn body so its bottom face sits just above ground. Body sizeY=0.5, so half=0.25.
	local targetBodyY = body.Size.Y * 0.5 + SPAWN_CLEARANCE
	local targetBodyCFrame = CFrame.new(spawnPosition + Vector3.new(0, targetBodyY, 0)) * (body.CFrame - body.Position)
	cart.Parent = workspace
	body.CFrame = targetBodyCFrame

	local body = configureCartModel(player, cart)
	if not body then
		cart:Destroy()
		return
	end

	cartModels[player.UserId] = cart
	cartContents[player.UserId] = {}
	rebuildCartDisplay(player)
	attachPlayerToCart(player, cart)
end

local function despawnCartForPlayer(player: Player, clearContents: boolean?)
	detachPlayer(player)

	local cart = cartModels[player.UserId]
	if cart then
		cart:Destroy()
	end

	cartModels[player.UserId] = nil
	-- Only clear contents at Lobby (new round). Style phase needs contents for placement.
	if clearContents then
		cartContents[player.UserId] = nil
	end
end

local function getStoreItemPosition(item: Instance): Vector3?
	if item:IsA("Model") then
		return item:GetPivot().Position
	elseif item:IsA("BasePart") then
		return item.Position
	end
	return nil
end

local function canPlayerGrabStoreItem(player: Player, item: Instance): boolean
	if player:GetAttribute("RoundPhase") ~= "Shop" then
		return false
	end
	if not item.Parent or not CollectionService:HasTag(item, "StoreItem") or item:GetAttribute("Claimed") then
		return false
	end
	local character = player.Character
	local root = character and getCharacterRoot(character)
	local position = getStoreItemPosition(item)
	if not (root and position) then
		return false
	end
	return (root.Position - position).Magnitude <= GRAB_DISTANCE
end

local function findNearestStoreItem(player: Player): Instance?
	local character = player.Character
	local root = character and getCharacterRoot(character)
	if not root then
		return nil
	end

	local nearest: Instance? = nil
	local nearestDistance = GRAB_DISTANCE
	for _, item in ipairs(CollectionService:GetTagged("StoreItem")) do
		if item:GetAttribute("Claimed") then
			continue
		end

		local position = getStoreItemPosition(item)
		if not position then
			continue
		end

		local distance = (root.Position - position).Magnitude
		if distance < nearestDistance then
			nearest = item
			nearestDistance = distance
		end
	end

	return nearest
end

local function getItemWorldPosition(item: Instance): Vector3
	if item:IsA("Model") then
		return item:GetPivot().Position
	elseif item:IsA("BasePart") then
		return (item :: BasePart).Position
	end
	return Vector3.zero
end

local function getAnyBasePart(instance: Instance): BasePart?
	if instance:IsA("BasePart") then
		return instance
	end
	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA("BasePart") then
			return descendant
		end
	end
	return nil
end

local function getInstanceHalfHeight(instance: Instance): number
	if instance:IsA("Model") then
		local _, size = (instance :: Model):GetBoundingBox()
		return math.max(size.Y * 0.5, 0.5)
	elseif instance:IsA("BasePart") then
		return math.max((instance :: BasePart).Size.Y * 0.5, 0.5)
	end
	return 1
end

local function settleLooseWorldItem(instance: Instance, anchorPosition: Vector3)
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { instance }

	local castOrigin = anchorPosition + Vector3.new(0, 16, 0)
	local result = workspace:Raycast(castOrigin, Vector3.new(0, -96, 0), rayParams)
	if result then
		local halfHeight = getInstanceHalfHeight(instance)
		local settledPosition = result.Position + Vector3.new(0, halfHeight + 0.05, 0)
		if instance:IsA("Model") then
			local model = instance :: Model
			local currentPivot = model:GetPivot()
			model:PivotTo(CFrame.new(settledPosition) * (currentPivot - currentPivot.Position))
		elseif instance:IsA("BasePart") then
			local part = instance :: BasePart
			part.CFrame = CFrame.new(settledPosition) * (part.CFrame - part.Position)
		end
	end

	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
		end
	end
end

local function clearDisplayFolder(cart: Model)
	local existing = cart:FindFirstChild("DisplayItems")
	if existing then
		existing:Destroy()
	end
end

local function createCarryBoxModel(itemId: string, itemName: string, boxSize: Vector3, bandSize: Vector3): Model
	local model = Instance.new("Model")
	model.Name = itemId .. "_CarryBox"
	model:SetAttribute("ItemId", itemId)
	model:SetAttribute("ItemName", itemName)

	local box = Instance.new("Part")
	box.Name = "CarryBox"
	box.Size = boxSize
	box.Color = Color3.fromRGB(180, 148, 108)
	box.Material = Enum.Material.SmoothPlastic
	box.TopSurface = Enum.SurfaceType.Smooth
	box.BottomSurface = Enum.SurfaceType.Smooth
	box.Anchored = false
	box.Massless = false
	box.CanCollide = false
	box.Parent = model

	local band = Instance.new("Part")
	band.Name = "Band"
	band.Size = bandSize
	band.Color = Color3.fromRGB(108, 78, 48)
	band.Material = Enum.Material.SmoothPlastic
	band.TopSurface = Enum.SurfaceType.Smooth
	band.BottomSurface = Enum.SurfaceType.Smooth
	band.Anchored = false
	band.Massless = true
	band.CanCollide = false
	band.Parent = model

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = box
	weld.Part1 = band
	weld.Parent = band

	model.PrimaryPart = box
	band.CFrame = box.CFrame * CFrame.new(0, boxSize.Y * 0.18, 0)
	return model
end

local function weldDisplayModelToBody(body: BasePart, model: Instance)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("Script") or descendant:IsA("LocalScript") or descendant:IsA("Sound") or descendant:IsA("ProximityPrompt") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.Massless = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = body
			weld.Part1 = descendant
			weld.Parent = descendant
		end
	end
end

rebuildCartDisplay = function(player: Player)
	local cart = cartModels[player.UserId]
	if not (cart and cart.Parent) then
		return
	end
	local body = cart:FindFirstChild("Body")
	if not (body and body:IsA("BasePart")) then
		return
	end

	clearDisplayFolder(cart)
	local folder = Instance.new("Folder")
	folder.Name = "DisplayItems"
	folder.Parent = cart

	local contents = cartContents[player.UserId] or {}
	for index = 1, math.min(#contents, CART_DISPLAY_LIMIT) do
		local entry = contents[index]
		local displayItem = createCarryBoxModel(
			entry.itemId,
			entry.itemName,
			Vector3.new(0.95, 0.72, 0.95),
			Vector3.new(1.05, 0.08, 0.22)
		)
		displayItem.Name = string.format("Display_%s_%d", entry.itemId, index)

		local offset = CART_DISPLAY_OFFSETS[index] or CART_DISPLAY_OFFSETS[#CART_DISPLAY_OFFSETS]
		local targetCF = body.CFrame * CFrame.new(offset) * CFrame.Angles(0, math.rad((index - 1) * 18), 0)
		if displayItem:IsA("Model") then
			(displayItem :: Model):PivotTo(targetCF)
		elseif displayItem:IsA("BasePart") then
			(displayItem :: BasePart).CFrame = targetCF
		end
		displayItem.Parent = folder
		weldDisplayModelToBody(body, displayItem)
		local primary = getAnyBasePart(displayItem)
		if primary then
			primary.AssemblyLinearVelocity = Vector3.zero
			primary.AssemblyAngularVelocity = Vector3.zero
		end
	end
end

local function createLooseWorldItem(itemId: string, itemName: string, origin: Vector3, launchDirection: Vector3?)
	local template = ItemAssets:FindFirstChild(itemId)
	if not template then
		return
	end

	local dropped = template:Clone()
	dropped.Name = itemId .. "_Loose"
	dropped:SetAttribute("ItemId", itemId)
	dropped:SetAttribute("ItemName", itemName)
	dropped:SetAttribute("Claimed", false)
	CollectionService:AddTag(dropped, "StoreItem")

	for _, descendant in ipairs(dropped:GetDescendants()) do
		if descendant:IsA("Script") or descendant:IsA("LocalScript") or descendant:IsA("Sound") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.Massless = false
			descendant.CanCollide = true
			descendant.CanTouch = false
			local existingPrompt = descendant:FindFirstChildOfClass("ProximityPrompt")
			if existingPrompt then
				existingPrompt:Destroy()
			end
		end
	end

	local primary = getAnyBasePart(dropped)
	local startPos = origin + Vector3.new(math.random(-2, 2), 2.5, math.random(-2, 2))
	if dropped:IsA("Model") then
		(dropped :: Model):PivotTo(CFrame.new(startPos))
	elseif dropped:IsA("BasePart") then
		(dropped :: BasePart).Position = startPos
	end
	if primary then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Style = Enum.ProximityPromptStyle.Custom
		prompt.ActionText = "Grab"
		prompt.ObjectText = itemName
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
		prompt.Parent = primary
	end

	dropped.Parent = workspace
	if primary then
		local launch = launchDirection and launchDirection.Unit or Vector3.new(math.random(-10, 10) / 10, 0, math.random(-10, 10) / 10)
		if launch.Magnitude < 0.1 then
			launch = Vector3.zAxis
		end
		primary.AssemblyLinearVelocity = launch * LOOSE_ITEM_POP_FORCE + Vector3.new(0, LOOSE_ITEM_POP_UP, 0)
		primary.AssemblyAngularVelocity = Vector3.new(math.random(-4, 4), math.random(-6, 6), math.random(-4, 4))

		task.delay(0.45, function()
			if not dropped.Parent then
				return
			end
			settleLooseWorldItem(dropped, primary.Position)
		end)
	end
end

local function addItemToCart(player: Player, item: Instance)
	local contents = cartContents[player.UserId]
	if not contents then
		contents = {}
		cartContents[player.UserId] = contents
	end
	if #contents >= CART_CAPACITY then
		CartFullNotify:FireClient(player)
		return
	end

	local itemId   = tostring(item:GetAttribute("ItemId")   or item.Name)
	local itemName = tostring(item:GetAttribute("ItemName") or itemId)
	local worldPos = getItemWorldPosition(item)

	table.insert(contents, { itemId = itemId, itemName = itemName })

	item:SetAttribute("Claimed",   true)
	item:SetAttribute("ClaimedBy", player.UserId)
	item.Parent = ServerStorage
	rebuildCartDisplay(player)

	-- Fire to client: itemId, itemName, total count, world position of item (for pickup effect)
	CartItemAdded:FireClient(player, itemId, itemName, #contents, worldPos)
	CartCountChanged:FireClient(player, #contents)
end

-- Shop pickup is driven by explicit target selection on the client plus ClickDetector tap/click.
-- Legacy ProximityPrompts stay disabled so they don't compete with the hover-targeted prompt UI.
-- The ClickDetector is placed on a SINGLE representative part (primary part or first BasePart)
-- so hover highlighting reads as one item instead of flickering across every sub-part.
local function getRepresentativePart(item: Instance): BasePart?
	if item:IsA("BasePart") then
		return item :: BasePart
	end
	if item:IsA("Model") and item.PrimaryPart then
		return item.PrimaryPart
	end
	for _, d in ipairs(item:GetDescendants()) do
		if d:IsA("BasePart") then
			return d :: BasePart
		end
	end
	return nil
end

local function connectItemPrompt(item: Instance)
	-- Disable any legacy ProximityPrompts on all parts.
	for _, desc in ipairs(item:GetDescendants()) do
		if desc:IsA("ProximityPrompt") then
			desc.Enabled = false
		end
	end

	local part = getRepresentativePart(item)
	if not part then
		return
	end

	local clickDetector = part:FindFirstChild("StoreItemClickDetector")
	if clickDetector and not clickDetector:IsA("ClickDetector") then
		clickDetector:Destroy()
		clickDetector = nil
	end
	if not clickDetector then
		local created = Instance.new("ClickDetector")
		created.Name = "StoreItemClickDetector"
		created.MaxActivationDistance = GRAB_DISTANCE
		created.Parent = part
		clickDetector = created
	end
	if clickDetector and clickDetector:IsA("ClickDetector") then
		clickDetector.MaxActivationDistance = GRAB_DISTANCE
		if not clickDetector:GetAttribute("PickupBound") then
			clickDetector:SetAttribute("PickupBound", true)
			clickDetector.MouseClick:Connect(function(triggeringPlayer: Player)
				if canPlayerGrabStoreItem(triggeringPlayer, item) then
					addItemToCart(triggeringPlayer, item)
				end
			end)
		end
	end
end

RequestGrabItem.OnServerEvent:Connect(function(player: Player, targetItem: Instance?)
	if player:GetAttribute("RoundPhase") ~= "Shop" then return end
	local item: Instance? = nil
	if typeof(targetItem) == "Instance" then
		if not canPlayerGrabStoreItem(player, targetItem) then
			return
		end
		item = targetItem
	else
		item = findNearestStoreItem(player)
	end
	if item then addItemToCart(player, item) end
end)

-- Connect prompts when items are tagged StoreItem
CollectionService:GetInstanceAddedSignal("StoreItem"):Connect(connectItemPrompt)
for _, item in ipairs(CollectionService:GetTagged("StoreItem")) do
	connectItemPrompt(item)
end

local function getDropOriginForPlayer(player: Player): (Vector3, Vector3?)
	local cart = cartModels[player.UserId]
	if cart then
		local body = cart:FindFirstChild("Body")
		if body and body:IsA("BasePart") then
			return body.Position + body.CFrame.LookVector * 3 + Vector3.new(0, 1.5, 0), body.CFrame.LookVector
		end
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root.Position + root.CFrame.LookVector * 2 + Vector3.new(0, 1.5, 0), root.CFrame.LookVector
	end

	return Vector3.zero, nil
end

RequestCartDismount.OnServerEvent:Connect(function(player: Player)
	if not riderStates[player.UserId] then
		return
	end

	detachPlayer(player)
end)

RequestDropCartItem.OnServerEvent:Connect(function(player: Player, slotIndex: number?)
	if typeof(slotIndex) ~= "number" then
		return
	end

	local contents = cartContents[player.UserId]
	if not contents or #contents == 0 then
		return
	end

	local index = math.clamp(math.floor(slotIndex), 1, #contents)
	local entry = contents[index]
	if not entry then
		return
	end

	table.remove(contents, index)
	rebuildCartDisplay(player)
	CartCountChanged:FireClient(player, #contents)

	local origin, launchDirection = getDropOriginForPlayer(player)
	createLooseWorldItem(entry.itemId, entry.itemName, origin, launchDirection)
end)

KnockLooseCartItem.Event:Connect(function(player: Player, origin: Vector3?, launchDirection: Vector3?)
	local contents = cartContents[player.UserId]
	if not contents or #contents == 0 then
		return
	end

	local removed = table.remove(contents, #contents)
	if not removed then
		return
	end

	rebuildCartDisplay(player)
	CartCountChanged:FireClient(player, #contents)

	local dropOrigin = origin
	if not dropOrigin then
		local cart = cartModels[player.UserId]
		if cart then
			dropOrigin = cart:GetPivot().Position
		else
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			dropOrigin = root and root.Position or Vector3.zero
		end
	end
	createLooseWorldItem(removed.itemId, removed.itemName, dropOrigin :: Vector3, launchDirection)
end)

GetCartContents.OnServerInvoke = function(player: Player)
	local contents = cartContents[player.UserId] or {}
	return table.clone(contents)
end

-- Server-side twin of GetCartContents. RoomService uses this to build the round
-- placement inventory, so the cart stays the single source of what a player collected.
GetCartContentsServer.OnInvoke = function(player: Player)
	local contents = cartContents[player.UserId] or {}
	return table.clone(contents)
end

-- Per-player fault isolation. This used to be a bare loop, so one player erroring during
-- despawn aborted it and left every player after them still welded to their cart with
-- WalkSpeed 0, unable to move for the rest of the round. Solo testing can never surface
-- that, because there is nobody after you in the cohort.
local function despawnCohort(cohort: {Player}, clearContents: boolean, phase: string)
	for _, player in ipairs(cohort) do
		local ok, err = pcall(despawnCartForPlayer, player, clearContents)
		if not ok then
			warn(string.format("[CartService] despawn failed for %s at %s: %s",
				player.Name, phase, tostring(err)))
			-- Last resort: give movement back even though the tidy path failed.
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				for _, weld in ipairs(character:GetDescendants()) do
					if weld:IsA("Weld") and weld.Name == "DriverWeld" then weld:Destroy() end
				end
				local body = workspace:FindFirstChild(string.format("Cart_%d", player.UserId), true)
				if body then body:Destroy() end
				humanoid.PlatformStand = false
				humanoid.Sit = false
				humanoid.AutoRotate = true
				humanoid.WalkSpeed = 16
				if humanoid.UseJumpPower then humanoid.JumpPower = 50 else humanoid.JumpHeight = 7.2 end
				for _, state in ipairs(Enum.HumanoidStateType:GetEnumItems()) do
					if state ~= Enum.HumanoidStateType.None then
						pcall(function() humanoid:SetStateEnabled(state, true) end)
					end
				end
				humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
				riderStates[player.UserId] = nil
				cartModels[player.UserId] = nil
				warn(string.format("[CartService] force-unfroze %s", player.Name))
			end
		end
	end
end

local function onRoundPhaseChanged(roundId: string, phase: string, cohort: {Player})
	if phase == "Shop" then
		task.wait(0.5)
		for _, player in ipairs(cohort) do
			task.spawn(spawnCartForPlayer, player)
		end
	elseif phase == "Style" or phase == "Judge" or phase == "Results" then
		-- No one should stay mounted outside Shop.
		despawnCohort(cohort, false, phase)
	elseif phase == "" or phase == "Lobby" then
		-- New round — clear everything
		despawnCohort(cohort, true, phase)
	end
end

local RoundPhaseServer = Events:WaitForChild("RoundPhaseServer", 15)
if RoundPhaseServer and RoundPhaseServer:IsA("BindableEvent") then
	RoundPhaseServer.Event:Connect(onRoundPhaseChanged)
end

local function onCharacterAdded(player: Player)
	return function(character: Model)
		character:SetAttribute("InCart", false)
		detachPlayer(player)
		if player:GetAttribute("RoundPhase") == "Shop" then
			task.wait(0.5)
			spawnCartForPlayer(player)
		end
	end
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(onCharacterAdded(player))
end)

for _, player in ipairs(Players:GetPlayers()) do
	player.CharacterAdded:Connect(onCharacterAdded(player))
	if player.Character then
		player.Character:SetAttribute("InCart", false)
	end
end

Players.PlayerRemoving:Connect(function(player)
	despawnCartForPlayer(player)
	riderStates[player.UserId] = nil
end)

-- Called by CartCollision to eject a player from their cart.
-- Restore baseline humanoid controls first so a phase transition can't leave
-- the player frozen with cart-era movement settings.
EjectFromCart.Event:Connect(function(player: Player)
	local riderState = riderStates[player.UserId]
	if not riderState then return end

	if riderState.leftIK then riderState.leftIK:Destroy() end
	if riderState.rightIK then riderState.rightIK:Destroy() end
	if riderState.driverWeld then riderState.driverWeld:Destroy() end

	setCharacterCartPhysics(riderState, false)
	setCartControls(riderState.body, Vector3.zero, Vector3.zero)

	if riderState.humanoid.Parent then
		riderState.humanoid.UseJumpPower = riderState.useJumpPower
		riderState.humanoid.WalkSpeed = riderState.walkSpeed
		riderState.humanoid.JumpPower = riderState.jumpPower
		riderState.humanoid.JumpHeight = riderState.jumpHeight
		riderState.humanoid.AutoRotate = riderState.autoRotate
		riderState.humanoid.PlatformStand = false
		riderState.humanoid.Sit = false
		riderState.humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, riderState.seatedEnabled)
		for _, stateSetting in ipairs(riderState.stateSettings) do
			riderState.humanoid:SetStateEnabled(stateSetting.state, stateSetting.enabled)
		end
	end

	if riderState.prompt and riderState.prompt.Parent then
		riderState.prompt.Enabled = false
	end

	if riderState.character.Parent then
		riderState.character:SetAttribute("InCart", false)
	end

	riderStates[player.UserId] = nil
end)

-- Called by CartCollision after ragdoll timer expires
RagdollReattach.Event:Connect(function(player: Player)
	if not player.Parent then return end
	local cart = cartModels[player.UserId]
	if not (cart and cart.Parent) then return end

	-- Teleport player back to handle position
	local body = cart:FindFirstChild("Body")
	local handle = cart:FindFirstChild("Handle")
	local character = player.Character
	local root = character and getCharacterRoot(character)
	if not (body and body:IsA("BasePart") and handle and handle:IsA("BasePart") and root) then return end

	-- Stop cart while player remounts
	setCartControls(body, Vector3.zero, Vector3.zero)

	-- Move player to behind the handle
	local behindPos = handle.Position + Vector3.new(0, 0, 2.5)
	root.CFrame = CFrame.new(behindPos)
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero

	-- Return ownership to player and re-attach
	pcall(function() root:SetNetworkOwner(player) end)
	task.wait(0.1)
	attachPlayerToCart(player, cart)
end)
