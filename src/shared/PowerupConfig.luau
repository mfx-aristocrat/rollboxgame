-- Session ability configuration, separate from exploration points and saved progression.
local config = {
	id = "mushroom", cratePosition = { -92, 11.625, 24 }, pickupRadius = 9,
	jumpSpeed = 52, horizontalLimit = 40,
	jumpCooldown = 0.18, requestInterval = 0.06, pickupInterval = 0.2,
	landingStableTime = 0.12, landingMaxVerticalSpeed = 5, takeoffMinVerticalSpeed = 8,
	groundTolerance = 0.35,
}
table.freeze(config.cratePosition)
return table.freeze(config)
