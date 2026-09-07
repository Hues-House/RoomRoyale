--!strict
-- WFC3D: pure-data 3D Wave Function Collapse solver. Returns 3D array of tile ids.
-- AC-4 propagation (support counters), O(1) Shannon entropy, exact-undo backtracking.

local WFC3D = {}
WFC3D.__index = WFC3D

-- 1=Top(+Y) 2=Bottom(-Y) 3=North(+Z) 4=South(-Z) 5=East(+X) 6=West(-X)
local DIR_NAMES = { "Top", "Bottom", "North", "South", "East", "West" }
local OPPOSITE = { 2, 1, 4, 3, 6, 5 }
local DX = { 0, 0, 0, 0, 1, -1 }
local DY = { 1, -1, 0, 0, 0, 0 }
local DZ = { 0, 0, 1, -1, 0, 0 }

local function socketsMatch(a: string, b: string, isVertical: boolean): boolean
	if isVertical then
		return a == b
	end
	if a == b and string.sub(a, 1, 2) == "s_" then
		return true
	end
	if a == b .. "_f" or b == a .. "_f" then
		return true
	end
	return a == b
end

function WFC3D.new(tileDefs, config)
	assert(#tileDefs > 0, "WFC3D: need at least one tile")
	local self = setmetatable({}, WFC3D)

	self.sizeX = config.sizeX
	self.sizeY = config.sizeY
	self.sizeZ = config.sizeZ
	self.cellCount = config.sizeX * config.sizeY * config.sizeZ
	self.rng = Random.new(config.seed or os.clock() * 1e6)
	self.maxBacktrackDepth = config.maxBacktrackDepth or 64
	self.maxRestarts = config.maxRestarts or 5

	self.tiles = tileDefs
	self.tileCount = #tileDefs
	self.weights = table.create(self.tileCount)
	self.weightLogWeights = table.create(self.tileCount)
	for i, t in tileDefs do
		assert(t.weight > 0, "WFC3D: tile weight must be > 0: " .. tostring(t.id))
		self.weights[i] = t.weight
		self.weightLogWeights[i] = t.weight * math.log(t.weight)
	end

	self:_buildCompatibility()
	return self
end

function WFC3D:_buildCompatibility()
	local compat = table.create(6)
	for dir = 1, 6 do
		local dirName = DIR_NAMES[dir]
		local oppName = DIR_NAMES[OPPOSITE[dir]]
		local isVertical = dir <= 2
		local perTile = table.create(self.tileCount)
		for a = 1, self.tileCount do
			local list = {}
			local sockA = self.tiles[a].sockets[dirName]
			for b = 1, self.tileCount do
				local sockB = self.tiles[b].sockets[oppName]
				if socketsMatch(sockA, sockB, isVertical) then
					list[#list + 1] = b
				end
			end
			perTile[a] = list
		end
		compat[dir] = perTile
	end
	self.compat = compat
end

function WFC3D:_index(x, y, z)
	return ((z - 1) * self.sizeY + (y - 1)) * self.sizeX + x
end

function WFC3D:_neighbor(ci, dir)
	local sx, sy = self.sizeX, self.sizeY
	local i = ci - 1
	local x = i % sx + 1
	local y = math.floor(i / sx) % sy + 1
	local z = math.floor(i / (sx * sy)) + 1
	local nx, ny, nz = x + DX[dir], y + DY[dir], z + DZ[dir]
	if nx < 1 or nx > sx or ny < 1 or ny > sy or nz < 1 or nz > self.sizeZ then
		return nil
	end
	return self:_index(nx, ny, nz)
end

function WFC3D:_initState()
	local n, T = self.cellCount, self.tileCount

	local domains = table.create(n)
	local totalW, totalWLW = 0, 0
	for t = 1, T do
		totalW += self.weights[t]
		totalWLW += self.weightLogWeights[t]
	end
	for ci = 1, n do
		local set = table.create(T)
		for t = 1, T do set[t] = true end
		domains[ci] = { set = set, count = T, sumW = totalW, sumWLW = totalWLW }
	end
	self.domains = domains

	local support = table.create(n)
	for ci = 1, n do
		local perDir = table.create(6)
		for dir = 1, 6 do
			if self:_neighbor(ci, dir) then
				local counters = table.create(T)
				for t = 1, T do
					counters[t] = #self.compat[dir][t]
				end
				perDir[dir] = counters
			end
		end
		support[ci] = perDir
	end
	self.support = support

	self.collapsedCount = 0
	self.stack = {}

	local queue = {}
	for ci = 1, n do
		for dir = 1, 6 do
			local counters = self.support[ci][dir]
			if counters then
				for t = 1, T do
					if counters[t] == 0 and self.domains[ci].set[t] then
						self:_removeTile(ci, t, nil)
						queue[#queue + 1] = { ci, t }
					end
				end
			end
		end
	end
	if #queue > 0 then
		local ok = self:_propagate(queue, nil)
		assert(ok, "WFC3D: tile set is inconsistent before any collapse")
	end
end

function WFC3D:_removeTile(ci, t, undoLog)
	local d = self.domains[ci]
	if not d.set[t] then
		return true
	end
	d.set[t] = nil
	d.count -= 1
	d.sumW -= self.weights[t]
	d.sumWLW -= self.weightLogWeights[t]
	if undoLog then
		undoLog[#undoLog + 1] = ci
		undoLog[#undoLog + 1] = t
	end
	return d.count > 0
end

function WFC3D:_restoreTile(ci, t)
	local d = self.domains[ci]
	if d.set[t] then return end
	d.set[t] = true
	d.count += 1
	d.sumW += self.weights[t]
	d.sumWLW += self.weightLogWeights[t]
	for dir = 1, 6 do
		local ni = self:_neighbor(ci, dir)
		if ni then
			local counters = self.support[ni][OPPOSITE[dir]]
			local allowed = self.compat[dir][t]
			for i = 1, #allowed do
				counters[allowed[i]] += 1
			end
		end
	end
end

function WFC3D:_propagate(queue, undoLog)
	local head = 1
	while head <= #queue do
		local ev = queue[head]
		head += 1
		local ci, t = ev[1], ev[2]

		for dir = 1, 6 do
			local ni = self:_neighbor(ci, dir)
			if ni then
				local counters = self.support[ni][OPPOSITE[dir]]
				local affected = self.compat[dir][t]
				local nd = self.domains[ni]
				for i = 1, #affected do
					local nt = affected[i]
					local c = counters[nt] - 1
					counters[nt] = c
					if c == 0 and nd.set[nt] then
						if not self:_removeTile(ni, nt, undoLog) then
							queue[#queue + 1] = { ni, nt }
							return false
						end
						queue[#queue + 1] = { ni, nt }
					end
				end
			end
		end
	end
	return true
end

function WFC3D:_findLowestEntropyCell()
	local best = nil
	local bestE = math.huge
	for ci = 1, self.cellCount do
		local d = self.domains[ci]
		if d.count > 1 then
			local e = math.log(d.sumW) - d.sumWLW / d.sumW
			e += self.rng:NextNumber() * 1e-6
			if e < bestE then
				bestE = e
				best = ci
			end
		end
	end
	return best
end

function WFC3D:_pickTile(ci, banned)
	local d = self.domains[ci]
	local total = 0
	for t in d.set do
		if not (banned and banned[t]) then
			total += self.weights[t]
		end
	end
	if total <= 0 then return nil end
	local r = self.rng:NextNumber() * total
	for t in d.set do
		if not (banned and banned[t]) then
			r -= self.weights[t]
			if r <= 0 then return t end
		end
	end
	for t in d.set do
		if not (banned and banned[t]) then return t end
	end
	return nil
end

function WFC3D:_collapseCell(ci, chosen, undoLog)
	local d = self.domains[ci]
	local queue = {}
	local toRemove = {}
	for t in d.set do
		if t ~= chosen then
			toRemove[#toRemove + 1] = t
		end
	end
	for i = 1, #toRemove do
		local t = toRemove[i]
		self:_removeTile(ci, t, undoLog)
		queue[#queue + 1] = { ci, t }
	end
	return self:_propagate(queue, undoLog)
end

function WFC3D:_undoFrame(frame)
	local log = frame.undoLog
	for i = #log - 1, 1, -2 do
		self:_restoreTile(log[i], log[i + 1])
	end
end

function WFC3D:Solve()
	for _ = 0, self.maxRestarts do
		self:_initState()
		if self:_run() then
			return self:_extractResult()
		end
	end
	return nil
end

function WFC3D:_run()
	while true do
		local ci = self:_findLowestEntropyCell()
		if not ci then
			for i = 1, self.cellCount do
				if self.domains[i].count == 0 then return false end
			end
			return true
		end

		local frame = {
			cell = ci,
			banned = {},
			chosen = 0,
			undoLog = {},
		}

		local solvedThisCell = false
		while true do
			local choice = self:_pickTile(ci, frame.banned)
			if not choice then
				break
			end
			frame.chosen = choice
			frame.undoLog = {}
			if self:_collapseCell(ci, choice, frame.undoLog) then
				self.stack[#self.stack + 1] = frame
				solvedThisCell = true
				break
			end
			self:_undoFrame(frame)
			frame.banned[choice] = true
		end

		if not solvedThisCell then
			if not self:_backtrack() then
				return false
			end
		end
	end
end

function WFC3D:_backtrack()
	local depth = 0
	while #self.stack > 0 do
		depth += 1
		if depth > self.maxBacktrackDepth then
			return false
		end

		local frame = table.remove(self.stack)
		self:_undoFrame(frame)
		frame.banned[frame.chosen] = true

		local ci = frame.cell
		while true do
			local choice = self:_pickTile(ci, frame.banned)
			if not choice then
				break
			end
			frame.chosen = choice
			frame.undoLog = {}
			if self:_collapseCell(ci, choice, frame.undoLog) then
				self.stack[#self.stack + 1] = frame
				return true
			end
			self:_undoFrame(frame)
			frame.banned[choice] = true
		end
	end
	return false
end

function WFC3D:_extractResult()
	local out = table.create(self.sizeX)
	for x = 1, self.sizeX do
		local plane = table.create(self.sizeY)
		for y = 1, self.sizeY do
			local row = table.create(self.sizeZ)
			for z = 1, self.sizeZ do
				local d = self.domains[self:_index(x, y, z)]
				local tileIdx = next(d.set)
				row[z] = tileIdx and self.tiles[tileIdx].id or "<unsolved>"
			end
			plane[y] = row
		end
		out[x] = plane
	end
	return out
end

return WFC3D
