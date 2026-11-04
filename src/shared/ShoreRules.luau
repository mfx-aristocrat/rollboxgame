-- Rescue is a convenience, never a checkpoint/reward request.
local Rules = {}
local function finite(n) return type(n) == "number" and n == n and math.abs(n) < math.huge end
function Rules.canReturn(bounds, surfaceY, bottomY, position, alive, water, now, lastAt)
	if not alive or not water or not finite(now) or type(position) ~= "table" then return false end
	for i = 1, 3 do if not finite(position[i]) then return false end end
	return position[1] >= bounds.minX and position[1] <= bounds.maxX
		and position[3] >= bounds.minZ and position[3] <= bounds.maxZ
		and position[2] >= bottomY - 4 and position[2] <= surfaceY + 4
		and (lastAt == nil or (finite(lastAt) and now - lastAt >= 2))
end
function Rules.nearest(landings, position)
	local chosen, best
	for _, landing in landings do
		local point = landing.position
		local distance = (point[1] - position[1]) ^ 2 + (point[3] - position[3]) ^ 2
		if not best or distance < best then chosen, best = landing, distance end
	end
	return chosen
end
return Rules
