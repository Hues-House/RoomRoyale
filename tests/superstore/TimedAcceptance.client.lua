-- Staged positions exercise the real pickup remote and server checkout in Studio.
local player=game.Players.LocalPlayer
local world=workspace:WaitForChild("CartLab")
local remote=game.ReplicatedStorage:WaitForChild("CartLabEvent")
local endsAt
repeat task.wait() endsAt=world:GetAttribute("AcceptanceShopEndsAt") until endsAt
local cart=workspace.LabCarts:WaitForChild(tostring(player.UserId))
local results={}
local function pickupId()
    local body = cart.PrimaryPart
    local nearest, distance = nil, math.huge
    for _, part in game:GetService("CollectionService"):GetTagged("CartLabPickup") do
        local current = (part.Position - body.Position).Magnitude
        if current < distance then nearest, distance = part, current end
    end
    return nearest and nearest:GetAttribute("PickupId")
end
local function sample(name)
	local value={name=name,phase=world:GetAttribute("ShoppingPhase"),space=cart:GetAttribute("SpaceUsed"),banked=cart:GetAttribute("BankedCount"),at=workspace:GetServerTimeNow()}
	table.insert(results,value)
	world:SetAttribute("TimedAcceptanceClient",game:GetService("HttpService"):JSONEncode(results))
	return value
end
local function move(cf)
	cart:PivotTo(cf)
	cart.PrimaryPart.AssemblyLinearVelocity=Vector3.zero
	cart.PrimaryPart.AssemblyAngularVelocity=Vector3.zero
	cart:SetAttribute("ResetVersion",(cart:GetAttribute("ResetVersion") or 0)+1)
	task.wait(0.65)
end
move(CFrame.new(-12,18.5,70))
remote:FireServer("Grab", pickupId())
task.wait(0.4)
assert(sample("Sofa pickup").space==40,"Sofa was not accepted")
move(CFrame.new(87,2.7,-342))
assert(sample("First checkout").banked==1,"First checkout was not banked")
move(CFrame.new(-12,18.5,42))
remote:FireServer("Grab", pickupId())
task.wait(0.4)
assert(sample("Second load").space==22,"Second load was not accepted")
repeat task.wait() until workspace:GetServerTimeNow()>endsAt+0.15
move(CFrame.new(-12,18.5,-17))
remote:FireServer("Grab", pickupId())
task.wait(0.3)
assert(sample("Pickup after zero rejected").space==22,"Pickup accepted after zero")
move(CFrame.new(87,2.7,-342))
local grace=sample("Grace checkout")
assert(grace.banked==2 and grace.space==0,"Grace checkout failed")
world:SetAttribute("TimedAcceptancePassed",true)
