--!strict

return function(loadCrashes)
	local methods = {}
	local vectorMeta = {
		__index = function(value, key)
			if key == "Magnitude" then return math.sqrt(value.X * value.X + value.Y * value.Y + value.Z * value.Z) end
			if key == "Unit" then return value / value.Magnitude end
			return methods[key]
		end,
	}
	local function vector(x, y, z) return setmetatable({X = x, Y = y, Z = z}, vectorMeta) end
	vectorMeta.__add = function(a, b) return vector(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
	vectorMeta.__sub = function(a, b) return vector(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
	vectorMeta.__mul = function(a, b)
		if type(b) == "number" then return vector(a.X * b, a.Y * b, a.Z * b) end
		return vector(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
	end
	vectorMeta.__div = function(a, b) return vector(a.X / b, a.Y / b, a.Z / b) end
	function methods:Dot(other) return self.X * other.X + self.Y * other.Y + self.Z * other.Z end
	local Vector3 = {new = vector, zero = vector(0, 0, 0)}
	local Enum = {RaycastFilterType = {Include = "Include", Exclude = "Exclude"}}
	local OverlapParams = {new = function() return {} end}

	local function fixture()
		local Players = {}
		local world = {time = 0, hit = nil, overlap = false, overlapCalls = 0}
		function world:GetServerTimeNow() return self.time end
		function world:Blockcast() return self.hit end
		local wall = {Parent = world}
		function wall:IsA(class) return class == "BasePart" end
		function wall:GetVelocityAtPosition() return Vector3.zero end
		function wall:FindFirstAncestorOfClass() return nil end
		function world:GetPartBoundsInBox(_, size, params)
			self.overlapCalls += 1
			assert(params.FilterType == "Include" and params.FilterDescendantsInstances[1] == wall)
			assert(params.RespectCanCollide == true)
			assert(math.abs(size.Z - 7.8) < 0.001)
			return if self.overlap then {wall} else {}
		end
		local humanoid = {}
		local character = {}
		function character:FindFirstChildOfClass() return humanoid end
		local seat = {Occupant = humanoid}
		function seat:IsA(class) return class == "Seat" end
		local body = {Size = vector(5, 1, 7)}
		local attributes = {ResetVersion = 0, ProtectedUntil = 0}
		local cart = {PrimaryPart = body}
		function cart:IsDescendantOf(parent) return parent == world end
		function cart:GetAttribute(name) return attributes[name] end
		function cart:FindFirstChild(name) return if name == "DriverSeat" then seat else nil end
		local player = {Parent = Players, Character = character}
		local game = {GetService = function(_, name) return if name == "Players" then Players else {} end}
		local Crashes = loadCrashes(game, world, Vector3, Enum, OverlapParams)
		local controller = setmetatable({tracks = {}, byCart = {}, ejections = {}}, Crashes)
		local track = {player = player, cart = cart, character = character, params = {}, epoch = 0}
		controller.tracks[player] = track
		function controller:eject(_, _, kind, velocity)
			table.insert(self.ejections, {kind = kind, velocity = velocity})
		end
		local function frame(time, z, speed, freshHit, overlap, normal)
			world.time = time
			world.overlap = overlap == true
			world.hit = if freshHit then {Instance = wall, Normal = normal or vector(0, 0, 1), Position = vector(0, 2.5, -28.5)} else nil
			body.CFrame = {Position = vector(0, 2.5, z), LookVector = vector(0, 0, -1)}
			body.AssemblyLinearVelocity = vector(0, 0, -speed)
			controller:step()
		end
		return {controller = controller, track = track, frame = frame, world = world, attributes = attributes, seat = seat}
	end

	local checks = 0
	local function check(name, run)
		run()
		checks += 1
		print("PASS " .. name)
	end
	check("reported hit then initial-overlap trace qualifies once", function()
		local f = fixture()
		f.frame(0, -24.65, 44, false, false)
		f.frame(0.016, -25.159, 40.1, true, false)
		f.frame(0.033, -25.5, 27.86, false, true)
		f.frame(0.05, -25.7, 19, false, true)
		assert(#f.controller.ejections == 1)
		assert(f.controller.ejections[1].kind == "HardWall")
		assert(f.controller.ejections[1].velocity.Z == -44)
	end)
	check("distributed loss keeps the original incoming peak", function()
		local f = fixture()
		f.frame(0, -24.65, 44, false, false)
		f.frame(0.016, -25.159, 38, true, false)
		f.frame(0.033, -25.5, 32, false, true)
		assert(#f.controller.ejections == 1)
	end)
	check("separation clears the impact", function()
		local f = fixture()
		f.frame(0, -24.65, 44, false, false)
		f.frame(0.016, -25.159, 40.1, true, false)
		f.frame(0.033, -25.5, 27.86, false, false)
		assert(#f.controller.ejections == 0 and f.track.contact == nil)
	end)
	check("expired overlap cannot retain a fast approach", function()
		local f = fixture()
		f.frame(0, -24.65, 44, false, false)
		f.frame(0.016, -25.159, 40.1, true, false)
		f.frame(0.36, -25.5, 27.86, false, true)
		assert(#f.controller.ejections == 0 and f.track.contact == nil)
	end)
	check("a low-speed hit remains a bump", function()
		local f = fixture()
		f.frame(0, -24.65, 31, false, false)
		f.frame(0.016, -25.159, 0, true, false)
		assert(#f.controller.ejections == 0)
	end)
	check("a new contact normal cannot borrow the old peak", function()
		local f = fixture()
		f.frame(0, -24.65, 44, false, false)
		f.frame(0.016, -25.159, 40.1, true, false)
		f.frame(0.033, -25.5, 27.86, true, false, vector(1, 0, 0))
		assert(#f.controller.ejections == 0)
	end)
	check("reset invalidates the impact", function()
		local f = fixture()
		f.frame(0, -24.65, 44, false, false)
		f.frame(0.016, -25.159, 40.1, true, false)
		f.attributes.ResetVersion = 1
		f.frame(0.033, -25.5, 27.86, false, true)
		assert(#f.controller.ejections == 0 and f.track.contact == nil)
	end)
	check("losing the seat invalidates the impact", function()
		local f = fixture()
		f.frame(0, -24.65, 44, false, false)
		f.frame(0.016, -25.159, 40.1, true, false)
		f.seat.Occupant = nil
		f.frame(0.033, -25.5, 27.86, false, true)
		assert(#f.controller.ejections == 0 and f.track.contact == nil)
	end)
	check("a stationary cached contact still requests overlap proof", function()
		local f = fixture()
		f.frame(0, -24.65, 44, false, false)
		f.frame(0.016, -25.159, 0, true, false)
		local before = f.world.overlapCalls
		f.frame(0.033, -25.159, 0, false, true)
		assert(f.world.overlapCalls == before + 1)
		assert(#f.controller.ejections == 1)
	end)
	for _, scenario in {
		{name = "decisive rear ram", attacker = 44, victim = 0, facing = 1, expected = 1},
		{name = "matching speed is an ordinary bump", attacker = 44, victim = 40, facing = 1, expected = 0},
		{name = "equal head-on approach has no perfect-ram winner", attacker = 44, victim = -44, facing = 1, expected = 0},
		{name = "slow rear bump", attacker = 24, victim = 0, facing = 1, expected = 0},
		{name = "sideways scrape", attacker = 44, victim = 0, facing = 0, expected = 0},
	} do
		check(scenario.name, function()
			local f = fixture()
			local a = {cf = {Position = vector(0, 0, 0), LookVector = vector(1 - scenario.facing, 0, -scenario.facing)}, velocity = vector(0, 0, -scenario.attacker)}
			local b = {cf = {Position = vector(0, 0, -8), LookVector = vector(0, 0, -1)}, velocity = vector(0, 0, -scenario.victim)}
			f.controller:ram({}, f.track, a, b)
			assert(#f.controller.ejections == scenario.expected)
		end)
	end
	print(string.format("%d crash source replay checks passed; geometry queries are stubbed, ragdoll execution is not tested.", checks))
end
