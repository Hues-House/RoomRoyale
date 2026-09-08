local Rules = require("../../prototype/cart-lab/PickupRules")
local Session = require("../../prototype/cart-lab/ShoppingSession")
local checked = 0
for used = 0, 100 do
    for cost = 0, 100 do
        local session = Session.new()
        session.space = used
        local display = Rules.capacityState(used, cost)
        local result = session:add({id = "candidate", space = cost}, 0)
        assert(display.fits == (result == "Added"), string.format("HUD/server mismatch at %d used, %d required", used, cost))
        assert(display.free == 100 - used and display.full == (used == 100))
        checked += 1
    end
end
assert(Rules.capacityState(92, 8).fits)
assert(not Rules.capacityState(93, 8).fits)
assert(Rules.capacityState(85).nearlyFull and not Rules.capacityState(84).nearlyFull)
assert(Rules.inRange(16, 4) and Rules.inRange(16, -4))
assert(not Rules.inRange(16.01, 0) and not Rules.inRange(2, 4.01))
local session = Session.new()
session:add({id = "sofa", space = 40}, 0)
session:add({id = "table", space = 35}, 0)
assert(Rules.capacityState(session.space, 26).fits == false)
session:deposit(1)
assert(Rules.capacityState(session.space, 100).fits and #session.banked == 2 and #session.entries == 0)
session:add({id = "chair", space = 22}, 2)
assert(session.space == 22 and #session.banked == 2)
local function position(x)
    return setmetatable({X = x, Y = 0}, {__sub = function(a, b) return {Magnitude = math.abs(a.X - b.X)} end})
end
local function candidate(id, x, available, reachable)
    local attributes = {PickupId = id, PickupAvailable = available}
    return {Position = position(x), reachable = reachable, GetAttribute = function(_, key) return attributes[key] end}
end
local originalCanReach = Rules.canReach
Rules.canReach = function(_, part) return part.reachable end
local body = {Position = position(0)}
local close = candidate(2, 2, true, true)
local far = candidate(1, 3, true, true)
local unavailable = candidate(3, 1, false, true)
local blocked = candidate(4, 1, true, false)
assert(Rules.select({far, unavailable, blocked, close}, body, {}) == close)
assert(Rules.select({close, far}, body, {}) == close)
local tie = candidate(1, 2, true, true)
assert(Rules.select({close, tie}, body, {}) == tie)
assert(Rules.select({unavailable, blocked}, body, {}) == nil)
Rules.canReach = originalCanReach
print(string.format("Pickup rules: %d capacity/session comparisons; range edges, candidate selection and checkout cargo/delivered separation passed", checked))
return true
