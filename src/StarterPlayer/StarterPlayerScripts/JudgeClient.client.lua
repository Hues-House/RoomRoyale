-- StarterPlayerScripts > JudgeClient
-- Handles theme cards, room tour overlays, token voting, and the reveal screen.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local UITheme = require(ReplicatedStorage:WaitForChild("UITheme"))
local ItemDatabase = require(ReplicatedStorage:WaitForChild("ItemDatabase"))
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Events = ReplicatedStorage:WaitForChild("Events", 15)
local RoundPhaseChanged = Events:WaitForChild("RoundPhaseChanged", 15)
local JudgePhaseStart = Events:WaitForChild("JudgePhaseStart", 15)
local TeleportToRoom = Events:WaitForChild("TeleportToRoom", 15)
local SubmitVote = Events:WaitForChild("SubmitVote", 15)
local VoteReveal = Events:WaitForChild("VoteReveal", 15)

local judgeGui = Instance.new("ScreenGui")
judgeGui.Name = "JudgeGui"
judgeGui.ResetOnSpawn = false
judgeGui.IgnoreGuiInset = true
judgeGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
judgeGui.Parent = playerGui

local judgeScale = Instance.new("UIScale")
judgeScale.Parent = judgeGui

local themeCardNonce = 0
local tourTimerNonce = 0
local voteTimerNonce = 0
local currentVoteOwnerUserId = nil
local hasSubmittedVote = false
local currentJudgeInfo = nil
local selectedVoteTokens = 1

