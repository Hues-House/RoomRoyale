--!strict
-- ServerScriptService > CartCollision
-- Detects cart-to-cart proximity hits via Heartbeat and applies scaled impulses / ragdoll.

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PhysicsService = game:GetService("PhysicsService")

-- Register RagdollLimbs collision group at startup
-- Limbs collide with Default (floor) but not with each other
pcall(function()
	PhysicsService:RegisterCollisionGroup("RagdollLimbs")
	PhysicsService:CollisionGroupSetCollidable("RagdollLimbs", "RagdollLimbs", false)
	PhysicsService:CollisionGroupSetCollidable("RagdollLimbs", "Default", true)
end)

local Events = ReplicatedStorage:WaitForChild("Events", 15)
local RagdollReattach = Events:WaitForChild("RagdollReattach", 15) :: BindableEvent
local EjectFromCart = Events:WaitForChild("EjectFromCart", 15) :: BindableEvent
local RoundPhaseServer = Events:WaitForChild("RoundPhaseServer", 15) :: BindableEvent

local function ensureBindable(name: string): BindableEvent
	local e = Events:FindFirstChild(name)
	if e and e:IsA("BindableEvent") then return e :: BindableEvent end
	if e then e:Destroy() end
	local b = Instance.new("BindableEvent")
	b.Name = name
	b.Parent = Events
	return b
end

local KnockLooseCartItem = ensureBindable("KnockLooseCartItem")

-- Tuning
local MIN_IMPACT_SPEED = 2       -- studs/s minimum to register a hit
local RAGDOLL_SPEED = 32         -- closing speed threshold for ragdoll ejection
local RAGDOLL_BOOST_SPEED = 26   -- lower threshold if at least one cart is boosting
local PUSH_FORCE_SCALE = 0.6     -- multiplier: closing speed -> impulse magnitude
local RAGDOLL_LAUNCH_FORCE = 34          -- outward launch speed on ejection
local RAGDOLL_LAUNCH_UP_BASE = 28        -- baseline upward component keeps eject readable without ceiling shots
local RAGDOLL_LAUNCH_UP_MOVING_BONUS = 12 -- extra lift for already-moving targets
local RAGDOLL_LAUNCH_UP_HEAD_ON_BONUS = 10 -- slightly more lift for earned head-on crashes
local RAGDOLL_DURATION = 2.2             -- seconds before player gets back up
local HIT_COOLDOWN = 1.5         -- seconds between registering hits on the same pair
local HEAD_ON_DOT = 0.42
local DIRECT_HIT_DOT = 0.72
local HEAD_ON_MIN_SPEED = 18
local CLEAN_HIT_MIN_SPEED = 34
local BOOST_RAM_MIN_SPEED = 30
local CLEAN_HIT_SPEED_ADVANTAGE = 12
local STATIONARY_TARGET_SPEED_MAX = 4
local MOVING_TARGET_MIN_SPEED = 14
local HEAD_ON_RAGDOLL_SPEED = 38
local BOOST_STATIONARY_MIN_CLOSING = 32
local FULL_SPEED_STATIONARY_MIN_SPEED = 42
local FULL_SPEED_STATIONARY_MIN_CLOSING = 34
local FULL_SPEED_STATIONARY_ADVANTAGE = 22
local LOOSE_ITEM_DROP_PUSH_CHANCE = 0
local LOOSE_ITEM_DROP_RAGDOLL_CHANCE = 0.20
local KNOCK_PROTECTION_BASE = 5.5
local KNOCK_PROTECTION_REPEAT_BONUS = 1.75
local KNOCK_PROTECTION_MAX = 10
local KNOCK_PROTECTION_REPEAT_WINDOW = 20

local function ensureEvent(name: string): RemoteEvent
	local e = Events:FindFirstChild(name)
	if e and e:IsA("RemoteEvent") then return e :: RemoteEvent end
	if e then e:Destroy() end
	local r = Instance.new("RemoteEvent"); r.Name = name; r.Parent = Events; return r
