--!strict

type GestureModule = typeof(require("../../packages/RideRuntime/Gesture"))

return function(Gesture: GestureModule)
	local passed = 0
	local config = {
		SteeringDeadzone = 0.15,
		HopSpeed = 10,
		ChargedHopSpeed = 20,
		JumpChargeSeconds = 0.4,
		LedgeGraceSeconds = 0.1,
		MinDriftSpeed = 8,
		MinDriftSlip = 0.15,
		DriftTierSeconds = { 0.4, 0.9 },
		DriftBoostSeconds = { 0.15, 0.4 },
	}

	local function check(name: string, run: () -> ())
		local ok, message = pcall(run)
		assert(ok, name .. ": " .. tostring(message))
		passed += 1
	end

	local function near(actual: number, expected: number, message: string)
		assert(math.abs(actual - expected) < 1e-8,
			string.format("%s: expected %.9f, got %.9f", message, expected, actual))
	end

	local function step(state: typeof(Gesture.new(config)), dt: number, steer: number, held: boolean,
		grounded: boolean, speed: number?, slip: number?, enabled: boolean?)
		return state:step(dt, {
			steer = steer,
			held = held,
			enabled = enabled ~= false,
		}, {
			grounded = grounded,
			speed = speed or 16,
			slip = slip or 0.3,
		})
	end

	check("idle produces no action", function()
		local result = step(Gesture.new(config), 1, 1, false, true)
		assert(result.mode == "Idle" and not result.drifting)
		assert(result.jumpSpeed == 0 and result.boostSeconds == 0)
		assert(result.jumpCharge == 0 and result.driftCharge == 0)
	end)

	check("a neutral tap hops immediately on release", function()
		local state = Gesture.new(config)
		local pressed = step(state, 0, 0, true, true)
		assert(pressed.mode == "JumpCharge" and pressed.jumpSpeed == 0)
		local released = step(state, 0, 0, false, true)
		assert(released.mode == "Idle")
		near(released.jumpSpeed, config.HopSpeed, "tap hop")
		assert(released.boostSeconds == 0)
		assert(step(state, 1, 0, false, true).jumpSpeed == 0)
	end)

	check("neutral charging survives later steering and countersteering", function()
		local state = Gesture.new(config)
		step(state, 0, 0, true, true)
		local turning = step(state, 0.1, 1, true, true)
		assert(turning.mode == "JumpCharge" and turning.jumpSpeed == 0)
		local countersteering = step(state, 0.1, -1, true, true)
		assert(countersteering.mode == "JumpCharge" and not countersteering.drifting)
		near(countersteering.jumpCharge, 0.5, "half charged")
		near(step(state, 0, -1, false, true).jumpSpeed, 15, "charged release")
	end)

	check("maximum jump charge waits indefinitely for release", function()
		local state = Gesture.new(config)
		local held = step(state, 4, 0, true, true)
		near(held.jumpCharge, 1, "charge clamp")
		assert(held.jumpSpeed == 0)
		assert(step(state, 4, 0, true, true).jumpSpeed == 0)
		near(step(state, 0, 0, false, true).jumpSpeed, 20, "maximum hop")
	end)

	check("steering press hops once and remains drift after neutral or opposite steer", function()
		local state = Gesture.new(config)
		local pressed = step(state, 0, 1, true, true)
		assert(pressed.mode == "Drift" and not pressed.drifting)
		near(pressed.jumpSpeed, 10, "drift entry hop")
		local airborne = step(state, 0.3, 0, true, false)
		assert(airborne.mode == "Drift" and not airborne.drifting)
		assert(airborne.jumpSpeed == 0 and airborne.jumpCharge == 0)
		local landed = step(state, 0.4, -1, true, true)
		assert(landed.mode == "Drift" and landed.drifting and landed.jumpSpeed == 0)
		local released = step(state, 0, -1, false, true)
		near(released.boostSeconds, 0.15, "first drift tier")
		assert(released.jumpSpeed == 0)
	end)

	check("deadzone boundary selects neutral and either direction selects drift", function()
		for _, steer in { -0.15, 0, 0.15 } do
			assert(step(Gesture.new(config), 0, steer, true, true).mode == "JumpCharge")
		end
		for _, steer in { -0.1501, 0.1501 } do
			assert(step(Gesture.new(config), 0, steer, true, true).mode == "Drift")
		end
	end)

	check("airborne steering press dives without creating an air or landing hop", function()
		local state = Gesture.new(config)
		local airborne = step(state, 2, 1, true, false)
		assert(airborne.mode == "Dive" and airborne.diving and airborne.jumpSpeed == 0)
		assert(airborne.driftCharge == 0 and not airborne.drifting)
		local landed = step(state, 0.1, 1, true, true)
		assert(not landed.drifting and not landed.diving and landed.jumpSpeed == 0)
		assert(step(state, 0, 1, false, true).jumpSpeed == 0)
	end)

	check("releasing a dive before landing returns to float", function()
		local state = Gesture.new(config)
		step(state, 0, 1, true, false)
		local released = step(state, 0, 1, false, false)
		assert(released.boostSeconds == 0 and released.jumpSpeed == 0)
		local landed = step(state, 1, 1, false, true)
		assert(landed.mode == "Idle" and not landed.drifting)
	end)

	check("drift charge excludes airtime, low speed, and insufficient slip", function()
		local state = Gesture.new(config)
		step(state, 0, 1, true, true)
		assert(step(state, 1, 1, true, false).driftCharge == 0)
		assert(step(state, 1, 1, true, true, 7, 0.3).driftCharge == 0)
		assert(step(state, 1, 1, true, true, 16, 0.14).driftCharge == 0)
		local valid = step(state, 0.4, 1, true, true, 8, -0.15)
		near(valid.driftCharge, 0.4 / 0.9, "negative slip counts by magnitude")
		near(step(state, 0, 1, false, true).boostSeconds, 0.15, "earned first tier")
	end)

	check("boost is tiered, capped, and emitted once", function()
		local state = Gesture.new(config)
		step(state, 0, 1, true, true)
		near(step(state, 3, 1, true, true).driftCharge, 1, "drift charge clamp")
		local released = step(state, 0, 1, false, true)
		near(released.boostSeconds, 0.4, "highest boost tier")
		assert(released.jumpSpeed == 0 and released.driftCharge == 0)
		assert(step(state, 1, 1, false, true).boostSeconds == 0)
		step(state, 0, 1, true, true)
		assert(step(state, 0, 1, false, true).boostSeconds == 0)
	end)

	check("airborne drift release spends existing charge without an air hop", function()
		local state = Gesture.new(config)
		step(state, 0, 1, true, true)
		step(state, 0.4, 1, true, true)
		local released = step(state, 0.1, 1, false, false)
		near(released.boostSeconds, 0.15, "saved drift tier")
		assert(released.jumpSpeed == 0 and not released.drifting)
	end)

	check("charge freezes in ledge grace and may release there", function()
		local state = Gesture.new(config)
		step(state, 0.2, 0, true, true)
		near(step(state, 0.05, 0, true, false).jumpCharge, 0.5, "airtime adds no charge")
		near(step(state, 0, 0, false, false).jumpSpeed, 15, "grace release")
	end)

	check("expired ledge grace cancels until a new press even after landing", function()
		local state = Gesture.new(config)
		step(state, 0.2, 0, true, true)
		local expired = step(state, 0.11, 1, true, false)
		assert(expired.mode == "Idle" and expired.jumpCharge == 0)
		local landed = step(state, 1, 1, true, true)
		assert(landed.mode == "Idle" and landed.jumpSpeed == 0)
		assert(step(state, 0, 1, false, true).jumpSpeed == 0)
		near(step(state, 0, 1, true, true).jumpSpeed, 10, "fresh press rearms")
	end)

	check("release after grace expires cannot launch", function()
		local state = Gesture.new(config)
		step(state, 0.4, 0, true, true)
		local released = step(state, 0.11, 0, false, false)
		assert(released.jumpSpeed == 0 and released.mode == "Idle")
	end)

	check("neutral press in the air cannot become a landing jump", function()
		local state = Gesture.new(config)
		assert(step(state, 0.2, 0, true, false).mode == "Dive")
		assert(step(state, 0.4, 0, true, true).jumpCharge == 0)
		assert(step(state, 0, 0, false, true).jumpSpeed == 0)
	end)

	check("disabled input cancels charge and requires an enabled release", function()
		local state = Gesture.new(config)
		step(state, 0.4, 0, true, true)
		local disabled = step(state, 0, 0, true, true, nil, nil, false)
		assert(disabled.mode == "Idle" and disabled.jumpSpeed == 0)
		assert(step(state, 1, 1, true, true).jumpSpeed == 0)
		assert(step(state, 0, 1, false, true).jumpSpeed == 0)
		near(step(state, 0, 1, true, true).jumpSpeed, 10, "release rearms")
	end)

	check("disabled release cannot fire a charged jump or earned boost", function()
		for _, steer in { 0, 1 } do
			local state = Gesture.new(config)
			step(state, 0, steer, true, true)
			step(state, 1, steer, true, true)
			local result = step(state, 0, steer, false, true, nil, nil, false)
			assert(result.jumpSpeed == 0 and result.boostSeconds == 0)
			assert(step(state, 0, steer, false, true).boostSeconds == 0)
		end
	end)

	check("charge and boost thresholds agree at 30, 60, and 120 FPS", function()
		for _, fps in { 30, 60, 120 } do
			local charge = Gesture.new(config)
			step(charge, 0, 0, true, true)
			for _ = 1, fps * 0.2 do
				step(charge, 1 / fps, 0, true, true)
			end
			near(step(charge, 0, 0, false, true).jumpSpeed, 15,
				"half charge at " .. tostring(fps) .. " FPS")
			local drift = Gesture.new(config)
			step(drift, 0, 1, true, true)
			for _ = 1, fps * 0.4 do
				step(drift, 1 / fps, 1, true, true)
			end
			near(step(drift, 0, 1, false, true).boostSeconds, 0.15,
				"first drift tier at " .. tostring(fps) .. " FPS")
		end
	end)

	check("queued neutral press and release produce a tap within one simulation tick", function()
		local state = Gesture.new(config)
		local contact = { grounded = true, speed = 16, slip = 0.3 }
		local released = { steer = 0, held = false, enabled = true }
		local result = state:stepEvents(1 / 30, released, contact, {
			{ steer = 0, held = true, enabled = true },
			released,
		})
		near(result.jumpSpeed, 10, "queued tap hop")
		assert(result.mode == "Idle" and result.jumpCharge == 0 and result.boostSeconds == 0)
		assert(contact.grounded, "processing a jump must not mutate the caller's contact")
		assert(state:stepEvents(1 / 30, released, contact, {}).jumpSpeed == 0)
	end)

	check("queued press uses initial steering even when neutral before simulation", function()
		local state = Gesture.new(config)
		local result = state:stepEvents(0.2,
			{ steer = 0, held = true, enabled = true },
			{ grounded = true, speed = 16, slip = 0.3 }, {
				{ steer = 1, held = true, enabled = true },
			})
		assert(result.mode == "Drift" and result.jumpSpeed == 10)
		assert(result.jumpCharge == 0 and result.driftCharge == 0 and not result.drifting)
	end)

	check("queued neutral press keeps charge mode through later steering", function()
		local state = Gesture.new(config)
		local result = state:stepEvents(0.2,
			{ steer = 1, held = true, enabled = true },
			{ grounded = true, speed = 16, slip = 0.3 }, {
				{ steer = 0, held = true, enabled = true },
			})
		assert(result.mode == "JumpCharge" and result.jumpSpeed == 0)
		near(result.jumpCharge, 0.5, "only the final elapsed step charges")
	end)

	check("zero-time queued input does not accumulate charge", function()
		local state = Gesture.new(config)
		local held = { steer = 0, held = true, enabled = true }
		local result = state:stepEvents(0, held,
			{ grounded = true, speed = 16, slip = 0.3 }, { held, held, held })
		assert(result.mode == "JumpCharge" and result.jumpCharge == 0)
	end)

	check("disabled current input discards queued actions and earned charge", function()
		local state = Gesture.new(config)
		step(state, 0.4, 0, true, true)
		local result = state:stepEvents(0.1,
			{ steer = 1, held = false, enabled = false },
			{ grounded = true, speed = 16, slip = 0.3 }, {
				{ steer = 0, held = false, enabled = true },
				{ steer = 1, held = true, enabled = true },
			})
		assert(result.mode == "Idle" and result.jumpSpeed == 0 and result.boostSeconds == 0)
		assert(step(state, 0, 1, true, true).jumpSpeed == 0)
		step(state, 0, 1, false, true)
		assert(step(state, 0, 1, true, true).jumpSpeed == 10)
	end)

	check("multiple queued presses cannot sum hops or award another air hop", function()
		local state = Gesture.new(config)
		local released = { steer = 1, held = false, enabled = true }
		local pressed = { steer = 1, held = true, enabled = true }
		local result = state:stepEvents(0.2, released,
			{ grounded = true, speed = 16, slip = 0.3 }, {
				pressed, released, pressed, released, pressed, released, pressed, released,
			})
		near(result.jumpSpeed, 10, "one hop per physics frame")
		assert(result.boostSeconds == 0 and result.mode == "Idle")
	end)

	check("queued boost release and next hop retain both one-shot outputs", function()
		local state = Gesture.new(config)
		step(state, 0, 1, true, true)
		step(state, 0.4, 1, true, true)
		local pressed = { steer = 1, held = true, enabled = true }
		local result = state:stepEvents(0.1, pressed,
			{ grounded = true, speed = 16, slip = 0.3 }, {
				{ steer = 1, held = false, enabled = true },
				pressed,
			})
		near(result.boostSeconds, 0.15, "queued earned boost")
		near(result.jumpSpeed, 10, "queued next hop")
		assert(result.mode == "Drift" and not result.drifting and result.driftCharge == 0)
	end)

	check("more than eight queued edges cancel before awarding any action", function()
		local state = Gesture.new(config)
		local pressed = { steer = 1, held = true, enabled = true }
		local result = state:stepEvents(0.1, pressed,
			{ grounded = true, speed = 16, slip = 0.3 }, table.create(9, pressed))
		assert(result.mode == "Idle" and result.jumpSpeed == 0 and result.boostSeconds == 0)
		assert(step(state, 0, 1, true, true).jumpSpeed == 0)
		step(state, 0, 1, false, true)
		assert(step(state, 0, 1, true, true).jumpSpeed == 10)
	end)

	check("charged release floats until a new airborne press dives", function()
		local state = Gesture.new(config)
		step(state, 0.4, 0, true, true)
		local launch = step(state, 0, 0, false, true)
		assert(launch.jumpSpeed == 20 and not launch.diving)
		assert(not step(state, 0.05, 0, false, false).diving)
		local dive = step(state, 0.05, 1, true, false)
		assert(dive.diving and dive.mode == "Dive" and dive.jumpSpeed == 0)
		assert(not step(state, 0.05, 1, false, false).diving)
	end)
	check("holding the original drift hop cannot trigger a dive", function()
		local state = Gesture.new(config)
		step(state, 0, 1, true, true)
		local air = step(state, 0.1, 1, true, false)
		assert(air.mode == "Drift" and not air.diving)
	end)
	check("landing with dive held does not launch or drift until released", function()
		local state = Gesture.new(config)
		step(state, 0, 0, true, false)
		local landed = step(state, 0.1, 1, true, true)
		assert(not landed.diving and landed.jumpSpeed == 0 and not landed.drifting)
		step(state, 0, 0, false, true)
		assert(step(state, 0.1, 0, true, true).mode == "JumpCharge")
	end)
	return { passed = passed }
end
