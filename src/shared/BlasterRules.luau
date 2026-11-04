-- Pure authority rules. Engine observations, projectile rays and cosmetics belong to Blaster.
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
function Rules.direction(point)
	if not Rules.validPosition(point) then return nil end
	local length = math.sqrt(point[1]^2 + point[2]^2 + point[3]^2)
	if length < 0.95 or length > 1.05 then return nil end
	return { point[1]/length, point[2]/length, point[3]/length }
end
function Rules.newState()
	return { unlocked = false, shots = 0, hits = 0, activeProjectiles = 0,
		lastRequest = -math.huge, lastPickup = -math.huge, lastFire = -math.huge,
		message = "Find the orange mushroom crate on the east trail." }
end
function Rules.admit(config, state, channel, now)
	if not Rules.finite(now) or now < 0 then return false end
	local field = if channel == "pickup" then "lastPickup" else "lastRequest"
	local interval = if channel == "pickup" then config.pickupInterval else config.requestInterval
	if now - state[field] < interval then return false end
	state[field] = now
	return true
end
function Rules.collect(config, state, point, alive)
	if state.unlocked or alive ~= true or not Rules.validPosition(point) then return false end
	local distance = 0
	for index = 1, 3 do distance += (point[index] - config.cratePosition[index])^2 end
	if distance > config.pickupRadius^2 then return false end
	state.unlocked, state.message = true, "Cannon unlocked! Aim at the striped practice targets."
	return true
end
function Rules.fire(config, state, direction, alive, now, globalActive)
	local unit = Rules.direction(direction)
	if not unit or alive ~= true or not state.unlocked or not Rules.finite(now) or now < 0
		or now - state.lastFire < config.cooldown
		or state.activeProjectiles >= config.maxPerPlayer
		or not Rules.finite(globalActive) or globalActive < 0 or globalActive >= config.maxProjectiles then return nil end
	state.lastFire = now
	state.activeProjectiles += 1
	state.shots = math.min(state.shots + 1, 999999)
	return unit
end
function Rules.retire(state)
	state.activeProjectiles = math.max(0, state.activeProjectiles - 1)
end
function Rules.hit(state)
	state.hits = math.min(state.hits + 1, 999999)
	state.message = "Bullseye! Target hits: " .. state.hits
end
function Rules.snapshot(state)
	return { unlocked = state.unlocked, shots = state.shots, hits = state.hits,
		activeProjectiles = state.activeProjectiles, message = state.message }
end
return Rules