end
local RagdollStart = ensureEvent("RagdollStart")
local RagdollEnd = ensureEvent("RagdollEnd")
local CartImpact = ensureEvent("CartImpact")

local recentHits: {[string]: number} = {}  -- "cartA_cartB" -> last hit time
local cachedCarts: {Model} = {}  -- rebuilt only on tag add/remove
local ragdolledPlayers: {[number]: boolean} = {}  -- userId -> currently ragdolled, immune to hits
local ragdollRecoveryCallbacks: {[number]: (() -> ())} = {}
local knockProtectionUntil: {[number]: number} = {}
local recentKnockdowns: {[number]: {count: number, lastKnock: number}} = {}

local function rebuildCartCache()
	cachedCarts = CollectionService:GetTagged("PlayerCart") :: {Model}
end
rebuildCartCache()
CollectionService:GetInstanceAddedSignal("PlayerCart"):Connect(rebuildCartCache)
CollectionService:GetInstanceRemovedSignal("PlayerCart"):Connect(rebuildCartCache)

local function getPairKey(a: string, b: string): string
	-- Consistent key regardless of order
	if a < b then return a .. "_" .. b end
	return b .. "_" .. a
end

local function getOwnerPlayer(cart: Model): Player?
	local userId = cart:GetAttribute("OwnerUserId")
	if not userId then return nil end
	for _, player in ipairs(Players:GetPlayers()) do
		if player.UserId == userId then return player end
	end
	return nil
end

local function getCartBody(cart: Model): BasePart?
	local body = cart:FindFirstChild("Body")
	if body and body:IsA("BasePart") then return body end
	return nil
end

local function isCartBoosting(cart: Model): boolean
	return cart:GetAttribute("IsBoosting") == true
end

local function getRiderCharacter(player: Player): Model?
	return player.Character
end

local function getCartForPlayer(player: Player): Model?
	local CollectionSvc = game:GetService("CollectionService")
	for _, cart in ipairs(CollectionSvc:GetTagged("PlayerCart")) do
		if cart:GetAttribute("OwnerUserId") == player.UserId then
			return cart :: Model
		end
	end
	return nil
end

local function stopCart(cart: Model)
	local body = cart:FindFirstChild("Body")
	local lv = body and body:FindFirstChild("CartLinearVelocity")
	local av = body and body:FindFirstChild("CartAngularVelocity")
	if lv and lv:IsA("LinearVelocity") then lv.VectorVelocity = Vector3.zero end
	if av and av:IsA("AngularVelocity") then av.AngularVelocity = Vector3.zero end
end

local function flatUnit(vector: Vector3): Vector3
	local flat = Vector3.new(vector.X, 0, vector.Z)
	if flat.Magnitude < 0.001 then
		return Vector3.zAxis
	end
	return flat.Unit
end

local function getCartForward(cart: Model, body: BasePart): Vector3
	local handle = cart:FindFirstChild("Handle")
	if handle and handle:IsA("BasePart") then
		return flatUnit(body.Position - handle.Position)
	end
	return flatUnit(body.CFrame.LookVector)
end

local function maybeKnockLoose(player: Player?, chance: number, origin: Vector3, direction: Vector3)
	if not player then
		return
	end
	if math.random() <= chance then
		KnockLooseCartItem:Fire(player, origin, direction)
	end
end

local function setShieldHighlight(container: Instance?, adornee: Instance?, isProtected: boolean)
	if not container or not adornee then
		return
	end

	local highlight = container:FindFirstChild("KnockShield")
	if not highlight or not highlight:IsA("Highlight") then
		if not isProtected then
			return
		end
		highlight = Instance.new("Highlight")
		highlight.Name = "KnockShield"
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		highlight.FillColor = Color3.fromRGB(110, 235, 255)
		highlight.FillTransparency = 0.72
		highlight.OutlineColor = Color3.fromRGB(210, 250, 255)
		highlight.OutlineTransparency = 0.08
		highlight.Parent = container
	end

	local shield = highlight :: Highlight
	shield.Adornee = adornee
	shield.Enabled = isProtected
	if not isProtected then
		shield:Destroy()
	end
