--!strict

-- Inject into the standalone lab's Play server for an observed rider qualification.
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local player = game.Players:GetPlayers()[1]
local cart = workspace.LabCarts:FindFirstChild(tostring(player.UserId))
assert(cart and player.Character, "A mounted cart-lab player is required")
local character = player.Character
local humanoid = character:FindFirstChildOfClass("Humanoid")
local start = workspace:GetServerTimeNow()
local initialCount = cart:GetAttribute("CrashCount") or 0
local cargo = {}
for _, item in cart.Cargo:GetChildren() do table.insert(cargo, item.Name) end
table.sort(cargo)
local result = {initialCargo = cargo, initialCount = initialCount, peakDisabledJoints = 0, peakHeight = 0, minimumHealth = humanoid.Health, events = {}, trace = {}}
cart:SetAttribute("DebugCrashes", true)
local debugConnection = cart:GetAttributeChangedSignal("CrashDebug"):Connect(function()
	local message = cart:GetAttribute("CrashDebug")
	if string.match(message, "^Wall") or string.match(message, "^Eject") or string.match(message, "^Reject") then
		if #result.trace < 40 then table.insert(result.trace, message) end
	end
end)
local ejectedAt = nil
local connection
connection = RunService.Heartbeat:Connect(function()
	local now = workspace:GetServerTimeNow()
	local count = cart:GetAttribute("CrashCount") or 0
	if count > initialCount and not ejectedAt then
		ejectedAt = now
		table.insert(result.events, {phase = "Eject", elapsed = now - start, kind = cart:GetAttribute("LastCrashKind")})
	end
	local disabled = 0
	for _, joint in character:GetDescendants() do
		if (joint:IsA("AnimationConstraint") or joint:IsA("Motor6D")) and not joint.Enabled then disabled += 1 end
	end
	result.peakDisabledJoints = math.max(result.peakDisabledJoints, disabled)
	result.peakHeight = math.max(result.peakHeight, character.HumanoidRootPart.Position.Y)
	result.minimumHealth = math.min(result.minimumHealth, humanoid.Health)
	local seat = cart:FindFirstChild("DriverSeat")
	if ejectedAt and not result.recoveredAfter and cart:GetAttribute("Ejected") ~= true and seat and seat.Occupant == humanoid then
		result.recoveredAfter = now - ejectedAt
		result.protectionAtRecovery = (cart:GetAttribute("ProtectedUntil") or 0) - now
		result.disabledAfterRecovery = disabled
	end
	if workspace:GetAttribute("StopRiderCrashProbe") == true or now - start > 30 then
		connection:Disconnect()
		debugConnection:Disconnect()
		cart:SetAttribute("DebugCrashes", nil)
		cart:SetAttribute("CrashDebug", nil)
		result.finalCount = count
		result.finalCargo = {}
		for _, item in cart.Cargo:GetChildren() do table.insert(result.finalCargo, item.Name) end
		table.sort(result.finalCargo)
		result.cargoPreserved = HttpService:JSONEncode(result.initialCargo) == HttpService:JSONEncode(result.finalCargo)
		result.mounted = seat and seat.Occupant == humanoid
		workspace:SetAttribute("RiderCrashProbeResult", HttpService:JSONEncode(result))
		script:Destroy()
	end
end)