-- Turn a list of item ids (or category/type tokens) into a readable string,
-- preferring the catalog's display Name and falling back to a humanized id.
local function humanizeItemList(list)
	if type(list) ~= "table" or #list == 0 then
		return "\u{2014}"
	end
	local names = {}
	for _, itemId in ipairs(list) do
		local data = ItemDatabase.Get and ItemDatabase.Get(itemId) or nil
		local display = data and data.Name
		if not display then
			display = tostring(itemId):gsub("(%l)(%u)", "%1 %2"):gsub("_", " ")
		end
		names[#names + 1] = display
	end
	return table.concat(names, ", ")
end

local function getSharedThemeAttribute(name)
	local value = ReplicatedStorage:GetAttribute(name)
	if value ~= nil then
		return value
	end
	return game:GetAttribute(name)
end

local function makeCorner(instance, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 12)
	corner.Parent = instance
end

local function makeStroke(instance, color, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness or 1
	stroke.Transparency = 0.84
	stroke.Parent = instance
	return stroke
end

local function makeLabel(parent, name, size, position, text, font, textSize, color, transparency)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = transparency or 1
	label.Text = text or ""
	label.TextColor3 = color or UITheme.Color.TextPrimary
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Font = font or UITheme.Font.Bold
	label.TextSize = textSize or 18
	label.Parent = parent
	return label
end

local root = Instance.new("Frame")
root.Name = "Root"
root.Size = UDim2.fromScale(1, 1)
root.BackgroundTransparency = 1
root.Parent = judgeGui

local backdrop = Instance.new("Frame")
backdrop.Name = "Backdrop"
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.BackgroundColor3 = UITheme.Color.Overlay
backdrop.BackgroundTransparency = 0.8
backdrop.Visible = false
backdrop.Parent = root

local themeCard = Instance.new("Frame")
themeCard.Name = "ThemeCard"
themeCard.Size = UDim2.new(0, 352, 0, 132)
themeCard.Position = UDim2.new(0.5, -176, 0, 70)
themeCard.BackgroundColor3 = UITheme.Color.WarmSurface
themeCard.BackgroundTransparency = 0.18
themeCard.Visible = false
themeCard.Parent = root
makeCorner(themeCard, 22)
makeStroke(themeCard, UITheme.Color.WarmPrimary, 2)

local themeTitle = makeLabel(themeCard, "ThemeTitle", UDim2.new(1, -24, 0, 24), UDim2.new(0, 12, 0, 10), "THIS ROUND", UITheme.Font.Heavy, 18, UITheme.Color.TextPrimary)
local themeSubtitle = makeLabel(themeCard, "ThemeSubtitle", UDim2.new(1, -24, 0, 18), UDim2.new(0, 12, 0, 30), "Shop with this style in mind.", UITheme.Font.Body, 12, UITheme.Color.TextSecondary)

local mechanicalThemeFrame = Instance.new("Frame")
mechanicalThemeFrame.Name = "MechanicalTheme"
mechanicalThemeFrame.Size = UDim2.new(1, -24, 0, 24)
mechanicalThemeFrame.Position = UDim2.new(0, 12, 0, 54)
mechanicalThemeFrame.BackgroundColor3 = UITheme.Color.SurfaceRaised
mechanicalThemeFrame.BackgroundTransparency = 0.3
mechanicalThemeFrame.Parent = themeCard
makeCorner(mechanicalThemeFrame, 14)

local aestheticThemeFrame = Instance.new("Frame")
aestheticThemeFrame.Name = "AestheticTheme"
aestheticThemeFrame.Size = UDim2.new(1, -24, 0, 38)
aestheticThemeFrame.Position = UDim2.new(0, 12, 0, 82)
aestheticThemeFrame.BackgroundColor3 = UITheme.Color.SurfaceRaised
aestheticThemeFrame.BackgroundTransparency = 0.3
aestheticThemeFrame.Parent = themeCard
makeCorner(aestheticThemeFrame, 14)

local mechanicalThemeLabel = makeLabel(mechanicalThemeFrame, "Label", UDim2.new(1, -14, 1, 0), UDim2.new(0, 8, 0, 0), "Theme", UITheme.Font.Bold, 13, UITheme.Color.TextPrimary)
local aestheticThemeLabel = makeLabel(aestheticThemeFrame, "Label", UDim2.new(1, -14, 1, 0), UDim2.new(0, 8, 0, 0), "Goal", UITheme.Font.Bold, 13, UITheme.Color.TextPrimary)

local tourPanel = Instance.new("Frame")
tourPanel.Name = "TourPanel"
tourPanel.Size = UDim2.new(0.7, 0, 0, 90)
tourPanel.AnchorPoint = Vector2.new(0.5, 0)
tourPanel.Position = UDim2.new(0.5, 0, 0, 164)
tourPanel.BackgroundColor3 = UITheme.Color.SurfaceRaised
tourPanel.BackgroundTransparency = 0.18
tourPanel.Visible = false
tourPanel.Parent = root
makeCorner(tourPanel, 20)
makeStroke(tourPanel, UITheme.Color.Stroke, 1.5)

local tourHeader = makeLabel(tourPanel, "TourHeader", UDim2.new(1, -22, 0, 18), UDim2.new(0, 12, 0, 8), "Room Tour", UITheme.Font.Heavy, 14, UITheme.Color.TextSecondary)
local tourTitle = makeLabel(tourPanel, "TourTitle", UDim2.new(1, -82, 0, 26), UDim2.new(0, 12, 0, 26), "", UITheme.Font.Heavy, 20, UITheme.Color.WarmPrimary)
local tourSubtitle = makeLabel(tourPanel, "TourSubtitle", UDim2.new(1, -22, 0, 16), UDim2.new(0, 12, 0, 56), "", UITheme.Font.Body, 11, UITheme.Color.TextSecondary)
local tourTimer = makeLabel(tourPanel, "TourTimer", UDim2.new(0, 60, 0, 18), UDim2.new(1, -74, 0, 28), "15s", UITheme.Font.Bold, 14, UITheme.Color.TextPrimary)
tourTimer.TextXAlignment = Enum.TextXAlignment.Right

local sendBtn = Instance.new("TextButton")
sendBtn.Name = "SendButton"
sendBtn.AnchorPoint = Vector2.new(0.5, 0)
sendBtn.Size = UDim2.new(0, 172, 0, 38)
sendBtn.Position = UDim2.new(0.5, 0, 1, -48)
sendBtn.BackgroundColor3 = UITheme.Color.WarmPrimary
sendBtn.BackgroundTransparency = 0.04
sendBtn.BorderSizePixel = 0
sendBtn.TextColor3 = UITheme.Color.TextOnDark
sendBtn.Font = UITheme.Font.Heavy
sendBtn.TextSize = 15
sendBtn.Text = "Send Shine"
sendBtn.Visible = false
sendBtn.Parent = root
makeCorner(sendBtn, 999)
makeStroke(sendBtn, UITheme.Color.WarmPrimary, 2)

local votePanel = Instance.new("Frame")
votePanel.Name = "VotePanel"
votePanel.Size = UDim2.new(0.88, 0, 0, 216)
votePanel.AnchorPoint = Vector2.new(0.5, 0)
votePanel.Position = UDim2.new(0.5, 0, 1, -232)
votePanel.BackgroundColor3 = UITheme.Color.WarmSurface
votePanel.BackgroundTransparency = 0.16
votePanel.Visible = false
votePanel.Parent = root
makeCorner(votePanel, 24)
makeStroke(votePanel, UITheme.Color.WarmPrimary, 1.5)

local voteTitle = makeLabel(votePanel, "VoteTitle", UDim2.new(1, -86, 0, 24), UDim2.new(0, 14, 0, 10), "SEND SHINE", UITheme.Font.Heavy, 18, UITheme.Color.TextPrimary)
local voteSubtitle = makeLabel(votePanel, "VoteSubtitle", UDim2.new(1, -86, 0, 20), UDim2.new(0, 14, 0, 32), "Pick how much room love to give.", UITheme.Font.Body, 12, UITheme.Color.TextSecondary)
local voteTimer = makeLabel(votePanel, "VoteTimer", UDim2.new(0, 64, 0, 20), UDim2.new(1, -78, 0, 10), "8s", UITheme.Font.Bold, 16, UITheme.Color.TextPrimary)
voteTimer.TextXAlignment = Enum.TextXAlignment.Right

local voteHint = makeLabel(votePanel, "VoteHint", UDim2.new(1, -28, 0, 16), UDim2.new(0, 14, 0, 56), "", UITheme.Font.Bold, 11, UITheme.Color.WarmPrimary)

local tokenRow = Instance.new("Frame")
tokenRow.Name = "TokenRow"
tokenRow.Size = UDim2.new(1, -24, 0, 90)
tokenRow.Position = UDim2.new(0, 12, 0, 82)
tokenRow.BackgroundTransparency = 1
tokenRow.Parent = votePanel

local tokenLayout = Instance.new("UIListLayout")
tokenLayout.FillDirection = Enum.FillDirection.Horizontal
tokenLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
tokenLayout.VerticalAlignment = Enum.VerticalAlignment.Center
tokenLayout.Padding = UDim.new(0.025, 0)
tokenLayout.Parent = tokenRow

local voteStatus = makeLabel(votePanel, "VoteStatus", UDim2.new(1, -28, 0, 18), UDim2.new(0, 14, 1, -28), "Choose a reaction, then send it.", UITheme.Font.Bold, 12, UITheme.Color.TextSecondary)
voteStatus.TextXAlignment = Enum.TextXAlignment.Center

local TOKEN_PRESENTATION = {
	[0] = {emoji = "😐", caption = "Skip", color = UITheme.Color.SurfaceHover, stroke = UITheme.Color.Stroke},
	[1] = {emoji = "👍", caption = "Nice", color = UITheme.Color.SageDim, stroke = UITheme.Color.Sage},
	[2] = {emoji = "💖", caption = "Love", color = UITheme.Color.BlushDim, stroke = UITheme.Color.Blush},
	[3] = {emoji = "⭐", caption = "Star!", color = UITheme.Color.WarmSurface, stroke = UITheme.Color.WarmPrimary},
}

local tokenButtons = {}
for tokens = 0, 3 do
	local config = TOKEN_PRESENTATION[tokens]
	local button = Instance.new("TextButton")
	button.Name = "Token" .. tokens
	button.Size = UDim2.new(0.22, 0, 1, 0)
	button.BackgroundColor3 = config.color
	button.BackgroundTransparency = 0
	button.BorderSizePixel = 0
	button.Text = ""
	button.Parent = tokenRow
	makeCorner(button, 20)
	local stroke = makeStroke(button, config.stroke, tokens == 3 and 2 or 1.5)
	stroke.Name = "TokenStroke"
	stroke.Transparency = tokens == 3 and 0.18 or 0.42

	local emojiLabel = makeLabel(button, "Emoji", UDim2.new(1, 0, 0, 18), UDim2.new(0, 0, 0, 6), config.emoji, UITheme.Font.Bold, 18, UITheme.Color.TextPrimary)
	emojiLabel.TextXAlignment = Enum.TextXAlignment.Center

	local numberLabel = makeLabel(button, "Number", UDim2.new(1, 0, 0, 24), UDim2.new(0, 0, 0, 24), tostring(tokens), UITheme.Font.Heavy, 24, UITheme.Color.TextPrimary)
	numberLabel.TextXAlignment = Enum.TextXAlignment.Center

	local caption = makeLabel(button, "Caption", UDim2.new(1, -6, 0, 14), UDim2.new(0, 3, 1, -18), config.caption, UITheme.Font.Bold, 10, UITheme.Color.TextMuted)
	caption.TextXAlignment = Enum.TextXAlignment.Center

	tokenButtons[tokens] = button
end

local revealPanel = Instance.new("Frame")
revealPanel.Name = "RevealPanel"
revealPanel.Size = UDim2.new(0.88, 0, 0, 400)
revealPanel.AnchorPoint = Vector2.new(0.5, 0.5)
revealPanel.Position = UDim2.new(0.5, 0, 0.5, 0)
revealPanel.BackgroundColor3 = UITheme.Color.SurfaceRaised
revealPanel.BackgroundTransparency = 0.12
revealPanel.Visible = false
revealPanel.Parent = root
makeCorner(revealPanel, 24)
makeStroke(revealPanel, UITheme.Color.WarmPrimary, 2)

local revealTitle = makeLabel(revealPanel, "RevealTitle", UDim2.new(1, -24, 0, 32), UDim2.new(0, 12, 0, 12), "Room Reveal", UITheme.Font.Heavy, 26, UITheme.Color.TextPrimary)
local revealSubtitle = makeLabel(revealPanel, "RevealSubtitle", UDim2.new(1, -24, 0, 22), UDim2.new(0, 12, 0, 44), "", UITheme.Font.Body, 14, UITheme.Color.TextSecondary)

local breakdownFrame = Instance.new("Frame")
breakdownFrame.Name = "Breakdown"
breakdownFrame.Size = UDim2.new(0.5, -18, 1, -82)
breakdownFrame.Position = UDim2.new(0, 12, 0, 76)
breakdownFrame.BackgroundColor3 = UITheme.Color.Surface
breakdownFrame.BackgroundTransparency = 0.12
breakdownFrame.Parent = revealPanel
makeCorner(breakdownFrame, 18)

local leaderboardFrame = Instance.new("Frame")
leaderboardFrame.Name = "Leaderboard"
leaderboardFrame.Size = UDim2.new(0.5, -18, 1, -82)
leaderboardFrame.Position = UDim2.new(0.5, 6, 0, 76)
leaderboardFrame.BackgroundColor3 = UITheme.Color.Surface
leaderboardFrame.BackgroundTransparency = 0.12
leaderboardFrame.Parent = revealPanel
makeCorner(leaderboardFrame, 18)

local breakdownTitle = makeLabel(breakdownFrame, "BreakdownTitle", UDim2.new(1, -24, 0, 28), UDim2.new(0, 12, 0, 10), "Your Score", UITheme.Font.Heavy, 20, UITheme.Color.WarmPrimary)
local scoreLines = {}
for index, labelText in ipairs({"💖 Room Love", "🏷️ Theme Fit", "✨ Style Bonus", "⭐ Total"}) do
	local line = makeLabel(breakdownFrame, "ScoreLine" .. index, UDim2.new(1, -24, 0, 28), UDim2.new(0, 12, 0, 46 + ((index - 1) * 34)), labelText, UITheme.Font.Bold, 17, UITheme.Color.TextPrimary)
	scoreLines[index] = line
end

local matchSummary = makeLabel(breakdownFrame, "MatchSummary", UDim2.new(1, -24, 0, 60), UDim2.new(0, 12, 0, 190), "", UITheme.Font.Body, 13, UITheme.Color.TextSecondary)
matchSummary.TextYAlignment = Enum.TextYAlignment.Top

local votersTitle = makeLabel(breakdownFrame, "VotersTitle", UDim2.new(1, -24, 0, 24), UDim2.new(0, 12, 1, -98), "Shine From", UITheme.Font.Heavy, 18, UITheme.Color.WarmPrimary)
local votersRow = Instance.new("Frame")
votersRow.Name = "VotersRow"
votersRow.Size = UDim2.new(1, -24, 0, 48)
votersRow.Position = UDim2.new(0, 12, 1, -60)
votersRow.BackgroundTransparency = 1
votersRow.Parent = breakdownFrame
local votersLayout = Instance.new("UIListLayout")
votersLayout.FillDirection = Enum.FillDirection.Horizontal
votersLayout.Padding = UDim.new(0, 8)
votersLayout.Parent = votersRow

local leaderboardTitle = makeLabel(leaderboardFrame, "LeaderboardTitle", UDim2.new(1, -24, 0, 28), UDim2.new(0, 12, 0, 10), "Top Rooms", UITheme.Font.Heavy, 20, UITheme.Color.WarmPrimary)
local leaderboardList = Instance.new("Frame")
leaderboardList.Name = "LeaderboardList"
leaderboardList.Size = UDim2.new(1, -24, 1, -52)
leaderboardList.Position = UDim2.new(0, 12, 0, 42)
leaderboardList.BackgroundTransparency = 1
leaderboardList.Parent = leaderboardFrame
local leaderboardLayout = Instance.new("UIListLayout")
leaderboardLayout.Padding = UDim.new(0, 8)
leaderboardLayout.Parent = leaderboardList

local function hideThemeCard()
	themeCard.Visible = false
end

local function showThemeCard()
	local roundLabel = getSharedThemeAttribute("RoundThemeLabel")
	local roundHint = getSharedThemeAttribute("RoundThemeHint")
	local roundPrompt = getSharedThemeAttribute("RoundThemePrompt")
	if type(roundLabel) ~= "string" then
		return
	end

	themeCardNonce += 1
	local nonce = themeCardNonce
	mechanicalThemeLabel.Text = "Theme: " .. roundLabel .. "  •  " .. (roundHint or "")
	aestheticThemeLabel.Text = "Goal: " .. (roundPrompt or "Build the vibe.")
	themeCard.Visible = true
	task.spawn(function()
		task.wait(10)
		if themeCardNonce == nonce then
			hideThemeCard()
		end
	end)
end

local function startTextCountdown(label, duration, nonceKey)
	if nonceKey == "tour" then
		tourTimerNonce += 1
		local nonce = tourTimerNonce
		task.spawn(function()
			for remaining = duration, 0, -1 do
				if tourTimerNonce ~= nonce then
					return
				end
				label.Text = string.format("%ds", remaining)
				if remaining > 0 then
					task.wait(1)
				end
			end
		end)
	else
		voteTimerNonce += 1
		local nonce = voteTimerNonce
		task.spawn(function()
			for remaining = duration, 0, -1 do
				if voteTimerNonce ~= nonce then
					return
				end
				label.Text = string.format("%ds", remaining)
				if remaining > 0 then
					task.wait(1)
				end
			end
		end)
	end
end

local function syncJudgeScale()
	local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
	local minAxis = math.min(viewport.X, viewport.Y)
	judgeScale.Scale = UITheme.GetUIScale()  -- shared touch-aware scaler (scales UP on phones)
end

local function setVoteSelection(tokenCount: number)
	selectedVoteTokens = math.clamp(tokenCount, 0, 3)
	for tokens, button in pairs(tokenButtons) do
		local stroke = button:FindFirstChild("TokenStroke")
		local isSelected = tokens == selectedVoteTokens and button.Active
		-- Scale-based sizing: selected gets a subtle grow via UIScale instead of size swap
		local existingScale = button:FindFirstChildOfClass("UIScale")
		if not existingScale then
			existingScale = Instance.new("UIScale")
			existingScale.Parent = button
		end
		existingScale.Scale = isSelected and 1.06 or 1
		button.BackgroundTransparency = button.Active and (isSelected and 0 or 0.08) or 0.4
		if stroke and stroke:IsA("UIStroke") then
			stroke.Thickness = isSelected and 2.5 or (tokens == 3 and 2 or 1.5)
			stroke.Transparency = button.Active and (isSelected and 0.04 or (tokens == 3 and 0.18 or 0.42)) or 0.7
		end
	end
end

local function setVoteButtonsEnabled(enabled)
	for _, button in pairs(tokenButtons) do
		button.Active = enabled
		button.AutoButtonColor = enabled
	end
	setVoteSelection(selectedVoteTokens)
end

local function submitSelectedVote(tokens: number)
	if hasSubmittedVote or currentVoteOwnerUserId == nil or currentVoteOwnerUserId == player.UserId then
		return
	end
	hasSubmittedVote = true
	setVoteButtonsEnabled(false)
	sendBtn.Visible = false
	voteStatus.Text = string.format("Sent %s %d.", TOKEN_PRESENTATION[tokens].emoji, tokens)
	SubmitVote:FireServer(currentVoteOwnerUserId, tokens)
end

local function hideJudgePanels()
	backdrop.Visible = false
	tourPanel.Visible = false
	votePanel.Visible = false
	revealPanel.Visible = false
	sendBtn.Visible = false
	currentVoteOwnerUserId = nil
	hasSubmittedVote = false
	selectedVoteTokens = 1
	tourTimerNonce += 1
	voteTimerNonce += 1
end

JudgePhaseStart.OnClientEvent:Connect(function(payload)
	currentJudgeInfo = payload
	judgeGui.Enabled = true
	root.Visible = true
	backdrop.Visible = true
	revealPanel.Visible = false
end)

TeleportToRoom.OnClientEvent:Connect(function(payload)
	if payload.stage == "tour" then
		backdrop.Visible = true
		votePanel.Visible = false
		tourPanel.Visible = true
		tourTitle.Text = payload.roomOwnerUserId == player.UserId and "✨ Your Room!" or (payload.roomOwnerName .. "'s Room")
		tourSubtitle.Text = string.format("Look around • Room %d of %d", payload.roomIndex, payload.roomCount)
		startTextCountdown(tourTimer, payload.duration or 15, "tour")
		return
	end

	if payload.stage == "vote" then
		backdrop.Visible = true
		tourPanel.Visible = false
		votePanel.Visible = true
		currentVoteOwnerUserId = payload.roomOwnerUserId
		hasSubmittedVote = false
		local isOwnRoom = payload.roomOwnerUserId == player.UserId
		voteTitle.Text = isOwnRoom and "YOUR ROOM" or ("SHINE FOR " .. string.upper(payload.roomOwnerName))
		voteSubtitle.Text = string.format("Choose 0 to %d shine.", payload.tokensPerRoom or 3)
		voteHint.Text = payload.nextRoomOwnerName and ("Next room: " .. payload.nextRoomOwnerName) or "Reveal next"
		selectedVoteTokens = 1
		voteStatus.Text = isOwnRoom and "🪞 Your room is on display." or "Pick a reaction, then hit Send."
		setVoteButtonsEnabled(not isOwnRoom)
		setVoteSelection(isOwnRoom and 0 or 1)
		sendBtn.Visible = not isOwnRoom
		sendBtn.Parent = votePanel
		startTextCountdown(voteTimer, payload.duration or 8, "vote")
	end
end)

for tokens, button in pairs(tokenButtons) do
	button.MouseButton1Click:Connect(function()
		setVoteSelection(tokens)
	end)
end

sendBtn.MouseButton1Click:Connect(function()
	submitSelectedVote(selectedVoteTokens)
end)

UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed or not votePanel.Visible or hasSubmittedVote or currentVoteOwnerUserId == nil or currentVoteOwnerUserId == player.UserId then
		return
	end

	local keyCode = input.KeyCode
	if keyCode == Enum.KeyCode.Left or keyCode == Enum.KeyCode.DPadLeft or keyCode == Enum.KeyCode.ButtonL1 then
		setVoteSelection(math.max(selectedVoteTokens - 1, 0))
		return
	end
	if keyCode == Enum.KeyCode.Right or keyCode == Enum.KeyCode.DPadRight or keyCode == Enum.KeyCode.ButtonR1 then
		setVoteSelection(math.min(selectedVoteTokens + 1, 3))
		return
	end
	if keyCode == Enum.KeyCode.Return or keyCode == Enum.KeyCode.Space or keyCode == Enum.KeyCode.ButtonA then
		if not hasSubmittedVote then
			submitSelectedVote(selectedVoteTokens)
		end
	end
end)

local function clearChildren(frame)
	for _, child in ipairs(frame:GetChildren()) do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
end

local function addVoterIcon(voter)
	local card = Instance.new("Frame")
	card.Size = UDim2.new(0, 48, 1, 0)
	card.BackgroundTransparency = 1
	card.Parent = votersRow

	local image = Instance.new("ImageLabel")
	image.Size = UDim2.new(0, 34, 0, 34)
	image.Position = UDim2.new(0.5, -17, 0, 0)
	image.BackgroundColor3 = UITheme.Color.WarmSurface
	image.BorderSizePixel = 0
	image.Image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=100&h=100", voter.userId)
	image.Parent = card
	makeCorner(image, 17)

	local reaction = makeLabel(card, "Reaction", UDim2.new(0, 18, 0, 18), UDim2.new(1, -16, 0, -2), TOKEN_PRESENTATION[math.clamp(voter.tokens or 0, 0, 3)].emoji, UITheme.Font.Bold, 14, UITheme.Color.TextPrimary)
	reaction.BackgroundColor3 = UITheme.Color.SurfaceRaised
	reaction.BackgroundTransparency = 0.08
	reaction.ZIndex = 3
	makeCorner(reaction, 9)
	UITheme.AddStroke(reaction, UITheme.Color.Stroke, 1, 0.35)
	reaction.TextXAlignment = Enum.TextXAlignment.Center

	local nameLabel = makeLabel(card, "Name", UDim2.new(1, 0, 0, 12), UDim2.new(0, 0, 1, -12), string.format("+%d", voter.tokens), UITheme.Font.Bold, 12, UITheme.Color.WarmPrimary)
	nameLabel.TextXAlignment = Enum.TextXAlignment.Center
end

local function addLeaderboardRow(entry)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 44)
	row.BackgroundColor3 = entry.userId == player.UserId and UITheme.Color.SurfaceHover or UITheme.Color.Surface
	row.Parent = leaderboardList
	makeCorner(row, 14)

	local rankLabel = ({[1] = "🥇", [2] = "🥈", [3] = "🥉"})[entry.rank] or string.format("#%d", entry.rank or 0)
	local label = makeLabel(row, "Label", UDim2.new(1, -20, 1, 0), UDim2.new(0, 10, 0, 0), string.format("%s  %s   %d", rankLabel, entry.name, entry.total), UITheme.Font.Bold, 18, UITheme.Color.TextPrimary)
	label.TextXAlignment = Enum.TextXAlignment.Left
