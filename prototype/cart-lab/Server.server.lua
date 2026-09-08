--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local PhysicsService = game:GetService("PhysicsService")
local Course = require(script.Parent:WaitForChild("Course"))
local Crashes = require(script.Parent:WaitForChild("Crashes"))
local Flatbed = require(script.Parent:WaitForChild("Flatbed"))
local ShoppingSession = require(script.Parent:WaitForChild("ShoppingSession"))
local Presentation = require(ReplicatedStorage:WaitForChild("CartItemPresentation"))
local course = Course.build()
type Pickup = Course.Pickup & { visual: Model?, visualOrigin: CFrame?, templateId: string?, variantId: string?, finiteStock: number?, remaining: number?, requiredFloorY: number? }
local stockGeneration = 0
for index, pickup: Pickup in course.pickups do
	pickup.templateId = pickup.variantId or (pickup.itemId .. "_" .. index)
	pickup.variantId = pickup.variantId or pickup.templateId
	pickup.remaining = pickup.finiteStock
	local template = Presentation.capture(pickup.visual or pickup.part, pickup.templateId, pickup.visualOrigin or pickup.part.CFrame)
	template:SetAttribute("ItemId", pickup.itemId)
	template:SetAttribute("VariantId", pickup.variantId)
	template:SetAttribute("Space", pickup.space)
	template:SetAttribute("Rarity", pickup.rarity or "Common")
	pickup.part:SetAttribute("TemplateId", pickup.templateId)
end
local RIDER_GROUP = "CartLabMountedRider"
if not PhysicsService:IsCollisionGroupRegistered(RIDER_GROUP) then PhysicsService:RegisterCollisionGroup(RIDER_GROUP) end
PhysicsService:CollisionGroupSetCollidable(RIDER_GROUP, "Default", false)
PhysicsService:CollisionGroupSetCollidable(RIDER_GROUP, RIDER_GROUP, false)

local remote = Instance.new("RemoteEvent")
remote.Name = "CartLabEvent"
remote.Parent = ReplicatedStorage
local carts = Instance.new("Folder")
carts.Name = "LabCarts"
carts.Parent = workspace

type Entry = { id: string, itemId: string, name: string, space: number, weight: number, color: Color3, order: number, rarity: string, templateId: string, variantId: string }
type Rider = { humanoid: Humanoid, jumping: boolean, parts: {[BasePart]: {massless: boolean, collide: boolean, group: string}} }
type State = { cart: Model?, session: any, delivered: boolean, lastGrab: number, lastReset: number, lastFeedback: number, feedbackActive: boolean, spawnIndex: number, nextOrder: number, mountAttempt: number, rider: Rider? }
local states: {[Player]: State} = {}
local spawnSerial = 0
local crashes
local currentRound = nil

local function clearFeedback(state: State)
	state.feedbackActive = false
	local cart = state.cart
	if not cart then return end
	cart:SetAttribute("FeedbackMode", "Idle")
	cart:SetAttribute("JumpCharge", 0)
	cart:SetAttribute("DriftCharge", 0)
	cart:SetAttribute("Boosting", false)
	cart:SetAttribute("Grounded", true)
	cart:SetAttribute("FeedbackAt", 0)
end

