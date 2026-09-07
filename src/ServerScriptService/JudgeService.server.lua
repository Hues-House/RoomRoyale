-- ServerScriptService > JudgeService
-- Runs the room tour, collects appreciation tokens, and reveals round scores.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local ServerScriptService = game:GetService("ServerScriptService")

local ThemeDatabase = require(ReplicatedStorage:WaitForChild("ThemeDatabase", 15))
local ItemDatabase = require(ReplicatedStorage:WaitForChild("ItemDatabase", 15))
local ProgressionService = require(ServerScriptService:WaitForChild("ProgressionService"))

local Events = ReplicatedStorage:WaitForChild("Events", 15)

local function getOrCreate(className, name)
	local existing = Events:FindFirstChild(name)
	if existing then
		return existing
	end

	local created = Instance.new(className)
	created.Name = name
	created.Parent = Events
	return created
end

local JudgePhaseStart = getOrCreate("RemoteEvent", "JudgePhaseStart")
local TeleportToRoom = getOrCreate("RemoteEvent", "TeleportToRoom")
local SubmitVote = getOrCreate("RemoteEvent", "SubmitVote")
local VoteReveal = getOrCreate("RemoteEvent", "VoteReveal")
local RunJudgeSequence = getOrCreate("BindableFunction", "RunJudgeSequence")

local CFG = {
	ROOM_TOUR_DURATION = 15,
	VOTE_DURATION = 8,
	REVEAL_DURATION = 8,
	TOKENS_PER_ROOM = 3,
	PARTICIPATION_BONUS = 2,
}

-- Per-round judge state, keyed by roundId, so concurrent lobbies never clobber each
-- other. Previously a single global broke the moment two rounds judged at once: the
-- second round overwrote/cleared it, the first crashed indexing nil.roomOrder, and the
-- tour teleported BOTH lobbies' players to the same rooms.
local judgeStates: {[string]: any} = {}    -- [roundId] = state
local stateByUserId: {[number]: any} = {}   -- [userId]  = state (routes votes + cleanup)

local function fireCohortClients(event, cohort, payload)
	for _, player in ipairs(cohort) do
		if player and player.Parent == Players then
			event:FireClient(player, payload)
		end
	end
end

local function isCohortJudging(cohort): boolean
	for _, player in ipairs(cohort) do
		if player and player.Parent == Players and player:GetAttribute("RoundPhase") == "Judge" then
			return true
		end
	end
	return false
end

local function getDisplayName(player)
	if not player then
		return "Player"
	end
	if player.DisplayName and player.DisplayName ~= "" then
		return player.DisplayName
	end
	return player.Name
end

local function getPlayerByUserId(userId)
	for _, player in ipairs(Players:GetPlayers()) do
		if player.UserId == userId then
			return player
		end
	end
	return nil
end

local function shufflePlayers(list)
	local shuffled = table.clone(list)
	local randomSource = Random.new(math.floor(os.clock() * 1000) % 1000000)
	for index = #shuffled, 2, -1 do
		local swapIndex = randomSource:NextInteger(1, index)
		shuffled[index], shuffled[swapIndex] = shuffled[swapIndex], shuffled[index]
	end
	return shuffled
end

local function getRoomForUserId(userId)
	return workspace:FindFirstChild("StyleRoom_" .. userId)
end

local function createRoomEntry(player)
	return {
		userId = player.UserId,
		name = getDisplayName(player),
	}
end

local function getEligibleRoomOwners(cohort)
	local owners = {}
	for _, player in ipairs(cohort) do
		if player and player.Parent == Players and getRoomForUserId(player.UserId) then
			table.insert(owners, createRoomEntry(player))
		end
	end
	return shufflePlayers(owners)
end

