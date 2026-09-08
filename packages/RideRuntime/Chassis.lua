--!strict

local Gesture = require(script.Parent.Gesture)

export type Input = {
	throttle: number,
	steer: number,
	brake: boolean,
	held: boolean,
	enabled: boolean,
	edges: { Gesture.Input }?,
}

export type Telemetry = {
	grounded: boolean,
	speed: number,
	slip: number,
	mode: string,
	jumpCharge: number,
	driftCharge: number,
	drifting: boolean,
	diving: boolean,
	jumpSpeed: number,
	driftAssist: number,
	driftSpeedAdded: number,
	boosting: boolean,
	boostSpeedAdded: number,
	load: number,
}

local Chassis = {}
Chassis.__index = Chassis

local function project(vector: Vector3, normal: Vector3): Vector3
	return vector - normal * vector:Dot(normal)
end

local function unitOr(vector: Vector3, fallback: Vector3): Vector3
	return if vector.Magnitude > 0.001 then vector.Unit else fallback
end

local function makeForce(body: BasePart, attachment: Attachment, name: string, atCenter: boolean): VectorForce
	local force = Instance.new("VectorForce")
	force.Name = name
	force.Attachment0 = attachment
	force.RelativeTo = Enum.ActuatorRelativeTo.World
	force.ApplyAtCenterOfMass = atCenter
	force.Force = Vector3.zero
	force.Parent = body
	return force
end

function Chassis.new(body: BasePart, profile, exclusions: { Instance })
	local filter = table.clone(exclusions)
	table.insert(filter, body)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = filter
	raycastParams.RespectCanCollide = true

	local attachment = Instance.new("Attachment")
	attachment.Name = "RideDrive"
	attachment.Parent = body
	local driveForce = makeForce(body, attachment, "RideDriveForce", true)

	local alignment = Instance.new("AlignOrientation")
	alignment.Name = "RideAlignment"
	alignment.Mode = Enum.OrientationAlignmentMode.OneAttachment
	alignment.Attachment0 = attachment
	alignment.RigidityEnabled = false
	alignment.Responsiveness = profile.AlignmentResponse
	alignment.MaxAngularVelocity = profile.MaxAngularVelocity
	alignment.CFrame = body.CFrame.Rotation
	alignment.Parent = body

	local probes = {}
	local halfWidth = math.max(body.Size.X * 0.5 - profile.ProbeInset, 0.1)
	local halfLength = math.max(body.Size.Z * 0.5 - profile.ProbeInset, 0.1)
	for _, x in ipairs({ -halfWidth, halfWidth }) do
		for _, z in ipairs({ -halfLength, halfLength }) do
			local springAttachment = Instance.new("Attachment")
			springAttachment.Name = "RideSupport"
			springAttachment.Position = Vector3.new(x, 0, z)
			springAttachment.Parent = body
			table.insert(probes, {
				attachment = springAttachment,
				force = makeForce(body, springAttachment, "RideSupportForce", false),
			})
		end
	end

	return setmetatable({
		body = body,
		profile = profile,
		params = raycastParams,
		attachment = attachment,
		driveForce = driveForce,
		alignment = alignment,
		probes = probes,
		gesture = Gesture.new(profile),
		load = 0,
		normal = Vector3.yAxis,
		heading = body.CFrame.LookVector,
		steering = 0,
		airSteerRemaining = profile.AirSteerRadians,
		supportRelease = 0,
		boostRemaining = 0,
		boostAirRemaining = 0,
		boostSpeedBudget = 0,
		boostSpeedAdded = 0,
		driftActive = false,
		driftSpeedBudget = 0,
		driftSpeedAdded = 0,
		destroyed = false,
		telemetry = {
			grounded = false, speed = 0, slip = 0, mode = "Idle",
			jumpCharge = 0, driftCharge = 0, drifting = false, driftAssist = 0,
			diving = false, jumpSpeed = 0,
			driftSpeedAdded = 0, boosting = false, boostSpeedAdded = 0, load = 0,
		},
	}, Chassis)
end

function Chassis:setLoad(weightRatio: number)
	if weightRatio == weightRatio then
		self.load = math.clamp(weightRatio, 0, 1)
	end
end

