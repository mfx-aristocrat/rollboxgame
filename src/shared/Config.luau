-- Pure configuration: numeric arrays are positions/RGB and load unchanged in Lune.
local config = {
	buildVersion = "0.6.0-cannon-ocean",
	rewardCoins = 25,
	mintCost = 50,
	maxCounter = 1_000_000_000,
	switchCooldown = 0.5,
	maxRunSeconds = 3_600,
	sampleSeconds = 0.1,
	snapshotSeconds = 0.25,
	maxMovementSpeed = 40,
	movementTolerance = 8,
	depotRadius = 15,
	pickup = { position = { 7, 11, 0 }, radius = 12 },
	fallY = -8,
	colors = {
		Amber = { 255, 182, 64 },
		Cyan = { 63, 219, 240 },
		mint = { 114, 245, 182 },
		default = { 235, 239, 249 },
	},
	cosmeticIds = { default = true, mint = true, sunset = true, aurora = true, supporter = true },
	routeIds = { training = true, rooftops = true, skybridge = true },
	routeUnlocks = { training = 0, rooftops = 3, skybridge = 10 },
	route = {
		id = "training",
		name = "Training",
		depot = { 0, 12, 0 },
		destination = { 0, 12, -148 },
		gates = {
			{ polarity = "Amber", position = { 0, 12, -24 }, checkpoint = { 0, 12, -30 }, distance = 24 },
			{ polarity = "Cyan", position = { 0, 12, -52 }, checkpoint = { 0, 12, -58 }, distance = 52 },
			{ polarity = "Amber", position = { 0, 12, -94 }, checkpoint = { 0, 12, -100 }, distance = 94 },
			{ polarity = "Cyan", position = { 0, 12, -126 }, checkpoint = { 0, 12, -132 }, distance = 126 },
		},
	},
}
local function freeze(value)
	for _, item in pairs(value) do
		if type(item) == "table" then freeze(item) end
	end
	return table.freeze(value)
end
return freeze(config)