local function publishCargo(state: State)
	local cart = state.cart
	if not cart then return end
	local cargo = cart:FindFirstChild("Cargo")
	if not cargo then
		cargo = Instance.new("Folder")
		cargo.Name = "Cargo"
		cargo.Parent = cart
	end
	local present: {[string]: boolean} = {}
	local space, weight = 0, 0
	for _, entry in ipairs(state.session.entries) do
		space += entry.space
		weight += entry.weight
		present[entry.id] = true
		if not cargo:FindFirstChild(entry.id) then
			local folder = Instance.new("Folder")
			folder.Name = entry.id
			folder:SetAttribute("ItemId", entry.itemId)
			folder:SetAttribute("Name", entry.name)
			folder:SetAttribute("Space", entry.space)
			folder:SetAttribute("Weight", entry.weight)
			folder:SetAttribute("Color", entry.color)
			folder:SetAttribute("Order", entry.order)
			folder:SetAttribute("Rarity", entry.rarity)
			folder:SetAttribute("TemplateId", entry.templateId)
			folder:SetAttribute("VariantId", entry.variantId)
			folder.Parent = cargo
		end
	end
	for _, child in ipairs(cargo:GetChildren()) do
		if not present[child.Name] then child:Destroy() end
	end
	cart:SetAttribute("SpaceUsed", space)
	cart:SetAttribute("CargoWeightRatio", math.clamp(weight / 120, 0, 1))
	cart:SetAttribute("BankedCount", #state.session.banked)
	cart:SetAttribute("CargoVersion", (cart:GetAttribute("CargoVersion") or 0) + 1)
end

local function activeBody(player: Player, state: State): BasePart?
	local cart = state.cart
	if cart and cart:GetAttribute("Ejected") then return nil end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = cart and cart:FindFirstChild("DriverSeat")
	if not (cart and cart.Parent and humanoid and humanoid.Health > 0 and seat and seat:IsA("Seat") and seat.Occupant == humanoid) then return nil end
	return cart.PrimaryPart
end

local function canSeePickup(player: Player, body: BasePart, pickup: Pickup): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	local exclusions: {Instance} = {}
	if body.Parent then table.insert(exclusions, body.Parent) end
	if player.Character then table.insert(exclusions, player.Character) end
	params.FilterDescendantsInstances = exclusions
	if math.abs(body.Position.Y - pickup.part.Position.Y) > 4 then return false end
	if pickup.requiredFloorY then
		local support = workspace:Raycast(body.Position, Vector3.new(0, -4.5, 0), params)
		if not support or support.Normal.Y < 0.6 or support.Position.Y < pickup.requiredFloorY - 0.75 then return false end
	end
	return workspace:Raycast(body.Position, pickup.part.Position - body.Position, params) == nil
end

local function grab(player: Player, pickup: Pickup)
	local state = states[player]
	local body = state and activeBody(player, state)
	if not state or not body or not pickup.available then return end
	local now = os.clock()
	local shoppingNow = workspace:GetServerTimeNow()
	if state.session:phase(shoppingNow) ~= "Shop" then return end
	if now - state.lastGrab < 0.15 or (body.Position - pickup.part.Position).Magnitude > 16 then return end
	if not canSeePickup(player, body, pickup) then return end
	state.lastGrab = now
	local space = state.cart and state.cart:GetAttribute("SpaceUsed") or 0
	local cost = math.max(8, pickup.space)
	if space + cost > 100 then
		remote:FireClient(player, "Full", { space = space, needed = cost })
		return
	end
	pickup.available = false
	pickup.prompt.Enabled = false
	pickup.label.Enabled = false
	pickup.part.Transparency = 1
	if pickup.remaining then
		pickup.remaining -= 1
		pickup.part:SetAttribute("StockRemaining", pickup.remaining)
	end
	state.nextOrder += 1
	local entry: Entry = { id = HttpService:GenerateGUID(false), itemId = pickup.itemId, name = pickup.name, space = cost, weight = pickup.weight, color = pickup.color, order = state.nextOrder, rarity = pickup.rarity or "Common", templateId = pickup.templateId :: string, variantId = pickup.variantId :: string }
	assert(state.session:add(entry, shoppingNow) == "Added")
	publishCargo(state)
	remote:FireAllClients("Pickup", { cart = state.cart, item = entry, position = (pickup.visualOrigin or pickup.part.CFrame).Position })
	-- The lab deliberately respawns stock; production rounds own their own stock policy.
	if pickup.remaining and pickup.remaining <= 0 then pickup.label.Enabled = true; return end
	local generation = stockGeneration
	task.delay(6, function()
		if not pickup.part.Parent or generation ~= stockGeneration then return end
		pickup.available = true
		pickup.part.Transparency = 0
		pickup.prompt.Enabled = not currentRound or currentRound:phase(workspace:GetServerTimeNow()) == "Shop"
		pickup.label.Enabled = true
	end)
end

local function spawnTransform(state: State): CFrame
	return course.spawn * CFrame.new(((state.spawnIndex - 1) % 5 - 2) * 10, 0, math.floor((state.spawnIndex - 1) / 5) * 10)
end

local function restoreRider(state: State)
	clearFeedback(state)
	local rider = state.rider
	state.rider = nil
	if not rider then return end
	if rider.humanoid.Parent then rider.humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, rider.jumping) end
	for part, previous in pairs(rider.parts) do
		if part.Parent then
			part.Massless = previous.massless
			part.CanCollide = previous.collide
			part.CollisionGroup = previous.group
		end
	end
end