local TELEPORT_OFFSETS = {
	Vector3.new(0, 0, 0),
	Vector3.new(6, 0, -1),
	Vector3.new(-6, 0, -1),
	Vector3.new(12, 0, -2),
	Vector3.new(-12, 0, -2),
	Vector3.new(18, 0, -3),
	Vector3.new(-18, 0, -3),
	Vector3.new(0, 0, -5),
}

local function wakeCharacterForTeleport(player: Player, character: Model, humanoid: Humanoid, root: BasePart)
	character:SetAttribute("InCart", false)
	for _, cart in ipairs(CollectionService:GetTagged("PlayerCart")) do
		if cart:GetAttribute("OwnerUserId") == player.UserId then
			cart:Destroy()
		end
	end
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BallSocketConstraint") and descendant.Name == "RagdollBSC" then
			descendant:Destroy()
		elseif descendant:IsA("Attachment") and (descendant.Name == "RagdollAtt0" or descendant.Name == "RagdollAtt1") then
			descendant:Destroy()
		elseif descendant:IsA("Motor6D") and not descendant.Enabled then
			descendant.Enabled = true
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = false
			pcall(function()
				descendant:SetNetworkOwner(player)
			end)
		end
	end
	root.Anchored = false
	humanoid.RequiresNeck = true
	humanoid.Sit = false
	humanoid.PlatformStand = false
	humanoid.AutoRotate = true
	if humanoid.WalkSpeed < 16 then
		humanoid.WalkSpeed = 16
	end
	if humanoid.UseJumpPower then
		if humanoid.JumpPower <= 0 then
			humanoid.JumpPower = 50
		end
	else
		if humanoid.JumpHeight <= 0 then
			humanoid.JumpHeight = 7.2
		end
	end
	for _, state in ipairs({
		Enum.HumanoidStateType.Seated,
		Enum.HumanoidStateType.Running,
		Enum.HumanoidStateType.RunningNoPhysics,
		Enum.HumanoidStateType.Jumping,
		Enum.HumanoidStateType.Freefall,
		Enum.HumanoidStateType.FallingDown,
		Enum.HumanoidStateType.GettingUp,
		Enum.HumanoidStateType.Climbing,
		Enum.HumanoidStateType.Swimming,
	}) do
		humanoid:SetStateEnabled(state, true)
	end
	humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	task.defer(function()
		if humanoid.Parent then
			humanoid:ChangeState(Enum.HumanoidStateType.Running)
		end
	end)
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
end

