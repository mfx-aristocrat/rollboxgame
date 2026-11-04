-- Pure session-only exploration. No profile, currency or delivery state is accepted.
local Rules = {}
local scores = { token = 1, crate = 5, landmark = 10 }
local radii = { token = 5, crate = 9, landmark = 8 }

local function finite(value)
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end
function Rules.validPosition(position)
	return type(position) == "table" and finite(position[1]) and finite(position[2]) and finite(position[3])
end
local function validId(id)
	return type(id) == "string" and #id > 0 and #id <= 80
end
local function positionCopy(position)
	return { position[1], position[2], position[3] }
end
function Rules.catalog(items, springs)
	local catalog = { items = {}, springs = {}, total = 0, landmarkTotal = 0 }
	local ids = {}
	for _, spec in items do
		assert(validId(spec.id) and not ids[spec.id], "Unique adventure item ID required")
		assert(scores[spec.kind] and spec.score == scores[spec.kind], "Fixed adventure score required")
		assert(Rules.validPosition(spec.position), "Finite adventure position required")
		ids[spec.id] = true
		catalog.items[spec.id] = {
			id = spec.id, kind = spec.kind, score = spec.score, position = positionCopy(spec.position),
		}
		catalog.total += 1
		if spec.kind == "landmark" then catalog.landmarkTotal += 1 end
	end
	for _, spec in springs do
		assert(validId(spec.id) and not ids[spec.id], "Unique adventure spring ID required")
		assert(Rules.validPosition(spec.position), "Finite spring position required")
		assert(finite(spec.launchSpeed) and spec.launchSpeed >= 48 and spec.launchSpeed <= 100, "Bounded spring speed required")
		ids[spec.id] = true
		catalog.springs[spec.id] = {
			id = spec.id, position = positionCopy(spec.position), launchSpeed = spec.launchSpeed,
		}
	end
	return catalog
end
function Rules.newState()
	return { collectedIds = {}, score = 0, collected = 0, landmarks = 0,
		lastCollectAt = -math.huge, lastCrateAt = -math.huge, lastSpringAt = -math.huge,
		message = "Explore for trail tokens, free crates and landmark flags. Session score resets on leave." }
end
local function validObservation(position, alive, now)
	return alive == true and Rules.validPosition(position) and finite(now) and now >= 0
end
local function within(position, target, radius)
	local squared = 0
	for index = 1, 3 do squared += (position[index] - target[index]) ^ 2 end
	return squared <= radius ^ 2
end
function Rules.collect(catalog, state, id, position, alive, now)
	local spec = catalog.items[id]
	if not spec then return false, "unknown_item" end
	if not validObservation(position, alive, now) then return false, "invalid_observation" end
	-- Prompt attempts consume their cooldown before range/duplicate checks.
	if spec.kind == "crate" then
		if now - state.lastCrateAt < 0.35 then return false, "rate_limited" end
		state.lastCrateAt = now
	end
	if state.collectedIds[id] then return false, "already_collected" end
	if not within(position, spec.position, radii[spec.kind]) then return false, "too_far" end
	if now - state.lastCollectAt < 0.075 then return false, "cooldown" end
	state.lastCollectAt = now
	state.collectedIds[id] = true
	state.collected += 1
	state.score += spec.score
	if spec.kind == "landmark" then state.landmarks += 1 end
	state.message = if spec.kind == "token" then "+1 trail token"
		elseif spec.kind == "crate" then "+5 bonus crate opened!"
		else "+10 landmark discovered!"
	return true
end
function Rules.spring(catalog, state, id, position, alive, running, now)
	local spec = catalog.springs[id]
	if not spec then return false, "unknown_spring" end
	if not validObservation(position, alive, now) then return false, "invalid_observation" end
	local dx, dz = position[1] - spec.position[1], position[3] - spec.position[3]
	local height = position[2] - spec.position[2]
	-- The root must be directly above the pad, close to the standing foot plane.
	if dx * dx + dz * dz > 4.5 ^ 2 or height < 1.5 or height > 6.5 then return false, "too_far" end
	if running ~= false then
		state.message = "Deliver your parcel before using a spring."
		return false, "delivery_active"
	end
	if now - state.lastSpringAt < 2 then return false, "cooldown" end
	state.lastSpringAt = now
	state.message = "Boing! Follow the trail to the next landmark."
	return true, spec.launchSpeed
end
function Rules.snapshot(catalog, state)
	local ids = {}
	for id in state.collectedIds do table.insert(ids, id) end
	table.sort(ids)
	return { score = state.score, collected = state.collected, total = catalog.total,
		landmarks = state.landmarks, landmarkTotal = catalog.landmarkTotal,
		message = state.message, collectedIds = ids }
end
return Rules