local function runnerTransform(body: BasePart, humanoid: Humanoid, root: BasePart, character: Model): CFrame
	local standingHeight = humanoid.HipHeight + root.Size.Y * 0.5
	if humanoid.RigType == Enum.HumanoidRigType.R6 then
		local leg = character:FindFirstChild("Left Leg")
		if leg and leg:IsA("BasePart") then standingHeight += leg.Size.Y end
	end
	local scale = math.clamp(standingHeight / 3, 0.65, 1.4)
	return body.CFrame * CFrame.new(0, standingHeight - 2.5, 3.45 + 1.75 * scale)
end

local function mount(player: Player, state: State, character: Model)
	local cart = state.cart
	if not cart then return end
	state.mountAttempt += 1
	local attempt = state.mountAttempt
	local seat = cart:FindFirstChild("DriverSeat")
	if not (seat and seat:IsA("Seat")) then return end
	local function isCurrent(): boolean
		return states[player] == state and state.cart == cart and state.mountAttempt == attempt
			and player.Parent == Players and player.Character == character and cart:IsDescendantOf(workspace)
	end
	local humanoid: Humanoid? = nil
	local root: BasePart? = nil
	local deadline = os.clock() + 10
	local readyFrames = 0
	while os.clock() < deadline do
		if not isCurrent() then return end
		local candidateHumanoid = character:FindFirstChildOfClass("Humanoid")
		local candidateRoot = character:FindFirstChild("HumanoidRootPart")
		if character:IsDescendantOf(workspace) and candidateHumanoid and candidateRoot and candidateRoot:IsA("BasePart")
			and candidateHumanoid.Health > 0 and candidateHumanoid:GetState() ~= Enum.HumanoidStateType.Dead
			and candidateHumanoid.RootPart == candidateRoot and not candidateRoot.Anchored then
			if readyFrames >= 1 then
				humanoid, root = candidateHumanoid, candidateRoot
				break
			end
			readyFrames += 1
		else
			readyFrames = 0
		end
		RunService.Heartbeat:Wait()
	end
	if not (isCurrent() and humanoid and root and seat:IsDescendantOf(cart)) then return end
	if seat.Occupant == humanoid then
		if cart.PrimaryPart then cart.PrimaryPart:SetNetworkOwner(player) end
		return
	end
	restoreRider(state)
	local parts: {[BasePart]: {massless: boolean, collide: boolean, group: string}} = {}
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			parts[part] = {massless = part.Massless, collide = part.CanCollide, group = part.CollisionGroup}
			part.Massless = true
			part.CanCollide = false
			part.CollisionGroup = RIDER_GROUP
		end
	end
	state.rider = { humanoid = humanoid, jumping = humanoid:GetStateEnabled(Enum.HumanoidStateType.Jumping), parts = parts }
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	local body = cart.PrimaryPart
	if not body then restoreRider(state); return end
	local rootTarget = runnerTransform(body, humanoid, root, character)
	character:PivotTo(rootTarget * root.CFrame:ToObjectSpace(character:GetPivot()))
	root.AssemblyLinearVelocity = Vector3.zero
	seat:Sit(humanoid)
	-- Keep the Seat lifecycle while its weld holds a standing runner behind the deck.
	local weldDeadline = os.clock() + 2
	while isCurrent() and seat.Parent and os.clock() < weldDeadline do
		local seatWeld = seat:FindFirstChild("SeatWeld")
		if seat.Occupant == humanoid and seatWeld and seatWeld:IsA("Weld") and seatWeld.Part0 and seatWeld.Part1 then
			local desiredRoot = runnerTransform(body, humanoid, root, character)
			local desiredPart = desiredRoot * root.CFrame:ToObjectSpace(seatWeld.Part1.CFrame)
			seatWeld.C0 = seatWeld.Part0.CFrame:ToObjectSpace(desiredPart * seatWeld.C1)
			cart:SetAttribute("RunnerMounted", true)
			break
		end
		RunService.Heartbeat:Wait()
	end
	if isCurrent() then body:SetNetworkOwner(player) end
end

