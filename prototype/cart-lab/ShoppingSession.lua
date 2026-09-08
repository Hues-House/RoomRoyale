--!strict

local ShoppingSession = {}
ShoppingSession.__index = ShoppingSession

function ShoppingSession.new(shopEndsAt: number?, checkoutEndsAt: number?, styleStartsAt: number?)
	assert(not shopEndsAt or (checkoutEndsAt and styleStartsAt and shopEndsAt < checkoutEndsAt and checkoutEndsAt < styleStartsAt), "Shopping deadlines must be ordered")
	return setmetatable({entries = {}, banked = {}, space = 0, settled = false,
		shopEndsAt = shopEndsAt, checkoutEndsAt = checkoutEndsAt, styleStartsAt = styleStartsAt}, ShoppingSession)
end

function ShoppingSession:phase(now: number): string
	if not self.shopEndsAt or now < self.shopEndsAt then return "Shop" end
	if now < self.checkoutEndsAt then return "Closing" end
	if now < self.styleStartsAt then return "Resolving" end
	return "Style"
end

function ShoppingSession:add(entry, now: number): string
	if self:phase(now) ~= "Shop" then return "Closed" end
	local cost = math.max(8, entry.space)
	if self.space + cost > 100 then return "Full" end
	table.insert(self.entries, entry)
	self.space += cost
	return "Added"
end

function ShoppingSession:deposit(now: number)
	local phase = self:phase(now)
	if (phase ~= "Shop" and phase ~= "Closing") or #self.entries == 0 then return nil end
	local deposited = self.entries
	self.entries = {}
	self.space = 0
	for _, entry in deposited do table.insert(self.banked, entry) end
	return deposited
end

function ShoppingSession:settle(now: number)
	if self.settled or not self.checkoutEndsAt or now < self.checkoutEndsAt then return nil end
	self.settled = true
	local discarded = self.entries
	self.entries = {}
	self.space = 0
	return discarded
end

function ShoppingSession:export()
	local result = {}
	for _, entry in self.banked do
		table.insert(result, {id = entry.id, itemId = entry.itemId, itemName = entry.name,
			templateId = entry.templateId, variantId = entry.variantId, color = entry.color, rarity = entry.rarity})
	end
	return result
end

return ShoppingSession