end

local function setKnockProtectionState(player: Player, untilTime: number?)
	local isProtected = untilTime ~= nil and untilTime > os.clock()
	player:SetAttribute("KnockProtected", isProtected)
	player:SetAttribute("KnockProtectedUntil", untilTime or 0)

	local character = player.Character
	if character then
		character:SetAttribute("KnockProtected", isProtected)
		character:SetAttribute("KnockProtectedUntil", untilTime or 0)
		setShieldHighlight(character, character, isProtected)
	end

	local cart = getCartForPlayer(player)
	if cart then
		cart:SetAttribute("KnockProtected", isProtected)
		cart:SetAttribute("KnockProtectedUntil", untilTime or 0)
		setShieldHighlight(cart, cart, isProtected)
	end
end

local function clearKnockProtection(player: Player)
	knockProtectionUntil[player.UserId] = nil
	setKnockProtectionState(player, nil)
end

local function isKnockProtected(player: Player?): boolean
	if not player then
		return false
	end
	return (knockProtectionUntil[player.UserId] or 0) > os.clock()
end

local function recordKnockdown(player: Player): number
	local now = os.clock()
	local existing = recentKnockdowns[player.UserId]
	if existing and now - existing.lastKnock <= KNOCK_PROTECTION_REPEAT_WINDOW then
		existing.count += 1
		existing.lastKnock = now
		return existing.count
	end

	recentKnockdowns[player.UserId] = {
		count = 1,
		lastKnock = now,
	}
	return 1
end

local function grantKnockProtection(player: Player, knockCount: number)
	local duration = math.min(
		KNOCK_PROTECTION_BASE + math.max(knockCount - 1, 0) * KNOCK_PROTECTION_REPEAT_BONUS,
		KNOCK_PROTECTION_MAX
	)
	local untilTime = os.clock() + duration
	knockProtectionUntil[player.UserId] = untilTime
	setKnockProtectionState(player, untilTime)

	task.delay(duration + 0.1, function()
		if (knockProtectionUntil[player.UserId] or 0) <= os.clock() then
			clearKnockProtection(player)
		end
	end)
end

local function buildLaunchVelocity(forward: Vector3, targetSpeed: number, closingSpeed: number, isHeadOn: boolean, horizontalScale: number?): Vector3
	local launchForward = flatUnit(forward)
	local movingFactor = math.clamp(targetSpeed / 28, 0, 1)
	local closingFactor = math.clamp((closingSpeed - 24) / 22, 0, 1)
	local upward = RAGDOLL_LAUNCH_UP_BASE
		+ (RAGDOLL_LAUNCH_UP_MOVING_BONUS * movingFactor)
		+ (RAGDOLL_LAUNCH_UP_HEAD_ON_BONUS * (isHeadOn and 1 or 0))
		+ (6 * closingFactor)
	local horizontal = RAGDOLL_LAUNCH_FORCE * (horizontalScale or 1)
	return launchForward * horizontal + Vector3.new(0, upward, 0)
end

