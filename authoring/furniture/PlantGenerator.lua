--!strict

local BuildParts = require(script.Parent.BuildParts)
local Generator = { Attributes = { LeafCount = 7, PotColor = Color3.fromRGB(188, 123, 94), LeafColor = Color3.fromRGB(97, 139, 90) } }

function Generator.OnGenerate(parameters, target: GeneratedFolder)
	local s, a = parameters.Size, parameters.Attributes
	assert(s.X >= 1 and s.X <= 3.5 and s.Y >= 1.3 and s.Y <= 6 and math.abs(s.X - s.Z) < .001, "Plant dimensions outside authoring range")
	assert(a.LeafCount % 1 == 0 and a.LeafCount >= 4 and a.LeafCount <= 12, "LeafCount must be 4 through 12")
	local b = BuildParts.new(parameters, target)
	local potHeight, diameter = s.Y * .28, s.X * .58
	b.cylinder("Pot", diameter, potHeight, Vector3.new(0, potHeight / 2, 0), a.PotColor, Enum.Material.SmoothPlastic, "Pot")
	b.cylinder("PotRim", diameter * 1.07, potHeight * .15, Vector3.new(0, potHeight * .925, 0), a.PotColor, Enum.Material.SmoothPlastic, "Pot")
	b.cylinder("Soil", diameter * .87, .02, Vector3.new(0, potHeight - .02, 0), Color3.fromRGB(68, 53, 39), Enum.Material.Ground, "Soil")
	b.cylinder("Stem", .065, s.Y * .65, Vector3.new(0, potHeight + s.Y * .325, 0), a.LeafColor:Lerp(Color3.new(), .25), Enum.Material.SmoothPlastic, "Stem")
	for i = 1, a.LeafCount do
		local angle = i * math.pi * (3 - math.sqrt(5))
		local y = potHeight + s.Y * .25 + (i - 1) / (a.LeafCount - 1) * s.Y * .3
		local radius = s.X * .27
		local leaf = b.ball("Leaf_" .. i, Vector3.new(s.X * .43, s.Y * .16, s.X * .18), Vector3.new(math.cos(angle) * radius, y, math.sin(angle) * radius), a.LeafColor:Lerp(Color3.fromRGB(161, 181, 113), (i % 3) * .12), Enum.Material.SmoothPlastic, "Leaves")
		leaf.CFrame *= CFrame.Angles(0, -angle, 0)
	end
	b.ball("Crown", Vector3.new(s.X * .25, s.Y * .22, s.X * .25), Vector3.new(0, s.Y * .89, 0), a.LeafColor, Enum.Material.SmoothPlastic, "Leaves")
	b.anchor()
end

return Generator
