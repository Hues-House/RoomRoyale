--!strict

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Runner = {}
Runner.__index = Runner

local function readJoint(instance: Instance)
	if instance:IsA("Motor6D") and instance.Part0 and instance.Part1 then
		return {instance = instance, Part0 = instance.Part0, Part1 = instance.Part1, C0 = instance.C0, C1 = instance.C1}
	end
	if instance:IsA("AnimationConstraint") and instance.Attachment0 and instance.Attachment1 then
		local attachment0, attachment1 = instance.Attachment0, instance.Attachment1
		local part0 = attachment0:FindFirstAncestorWhichIsA("BasePart")
		local part1 = attachment1:FindFirstAncestorWhichIsA("BasePart")
		if part0 and part1 then
			return {
				instance = instance, Part0 = part0, Part1 = part1,
				C0 = part0.CFrame:ToObjectSpace(attachment0.WorldCFrame),
				C1 = part1.CFrame:ToObjectSpace(attachment1.WorldCFrame),
			}
		end
	end
	return nil
end

local function rotatedBetween(from: Vector3, to: Vector3): CFrame
	local dot = math.clamp(from:Dot(to), -1, 1)
	local axis = from:Cross(to)
	if axis.Magnitude > 0.0001 then return CFrame.fromAxisAngle(axis.Unit, math.acos(dot)) end
	if dot > 0 then return CFrame.identity end
	local perpendicular = from:Cross(Vector3.xAxis)
	if perpendicular.Magnitude < 0.01 then perpendicular = from:Cross(Vector3.yAxis) end
	return CFrame.fromAxisAngle(perpendicular.Unit, math.pi)
end

local function segmentFrame(localStart: Vector3, localEnd: Vector3, worldStart: Vector3, worldEnd: Vector3, reference: CFrame): CFrame
	local original = reference:VectorToWorldSpace((localEnd - localStart).Unit)
	local rotation = rotatedBetween(original, (worldEnd - worldStart).Unit) * reference.Rotation
	return CFrame.new(worldStart - rotation:VectorToWorldSpace(localStart)) * rotation
end

local function release(rig)
	if rig.animationConnection then rig.animationConnection:Disconnect() end
	for motor, original in pairs(rig.original) do
		if motor.instance.Parent then motor.instance.Transform = original end
	end
	if rig.animate and rig.animate.Parent then rig.animate.Disabled = rig.animateDisabled end
	if rig.cart.Parent then rig.cart:SetAttribute("RunnerStatus", nil) end
end

local function createRig(cart: Model, character: Model, humanoid: Humanoid, owner: boolean)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then return nil end
	local motors, incoming, original = {}, {}, {}
	for _, child in ipairs(character:GetDescendants()) do
		local joint = readJoint(child)
		if joint then
			motors[child.Name] = joint
			incoming[joint.Part1] = joint
			original[joint] = joint.instance.Transform
		end
	end
	if not (motors.LeftHip and motors.RightHip and motors.LeftKnee and motors.RightKnee
		and motors.LeftShoulder and motors.RightShoulder and motors.LeftElbow and motors.RightElbow
		and motors.LeftWrist and motors.RightWrist and motors.Waist and motors.Root) then
		cart:SetAttribute("RunnerStatus", "Waiting for complete R15 joints")
		return nil
	end
	local rig = {
		cart = cart, character = character, humanoid = humanoid, root = root,
		motors = motors, incoming = incoming, original = original, poses = {},
		phase = 0, elapsed = 1, owner = owner, loadBlend = 0,
		flightBlend = 0, previousGrounded = true, priorCharge = 0, trick = 0,
		random = Random.new(),
	}
	for motor in pairs(original) do rig.poses[motor] = CFrame.identity end
	if owner then
		local animate = character:FindFirstChild("Animate")
		if animate and animate:IsA("LocalScript") then
			rig.animate, rig.animateDisabled = animate, animate.Disabled
			animate.Disabled = true
		end
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if animator then
			for _, track in ipairs(animator:GetPlayingAnimationTracks()) do track:Stop(0) end
			rig.animationConnection = animator.AnimationPlayed:Connect(function(track) track:Stop(0) end)
		end
	end
	cart:SetAttribute("RunnerStatus", "Running " .. motors.Root.instance.ClassName)
	return rig
