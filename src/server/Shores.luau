local Shores = {}
Shores.__index = Shores
function Shores.new(config, dependencies)
	local deps = dependencies or {}
	return setmetatable({config=config, terrain=deps.terrain or workspace.Terrain,
		rules=deps.rules or require(game:GetService("ReplicatedStorage").Shared.ShoreRules), last={}, requests={}}, Shores)
end
function Shores:inWater(root)
	if not root then return false end
	local c, p = self.config.water, root.Position
	for _, n in {p.X,p.Y,p.Z} do if n~=n or math.abs(n)==math.huge then return false end end
	if p.X < c.minX or p.X > c.maxX or p.Z < c.minZ or p.Z > c.maxZ
		or p.Y > c.surfaceY + 4 or p.Y < c.bottomY - 4 then return false end
	-- Check the actual native water just below the torso, not a client state flag.
	-- At the seafloor the feet are below the liquid slab but the torso still swims.
	local sampleY=math.max(p.Y-2,c.bottomY)
	local corner = Vector3.new(math.floor(p.X / 4) * 4, math.floor(sampleY / 4) * 4, math.floor(p.Z / 4) * 4)
	local channels = self.terrain:ReadVoxelChannels(Region3.new(corner, corner + Vector3.new(4,4,4)), 4, {"LiquidOccupancy"})
	return channels.LiquidOccupancy[1][1][1] > 0
end
function Shores:request(player, root, now)
	-- Bound expensive voxel reads even for invalid/flooded calls.
	local lastRequest = self.requests[player]
	if lastRequest and now - lastRequest < 0.5 then return nil end
	self.requests[player] = now
	local c = self.config.water
	if not root then return nil end
	local p = {root.Position.X,root.Position.Y,root.Position.Z}
	if not self.rules.canReturn(c,c.surfaceY,c.bottomY,p,true,self:inWater(root),now,self.last[player]) then return nil end
	local landing = self.rules.nearest(self.config.returnLandings,p)
	if landing then self.last[player] = now end
	return landing and landing.position
end
function Shores:remove(player) self.last[player],self.requests[player]=nil,nil end
return Shores
