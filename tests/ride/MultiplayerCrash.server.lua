--!strict
local service = game:GetService("StudioTestService")
if service:GetTestArgs() ~= "CartRamQualification" then return end
local result = {passed = false, samples = {}, traces = {}, clientPerformance = {}}
local finished = false
local function finish()
	if finished then return end
	finished = true
	service:EndTest(result)
end
task.delay(40, function() result.timeout = true; finish() end)
local report = Instance.new("RemoteEvent")
report.Name = "RamTestReport"
report.Parent = game.ReplicatedStorage
report.OnServerEvent:Connect(function(player, metrics) result.clientPerformance[player.Name] = metrics end)
local ok, err = pcall(function()
	while #game.Players:GetPlayers() < 2 do task.wait(0.1) end
	local players = game.Players:GetPlayers()
	table.sort(players, function(a,b) return a.UserId > b.UserId end)
	local attacker, victim = players[1], players[2]
	local a = workspace.LabCarts:WaitForChild(tostring(attacker.UserId))
	local b = workspace.LabCarts:WaitForChild(tostring(victim.UserId))
	while not a.DriverSeat.Occupant or not b.DriverSeat.Occupant do task.wait(0.1) end
	workspace:SetAttribute("RamTestAttacker", attacker.UserId)
	for _, cart in {a,b} do
		cart:SetAttribute("DebugCrashes",true)
		cart:GetAttributeChangedSignal("CrashDebug"):Connect(function()
			local message = cart:GetAttribute("CrashDebug")
			if message:match("^Eject") or message:match("^Reject") then table.insert(result.traces,cart.Name .. " " .. message) end
		end)
	end
	local function stage(cart, player, position)
		cart.PrimaryPart:SetNetworkOwner(nil)
		cart:PivotTo(CFrame.new(position))
		cart.PrimaryPart.AssemblyLinearVelocity = Vector3.zero
		cart.PrimaryPart.AssemblyAngularVelocity = Vector3.zero
		cart:SetAttribute("ResetVersion", (cart:GetAttribute("ResetVersion") or 0) + 1)
		task.wait(0.25)
		cart.PrimaryPart:SetNetworkOwner(player)
	end
	stage(a, attacker, Vector3.new(28,2.5,50))
	stage(b, victim, Vector3.new(-27,2.5,50))
	workspace:SetAttribute("RamTestPhase","Grab")
	task.wait(1.5)
	result.initialCargo = {attacker = a:GetAttribute("SpaceUsed"), victim = b:GetAttribute("SpaceUsed")}
	assert(result.initialCargo.attacker == 8 and result.initialCargo.victim == 40, "Both players must collect their own load")
	local function cargoIds(cart)
		local ids = {}
		for _, entry in cart.Cargo:GetChildren() do table.insert(ids, entry.Name) end
		table.sort(ids)
		return table.concat(ids, ",")
	end
	local attackerCargo, victimCargo = cargoIds(a), cargoIds(b)
	local function awaitCondition(condition, seconds, failure)
		local deadline = os.clock() + seconds
		repeat task.wait(0.05) until condition() or os.clock() >= deadline
		assert(condition(), failure)
	end
	local function approach()
		workspace:SetAttribute("RamTestPhase","Stage")
		stage(a,attacker,Vector3.new(-110,2.5,35))
		stage(b,victim,Vector3.new(-110,2.5,0))
		workspace:SetAttribute("RamTestPhase","Drive")
	end
	local function sample(name)
		local row = {name=name,attackerCount=a:GetAttribute("CrashCount") or 0,victimCount=b:GetAttribute("CrashCount") or 0,victimKind=b:GetAttribute("LastCrashKind"),attackerSpace=a:GetAttribute("SpaceUsed"),victimSpace=b:GetAttribute("SpaceUsed"),victimSeated=b.DriverSeat.Occupant~=nil}
		table.insert(result.samples,row)
		return row
	end
	approach()
	awaitCondition(function() return b:GetAttribute("CrashCount") == 1 end, 5, "First ram did not eject")
	workspace:SetAttribute("RamTestPhase", "Stage")
	awaitCondition(function() return b.DriverSeat.Occupant ~= nil and not b:GetAttribute("Ragdolled") end, 3, "Victim did not recover")
	local first = sample("rear ram and recovery")
	assert(first.victimCount==1 and first.attackerCount==0 and first.victimSeated, "Decisive ram must eject only victim and recover")
	assert(first.attackerSpace==8 and first.victimSpace==40,"Ram changed cargo")
	approach()
	awaitCondition(function()
		for _, trace in result.traces do if trace:find("shield remaining=", 1, true) then return true end end
		return false
	end, 3, "Repeat ram did not exercise active shield")
	workspace:SetAttribute("RamTestPhase", "Stage")
	local protected = sample("ram rejected during shield")
	assert(protected.victimCount == 1 and protected.victimSeated, "Shield allowed repeat ejection")
	awaitCondition(function() return workspace:GetServerTimeNow() > b:GetAttribute("ProtectedUntil") end, 6, "Shield did not expire")
	approach()
	awaitCondition(function() return b:GetAttribute("CrashCount") == 2 end, 5, "Ram did not eject after shield expired")
	workspace:SetAttribute("RamTestPhase", "Stage")
	awaitCondition(function() return b.DriverSeat.Occupant ~= nil and not b:GetAttribute("Ragdolled") end, 3, "Second recovery failed")
	local final = sample("ram after shield expiry and recovery")
	assert(final.attackerCount == 0 and final.victimCount == 2, "Unexpected crash counts")
	assert(cargoIds(a) == attackerCargo and cargoIds(b) == victimCargo, "Cargo identities changed")
	assert(victim.Character.Humanoid.Health == 100, "Ragdoll damaged victim")
	for _, joint in victim.Character:GetDescendants() do
		if joint:IsA("AnimationConstraint") then assert(joint.Enabled, "Animation joint remained disabled") end
	end
	result.cargoIdentitiesPreserved = true
	result.health = victim.Character.Humanoid.Health
	workspace:SetAttribute("RamTestPhase","Report")
	task.wait(0.5)
	result.passed = true
end)
if not ok then result.error = tostring(err) end
finish()
