--!strict

local RunService = game:GetService("RunService")

return function(Park, runtime)
	assert(RunService:IsRunning() and RunService:IsServer(), "Run in a local Play server")
	local fixture = Instance.new("Folder")
	fixture.Name = "ParkRideAcceptance"
	fixture.Parent = workspace
	local connection, controller
	local report = {passed = false, failures = {}, elapsed = 0, nodesPassed = 0,
		peakSpeed = 0, minSpeedAfterStart = math.huge, airborneSeconds = 0, airborneTransitions = 0,
		maxTrackOffset = 0, minBodyY = math.huge, minUp = 1, maxHeightAboveDeck = 0,
		method = "One real server-owned body on an isolated PracticePark; waypoint steering drives Chassis inputs. No rider or crash-ejection lifecycle is exercised."}
	local ok, message = xpcall(function()
		local origin = CFrame.new(310, -500, 0)
		local park = Park.build(fixture, origin)
		local profile = require(runtime.Profiles).Cart
		local Chassis = require(runtime.Chassis)
		local count = #park.loop - 1
		local first = park.loop[1]
		local body = Instance.new("Part")
		body.Name = "AcceptanceBody"
		body.Size = profile.BodySize
		body.CFrame = CFrame.lookAt(first.position + Vector3.yAxis * profile.RideHeight,
			first.position + Vector3.yAxis * profile.RideHeight + first.forward)
		body.CustomPhysicalProperties = PhysicalProperties.new(0.8, 0.15, 0, 1, 1)
		body.Parent = fixture
		body:SetNetworkOwner(nil)
		controller = Chassis.new(body, profile, {body})
		local progress = 1
		local previousGrounded = true
		local done = false
		local function node(index)
			return park.loop[(index - 1) % count + 1]
		end
		connection = RunService.PreSimulation:Connect(function(dt)
			if done then return end
			report.elapsed += dt
			if not body.Parent then table.insert(report.failures, "Body was destroyed below the fixture"); done = true; return end
			local position = body.Position
			local nearest, distance = progress, math.huge
			for index = progress, progress + 10 do
				local delta = (node(index).position - position) * Vector3.new(1, 0, 1)
				if delta.Magnitude < distance then nearest, distance = index, delta.Magnitude end
			end
			progress = nearest
			report.nodesPassed = progress - 1
			report.maxTrackOffset = math.max(report.maxTrackOffset, distance)
			local target = node(progress + 5).position
			local toTarget = (target - position) * Vector3.new(1, 0, 1)
			local forward = (body.CFrame.LookVector * Vector3.new(1, 0, 1)).Unit
			local angle = math.atan2(forward:Cross(toTarget.Unit).Y, forward:Dot(toTarget.Unit))
			local speed = (body.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude
			local desiredRate = 2 * math.max(speed, 14) * math.sin(angle) / math.max(toTarget.Magnitude, 1)
			local steer = math.clamp(-desiredRate / profile.TurnRate, -1, 1)
			if math.abs(steer) > 0.001 then steer = math.sign(steer) * (profile.SteeringDeadzone + math.abs(steer) * (1 - profile.SteeringDeadzone)) end
			local telemetry = controller:step(dt, {throttle = 1, steer = steer, brake = false, held = false, drift = false, enabled = true})
			report.peakSpeed = math.max(report.peakSpeed, telemetry.speed)
			if report.elapsed > 1.5 then report.minSpeedAfterStart = math.min(report.minSpeedAfterStart, telemetry.speed) end
			if not telemetry.grounded then report.airborneSeconds += dt end
			if previousGrounded and not telemetry.grounded then report.airborneTransitions += 1 end
			previousGrounded = telemetry.grounded
			report.minBodyY = math.min(report.minBodyY, position.Y)
			report.maxHeightAboveDeck = math.max(report.maxHeightAboveDeck, position.Y - origin.Position.Y)
			report.minUp = math.min(report.minUp, body.CFrame.UpVector.Y)
			if position.Y < origin.Position.Y then table.insert(report.failures, "Body fell below the park floor"); done = true end
			if distance > park.trackWidth / 2 then table.insert(report.failures, "Body left the pump-loop ribbon"); done = true end
			if progress > count then
				report.completedLoop = true
				report.finishSpeed = telemetry.speed
				done = true
			end
		end)
		while not done and report.elapsed < 30 do RunService.Heartbeat:Wait() end
		if not report.completedLoop then table.insert(report.failures, "Did not complete one loop within the bounded run") end
	end, debug.traceback)
	if connection then connection:Disconnect() end
	if controller then controller:destroy() end
	fixture:Destroy()
	if not ok then table.insert(report.failures, tostring(message)) end
	if report.minSpeedAfterStart == math.huge then report.minSpeedAfterStart = 0 end
	if report.minBodyY == math.huge then report.minBodyY = 0 end
	report.passed = ok and report.completedLoop == true and #report.failures == 0
	return report
end
