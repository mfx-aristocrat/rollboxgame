-- Server owns session unlocks, observations, rate limits and single-use boost approvals.
local Powerups = {}
Powerups.__index = Powerups
local function array(point) return { point.X, point.Y, point.Z } end
function Powerups.new(world, config, dependencies)
	local deps = dependencies or {}
	local rules = deps.rules or require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("PowerupRules"))
	local self = setmetatable({ world = world, config = config, rules = rules,
		workspace = deps.workspace or workspace, clock = deps.clock or os.clock,
		states = {}, connections = {}, destroyed = false, notify = deps.notify }, Powerups)
	table.insert(self.connections, world.prompt.Triggered:Connect(function(player)
		local state = self.states[player]
		if self.destroyed or not state or not rules.admit(config, state, "pickup", self.clock()) then return end
		-- ProximityPrompt can be spoofed; verify current life, position and fixed server crate.
		local crate = world.crate
		if not crate or not crate.Parent or not crate.Anchored or not rules.validPosition(array(crate.Position)) then return end
		for index, value in array(crate.Position) do if math.abs(value - config.cratePosition[index]) > 0.01 then return end end
		local root = self:_observe(player, state, self.clock())
		if root then rules.collect(config, state, array(root.Position), true) end
	end))
	return self
end
function Powerups:add(player)
	if not self.destroyed and not self.states[player] then self.states[player] = self.rules.newState() end
end
function Powerups:remove(player) self.states[player] = nil end
function Powerups:resetAir(player)
	local state = self.states[player]
	if state then
		self.rules.resetAir(state); state.character = player.Character
		state.epoch=(state.epoch or 0)+1
		state.previousPosition,state.previousTime=nil,nil
		if self.notify then self.notify(player,{kind="reset",epoch=state.epoch}) end
	end
end
function Powerups:_observe(player, state, now)
	local character = player.Character
	if state.character ~= character then self:resetAir(player) end
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not self.rules.finite(humanoid.Health) or humanoid.Health <= 0
		or not root or not root:IsA("BasePart") or root.Anchored
		or not self.rules.validPosition(array(root.Position)) or not self.rules.validPosition(array(root.AssemblyLinearVelocity)) then
		self.rules.observe(self.config, state, nil, now)
		return nil
	end
	-- Humanoid.FloorMaterial is not replicated. Raycast collidable geometry with the
	-- character collision group, excluding its outfit/parcel and all its body parts.
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances, params.RespectCanCollide = { character }, true
	params.CollisionGroup = root.CollisionGroup
	local footDistance = root.Size.Y / 2 + humanoid.HipHeight
	if humanoid.RigType == Enum.HumanoidRigType.R6 then
		local leg = character:FindFirstChild("Left Leg") or character:FindFirstChild("Right Leg")
		if leg and leg:IsA("BasePart") then footDistance += leg.Size.Y end
	end
	if not self.rules.finite(footDistance) or footDistance <= 0 or footDistance > 20 then
		self.rules.observe(self.config, state, nil, now)
		return nil
	end
	local hit = self.workspace:Raycast(root.Position, Vector3.new(0, -(footDistance + self.config.groundTolerance), 0), params)
	local grounded = hit ~= nil and hit.Normal.Y >= 0.5
	local velocity=array(root.AssemblyLinearVelocity)
	-- Owner velocity is not replicated. Derive ascent from server-observed positions.
	if state.previousPosition and now>state.previousTime then
		local delta=(root.Position.Y-state.previousPosition.Y)/(now-state.previousTime)
		if math.abs(velocity[2])<1 and math.abs(delta)<120 then velocity[2]=delta end
	end
	state.previousPosition,state.previousTime=root.Position,now
	local observed = self.rules.observe(self.config, state, { alive = true,
		position = array(root.Position), velocity = velocity, grounded = grounded }, now)
	return if observed then root else nil
end
function Powerups:step(player, now)
	local state = self.states[player]
	if not self.destroyed and state then self:_observe(player, state, now) end
end
function Powerups:requestJump(player, now, nonce)
	local state = self.states[player]
	if self.destroyed or not state or not self.rules.admit(self.config, state, "jump", now) then return false end
	-- Fresh sampling admits fast separate presses even between heartbeat samples.
	local root = self:_observe(player, state, now)
	if not root or not self.rules.consume(self.config, state, now) then return false end
	local approval={kind="jump",nonce=nonce,character=player.Character,epoch=state.epoch or 0}
	return true,approval
end
function Powerups:snapshot(player)
	local state = self.states[player]
	return if state then self.rules.snapshot(state) else nil
end
function Powerups:destroy()
	if self.destroyed then return end
	self.destroyed = true
	for _, connection in self.connections do connection:Disconnect() end
	table.clear(self.connections)
	table.clear(self.states)
end
return Powerups
