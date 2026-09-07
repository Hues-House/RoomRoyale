-- StarterPlayerScripts > JoinRoundClient
-- Hero "Join Round" CTA (bottom-center). Opts in/out of the round queue.
-- Styled from UITheme; pairs with the gold queue ring (same server queue).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local localPlayer = Players.LocalPlayer
local PlayerGui = localPlayer:WaitForChild("PlayerGui")
local UITheme = require(ReplicatedStorage:WaitForChild("UITheme"))
local Events = ReplicatedStorage:WaitForChild("Events")

local RequestJoinQueue = Events:WaitForChild("RequestJoinQueue")
local RequestLeaveQueue = Events:WaitForChild("RequestLeaveQueue")
local QueueStateChanged = Events:WaitForChild("QueueStateChanged")

-- Create GUI
local sg = Instance.new("ScreenGui")
sg.Name = "JoinRoundGui"
sg.ResetOnSpawn = false
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local button = Instance.new("TextButton")
button.Name = "JoinButton"
button.Size = UDim2.fromOffset(244, 64)
button.AnchorPoint = Vector2.new(1, 1)
button.Position = UDim2.new(1, -18, 1, -104)
button.ZIndex = 50
button.BackgroundColor3 = UITheme.Color.WarmPrimary
button.Text = "Join Round"
button.TextColor3 = UITheme.Color.TextPrimary
button.Font = UITheme.Font.Heavy
button.TextSize = 22
button.AutoButtonColor = false
button.Parent = sg

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(1, 0)
corner.Parent = button

local stroke = Instance.new("UIStroke")
stroke.Color = UITheme.Color.WarmSecondary
stroke.Thickness = 3
stroke.Transparency = 0.1
stroke.Parent = button

-- Soft drop shadow so the CTA pops off the bright hub floor.
local shadow = Instance.new("Frame")
shadow.Name = "Shadow"
shadow.AnchorPoint = Vector2.new(0.5, 0.5)
shadow.Size = UDim2.new(1, 14, 1, 14)
shadow.Position = UDim2.new(0.5, 0, 0.5, 6)
shadow.BackgroundColor3 = UITheme.Color.Overlay
shadow.BackgroundTransparency = 0.86
shadow.BorderSizePixel = 0
shadow.ZIndex = 49
shadow.Parent = button
local shadowCorner = Instance.new("UICorner")
shadowCorner.CornerRadius = UDim.new(1, 0)
shadowCorner.Parent = shadow

sg.Parent = PlayerGui
button.Visible = false  -- Join/Leave is now integrated into the lobby card (LobbyClient)

-- State
local inQueue = false
local queueCount = 0

local function updateUI()
	local phase = localPlayer:GetAttribute("RoundPhase")
	local inRound = phase ~= nil and phase ~= "" and phase ~= "Lobby"
	if inRound then
		sg.Enabled = false
		return
	else
		sg.Enabled = true
	end

	if inQueue then
		button.BackgroundColor3 = UITheme.Color.Blush
		stroke.Color = UITheme.Color.Danger
		button.TextColor3 = UITheme.Color.TextOnDark
		button.Text = "Leave Queue (" .. queueCount .. ")"
	else
		button.BackgroundColor3 = UITheme.Color.WarmPrimary
		stroke.Color = UITheme.Color.WarmSecondary
		button.TextColor3 = UITheme.Color.TextPrimary
		button.Text = "Join Round (" .. queueCount .. ")"
	end
end

-- Events
button.MouseButton1Click:Connect(function()
	if inQueue then
		RequestLeaveQueue:FireServer()
	else
		RequestJoinQueue:FireServer()
	end
end)

button.MouseEnter:Connect(function()
	TweenService:Create(button, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.fromOffset(258, 68)}):Play()
end)

button.MouseLeave:Connect(function()
	TweenService:Create(button, TweenInfo.new(0.12), {Size = UDim2.fromOffset(244, 64)}):Play()
end)

QueueStateChanged.OnClientEvent:Connect(function(list, countdown)
	queueCount = #list
	inQueue = false
	for _, p in ipairs(list) do
		if p.userId == localPlayer.UserId then
			inQueue = true
			break
		end
	end
	
	if countdown then
		if inQueue then
			button.Text = "Starting in " .. countdown .. "s..."
		else
			button.Text = "Join! (" .. countdown .. "s)"
		end
	else
		updateUI()
	end
end)

localPlayer:GetAttributeChangedSignal("RoundPhase"):Connect(updateUI)
updateUI()
