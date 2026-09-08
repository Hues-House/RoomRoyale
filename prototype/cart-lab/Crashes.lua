--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Crashes = {}
Crashes.__index = Crashes

local RAGDOLL_SECONDS = 1.6
local SHIELD_SECONDS = 5
local WALL_CONTACT_SECONDS = 0.3
local APPROACH_SECONDS = 0.1
local CONTACT_MARGIN = Vector3.new(0.8, 0.2, 0.8)

local function diagnostic(track, stage: string, detail: string)
	if track.cart:GetAttribute("DebugCrashes") ~= true then return end
	track.cart:SetAttribute("CrashDebug", string.format("%s t=%.4f %s", stage, workspace:GetServerTimeNow(), detail))
end

local function horizontal(vector: Vector3): Vector3
	return vector * Vector3.new(1, 0, 1)
end

local function directionOr(vector: Vector3, fallback: Vector3): Vector3
	return if vector.Magnitude > 0.001 then vector.Unit else fallback
end

local function restoreRig(rig)
	for _, instance in ipairs(rig.created) do instance:Destroy() end
	for motor, enabled in pairs(rig.motors) do
		if motor.Parent then motor.Enabled = enabled end
	end
	for joint, saved in pairs(rig.animationJoints) do
		if joint.Parent then
			joint.IsKinematic = saved.kinematic
			joint.Enabled = saved.enabled
		end
	end
	for socket, enabled in pairs(rig.sockets) do
		if socket.Parent then socket.Enabled = enabled end
	end
	for part, saved in pairs(rig.parts) do
		if part.Parent then
			part.CanCollide = saved.collide
			part.Massless = saved.massless
		end
	end
	local humanoid = rig.humanoid
	if humanoid.Parent then
		humanoid.RequiresNeck = rig.requiresNeck
		humanoid.BreakJointsOnDeath = rig.breakJointsOnDeath
		humanoid.AutoRotate = rig.autoRotate
		humanoid.PlatformStand = rig.platformStand
		humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, rig.gettingUp)
		if humanoid.Health > 0 then humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end
	end
	if rig.seat.Parent then rig.seat.Disabled = rig.seatDisabled end
end

