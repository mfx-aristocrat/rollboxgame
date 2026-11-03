--!strict
-- No Roblox globals: the server injects UpdateAsync, clocks, sleep and GUIDs.
-- All callbacks are synchronous and side-effect-free outside callback-local state.
local Persistence = {}
local SCHEMA_VERSION = 1
local MAX_INTEGER = 9_007_199_254_740_991

local function integer(value: any): boolean
	return type(value) == "number" and value == value and value >= 0
		and value <= MAX_INTEGER and value % 1 == 0
end

local function plain(value: any): boolean
	return type(value) == "table" and getmetatable(value) == nil
end

local function token(value: any): boolean
	return type(value) == "string" and #value > 0 and #value <= 128
		and string.match(value, "^[%w_%-:]+$") ~= nil
end

local function allowedFields(value: any, fields: any): boolean
	if not plain(value) then
		return false
	end
	for key in pairs(value) do
		if not fields[key] then
			return false
		end
	end
	return true
end

local function result(ok: boolean, reason: string, details: any?)
	local value = details or {}
	value.ok = ok
	value.reason = reason
	return value
end

function Persistence.storeName(environment: string): string
	assert(environment == "test" or environment == "production", "Explicit test or production environment required")
	return "SwitchbackCouriers_" .. environment .. "_v1"
end

