local Acceptance = {}

function Acceptance.run()
	local world = workspace:WaitForChild("CartLab")
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = {world}
	params.RespectCanCollide = true
	local spawn = world:GetAttribute("MarketSpawn")
	local destination = world:GetAttribute("CheckoutTarget")
	local eye = spawn.Position + Vector3.new(0, 4, 0)
	local occlusion = workspace:Raycast(eye, destination-eye, params)
	assert(not occlusion, "Checkout blocked at spawn by " .. (occlusion and occlusion.Instance:GetFullName() or ""))
	local routeSamples = 0
	for z = 100, -120, -5 do
		for _, x in {0, -72, 72} do
			local support = workspace:Raycast(Vector3.new(x, 8, z), Vector3.new(0,-12,0), params)
			assert(support and support.Normal.Y > 0.99, "Main loop has missing or sloped floor")
			routeSamples += 1
		end
	end
	for _, x in {0,-72,72} do
		local hit = workspace:Blockcast(CFrame.new(x, 3, 102), Vector3.new(8,4,8), Vector3.new(0,0,-175), params)
		assert(not hit, "Main shopping lane blocks loaded carts: " .. (hit and hit.Instance.Name or ""))
	end
	local signs = 0
	for _, child in world:GetDescendants() do if child:IsA("BillboardGui") and child.Name == "WayfindingSign" then signs += 1 end end
	assert(signs >= 10, "Missing floating route signs")
	local prizes = 0
	for _, child in world.Stock:GetChildren() do
		if child:IsA("BasePart") and child:GetAttribute("StockId") and child:GetAttribute("RouteId") == "jump" then prizes += 1 end
	end
	assert(prizes == 2, "Expected two optional course rewards")
	return {checkoutVisibleFromSpawn=true, flatLoopSamples=routeSamples, clearWideLanes=3, floatingSigns=signs, optionalRewards=prizes}
end

return Acceptance
