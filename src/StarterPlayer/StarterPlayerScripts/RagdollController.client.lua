--!strict
-- StarterPlayerScripts > RagdollController
-- Handles client-side ragdoll CanCollide since server can't set it persistently
-- on client-owned character parts.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local Events = ReplicatedStorage:WaitForChild("Events", 15)
local RagdollStart = Events:WaitForChild("RagdollStart", 15) :: RemoteEvent
local RagdollEnd = Events:WaitForChild("RagdollEnd", 15) :: RemoteEvent

local isRagdolled = false
local ragdollConnection: RBXScriptConnection? = nil

local limbPartNames = {
	LeftUpperArm=true, LeftLowerArm=true,
	RightUpperArm=true, RightLowerArm=true,
	LeftUpperLeg=true, LeftLowerLeg=true,
	RightUpperLeg=true, RightLowerLeg=true,
	["Left Arm"]=true, ["Right Arm"]=true,
	["Left Leg"]=true, ["Right Leg"]=true,
}

local function setLimbsCollidable(collidable: boolean)
	local char = player.Character
	if not char then return end
	for _, desc in ipairs(char:GetDescendants()) do
		if desc:IsA("BasePart") and limbPartNames[desc.Name] then
			desc.CanCollide = collidable
		end
	end
end

RagdollStart.OnClientEvent:Connect(function()
	isRagdolled = true
	-- Set collidable immediately
	setLimbsCollidable(true)
	-- Keep setting it every frame since physics can reset it
	ragdollConnection = RunService.Heartbeat:Connect(function()
		if not isRagdolled then
			if ragdollConnection then
				ragdollConnection:Disconnect()
				ragdollConnection = nil
			end
			return
		end
		setLimbsCollidable(true)
	end)
end)

RagdollEnd.OnClientEvent:Connect(function()
	isRagdolled = false
	if ragdollConnection then
		ragdollConnection:Disconnect()
		ragdollConnection = nil
	end
	setLimbsCollidable(false)
end)
