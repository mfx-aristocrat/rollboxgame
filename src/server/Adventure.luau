-- Explicitly constructed server adapter; the main sampler owns its update cadence.
local Adventure = {}
Adventure.__index = Adventure

local function observation(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then return root end
	return nil
end
local function position(root)
	local point = root.Position
	return { point.X, point.Y, point.Z }
end
function Adventure.new(world, _config)
	local replicatedStorage = game:GetService("ReplicatedStorage")
	local rules = require(replicatedStorage:WaitForChild("Shared"):WaitForChild("AdventureRules"))
	local itemSpecs, springSpecs = {}, {}
	for _, entry in world.items do table.insert(itemSpecs, entry.spec) end
	for _, entry in world.springs do table.insert(springSpecs, entry.spec) end
	local self = setmetatable({ rules = rules, catalog = rules.catalog(itemSpecs, springSpecs),
		world = world, states = {}, connections = {}, destroyed = false }, Adventure)
	for _, entry in world.items do
		if entry.spec.kind == "crate" and entry.prompt then
			local id = entry.spec.id
			table.insert(self.connections, entry.prompt.Triggered:Connect(function(player)
				local state = self.states[player]
				if not state or self.destroyed then return end
				-- Triggered can be fired by a modified client: never trust its distance/life checks.
				local root = observation(player)
				if root then rules.collect(self.catalog, state, id, position(root), true, os.clock()) end
			end))
		end
	end
	return self
end
function Adventure:add(player)
	if not self.destroyed and not self.states[player] then self.states[player] = self.rules.newState() end
end
function Adventure:remove(player)
	self.states[player] = nil
end
function Adventure:step(player, root, isAlive, running, now)
	local state = self.states[player]
	if self.destroyed or not state or isAlive ~= true or not root or root ~= observation(player) then return end
	local point = position(root)
	for _, entry in self.world.items do
		if entry.spec.kind ~= "crate" and not state.collectedIds[entry.spec.id] then
			self.rules.collect(self.catalog, state, entry.spec.id, point, true, now)
		end
	end
	for _, entry in self.world.springs do
		local launched, speed = self.rules.spring(self.catalog, state, entry.spec.id, point, true, running, now)
		if launched then
			-- Keep horizontal input, replace rather than stack vertical impulse, clamp all axes.
			local velocity = root.AssemblyLinearVelocity
			if not self.rules.validPosition({ velocity.X, velocity.Y, velocity.Z }) then velocity = Vector3.zero end
			root.AssemblyLinearVelocity = Vector3.new(math.clamp(velocity.X, -40, 40), speed, math.clamp(velocity.Z, -40, 40))
			break
		end
	end
end
function Adventure:snapshot(player)
	local state = self.states[player]
	return if state then self.rules.snapshot(self.catalog, state) else nil
end
function Adventure:destroy()
	if self.destroyed then return end
	self.destroyed = true
	for _, connection in self.connections do connection:Disconnect() end
	table.clear(self.connections)
	table.clear(self.states)
end
return Adventure
