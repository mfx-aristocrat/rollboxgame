-- Pure server rules. Time/IDs/spatial observations are supplied by the server adapter.
local RunRules = {}
local function finite(n)
	return type(n) == "number" and n == n and math.abs(n) < math.huge
end
local actions = {
	Start = "transaction", Retry = "transaction", Switch = "switch",
	BuyMint = "transaction", EquipDefault = "transaction", EquipMint = "transaction", Snapshot = "snapshot",
	DoubleJump = "jump",
	ReturnLand = "rescue",
}

function RunRules.newLimiter(now)
	return { total = { tokens = 8, at = now }, groups = {} }
end
local function take(bucket, now, rate, capacity)
	if not finite(now) or now < bucket.at then return false end
	bucket.tokens = math.min(capacity, bucket.tokens + (now - bucket.at) * rate)
	bucket.at = now
	if bucket.tokens < 1 then return false end
	bucket.tokens -= 1
	return true
end
function RunRules.admitIntent(limiter, action, argument, now)
	-- No payload tables, instance references, route IDs or client times are accepted.
	if not take(limiter.total, now, 4, 8) then return false, "rate_limited" end
	if type(action) ~= "string" or #action > 24 or not actions[action] or (argument ~= nil and action ~= "DoubleJump") then
		return false, "invalid_intent"
	end
	local group = actions[action]
	local bucket = limiter.groups[group]
	if not bucket then
		bucket = { tokens = 2, at = now }
		limiter.groups[group] = bucket
	end
	if not take(bucket, now, 2, 2) then return false, "rate_limited" end
	return true
end

function RunRules.start(now, id)
	assert(finite(now) and type(id) == "string", "Server run ID/time required")
	return {
		id = id, state = "Running", startedAt = now, lastSwitchAt = -math.huge,
		polarity = "Amber", nextGate = 1, checkpoint = 0, rewarded = false,
	}
end
function RunRules.elapsed(run, now)
	return math.max(0, now - run.startedAt)
end
function RunRules.active(run, now, config)
	return run ~= nil and run.state == "Running" and finite(now)
		and now >= run.startedAt and now - run.startedAt <= config.maxRunSeconds
end
function RunRules.toggle(run, now, config)
	if not RunRules.active(run, now, config) then return false, "inactive" end
	if now - run.lastSwitchAt < config.switchCooldown then return false, "cooldown" end
	run.lastSwitchAt = now
	run.polarity = if run.polarity == "Amber" then "Cyan" else "Amber"
	return true
end
function RunRules.gate(run, index, now, config)
	if not RunRules.active(run, now, config) then return false, "inactive" end
	if type(index) ~= "number" or index % 1 ~= 0 or not config.route.gates[index] then return false, "invalid_gate" end
	if index ~= run.nextGate then return false, "out_of_order" end
	local gate = config.route.gates[index]
	if RunRules.elapsed(run, now) < gate.distance / config.maxMovementSpeed then return false, "implausible_time" end
	if run.polarity ~= gate.polarity then return false, "wrong_polarity" end
	run.checkpoint = index
	run.nextGate += 1
	return true
end
function RunRules.finish(run, now, config)
	if not RunRules.active(run, now, config) then return false, "inactive" end
	if run.nextGate ~= #config.route.gates + 1 then return false, "gates_remaining" end
	local minimum = math.abs(config.route.destination[3] - config.route.depot[3]) / config.maxMovementSpeed
	if RunRules.elapsed(run, now) < minimum then return false, "implausible_time" end
	run.state = "Completed"
	run.resultTime = RunRules.elapsed(run, now)
	return true
end
function RunRules.abort(run)
	if run then run.state = "Idle" end
end
function RunRules.validPosition(position)
	return type(position) == "table" and finite(position[1]) and finite(position[2]) and finite(position[3])
end
function RunRules.validMovement(previous, current, dt, config)
	if not RunRules.validPosition(previous) or not RunRules.validPosition(current) or not finite(dt) or dt < 0 then return false end
	local squared = 0
	for index = 1, 3 do squared += (current[index] - previous[index]) ^ 2 end
	return math.sqrt(squared) <= config.maxMovementSpeed * dt + config.movementTolerance
end
-- A directed swept plane crossing catches a gate even between samples. Gate width
-- and height are fixed to the generated opening; walking around it cannot advance.
function RunRules.crossedGate(previous, current, gate)
	local z = gate.position[3]
	if previous[3] <= z or current[3] > z then return false end
	local alpha = (previous[3] - z) / (previous[3] - current[3])
	local x = previous[1] + (current[1] - previous[1]) * alpha
	local y = previous[2] + (current[2] - previous[2]) * alpha
	return math.abs(x - gate.position[1]) <= 7 and y >= 9 and y <= 20
end
return RunRules
