--!strict
-- ServerScriptService > DummyCartDriver
-- Spawns a dummy cart with identical physics to a player cart and drives it
-- back and forth so it behaves like a real moving cart for ram testing.

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

local DUMMY_SPEED = 20
local PATROL_DISTANCE = 20
local SPAWN_POS = Vector3.new(8, 0, 180)

local CartTemplate = ServerStorage:WaitForChild("CartTemplate", 15) :: Model

-- Clean up any existing dummy
for _, obj in ipairs(workspace:GetChildren()) do
	if obj.Name == "DummyCart" or obj.Name == "DummyDriver" then
		obj:Destroy()
	end
end

local cart = CartTemplate:Clone()
cart.Name = "DummyCart"

local body = cart.PrimaryPart :: BasePart
local spawnY = body.Size.Y * 0.5 + 0.2
cart.Parent = workspace
body.CFrame = CFrame.new(SPAWN_POS + Vector3.new(0, spawnY, 0))

-- Mirror CartService configureCartModel exactly
body.CanCollide = false
body.RootPriority = 127
body.AssemblyLinearVelocity = Vector3.zero
body.AssemblyAngularVelocity = Vector3.zero
body.CustomPhysicalProperties = PhysicalProperties.new(2, 0.1, 0.8, 1, 1)

local wheelsFolder = cart:FindFirstChild("Wheels") :: Folder
for _, desc in ipairs(cart:GetDescendants()) do
	if desc:IsA("BasePart") then
		if desc:IsDescendantOf(wheelsFolder) then
			desc.CanCollide = true
			desc.CanTouch = true
			desc.Massless = false
			desc.CustomPhysicalProperties = PhysicalProperties.new(2, 0, 0, 0, 0)
		elseif desc == body then
			desc.CanCollide = false
			desc.CanTouch = false
			desc.Massless = false
		else
			desc.CanCollide = false
			desc.CanTouch = false
			desc.Massless = true
		end
	end
end

-- Drive constraints
local driveAtt = Instance.new("Attachment")
driveAtt.Name = "DriveAttachment"
driveAtt.Axis = Vector3.yAxis
driveAtt.Position = Vector3.new(0, -0.95, 0)
driveAtt.Parent = body

local lv = Instance.new("LinearVelocity")
lv.Name = "CartLinearVelocity"
lv.Attachment0 = driveAtt
lv.RelativeTo = Enum.ActuatorRelativeTo.World
lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
lv.ForceLimitMode = Enum.ForceLimitMode.PerAxis
lv.MaxAxesForce = Vector3.new(110000, 0, 110000)
lv.VectorVelocity = Vector3.zero
lv.Parent = body

local av = Instance.new("AngularVelocity")
av.Name = "CartAngularVelocity"
av.Attachment0 = driveAtt
av.RelativeTo = Enum.ActuatorRelativeTo.World
av.MaxTorque = 90000
av.AngularVelocity = Vector3.zero
av.Parent = body

local uprightLock = Instance.new("AlignOrientation")
uprightLock.Name = "UprightLock"
uprightLock.Mode = Enum.OrientationAlignmentMode.OneAttachment
uprightLock.Attachment0 = driveAtt
uprightLock.AlignType = Enum.AlignType.Parallel
uprightLock.PrimaryAxisOnly = true
uprightLock.PrimaryAxis = Vector3.yAxis
uprightLock.RigidityEnabled = true
uprightLock.Parent = body

-- Tag so CartCollision picks it up
CollectionService:AddTag(cart, "PlayerCart")
cart:SetAttribute("OwnerUserId", -1)
cart:SetAttribute("IsBoosting", false)

-- Patrol AI
local originZ = SPAWN_POS.Z
local direction = -1
local lastNetworkOwner: Player? = nil

RunService.Heartbeat:Connect(function()
	if not (cart.Parent and body.Parent) then return end

	local currentZ = body.Position.Z
	local targetZ = originZ + direction * PATROL_DISTANCE

	if direction == -1 and currentZ <= targetZ then
		direction = 1
	elseif direction == 1 and currentZ >= targetZ then
		direction = -1
	end

	lv.VectorVelocity = Vector3.new(0, 0, direction * DUMMY_SPEED)

	-- Transfer network ownership to nearest player so collision resolves on same client
	local nearestPlayer: Player? = nil
	local nearestDist = math.huge
	for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local d = (body.Position - root.Position).Magnitude
			if d < nearestDist then
				nearestDist = d
				nearestPlayer = player
			end
		end
	end

	if nearestPlayer ~= lastNetworkOwner and nearestDist < 30 then
		pcall(function() body:SetNetworkOwner(nearestPlayer) end)
		lastNetworkOwner = nearestPlayer
	end
end)

print("[DummyCart] Spawned at", SPAWN_POS, "patrolling ±", PATROL_DISTANCE, "studs along Z")
