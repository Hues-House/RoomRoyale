--!strict
-- StarterPlayerScripts > CartImpactEffects
-- Client-side effects for cart-to-cart collisions: screen shake, sparks, sound

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local Events = ReplicatedStorage:WaitForChild("Events", 15)
local CartImpact = Events:WaitForChild("CartImpact", 15) :: RemoteEvent

-- Shake state
local shakeOffset = CFrame.identity
local shakeMagnitude = 0
local shakeDecay = 0

-- Apply shake each frame
RunService.RenderStepped:Connect(function(dt: number)
	if shakeMagnitude < 0.001 then
		shakeOffset = CFrame.identity
		return
	end
	local rx = (math.random() - 0.5) * 2 * shakeMagnitude
	local ry = (math.random() - 0.5) * 2 * shakeMagnitude
	local rz = (math.random() - 0.5) * 2 * shakeMagnitude
	shakeOffset = CFrame.Angles(rx, ry, rz)
	camera.CFrame = camera.CFrame * shakeOffset
	shakeMagnitude = math.max(0, shakeMagnitude - shakeDecay * dt)
end)

local function triggerShake(magnitude: number, duration: number)
	shakeMagnitude = math.min(magnitude, 0.25) -- cap so it's not nauseating
	shakeDecay = magnitude / duration
end

local function spawnImpactSparks(pos: Vector3, speed: number)
	-- Spark burst at impact point
	local att = Instance.new("Attachment")
	att.WorldPosition = pos
	att.Parent = workspace.Terrain

	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = ""
	sparks.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 240, 100)),
		ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 140, 20)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 180, 180)),
	})
	sparks.LightEmission = 1
	sparks.LightInfluence = 0
	sparks.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparks.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	sparks.Speed = NumberRange.new(speed * 0.3, speed * 0.6)
	sparks.SpreadAngle = Vector2.new(80, 80)
	sparks.Lifetime = NumberRange.new(0.2, 0.5)
	sparks.Rate = 0
	sparks.RotSpeed = NumberRange.new(-180, 180)
	sparks.Rotation = NumberRange.new(0, 360)
	sparks.Parent = att

	-- Burst emit then clean up
	local burstCount = math.clamp(math.floor(speed * 1.5), 8, 40)
	sparks:Emit(burstCount)

	-- Dust puff
	local dust = Instance.new("ParticleEmitter")
	dust.Texture = "rbxassetid://3845808160"
	dust.Color = ColorSequence.new(Color3.fromRGB(200, 190, 175))
	dust.LightEmission = 0
	dust.LightInfluence = 0.6
	dust.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(0.5, 1.0),
		NumberSequenceKeypoint.new(1, 0),
	})
	dust.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	dust.Speed = NumberRange.new(4, 10)
	dust.SpreadAngle = Vector2.new(60, 60)
	dust.Lifetime = NumberRange.new(0.4, 0.9)
	dust.Rate = 0
	dust.Parent = att
	dust:Emit(math.clamp(math.floor(speed * 0.8), 4, 20))

	-- Clean up after particles die
	task.delay(1.5, function()
		att:Destroy()
	end)
end

local CRASH_IDS = {"rbxassetid://9119089696", "rbxassetid://9119088927"}

local function playImpactSound(pos: Vector3, speed: number)
	local soundPart = Instance.new("Part")
	soundPart.Anchored = true
	soundPart.CanCollide = false
	soundPart.Transparency = 1
	soundPart.Size = Vector3.one
	soundPart.Position = pos
	soundPart.Parent = workspace

	local sound = Instance.new("Sound")
	sound.SoundId = CRASH_IDS[math.random(1, #CRASH_IDS)]
	sound.Volume = math.clamp(speed / 30, 0.3, 1.0)
	sound.PlaybackSpeed = math.clamp(1.4 - (speed / 60), 0.7, 1.3)
	sound.RollOffMaxDistance = 80
	sound.Parent = soundPart
	sound:Play()

	sound.Ended:Connect(function() soundPart:Destroy() end)
	task.delay(3, function()
		if soundPart.Parent then soundPart:Destroy() end
	end)
end

CartImpact.OnClientEvent:Connect(function(impactPos: Vector3, impactSpeed: number, isRagdoll: boolean)
	-- Scale effects by speed
	local speedFactor = math.clamp(impactSpeed / 30, 0.2, 1.0)

	-- How close is this player to the impact?
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local distFactor = 1.0
	if root and root:IsA("BasePart") then
		local dist = (root.Position - impactPos).Magnitude
		distFactor = math.clamp(1 - dist / 40, 0.1, 1.0)
	end

	-- Screen shake: bigger if you're close or it's a ragdoll hit
	local shakeMag = speedFactor * distFactor * (if isRagdoll then 0.22 else 0.10)
	triggerShake(shakeMag, 0.35)

	-- Sparks and dust at impact point
	spawnImpactSparks(impactPos, impactSpeed)

	-- Sound
	playImpactSound(impactPos, impactSpeed)
end)