function Persistence.new(deps: any)
	Persistence.storeName(deps.environment)
	for _, name in { "update", "now", "sleep", "makeToken" } do
		assert(type(deps[name]) == "function", "Missing persistence dependency: " .. name)
	end
	local profile = deps.profile
	assert(type(profile) == "table" and type(profile.validate) == "function"
		and type(profile.copy) == "function" and type(profile.default) == "function", "Missing profile codec")
	local leaseSeconds = deps.leaseSeconds or 180
	local attempts = deps.attempts or 3
	local random = deps.random or math.random
	local isRetryable = deps.isRetryable or function()
		return true
	end
	assert(integer(leaseSeconds) and leaseSeconds >= 30 and leaseSeconds <= 600, "Lease must be 30..600 seconds")
	assert(integer(attempts) and attempts >= 1 and attempts <= 5, "Attempts must be 1..5")
	local sessions: any = {}
	local service = {}

	local function freshToken(): string
		local value = deps.makeToken()
		assert(token(value), "makeToken must return a unique ASCII token")
		return value
	end

	local function keyFor(userId: any): string?
		if not integer(userId) or userId < 1 then
			return nil
		end
		return deps.environment .. ":User_" .. string.format("%.0f", userId)
	end

	local function validateRecord(value: any): (boolean, string?)
		if not allowedFields(value, { schemaVersion = true, profile = true, session = true, lastWrite = true }) then
			return false, "invalid_record"
		end
		if value.schemaVersion ~= SCHEMA_VERSION then
			return false, "unsupported_schema"
		end
		local valid, reason = profile.validate(value.profile)
		if not valid then
			return false, reason
		end
		if value.session ~= nil then
			if not allowedFields(value.session, { token = true, expiresAt = true })
				or not token(value.session.token) or not integer(value.session.expiresAt) then
				return false, "invalid_session"
			end
		end
		if value.lastWrite ~= nil and not token(value.lastWrite) then
			return false, "invalid_write_id"
		end
		return true, nil
	end

	local function record(data: any, owner: string?, expiresAt: number?, writeId: string?)
		return {
			schemaVersion = SCHEMA_VERSION,
			profile = profile.copy(data),
			session = if owner then { token = owner, expiresAt = expiresAt } else nil,
			lastWrite = writeId,
		}
	end

	-- A deadline bounds scheduling/retries, not a network call already in flight.
	local function transact(key: string, userId: number, transform: any, deadline: number?)
		for attempt = 1, attempts do
			if deadline and deps.now() >= deadline then
				return result(false, "deadline", { attempts = attempt - 1 })
			end
			local decision = "cancelled"
			local ok, value = pcall(deps.update, key, function(current: any, keyInfo: any)
				-- UpdateAsync may discard this callback's proposed value and call again.
				local proposed, reason = transform(current)
				decision = reason
				if proposed == nil then
					return nil
				end
				local userIds = if keyInfo then keyInfo:GetUserIds() else { userId }
				local metadata = if keyInfo then keyInfo:GetMetadata() else nil
				return proposed, userIds, metadata
			end)
			if ok and value ~= nil and decision == "ok" then
				return result(true, "ok", { record = value, attempts = attempt })
			end
			local reason = if ok then decision else "store_unavailable"
			local retry = (ok and reason == "session_locked") or (not ok and isRetryable(value))
			if not retry or attempt == attempts then
				return result(false, reason, { attempts = attempt, error = if ok then nil else tostring(value) })
			end
			local delay = math.min(2 ^ (attempt - 1), 4) + math.clamp(random(), 0, 1) * 0.25
			if deadline and deps.now() + delay >= deadline then
				return result(false, "deadline", { attempts = attempt })
			end
			deps.sleep(delay)
		end
		error("Unreachable retry state")
	end

	function service.status(userId: number)
		local session = sessions[userId]
		if not session then
			return result(false, "not_loaded", { canWrite = false, busy = false })
		end
		local validLease = session.expiresAt ~= nil and deps.now() < session.expiresAt
		return result(session.phase == "active" and validLease, session.phase, {
			canWrite = session.phase == "active" and validLease,
			busy = session.busy,
			expiresAt = session.expiresAt,
			lastError = session.lastError,
		})
	end

	function service.load(userId: number, deadline: number?)
		local key = keyFor(userId)
		if not key then
			return result(false, "invalid_user_id")
		end
		local previous = sessions[userId]
		if previous and previous.busy then
			return result(false, "busy")
		end
		if previous and previous.phase ~= "load_failed" and previous.phase ~= "released" then
			return result(false, "already_loaded")
		end
		-- A failed load may have committed a lock before the network response failed.
		local session = {
			token = if previous and previous.phase == "load_failed" then previous.token else freshToken(),
			phase = "loading",
			busy = true,
		}
		sessions[userId] = session
		local outcome = transact(key, userId, function(current: any)
			local data
			if current == nil then
				data = profile.default()
			else
				local valid, reason = validateRecord(current)
				if not valid then
					return nil, reason
				end
				if current.session and current.session.token ~= session.token and current.session.expiresAt > deps.now() then
					return nil, "session_locked"
				end
				data = current.profile
			end
			return record(data, session.token, deps.now() + leaseSeconds, if current then current.lastWrite else nil), "ok"
		end, deadline)
		session.busy = false
		if outcome.ok then
			local value = outcome.record
			local valid = validateRecord(value)
			if not valid or not value.session or value.session.token ~= session.token or value.session.expiresAt <= deps.now() then
				outcome = result(false, "unconfirmed_load")
			else
				session.phase = "active"
				session.expiresAt = value.session.expiresAt
				return result(true, "ok", { profile = profile.copy(value.profile), attempts = outcome.attempts })
			end
		end
		session.phase = "load_failed"
		session.lastError = outcome.reason
		return outcome
	end

	local function write(userId: number, data: any, release: boolean, deadline: number?)
		local key = keyFor(userId)
		if not key then
			return result(false, "invalid_user_id")
		end
		local session = sessions[userId]
		if not session then
			return result(false, "not_loaded")
		end
		if session.busy then
			return result(false, "busy")
		end
		if release and session.phase == "released" then
			return result(true, "already_released")
		end
		if session.phase ~= "active" and not (release and session.phase == "closing") then
			return result(false, "not_writable")
		end
		if session.phase == "active" and deps.now() >= session.expiresAt then
			session.phase = "lost"
			return result(false, "lease_expired")
		end
		local pending = session.pendingRelease
		if not pending then
			local valid, reason = profile.validate(data)
			if not valid then
				return result(false, "invalid_profile", { detail = reason })
			end
			pending = { profile = profile.copy(data), id = freshToken() }
		end
		if release then
			-- Preserve exactly this operation when PlayerRemoving and BindToClose retry.
			session.phase = "closing"
			session.pendingRelease = pending
		end
		session.busy = true
		local outcome = transact(key, userId, function(current: any)
			local valid, reason = validateRecord(current)
			if not valid then
				return nil, reason
			end
			if current.lastWrite == pending.id then
				-- A previous attempt committed but its response was lost. No replay.
				return current, "ok"
			end
			if not current.session or current.session.token ~= session.token then
				return nil, "lock_lost"
			end
			if current.session.expiresAt <= deps.now() then
				return nil, "lease_expired"
			end
			return record(pending.profile, if release then nil else session.token,
				if release then nil else deps.now() + leaseSeconds, pending.id), "ok"
		end, deadline)
		session.busy = false
		if outcome.ok then
			local value = outcome.record
			local valid = validateRecord(value)
			if not valid or value.lastWrite ~= pending.id then
				outcome = result(false, "unconfirmed_write")
			elseif release then
				session.phase = "released"
				session.pendingRelease = nil
				session.lastError = nil
				return result(true, "ok", { attempts = outcome.attempts })
			elseif not value.session or value.session.token ~= session.token or value.session.expiresAt <= deps.now() then
				outcome = result(false, "lock_lost")
			else
				session.expiresAt = value.session.expiresAt
				session.lastError = nil
				return result(true, "ok", { attempts = outcome.attempts })
			end
		end
		session.lastError = outcome.reason
		if outcome.reason ~= "store_unavailable" and outcome.reason ~= "deadline" then
			session.phase = "lost"
		end
		return outcome
	end

	function service.save(userId: number, data: any, deadline: number?)
		return write(userId, data, false, deadline)
	end

	function service.release(userId: number, data: any, deadline: number?)
		return write(userId, data, true, deadline)
	end

	-- Drop terminal bookkeeping after the caller has joined all lifecycle workers.
	-- Never forget an active/in-flight session or an uncertain final release.
	function service.forget(userId: number)
		local session = sessions[userId]
		if session and (session.busy or ((session.phase == "active" or session.phase == "closing")
			and session.expiresAt ~= nil and deps.now() < session.expiresAt)) then
			return result(false, "session_in_use")
		end
		sessions[userId] = nil
		return result(true, "ok")
	end

	return service
end

return Persistence
