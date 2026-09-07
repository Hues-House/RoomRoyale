-- ServerScriptService > RoundManager
-- Hub-world architecture: hub always live. Rounds run on demand for opted-in cohorts.
-- Per-player RoundPhase / RoundId attrs tell clients whether they are in a round.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ThemeDatabase = require(ReplicatedStorage:WaitForChild("ThemeDatabase", 15))

local CFG = {
	MIN_PLAYERS      = 2,   -- a lobby needs 2+ to start (auto-relaxes to 1 if only one player is online, which also serves as the solo-test bypass)
	MAX_PLAYERS      = 6,   -- lobby cap; a forming lobby starts immediately when it hits 6
	QUEUE_WAIT       = 10,  -- seconds others have to join the forming lobby
	SHOP_DURATION    = 90,
	STYLE_DURATION   = 120,
	JUDGE_DURATION   = 15,
	RESULTS_DURATION = 8,
}

local Events = ReplicatedStorage:FindFirstChild("Events")
if not Events then
	Events = Instance.new("Folder")
	Events.Name = "Events"
	Events.Parent = ReplicatedStorage
end

local function getOrCreate(className, name)
	local existing = Events:FindFirstChild(name)
	if existing then return existing end
	local r = Instance.new(className)
	r.Name = name; r.Parent = Events
	return r
end

local RoundPhaseChanged  = getOrCreate("RemoteEvent",     "RoundPhaseChanged")
local TimerTick          = getOrCreate("RemoteEvent",     "TimerTick")
local RoundStarted       = getOrCreate("RemoteEvent",     "RoundStarted")
local RoundEnded         = getOrCreate("RemoteEvent",     "RoundEnded")
local RoundPhaseServer   = getOrCreate("BindableEvent",   "RoundPhaseServer")
local RunJudgeSequence   = getOrCreate("BindableFunction","RunJudgeSequence")
local QueueStateChanged  = getOrCreate("RemoteEvent",     "QueueStateChanged")
local RequestJoinQueue   = getOrCreate("RemoteEvent",     "RequestJoinQueue")
local RequestLeaveQueue  = getOrCreate("RemoteEvent",     "RequestLeaveQueue")
getOrCreate("RemoteEvent",     "PhaseChanged")
local PhaseChangedServer = getOrCreate("BindableEvent",   "PhaseChangedServer")
local StartRoundRequest  = getOrCreate("BindableFunction","StartRoundRequest")

local activeRounds: {[string]: any}      = {}
local playerRoundMap: {[number]: string} = {}
local roundCounter = 0
local playerQueue: {Player} = {}
local queueThread: thread?  = nil
local queueEndsAt  = 0
local queueActive  = false
local reevaluateQueue -- defined below startQueueCountdown

local function getPlayerRound(player: Player)
	local rid = playerRoundMap[player.UserId]
	return rid and activeRounds[rid]
end

local function fireCohort(event: RemoteEvent, rs, ...)
	for _, p in ipairs(rs.cohort) do
		if p.Parent == Players then event:FireClient(p, ...) end
	end
end

local function getActiveCohort(rs): {Player}
	local t = {}
	for _, p in ipairs(rs.cohort) do
		if p and p.Parent == Players then table.insert(t, p) end
	end
	return t
end

local function setPlayerAttrs(rs, phase: string?)
	rs.phase = phase or ""
	for _, p in ipairs(rs.cohort) do
		if p.Parent == Players then
			if phase then
				p:SetAttribute("RoundPhase", phase)
				p:SetAttribute("RoundId",    rs.roundId)
			else
				p:SetAttribute("RoundPhase", nil)
				p:SetAttribute("RoundId",    nil)
			end
		end
	end
end

local function chooseThemes(roundId: string)
	local pair = ThemeDatabase.RollThemePair()
	game:SetAttribute("MechanicalThemeId",    pair.mechanical.id)
	game:SetAttribute("MechanicalThemeLabel", pair.mechanical.label)
	game:SetAttribute("MechanicalThemeHint",  pair.mechanical.hint)
	game:SetAttribute("AestheticThemeId",     pair.aesthetic.id)
	game:SetAttribute("AestheticThemeLabel",  pair.aesthetic.label)
	game:SetAttribute("AestheticThemeHint",   pair.aesthetic.hint)
	game:SetAttribute("RoundThemeId",         pair.mechanical.id)
	game:SetAttribute("RoundThemeLabel",      pair.mechanical.label)
	game:SetAttribute("RoundThemeHint",       pair.mechanical.hint)
	game:SetAttribute("RoundThemePrompt",     pair.mechanical.prompt)
	print(string.format("[RoundManager] Round %s theme: %s", roundId, pair.mechanical.label))
	return pair