end

local function setPose(rig, name: string, pose: CFrame)
	local motor = rig.motors[name]
	if motor then rig.poses[motor] = pose end
end

local function partFrame(rig, part: BasePart, cache): CFrame
	local cached = cache[part]
	if cached then return cached end
	local motor = rig.incoming[part]
	local result = if motor and motor.Part0
		then partFrame(rig, motor.Part0, cache) * motor.C0 * (rig.poses[motor] or CFrame.identity) * motor.C1:Inverse()
		else part.CFrame
	cache[part] = result
	return result
end

local function poseArm(rig, side: string, target: Vector3, cache)
	local shoulder = rig.motors[side .. "Shoulder"]
	local elbow = rig.motors[side .. "Elbow"]
	local wrist = rig.motors[side .. "Wrist"]
	local torso = partFrame(rig, shoulder.Part0, cache)
	local start = (torso * shoulder.C0).Position
	local upperLength = (elbow.C0.Position - shoulder.C1.Position).Magnitude
	local lowerLength = (wrist.C0.Position - elbow.C1.Position).Magnitude
	if upperLength < 0.05 or lowerLength < 0.05 then return end
	local handRotation = rig.root.CFrame.Rotation * CFrame.Angles(math.pi * 0.5, 0, 0)
	local gripAttachment = wrist.Part1:FindFirstChild(side .. "GripAttachment")
	local gripLocal = if gripAttachment and gripAttachment:IsA("Attachment") then gripAttachment.Position else Vector3.zero
	local wristTarget = target - handRotation:VectorToWorldSpace(gripLocal - wrist.C1.Position)
	local delta = wristTarget - start
	if delta.Magnitude < 0.05 then return end
	local direction = delta.Unit
	local distance = math.clamp(delta.Magnitude, math.abs(upperLength - lowerLength) + 0.01, upperLength + lowerLength - 0.01)
	local wristPosition = start + direction * distance
	local bend = -rig.root.CFrame.UpVector + rig.root.CFrame.RightVector * (if side == "Left" then -0.3 else 0.3)
	bend -= direction * bend:Dot(direction)
	if bend.Magnitude < 0.01 then bend = rig.root.CFrame.LookVector end
	local along = (upperLength * upperLength - lowerLength * lowerLength + distance * distance) / (2 * distance)
	local bendDistance = math.sqrt(math.max(0, upperLength * upperLength - along * along))
	local elbowPosition = start + direction * along + bend.Unit * bendDistance
	local upper = segmentFrame(shoulder.C1.Position, elbow.C0.Position, start, elbowPosition, torso.Rotation)
	local lower = segmentFrame(elbow.C1.Position, wrist.C0.Position, elbowPosition, wristPosition, torso.Rotation)
	rig.poses[shoulder] = (torso * shoulder.C0):ToObjectSpace(upper * shoulder.C1)
	rig.poses[elbow] = (upper * elbow.C0):ToObjectSpace(lower * elbow.C1)
	local hand = CFrame.new(wristPosition - handRotation:VectorToWorldSpace(wrist.C1.Position)) * handRotation
	rig.poses[wrist] = (lower * wrist.C0):ToObjectSpace(hand * wrist.C1)
end

