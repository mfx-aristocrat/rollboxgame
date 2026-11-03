--!strict
-- Pure serialization boundary. Catalogs include every historically persisted ID.
local Profile = {}

Profile.VERSION = 1
Profile.MAX_COUNTER = 1_000_000_000
Profile.MAX_BEST_TIME_SECONDS = 3_600

local fields = {
	coins = true,
	completedRuns = true,
	tutorialComplete = true,
	cosmetics = true,
	equippedCosmetic = true,
	bestTimes = true,
}

local function plain(value: any): boolean
	return type(value) == "table" and getmetatable(value) == nil
end

local function counter(value: any): boolean
	return type(value) == "number" and value == value and value >= 0
		and value <= Profile.MAX_COUNTER and value % 1 == 0
end

local function catalog(source: any): { [string]: boolean }
	assert(plain(source), "Profile catalog must be a plain ID -> true map")
	local result = {}
	local count = 0
	for id, enabled in pairs(source) do
		assert(type(id) == "string" and #id > 0 and #id <= 48
			and string.match(id, "^[%w_%-]+$") ~= nil and enabled == true, "Invalid profile catalog entry")
		count += 1
		assert(count <= 256, "Profile catalog exceeds bounded initial-release scope")
		result[id] = true
	end
	return result
end

function Profile.createCodec(config: any)
	local cosmetics = catalog(config.cosmeticIds)
	local routes = catalog(config.routeIds)
	assert(cosmetics.default, "Profile catalog must include the default cosmetic")
	local codec = {}

	function codec.default()
		return {
			coins = 0,
			completedRuns = 0,
			tutorialComplete = false,
			cosmetics = { default = true },
			equippedCosmetic = "default",
			bestTimes = {},
		}
	end

	function codec.validate(value: any): (boolean, string?)
		if not plain(value) then
			return false, "profile_not_table"
		end
		for field in pairs(value) do
			if not fields[field] then
				return false, "unknown_profile_field"
			end
		end
		if not counter(value.coins) or not counter(value.completedRuns) then
			return false, "invalid_counter"
		end
		if type(value.tutorialComplete) ~= "boolean" then
			return false, "invalid_tutorial"
		end
		if not plain(value.cosmetics) or value.cosmetics.default ~= true then
			return false, "invalid_cosmetics"
		end
		for id, owned in pairs(value.cosmetics) do
			if not cosmetics[id] or owned ~= true then
				return false, "invalid_cosmetic"
			end
		end
		if type(value.equippedCosmetic) ~= "string" or value.cosmetics[value.equippedCosmetic] ~= true then
			return false, "invalid_equipped_cosmetic"
		end
		if not plain(value.bestTimes) then
			return false, "invalid_best_times"
		end
		for id, seconds in pairs(value.bestTimes) do
			if not routes[id] or type(seconds) ~= "number" or seconds ~= seconds
				or seconds <= 0 or seconds > Profile.MAX_BEST_TIME_SECONDS then
				return false, "invalid_best_time"
			end
		end
		return true, nil
	end

	-- Call only after validation; deliberately copies just the versioned schema.
	function codec.copy(value: any)
		return {
			coins = value.coins,
			completedRuns = value.completedRuns,
			tutorialComplete = value.tutorialComplete,
			cosmetics = table.clone(value.cosmetics),
			equippedCosmetic = value.equippedCosmetic,
			bestTimes = table.clone(value.bestTimes),
		}
	end

	return codec
end

return Profile
