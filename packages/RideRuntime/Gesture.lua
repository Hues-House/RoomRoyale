--!strict

export type Config = {
	SteeringDeadzone: number,
	HopSpeed: number,
	ChargedHopSpeed: number,
	JumpChargeSeconds: number,
	LedgeGraceSeconds: number,
	MinDriftSpeed: number,
	MinDriftSlip: number,
	DriftTierSeconds: { number },
	DriftBoostSeconds: { number },
}

export type Input = {
	steer: number,
	held: boolean,
	enabled: boolean,
}

export type Contact = {
	grounded: boolean,
	speed: number,
	slip: number,
}

export type Mode = "Idle" | "JumpCharge" | "Drift" | "Dive"

export type Result = {
	mode: Mode,
	jumpSpeed: number,
	boostSeconds: number,
	jumpCharge: number,
	driftCharge: number,
	drifting: boolean,
	diving: boolean,
}

type Data = {
	_config: Config,
	_mode: Mode,
	_held: boolean,
	_needsRelease: boolean,
	_jumpSeconds: number,
	_driftSeconds: number,
	_unsupportedSeconds: number,
}

local Gesture = {}
Gesture.__index = Gesture

export type State = typeof(setmetatable({} :: Data, Gesture))

local function reset(self: Data)
	self._mode = "Idle"
	self._jumpSeconds = 0
	self._driftSeconds = 0
	self._unsupportedSeconds = 0
end

function Gesture.new(config: Config): State
	assert(config.SteeringDeadzone >= 0 and config.SteeringDeadzone < 1,
		"SteeringDeadzone must be between 0 and 1")
	assert(config.HopSpeed > 0 and config.ChargedHopSpeed >= config.HopSpeed,
		"ChargedHopSpeed must be at least the positive HopSpeed")
	assert(config.JumpChargeSeconds > 0 and config.LedgeGraceSeconds >= 0,
		"JumpChargeSeconds must be positive and LedgeGraceSeconds nonnegative")
	assert(config.MinDriftSpeed >= 0 and config.MinDriftSlip >= 0,
		"Drift speed and slip thresholds must be nonnegative")
	assert(#config.DriftTierSeconds > 0 and #config.DriftTierSeconds == #config.DriftBoostSeconds,
		"Each drift tier must have a boost duration")
	local previousTier = 0
	for index, seconds in config.DriftTierSeconds do
		assert(seconds > previousTier, "DriftTierSeconds must be positive and increasing")
		assert(config.DriftBoostSeconds[index] >= 0, "DriftBoostSeconds must be nonnegative")
		previousTier = seconds
	end

	local ownedConfig = table.clone(config)
	ownedConfig.DriftTierSeconds = table.clone(config.DriftTierSeconds)
	ownedConfig.DriftBoostSeconds = table.clone(config.DriftBoostSeconds)
	local data: Data = {
		_config = ownedConfig,
		_mode = "Idle",
		_held = false,
		_needsRelease = false,
		_jumpSeconds = 0,
		_driftSeconds = 0,
		_unsupportedSeconds = 0,
	}
	return setmetatable(data, Gesture)
end

function Gesture.step(self: State, dt: number, input: Input, contact: Contact): Result
	local config = self._config
	local jumpSpeed = 0
	local boostSeconds = 0

	if not input.enabled then
		reset(self)
		self._needsRelease = true
		self._held = input.held
	elseif self._needsRelease then
		if not input.held then
			self._needsRelease = false
		end
		self._held = input.held
	else
		local pressed = input.held and not self._held
		local released = not input.held and self._held
		self._held = input.held

		if pressed then
			reset(self)
			if not contact.grounded then
				self._mode = "Dive"
			elseif math.abs(input.steer) > config.SteeringDeadzone then
				self._mode = "Drift"
				if contact.grounded then
					jumpSpeed = config.HopSpeed
				end
			elseif contact.grounded then
				self._mode = "JumpCharge"
			end
		end

		if self._mode == "Dive" then
			if released then reset(self) end
		elseif self._mode == "JumpCharge" then
			if contact.grounded then
				self._unsupportedSeconds = 0
				if input.held then
					self._jumpSeconds = math.min(config.JumpChargeSeconds, self._jumpSeconds + dt)
				end
			else
				self._unsupportedSeconds += dt
				if self._unsupportedSeconds > config.LedgeGraceSeconds then
					reset(self)
				end
			end

			if released and self._mode == "JumpCharge" then
				local charge = self._jumpSeconds / config.JumpChargeSeconds
				jumpSpeed = config.HopSpeed + (config.ChargedHopSpeed - config.HopSpeed) * charge
				reset(self)
			end
		elseif self._mode == "Drift" then
			if released then
				for index = #config.DriftTierSeconds, 1, -1 do
					if self._driftSeconds + 1e-9 >= config.DriftTierSeconds[index] then
						boostSeconds = config.DriftBoostSeconds[index]
						break
					end
				end
				reset(self)
			elseif contact.grounded and jumpSpeed == 0
				and contact.speed >= config.MinDriftSpeed
				and math.abs(contact.slip) >= config.MinDriftSlip then
				local maximum = config.DriftTierSeconds[#config.DriftTierSeconds]
				self._driftSeconds = math.min(maximum, self._driftSeconds + dt)
			end
		end
	end

	return {
		mode = self._mode,
		jumpSpeed = jumpSpeed,
		boostSeconds = boostSeconds,
		jumpCharge = self._jumpSeconds / config.JumpChargeSeconds,
		driftCharge = self._driftSeconds / config.DriftTierSeconds[#config.DriftTierSeconds],
		drifting = self._mode == "Drift" and contact.grounded and input.held and jumpSpeed == 0,
		diving = self._mode == "Dive" and not contact.grounded and input.held,
	}
end

function Gesture.stepEvents(self: State, dt: number, input: Input, contact: Contact, edges: { Input }): Result
	if not input.enabled or #edges > 8 then
		return self:step(dt, {
			steer = input.steer,
			held = input.held,
			enabled = false,
		}, contact)
	end

	local frameContact = contact
	local jumpSpeed = 0
	local boostSeconds = 0
	for _, edge in edges do
		local result = self:step(0, edge, frameContact)
		jumpSpeed = math.max(jumpSpeed, result.jumpSpeed)
		boostSeconds = math.max(boostSeconds, result.boostSeconds)
		if result.jumpSpeed > 0 then
			frameContact = { grounded = false, speed = contact.speed, slip = contact.slip }
		end
	end

	local result = self:step(dt, input, frameContact)
	result.jumpSpeed = math.max(jumpSpeed, result.jumpSpeed)
	result.boostSeconds = math.max(boostSeconds, result.boostSeconds)
	return result
end

return Gesture
