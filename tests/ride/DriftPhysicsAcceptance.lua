--!strict

local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local DriftPhysicsAcceptance = {}

local function finite(value: number): boolean
	return value == value and math.abs(value) < math.huge
end

function DriftPhysicsAcceptance.run(runtimeFolder: Instance)
	local result = { passed = false, duration = 0, errors = {}, runs = {} }
	local temporary: Folder? = nil
	local connection: RBXScriptConnection? = nil
	local states = {}
	local elapsed = 0
	local holdSeconds = 7
	local duration = 9

	local ok, err = xpcall(function()
		assert(RunService:IsServer() and RunService:IsRunning(), "Run this check in a running server simulation")
		local chassisModule = runtimeFolder:FindFirstChild("Chassis")
		local profilesModule = runtimeFolder:FindFirstChild("Profiles")
		assert(chassisModule and chassisModule:IsA("ModuleScript"), "Missing Chassis ModuleScript")
		assert(profilesModule and profilesModule:IsA("ModuleScript"), "Missing Profiles ModuleScript")
		local Chassis = require(chassisModule)
		local profile = require(profilesModule).Cart
		local folder = Instance.new("Folder")
		folder.Name = "RideDriftAcceptance_" .. HttpService:GenerateGUID(false)
		folder.Parent = workspace
		temporary = folder

		local cases = {
			{ name = "cruise_empty", speed = 44, load = 0 },
			{ name = "downhill_momentum_full", speed = 85, load = 1 },
			{ name = "near_assist_ceiling_full", speed = 115, load = 1 },
			{ name = "above_assist_ceiling_empty", speed = 135, load = 0 },
		}
		for index, case in ipairs(cases) do
			local center = Vector3.new((index - 1) * 1400, 2000, 0)
			local floor = Instance.new("Part")
			floor.Name = case.name .. "_floor"
			floor.Size = Vector3.new(1200, 1, 1200)
			floor.Position = center - Vector3.new(0, 0.5, 0)
			floor.Anchored = true
			floor.Parent = folder

			local body = Instance.new("Part")
			body.Name = case.name
			body.Size = Vector3.new(5, 1, 7)
			body.CFrame = CFrame.new(center + Vector3.new(0, profile.RideHeight, 0))
			body.CustomPhysicalProperties = PhysicalProperties.new(0.8, 0.15, 0, 1, 1)
			body.Parent = folder
			body:SetNetworkOwner(nil)
			local controller = Chassis.new(body, profile, { body })
			controller:setLoad(case.load)
			-- This isolates inherited speed from terrain changes; the course check covers the hill itself.
			body.AssemblyLinearVelocity = Vector3.new(0, 0, -case.speed)
			local report = {
				name = case.name, load = case.load, entrySpeed = case.speed,
				passed = false, failures = {}, minHeldSpeed = case.speed,
				maxHeldSpeed = case.speed, releaseSpeed = 0, peakBoostSpeed = 0,
				lateHeldMin = math.huge, lateHeldMax = 0, maxSlipDegrees = 0,
				maxDriftCharge = 0, driftSpeedAdded = 0, boostSpeedAdded = 0,
				groundedDriftSeconds = 0, boostObserved = false,
			}
			table.insert(result.runs, report)
			table.insert(states, { body = body, controller = controller, report = report, telemetry = nil })
		end

		connection = RunService.PreSimulation:Connect(function(dt: number)
			for _, state in ipairs(states) do
				local success, failure = pcall(function()
					state.telemetry = state.controller:step(dt, {
						throttle = 1, steer = if elapsed < holdSeconds then 1 else 0,
						brake = false, held = elapsed < holdSeconds, enabled = true,
					})
				end)
				if not success then
					table.insert(result.errors, tostring(failure))
				end
			end
		end)

		while elapsed < duration and #result.errors == 0 do
			local dt = RunService.Heartbeat:Wait()
			elapsed += dt
			for _, state in ipairs(states) do
				local report = state.report
				local velocity = state.body.AssemblyLinearVelocity
				local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
				assert(finite(speed) and finite(state.body.Position.Y), report.name .. ": non-finite physics state")
				assert(state.body.Position.Y >= 1999, report.name .. ": fell through the test floor")
				local telemetry = state.telemetry
				if not telemetry then continue end
				report.maxSlipDegrees = math.max(report.maxSlipDegrees, math.deg(math.abs(telemetry.slip)))
				report.maxDriftCharge = math.max(report.maxDriftCharge, telemetry.driftCharge)
				report.driftSpeedAdded = math.max(report.driftSpeedAdded, telemetry.driftSpeedAdded or 0)
				report.boostSpeedAdded = math.max(report.boostSpeedAdded, telemetry.boostSpeedAdded or 0)
				if elapsed < holdSeconds then
					report.minHeldSpeed = math.min(report.minHeldSpeed, speed)
					report.maxHeldSpeed = math.max(report.maxHeldSpeed, speed)
					report.releaseSpeed = speed
					if telemetry.grounded and telemetry.mode == "Drift" then
						report.groundedDriftSeconds += dt
					end
					if elapsed >= 4 then
						report.lateHeldMin = math.min(report.lateHeldMin, speed)
						report.lateHeldMax = math.max(report.lateHeldMax, speed)
					end
				elseif telemetry.boosting then
					report.boostObserved = true
					report.peakBoostSpeed = math.max(report.peakBoostSpeed, speed)
				end
			end
		end

		for _, report in ipairs(result.runs) do
			local function check(condition: boolean, message: string)
				if not condition then table.insert(report.failures, message) end
			end
			check(report.groundedDriftSeconds >= 4, "Did not sustain a grounded drift")
			check(report.minHeldSpeed >= report.entrySpeed - 2, "Holding drift lost more than 2 studs/s of incoming speed")
			check(report.lateHeldMax - report.lateHeldMin <= 2, "Sustained drift did not settle after its additive budget")
			check(report.driftSpeedAdded <= profile.DriftMaxSpeedGain + 0.01, "Drift exceeded its additive budget")
			check(report.boostSpeedAdded <= profile.BoostMaxSpeedGain + 0.01, "Release boost exceeded its additive budget")
			check(report.boostObserved, "A charged drift release did not boost")
			local room = math.max(profile.ArcadeSpeedCeiling - report.entrySpeed, 0)
			check(report.releaseSpeed >= report.entrySpeed + math.min(profile.DriftMaxSpeedGain, room) - 2, "Held drift did not add its available speed gain")
			if report.entrySpeed < 100 then
				check(report.peakBoostSpeed >= report.releaseSpeed + 5, "Release boost did not add speed to the incoming drift")
			elseif report.entrySpeed > profile.ArcadeSpeedCeiling then
				check(report.driftSpeedAdded == 0 and report.boostSpeedAdded == 0, "Assists added speed above their ceiling")
			else
				check(math.max(report.maxHeldSpeed, report.peakBoostSpeed) <= profile.ArcadeSpeedCeiling + 2, "Assists accelerated beyond their ceiling")
			end
			report.passed = #report.failures == 0
			if report.lateHeldMin == math.huge then report.lateHeldMin = 0 end
		end
	end, debug.traceback)

	if connection then connection:Disconnect() end
	for _, state in ipairs(states) do
		local success, failure = pcall(function() state.controller:destroy() end)
		if not success then table.insert(result.errors, tostring(failure)) end
		if state.report.lateHeldMin == math.huge then state.report.lateHeldMin = 0 end
	end
	if temporary then temporary:Destroy() end
	if not ok then table.insert(result.errors, tostring(err)) end
	result.duration = elapsed
	result.passed = ok and #result.errors == 0 and #result.runs == 4
	for _, report in ipairs(result.runs) do result.passed = result.passed and report.passed end
	return result
end

return DriftPhysicsAcceptance