local function ragdoll(character: Model, humanoid: Humanoid, root: BasePart, seat: Seat, launch: Vector3)
	local rig = {
		humanoid = humanoid, seat = seat, seatDisabled = seat.Disabled,
		requiresNeck = humanoid.RequiresNeck, breakJointsOnDeath = humanoid.BreakJointsOnDeath,
		autoRotate = humanoid.AutoRotate, platformStand = humanoid.PlatformStand,
		gettingUp = humanoid:GetStateEnabled(Enum.HumanoidStateType.GettingUp),
		motors = {}, animationJoints = {}, sockets = {}, parts = {}, created = {},
	}
	seat.Disabled = true
	humanoid.RequiresNeck = false
	humanoid.BreakJointsOnDeath = false
	humanoid.AutoRotate = false
	humanoid.PlatformStand = true
	humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
	humanoid.Sit = false
	local seatWeld = seat:FindFirstChild("SeatWeld")
	if seatWeld then seatWeld:Destroy() end
	for _, instance in ipairs(character:GetDescendants()) do
		if instance:IsA("Motor6D") and instance.Part0 and instance.Part1 and instance.Part0 ~= root and instance.Part1 ~= root then
			local attachment0 = Instance.new("Attachment")
			attachment0.Name = "LabRagdoll0"
			attachment0.CFrame = instance.C0 * instance.Transform
			attachment0.Parent = instance.Part0
			local attachment1 = Instance.new("Attachment")
			attachment1.Name = "LabRagdoll1"
			attachment1.CFrame = instance.C1
			attachment1.Parent = instance.Part1
			local socket = Instance.new("BallSocketConstraint")
			socket.Name = "LabRagdollJoint"
			socket.Attachment0, socket.Attachment1 = attachment0, attachment1
			socket.LimitsEnabled = true
			socket.UpperAngle = if instance.Name == "Neck" then 35 else 65
			socket.TwistLimitsEnabled = true
			socket.TwistLowerAngle, socket.TwistUpperAngle = -35, 35
			socket.Parent = instance.Part0
			local noCollision = Instance.new("NoCollisionConstraint")
			noCollision.Part0, noCollision.Part1 = instance.Part0, instance.Part1
			noCollision.Parent = instance.Part0
			for _, created in ipairs({attachment0, attachment1, socket, noCollision}) do table.insert(rig.created, created) end
			rig.motors[instance] = instance.Enabled
			instance.Enabled = false
		elseif instance:IsA("AnimationConstraint") and instance.Attachment0 and instance.Attachment1 then
			local part0 = instance.Attachment0:FindFirstAncestorWhichIsA("BasePart")
			local part1 = instance.Attachment1:FindFirstAncestorWhichIsA("BasePart")
			if not part0 or not part1 or part0 == root or part1 == root then continue end
			local socket = nil
			for _, candidate in ipairs(character:GetDescendants()) do
				if candidate:IsA("BallSocketConstraint") and candidate.Attachment0 == instance.Attachment0 and candidate.Attachment1 == instance.Attachment1 then
					socket = candidate
					break
				end
			end
			if socket then
				rig.sockets[socket] = socket.Enabled
				socket.Enabled = true
			else
				socket = Instance.new("BallSocketConstraint")
				socket.Name = "LabRagdollJoint"
				socket.Attachment0, socket.Attachment1 = instance.Attachment0, instance.Attachment1
				socket.LimitsEnabled = true
				socket.UpperAngle = if instance.Name == "Neck" then 35 else 65
				socket.TwistLimitsEnabled = true
				socket.TwistLowerAngle, socket.TwistUpperAngle = -35, 35
				socket.Parent = part0
				table.insert(rig.created, socket)
			end
			rig.animationJoints[instance] = {enabled = instance.Enabled, kinematic = instance.IsKinematic}
			instance.IsKinematic = false
			instance.Enabled = false
		elseif instance:IsA("BasePart") then
			rig.parts[instance] = {collide = instance.CanCollide, massless = instance.Massless}
			instance.CanCollide = instance.Parent == character and instance ~= root
			if instance.Parent == character then instance.Massless = false end
		end
	end
	humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	for part in pairs(rig.parts) do
		if part.Parent == character and not part.Anchored then
			part:SetNetworkOwner(nil)
			part.AssemblyLinearVelocity = launch
		end
	end
	return rig
end

function Crashes.new(onRiderPhase)
	local self = setmetatable({tracks = {}, byCart = {}, onRiderPhase = onRiderPhase}, Crashes)
	self.connection = RunService.Heartbeat:Connect(function() self:step() end)
	return self
end

function Crashes:isCurrent(track): boolean
	return self.tracks[track.player] == track and track.player.Parent == Players
		and track.player.Character == track.character and track.cart:IsDescendantOf(workspace)
end

function Crashes:cancel(player: Player)
	local track = self.tracks[player]
	if not track then return end
	track.epoch += 1
	track.sample = nil
	track.contact = nil
	if track.rig then
		restoreRig(track.rig)
		track.rig = nil
	end
	if track.parkedBody and track.parkedBody.Parent then track.parkedBody.Anchored = false end
	track.parkedBody = nil
	if track.cart.Parent then
		track.cart:SetAttribute("Ragdolled", false)
		track.cart:SetAttribute("Ejected", false)
	end
end

function Crashes:forget(player: Player)
	local track = self.tracks[player]
	if not track then return end
	self:cancel(player)
	if track.shield then track.shield:Destroy() end
	self.byCart[track.cart] = nil
	self.tracks[player] = nil
end

function Crashes:track(player: Player, cart: Model, character: Model)
	self:forget(player)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {cart, character}
	params.RespectCanCollide = true
	local track = {player = player, cart = cart, character = character, epoch = 0, sample = nil, contact = nil, rig = nil, shield = nil, params = params}
	self.tracks[player] = track
	self.byCart[cart] = track
