--!strict

local BuildParts = require(script.Parent.BuildParts)
local Generator = { Attributes = { Layout = "Open", Divisions = 3, BodyColor = Color3.fromRGB(186, 148, 103), AccentColor = Color3.fromRGB(128, 151, 121) } }

function Generator.OnGenerate(parameters, target: GeneratedFolder)
	local s, a = parameters.Size, parameters.Attributes
	assert(s.X >= 2 and s.X <= 7 and s.Y >= 2 and s.Y <= 7.5 and s.Z >= 1.1 and s.Z <= 2.5, "Storage dimensions outside authoring range")
	assert(a.Layout == "Open" or a.Layout == "Doors" or a.Layout == "Drawers", "Unknown storage layout")
	assert(a.Divisions % 1 == 0 and a.Divisions >= 1 and a.Divisions <= 5, "Divisions must be 1 through 5")
	local b, wood = BuildParts.new(parameters, target), Enum.Material.Wood
	local height = s.Y - .55
	for _, x in ipairs({ -1, 1 }) do
		for _, z in ipairs({ -1, 1 }) do
			b.block("Foot_" .. x .. "_" .. z, Vector3.new(.25, .4, .25), Vector3.new(x * (s.X / 2 - .25), .2, z * (s.Z / 2 - .25)), a.BodyColor, wood, "Body")
		end
		b.block("Side_" .. x, Vector3.new(.16, height, s.Z), Vector3.new(x * (s.X / 2 - .08), .4 + height / 2, 0), a.BodyColor, wood, "Body")
	end
	b.round("Top", Vector3.new(s.X, .2, s.Z), Vector3.new(0, s.Y - .1, 0), a.BodyColor, wood, "Body", .05)
	b.block("Bottom", Vector3.new(s.X - .3, .15, s.Z), Vector3.new(0, .475, 0), a.BodyColor, wood, "Body")
	b.block("Back", Vector3.new(s.X - .3, height, .12), Vector3.new(0, .4 + height / 2, -s.Z / 2 + .06), a.AccentColor, Enum.Material.SmoothPlastic, "Accent")
	local innerHeight = s.Y - .75
	if a.Layout == "Open" then
		for i = 1, a.Divisions - 1 do
			b.block("Shelf_" .. i, Vector3.new(s.X - .32, .12, s.Z - .12), Vector3.new(0, .55 + i * innerHeight / a.Divisions, .06), a.BodyColor, wood, "Body")
		end
	elseif a.Layout == "Doors" then
		local width = (s.X - .36) / a.Divisions
		for i = 1, a.Divisions do
			local x = -(s.X - .36) / 2 + width * (i - .5)
			b.round("Door_" .. i, Vector3.new(width - .04, innerHeight - .04, .15), Vector3.new(x, .55 + innerHeight / 2, s.Z / 2 - .175), a.AccentColor, Enum.Material.SmoothPlastic, "Accent", .035)
			b.ball("Knob_" .. i, Vector3.new(.12, .12, .12), Vector3.new(x + width * .28, .55 + innerHeight * .65, s.Z / 2 - .06), Color3.fromRGB(172, 137, 71), Enum.Material.Metal, "Hardware")
		end
	else
		local heightPerDrawer = innerHeight / a.Divisions
		for i = 1, a.Divisions do
			local y = .55 + heightPerDrawer * (i - .5)
			b.round("Drawer_" .. i, Vector3.new(s.X - .36, heightPerDrawer - .04, .15), Vector3.new(0, y, s.Z / 2 - .175), a.AccentColor, Enum.Material.SmoothPlastic, "Accent", .035)
			b.block("Pull_" .. i, Vector3.new(math.min(.65, s.X / 4), .07, .1), Vector3.new(0, y, s.Z / 2 - .05), Color3.fromRGB(172, 137, 71), Enum.Material.Metal, "Hardware")
		end
	end
	b.anchor(s.Y)
end

return Generator
