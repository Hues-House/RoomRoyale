--!strict

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Acceptance = {}

function Acceptance.run()
	assert(RunService:IsRunning() and RunService:IsServer(), "Run in an isolated local Play server")
	local runtime = ReplicatedStorage:WaitForChild("RideRuntime")
	local Chassis = require(runtime.Chassis)
	local CameraDirection = require(runtime.CameraDirection)
	local profile = require(runtime.Profiles).Cart
	local folder = Instance.new("Folder")
	folder.Name = "CartRefinementAcceptance"
	folder.Parent = workspace
	local floor = Instance.new("Part")
	floor.Name = "IsolatedFloor"
	floor.Anchored = true
	floor.Size = Vector3.new(2048, 1, 2048)
	floor.Position = Vector3.new(6000, 99.5, 6000)
	floor.Parent = folder
	local states, runs, checks = {}, {}, {}
	local function add(name, kind, load, x, z, yaw, pitch)
		local body = Instance.new("Part")
		body.Name = name
		body.Size = profile.BodySize
		body.CanCollide, body.CanTouch = false, false
		body.CFrame = CFrame.new(5300 + #states * 80, 100 + profile.RideHeight, 6000)
		body.Parent = folder
		body:SetNetworkOwner(nil)
		local controller = Chassis.new(body, profile, {})
		controller:setLoad(load)
		local camera = CFrame.Angles(0, math.rad(yaw or 0), 0) * CFrame.Angles(math.rad(pitch or 0), 0, 0)
		local look = camera.LookVector
		local horizontal = Vector3.new(look.X, 0, look.Z).Unit
		local desired = (horizontal:Cross(Vector3.yAxis) * (x or 0) - horizontal * (z or -1)).Unit
		local report = {load = load, apex = 0, jumpSpeed = 0, maxSpeed = 0, maxUnintendedJump = 0,
			minUp = 1, drifted = false, initialSpeed = 0, jumpCount = 0, expectedDriftHops = 0}
		runs[name] = report
		table.insert(states, {body = body, controller = controller, name = name, kind = kind,
			x = x or 0, z = z or -1, camera = camera, desired = desired, report = report})
	end
	for _, load in {0, 1} do
		local suffix = if load == 0 then "Empty" else "Full"
		add("accelerate" .. suffix, "accelerate", load)
		add("brake" .. suffix, "brake", load)
		add("jump" .. suffix, "jump", load)
	end
	add("forward", "camera", 0, 0, -1, 0)
	add("rightHeading", "camera", 0, 0, -1, -90)
	add("rearHeading", "camera", 0, 0, -1, 180)
	add("leftHeading", "camera", 0, 0, -1, 90)
	add("frontDiagonal", "camera", 0, 1, -1, 0)
	add("rearDiagonalSD", "camera", 0, 1, 1, 0)
	add("reverse", "camera", 0, 0, 1, 0)
	add("steepPitch", "camera", 0, 0, -1, -90, 89.9)
	add("noInputCamera", "idle", 0, 0, 0, 0)
	add("explicitDrift", "drift", 0)
	add("turningChargedJump", "turningJump", 0)
	local elapsed, failure = 0, nil
	local connection
	connection = RunService.PreSimulation:Connect(function(dt)
		local ok, message = xpcall(function()
			elapsed += dt
			for _, state in states do
				local body, report = state.body, state.report
				local input = {throttle = 0, steer = 0, brake = false, held = false, drift = false, enabled = true}
				if elapsed >= 1 then
					if not state.started then
						state.started = elapsed
						body.AssemblyLinearVelocity = if state.kind == "brake" then Vector3.new(0, 0, -40) else Vector3.zero
						body.AssemblyAngularVelocity = Vector3.zero
						state.start = body.Position
						report.initialSpeed = body.AssemblyLinearVelocity.Magnitude
					end
					local age = elapsed - state.started
					if state.kind == "accelerate" then
						input.throttle = 1
					elseif state.kind == "brake" then
						input.brake = true
					elseif state.kind == "jump" then
						input.held = age >= 0.1 and age < 0.7
					elseif state.kind == "drift" then
						input.throttle = 1
						input.drift = age >= 0.9 and age < 1.8
						input.steer = if input.drift then 0.7 else 0
					elseif state.kind == "turningJump" then
						local look = CFrame.Angles(0, math.min(math.max(age - 0.7, 0), 1.3), 0).LookVector
						local forward = body.CFrame.LookVector
						local command = CameraDirection.resolve(0, -1, look.X, look.Z, forward.X, forward.Z, 0.15)
						input.throttle, input.steer = command.throttle, command.steer
						input.held = age >= 1.1 and age < 1.7
					elseif state.kind == "camera" or state.kind == "idle" then
						local look = if state.kind == "idle" then CFrame.Angles(0, age * 2, 0).LookVector else state.camera.LookVector
						local forward = body.CFrame.LookVector
						local command = CameraDirection.resolve(state.x, state.z, look.X, look.Z, forward.X, forward.Z, 0.15)
						input.throttle, input.steer = command.throttle, command.steer
					end
				end
				local telemetry = state.controller:step(dt, input)
				report.minUp = math.min(report.minUp, body.CFrame.UpVector.Y)
				report.drifted = report.drifted or telemetry.drifting
				if telemetry.jumpSpeed > 0 then
					report.jumpCount += 1
					local expectedDriftHop = state.kind == "drift" and input.drift and not state.previousDrift
						and telemetry.jumpSpeed == profile.HopSpeed
					if expectedDriftHop then
						report.expectedDriftHops += 1
					elseif state.kind ~= "jump" and state.kind ~= "turningJump" then
						report.maxUnintendedJump = math.max(report.maxUnintendedJump, telemetry.jumpSpeed)
					end
				end
				state.previousDrift = input.drift
				if not state.started then continue end
				local age = elapsed - state.started
				local speed = (body.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude
				report.maxSpeed = math.max(report.maxSpeed, speed)
				if state.kind == "accelerate" and not report.secondsTo40 and speed >= 40 then report.secondsTo40 = age end
				if state.kind == "brake" and not report.stopSeconds and speed <= 0.25 then
					report.stopSeconds = age
					report.stopDistance = (body.Position - state.start).Magnitude
				end
				if telemetry.jumpSpeed > 0 then
					state.launchY, state.launchedAt = body.Position.Y, elapsed
					report.jumpSpeed = telemetry.jumpSpeed
				end
				if state.launchY then
					report.apex = math.max(report.apex, body.Position.Y - state.launchY)
					if telemetry.grounded and elapsed - state.launchedAt > 0.1 then report.landed = true end
				end
				if state.kind == "camera" then
					local expected = state.desired * (if state.z > 0 then -1 else 1)
					report.headingErrorDegrees = math.deg(math.acos(math.clamp(body.CFrame.LookVector:Dot(expected), -1, 1)))
					report.travelAlignment = if speed > 1 then body.AssemblyLinearVelocity.Unit:Dot(state.desired) else -1
					report.finalSpeed = speed
				elseif state.kind == "idle" then
					report.distance = (body.Position - state.start).Magnitude
				end
			end
		end, debug.traceback)
		if not ok then failure = message end
	end)
	while elapsed < 10 and not failure do RunService.Heartbeat:Wait() end
	connection:Disconnect()
	for _, state in states do state.controller:destroy() end
	folder:Destroy()
	if failure then return {passed = false, error = failure, runs = runs} end
	local empty, full = runs.accelerateEmpty, runs.accelerateFull
	checks.slowerLoadedAcceleration = empty.secondsTo40 ~= nil and full.secondsTo40 ~= nil
		and full.secondsTo40 / empty.secondsTo40 > 1.2 and full.secondsTo40 / empty.secondsTo40 < 1.8
	empty, full = runs.brakeEmpty, runs.brakeFull
	checks.equalBrakeStart = math.abs(empty.initialSpeed - 40) < 0.01 and math.abs(full.initialSpeed - 40) < 0.01
	checks.longerLoadedBraking = empty.stopDistance ~= nil and full.stopDistance ~= nil
		and empty.stopDistance > 1 and full.stopDistance / empty.stopDistance > 1.15 and full.stopDistance / empty.stopDistance < 1.65
	empty, full = runs.jumpEmpty, runs.jumpFull
	checks.sameChargedJump = empty.jumpSpeed == profile.ChargedHopSpeed and full.jumpSpeed == profile.ChargedHopSpeed
		and empty.apex > 2 and math.abs(full.apex / empty.apex - 1) < 0.08 and empty.landed == true and full.landed == true
	for _, state in states do
		local report = state.report
		checks[state.name .. "Stable"] = report.minUp > 0.95 and (state.kind == "drift" or not report.drifted) and report.maxUnintendedJump == 0
		if state.kind == "camera" then
			checks[state.name .. "Converged"] = report.headingErrorDegrees < 12 and report.travelAlignment > 0.9 and report.finalSpeed > 8
		end
	end
	checks.noInputDoesNotDrive = runs.noInputCamera.maxSpeed < 0.1 and runs.noInputCamera.distance < 0.1
	checks.explicitDriftReached = runs.explicitDrift.drifted
	checks.singleDriftEntryHop = runs.explicitDrift.jumpCount == 1 and runs.explicitDrift.expectedDriftHops == 1
	checks.chargeSurvivesCameraTurn = runs.turningChargedJump.jumpSpeed == profile.ChargedHopSpeed
		and runs.turningChargedJump.apex > 2 and runs.turningChargedJump.landed == true and not runs.turningChargedJump.drifted
	local passed = true
	for _, ok in checks do if not ok then passed = false end end
	return {passed = passed, checks = checks, runs = runs, duration = elapsed,
		method = "Parallel server-owned Chassis assemblies on isolated flat support; real physics with synthetic camera headings and actions"}
end

return Acceptance