function Chassis:step(deltaTime: number, input: Input): Telemetry
	if self.destroyed or not self.body.Parent or deltaTime <= 0 or deltaTime ~= deltaTime then
		return self.telemetry
	end
	local profile = self.profile
	local dt = math.min(deltaTime, profile.MaxStepSeconds)
	local body = self.body
	local mass = body.AssemblyMass
	if body.Anchored or mass == math.huge then
		self.driveForce.Force = Vector3.zero
		for _, probe in ipairs(self.probes) do
			probe.force.Force = Vector3.zero
		end
		return self.telemetry
	end

	self.supportRelease = math.max(0, self.supportRelease - dt)
	local up = unitOr(body.CFrame.UpVector + Vector3.yAxis * 0.15, Vector3.yAxis)
	local rayDirection = -up * profile.ProbeLength
	local normalSum = Vector3.zero
	local supportVelocitySum = Vector3.zero
	local groundCount = 0
	local supportCount = 0
	for _, probe in ipairs(self.probes) do
		local position = probe.attachment.WorldPosition
		local hit = workspace:Raycast(position, rayDirection, self.params)
		probe.force.Force = Vector3.zero
		if not hit or hit.Normal.Y < profile.MinSupportNormalY or self.supportRelease > 0 then
			continue
		end
		local supportVelocity = Vector3.zero
		if hit.Instance:IsA("BasePart") then
			supportVelocity = hit.Instance:GetVelocityAtPosition(hit.Position)
		end
		local normalVelocity = (body:GetVelocityAtPosition(position) - supportVelocity):Dot(hit.Normal)
		if normalVelocity > profile.SeparatingSpeed then
			continue
		end
		supportCount += 1

		local distance = hit.Distance * math.max(up:Dot(hit.Normal), 0)
		local springAcceleration = workspace.Gravity * hit.Normal.Y
			+ (profile.RideHeight - distance) * profile.SupportSpring
			- normalVelocity * profile.SupportDamping
		probe.force.Force = hit.Normal
			* math.clamp(springAcceleration, 0, workspace.Gravity * profile.MaxSupportGravity)
			* mass / #self.probes
		if distance <= profile.RideHeight + profile.GroundContactMargin then
			groundCount += 1
			normalSum += hit.Normal
			supportVelocitySum += supportVelocity
		end
	end

	local grounded = groundCount >= 2
	if grounded then
		self.airSteerRemaining = profile.AirSteerRadians
	end
	local supportVelocity = if groundCount > 0 then supportVelocitySum / groundCount else Vector3.zero
	local targetNormal = if grounded then unitOr(normalSum, Vector3.yAxis) else Vector3.yAxis
	local normalResponse = if grounded then profile.NormalResponse else profile.AirAlignmentResponse
	self.normal = unitOr(self.normal:Lerp(targetNormal, 1 - math.exp(-normalResponse * dt)), Vector3.yAxis)
	local normal = self.normal
	local fallbackForward = unitOr(project(Vector3.new(0, 0, -1), normal), Vector3.xAxis)
	local forward = unitOr(project(body.CFrame.LookVector, normal), fallbackForward)
	local right = forward:Cross(normal)
	local relativeVelocity = body.AssemblyLinearVelocity - supportVelocity
	local tangentVelocity = project(relativeVelocity, normal)
	local speed = tangentVelocity.Magnitude
	local forwardSpeed = tangentVelocity:Dot(forward)
	local sideSpeed = tangentVelocity:Dot(right)
	local slip = if speed > 0.5 then math.atan2(sideSpeed, math.abs(forwardSpeed)) else 0
	local gesture = self.gesture:stepEvents(dt, {
		steer = input.steer,
		held = input.held,
		enabled = input.enabled,
	}, { grounded = grounded, speed = speed, slip = slip }, input.edges or {})
	local driftActive = gesture.mode == "Drift"
	if driftActive and not self.driftActive then
		self.driftSpeedBudget = profile.DriftMaxSpeedGain
		self.driftSpeedAdded = 0
	elseif not driftActive then
		self.driftSpeedBudget = 0
	end
	self.driftActive = driftActive

	if gesture.jumpSpeed > 0 then
		local launchDirection = unitOr(normal + Vector3.yAxis, Vector3.yAxis)
		body:ApplyImpulse(launchDirection * gesture.jumpSpeed * mass)
		self.supportRelease = profile.HopSupportReleaseSeconds
		for _, probe in ipairs(self.probes) do
			probe.force.Force = Vector3.zero
		end
		grounded = false
		supportCount = 0
	end
	if gesture.boostSeconds > 0 then
		self.boostRemaining = gesture.boostSeconds
		self.boostAirRemaining = profile.BoostAirGraceSeconds
		self.boostSpeedBudget = math.min(profile.BoostMaxSpeedGain, gesture.boostSeconds * profile.BoostSpeedGainPerSecond)
		self.boostSpeedAdded = 0
	end
	if input.brake or input.throttle < 0 or not input.enabled then
		self.boostRemaining = 0
		self.boostSpeedBudget = 0
	end
	local boosting = grounded and self.boostRemaining > 0
	if grounded then
		self.boostRemaining = math.max(0, self.boostRemaining - dt)
	else
		self.boostAirRemaining = math.max(0, self.boostAirRemaining - dt)
		if self.boostAirRemaining == 0 then
			self.boostRemaining = 0
		end
	end

	local steer = if input.enabled then math.clamp(input.steer, -1, 1) else 0
	local steerMagnitude = math.abs(steer)
	steer = if steerMagnitude <= profile.SteeringDeadzone then 0
		else math.sign(steer) * (steerMagnitude - profile.SteeringDeadzone) / (1 - profile.SteeringDeadzone)
	local steerResponse = profile.SteeringResponse * (1 - self.load * profile.FullLoadSteeringLoss)
	self.steering += (steer - self.steering) * (1 - math.exp(-steerResponse * dt))
	local turnRate = if gesture.drifting then profile.DriftTurnRate else profile.TurnRate
	local turnScale = math.clamp(speed / profile.SteerReferenceSpeed, 0, 1)
	local travelSign = if not driftActive and forwardSpeed < -1 then -1 else 1
	local turn = -self.steering * turnRate * turnScale * travelSign * dt
	if not grounded then
		turn = math.clamp(-self.steering * profile.AirTurnRate * dt, -self.airSteerRemaining, self.airSteerRemaining)
		self.airSteerRemaining = math.max(0, self.airSteerRemaining - math.abs(turn))
	end
	self.heading = unitOr(project(self.heading, normal), forward)
	self.heading = CFrame.fromAxisAngle(normal, turn):VectorToWorldSpace(self.heading)
	if grounded and driftActive and speed >= profile.MinDriftSpeed then
		local direction = tangentVelocity.Unit
		local headingSlip = math.atan2(direction:Cross(self.heading):Dot(normal), direction:Dot(self.heading))
		self.heading = CFrame.fromAxisAngle(normal, math.clamp(headingSlip, -profile.DriftMaxSlip, profile.DriftMaxSlip)):VectorToWorldSpace(direction)
	end
	if not input.enabled then
		self.heading = forward
		self.steering = 0
	end
	self.alignment.Enabled = input.enabled
	self.alignment.Responsiveness = if grounded then profile.AlignmentResponse else profile.AirAlignmentResponse
	self.alignment.MaxTorque = mass * profile.AlignmentTorquePerMass
	self.alignment.CFrame = CFrame.lookAt(Vector3.zero, self.heading, normal)

	local acceleration = Vector3.zero
	local driftAssist = 0
	if input.enabled and grounded then
		local loadAcceleration = 1 - self.load * profile.FullLoadAccelerationLoss
		local throttle = math.clamp(input.throttle, -1, 1)
		local carryingDrift = gesture.drifting and throttle >= 0
		local direction = if speed > 0.5 then tangentVelocity.Unit else forward
		if input.brake then
			if speed > 0.001 then
				acceleration -= tangentVelocity.Unit * math.min(profile.BrakeAcceleration, speed / dt)
			end
		elseif throttle ~= 0 then
			local carryingMomentum = carryingDrift or boosting
			local driveDirection = if carryingMomentum then direction else forward
			local targetSpeed = if throttle > 0 then profile.CruiseSpeed else profile.ReverseSpeed
			local driveAcceleration = profile.Acceleration * loadAcceleration
			local uphillGravity = math.max(workspace.Gravity * driveDirection.Y * math.sign(throttle), 0)
			driveAcceleration += uphillGravity * profile.ClimbAssist
			if not carryingMomentum and forwardSpeed * throttle < -1 then
				driveAcceleration = profile.BrakeAcceleration
			elseif speed >= targetSpeed then
				driveAcceleration = 0
			else
				driveAcceleration = math.min(driveAcceleration, (targetSpeed - speed) / dt)
			end
			acceleration += driveDirection * throttle * driveAcceleration
		end

		if not input.brake then
			-- These budgets add speed once per action; collisions never refill them.
			local availableGain = math.max(profile.ArcadeSpeedCeiling - speed, 0)
			if carryingDrift and speed >= profile.MinDriftSpeed then
				local gain = math.min(profile.DriftAcceleration * dt, self.driftSpeedBudget, availableGain)
				self.driftSpeedBudget -= gain
				self.driftSpeedAdded += gain
				availableGain -= gain
				driftAssist = gain / (profile.DriftAcceleration * dt)
				acceleration += direction * (gain / dt)
			end
			if boosting then
				local gain = math.min(profile.BoostAcceleration * loadAcceleration * dt, self.boostSpeedBudget, availableGain)
				self.boostSpeedBudget -= gain
				self.boostSpeedAdded += gain
				acceleration += direction * (gain / dt)
			end
		end

		if speed > 0.5 then
			local direction = tangentVelocity.Unit
			local travelForward = forward * travelSign
			local angle = math.atan2(direction:Cross(travelForward):Dot(normal), direction:Dot(travelForward))
			local gripResponse = if gesture.drifting then profile.DriftGripResponse else profile.GripResponse
			local gripLimit = if gesture.drifting then profile.DriftGripAcceleration else profile.GripAcceleration
			local gripAngle = math.clamp(angle * (1 - math.exp(-gripResponse * dt)), -gripLimit * dt / speed, gripLimit * dt / speed)
			-- A finite rotation avoids adding energy when a force is held across a slow frame.
			local grippedVelocity = CFrame.fromAxisAngle(normal, gripAngle):VectorToWorldSpace(tangentVelocity)
			acceleration += (grippedVelocity - tangentVelocity) / dt
			local coastReduction = 1 - self.load * profile.FullLoadCoastReduction
			local drag = if (carryingDrift or boosting) and not input.brake then 0
				else (if throttle == 0 and not input.brake then profile.CoastDeceleration else profile.RollingDeceleration) * coastReduction
			acceleration -= direction * math.min(drag, speed / dt)
		end
	elseif input.enabled and not grounded and turn ~= 0 and speed > 0.5 then
		local correctionAngle = math.sign(turn) * profile.AirLateralAcceleration * dt / speed
		local correctedVelocity = CFrame.fromAxisAngle(normal, correctionAngle):VectorToWorldSpace(tangentVelocity)
		acceleration = (correctedVelocity - tangentVelocity) / dt
	end
	if input.enabled and not grounded and supportCount == 0 then
		local gravityScale = if gesture.diving then profile.DiveGravityScale else profile.AirGravityScale
		acceleration += Vector3.yAxis * workspace.Gravity * (1 - gravityScale)
	end
	self.driveForce.Force = acceleration * mass

	self.telemetry = {
		grounded = grounded,
		speed = speed,
		slip = slip,
		mode = gesture.mode,
		jumpCharge = gesture.jumpCharge,
		driftCharge = gesture.driftCharge,
		drifting = gesture.drifting,
		diving = gesture.diving,
		jumpSpeed = gesture.jumpSpeed,
		driftAssist = driftAssist,
		driftSpeedAdded = self.driftSpeedAdded,
		boosting = boosting,
		boostSpeedAdded = self.boostSpeedAdded,
		load = self.load,
	}
	return self.telemetry
end

function Chassis:destroy()
	if self.destroyed then
		return
	end
	self.destroyed = true
	self.driveForce:Destroy()
	self.alignment:Destroy()
	self.attachment:Destroy()
	for _, probe in ipairs(self.probes) do
		probe.force:Destroy()
		probe.attachment:Destroy()
	end
end

return Chassis
