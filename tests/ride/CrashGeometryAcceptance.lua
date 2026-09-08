--!strict

-- Replays replicated wall-approach samples through real engine geometry queries.
return function(Crashes)
	local wall = Instance.new("Part")
	local wallModel = Instance.new("Model")
	wallModel.Name = "CrashGeometryAcceptance"
	wallModel.Parent = workspace
	wall.Name = "CrashGeometryAcceptanceWall"
	wall.Anchored = true
	wall.Size = Vector3.new(28, 12, 3)
	wall.CFrame = CFrame.new(1000, 6, -30)
	wall.Parent = wallModel
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = {wall}
	params.RespectCanCollide = true
	local results = {}
	local function replay(name, frames, expected, ram)
		local humanoid = {}
		local seat = {Occupant = humanoid, IsA = function(_, class) return class == "Seat" end}
		local body = {Size = Vector3.new(5, 1, 7)}
		local cart = {
			PrimaryPart = body,
			GetAttribute = function() return nil end,
			FindFirstChild = function(_, key) return if key == "DriverSeat" then seat else nil end,
		}
		local character = {FindFirstChildOfClass = function() return humanoid end}
		local track = {cart = cart, character = character, params = params}
		local count = 0
		local controller = setmetatable({tracks = {track}, byCart = {}, isCurrent = function() return true end}, Crashes)
		if ram then
			controller.byCart[wallModel] = {sample = {cf = CFrame.new(1000, 2.5, -32), velocity = Vector3.zero}, cart = wallModel}
		end
		function controller:eject() count += 1 end
		for _, frame in frames do
			body.CFrame = CFrame.new(1000, 2.5, frame[1])
			body.AssemblyLinearVelocity = Vector3.new(0, 0, -frame[2])
			controller:step()
		end
		table.insert(results, {name = name, expected = expected, actual = count, passed = count == expected})
	end
	local ok, err = pcall(function()
		replay("eject on the first replicated impact without waiting for deep overlap", {{-21.104,44},{-21.850,44},{-22.564,42.046},{-23.317,32.151},{-24.070,16.548},{-24.615,1.717}}, 1)
		replay("live replicated full-speed wall miss", {{-21.342,44},{-22.130,44},{-22.888,42.27},{-23.624,31.50},{-24.252,15.64},{-24.8,3},{-25,0}}, 1)
		replay("braking before contact", {{-21.342,44},{-22.130,36},{-22.888,22},{-23.624,8},{-24.252,0},{-24.252,0}}, 0)
		replay("slow wall bump", {{-23,20},{-24,20},{-24.8,12},{-25,0}}, 0)
		replay("ram approach without contact", {{-21.342,44},{-22.130,44},{-22.888,42.27}}, 0, true)
		replay("ram preserves approach until physical contact", {{-21.342,44},{-22.130,44},{-22.888,42.27},{-23.624,31.50},{-24.252,15.64},{-24.8,3},{-25,0}}, 1, true)
		replay("replicated rebound precedes contact position", {{-21.104,44},{-21.850,44},{-22.564,42.046},{-23.317,32.151},{-24.070,16.548},{-24.615,1.717},{-24.895,-9.19},{-24.94,-5},{-25,0}}, 1)
	end)
	wallModel:Destroy()
	if not ok then error(err) end
	local passed = true
	for _, result in results do if not result.passed then passed = false end end
	return {passed = passed, cases = results, method = "Recorded server samples with real Blockcast and overlap queries; no rider or network simulation"}
end