local function ragdollPlayer(player: Player, launchVelocity: Vector3)
	-- Immune check
	if ragdolledPlayers[player.UserId] then return end
	local character = getRiderCharacter(player)
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not (humanoid and root and root:IsA("BasePart")) then return end

	ragdolledPlayers[player.UserId] = true
	local knockCount = recordKnockdown(player)

	-- Eject from cart
	EjectFromCart:Fire(player)

	-- Stop the cart
	local cart = getCartForPlayer(player)
	if cart then stopCart(cart) end

	-- Keep Motor6Ds enabled so the body stays rigid and launches as one unit.
	-- Add BallSocketConstraints on top of existing joints so arms/legs flop
	-- loosely while the whole character flies through the air.
	humanoid.RequiresNeck = false
	humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
	humanoid:ChangeState(Enum.HumanoidStateType.Freefall)

	local addedConstraints: {BallSocketConstraint} = {}
	local disabledLimbMotors: {Motor6D} = {}

	-- Limb joints get disabled + BSC so they flop freely
	-- Spine/neck stay enabled so the torso stays rigid during flight
	local limbJoints = {
		["LeftShoulder"] = true, ["RightShoulder"] = true,
		["LeftHip"] = true, ["RightHip"] = true,
		["LeftElbow"] = true, ["RightElbow"] = true,
		["LeftKnee"] = true, ["RightKnee"] = true,
		-- Ankles and wrists stay enabled to prevent weird small joint flopping
		["Left Shoulder"] = true, ["Right Shoulder"] = true,
		["Left Hip"] = true, ["Right Hip"] = true,
	}

	for _, desc in ipairs(character:GetDescendants()) do
		if desc:IsA("Motor6D") and limbJoints[desc.Name] and desc.Part0 and desc.Part1 then
			-- Disable the motor so animation stops overriding the BSC
			desc.Enabled = false
			table.insert(disabledLimbMotors, desc)

			local att0 = Instance.new("Attachment")
			att0.Name = "RagdollAtt0"
			att0.CFrame = desc.C0
			att0.Parent = desc.Part0

			local att1 = Instance.new("Attachment")
			att1.Name = "RagdollAtt1"
			att1.CFrame = desc.C1
			att1.Parent = desc.Part1

			local bsc = Instance.new("BallSocketConstraint")
			bsc.Name = "RagdollBSC"
			bsc.Attachment0 = att0
			bsc.Attachment1 = att1
			bsc.LimitsEnabled = false
			bsc.Parent = desc.Part0
			table.insert(addedConstraints, bsc)
		end
	end

	-- Fire to client so it sets CanCollide on limbs (server can't do this persistently)
	RagdollStart:FireClient(player)

	-- Put limb parts in RagdollLimbs collision group so they hit the floor
	-- but don't collide with each other (prevents spazzing)
	local limbPartNames = {
		LeftUpperArm=true, LeftLowerArm=true,
		RightUpperArm=true, RightLowerArm=true,
		LeftUpperLeg=true, LeftLowerLeg=true,
		RightUpperLeg=true, RightLowerLeg=true,
		["Left Arm"]=true, ["Right Arm"]=true,
		["Left Leg"]=true, ["Right Leg"]=true,
	}
	local savedGroups: {[BasePart]: string} = {}

	for _, desc in ipairs(character:GetDescendants()) do
		if desc:IsA("BasePart") then
			desc.Massless = false
			if limbPartNames[desc.Name] then
				savedGroups[desc] = desc.CollisionGroup
				pcall(function() desc.CollisionGroup = "RagdollLimbs" end)
				desc.CanCollide = true
			else
				desc.CanCollide = true
			end
		end
	end
	local addedNoCollisions: {NoCollisionConstraint} = {}

	-- Transfer ALL character part assemblies to server ownership.
	-- After Motor6Ds are disabled each limb becomes its own assembly.
	-- Roblox auto-assigns limb ownership back to the player, so we must
	-- explicitly set every BasePart to server-owned so our CanCollide sticks.
	for _, desc in ipairs(character:GetDescendants()) do
		if desc:IsA("BasePart") then
			pcall(function() desc:SetNetworkOwner(nil) end)
		end
	end
	pcall(function() root:SetNetworkOwner(nil) end)

	-- Wait one physics step for weld destruction and ownership transfer to take effect
	task.wait()
	if not root.Parent then
		ragdolledPlayers[player.UserId] = nil
		ragdollRecoveryCallbacks[player.UserId] = nil
		return
	end

	root.AssemblyLinearVelocity = launchVelocity
	root.AssemblyAngularVelocity = Vector3.new(
		math.random(-4, 4), math.random(-2, 2), math.random(-4, 4)
	)

	local recovered = false
	local function recover(shouldReattach: boolean)
		if recovered then
			return
		end
		recovered = true
		ragdolledPlayers[player.UserId] = nil
		ragdollRecoveryCallbacks[player.UserId] = nil

		for _, bsc in ipairs(addedConstraints) do
			if bsc.Parent then
				if bsc.Attachment0 and bsc.Attachment0.Parent then bsc.Attachment0:Destroy() end
				if bsc.Attachment1 and bsc.Attachment1.Parent then bsc.Attachment1:Destroy() end
				bsc:Destroy()
			end
		end

		for _, motor in ipairs(disabledLimbMotors) do
			if motor.Parent then motor.Enabled = true end
		end

		for part, group in pairs(savedGroups) do
			if part.Parent then
				pcall(function() part.CollisionGroup = group end)
			end
		end

		if character.Parent and humanoid.Parent then
			for _, desc in ipairs(character:GetDescendants()) do
				if desc:IsA("BasePart") then
					pcall(function() desc:SetNetworkOwner(player) end)
				end
			end
			RagdollEnd:FireClient(player)
			humanoid.RequiresNeck = true
			humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
			if player:GetAttribute("RoundPhase") == "Shop" and player.Parent then
				grantKnockProtection(player, knockCount)
			else
				clearKnockProtection(player)
			end
			if shouldReattach then
				task.delay(0.4, function()
					if player.Parent then
						RagdollReattach:Fire(player)
					end
				end)
			end
		end
	end

	ragdollRecoveryCallbacks[player.UserId] = function()
		recover(false)
	end

	task.delay(RAGDOLL_DURATION, function()
		recover(player:GetAttribute("RoundPhase") == "Shop")
	end)
end

if RoundPhaseServer and RoundPhaseServer:IsA("BindableEvent") then
	RoundPhaseServer.Event:Connect(function(roundId: string, phase: string, cohort: {Player})
		if phase == "Shop" then
			return
		end
		for _, player in ipairs(cohort) do
			local recover = ragdollRecoveryCallbacks[player.UserId]
			if recover then recover() end
			clearKnockProtection(player)
			recentKnockdowns[player.UserId] = nil
		end
	end)
end

Players.PlayerRemoving:Connect(function(player)
	ragdolledPlayers[player.UserId] = nil
	ragdollRecoveryCallbacks[player.UserId] = nil
	knockProtectionUntil[player.UserId] = nil
	recentKnockdowns[player.UserId] = nil
end)

local HIT_PROXIMITY = 4.6  -- studs between body centers; tighter to reduce accidental side hits

local function processHit(cartA: Model, cartB: Model)
	local pairKey = getPairKey(cartA.Name, cartB.Name)
	local now = os.clock()
	if (recentHits[pairKey] or 0) + HIT_COOLDOWN > now then return end

	local bodyA = getCartBody(cartA)
	local bodyB = getCartBody(cartB)
	if not (bodyA and bodyB) then return end

	local velA = bodyA.AssemblyLinearVelocity
	local velB = bodyB.AssemblyLinearVelocity

	local boostingA = isCartBoosting(cartA)
	local boostingB = isCartBoosting(cartB)
	local anyBoosting = boostingA or boostingB

	local hitDir = Vector3.new(
		bodyA.Position.X - bodyB.Position.X,
		0,
		bodyA.Position.Z - bodyB.Position.Z
	)
	if hitDir.Magnitude > 0.001 then
		hitDir = hitDir.Unit
	else
		hitDir = Vector3.zAxis
	end

	local towardB = -hitDir
	local towardA = hitDir
	local forwardA = getCartForward(cartA, bodyA)
	local forwardB = getCartForward(cartB, bodyB)
	local flatRelativeVelocity = Vector3.new(velA.X - velB.X, 0, velA.Z - velB.Z)
	local impactSpeed = flatRelativeVelocity.Magnitude
	local closingSpeed = math.max(flatRelativeVelocity:Dot(towardB), 0)
	if impactSpeed < MIN_IMPACT_SPEED or closingSpeed < MIN_IMPACT_SPEED then return end

	recentHits[pairKey] = now

	local ragdollThreshold = if anyBoosting then RAGDOLL_BOOST_SPEED else RAGDOLL_SPEED
	local speedA = Vector3.new(velA.X, 0, velA.Z).Magnitude
	local speedB = Vector3.new(velB.X, 0, velB.Z).Magnitude
	local approachA = forwardA:Dot(towardB)
	local approachB = forwardB:Dot(towardA)
	local headOn = approachA > HEAD_ON_DOT and approachB > HEAD_ON_DOT and speedA >= HEAD_ON_MIN_SPEED and speedB >= HEAD_ON_MIN_SPEED
	local cleanHitA = approachA > DIRECT_HIT_DOT and speedA >= CLEAN_HIT_MIN_SPEED and speedA > speedB + CLEAN_HIT_SPEED_ADVANTAGE
	local cleanHitB = approachB > DIRECT_HIT_DOT and speedB >= CLEAN_HIT_MIN_SPEED and speedB > speedA + CLEAN_HIT_SPEED_ADVANTAGE
	local boostRamA = boostingA and not boostingB and approachA > DIRECT_HIT_DOT and speedA >= BOOST_RAM_MIN_SPEED and speedA > speedB + CLEAN_HIT_SPEED_ADVANTAGE
	local boostRamB = boostingB and not boostingA and approachB > DIRECT_HIT_DOT and speedB >= BOOST_RAM_MIN_SPEED and speedB > speedA + CLEAN_HIT_SPEED_ADVANTAGE
	local targetStillForA = speedB <= STATIONARY_TARGET_SPEED_MAX
	local targetStillForB = speedA <= STATIONARY_TARGET_SPEED_MAX
	local movingClashA = cleanHitA and speedB >= MOVING_TARGET_MIN_SPEED and closingSpeed >= ragdollThreshold
	local movingClashB = cleanHitB and speedA >= MOVING_TARGET_MIN_SPEED and closingSpeed >= ragdollThreshold
	local boostedStillRamA = boostRamA and targetStillForA and closingSpeed >= BOOST_STATIONARY_MIN_CLOSING
	local boostedStillRamB = boostRamB and targetStillForB and closingSpeed >= BOOST_STATIONARY_MIN_CLOSING
	local fullSpeedStillRamA = targetStillForA
		and approachA > DIRECT_HIT_DOT
		and speedA >= FULL_SPEED_STATIONARY_MIN_SPEED
		and closingSpeed >= FULL_SPEED_STATIONARY_MIN_CLOSING
		and speedA >= speedB + FULL_SPEED_STATIONARY_ADVANTAGE
	local fullSpeedStillRamB = targetStillForB
		and approachB > DIRECT_HIT_DOT
		and speedB >= FULL_SPEED_STATIONARY_MIN_SPEED
		and closingSpeed >= FULL_SPEED_STATIONARY_MIN_CLOSING
		and speedB >= speedA + FULL_SPEED_STATIONARY_ADVANTAGE
	local earnedHeadOn = headOn and closingSpeed >= HEAD_ON_RAGDOLL_SPEED

	-- Fire impact event to all nearby players so they hear the crash
	local playerA = getOwnerPlayer(cartA)
	local playerB = getOwnerPlayer(cartB)
	local protectedA = isKnockProtected(playerA)
	local protectedB = isKnockProtected(playerB)
	local ragdollA = false
	local ragdollB = false
	if earnedHeadOn then
		ragdollA = playerA ~= nil and not protectedA
		ragdollB = playerB ~= nil and not protectedB
	elseif boostedStillRamA or movingClashA or fullSpeedStillRamA then
		ragdollB = playerB ~= nil and not protectedB
	elseif boostedStillRamB or movingClashB or fullSpeedStillRamB then
		ragdollA = playerA ~= nil and not protectedA
	end
	local shouldRagdoll = ragdollA or ragdollB
	local impactPos = (bodyA.Position + bodyB.Position) * 0.5
	for _, p in ipairs(Players:GetPlayers()) do
		local char = p.Character
		local pRoot = char and char:FindFirstChild("HumanoidRootPart")
		if pRoot and (pRoot.Position - impactPos).Magnitude < 80 then
			CartImpact:FireClient(p, impactPos, closingSpeed, shouldRagdoll)
		end
	end

	local didRagdoll = false
	if shouldRagdoll then
		local launchA = buildLaunchVelocity(forwardA, speedA, closingSpeed, earnedHeadOn, 0.8)
		local launchB = buildLaunchVelocity(forwardB, speedB, closingSpeed, earnedHeadOn, 0.8)
		local impactOrigin = (bodyA.Position + bodyB.Position) * 0.5

		if earnedHeadOn then
			didRagdoll = ragdollA or ragdollB
			if ragdollA and playerA then
				task.spawn(ragdollPlayer, playerA, launchA)
				maybeKnockLoose(playerA, LOOSE_ITEM_DROP_RAGDOLL_CHANCE, impactOrigin, forwardA)
			end
			if ragdollB and playerB then
				task.spawn(ragdollPlayer, playerB, launchB)
				maybeKnockLoose(playerB, LOOSE_ITEM_DROP_RAGDOLL_CHANCE, impactOrigin, forwardB)
			end
		elseif boostedStillRamA or movingClashA or fullSpeedStillRamA then
			didRagdoll = ragdollB
			if ragdollB and playerB then
				task.spawn(ragdollPlayer, playerB, buildLaunchVelocity(forwardA, speedB, closingSpeed, false))
				maybeKnockLoose(playerB, LOOSE_ITEM_DROP_RAGDOLL_CHANCE, impactOrigin, forwardA)
			end
		elseif boostedStillRamB or movingClashB or fullSpeedStillRamB then
			didRagdoll = ragdollA
			if ragdollA and playerA then
				task.spawn(ragdollPlayer, playerA, buildLaunchVelocity(forwardB, speedA, closingSpeed, false))
				maybeKnockLoose(playerA, LOOSE_ITEM_DROP_RAGDOLL_CHANCE, impactOrigin, forwardB)
			end
		end
	end

	if not didRagdoll then
		-- Push impulse: bias the shove toward the cart that lost the exchange.
		local impulse = closingSpeed * PUSH_FORCE_SCALE
		local pushShareA = if protectedA and not protectedB then 0.2 elseif movingClashB or boostedStillRamB or fullSpeedStillRamB then 1.0 elseif movingClashA or boostedStillRamA or fullSpeedStillRamA then 0.35 else 0.75
		local pushShareB = if protectedB and not protectedA then 0.2 elseif movingClashA or boostedStillRamA or fullSpeedStillRamA then 1.0 elseif movingClashB or boostedStillRamB or fullSpeedStillRamB then 0.35 else 0.75
		local lvA = bodyA:FindFirstChild("CartLinearVelocity")
		local lvB = bodyB:FindFirstChild("CartLinearVelocity")
		if lvA and lvA:IsA("LinearVelocity") then
			lvA.VectorVelocity = lvA.VectorVelocity + hitDir * impulse * pushShareA
		end
		if lvB and lvB:IsA("LinearVelocity") then
			lvB.VectorVelocity = lvB.VectorVelocity - hitDir * impulse * pushShareB
		end
	end
end

-- Heartbeat proximity loop: check all cart pairs each frame
-- With 8 players this is 28 pair checks = trivial cost.
RunService.Heartbeat:Connect(function()
	for i = 1, #cachedCarts do
		for j = i + 1, #cachedCarts do
			local cartA = cachedCarts[i]
			local cartB = cachedCarts[j]
			if not (cartA:IsA("Model") and cartB:IsA("Model")) then continue end
			local bodyA = getCartBody(cartA)
			local bodyB = getCartBody(cartB)
			if not (bodyA and bodyB) then continue end
			local dist = (bodyA.Position - bodyB.Position).Magnitude
			if dist <= HIT_PROXIMITY then
				processHit(cartA, cartB)
			end
		end
	end
end)

-- Clean up stale cooldowns
task.spawn(function()
	while true do
		task.wait(5)
		local now = os.clock()
		for key, t in pairs(recentHits) do
			if now - t > 5 then recentHits[key] = nil end
		end
	end
end)
