--!strict

local BuildParts = require(script.Parent.BuildParts)
local Generator = { Attributes = { Back = "Slats", FrameColor = Color3.fromRGB(180, 140, 94), SeatColor = Color3.fromRGB(153, 171, 136) } }

function Generator.OnGenerate(parameters, target: GeneratedFolder)
	local s, a = parameters.Size, parameters.Attributes
	assert(s.X >= 1.7 and s.X <= 5 and s.Y >= 1.8 and s.Y <= 3.8 and s.Z >= 1.7 and s.Z <= 2.6, "Chair dimensions outside authoring range")
	assert(a.Back == "Slats" or a.Back == "Panel" or a.Back == "None", "Unknown chair back")
	assert(a.Back == "None" or s.Y >= 2.8, "Backed chair must be at least 2.8 studs high")
	local b, wood = BuildParts.new(parameters, target), Enum.Material.Wood
	local seatTop = if a.Back == "None" then s.Y else 1.9
	for _, x in ipairs({ -1, 1 }) do
		for _, z in ipairs({ -1, 1 }) do
			b.round("Leg_" .. x .. "_" .. z, Vector3.new(.22, seatTop - .22, .22), Vector3.new(x * (s.X / 2 - .24), (seatTop - .22) / 2, z * (s.Z / 2 - .24)), a.FrameColor, wood, "Frame", .04)
		end
	end
	b.round("Seat", Vector3.new(s.X, .24, s.Z), Vector3.new(0, seatTop - .12, 0), a.SeatColor, Enum.Material.Fabric, "Seat", .09)
	if a.Back ~= "None" then
		local height = s.Y - seatTop
		if a.Back == "Panel" then
			b.round("Back", Vector3.new(s.X, height, .2), Vector3.new(0, seatTop + height / 2, -s.Z / 2 + .1), a.FrameColor, wood, "Frame", .07)
		else
			for i = 1, 4 do
				b.round("Slat_" .. i, Vector3.new(.13, height, .13), Vector3.new(-s.X * .4 + (i - 1) * s.X * .8 / 3, seatTop + height / 2, -s.Z / 2 + .1), a.FrameColor, wood, "Frame", .03)
			end
			b.round("BackRail", Vector3.new(s.X, .2, .2), Vector3.new(0, s.Y - .1, -s.Z / 2 + .1), a.FrameColor, wood, "Frame", .05)
		end
	end
	b.anchor()
end

return Generator