end

local PLAZA_RETURN = Vector3.new(0, 6, 268) -- behind the fountain; MUST stay clear of the gold queue ring (~z208) so returning players don't auto-requeue

local function tpTo(players: {Player}, cf: CFrame, spread: number?)
	for i, p in ipairs(players) do
		local char = p.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local dx = ((i-1) - (#players-1)*0.5) * (spread or 6)
			char:PivotTo(cf * CFrame.new(dx, 0, 0))
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
		end
	end
end

local function teleportToShowroom(rs)
	local SB = require(game.ServerScriptService:WaitForChild("ShowroomBootstrap"))
	SB.EnsureAll()
	-- Acquire this round's OWN store instance (slot 0 = canonical; slots 1+ = offset clones).
	local padCF
	local acquireFn = Events:FindFirstChild("AcquireStore")
	if acquireFn then
		local ok, res = pcall(function() return acquireFn:Invoke(rs.roundId) end)
		if ok and typeof(res) == "CFrame" then padCF = res end
	end
	if not padCF then padCF = SB.GetShopEntryPad() end
	if not padCF then warn("[RoundManager] No ShopEntryPad"); return end
	local cohort = getActiveCohort(rs)
	for _ = 1, 10 do
		local ok = true
		for _, p in ipairs(cohort) do
			if not (p.Character and p.Character:FindFirstChild("HumanoidRootPart")) then ok=false; break end
		end
		if ok then break end
		task.wait(0.15)
	end
	local dest = CFrame.new(padCF.Position + Vector3.new(0, 4, 0)) * CFrame.Angles(0, math.pi, 0)
	local n = #cohort
	-- Spread the lobby across up to 6 tidy slots so players never stack on one pad.
	local function slotCF(i: number): CFrame
		return dest * CFrame.new(((i - 1) - (n - 1) * 0.5) * 7, 0, 0)
	end
	for i, p in ipairs(cohort) do
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			p.Character:PivotTo(slotCF(i))
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
		end
	end
	task.spawn(function()
		for _ = 1, 12 do
			task.wait(0.2)
			if rs.phase ~= "Shop" then break end
			for i, p in ipairs(getActiveCohort(rs)) do
				local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
				if root and (root.Position - padCF.Position).Magnitude > 80 then
					p.Character:PivotTo(slotCF(i))
					root.AssemblyLinearVelocity = Vector3.zero
				end
			end
		end
	end)
end

local function teleportToPlaza(rs)
	tpTo(getActiveCohort(rs), CFrame.new(PLAZA_RETURN), 5)
end

local function setPhase(rs, phase: string)
	setPlayerAttrs(rs, phase)
	fireCohort(RoundPhaseChanged, rs, phase)
	RoundPhaseServer:Fire(rs.roundId, phase, rs.cohort)
	print(string.format("[RoundManager] Round %s -> %s", rs.roundId, phase))
end

local function countdownR(rs, phase: string, secs: number)
	for t = secs, 0, -1 do
		if rs.phase ~= phase then return end
		fireCohort(TimerTick, rs, phase, t)
		if t > 0 then task.wait(1) end
	end
end

local function runShop(rs)
	setPhase(rs, "Shop")
	local cohort = getActiveCohort(rs)
	fireCohort(RoundStarted, rs, rs.roundNum, cohort)
	task.defer(function() teleportToShowroom(rs) end)
	countdownR(rs, "Shop", CFG.SHOP_DURATION)
end

local function runStyle(rs)
	-- Shop is over; hand back this round's store instance (frees its slot / destroys clones).
	local releaseFn = Events:FindFirstChild("ReleaseStore")
	if releaseFn then pcall(function() releaseFn:Invoke(rs.roundId) end) end
	setPhase(rs, "Style")
	countdownR(rs, "Style", CFG.STYLE_DURATION)
end

local function runJudge(rs)
	setPhase(rs, "Judge")
	local cohort = getActiveCohort(rs)
	local ok, result = pcall(function() return RunJudgeSequence:Invoke(rs.roundId, cohort, rs.themePair) end)
	if not ok then
		warn("[RoundManager] JudgeSequence err: " .. tostring(result))
		countdownR(rs, "Judge", #cohort * CFG.JUDGE_DURATION)
		return
	end
	if result == false then countdownR(rs, "Judge", #cohort * CFG.JUDGE_DURATION) end
end

local function runResults(rs)
	setPhase(rs, "Results")
	fireCohort(RoundEnded, rs, rs.roundNum)
	task.defer(function() teleportToPlaza(rs) end)
	countdownR(rs, "Results", CFG.RESULTS_DURATION)
end

local function cleanupRound(rs)
	-- Safety release (idempotent) in case the round errored before Style.
	local releaseFn = Events:FindFirstChild("ReleaseStore")
	if releaseFn then pcall(function() releaseFn:Invoke(rs.roundId) end) end
	setPlayerAttrs(rs, nil)
	for _, p in ipairs(rs.cohort) do playerRoundMap[p.UserId] = nil end
	activeRounds[rs.roundId] = nil
	print(string.format("[RoundManager] Round %s done.", rs.roundId))
end

local function runRoundSequence(rs)
	local ok, err = pcall(function()
		runShop(rs); runStyle(rs); runJudge(rs); runResults(rs)
	end)
	if not ok then warn("[RoundManager] Round error: " .. tostring(err)) end
	cleanupRound(rs)
end

local function startRoundForCohort(cohort: {Player})
	if #cohort == 0 then return end
	roundCounter += 1
	local roundId = tostring(math.floor(os.clock()*1000)) .. "_" .. tostring(roundCounter)
	local selected: {Player} = {}
	for _, p in ipairs(cohort) do
		if p and p.Parent == Players then table.insert(selected, p) end
	end
	if #selected == 0 then return end
	local rs = { roundId = roundId, roundNum = roundCounter, cohort = selected, phase = "" }
	activeRounds[roundId] = rs
	for _, p in ipairs(selected) do playerRoundMap[p.UserId] = roundId end
	local themePair = chooseThemes(roundId)
	rs.themePair = themePair and { mechanicalId = themePair.mechanical.id, aestheticId = themePair.aesthetic.id } or nil
	print(string.format("[RoundManager] Starting %s for %d player(s)", roundId, #selected))
	task.spawn(runRoundSequence, rs)
end

local function broadcastQueue(cd: number?)
	local list = {}
	for _, p in ipairs(playerQueue) do
		table.insert(list, {userId = p.UserId, name = p.DisplayName})
	end
	QueueStateChanged:FireAllClients(list, cd)
	game:SetAttribute("QueueCount",             #playerQueue)
	game:SetAttribute("QueueCountdownActive",    cd ~= nil)
	game:SetAttribute("QueueCountdownRemaining", cd or -1)
end

-- Clears state before task.cancel, and never cancels the thread it is running on.
-- fireQueueRound calls this from inside queueThread, and cancelling a yielded thread
-- from itself kills it mid-statement, which left queueActive stuck true and blocked
-- every later countdown for the life of the server.
local function cancelQueue()
	local th = queueThread
	queueThread = nil
	queueActive = false
	queueEndsAt = 0
	if th and th ~= coroutine.running() then task.cancel(th) end
	broadcastQueue(nil)
end

-- A lobby requires MIN_PLAYERS, but never more than the players actually online,
-- so the only person in a server can still start (and solo Studio tests work)
-- instead of waiting forever. With 2+ online it enforces the real 2-player minimum.
local function effectiveMin(): number
	return math.max(1, math.min(CFG.MIN_PLAYERS, #Players:GetPlayers()))
end

-- The player minimum gates arming the countdown, not firing it. A committed lobby
-- starts with whoever is still queued, so someone joining the server mid-countdown
-- raises effectiveMin without stranding the players already waiting.
local function fireQueueRound()
	if #playerQueue == 0 then cancelQueue(); return end
	-- Take up to MAX_PLAYERS (FIFO) for this lobby; anyone past the cap waits for the next.
	local cohort = {}
	for _ = 1, math.min(CFG.MAX_PLAYERS, #playerQueue) do
		table.insert(cohort, table.remove(playerQueue, 1))
	end
	queueActive = false; queueThread = nil; broadcastQueue(nil)
	startRoundForCohort(cohort)
end

local function startQueueCountdown()
	if queueActive or #playerQueue < effectiveMin() then return end
	queueActive = true
	queueEndsAt = os.clock() + CFG.QUEUE_WAIT
	queueThread = task.spawn(function()
		for t = CFG.QUEUE_WAIT, 0, -1 do
			broadcastQueue(t)
			if t == 0 then
				fireQueueRound()
				-- Overflow (>6 queued): leftovers immediately form the next lobby's timer.
				reevaluateQueue()
				return
			end
			task.wait(1)
		end
	end)
end

-- Called whenever the server population changes, because effectiveMin() reads the live
-- player count. It only ever ARMS. A rising minimum must not cancel a countdown players
-- are already waiting on, which is the same reason fireQueueRound stopped re-checking the
-- minimum. Cancelling belongs to LeaveQueue, where the queue itself shrank.
reevaluateQueue = function()
	if #playerQueue >= effectiveMin() then
		startQueueCountdown()
	end
end

local function isInQueue(player: Player): boolean
	for _, p in ipairs(playerQueue) do if p == player then return true end end
	return false
end

local RoundManager = {}

function RoundManager.JoinQueue(player: Player)
	if not (player and player.Parent == Players) then return end
	if isInQueue(player) or playerRoundMap[player.UserId] then return end
	table.insert(playerQueue, player)
	local cd = queueActive and math.ceil(math.max(0, queueEndsAt - os.clock())) or nil
	broadcastQueue(cd)
	if #playerQueue >= CFG.MAX_PLAYERS then
		-- Lobby full: start now instead of waiting out the timer.
		cancelQueue()
		fireQueueRound()
	end
	reevaluateQueue()
	print(string.format("[RoundManager] %s joined queue (%d)", player.Name, #playerQueue))
end

function RoundManager.LeaveQueue(player: Player)
	for i, p in ipairs(playerQueue) do
		if p == player then table.remove(playerQueue, i); break end
	end
	-- The queue itself shrank, so dropping below the minimum does cancel here. This is
	-- also the PlayerRemoving path: the leaving player is still counted by effectiveMin,
	-- so the deferred reevaluateQueue re-arms once they are actually gone.
	if #playerQueue < effectiveMin() then
		cancelQueue()
	else
		local cd = queueActive and math.ceil(math.max(0, queueEndsAt - os.clock())) or nil
		broadcastQueue(cd)
	end
end

function RoundManager.IsInRound(player: Player): boolean
	return playerRoundMap[player.UserId] ~= nil
end

function RoundManager.IsInQueue(player: Player): boolean
	return isInQueue(player)
end

function RoundManager.GetPlayerRound(player: Player)
	return getPlayerRound(player)
end

function RoundManager.GetQueueCount(): number
	return #playerQueue
end

function RoundManager.RequestStartRound(cohort: {Player}?): boolean
	local sel: {Player} = {}
	if typeof(cohort) == "table" and #cohort > 0 then
		for _, p in ipairs(cohort) do
			if typeof(p) == "Instance" and p:IsA("Player") and p.Parent == Players then
				table.insert(sel, p)
			end
		end
	else
		sel = Players:GetPlayers()
	end
	if #sel == 0 then return false end
	startRoundForCohort(sel)
	return true
end

RequestJoinQueue.OnServerEvent:Connect(function(p) RoundManager.JoinQueue(p) end)
RequestLeaveQueue.OnServerEvent:Connect(function(p) RoundManager.LeaveQueue(p) end)
StartRoundRequest.OnInvoke = function(c) return RoundManager.RequestStartRound(c) end

-- effectiveMin() reads the live player count, so a population change in either
-- direction has to re-evaluate. PlayerRemoving fires while the player is still a
-- child of Players, hence the defer.
Players.PlayerAdded:Connect(function() reevaluateQueue() end)

Players.PlayerRemoving:Connect(function(player: Player)
	RoundManager.LeaveQueue(player)
	task.defer(reevaluateQueue)
	local rs = getPlayerRound(player)
	if rs then
		for i, p in ipairs(rs.cohort) do
			if p == player then table.remove(rs.cohort, i); break end
		end
		playerRoundMap[player.UserId] = nil
	end
end)

_G.ShopAndShineRoundManager = RoundManager

game:SetAttribute("HubActive",               true)
game:SetAttribute("GamePhase",               "Hub")
game:SetAttribute("RoundInProgress",         false)
game:SetAttribute("QueueCount",              0)
game:SetAttribute("QueueCountdownActive",    false)
game:SetAttribute("QueueCountdownRemaining", -1)

task.defer(function() PhaseChangedServer:Fire("Lobby") end)

print("[RoundManager] Loaded (hub + on-demand rounds)")
return RoundManager
