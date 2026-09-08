--!strict

local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local PhysicsAcceptance = {}
local TIMEOUT_SECONDS = 20

local function finite(value: number): boolean
	return value == value and math.abs(value) < math.huge
end

local function finiteVector(value: Vector3): boolean
	return finite(value.X) and finite(value.Y) and finite(value.Z)
end

local function positionRecord(position: Vector3)
	return { x = position.X, y = position.Y, z = position.Z }
end

function PhysicsAcceptance.run(runtimeFolder: Instance, courseFolder: Instance)
	local result = {
		passed = false,
		timeoutSeconds = TIMEOUT_SECONDS,
		duration = 0,
		errors = {},
		runs = {},
	}
	local temporary: Folder? = nil
	local simulationConnection: RBXScriptConnection? = nil
	local states = {}
	local elapsed = 0

	local function fail(state, message: string)
		table.insert(state.report.failures, message)
		state.done = true
		if state.body.Parent then
			state.body.Anchored = true
		end
	end

	local succeeded, failure = xpcall(function()
		assert(RunService:IsServer() and RunService:IsRunning(), "Run this acceptance check in a running server simulation")
		for _, name in ipairs({ "Floor", "Uphill", "HighDeck", "Downhill", "TransferJump", "BankLanding" }) do
			assert(courseFolder:FindFirstChild(name), "Missing course section: " .. name)
		end
		local chassisModule = runtimeFolder:FindFirstChild("Chassis")
		local profilesModule = runtimeFolder:FindFirstChild("Profiles")
		assert(chassisModule and chassisModule:IsA("ModuleScript"), "Missing Chassis ModuleScript")
		assert(profilesModule and profilesModule:IsA("ModuleScript"), "Missing Profiles ModuleScript")
		local Chassis = require(chassisModule)
		local profile = require(profilesModule).Cart

		local folder = Instance.new("Folder")
		folder.Name = "RidePhysicsAcceptance_" .. HttpService:GenerateGUID(false)
		folder.Parent = workspace
		temporary = folder

		for index, load in ipairs({ 0, 1 }) do
			local name = if load == 0 then "empty" else "full"
			local body = Instance.new("Part")
			body.Name = name
			body.Size = Vector3.new(5, 1, 7)
			body.CFrame = CFrame.new(if index == 1 then -6 else 6, 2.5, -70)
			body.CanCollide = true
			body.CanTouch = false
			body.CustomPhysicalProperties = PhysicalProperties.new(0.8, 0.15, 0, 1, 1)
			body.Parent = folder
			body:SetNetworkOwner(nil)

			local controller = Chassis.new(body, profile, { folder })
			controller:setLoad(load)
			local report = {
				load = load,
				passed = false,
				failures = {},
				crestReached = false,
				bankLandingSupported = false,
				reachedFinish = false,
				maxUphillHeight = 0,
				maxDeckSpeed = 0,
				maxDownhillSpeed = 0,
				maxLandingSpeed = 0,
				maxSpeed = 0,
				maxJumpCharge = 0,
				chargedHopReleased = false,
				airborneAfterRelease = false,
				maxAirborneHeight = 0,
				finalPosition = positionRecord(body.Position),
			}
			table.insert(result.runs, report)
			table.insert(states, {
				body = body,
				controller = controller,
				report = report,
				done = false,
				chargeStarted = false,
				chargeElapsed = 0,
				released = false,
				previousPosition = body.Position,
				telemetry = nil,
			})
		end

		simulationConnection = RunService.PreSimulation:Connect(function(dt: number)
			for _, state in ipairs(states) do
				if state.done then continue end
				local ok, err = pcall(function()
					local held = false
					if not state.chargeStarted and state.body.Position.Z <= -265 then
						state.chargeStarted = true
					end
					if state.chargeStarted and not state.released then
						if state.chargeElapsed < 0.35 then
							held = true
							state.chargeElapsed += dt
						else
							state.released = true
							state.report.chargedHopReleased = true
						end
					end
					state.telemetry = state.controller:step(dt, {
						throttle = 1, steer = 0, brake = false,
						held = held, drift = false, enabled = true,
					})
				end)
				if not ok then fail(state, "Simulation callback: " .. tostring(err)) end
			end
		end)

		while elapsed < TIMEOUT_SECONDS do
			local dt = RunService.Heartbeat:Wait()
			elapsed += dt
			local complete = true
			for _, state in ipairs(states) do
				if state.done then continue end
				complete = false
				local body = state.body
				local report = state.report
				local position = body.Position
				local velocity = body.AssemblyLinearVelocity
				local angular = body.AssemblyAngularVelocity
				if not finiteVector(position) or not finiteVector(velocity) or not finiteVector(angular) then
					fail(state, "Non-finite physics state")
					continue
				end
				report.finalPosition = positionRecord(position)
				if position.Y < -1 then
					fail(state, "Body dropped below the course floor")
					continue
				end
				local displacement = (position - state.previousPosition).Magnitude
				if displacement > math.max(16, (velocity.Magnitude + 30) * dt * 2) then
					fail(state, "Unexpected reset or position discontinuity")
					continue
				end
				state.previousPosition = position
				local telemetry = state.telemetry
				if not telemetry then continue end
				if not finite(telemetry.speed) or not finite(telemetry.slip) then
					fail(state, "Non-finite chassis telemetry")
					continue
				end

				report.maxSpeed = math.max(report.maxSpeed, velocity.Magnitude)
				report.maxJumpCharge = math.max(report.maxJumpCharge, telemetry.jumpCharge)
				if position.Z <= -94 and position.Z >= -201 then
					report.maxUphillHeight = math.max(report.maxUphillHeight, position.Y)
				end
				if position.Z <= -160 and position.Z >= -198 and position.Y >= 18 then
					report.crestReached = report.crestReached or telemetry.grounded
					report.maxDeckSpeed = math.max(report.maxDeckSpeed, velocity.Magnitude)
				end
				if position.Z < -201 and position.Z >= -251 then
					report.maxDownhillSpeed = math.max(report.maxDownhillSpeed, velocity.Magnitude)
				end
				if state.released and not telemetry.grounded then
					report.airborneAfterRelease = true
					report.maxAirborneHeight = math.max(report.maxAirborneHeight, position.Y)
				end
				if position.Z <= -310 and position.Z >= -394 and position.Y >= 5 and telemetry.grounded then
					report.bankLandingSupported = true
					report.maxLandingSpeed = math.max(report.maxLandingSpeed, velocity.Magnitude)
				end
				if position.Z < -395 then
					report.reachedFinish = true
					report.finishTime = elapsed
					state.done = true
					body.Anchored = true
				end
			end
			if complete then break end
		end

		for _, state in ipairs(states) do
			local report = state.report
			if not report.crestReached then table.insert(report.failures, "Did not traverse the supported high deck") end
			if not report.reachedFinish then table.insert(report.failures, "Did not reach z < -395 within 20 seconds") end
			if not report.bankLandingSupported then table.insert(report.failures, "No supported bank landing recorded") end
			if report.maxDownhillSpeed <= report.maxDeckSpeed + 2 then table.insert(report.failures, "No downhill speed gain recorded") end
			if not report.chargedHopReleased or report.maxJumpCharge < 0.95 then table.insert(report.failures, "Neutral hop did not reach full charge before release") end
			if not report.airborneAfterRelease then table.insert(report.failures, "No airborne state observed after charged release") end
			report.passed = #report.failures == 0
		end
	end, debug.traceback)

	if simulationConnection then simulationConnection:Disconnect() end
	for _, state in ipairs(states) do
		local ok, err = pcall(function() state.controller:destroy() end)
		if not ok then table.insert(result.errors, "Controller cleanup: " .. tostring(err)) end
	end
	if temporary then temporary:Destroy() end
	if not succeeded then table.insert(result.errors, tostring(failure)) end
	result.duration = elapsed
	result.passed = succeeded and #result.errors == 0 and #result.runs == 2
	for _, report in ipairs(result.runs) do
		result.passed = result.passed and report.passed
	end
	return result
end

return PhysicsAcceptance
