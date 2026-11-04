-- Original session-only target practice; grants no currency and never damages players.
local config = {
	id = "orangeMushroom", cratePosition = { 92, 11.625, 24 }, pickupRadius = 9,
	pickupInterval = 0.2, requestInterval = 0.06, cooldown = 0.4,
	projectileSpeed = 90, projectileRange = 150, maxPerPlayer = 6, maxProjectiles = 48,
	targetPulseTime = 0.18,
	targets = {
		{ id = "near", position = { 128, 10, 58 } },
		{ id = "middle", position = { 152, 9, 86 } },
		{ id = "far", position = { 176, 11, 56 } },
	},
}
table.freeze(config.cratePosition)
for _, target in config.targets do table.freeze(target.position); table.freeze(target) end
table.freeze(config.targets)
return table.freeze(config)