local function updatePose(rig, dt: number, telemetry)
	local body = rig.cart.PrimaryPart
	if not body then return end
	local velocity = body.AssemblyLinearVelocity
	local speed = if telemetry then math.abs(telemetry.speed or 0) else (velocity * Vector3.new(1, 0, 1)).Magnitude
	local moving = math.clamp(speed / 10, 0, 1)
	local fresh = workspace:GetServerTimeNow() - (rig.cart:GetAttribute("FeedbackAt") or 0) < 0.6
	local grounded = if telemetry then telemetry.grounded else not fresh or rig.cart:GetAttribute("Grounded") ~= false
	local mode = if telemetry then telemetry.mode else if fresh then rig.cart:GetAttribute("FeedbackMode") else "Idle"
	local charge = if telemetry then telemetry.jumpCharge or 0 else if fresh then rig.cart:GetAttribute("JumpCharge") or 0 else 0
	local crouch = if mode == "JumpCharge" and grounded then math.clamp(charge, 0, 1) else 0
	local tuck = if grounded then 0 else 1
	local load = math.clamp(rig.cart:GetAttribute("CargoWeightRatio") or 0, 0, 1)
	rig.loadBlend += (load - rig.loadBlend) * (1 - math.exp(-6 * dt))
	local effort = rig.loadBlend * (1 - tuck) * (1 - crouch)
	if not grounded and rig.previousGrounded then
		rig.trick = if rig.priorCharge >= 0.75 or (telemetry and (telemetry.jumpSpeed or 0) >= 24) then rig.random:NextInteger(1, 3) else 0
	end
	rig.previousGrounded, rig.priorCharge = grounded, charge
	local flight = if not grounded and rig.trick > 0 and velocity.Y > -8 then 1 else 0
	rig.flightBlend += (flight - rig.flightBlend) * (1 - math.exp(-16 * dt))
	local flourish = rig.flightBlend
	local stride = 0.72 * moving * (1 - effort * 0.12)
	rig.phase = (rig.phase + dt * (8 + math.min(speed, 65) * 0.28) * moving) % (math.pi * 2)
	local bob = math.abs(math.cos(rig.phase)) * 0.1 * moving * (1 - tuck)
	setPose(rig, "Root", CFrame.new(0, bob - crouch * 0.42 - effort * 0.1 + flourish * 0.45, flourish * 0.75) * CFrame.Angles(-flourish * 0.85, 0, 0))
	setPose(rig, "Waist", CFrame.Angles(-0.12 - moving * 0.16 - crouch * 0.18 - effort * 0.14, 0, 0))
	setPose(rig, "Neck", CFrame.Angles(0.1 + moving * 0.12 + effort * 0.08, 0, 0))
	for index, side in ipairs({"Left", "Right"}) do
		local phase = rig.phase + (index - 1) * math.pi
		local swing = math.sin(phase)
		local hip = (swing * stride + crouch * 0.55 + effort * 0.12) * (1 - tuck) + tuck * 0.95
		local knee = (-math.max(0, -swing) * 1.25 * moving - crouch * 1.1 - effort * 0.24) * (1 - tuck) - tuck * 1.7
		local kick = if rig.trick == 2 and side == "Right" then 0.85 else if rig.trick == 3 then -0.4 else 0
		hip = hip * (1 - flourish) + (-0.35 + kick) * flourish
		knee = knee * (1 - flourish) - (if rig.trick == 3 then 1.1 else 0.15) * flourish
		setPose(rig, side .. "Hip", CFrame.Angles(hip, 0, if rig.trick == 2 then flourish * (index * 2 - 3) * 0.35 else 0))
		setPose(rig, side .. "Knee", CFrame.Angles(knee, 0, 0))
		setPose(rig, side .. "Ankle", CFrame.Angles(-hip * 0.28 - knee * 0.35, 0, 0))
	end
	local visual = rig.cart:FindFirstChild("VisualRoot")
	local left = visual and visual:FindFirstChild("HandleLeft")
	local right = visual and visual:FindFirstChild("HandleRight")
	if not (left and left:IsA("Attachment") and right and right:IsA("Attachment")) then return end
	local cache = {[rig.root] = rig.root.CFrame}
	for _, side in ipairs({"Left", "Right"}) do
		local attachment = if side == "Left" then left else right
		local shoulder = rig.motors[side .. "Shoulder"]
		local shoulderPosition = (partFrame(rig, shoulder.Part0, cache) * shoulder.C0).Position
		local localShoulder = body.CFrame:PointToObjectSpace(shoulderPosition)
		local targetLocal = body.CFrame:PointToObjectSpace(attachment.WorldPosition)
		targetLocal = Vector3.new(math.clamp(localShoulder.X, -1.5, 1.5), targetLocal.Y, targetLocal.Z)
		poseArm(rig, side, body.CFrame:PointToWorldSpace(targetLocal), cache)
	end
