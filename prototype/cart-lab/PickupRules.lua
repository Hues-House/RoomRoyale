local Rules = {}
Rules.capacity = 100
Rules.range = 16

function Rules.cost(space)
    return math.max(8, space)
end

function Rules.capacityState(used, required)
    local free = math.max(0, Rules.capacity - used)
    return {
        used = used, free = free, ratio = math.clamp(used / Rules.capacity, 0, 1),
        full = free == 0, nearlyFull = used >= 85,
        fits = required == nil or Rules.cost(required) <= free,
    }
end

function Rules.inRange(distance, heightDifference)
    return distance <= Rules.range and math.abs(heightDifference) <= 4
end

function Rules.canReach(body, part, requiredFloorY, exclusions)
    if not Rules.inRange((body.Position - part.Position).Magnitude, body.Position.Y - part.Position.Y) then return false end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.RespectCanCollide = true
    params.FilterDescendantsInstances = exclusions
    if requiredFloorY then
        local support = workspace:Raycast(body.Position, Vector3.new(0, -4.5, 0), params)
        if not support or support.Normal.Y < 0.6 or support.Position.Y < requiredFloorY - 0.75 then return false end
    end
    return workspace:Raycast(body.Position, part.Position - body.Position, params) == nil
end

function Rules.select(parts, body, exclusions)
    local nearest, distance, id = nil, math.huge, math.huge
    for _, part in parts do
        local pickupId = part:GetAttribute("PickupId")
        local current = (body.Position - part.Position).Magnitude
        if pickupId and part:GetAttribute("PickupAvailable") and (current < distance or (current == distance and pickupId < id))
            and Rules.canReach(body, part, part:GetAttribute("RequiredFloorY"), exclusions) then
            nearest, distance, id = part, current, pickupId
        end
    end
    return nearest
end

return Rules
