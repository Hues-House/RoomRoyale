local Acceptance = {}

function Acceptance.run(park)
	assert(park and park.root and park.root:IsDescendantOf(workspace), "Build the park in Workspace before checking it")
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = {park.root}
	params.RespectCanCollide = true
	local checks, joins, floorChecks, failures = 0, 0, 0, {}
	local function check(position, route, isJoin)
		local hit = workspace:Raycast(position + Vector3.new(0, 20, 0), Vector3.new(0, -44, 0), params)
		checks += 1
		if isJoin then joins += 1 end
		local problem
		if not hit then
			problem = "Missing collision support"
		elseif route and hit.Instance:GetAttribute("ParkRoute") ~= route then
			problem = "Track has a gap or another collider covers it"
		elseif route and math.abs(hit.Position.Y - position.Y) > 0.09 then
			problem = "Track surface differs from authored riding line"
		elseif not route and hit.Position.Y < position.Y - 0.025 then
			problem = "Landing floor is below expected height"
		elseif hit.Normal.Y < 0.9 then
			problem = "Route has an abrupt or over-steep surface"
		end
		if problem then
			table.insert(failures, {problem = problem, route = route or "landing/connection", join = isJoin == true,
				position = {position.X, position.Y, position.Z}, hit = if hit then hit.Instance:GetFullName() else nil,
				hitY = if hit then hit.Position.Y else nil})
		end
	end
	for _, sample in park.supportSamples do check(sample.position, sample.route, sample.join) end
	local function floor(x, z)
		floorChecks += 1
		check(park.origin:PointToWorldSpace(Vector3.new(x, -0.02, z)))
	end
	for x = -162, -87, 3 do
		for _, z in {72, 81, 90, 99, 108} do floor(x, z) end
	end
	for x = -40, 88, 4 do
		for z = -15, 25, 4 do floor(x, z) end
	end
	for x = -126, 136, 8 do
		for _, z in {-116, 126} do floor(x, z) end
	end
	for z = -116, 126, 8 do
		for _, x in {-126, 136} do floor(x, z) end
	end
	local first, last = park.loop[1], park.loop[#park.loop]
	assert((first.left - last.left).Magnitude < 0.001 and (first.right - last.right).Magnitude < 0.001, "Pump loop must close")
	assert(park.insideBendRadius >= 26 and park.trackWidth >= 24, "Practice loop must leave room for novice steering")
	local report = {passed = #failures == 0, engineActual = true, checks = checks, joinChecks = joins,
		floorChecks = floorChecks, failures = failures,
		method = "Actual Workspace raycasts across track width, every segment join, market connection, overshoot area, and floor perimeter. Does not certify rider feel or camera behavior."}
	local examples = {}
	for i = 1, math.min(8, #failures) do table.insert(examples, failures[i]) end
	assert(report.passed, "Practice park has " .. #failures .. " support failures: " .. game:GetService("HttpService"):JSONEncode(examples))
	return report
end

return Acceptance