end

function Runner.new(carts: Instance, player: Player)
	local self = setmetatable({carts = carts, player = player, rigs = {}, scanElapsed = 1,
		cameraPosition = Vector3.zero, ownCart = nil, telemetry = nil, unsupported = {}}, Runner)
	-- Both avatar joint types receive their animation Transform before this phase.
	self.connection = RunService.PreSimulation:Connect(function(dt) self:_simulate(dt) end)
	return self
end

function Runner:step(dt: number, cameraPosition: Vector3, ownCart: Model?, telemetry)
	self.cameraPosition, self.ownCart, self.telemetry = cameraPosition, ownCart, telemetry
	self.scanElapsed += dt
	if self.scanElapsed < 0.2 then return end
	self.scanElapsed = 0
	for _, cart in ipairs(self.carts:GetChildren()) do
		if not cart:IsA("Model") or self.rigs[cart] then continue end
		local player = Players:GetPlayerByUserId(cart:GetAttribute("OwnerUserId") or 0)
		local character = player and player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local seat = cart:FindFirstChild("DriverSeat")
		local retry = self.unsupported[cart]
		if character and humanoid and humanoid.Health > 0 and seat and seat:IsA("Seat") and seat.Occupant == humanoid
			and cart:GetAttribute("Ejected") ~= true and (not retry or retry.character ~= character or os.clock() >= retry.at) then
			local rig = createRig(cart, character, humanoid, player == self.player)
			if rig then
				self.rigs[cart], self.unsupported[cart] = rig, nil
			else
				self.unsupported[cart] = {character = character, at = os.clock() + 2}
			end
		end
	end
	for cart in pairs(self.unsupported) do if not cart.Parent then self.unsupported[cart] = nil end end
end

function Runner:_simulate(dt: number)
	dt = math.min(dt, 0.1)
	for cart, rig in pairs(self.rigs) do
		local seat = cart:FindFirstChild("DriverSeat")
		local player = Players:GetPlayerByUserId(cart:GetAttribute("OwnerUserId") or 0)
		if not cart.Parent or not rig.character.Parent or not player or player.Character ~= rig.character
			or rig.humanoid.Health <= 0 or cart:GetAttribute("Ejected") == true
			or not seat or not seat:IsA("Seat") or seat.Occupant ~= rig.humanoid then
			release(rig)
			self.rigs[cart] = nil
			continue
		end
		local distance = (rig.root.Position - self.cameraPosition).Magnitude
		local interval = if rig.owner then 0 else if distance < 90 then 1 / 30 else if distance < 220 then 1 / 12 else 1 / 5
		rig.elapsed += dt
		if rig.elapsed >= interval then
			updatePose(rig, math.min(rig.elapsed, 0.2), if cart == self.ownCart then self.telemetry else nil)
			rig.elapsed = 0
		end
		for motor, pose in pairs(rig.poses) do
			if motor.instance.Parent and motor.instance.Enabled then motor.instance.Transform = pose end
		end
	end
end

function Runner:destroy()
	self.connection:Disconnect()
	for _, rig in pairs(self.rigs) do release(rig) end
	table.clear(self.rigs)
	table.clear(self.unsupported)
end

return Runner