end

local function fillLeaderboard(entries)
	clearChildren(leaderboardList)

	local shownOwnRow = false
	for index, entry in ipairs(entries) do
		if index <= 5 then
			addLeaderboardRow(entry)
			shownOwnRow = shownOwnRow or entry.userId == player.UserId
		end
	end

	if not shownOwnRow then
		for _, entry in ipairs(entries) do
			if entry.userId == player.UserId then
				addLeaderboardRow(entry)
				break
			end
		end
	end
end

VoteReveal.OnClientEvent:Connect(function(payload)
	hideJudgePanels()
	backdrop.Visible = true
	revealPanel.Visible = true
	revealPanel.BackgroundTransparency = 1
	revealPanel.Position = UDim2.new(0.5, 0, 0.62, 0)
	TweenService:Create(revealPanel, TweenInfo.new(0.38, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0.5, 0),
		BackgroundTransparency = 0.12,
	}):Play()

	local personal = payload and payload.personal
	if not personal then return end
	print(("[JudgeClient] reveal: voters=%d leaderboard=%s"):format(#(personal.voters or {}), tostring(payload.leaderboard and #payload.leaderboard or "nil")))
	local medalLabel = nil
	if personal.rank then
		medalLabel = ({[1] = "🥇", [2] = "🥈", [3] = "🥉"})[personal.rank] or string.format("#%d", personal.rank)
	end
	revealTitle.Text = medalLabel and string.format("Room Reveal  •  %s", medalLabel) or "Room Reveal"
	local mechTheme = payload.mechanicalTheme or {}
	if mechTheme.prompt and mechTheme.prompt ~= "" then
		revealSubtitle.Text = string.format("%s  •  %s", mechTheme.label or "", mechTheme.prompt)
	else
		revealSubtitle.Text = mechTheme.label or ""
	end
	local scoreTextValues = {
		string.format("💖 Room Love   +%d", personal.aesthetic),
		string.format("🏷️ Theme Fit   +%d", personal.mechanical),
		string.format("✨ Style Bonus   +%d", personal.participation),
		string.format("⭐ Total   %d", personal.total),
	}
	for index, line in ipairs(scoreLines) do
		line.Text = ""
		line.TextTransparency = 1
		task.delay((index - 1) * 0.12, function()
			if not revealPanel.Visible then
				return
			end
			line.Text = scoreTextValues[index]
			TweenService:Create(line, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				TextTransparency = 0,
			}):Play()
		end)
	end

	local matched = personal.mechanicalBreakdown
	if matched then
		if matched.requiredMet then
			local summaryParts = {
				"Anchor: " .. humanizeItemList(matched.matchedRequired or {}),
			}
			if #(matched.matchedBonus or {}) > 0 then
				table.insert(summaryParts, "Bonus: " .. humanizeItemList(matched.matchedBonus))
			end
			if #(matched.themeMatches or {}) > 0 then
				table.insert(summaryParts, "Theme hits: " .. humanizeItemList(matched.themeMatches))
			end
			if #(matched.rarityHighlights or {}) > 0 then
				table.insert(summaryParts, "Rare finds: " .. table.concat(matched.rarityHighlights, ", "))
			end
			matchSummary.Text = table.concat(summaryParts, "  •  ")
		else
			matchSummary.Text = "Need: " .. humanizeItemList(matched.missingRequired or {})
		end
	else
		matchSummary.Text = ""
	end

	local okFill, fillErr = pcall(function()
	clearChildren(votersRow)
	if #personal.voters == 0 then
		local empty = makeLabel(votersRow, "Empty", UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), "No shine this round.", UITheme.Font.Bold, 15, UITheme.Color.TextSecondary)
		empty.TextXAlignment = Enum.TextXAlignment.Left
	else
		for _, voter in ipairs(personal.voters) do
			addVoterIcon(voter)
		end
	end

	fillLeaderboard(payload.leaderboard)
	end)
	if not okFill then warn("[JudgeClient] reveal fill failed: " .. tostring(fillErr)) end
	for index, child in ipairs(leaderboardList:GetChildren()) do
		if child:IsA("Frame") then
			child.BackgroundTransparency = 1
			local label = child:FindFirstChild("Label")
			if label and label:IsA("TextLabel") then
				label.TextTransparency = 1
			end
			task.delay((index - 1) * 0.08, function()
				if not child.Parent then
					return
				end
				TweenService:Create(child, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					BackgroundTransparency = 0,
				}):Play()
				if label and label.Parent then
					TweenService:Create(label, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						TextTransparency = 0,
					}):Play()
				end
			end)
		end
	end
end)

game.Players.LocalPlayer:GetAttributeChangedSignal("RoundPhase"):Connect(function()
	local phase = game.Players.LocalPlayer:GetAttribute("RoundPhase") or "Lobby"
	-- The reveal panel is populated by VoteReveal while the phase is still Judge, but it
	-- exists to be READ during Results. Hiding on every non-Judge phase wiped the final
	-- scores the instant the round ended, so nobody ever saw them. Results keeps it up;
	-- returning to the lobby clears RoundPhase and hides it here.
	-- Shop and Style used to return early before reaching the hide, which left a stale
	-- reveal panel up if a round went Judge straight into the next Shop.
	if phase ~= "Judge" and phase ~= "Results" then
		hideJudgePanels()
		hideThemeCard()
	end
end)

syncJudgeScale()
local currentCamera = workspace.CurrentCamera
if currentCamera then
	currentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(syncJudgeScale)
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(syncJudgeScale)

ReplicatedStorage:GetAttributeChangedSignal("RoundThemeLabel"):Connect(function()
	hideThemeCard()
end)

hideThemeCard()

print("[JudgeClient] Loaded")
