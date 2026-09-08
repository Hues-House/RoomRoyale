--!strict
-- Run in the lab Play Client immediately after StartCartLabRound:Invoke(18).
-- Positions are staged. Pickups and checkout use the real server rules.
local player = game.Players.LocalPlayer
local event = game.ReplicatedStorage.CartLabEvent
local cart = workspace.LabCarts:WaitForChild(tostring(player.UserId))
local world = workspace.CartLab
local result = {events = {}}
local function sample(name)
	local row = {phase = name, time = workspace:GetServerTimeNow(), space = cart:GetAttribute("SpaceUsed"), banked = cart:GetAttribute("BankedCount")}
	table.insert(result.events, row)
	return row
end
local function stage(position)
	cart:PivotTo(CFrame.new(position))
	cart.PrimaryPart.AssemblyLinearVelocity = Vector3.zero
	cart.PrimaryPart.AssemblyAngularVelocity = Vector3.zero
	task.wait(0.5)
end
local function grab(position)
	stage(position)
	event:FireServer("Grab")
	task.wait(0.5)
end
grab(Vector3.new(-27, 2.5, 50))
assert(sample("first pickup").space == 40, "Sofa pickup did not succeed")
stage(Vector3.new(-75, 2.5, 55))
task.wait(0.5)
assert(sample("first deposit").banked == 1, "First load did not bank")
grab(Vector3.new(28, 2.5, 50))
assert(sample("second load").space == 8, "Second load did not succeed")
while world:GetAttribute("ShoppingPhase") == "Shop" do task.wait(0.05) end
assert(world:GetAttribute("ShoppingPhase") == "Closing", "Missed arrival grace")
stage(Vector3.new(26, 2.5, -58))
event:FireServer("Grab")
task.wait(0.25)
assert(sample("zero rejects pickup").space == 8, "Pickup accepted after zero")
stage(Vector3.new(-75, 2.5, 55))
task.wait(0.3)
local late = sample("late arrival")
assert(late.banked == 2 and late.space == 0, "Late checkout failed")
while world:GetAttribute("ShoppingPhase") ~= "Style" do task.wait(0.05) end
task.wait(1.5)
result.cartRemoved = not cart.Parent
result.roomPresent = workspace:FindFirstChild("LabStyleRoom1") ~= nil
result.characterPosition = tostring(player.Character.HumanoidRootPart.Position)
result.clientInRoom = (player.Character.HumanoidRootPart.Position - Vector3.new(465, 3, 94)).Magnitude < 10
result.deliveredModels = #workspace.CartLabCargoVisuals:GetChildren()
result.passed = result.cartRemoved and result.roomPresent and result.clientInRoom and result.deliveredModels == 2
assert(result.passed, "Client did not arrive in Style with exactly two delivered pieces")
workspace:SetAttribute("TimedRoundAcceptance", game.HttpService:JSONEncode(result))
return result