local function createSeat(state: State, cart: Model, body: BasePart)
	local previous = cart:FindFirstChild("DriverSeat")
	if previous then previous:Destroy() end
	local seat = Instance.new("Seat")
	seat.Name = "DriverSeat"
	seat.Size = Vector3.new(2.5, 0.5, 2)
	seat.CFrame = body.CFrame * CFrame.new(0, -0.5, 5.2)
	seat.Transparency = 1
	seat.CanCollide = false
	seat.CanTouch = false
	seat.CanQuery = false
	seat.Massless = true
	seat.Parent = cart
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1 = body, seat
	weld.Parent = seat
	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		if state.cart ~= cart then return end
		if state.rider and seat.Occupant ~= state.rider.humanoid then
			cart:SetAttribute("RunnerMounted", false)
			restoreRider(state)
		end
	end)
	return seat
end

local function createCart(player: Player, state: State, character: Model)
	crashes:forget(player)
	restoreRider(state)
	if state.cart then state.cart:Destroy() end
	local cart = Instance.new("Model")
	cart.Name = tostring(player.UserId)
	cart:SetAttribute("OwnerUserId", player.UserId)
	cart:SetAttribute("ProtectedUntil", 0)
	cart:SetAttribute("Ejected", false)
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(5, 1, 7)
	body.CFrame = spawnTransform(state)
	body.Color = Color3.fromRGB(222, 178, 118)
	body.Material = Enum.Material.SmoothPlastic
	body.CustomPhysicalProperties = PhysicalProperties.new(0.8, 0.15, 0, 1, 1)
	body.CanCollide = true
	body.Parent = cart
	cart.PrimaryPart = body
	Flatbed.build(cart, body)
	createSeat(state, cart, body)
	state.cart = cart
	clearFeedback(state)
	publishCargo(state)
	cart.Parent = carts
	crashes:track(player, cart, character)
	body:SetNetworkOwner(player)
	mount(player, state, character)
end

local function reset(player: Player, state: State)
	local cart = state.cart
	local character = player.Character
	if not cart or not character or os.clock() - state.lastReset < 1 then return end
	state.lastReset = os.clock()
	clearFeedback(state)
	local seat = cart:FindFirstChild("DriverSeat")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local replaceSeat = not seat or not seat:IsA("Seat") or seat.Occupant ~= humanoid
	crashes:cancel(player)
	cart:PivotTo(spawnTransform(state))
	if cart.PrimaryPart then
		cart.PrimaryPart.AssemblyLinearVelocity = Vector3.zero
		cart.PrimaryPart.AssemblyAngularVelocity = Vector3.zero
		if replaceSeat then createSeat(state, cart, cart.PrimaryPart) end
	end
	cart:SetAttribute("ResetVersion", (cart:GetAttribute("ResetVersion") or 0) + 1)
	mount(player, state, character)
end

crashes = Crashes.new(function(player: Player, cart: Model, character: Model, phase: string, recovery: CFrame?)
	local state = states[player]
	if not state or state.cart ~= cart or player.Character ~= character or not cart.Parent then return false end
	if phase == "Eject" then
		state.mountAttempt += 1
		cart:SetAttribute("RunnerMounted", false)
		restoreRider(state)
		remote:FireClient(player, "Notice", "WHAM! Your items are safe.")
		return true
	end
	if phase == "Recover" and cart.PrimaryPart then
		cart:PivotTo(recovery or spawnTransform(state))
		cart.PrimaryPart.AssemblyLinearVelocity = Vector3.zero
		cart.PrimaryPart.AssemblyAngularVelocity = Vector3.zero
		createSeat(state, cart, cart.PrimaryPart)
		cart:SetAttribute("ResetVersion", (cart:GetAttribute("ResetVersion") or 0) + 1)
		remote:FireClient(player, "Notice", "Back on wheels! Shielded for 5 seconds.")
		task.spawn(mount, player, state, character)
		return true
	end
	return false
end)

local moveCart = Instance.new("BindableFunction")
moveCart.Name = "MoveCartLabTo"
moveCart.Parent = game:GetService("ServerStorage")
moveCart.OnInvoke = function(player: Player, target: CFrame)
	local state = states[player]
	if not state or typeof(target) ~= "CFrame" or currentRound or not activeBody(player, state) then return false end
	local cart = state.cart :: Model
	local body = cart.PrimaryPart :: BasePart
	clearFeedback(state)
	crashes:cancel(player)
	cart:PivotTo(target)
	body.AssemblyLinearVelocity = Vector3.zero
	body.AssemblyAngularVelocity = Vector3.zero
	cart:SetAttribute("ResetVersion", (cart:GetAttribute("ResetVersion") or 0) + 1)
	return true
end

