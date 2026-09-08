--!strict
local args = game:GetService("StudioTestService"):GetTestArgs()
if args ~= "CartRamQualification" then return end
local player = game.Players.LocalPlayer
local runtime = game.ReplicatedStorage:WaitForChild("RideRuntime")
local Chassis = require(runtime:WaitForChild("Chassis"))
local original = Chassis.step
local frames, timings = {}, {}
function Chassis:step(dt, input)
	if workspace:GetAttribute("RamTestPhase") == "Drive" then
		input.enabled = true
		input.throttle = if player.UserId == workspace:GetAttribute("RamTestAttacker") then 1 else 0
		input.brake = input.throttle == 0
		input.steer = 0
		input.held = false
		input.edges = {}
	end
	local start = os.clock()
	local result = original(self, dt, input)
	table.insert(timings, (os.clock() - start) * 1000)
	return result
end
game.RunService.RenderStepped:Connect(function(dt) table.insert(frames, dt * 1000) end)
workspace:GetAttributeChangedSignal("RamTestPhase"):Connect(function()
	if workspace:GetAttribute("RamTestPhase") == "Grab" then
		task.wait(0.4)
		game.ReplicatedStorage.CartLabEvent:FireServer("Grab")
	elseif workspace:GetAttribute("RamTestPhase") == "Report" then
		table.sort(frames)
		table.sort(timings)
		local function percentile(values, p) return values[math.max(1, math.ceil(#values * p))] or 0 end
		game.ReplicatedStorage.RamTestReport:FireServer({frames = #frames, frameP50Ms = percentile(frames, 0.5), frameP95Ms = percentile(frames, 0.95), chassisP95Ms = percentile(timings, 0.95), input = "Scripted Chassis inputs on two simulated clients"})
		Chassis.step = original
	end
end)
