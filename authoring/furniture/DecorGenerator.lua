--!strict

local BuildParts = require(script.Parent.BuildParts)
local Generator = { Attributes = { Object = "Vase", Count = 3, BodyColor = Color3.fromRGB(190, 130, 104), AccentColor = Color3.fromRGB(227, 214, 185) } }

function Generator.OnGenerate(parameters, target: GeneratedFolder)
	local s, a = parameters.Size, parameters.Attributes
	assert(s.X >= .5 and s.X <= 3 and s.Y >= .2 and s.Y <= 2.5 and s.Z >= .5 and s.Z <= 3, "Decor dimensions outside authoring range")
	assert(a.Object == "Vase" or a.Object == "Books" or a.Object == "Tray" or a.Object == "Candle", "Unknown decor object")
	assert(a.Count % 1 == 0 and a.Count >= 1 and a.Count <= 5, "Count must be 1 through 5")
	local b, ceramic = BuildParts.new(parameters, target), Enum.Material.SmoothPlastic
	if a.Object == "Vase" then
		assert(math.abs(s.X - s.Z) < .001, "Vase needs equal width and depth")
		b.cylinder("Foot", s.X * .65, s.Y * .1, Vector3.new(0, s.Y * .05, 0), a.BodyColor, ceramic, "Body")
		b.ball("Belly", Vector3.new(s.X, s.Y * .8, s.Z), Vector3.new(0, s.Y * .43, 0), a.BodyColor, ceramic, "Body")
		b.cylinder("Neck", s.X * .42, s.Y * .35, Vector3.new(0, s.Y * .825, 0), a.BodyColor, ceramic, "Body")
		b.cylinder("Rim", s.X * .5, s.Y * .07, Vector3.new(0, s.Y * .965, 0), a.AccentColor, ceramic, "Accent")
		b.cylinder("Opening", s.X * .35, .005, Vector3.new(0, s.Y - .005, 0), a.BodyColor:Lerp(Color3.new(), .6), ceramic, "Interior")
	elseif a.Object == "Books" then
		local h = s.Y / a.Count
		for i = 1, a.Count do
			local width = s.X * (1 - (i - 1) * .055)
			local color = if i % 2 == 0 then a.AccentColor else a.BodyColor
			b.block("Pages_" .. i, Vector3.new(width - .05, h * .74, s.Z - .05), Vector3.new(0, h * (i - .5), 0), Color3.fromRGB(231, 223, 201), Enum.Material.SmoothPlastic, "Pages")
			for _, sign in ipairs({ -1, 1 }) do
				b.block("Cover_" .. i .. "_" .. sign, Vector3.new(width, h * .13, s.Z), Vector3.new(0, h * (i - .5 + sign * .435), 0), color, Enum.Material.Fabric, "Cover")
			end
			b.block("Spine_" .. i, Vector3.new(width, h, .035), Vector3.new(0, h * (i - .5), s.Z / 2 - .0175), color, Enum.Material.Fabric, "Cover")
		end
	elseif a.Object == "Tray" then
		b.round("TrayBase", Vector3.new(s.X, s.Y * .4, s.Z), Vector3.new(0, s.Y * .2, 0), a.BodyColor, Enum.Material.Wood, "Body", .03)
		for _, sign in ipairs({ -1, 1 }) do
			b.block("RimX_" .. sign, Vector3.new(.07, s.Y * .6, s.Z), Vector3.new(sign * (s.X / 2 - .035), s.Y * .7, 0), a.AccentColor, Enum.Material.Wood, "Accent")
			b.block("RimZ_" .. sign, Vector3.new(s.X, s.Y * .6, .07), Vector3.new(0, s.Y * .7, sign * (s.Z / 2 - .035)), a.AccentColor, Enum.Material.Wood, "Accent")
		end
	else
		assert(math.abs(s.X - s.Z) < .001, "Candle needs equal width and depth")
		b.cylinder("Saucer", s.X, s.Y * .08, Vector3.new(0, s.Y * .04, 0), a.BodyColor, ceramic, "Body")
		b.cylinder("Wax", s.X * .72, s.Y * .84, Vector3.new(0, s.Y * .5, 0), a.AccentColor, ceramic, "Wax")
		b.cylinder("Wick", .035, s.Y * .08, Vector3.new(0, s.Y * .96, 0), Color3.fromRGB(60, 48, 38), Enum.Material.SmoothPlastic, "Wick")
	end
	b.anchor()
end

return Generator
