local Persistence = require("../src/server/Persistence")
local Profile = require("../src/shared/Profile")

local codec = Profile.createCodec({
	cosmeticIds = { default = true, mint = true, sunset = true, aurora = true, supporter = true },
	routeIds = { training = true, rooftops = true, skybridge = true },
})

local function equal(actual, expected, context)
	assert(actual == expected, (context or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local function outcome(value, ok, reason)
	equal(value.ok, ok, "success")
	if reason then
		equal(value.reason, reason, "reason")
	end
	return value
end

local function copy(value)
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for key, item in pairs(value) do
		out[key] = copy(item)
	end
	return out
end

local function fixture()
	local f = { time = 1_000, records = {}, calls = 0, writes = 0, failures = 0, postFailures = 0, delays = {}, nextToken = 0 }
	f.key = "test:User_7"
	function f.existing(coins)
		local data = codec.default()
		data.coins = coins
		data.completedRuns = 2
		data.cosmetics.mint = true
		data.equippedCosmetic = "mint"
		data.bestTimes.training = 42.5
		f.records[f.key] = { schemaVersion = 1, profile = data }
	end
	function f.newService(overrides)
		local deps = {
			environment = "test",
			profile = codec,
			leaseSeconds = 60,
			now = function() return math.floor(f.time) end,
			sleep = function(delay)
				table.insert(f.delays, delay)
				f.time += delay
			end,
			random = function() return 0 end,
			makeToken = function()
				f.nextToken += 1
				return "token_" .. f.nextToken
			end,
			update = function(key, transform)
				f.calls += 1
				if f.onCall then f.onCall() end
				if f.failures > 0 then
					f.failures -= 1
					error("simulated unavailable store")
				end
				local keyInfo = if f.metadata then {
					GetMetadata = function() return copy(f.metadata) end,
					GetUserIds = function() return copy(f.userIds) end,
				} else nil
				local proposed, userIds, metadata = transform(copy(f.records[key]), keyInfo)
				if f.reenter then
					-- The first proposal is discarded, exactly as a concurrent update can do.
					local hook = f.reenter
					f.reenter = nil
					hook(key)
					proposed, userIds, metadata = transform(copy(f.records[key]), keyInfo)
				end
				if proposed == nil then return nil end
				f.records[key] = copy(proposed)
				f.lastUserIds = userIds
				f.lastMetadata = metadata
				f.writes += 1
				if f.postFailures > 0 then
					f.postFailures -= 1
					error("response lost after committed write")
				end
				return copy(proposed)
			end,
		}
		for key, value in pairs(overrides or {}) do deps[key] = value end
		return Persistence.new(deps)
	end
	return f
end

return function()
	local count = 0
	local function test(name, run)
		local ok, failure = pcall(run)
		assert(ok, "Persistence: " .. name .. "\n" .. tostring(failure))
		count += 1
	end

	test("new profile acquired and detached", function()
		local f = fixture()
		local service = f.newService()
		local loaded = outcome(service.load(7), true)
		equal(loaded.profile.coins, 0)
		loaded.profile.cosmetics.mint = true
		equal(f.records[f.key].profile.cosmetics.mint, nil)
		equal(service.status(7).canWrite, true)
		equal(f.lastUserIds[1], 7)
	end)

	test("returning profile fields retained", function()
		local f = fixture()
		f.existing(125)
		local data = outcome(f.newService().load(7), true).profile
		equal(data.coins, 125)
		equal(data.completedRuns, 2)
		equal(data.equippedCosmetic, "mint")
		equal(data.bestTimes.training, 42.5)
	end)

	test("failed load has no writable default", function()
		local f = fixture()
		f.existing(125)
		f.failures = 10
		local service = f.newService()
		local loaded = outcome(service.load(7), false, "store_unavailable")
		equal(loaded.profile, nil)
		equal(loaded.attempts, 3)
		equal(service.status(7).canWrite, false)
		outcome(service.save(7, codec.default()), false, "not_writable")
		outcome(service.release(7, codec.default()), false, "not_writable")
		equal(f.calls, 3)
		equal(f.records[f.key].profile.coins, 125)
	end)

	test("load transient failures recover with bounded backoff", function()
		local f = fixture()
		f.failures = 2
		local loaded = outcome(f.newService().load(7), true)
		equal(loaded.attempts, 3)
		equal(f.delays[1], 1)
		equal(f.delays[2], 2)
	end)

	test("unknown load commit can be recovered without new owner", function()
		local f = fixture()
		f.postFailures = 3
		local service = f.newService()
		outcome(service.load(7), false, "store_unavailable")
		equal(service.status(7).canWrite, false)
		local owner = f.records[f.key].session.token
		outcome(service.load(7), true)
		equal(f.records[f.key].session.token, owner)
	end)

	test("concurrent active owner excluded", function()
		local f = fixture()
		outcome(f.newService().load(7), true)
		local owner = f.records[f.key].session.token
		local other = f.newService()
		outcome(other.load(7), false, "session_locked")
		equal(f.records[f.key].session.token, owner)
		equal(other.status(7).canWrite, false)
	end)

	test("expired owner taken over without resetting progress", function()
		local f = fixture()
		f.existing(250)
		local old = f.newService()
		local data = outcome(old.load(7), true).profile
		f.time += 61
		local fresh = outcome(f.newService().load(7), true)
		equal(fresh.profile.coins, 250)
		data.coins = 999
		outcome(old.save(7, data), false, "lease_expired")
		equal(f.records[f.key].profile.coins, 250)
	end)

	test("changed owner fences stale save before local expiry", function()
		local f = fixture()
		local service = f.newService()
		local data = outcome(service.load(7), true).profile
		f.records[f.key].session.token = "new_server"
		data.coins = 100
		outcome(service.save(7, data), false, "lock_lost")
		equal(service.status(7).canWrite, false)
		equal(f.records[f.key].profile.coins, 0)
	end)

	test("expired session cannot renew itself with stale data", function()
		local f = fixture()
		local service = f.newService()
		local data = outcome(service.load(7), true).profile
		f.time += 60
		equal(service.status(7).canWrite, false)
		outcome(service.save(7, data), false, "lease_expired")
		equal(f.writes, 1)
	end)

	test("successful save renews lease and preserves updated progress", function()
		local f = fixture()
		local service = f.newService()
		local data = outcome(service.load(7), true).profile
		f.time += 30
		data.coins = 75
		outcome(service.save(7, data), true)
		equal(f.records[f.key].profile.coins, 75)
		equal(f.records[f.key].session.expiresAt, 1090)
		data.coins = 100
		equal(f.records[f.key].profile.coins, 75)
	end)

	test("save failure preserves durable data and can recover", function()
		local f = fixture()
		f.existing(50)
		local service = f.newService()
		local data = outcome(service.load(7), true).profile
		data.coins = 100
		f.failures = 3
		outcome(service.save(7, data), false, "store_unavailable")
		equal(f.records[f.key].profile.coins, 50)
		equal(service.status(7).lastError, "store_unavailable")
		outcome(service.save(7, data), true)
		equal(f.records[f.key].profile.coins, 100)
		equal(service.status(7).lastError, nil)
	end)

	test("release saves then removes ownership", function()
		local f = fixture()
		local service = f.newService()
		local data = outcome(service.load(7), true).profile
		data.coins = 90
		outcome(service.release(7, data), true)
		equal(f.records[f.key].session, nil)
		equal(service.status(7).canWrite, false)
		equal(outcome(f.newService().load(7), true).profile.coins, 90)
		outcome(service.release(7, data), true, "already_released")
		outcome(service.save(7, data), false, "not_writable")
	end)

	test("release failure freezes one retry snapshot", function()
		local f = fixture()
		local service = f.newService()
		local data = outcome(service.load(7), true).profile
		data.coins = 90
		f.failures = 3
		outcome(service.release(7, data), false, "store_unavailable")
		equal(service.status(7).canWrite, false)
		data.coins = 999
		outcome(service.save(7, data), false, "not_writable")
		outcome(service.release(7, data), true)
		equal(f.records[f.key].profile.coins, 90)
	end)

	test("committed release with lost response acknowledged safely", function()
		local f = fixture()
		local service = f.newService()
		local data = outcome(service.load(7), true).profile
		data.coins = 25
		f.postFailures = 1
		outcome(service.release(7, data), true)
		equal(f.records[f.key].profile.coins, 25)
		equal(f.records[f.key].session, nil)
	end)

	test("uncertain release cannot overwrite next session", function()
		local f = fixture()
		local old = f.newService({ attempts = 1 })
		local data = outcome(old.load(7), true).profile
		data.coins = 25
		f.postFailures = 1
		outcome(old.release(7, data), false, "store_unavailable")
		local fresh = f.newService()
		local nextData = outcome(fresh.load(7), true).profile
		nextData.coins = 50
		outcome(fresh.save(7, nextData), true)
		outcome(old.release(7, data), false, "lock_lost")
		equal(f.records[f.key].profile.coins, 50)
	end)

	test("committed save with lost response does not double apply", function()
		local f = fixture()
		local service = f.newService()
		local data = outcome(service.load(7), true).profile
		data.coins = 25
		f.postFailures = 2
		outcome(service.save(7, data), true)
		equal(f.records[f.key].profile.coins, 25)
	end)

	test("callback re-entry takes latest loaded progress", function()
		local f = fixture()
		f.existing(25)
		f.reenter = function(key) f.records[key].profile.coins = 100 end
		local data = outcome(f.newService().load(7), true).profile
		equal(data.coins, 100)
	end)

	test("callback re-entry after another owner wins cancels", function()
		local f = fixture()
		f.existing(25)
		f.reenter = function(key)
			f.records[key].session = { token = "winning_owner", expiresAt = 2000 }
		end
		outcome(f.newService().load(7), false, "session_locked")
		equal(f.records[f.key].session.token, "winning_owner")
		equal(f.writes, 0)
	end)

	test("save callback re-entry rechecks owner", function()
		local f = fixture()
		local service = f.newService()
		local data = outcome(service.load(7), true).profile
		data.coins = 25
		f.reenter = function(key)
			f.records[key].session.token = "winning_owner"
			f.records[key].profile.coins = 75
		end
		outcome(service.save(7, data), false, "lock_lost")
		equal(f.records[f.key].profile.coins, 75)
	end)

	test("overlapping operations rejected while request yields", function()
		local f = fixture()
		local service = f.newService()
		local data = outcome(service.load(7), true).profile
		f.onCall = function()
			outcome(service.save(7, data), false, "busy")
			outcome(service.release(7, data), false, "busy")
			outcome(service.load(7), false, "busy")
		end
		outcome(service.save(7, data), true)
	end)

	test("future and unversioned records never overwritten", function()
		for _, version in { 0, 2, "1", false } do
			local f = fixture()
			f.existing(100)
			f.records[f.key].schemaVersion = version
			outcome(f.newService().load(7), false, "unsupported_schema")
			equal(f.records[f.key].profile.coins, 100)
			equal(f.writes, 0)
		end
		local f = fixture()
		f.existing(100)
		f.records[f.key].schemaVersion = nil
		outcome(f.newService().load(7), false, "unsupported_schema")
	end)

	test("malformed envelopes never replaced", function()
		local malformed = { false, 7, "broken", {}, { schemaVersion = 1, profile = codec.default(), surprise = true } }
		for _, raw in malformed do
			local f = fixture()
			f.records[f.key] = raw
			outcome(f.newService().load(7), false)
			equal(f.writes, 0)
		end
	end)

	test("invalid lock is not mistaken for abandoned owner", function()
		for _, session in { {}, { token = "owner", expiresAt = math.huge }, { token = 4, expiresAt = 1 }, { token = "owner", expiresAt = -1 } } do
			local f = fixture()
			f.existing(25)
			f.records[f.key].session = session
			outcome(f.newService().load(7), false, "invalid_session")
			equal(f.writes, 0)
		end
	end)

	test("bad counters rejected on load and before save request", function()
		for _, number in { -1, 0.5, math.huge, -math.huge, 0 / 0, Profile.MAX_COUNTER + 1, "25" } do
			local f = fixture()
			f.existing(25)
			f.records[f.key].profile.coins = number
			outcome(f.newService().load(7), false, "invalid_counter")
			equal(f.writes, 0)
			local clean = fixture()
			local service = clean.newService()
			local data = outcome(service.load(7), true).profile
			data.completedRuns = number
			outcome(service.save(7, data), false, "invalid_profile")
			equal(clean.calls, 1)
		end
	end)

	test("unknown fields and malformed profile values rejected", function()
		local changes = {
			function(p) p.extraCurrency = 1 end,
			function(p) p.tutorialComplete = 1 end,
			function(p) p.cosmetics = {} end,
			function(p) p.cosmetics.mint = false end,
			function(p) p.cosmetics.unregistered = true end,
			function(p) p.equippedCosmetic = "mint" end,
			function(p) p.bestTimes.unknown = 12 end,
			function(p) p.bestTimes.training = 0 end,
			function(p) p.bestTimes.training = math.huge end,
			function(p) p.bestTimes.training = 0 / 0 end,
			function(p) p.bestTimes.training = 3601 end,
			function(p) p.bestTimes.training = {} end,
			function(p) p.bestTimes = p end,
			function(p) setmetatable(p, {}) end,
		}
		for _, change in changes do
			local data = codec.default()
			change(data)
			local valid = codec.validate(data)
			equal(valid, false)
		end
	end)

	test("catalogs immutable after codec creation", function()
		local cosmetics = { default = true }
		local ownCodec = Profile.createCodec({ cosmeticIds = cosmetics, routeIds = {} })
		cosmetics.injected = true
		local data = ownCodec.default()
		data.cosmetics.injected = true
		equal(ownCodec.validate(data), false)
	end)

	test("test and production do not share keys or names", function()
		local f = fixture()
		local testService = f.newService()
		local data = outcome(testService.load(7), true).profile
		data.coins = 999
		outcome(testService.save(7, data), true)
		local production = f.newService({ environment = "production" })
		equal(outcome(production.load(7), true).profile.coins, 0)
		assert(Persistence.storeName("test") ~= Persistence.storeName("production"))
		equal(pcall(Persistence.storeName, "staging"), false)
	end)

	test("invalid user IDs rejected without request", function()
		local f = fixture()
		local service = f.newService()
		for _, id in { 0, -1, 1.5, math.huge, 0 / 0, "7" } do
			outcome(service.load(id), false, "invalid_user_id")
			outcome(service.save(id, codec.default()), false, "invalid_user_id")
		end
		equal(f.calls, 0)
	end)

	test("retry deadline stops work before next delay", function()
		local f = fixture()
		f.failures = 10
		local service = f.newService()
		outcome(service.load(7, f.time + 1), false, "deadline")
		equal(f.calls, 1)
		equal(#f.delays, 0)
		equal(service.status(7).canWrite, false)
	end)

	test("shutdown release deadline retry keeps frozen snapshot", function()
		local f = fixture()
		local service = f.newService()
		local data = outcome(service.load(7), true).profile
		data.coins = 25
		outcome(service.release(7, data, f.time), false, "deadline")
		data.coins = 500
		outcome(service.release(7, data, f.time + 10), true)
		equal(f.records[f.key].profile.coins, 25)
	end)

	test("known permanent adapter errors do not retry", function()
		local f = fixture()
		f.failures = 10
		outcome(f.newService({ isRetryable = function() return false end }).load(7), false, "store_unavailable")
		equal(f.calls, 1)
	end)

	test("metadata and associated user IDs preserved", function()
		local f = fixture()
		f.existing(25)
		f.metadata = { audit = "preserve" }
		f.userIds = { 7, 8 }
		outcome(f.newService().load(7), true)
		equal(f.lastMetadata.audit, "preserve")
		equal(f.lastUserIds[2], 8)
	end)

	test("released session can reacquire with a new owner token", function()
		local f = fixture()
		local service = f.newService()
		local data = outcome(service.load(7), true).profile
		local oldToken = f.records[f.key].session.token
		outcome(service.load(7), false, "already_loaded")
		outcome(service.release(7, data), true)
		outcome(service.load(7), true)
		assert(f.records[f.key].session.token ~= oldToken)
	end)

	test("lifecycle cleanup only forgets terminal sessions", function()
		local f = fixture()
		local service = f.newService()
		local data = outcome(service.load(7), true).profile
		outcome(service.forget(7), false, "session_in_use")
		f.failures = 3
		outcome(service.release(7, data), false, "store_unavailable")
		outcome(service.forget(7), false, "session_in_use")
		outcome(service.release(7, data), true)
		outcome(service.forget(7), true)
		equal(service.status(7).reason, "not_loaded")
		outcome(service.save(7, data), false, "not_loaded")
	end)

	test("lease expiring inside network attempt denies write", function()
		local f = fixture()
		local service = f.newService()
		local data = outcome(service.load(7), true).profile
		f.onCall = function() f.time += 61 end
		data.coins = 25
		outcome(service.save(7, data), false, "lease_expired")
		equal(f.records[f.key].profile.coins, 0)
	end)

	test("load response arriving after lease expiry grants no writer", function()
		local f = fixture()
		local service = f.newService({
			update = function(_, transform)
				local proposed = transform(nil)
				f.time += 61
				return proposed
			end,
		})
		outcome(service.load(7), false, "unconfirmed_load")
		equal(service.status(7).canWrite, false)
	end)

	test("expired uncertain closing session can retire bookkeeping", function()
		local f = fixture()
		local service = f.newService()
		local data = outcome(service.load(7), true).profile
		f.failures = 3
		outcome(service.release(7, data), false, "store_unavailable")
		outcome(service.forget(7), false, "session_in_use")
		f.time += 61
		outcome(service.forget(7), true)
	end)

	return count
end
