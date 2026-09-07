-- StarterPlayerScripts > FtueController
-- First-time user experience. ONE contextual hint (top-center, under the objective banner)
-- that opens with the game's goal and advances by phase through the loop:
--   Lobby → Shop → Style → Judge → Results.
-- Light steering (gentle pulse + 👇 toward Play), non-gating. Shows ONLY for new players
-- (snapshot.roundsFinished == 0) and stops the moment they finish their first round.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local UITheme = require(ReplicatedStorage:WaitForChild("UITheme"))
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Events = ReplicatedStorage:WaitForChild("Events", 15)
local GetProgressionSnapshot = Events:WaitForChild("GetProgressionSnapshot", 15)
local ProgressionUpdated = Events:FindFirstChild("ProgressionUpdated")

local active = true  -- false once the player has finished a round (no longer "new")

local HINTS = {
	Lobby   = "👇 New here? Tap Play to start your first styling round!",  -- banner already states the goal; this just steers
	Shop    = "🛒 Drive your cart and grab furniture that fits the theme!",
	Style   = "🎨 Decorate to the theme — place furniture and paint your walls!",
	Judge   = "⭐ Tour each room and vote for your favorites!",
	Results = "🎉 Nice — you styled your first room and earned Style Bucks!",
}

local gui = Instance.new("ScreenGui")
gui.Name = "FtueGui"; gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling; gui.DisplayOrder = 20
gui.Enabled = false; gui.Parent = playerGui
UITheme.ApplySafeArea(gui)
UITheme.AttachScale(gui)

local card = Instance.new("Frame")
card.Name = "HintCard"; card.AnchorPoint = Vector2.new(0.5, 0)
card.Size = UDim2.new(0, 380, 0, 62); card.Position = UDim2.new(0.5, 0, 0, 108)
card.BackgroundColor3 = UITheme.Color.WarmPrimary; card.BackgroundTransparency = 0.04
card.BorderSizePixel = 0; card.Parent = gui
UITheme.AddCorner(card, UITheme.Radius.Large)
UITheme.AddStroke(card, Color3.fromRGB(255, 253, 248), 1.5, 0.4)

local stepLabel = Instance.new("TextLabel")
stepLabel.Name = "Step"; stepLabel.BackgroundTransparency = 1
stepLabel.Size = UDim2.new(1, -28, 1, -14); stepLabel.Position = UDim2.new(0, 14, 0, 7)
stepLabel.Font = UITheme.Font.Heavy; stepLabel.TextColor3 = Color3.fromRGB(255, 253, 248)
stepLabel.TextScaled = true; stepLabel.TextWrapped = true; stepLabel.Text = ""
stepLabel.Parent = card
local sizeC = Instance.new("UITextSizeConstraint"); sizeC.MaxTextSize = 18; sizeC.Parent = stepLabel

-- Gentle pulse to draw the eye without nagging.
TweenService:Create(card, TweenInfo.new(1.0, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
	{ BackgroundTransparency = 0.24 }):Play()

local function refresh()
	if not active then gui.Enabled = false; return end
	local phase = player:GetAttribute("RoundPhase") or "Lobby"
	stepLabel.Text = HINTS[phase] or HINTS.Lobby
	gui.Enabled = true
end

local function applySnapshot(snap)
	if type(snap) == "table" and type(snap.roundsFinished) == "number" and snap.roundsFinished > 0 then
		active = false
	end
	refresh()
end

task.spawn(function()
	local ok, snap = pcall(function() return GetProgressionSnapshot:InvokeServer() end)
	if ok then applySnapshot(snap) else refresh() end
end)

if ProgressionUpdated and ProgressionUpdated:IsA("RemoteEvent") then
	ProgressionUpdated.OnClientEvent:Connect(applySnapshot)
end
player:GetAttributeChangedSignal("RoundPhase"):Connect(refresh)

print("[FtueController] Loaded")