for _, pickup in ipairs(course.pickups) do
	pickup.prompt.Triggered:Connect(function(player) grab(player, pickup) end)
end

local function unitNumber(value: unknown): boolean
	return type(value) == "number" and value == value and value >= 0 and value <= 1
end

remote.OnServerEvent:Connect(function(player: Player, action: unknown, payload: any)
	if type(action) ~= "string" then return end
	local state = states[player]
	if not state then return end
	if action == "Feedback" then
		local now = os.clock()
		if now - state.lastFeedback < 0.1 or not activeBody(player, state) then return end
		if type(payload) ~= "table" or (payload.mode ~= "Idle" and payload.mode ~= "Drift" and payload.mode ~= "JumpCharge" and payload.mode ~= "Dive")
			or not unitNumber(payload.jumpCharge) or not unitNumber(payload.driftCharge)
			or type(payload.boosting) ~= "boolean" or type(payload.grounded) ~= "boolean" then return end
		state.lastFeedback = now
		state.feedbackActive = true
		local cart = state.cart :: Model
		cart:SetAttribute("FeedbackMode", payload.mode)
		cart:SetAttribute("JumpCharge", payload.jumpCharge)
		cart:SetAttribute("DriftCharge", payload.driftCharge)
		cart:SetAttribute("Boosting", payload.boosting)
		cart:SetAttribute("Grounded", payload.grounded)
		cart:SetAttribute("FeedbackAt", workspace:GetServerTimeNow())
		return
	end
	if action == "Reset" then reset(player, state) end
	if action ~= "Grab" then return end
	local body = activeBody(player, state)
	if not body then return end
	local nearest: Pickup? = nil
	local distance = 16
	for _, pickup in ipairs(course.pickups) do
		local current = (body.Position - pickup.part.Position).Magnitude
		if pickup.available and current < distance and canSeePickup(player, body, pickup) then nearest, distance = pickup, current end
	end
	if nearest then grab(player, nearest) end
end)

local function deliverToStyle(player: Player, state: State)
	state.delivered = true
	state.mountAttempt += 1
	crashes:forget(player)
	restoreRider(state)
	if state.cart then state.cart:Destroy(); state.cart = nil end
	local roomFrame = Course.buildStyleRoom(state.spawnIndex)
	local character = player.Character
	if character then
		local root = character:FindFirstChild("HumanoidRootPart")
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then humanoid.Sit = false end
		if root and root:IsA("BasePart") then
			root:SetNetworkOwner(nil)
			character:PivotTo(roomFrame * CFrame.new(0, 4, 14))
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
			task.delay(0.25, function()
				if player.Parent == Players and player.Character == character and root.Parent and state.delivered then root:SetNetworkOwner(player) end
			end)
		end
	end
	remote:FireAllClients("Delivery", {items = state.session.banked, room = roomFrame, ownerUserId = player.UserId})
end

local shoppingTransition = false
local function beginShopping(round)
	shoppingTransition = true
	currentRound = round
	course.world:SetAttribute("ShoppingPhase", if round then "Shop" else nil)
	course.world:SetAttribute("ShoppingRemaining", if round then math.ceil(round.shopEndsAt - workspace:GetServerTimeNow()) else nil)
	stockGeneration += 1
	for _, pickup: Pickup in course.pickups do
		pickup.available = true
		pickup.remaining = pickup.finiteStock
		pickup.part:SetAttribute("StockRemaining", pickup.remaining)
		pickup.part.Transparency = 0
		pickup.prompt.Enabled = true
		pickup.label.Enabled = true
	end
	for _, state in states do
		state.session = if round then ShoppingSession.new(round.shopEndsAt, round.checkoutEndsAt, round.styleStartsAt) else ShoppingSession.new()
		state.delivered = false
		state.nextOrder = 0
	end
	for player, state in states do
		if state.cart and player.Character then
			state.lastReset = -math.huge
			reset(player, state)
			publishCargo(state)
		elseif player.Character then
			createCart(player, state, player.Character)
		end
	end
	remote:FireAllClients("RoundStarted", {})
	shoppingTransition = false
end

