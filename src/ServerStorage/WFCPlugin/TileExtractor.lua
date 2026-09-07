--!strict
-- TileExtractor: converts a Folder of authored sample assets into WFC3D TileDefs.
-- Reads Socket_* StringValues, optional Weight (NumberValue), NoRotate (BoolValue).
-- Auto-generates Y-rotation variants (deduped) and splits weight across them.

local TileExtractor = {}

local function readSocket(container, face, defaultSocket)
	local sv = container:FindFirstChild("Socket_" .. face)
	if sv and sv:IsA("StringValue") then
		local v = sv.Value
		if v ~= "" then
			return v
		end
		warn(("[TileExtractor] %s: Socket_%s exists but is empty"):format(container.Name, face))
	end
	if defaultSocket then
		return defaultSocket
	end
	error(("[TileExtractor] %s is missing Socket_%s (add a StringValue, or pass options.defaultSocket)")
		:format(container:GetFullName(), face))
end

local function readWeight(container)
	local nv = container:FindFirstChild("Weight")
	if nv and nv:IsA("NumberValue") then
		if nv.Value > 0 then
			return nv.Value
		end
		warn(("[TileExtractor] %s: Weight must be > 0, defaulting to 1"):format(container.Name))
	end
	return 1
end

local function readNoRotate(container)
	local bv = container:FindFirstChild("NoRotate")
	return (bv ~= nil and bv:IsA("BoolValue") and bv.Value) == true
end

-- 90 deg CCW about +Y: new N = old E, new E = old S, new S = old W, new W = old N
local function rotateSocketsY90(s)
	return {
		Top = s.Top,
		Bottom = s.Bottom,
		North = s.East,
		East = s.South,
		South = s.West,
		West = s.North,
	}
end

local function socketsEqual(a, b)
	return a.Top == b.Top and a.Bottom == b.Bottom
		and a.North == b.North and a.South == b.South
		and a.East == b.East and a.West == b.West
end

function TileExtractor.ExtractFromFolder(folder, options)
	assert(folder and folder:IsA("Folder"), "[TileExtractor] expected a Folder")
	local opts = options or {}
	local generateRotations = opts.generateRotations ~= false

	local tiles = {}
	local seenIds = {}

	for _, child in folder:GetChildren() do
		if not (child:IsA("Model") or child:IsA("BasePart")) then
			continue
		end

		local baseSockets = {
			Top = readSocket(child, "Top", opts.defaultSocket),
			Bottom = readSocket(child, "Bottom", opts.defaultSocket),
			North = readSocket(child, "North", opts.defaultSocket),
			South = readSocket(child, "South", opts.defaultSocket),
			East = readSocket(child, "East", opts.defaultSocket),
			West = readSocket(child, "West", opts.defaultSocket),
		}
		local weight = readWeight(child)
		local skipRotation = readNoRotate(child) or not generateRotations

		local variants = {
			{ sockets = baseSockets, rot = 0 },
		}

		if not skipRotation then
			local current = baseSockets
			for rot = 90, 270, 90 do
				current = rotateSocketsY90(current)
				local duplicate = false
				for _, v in variants do
					if socketsEqual(v.sockets, current) then
						duplicate = true
						break
					end
				end
				if not duplicate then
					variants[#variants + 1] = { sockets = current, rot = rot }
				end
			end
		end

		local perVariantWeight = weight / #variants

		for _, v in variants do
			local id = v.rot == 0 and child.Name
				or (child.Name .. "_r" .. tostring(v.rot))
			if seenIds[id] then
				error(("[TileExtractor] duplicate tile id '%s' - rename the asset"):format(id))
			end
			seenIds[id] = true

			tiles[#tiles + 1] = {
				id = id,
				model = child,
				weight = perVariantWeight,
				sockets = v.sockets,
				rotationY = v.rot,
				sourceName = child.Name,
			}
		end
	end

	if #tiles == 0 then
		warn(("[TileExtractor] folder '%s' produced zero tiles"):format(folder:GetFullName()))
	end

	return tiles
end

-- Prints any socket with no possible partner in the set (the #1 cause of
-- instant contradictions). Run once after extraction while authoring.
function TileExtractor.AuditSockets(tiles)
	local horizontalFaces = { North = "South", South = "North", East = "West", West = "East" }

	local function horizontalMatch(a, b)
		if a == b and string.sub(a, 1, 2) == "s_" then return true end
		if a == b .. "_f" or b == a .. "_f" then return true end
		return a == b
	end

	for _, tile in tiles do
		for face, oppFace in horizontalFaces do
			local sock = tile.sockets[face]
			local found = false
			for _, other in tiles do
				if horizontalMatch(sock, other.sockets[oppFace]) then
					found = true
					break
				end
			end
			if not found then
				warn(("[TileExtractor] %s.%s = '%s' has NO matching partner in the set")
					:format(tile.id, face, sock))
			end
		end
		for _, pair in { { "Top", "Bottom" }, { "Bottom", "Top" } } do
			local sock = tile.sockets[pair[1]]
			local found = false
			for _, other in tiles do
				if other.sockets[pair[2]] == sock then
					found = true
					break
				end
			end
			if not found then
				warn(("[TileExtractor] %s.%s = '%s' has NO matching partner in the set")
					:format(tile.id, pair[1], sock))
			end
		end
	end
end

return TileExtractor
