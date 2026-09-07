-- ReplicatedStorage.UIStateManager
-- Centralized CLIENT-side UI state machine. One source of truth for "what HUD
-- should be visible right now", so individual controllers stop each toggling their
-- own visibility off RoundPhase (the root cause of the overlap / "everything fails
-- to hide" bugs). Handoff §12 keystone.
--
-- States (canonical):
--   Lobby     -- hub / plaza (RoundPhase == "Lobby")
--   Shop      -- shopping with the cart (RoundPhase == "Shop")
--   Design    -- styling a room (RoundPhase == "Style")
--   Judge     -- judging tour (RoundPhase == "Judge")
--   Results   -- results screen (RoundPhase == "Results")
--   Placement -- in build mode placing furniture (IsBuildMode == true)
--
-- Drivers (LocalPlayer attributes, already maintained elsewhere):
--   RoundPhase  -> set by the server each phase (RoundClient/etc. read it today)
--   IsBuildMode -> set by PlacementController on enter/exit build mode
-- Placement is an OVERRIDE: while IsBuildMode is true the state is Placement
-- regardless of phase (so the rest of the HUD hides entirely while placing).
--
-- Singleton on the client: a ModuleScript is cached per-VM, and all client
-- LocalScripts share one VM, so every `require` returns this same table and the
-- watchers are wired exactly once.
--
-- USAGE
--   local UIState = require(ReplicatedStorage.UIStateManager)
--
--   -- Declarative: bind an element's visibility to a set of states.
--   local handle = UIState.register({
--     name      = "CartHUD",
--     instance  = cartHudGui,        -- ScreenGui -> .Enabled ; GuiObject -> .Visible
--     visibleIn = { UIState.State.Shop },
--     onShow    = function() ... end,  -- optional, on transition into visible
--     onHide    = function() ... end,  -- optional, on transition into hidden
--     -- apply  = function(visible) ... end,  -- optional: full custom toggle
--   })
--   handle:unregister()
--
--   -- Imperative: react to state changes (e.g. bind/unbind ContextActions).
--   local unsub = UIState.subscribe(function(state, prevState) ... end)
--   -- fires immediately with the current state, then on every change. unsub()
--
--   UIState.getState()        -> current state string
--   UIState.is(UIState.State.Placement) -> boolean

local Players     = game:GetService("Players")
local RunService  = game:GetService("RunService")

local UIStateManager = {}

-- Toggle for transition tracing (set true while debugging).
UIStateManager.Debug = false

-- ============================================================
-- STATES
-- ============================================================

UIStateManager.State = {
	Lobby     = "Lobby",
	Shop      = "Shop",
	Design    = "Design",
	Judge     = "Judge",
	Results   = "Results",
	Placement = "Placement",
}

-- RoundPhase attribute value -> canonical state (Placement is handled separately).
local PHASE_TO_STATE = {
	Lobby   = UIStateManager.State.Lobby,
	Shop    = UIStateManager.State.Shop,
	Style   = UIStateManager.State.Design,
	Judge   = UIStateManager.State.Judge,
	Results = UIStateManager.State.Results,
}

-- ============================================================
-- INTERNAL STATE
-- ============================================================

local player = Players.LocalPlayer  -- nil if required on the server

local currentState = UIStateManager.State.Lobby
local registrations = {}   -- array of registration records (insertion order)
local subscribers   = {}   -- array of { fn = function }
local initialized   = false

local function dprint(...)
	if UIStateManager.Debug then
		print("[UIStateManager]", ...)
	end
end

-- Normalize visibleIn (array OR set) into a set keyed by state string.
local function toStateSet(visibleIn): { [string]: boolean }
	local set = {}
	if type(visibleIn) ~= "table" then
		return set
	end
	-- Array form: { State.Shop, State.Placement }
	for _, v in ipairs(visibleIn) do
		if type(v) == "string" then set[v] = true end
	end
	-- Set form: { Shop = true }
	for k, v in pairs(visibleIn) do
		if type(k) == "string" and v == true then set[k] = true end
	end
	return set
end

-- ============================================================
-- STATE COMPUTATION
-- ============================================================

local function computeState(): string
	if not player then
		return UIStateManager.State.Lobby
	end
	if player:GetAttribute("IsBuildMode") == true then
		return UIStateManager.State.Placement
	end
	local phase = player:GetAttribute("RoundPhase") or "Lobby"
	return PHASE_TO_STATE[phase] or UIStateManager.State.Lobby
end

-- Apply visibility to a single registration for the given state.
local function applyRegistration(reg, state: string)
	local shouldShow = reg.visibleIn[state] == true
	local was = reg.lastVisible

	if reg.apply then
		reg.apply(shouldShow)
	elseif reg.instance then
		local inst = reg.instance
		if not inst.Parent and not inst:IsA("ScreenGui") then
			-- Destroyed/unparented GuiObject: skip (will be cleaned up on next change).
		end
		if inst:IsA("ScreenGui") or inst:IsA("LayerCollector") then
			inst.Enabled = shouldShow
		elseif inst:IsA("GuiObject") then
			inst.Visible = shouldShow
		end
	end

	-- Fire transition callbacks only on an actual change of visibility.
	if shouldShow ~= was then
		reg.lastVisible = shouldShow
		if shouldShow and reg.onShow then
			task.spawn(reg.onShow)
		elseif (not shouldShow) and reg.onHide then
			task.spawn(reg.onHide)
		end
	end
end

-- Push the given state out to every registration + subscriber.
local function broadcast(state: string, prevState: string)
	-- Prune dead registrations (instance destroyed) while applying.
	for i = #registrations, 1, -1 do
		local reg = registrations[i]
		if reg.instance and not reg.instance.Parent and reg.instance:IsDescendantOf(game) == false then
			table.remove(registrations, i)
		else
			applyRegistration(reg, state)
		end
	end
	for _, sub in ipairs(subscribers) do
		task.spawn(sub.fn, state, prevState)
	end
end

local function recompute()
	local newState = computeState()
	if newState == currentState then
		return
	end
	local prev = currentState
	currentState = newState
	dprint(string.format("%s -> %s", prev, newState))
	broadcast(newState, prev)
end

-- ============================================================
-- PUBLIC API
-- ============================================================

function UIStateManager.getState(): string
	return currentState
end

function UIStateManager.is(state: string): boolean
	return currentState == state
end

-- Register an element whose visibility this manager owns.
-- opts = { instance?, visibleIn, apply?, onShow?, onHide?, name? }
-- Returns a handle with :unregister().
function UIStateManager.register(opts)
	assert(type(opts) == "table", "UIStateManager.register expects a table")
	local reg = {
		name        = opts.name,
		instance    = opts.instance,
		visibleIn   = toStateSet(opts.visibleIn),
		apply       = opts.apply,
		onShow      = opts.onShow,
		onHide      = opts.onHide,
		lastVisible = nil,  -- unknown -> first apply always fires the transition
	}
	table.insert(registrations, reg)
	-- Sync immediately to the current state.
	applyRegistration(reg, currentState)

	local handle = {}
	function handle.unregister()
		local idx = table.find(registrations, reg)
		if idx then table.remove(registrations, idx) end
	end
	handle.unregister = handle.unregister
	return handle
end

-- Subscribe to state changes. Fires immediately with the current state, then on
-- every transition. Returns an unsubscribe function.
function UIStateManager.subscribe(fn): () -> ()
	assert(type(fn) == "function", "UIStateManager.subscribe expects a function")
	local sub = { fn = fn }
	table.insert(subscribers, sub)
	task.spawn(fn, currentState, nil)
	return function()
		local idx = table.find(subscribers, sub)
		if idx then table.remove(subscribers, idx) end
	end
end

-- Force a recompute + rebroadcast (rarely needed; attribute watchers cover the
-- normal path). Always re-applies even if the state is unchanged.
function UIStateManager.refresh()
	local prev = currentState
	currentState = computeState()
	broadcast(currentState, prev)
end

-- ============================================================
-- INIT (client only)
-- ============================================================

local function init()
	if initialized then return end
	initialized = true
	if not (RunService:IsClient() and player) then
		return  -- server / Edit require: API stays usable, state pinned to Lobby
	end
	currentState = computeState()
	player:GetAttributeChangedSignal("RoundPhase"):Connect(recompute)
	player:GetAttributeChangedSignal("IsBuildMode"):Connect(recompute)
	dprint("initialized; state =", currentState)
end

init()

return UIStateManager