end

local function findRecovery(track, origin: Vector3, away: Vector3): CFrame?
	local overlaps = OverlapParams.new()
	overlaps.FilterType = Enum.RaycastFilterType.Exclude
	overlaps.FilterDescendantsInstances = {track.cart, track.character}
	overlaps.RespectCanCollide = true
	overlaps.MaxParts = 1
	for _, distance in ipairs({8, 12, 16}) do
		local position = origin + away * distance
		local ground = workspace:Raycast(position + Vector3.new(0, 12, 0), Vector3.new(0, -60, 0), track.params)
		if not ground or ground.Normal.Y < 0.65 then continue end
		position = Vector3.new(position.X, ground.Position.Y + 2.5, position.Z)
		local candidate = CFrame.lookAt(position, position + away)
		local occupied = workspace:GetPartBoundsInBox(candidate * CFrame.new(0, 3.5, 0), Vector3.new(8, 8, 11), overlaps)
		if #occupied == 0 then return candidate end
	end
	return nil
end

function Crashes:eject(track, away: Vector3, kind: string, launchDirection: Vector3?)
	if not self:isCurrent(track) then diagnostic(track, "Reject", "stale rider or cart"); return end
	if track.rig then diagnostic(track, "Reject", "ragdoll already active"); return end
	local protection = (track.cart:GetAttribute("ProtectedUntil") or 0) - workspace:GetServerTimeNow()
	if protection > 0 then diagnostic(track, "Reject", string.format("shield remaining=%.4f", protection)); return end
	local humanoid = track.character:FindFirstChildOfClass("Humanoid")
	local root = track.character:FindFirstChild("HumanoidRootPart")
	local seat = track.cart:FindFirstChild("DriverSeat")
	local body = track.cart.PrimaryPart
	if not (humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") and seat and seat:IsA("Seat") and seat.Occupant == humanoid and body) then
		diagnostic(track, "Reject", string.format("health=%s root=%s seat=%s occupied=%s body=%s", tostring(humanoid and humanoid.Health), tostring(root ~= nil), tostring(seat ~= nil), tostring(seat and seat:IsA("Seat") and seat.Occupant == humanoid), tostring(body ~= nil)))
		return
	end
	if not self.onRiderPhase(track.player, track.cart, track.character, "Eject", nil) then diagnostic(track, "Reject", "owner callback rejected rider"); return end
	diagnostic(track, "Eject", kind)
	track.epoch += 1
	local epoch = track.epoch
	local push = directionOr(horizontal(away), -horizontal(body.CFrame.LookVector))
	local launch = directionOr(horizontal(launchDirection or push), push)
	track.cart:SetAttribute("Ragdolled", true)
	track.cart:SetAttribute("Ejected", true)
	track.cart:SetAttribute("ProtectedUntil", workspace:GetServerTimeNow() + RAGDOLL_SECONDS + SHIELD_SECONDS)
	track.cart:SetAttribute("LastCrashKind", kind)
	track.cart:SetAttribute("CrashCount", (track.cart:GetAttribute("CrashCount") or 0) + 1)
	track.rig = ragdoll(track.character, humanoid, root, seat, launch * 32 + Vector3.new(0, 70, 0))
	-- Suspension belongs to the rider's client. Keep the empty cart at ride height during recovery.
	body.AssemblyLinearVelocity = Vector3.zero
	body.AssemblyAngularVelocity = Vector3.zero
	body.Anchored = true
	track.parkedBody = body
	task.delay(RAGDOLL_SECONDS, function()
		if not self:isCurrent(track) or track.epoch ~= epoch then return end
		if track.rig then restoreRig(track.rig); track.rig = nil end
		track.cart:SetAttribute("Ragdolled", false)
		track.cart:SetAttribute("Ejected", false)
		track.sample = nil
		track.contact = nil
		if humanoid.Health <= 0 then return end
		track.cart:SetAttribute("ProtectedUntil", workspace:GetServerTimeNow() + SHIELD_SECONDS)
		local shield = Instance.new("Highlight")
		shield.Name = "LabRecoveryShield"
		shield.Adornee = track.cart
		shield.FillColor = Color3.fromRGB(115, 234, 209)
		shield.FillTransparency = 0.8
		shield.OutlineColor = Color3.fromRGB(186, 255, 240)
		shield.OutlineTransparency = 0.15
		shield.DepthMode = Enum.HighlightDepthMode.Occluded
		shield.Parent = track.cart
		track.shield = shield
		local recovery = findRecovery(track, body.Position, push)
		body.Anchored = false
		track.parkedBody = nil
		self.onRiderPhase(track.player, track.cart, track.character, "Recover", recovery)
	end)
end

function Crashes:ram(attacker, victim, attackerSample, victimSample): boolean
	if not self:isCurrent(victim) or victim.rig then return false end
	local a, b = attackerSample, victimSample
	if not a or not b then return false end
	local toward = directionOr(horizontal(b.cf.Position - a.cf.Position), Vector3.zero)
	if toward.Magnitude < 0.5 then return false end
	local closing = (a.velocity - b.velocity):Dot(toward)
	local attackerApproach = a.velocity:Dot(toward)
	local victimApproach = -b.velocity:Dot(toward)
	if closing >= 30 and a.cf.LookVector:Dot(toward) > 0.75 and attackerApproach >= victimApproach + 6 then
		self:eject(victim, toward, "PerfectRam")
		return true
	end
	return false
end

function Crashes:step()
	local now = workspace:GetServerTimeNow()
	local nextSamples = {}
	for _, track in pairs(self.tracks) do
		if not self:isCurrent(track) then continue end
		local debugging = track.cart:GetAttribute("DebugCrashes") == true
		if track.shield and (track.cart:GetAttribute("ProtectedUntil") or 0) <= now then
			track.shield:Destroy()
			track.shield = nil
		end
		local body = track.cart.PrimaryPart
		local humanoid = track.character:FindFirstChildOfClass("Humanoid")
		local seat = track.cart:FindFirstChild("DriverSeat")
		if not body or not humanoid or not seat or not seat:IsA("Seat") or seat.Occupant ~= humanoid or track.rig then
			if debugging then diagnostic(track, "Inactive", string.format("body=%s humanoid=%s seated=%s ragdoll=%s", tostring(body ~= nil), tostring(humanoid ~= nil), tostring(seat and seat:IsA("Seat") and seat.Occupant == humanoid), tostring(track.rig ~= nil))) end
			track.sample = nil
			track.contact = nil
			continue
		end
		local sample = {cf = body.CFrame, velocity = body.AssemblyLinearVelocity, reset = track.cart:GetAttribute("ResetVersion")}
		nextSamples[track] = sample
		local previous = track.sample
		if not previous or previous.reset ~= sample.reset then
			if debugging then diagnostic(track, "Rebase", "first sample or ResetVersion changed") end
			track.contact = nil
			continue
		end
		local delta = sample.cf.Position - previous.cf.Position
		if delta.Magnitude > 60 or (previous.velocity.Magnitude < 20 and not track.contact) then
			if debugging then diagnostic(track, "Skip", string.format("delta=%.3f priorSpeed=%.3f", delta.Magnitude, previous.velocity.Magnitude)) end
			track.contact = nil
			continue
		end
		local sweep = delta + directionOr(previous.velocity, Vector3.zero) * math.clamp(previous.velocity.Magnitude * APPROACH_SECONDS, 0.25, 6)
		local result = if sweep.Magnitude >= 0.01 then workspace:Blockcast(previous.cf, body.Size * 0.98, sweep, track.params) else nil
		local hit = if result then {Instance = result.Instance, Normal = result.Normal, Position = result.Position} else nil
		local overlapCount = -1
		local contactAge = if track.contact then now - track.contact.startedAt else -1
		if not hit then
			local contact = track.contact
			if contact and contact.part.Parent and now - contact.startedAt <= WALL_CONTACT_SECONDS then
				local overlaps = workspace:GetPartBoundsInBox(sample.cf, body.Size + CONTACT_MARGIN, contact.overlaps)
				overlapCount = #overlaps
				if #overlaps > 0 then
					hit = {Instance = contact.part, Normal = contact.normal, Position = contact.position}
				end
			end
		end
		local debugFrame = if debugging then string.format("fresh=%s overlap=%d age=%.4f priorCF=[%s] currentCF=[%s] priorV=[%s] currentV=[%s]", tostring(result ~= nil), overlapCount, contactAge, tostring(previous.cf), tostring(sample.cf), tostring(previous.velocity), tostring(sample.velocity)) else ""
		if debugging and track.contact then
			local cachedPart = track.contact.part
			debugFrame ..= string.format(" cached=%s collidable=%s queryable=%s cachedNormal=[%s]", cachedPart:GetFullName(), tostring(cachedPart:IsA("BasePart") and cachedPart.CanCollide), tostring(cachedPart:IsA("BasePart") and cachedPart.CanQuery), tostring(track.contact.normal))
		end
		if not hit or hit.Normal.Y > 0.55 then
			if debugging then diagnostic(track, if hit then "Ground" else "Separated", debugFrame) end
			track.contact = nil
			continue
		end
		local hitCart = hit.Instance:FindFirstAncestorOfClass("Model")
		local victim = hitCart and self.byCart[hitCart]
		local otherVelocity = if hit.Instance:IsA("BasePart") then hit.Instance:GetVelocityAtPosition(hit.Position) else Vector3.zero
		local incoming = math.max(0, -(previous.velocity - otherVelocity):Dot(hit.Normal))
		local remaining = math.max(0, -(sample.velocity - otherVelocity):Dot(hit.Normal))
		local contact = track.contact
		if not contact or contact.part ~= hit.Instance or contact.normal:Dot(hit.Normal) < 0.94 or now - contact.startedAt > WALL_CONTACT_SECONDS then
			local overlaps = OverlapParams.new()
			overlaps.FilterType = Enum.RaycastFilterType.Include
			overlaps.FilterDescendantsInstances = {hit.Instance}
			overlaps.RespectCanCollide = true
			overlaps.MaxParts = 1
			contact = {part = hit.Instance, normal = hit.Normal, position = hit.Position, overlaps = overlaps, startedAt = now, peak = incoming, velocity = previous.velocity, triggered = false,
				attackerSample = previous, victimSample = victim and victim.sample}
			track.contact = contact
		elseif incoming > contact.peak then
			contact.peak = incoming
			contact.velocity = previous.velocity
			contact.attackerSample = previous
			contact.victimSample = victim and victim.sample
		end
		if result then contact.position = result.Position end
		if debugging then diagnostic(track, "Wall", debugFrame .. string.format(" part=%s normal=[%s] peak=%.3f remaining=%.3f loss=%.3f fired=%s", hit.Instance:GetFullName(), tostring(hit.Normal), contact.peak, remaining, contact.peak - remaining, tostring(contact.triggered))) end
		-- Constraint deceleration can span several physics frames of one wall impact.
		local touching = if overlapCount >= 0 then overlapCount > 0
			else #workspace:GetPartBoundsInBox(sample.cf, body.Size + CONTACT_MARGIN, contact.overlaps) > 0
		if victim and not contact.triggered and touching then
			contact.triggered = self:ram(track, victim, contact.attackerSample, contact.victimSample)
		elseif not victim and not contact.triggered and touching and contact.peak >= 32 and contact.peak - remaining >= 12 then
			contact.triggered = true
			self:eject(track, hit.Normal, "HardWall", contact.velocity)
		end
	end
	for track, sample in pairs(nextSamples) do
		if self:isCurrent(track) and not track.rig then track.sample = sample end
	end
end

return Crashes
