-- Pure mutations; caller supplies the loaded writable profile (session-only in M03).
local Progression = {}
function Progression.unlocked(profile, routeId, config)
	local threshold = config.routeUnlocks[routeId]
	return threshold ~= nil and profile.completedRuns >= threshold
end
function Progression.reward(profile, run, config)
	if not run or run.state ~= "Completed" or run.rewarded then return false, "not_rewardable" end
	if type(run.resultTime) ~= "number" or run.resultTime ~= run.resultTime
		or run.resultTime <= 0 or run.resultTime > config.maxRunSeconds then return false, "invalid_time" end
	-- Mark before mutation; an already completed run can never issue another grant.
	run.rewarded = true
	profile.coins = math.min(config.maxCounter, profile.coins + config.rewardCoins)
	profile.completedRuns = math.min(config.maxCounter, profile.completedRuns + 1)
	profile.tutorialComplete = true
	local best = profile.bestTimes.training
	if not best or run.resultTime < best then profile.bestTimes.training = run.resultTime end
	return true
end
function Progression.buyMint(profile, config)
	if profile.cosmetics.mint then return false, "already_owned" end
	if profile.coins < config.mintCost then return false, "insufficient_coins" end
	profile.coins -= config.mintCost
	profile.cosmetics.mint = true
	return true
end
function Progression.equip(profile, id)
	if id ~= "default" and id ~= "mint" then return false, "invalid_cosmetic" end
	if profile.cosmetics[id] ~= true then return false, "not_owned" end
	profile.equippedCosmetic = id
	return true
end
return Progression
