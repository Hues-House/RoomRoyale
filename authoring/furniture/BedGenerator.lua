--!strict

local BuildParts = require(script.Parent.BuildParts)
local Generator = { Attributes = { PillowCount = 2, FrameColor = Color3.fromRGB(173, 135, 95), LinenColor = Color3.fromRGB(224, 214, 192), ThrowColor = Color3.fromRGB(136, 157, 127) } }

function Generator.OnGenerate(parameters, target: GeneratedFolder)
	local s, a = parameters.Size, parameters.Attributes
	assert(s.X >= 3.8 and s.X <= 7 and s.Y >= 3 and s.Y <= 4 and s.Z >= 7 and s.Z <= 9, "Bed dimensions outside authoring range")
	assert(a.PillowCount == 1 or a.PillowCount == 2, "PillowCount must be 1 or 2")
	local b = BuildParts.new(parameters, target)
	for _, x in ipairs({ -1, 1 }) do
		for _, z in ipairs({ -1, 1 }) do
			b.block("Foot_" .. x .. "_" .. z, Vector3.new(.3, .5, .3), Vector3.new(x * (s.X / 2 - .4), .25, z * (s.Z / 2 - .4)), a.FrameColor, Enum.Material.Wood, "Frame")
		end
	end
	b.round("Frame", Vector3.new(s.X, .5, s.Z), Vector3.new(0, .65, 0), a.FrameColor, Enum.Material.Wood, "Frame", .1)
	b.round("Headboard", Vector3.new(s.X, s.Y - .5, .3), Vector3.new(0, .5 + (s.Y - .5) / 2, -s.Z / 2 + .15), a.FrameColor, Enum.Material.Wood, "Frame", .12)
	b.round("Mattress", Vector3.new(s.X - .3, .8, s.Z - .5), Vector3.new(0, 1.25, .1), a.LinenColor, Enum.Material.Fabric, "Linen", .2)
	b.round("Duvet", Vector3.new(s.X - .2, .25, s.Z * .7), Vector3.new(0, 1.72, s.Z * .13), a.LinenColor, Enum.Material.Fabric, "Linen", .1)
	b.round("FoldedThrow", Vector3.new(s.X - .12, .15, s.Z * .22), Vector3.new(0, 1.92, s.Z * .29), a.ThrowColor, Enum.Material.Fabric, "Throw", .05)
	local pillowWidth = (s.X - .7) / a.PillowCount
	for i = 1, a.PillowCount do
		b.round("Pillow_" .. i, Vector3.new(pillowWidth - .1, .38, 1.2), Vector3.new(-(s.X - .7) / 2 + pillowWidth * (i - .5), 1.82, -s.Z * .31), a.LinenColor, Enum.Material.Fabric, "Linen", .16)
	end
	b.anchor()
end

return Generator