local startRound = Instance.new("BindableFunction")
startRound.Name = "StartCartLabRound"
startRound.Parent = game:GetService("ServerStorage")
startRound.OnInvoke = function(shopSeconds: number?)
	local now = workspace:GetServerTimeNow()
	if shoppingTransition or (currentRound and currentRound:phase(now) ~= "Style") then return false end
	local duration = shopSeconds or 45
	assert(duration >= 5 and duration <= 600, "Lab round duration must be 5 to 600 seconds")
	beginShopping(ShoppingSession.new(now + duration, now + duration + 3, now + duration + 5.5))
	return {shopEndsAt = currentRound.shopEndsAt, checkoutEndsAt = currentRound.checkoutEndsAt, styleStartsAt = currentRound.styleStartsAt}
end

local freeShopping = Instance.new("BindableFunction")
freeShopping.Name = "StartCartLabFreeShopping"
freeShopping.Parent = game:GetService("ServerStorage")
freeShopping.OnInvoke = function()
	if shoppingTransition then return false end
	if not currentRound then return true end
	if currentRound:phase(workspace:GetServerTimeNow()) ~= "Style" then return false end
	beginShopping(nil)
	return true
end

local exportCollection = Instance.new("BindableFunction")
exportCollection.Name = "GetCartLabRoundCollection"
exportCollection.Parent = game:GetService("ServerStorage")
exportCollection.OnInvoke = function(player: Player)
	local state = states[player]
	return state and state.session:export() or {}
end

local accumulated = 0
RunService.Heartbeat:Connect(function(dt)
	accumulated += dt
	if accumulated < 0.1 then return end
	accumulated = 0
	local now = workspace:GetServerTimeNow()
	if currentRound then
		local phase = currentRound:phase(now)
		if course.world:GetAttribute("ShoppingPhase") ~= phase then
			course.world:SetAttribute("ShoppingPhase", phase)
			for _, pickup in course.pickups do pickup.prompt.Enabled = pickup.available and phase == "Shop" end
		end
		course.world:SetAttribute("ShoppingRemaining", math.max(0, math.ceil((if phase == "Closing" then currentRound.checkoutEndsAt else currentRound.shopEndsAt) - now)))
	end
	for player, state in pairs(states) do
		local discarded = state.session:settle(now)
		if discarded then
			if #discarded > 0 then remote:FireAllClients("Poof", {cart = state.cart, items = discarded}) end
			publishCargo(state)
		end
		if state.session:phase(now) == "Style" and not state.delivered then deliverToStyle(player, state) end
		local body = activeBody(player, state)
		if state.feedbackActive and (not body or os.clock() - state.lastFeedback > 0.6) then clearFeedback(state) end
		if not body then continue end
		if body.Position.Y < -30 then reset(player, state); continue end
		if #state.session.entries == 0 then continue end
		for _, zone in ipairs(course.checkoutZones) do
			local offset = zone.CFrame:PointToObjectSpace(body.Position)
			local half = zone.Size * 0.5
			if math.abs(offset.X) > half.X or math.abs(offset.Y) > half.Y or math.abs(offset.Z) > half.Z then continue end
			local deposited = state.session:deposit(now)
			if not deposited then break end
			publishCargo(state)
			remote:FireAllClients("Deposit", { cart = state.cart, items = deposited, banked = #state.session.banked, position = zone:GetAttribute("TubeDestination") or zone.Position + Vector3.new(0, 9, 0) })
			break
		end
	end
end)

local function added(player: Player)
	spawnSerial += 1
	local session = if currentRound then ShoppingSession.new(currentRound.shopEndsAt, currentRound.checkoutEndsAt, currentRound.styleStartsAt) else ShoppingSession.new()
	local state: State = { cart = nil, session = session, delivered = false, lastGrab = -math.huge, lastReset = -math.huge, lastFeedback = -math.huge, feedbackActive = false, spawnIndex = spawnSerial, nextOrder = 0, mountAttempt = 0, rider = nil }
	states[player] = state
	player.CharacterAdded:Connect(function(character)
		if state.session:phase(workspace:GetServerTimeNow()) == "Style" then
			character:WaitForChild("HumanoidRootPart", 10)
			if player.Character == character then deliverToStyle(player, state) end
		else
			createCart(player, state, character)
		end
	end)
	if player.Character then task.spawn(createCart, player, state, player.Character) end
end

Players.PlayerAdded:Connect(added)
Players.PlayerRemoving:Connect(function(player)
	crashes:forget(player)
	local state = states[player]
	if state then restoreRider(state) end
	if state and state.cart then state.cart:Destroy() end
	states[player] = nil
end)
for _, player in ipairs(Players:GetPlayers()) do added(player) end
