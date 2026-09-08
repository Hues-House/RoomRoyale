--!strict

local RunService = game:GetService("RunService")

return function(runtime)
	assert(RunService:IsRunning() and RunService:IsServer(), "Run in a local Play server")
	local Chassis = require(runtime.Chassis)
	local current = require(runtime.Profiles).Cart
	local baseline = table.clone(current)
	baseline.ChargedHopSpeed = 18 * math.sqrt(1.25)
	baseline.AirGravityScale = 1
	baseline.CoastDeceleration = 3
	baseline.GripResponse, baseline.GripAcceleration = 4.2, 145
	baseline.TurnRate, baseline.SteeringResponse = 2.25, 13
	baseline.AlignmentResponse, baseline.AlignmentTorquePerMass, baseline.SupportDamping = 14, 260, 24
	local folder = Instance.new("Folder")
	folder.Name = "HandlingAcceptance"
	folder.Parent = workspace
	local floor = Instance.new("Part")
	floor.Anchored = true
	floor.Size = Vector3.new(650, 1, 650)
	floor.Position = Vector3.new(1200, -0.5, 1200)
	floor.Parent = folder
	local states, reports = {}, {}
	local scenarios = {
		{"oldJump", baseline, "jump"}, {"floatJump", current, "jump"}, {"diveJump", current, "dive"},
		{"oldCoast", baseline, "coast"}, {"coast", current, "coast"},
		{"oldTurn", baseline, "turn"}, {"turn", current, "turn"},
	}
	local elapsed = 0
	for index, scenario in scenarios do
		local body = Instance.new("Part")
		body.Name = scenario[1]
		body.Size = current.BodySize
		body.CFrame = CFrame.new(1050 + index * 40, current.RideHeight, 1200)
		body.CustomPhysicalProperties = PhysicalProperties.new(0.8, 0.15, 0, 1, 1)
		body.Parent = folder
		body:SetNetworkOwner(nil)
		local report = {apex = 0, minUp = 1, maxSlip = 0, peakSpeed = 0}
		reports[scenario[1]] = report
		table.insert(states, {body = body, controller = Chassis.new(body, scenario[2], {body}),
			kind = scenario[3], report = report, startZ = body.Position.Z, profile = scenario[2]})
	end
	local connection = RunService.PreSimulation:Connect(function(dt)
		elapsed += dt
		for _, state in states do
			local b, r = state.body, state.report
			local jumping = state.kind == "jump" or state.kind == "dive"
			if not state.started and elapsed >= 0.3 then
				state.started = true
				b.AssemblyLinearVelocity = Vector3.new(0, 0, -44)
				state.startZ = b.Position.Z
			end
			local held = jumping and elapsed >= 0.4 and elapsed < 0.85
			if state.kind == "dive" and state.launchedAt and elapsed - state.launchedAt >= 0.14 then held = true end
			local steer = if state.kind == "turn" and elapsed >= 0.4 and elapsed < 1.25 then 1 else 0
			local t = state.controller:step(dt, {throttle = if state.kind == "coast" then 0 else 1,
				steer = steer, brake = false, held = held, enabled = true})
			if t.jumpSpeed > 0 then state.launchedAt = elapsed; state.launchY = b.Position.Y end
			if state.launchedAt and not r.airtime then
				r.apex = math.max(r.apex, b.Position.Y - state.launchY)
				if t.grounded and elapsed > state.launchedAt + 0.1 then
					r.airtime = elapsed - state.launchedAt
					r.landingSpeed = (b.AssemblyLinearVelocity * Vector3.new(1,0,1)).Magnitude
				end
			end
			if not r.speedAfterTwoSeconds and elapsed >= 2.3 then
				r.speedAfterTwoSeconds = t.speed
				r.distanceAfterTwoSeconds = (b.Position.Z - state.startZ) * -1
			end
			r.minUp = math.min(r.minUp, b.CFrame.UpVector.Y)
			r.maxSlip = math.max(r.maxSlip, math.abs(t.slip))
			r.peakSpeed = math.max(r.peakSpeed, t.speed)
		end
	end)
	while elapsed < 3 do RunService.Heartbeat:Wait() end
	connection:Disconnect()
	for _, state in states do state.controller:destroy() end
	folder:Destroy()
	local ratio = reports.floatJump.apex / reports.oldJump.apex
	return {passed = ratio >= 3 and ratio <= 4 and reports.diveJump.airtime ~= nil and reports.floatJump.airtime ~= nil and reports.diveJump.airtime < reports.floatJump.airtime
		and reports.coast.speedAfterTwoSeconds < reports.oldCoast.speedAfterTwoSeconds - 10
		and reports.turn.maxSlip < reports.oldTurn.maxSlip and reports.turn.minUp > 0.95,
		jumpHeightRatio = ratio, runs = reports,
		method = "Real server-owned Roblox assemblies driven by the current Chassis; baseline profile restored in parallel"}
end