local function teleportPlayersToRoom(ownerEntry, audience)
	local room = getRoomForUserId(ownerEntry.userId)
	if not room then
		return false
	end

	local floor = room:FindFirstChild("Floor")
	local spawnPart = room:FindFirstChild("SpawnPart")
	if not (floor and floor:IsA("BasePart")) and not (spawnPart and spawnPart:IsA("BasePart")) then
		return false
	end

	local anchorPart = if spawnPart and spawnPart:IsA("BasePart") then spawnPart else (floor :: BasePart)
	local lookTarget = anchorPart.Position + Vector3.new(0, 2, -6)
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Include
	rayParams.FilterDescendantsInstances = {room}

	for index, viewer in ipairs(audience) do
		local character = viewer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if character and humanoid and root and root:IsA("BasePart") then
			wakeCharacterForTeleport(viewer, character, humanoid, root)
			local standHeight = math.max(5, humanoid.HipHeight + (root.Size.Y * 0.5) + 3)

			local offset = TELEPORT_OFFSETS[((index - 1) % #TELEPORT_OFFSETS) + 1]
			local basePos
			if spawnPart and spawnPart:IsA("BasePart") then
				basePos = (spawnPart.CFrame * CFrame.new(offset)).Position
			else
				basePos = ((floor :: BasePart).CFrame * CFrame.new(offset.X, (floor :: BasePart).Size.Y * 0.5 + 2, ((floor :: BasePart).Size.Z * 0.5) - 6 + offset.Z)).Position
			end

			local rayOrigin = basePos + Vector3.new(0, 6, 0)
			local floorHit = workspace:Raycast(rayOrigin, Vector3.new(0, -80, 0), rayParams)
			local targetPos = basePos + Vector3.new(0, standHeight, 0)
			if floorHit then
				targetPos = Vector3.new(basePos.X, floorHit.Position.Y + standHeight, basePos.Z)
			end

			character:PivotTo(CFrame.lookAt(targetPos, lookTarget))
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero

			task.delay(0.18, function()
				if not character.Parent or not root.Parent then
					return
				end
				-- Start the correction ray BELOW the room ceiling, or it hits the ceiling
				-- top (a room descendant) from above and plants the player on the roof.
				local correctionHit = workspace:Raycast(Vector3.new(targetPos.X, basePos.Y + 6, targetPos.Z), Vector3.new(0, -60, 0), rayParams)
				if correctionHit and root.Position.Y < correctionHit.Position.Y + 3 then
					character:PivotTo(CFrame.lookAt(Vector3.new(targetPos.X, correctionHit.Position.Y + standHeight, targetPos.Z), lookTarget))
					root.AssemblyLinearVelocity = Vector3.zero
					root.AssemblyAngularVelocity = Vector3.zero
				end
			end)
		end
	end

	return true
end

local function waitForJudgeSeconds(cohort, seconds, continuePredicate)
	for _ = 1, seconds do
		if not isCohortJudging(cohort) then
			return false, "phase"
		end
		if continuePredicate and not continuePredicate() then
			return false, "invalid"
		end
		task.wait(1)
	end
	return true, "done"
end

local function getThemeState()
	local mechanical = ThemeDatabase.GetMechanicalTheme(game:GetAttribute("MechanicalThemeId"))
	local aesthetic = ThemeDatabase.GetAestheticTheme(game:GetAttribute("AestheticThemeId"))
	if mechanical and aesthetic then
		return mechanical, aesthetic
	end

	local fallbackPair = ThemeDatabase.RollThemePair()
	return fallbackPair.mechanical, fallbackPair.aesthetic
end

local function getPlacedItemSet(userId)
	local room = getRoomForUserId(userId)
	local placedItems = room and room:FindFirstChild("PlacedItems")
	local itemSet = {}
	if not placedItems then
		return itemSet
	end

	for _, child in ipairs(placedItems:GetChildren()) do
		local itemId = child:GetAttribute("ItemId")
		if type(itemId) == "string" and itemId ~= "" then
			itemSet[itemId] = true
		elseif child.Name ~= "" then
			itemSet[child.Name:gsub("_placed$", "")] = true
		end
	end

	return itemSet
end

local function scoreMechanicalTheme(userId, theme)
	local itemSet = getPlacedItemSet(userId)
	local matchedRequired = {}
	local missingRequired = {}
	local matchedBonus = {}
	local anchorLookup = {}
	local themeMatches = {}
	local rareHighlights = {}

	for _, itemId in ipairs(theme.required or {}) do
		if itemSet[itemId] then
			table.insert(matchedRequired, itemId)
			anchorLookup[itemId] = true
		else
			table.insert(missingRequired, itemId)
		end
	end

	local requiredMet = #missingRequired == 0
	if requiredMet then
		for _, itemId in ipairs(theme.bonus or {}) do
			if itemSet[itemId] then
				table.insert(matchedBonus, itemId)
				anchorLookup[itemId] = true
			end
		end
	end

	for itemId in pairs(itemSet) do
		local data = ItemDatabase.Get(itemId)
		if data and ItemDatabase.MatchesTheme(itemId, theme.id) and not anchorLookup[itemId] then
			table.insert(themeMatches, itemId)
		end
		local rarityValue = ItemDatabase.GetRarityStyleValue(itemId)
		if data and rarityValue > 0 then
			table.insert(rareHighlights, {
				itemId = itemId,
				value = rarityValue,
				rarity = data.Rarity,
			})
		end
	end

	table.sort(themeMatches)
	table.sort(rareHighlights, function(a, b)
		if a.value == b.value then
			return a.itemId < b.itemId
		end
		return a.value > b.value
	end)

	local anchorScore = requiredMet and (#matchedRequired + #matchedBonus) or 0
	local themeAffinityScore = math.min(requiredMet and 4 or 2, #themeMatches)
	local rarityScore = 0
	local rarityNames = {}
	for index, info in ipairs(rareHighlights) do
		if index > (requiredMet and 2 or 1) then
			break
		end
		rarityScore += info.value
		table.insert(rarityNames, info.itemId .. " (" .. info.rarity .. ")")
	end
	local styleBonus = CFG.PARTICIPATION_BONUS + themeAffinityScore + rarityScore

	return {
		score = anchorScore,
		anchorScore = anchorScore,
		styleBonus = styleBonus,
		themeAffinityScore = themeAffinityScore,
		rarityScore = rarityScore,
		requiredMet = requiredMet,
		matchedRequired = matchedRequired,
		missingRequired = missingRequired,
		matchedBonus = matchedBonus,
		themeMatches = themeMatches,
		rarityHighlights = rarityNames,
	}
end

local function isParticipantUserId(state, userId)
	return state ~= nil and state.participantUserIds[userId] == true
end

local function createVoteWindow(state, ownerEntry)
	state.currentVote = {
		ownerUserId = ownerEntry.userId,
		votes = {},
		submitted = {},
	}
end

local function closeVoteWindow(state)
	local currentVote = state and state.currentVote
	if not currentVote then
		return
	end

	state.roomVotes[currentVote.ownerUserId] = table.clone(currentVote.votes)
	state.currentVote = nil
end

SubmitVote.OnServerEvent:Connect(function(player, ownerUserId, tokenCount)
	local state = stateByUserId[player.UserId]
	if not state or not state.currentVote then
		return
	end
	if typeof(ownerUserId) ~= "number" then
		return
	end
	if state.currentVote.ownerUserId ~= ownerUserId then
		return
	end
	if not isParticipantUserId(state, player.UserId) or not isParticipantUserId(state, ownerUserId) then
		return
	end
	if player.UserId == ownerUserId then
		return
	end
	if state.currentVote.submitted[player.UserId] then
		return
	end

	local amount = math.clamp(math.floor(tonumber(tokenCount) or 0), 0, CFG.TOKENS_PER_ROOM)
	state.currentVote.submitted[player.UserId] = true
	state.currentVote.votes[player.UserId] = amount
end)

local function buildLeaderboard(scoreByUserId)
	local leaderboard = {}
	for userId, entry in pairs(scoreByUserId) do
		table.insert(leaderboard, {
			userId = userId,
			name = entry.name,
			aesthetic = entry.aesthetic,
			mechanical = entry.mechanical,
			participation = entry.participation,
			total = entry.total,
		})
	end

	table.sort(leaderboard, function(a, b)
		if a.total == b.total then
			if a.aesthetic == b.aesthetic then
				return a.name < b.name
			end
			return a.aesthetic > b.aesthetic
		end
		return a.total > b.total
	end)

	for index, entry in ipairs(leaderboard) do
		entry.rank = index
	end

	return leaderboard
end

local function buildRevealData(state, mechanicalTheme, aestheticTheme)
	local scoreByUserId = {}
	for _, ownerEntry in ipairs(state.roomOrder) do
		local userId = ownerEntry.userId
		local roomVotes = state.roomVotes[userId] or {}
		local aestheticScore = 0
		local voters = {}
		for voterUserId, amount in pairs(roomVotes) do
			aestheticScore += amount
			if amount > 0 then
				local voter = getPlayerByUserId(voterUserId)
				table.insert(voters, {
					userId = voterUserId,
					name = voter and getDisplayName(voter) or ("Player " .. voterUserId),
					tokens = amount,
				})
			end
		end

		table.sort(voters, function(a, b)
			if a.tokens == b.tokens then
				return a.name < b.name
			end
			return a.tokens > b.tokens
		end)

		local mechanicalBreakdown = scoreMechanicalTheme(userId, mechanicalTheme)
		local participation = mechanicalBreakdown.styleBonus
		scoreByUserId[userId] = {
			userId = userId,
			name = ownerEntry.name,
			aesthetic = aestheticScore,
			mechanical = mechanicalBreakdown.score,
			participation = participation,
			total = aestheticScore + mechanicalBreakdown.score + participation,
			voters = voters,
			mechanicalBreakdown = mechanicalBreakdown,
		}
	end

	local leaderboard = buildLeaderboard(scoreByUserId)
	for _, entry in ipairs(leaderboard) do
		if scoreByUserId[entry.userId] then
			scoreByUserId[entry.userId].rank = entry.rank
		end
	end
	return scoreByUserId, leaderboard
end

local function fireReveal(state, mechanicalTheme, aestheticTheme)
	local scoreByUserId, leaderboard = buildRevealData(state, mechanicalTheme, aestheticTheme)
	if state and state.roundNumber then
		ProgressionService.AwardRoundResults(state.roundNumber, scoreByUserId, leaderboard)
	end
	for _, player in ipairs(state.cohort) do
		if not (player and player.Parent == Players) then continue end
		local personal = scoreByUserId[player.UserId] or {
			rank = nil,
			userId = player.UserId,
			name = getDisplayName(player),
			aesthetic = 0,
			mechanical = 0,
			participation = CFG.PARTICIPATION_BONUS,
			total = CFG.PARTICIPATION_BONUS,
			voters = {},
			mechanicalBreakdown = {
				score = 0,
				anchorScore = 0,
				styleBonus = CFG.PARTICIPATION_BONUS,
				themeAffinityScore = 0,
				rarityScore = 0,
				requiredMet = false,
				matchedRequired = {},
				missingRequired = mechanicalTheme.required or {},
				matchedBonus = {},
				themeMatches = {},
				rarityHighlights = {},
			},
		}

		VoteReveal:FireClient(player, {
			mechanicalTheme = {
				id = mechanicalTheme.id,
				label = mechanicalTheme.label,
				hint = mechanicalTheme.hint,
				prompt = mechanicalTheme.prompt,
				required = mechanicalTheme.required,
				bonus = mechanicalTheme.bonus,
			},
			aestheticTheme = {
				id = aestheticTheme.id,
				label = aestheticTheme.label,
				hint = aestheticTheme.hint,
			},
			personal = personal,
			leaderboard = leaderboard,
			revealDuration = CFG.REVEAL_DURATION,
		})
	end
end

local function runJudgeSequence(roundId, cohort, themeIds)
	cohort = cohort or {}
	local players = {}
	for _, p in ipairs(cohort) do
		if p and p.Parent == Players then table.insert(players, p) end
	end
	if not isCohortJudging(players) then
		warn("[JudgeService] Invoked but no cohort player is in Judge phase (round " .. tostring(roundId) .. ")")
		return false
	end

	local roomOrder = getEligibleRoomOwners(players)
	if #roomOrder == 0 then
		warn("[JudgeService] No style rooms found for Judge phase (round " .. tostring(roundId) .. ")")
		return false
	end

	-- Resolve this round's OWN theme (themeIds passed by RoundManager). The global game
	-- theme attributes are shared and get overwritten by concurrent rounds, so we must not
	-- rely on them for scoring; fall back to them only if no per-round ids were supplied.
	local mechanicalTheme, aestheticTheme
	if themeIds and themeIds.mechanicalId and themeIds.aestheticId then
		mechanicalTheme = ThemeDatabase.GetMechanicalTheme(themeIds.mechanicalId)
		aestheticTheme = ThemeDatabase.GetAestheticTheme(themeIds.aestheticId)
	end
	if not (mechanicalTheme and aestheticTheme) then
		mechanicalTheme, aestheticTheme = getThemeState()
	end

	local participantUserIds = {}
	for _, entry in ipairs(roomOrder) do
		participantUserIds[entry.userId] = true
	end

	local state = {
		roundId = roundId,
		roundNumber = roundId,
		cohort = players,
		roomOrder = roomOrder,
		roomVotes = {},
		currentVote = nil,
		participantUserIds = participantUserIds,
	}
	judgeStates[roundId] = state
	for userId in pairs(participantUserIds) do
		stateByUserId[userId] = state
	end

	local function cleanup()
		judgeStates[roundId] = nil
		for userId in pairs(participantUserIds) do
			if stateByUserId[userId] == state then
				stateByUserId[userId] = nil
			end
		end
	end

	fireCohortClients(JudgePhaseStart, players, {
		roundNumber = roundId,
		roomCount = #roomOrder,
		roomSeconds = CFG.ROOM_TOUR_DURATION,
		voteSeconds = CFG.VOTE_DURATION,
		tokensPerRoom = CFG.TOKENS_PER_ROOM,
		mechanicalTheme = mechanicalTheme,
		aestheticTheme = aestheticTheme,
	})

	local shownRoomIndex = 0
	for queueIndex, ownerEntry in ipairs(roomOrder) do
		local function roomStillValid()
			return isParticipantUserId(state, ownerEntry.userId) and getRoomForUserId(ownerEntry.userId) ~= nil
		end

		if not roomStillValid() then
			continue
		end

		shownRoomIndex += 1
		teleportPlayersToRoom(ownerEntry, players)
		fireCohortClients(TeleportToRoom, players, {
			stage = "tour",
			roomIndex = shownRoomIndex,
			roomCount = #roomOrder,
			duration = CFG.ROOM_TOUR_DURATION,
			roomOwnerUserId = ownerEntry.userId,
			roomOwnerName = ownerEntry.name,
			nextRoomOwnerName = roomOrder[queueIndex + 1] and roomOrder[queueIndex + 1].name or "Results",
		})
		local completedTour, tourReason = waitForJudgeSeconds(players, CFG.ROOM_TOUR_DURATION, roomStillValid)
		if not completedTour then
			if tourReason == "phase" then
				cleanup()
				return false
			end
			continue
		end

		createVoteWindow(state, ownerEntry)
		fireCohortClients(TeleportToRoom, players, {
			stage = "vote",
			roomIndex = shownRoomIndex,
			roomCount = #roomOrder,
			duration = CFG.VOTE_DURATION,
			tokensPerRoom = CFG.TOKENS_PER_ROOM,
			roomOwnerUserId = ownerEntry.userId,
			roomOwnerName = ownerEntry.name,
			nextRoomOwnerName = roomOrder[queueIndex + 1] and roomOrder[queueIndex + 1].name or "Results",
		})
		local completedVote, voteReason = waitForJudgeSeconds(players, CFG.VOTE_DURATION, roomStillValid)
		closeVoteWindow(state)
		if not completedVote and voteReason == "phase" then
			cleanup()
			return false
		end
	end

	fireReveal(state, mechanicalTheme, aestheticTheme)
	waitForJudgeSeconds(players, CFG.REVEAL_DURATION)
	cleanup()
	return true
end

RunJudgeSequence.OnInvoke = runJudgeSequence

Players.PlayerRemoving:Connect(function(player)
	local state = stateByUserId[player.UserId]
	stateByUserId[player.UserId] = nil
	if not state then
		return
	end
	if state.participantUserIds then
		state.participantUserIds[player.UserId] = nil
	end
	if state.currentVote then
		state.currentVote.submitted[player.UserId] = nil
		state.currentVote.votes[player.UserId] = nil
	end
end)

print("[JudgeService] Loaded")
