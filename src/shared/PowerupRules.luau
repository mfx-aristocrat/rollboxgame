-- Pure observations/rules. Engine input and physics remain in the server adapter.
local Rules = {}
function Rules.finite(value)
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end
function Rules.validPosition(point)
	if type(point) ~= "table" then return false end
	for index = 1, 3 do
		if not Rules.finite(point[index]) or math.abs(point[index]) > 10_000_000 then return false end
	end
	return true
end
function Rules.newState()
	return { unlocked = false, phase = "unarmed", ready = false, groundSince = nil,
		lastObservation = -math.huge, lastJump = -math.huge,
		lastRequest = -math.huge, lastPickup = -math.huge,
		message = "Find a mushroom crate to unlock double jump." }
end
function Rules.resetAir(state)
	state.phase, state.ready, state.groundSince, state.airborne = "unarmed", false, nil, false
	state.lastObservation = -math.huge
end
function Rules.admit(config, state, channel, now)
	if not Rules.finite(now) then return false end
	local field = if channel == "pickup" then "lastPickup" else "lastRequest"
	local interval = if channel == "pickup" then config.pickupInterval else config.requestInterval
	if now - state[field] < interval then return false end
	state[field] = now
	return true
end
function Rules.collect(config, state, point, isAlive)
	if state.unlocked or isAlive ~= true or not Rules.validPosition(point) then return false end
	local distance = 0
	for index = 1, 3 do distance += (point[index] - config.cratePosition[index]) ^ 2 end
	if distance > config.pickupRadius ^ 2 then return false end
	state.unlocked = true
	state.message = "Mushroom found! Press jump again in the air."
	return true
end
function Rules.observe(config, state, sample, now)
	if not Rules.finite(now) or now < state.lastObservation then return false end
	if not sample or sample.alive ~= true or not Rules.validPosition(sample.position)
		or not Rules.validPosition(sample.velocity) then
		Rules.resetAir(state)
		return false
	end
	state.lastObservation = now
	local vertical = sample.velocity[2]
	state.airborne = sample.grounded ~= true or vertical >= config.takeoffMinVerticalSpeed
	if sample.grounded == true and math.abs(vertical) <= config.landingMaxVerticalSpeed then
		state.groundY=sample.position[2]
		if not state.groundSince then state.groundSince = now end
		if now - state.groundSince >= config.landingStableTime then
			state.phase, state.ready = "grounded", false
		end
	else
		state.groundSince = nil
		if state.phase == "grounded" then
			state.phase, state.takeoffAt = "pending", now
		end
		if state.phase == "pending" then
			if vertical >= config.takeoffMinVerticalSpeed or (state.groundY and sample.position[2]>state.groundY+0.2) then state.phase, state.ready = "air", true
			elseif vertical < 0 or now-state.takeoffAt > 0.25 then state.phase = "falling" end
		end
	end
	return true
end
function Rules.consume(config, state, now)
	if not Rules.finite(now) or now ~= state.lastObservation or not state.unlocked
		or not state.airborne or state.phase ~= "air" or not state.ready or now - state.lastJump < config.jumpCooldown then return false end
	-- Consume before the adapter writes physics; duplicate requests cannot stack.
	state.ready, state.lastJump = false, now
	state.message = "Double jump! Land to recharge."
	return true
end
function Rules.snapshot(state)
	return { unlocked = state.unlocked, ready = state.unlocked and (state.ready or state.phase == "grounded"), message = state.message }
end
return Rules
