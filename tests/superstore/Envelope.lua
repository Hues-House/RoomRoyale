local RunService = game:GetService("RunService")
local Envelope = {}

function Envelope.run()
	local runtime = game.ReplicatedStorage.RideRuntime
	local Chassis = require(runtime.Chassis)
	local profile = require(runtime.Profiles).Cart
	local root = Instance.new("Folder")
	root.Name = "SuperstoreEnvelopeTest"
	root.Parent = workspace
	local runs, active = {}, {}
	for index, definition in ipairs({
		{ name = "empty_cruise_turn", speed = 44, load = 0, drift = false },
		{ name = "full_cruise_turn", speed = 44, load = 1, drift = false },
		{ name = "full_fast_drift", speed = 85, load = 1, drift = true },
		{ name = "full_flat_jump", speed = 44, load = 1, jump = true },
	}) do
		local origin = Vector3.new(index * 800, 1000, 0)
		local floor = Instance.new("Part")
		floor.Anchored = true
		floor.Size = Vector3.new(650, 1, 650)
		floor.Position = origin - Vector3.new(0, 0.5, 0)
		floor.Parent = root
		local body = Instance.new("Part")
		body.Size = profile.BodySize
		body.CFrame = CFrame.new(origin + Vector3.new(0, profile.RideHeight, 0))
		body.CustomPhysicalProperties = PhysicalProperties.new(0.8, 0.15, 0, 1, 1)
		body.Parent = root
		body:SetNetworkOwner(nil)
		body.AssemblyLinearVelocity = Vector3.new(0, 0, -definition.speed)
		local controller = Chassis.new(body, profile, { body })
		controller:setLoad(definition.load)
		local report = { name = definition.name, maxCenterRise = 0, firstQuarterTurnTravel = 0, firstQuarterTurnWidth = 0, firstQuarterTurnDepth = 0, peakSpeed = 0, airborneSeconds = 0, groundedAfterJump = false }
		table.insert(runs, report)
		table.insert(active, { definition = definition, body = body, controller = controller, origin = origin, report = report, last = body.Position, distance = 0, width = 0, depth = 0 })
	end
	local elapsed = 0
	local connection = RunService.PreSimulation:Connect(function(dt)
		for _, state in active do
			local d = state.definition
			state.telemetry = state.controller:step(dt, {
				throttle = 1, steer = d.jump and 0 or 1, brake = false,
				held = d.jump and elapsed >= 0.5 and elapsed < 0.9 or d.drift == true,
				enabled = true,
			})
		end
	end)
	local ok, err = pcall(function()
		while elapsed < 4 do
			local dt = RunService.Heartbeat:Wait()
			elapsed += dt
			for _, state in active do
				local body, report = state.body, state.report
				local offset = body.Position - state.origin
				report.maxCenterRise = math.max(report.maxCenterRise, offset.Y - profile.RideHeight)
				report.peakSpeed = math.max(report.peakSpeed, body.AssemblyLinearVelocity.Magnitude)
				state.distance += (body.Position - state.last).Magnitude
				state.last = body.Position
				if report.firstQuarterTurnTravel == 0 then
					state.width = math.max(state.width, math.abs(offset.X))
					state.depth = math.max(state.depth, math.abs(offset.Z))
					if body.CFrame.LookVector.Z >= 0 and not state.definition.jump then
						report.firstQuarterTurnTravel = state.distance
						report.firstQuarterTurnWidth = state.width
						report.firstQuarterTurnDepth = state.depth
					end
				end
				if elapsed > 0.9 and state.telemetry then
					if not state.telemetry.grounded then report.airborneSeconds += dt
					elseif report.airborneSeconds > 0 then report.groundedAfterJump = true end
				end
				assert(offset.Y > -1, "Body fell below floor")
			end
		end
	end)
	connection:Disconnect()
	for _, state in active do state.controller:destroy() end
	root:Destroy()
	return { passed = ok, error = if ok then nil else tostring(err), engineActual = true, method = "Server-owned unseated bodies. Initial speed seeded. Quarter turn is body heading, not path completion. No rider or cargo visual coverage.", runs = runs }
end

return Envelope
