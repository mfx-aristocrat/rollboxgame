-- Bounded server projectile simulation: targets only, no damage/rewards/profile writes.
local Blaster = {}
Blaster.__index = Blaster
local function array(point) return {point.X,point.Y,point.Z} end
local function cosmetic(name,size,color)
	local part=Instance.new("Part")
	part.Name,part.Size,part.Color=name,size,color
	part.CanCollide,part.CanTouch,part.CanQuery,part.CastShadow=false,false,false,false
	part.Material=Enum.Material.SmoothPlastic
	return part
end
local function equip(character,root)
	local old=character:FindFirstChild("PracticeCannon")
	if old then old:Destroy() end
	local model=Instance.new("Model");model.Name="PracticeCannon"
	local hand=character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm") or root
	if not hand:IsA("BasePart") then hand=root end
	local frame=hand.CFrame*CFrame.new(0,-0.35,-1)
	for index,spec in {
		{Vector3.new(1.05,1.05,2.5),CFrame.new(),Color3.fromRGB(255,157,55)},
		{Vector3.new(1.25,1.25,0.3),CFrame.new(0,0,-1.3),Color3.fromRGB(69,89,103)},
		{Vector3.new(0.55,1.2,0.65),CFrame.new(0,-0.7,0.6),Color3.fromRGB(116,79,58)},
	} do
		local part=cosmetic("CannonPart"..index,spec[1],spec[3])
		part.Anchored,part.Massless=false,true
		part.CFrame=frame*spec[2];part.Parent=model
		local weld=Instance.new("WeldConstraint");weld.Part0,weld.Part1=hand,part;weld.Parent=part
	end
	model.Parent=character
	return model
end
local function projectilePart(position,parent)
	local part=cosmetic("PracticeBall",Vector3.new(0.7,0.7,0.7),Color3.fromRGB(255,196,81))
	part.Shape,part.Anchored,part.Position=Enum.PartType.Ball,true,position
	part.Material=Enum.Material.Neon;part.Parent=parent
	return part
end
function Blaster.new(world,config,dependencies)
	local deps=dependencies or {}
	local self=setmetatable({world=world,config=config,
		rules=deps.rules or require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("BlasterRules")),
		workspace=deps.workspace or workspace,clock=deps.clock or os.clock,
		players=deps.players or game:GetService("Players"),equip=deps.equip or equip,
		makeProjectile=deps.makeProjectile or projectilePart,
		states={},projectiles={},connections={},targets={},pulses={},destroyed=false},Blaster)
	for _,entry in world.targets do self.targets[entry.part]=entry end
	table.insert(self.connections,world.prompt.Triggered:Connect(function(player)
		local state=self.states[player]
		if self.destroyed or not state or not self.rules.admit(config,state,"pickup",self.clock()) then return end
		local crate=world.crate
		if not crate or not crate.Parent or not crate.Anchored or not self.rules.validPosition(array(crate.Position)) then return end
		for index,value in array(crate.Position) do if math.abs(value-config.cratePosition[index])>0.01 then return end end
		local root=self:_root(player)
		if root and self.rules.collect(config,state,array(root.Position),true) then self:characterAdded(player) end
	end))
	return self
end
function Blaster:_root(player)
	local character=player.Character
	local root=character and character:FindFirstChild("HumanoidRootPart")
	local humanoid=character and character:FindFirstChildOfClass("Humanoid")
	if root and root:IsA("BasePart") and not root.Anchored and humanoid
		and self.rules.finite(humanoid.Health) and humanoid.Health>0
		and self.rules.validPosition(array(root.Position)) then return root end
	return nil
end
function Blaster:add(player)
	if not self.destroyed and not self.states[player] then self.states[player]=self.rules.newState() end
end
function Blaster:characterAdded(player)
	local state=self.states[player]
	local root=self:_root(player)
	if not self.destroyed and state and state.unlocked and root then
		if state.cannon then state.cannon:Destroy() end
		state.cannon=self.equip(player.Character,root)
		state.character=player.Character
	end
end
function Blaster:_retire(index)
	local projectile=self.projectiles[index]
	self.rules.retire(projectile.state)
	projectile.part:Destroy()
	table.remove(self.projectiles,index)
end
function Blaster:remove(player)
	local state=self.states[player]
	if not state then return end
	for index=#self.projectiles,1,-1 do
		if self.projectiles[index].player==player then self:_retire(index) end
	end
	if state.cannon then state.cannon:Destroy() end
	self.states[player]=nil
end
function Blaster:_params()
	local exclude={}
	-- Exclude every current player character, including players not registered yet.
	for _,player in self.players:GetPlayers() do if player.Character then table.insert(exclude,player.Character) end end
	for _,projectile in self.projectiles do table.insert(exclude,projectile.part) end
	local params=RaycastParams.new()
	params.FilterType,params.FilterDescendantsInstances=Enum.RaycastFilterType.Exclude,exclude
	params.IgnoreWater=true
	return params
end
function Blaster:fire(player,direction,now)
	local state=self.states[player]
	if self.destroyed or not state or not self.rules.admit(self.config,state,"fire",now) then return false end
	-- Consume request throttle before type/life checks; malformed floods never cast rays.
	if typeof(direction)~="Vector3" then return false end
	local root=self:_root(player)
	local unit=self.rules.fire(self.config,state,array(direction),root~=nil,now,#self.projectiles)
	if not unit then return false end
	-- Check root to torso muzzle too, so even a thin obstruction at the origin
	-- cannot be skipped. No client origin/hit/target/timestamp is accepted.
	local origin=root.Position+Vector3.new(0,1,0)
	local obstruction=self.workspace:Raycast(root.Position,origin-root.Position,self:_params())
	if obstruction then
		self:_hit({state=state},obstruction,now)
		self.rules.retire(state)
		return true
	end
	local part=self.makeProjectile(origin,self.world.root or self.world.model)
	table.insert(self.projectiles,{player=player,state=state,part=part,position=origin,
		direction=Vector3.new(table.unpack(unit)),travelled=0,born=now})
	return true
end
function Blaster:_hit(projectile,result,now)
	local entry=self.targets[result.Instance]
	if not entry then return end
	self.rules.hit(projectile.state)
	local target=entry.part
	local pulse=self.pulses[target]
	if not pulse then pulse={color=target.Color,material=target.Material};self.pulses[target]=pulse end
	pulse.untilTime=now+self.config.targetPulseTime
	target.Color,target.Material=Color3.fromRGB(255,244,151),Enum.Material.Neon
	target:SetAttribute("HitCount",math.min((target:GetAttribute("HitCount") or 0)+1,999999))
end
function Blaster:step(dt,now)
	if self.destroyed or not self.rules.finite(dt) or dt<0 or not self.rules.finite(now) or now<0 then return end
	for player,state in self.states do
		if state.unlocked and (state.character~=player.Character or not state.cannon or not state.cannon.Parent) then self:characterAdded(player) end
	end
	for target,pulse in self.pulses do
		if not target.Parent then self.pulses[target]=nil
		elseif now>=pulse.untilTime then target.Color,target.Material=pulse.color,pulse.material;self.pulses[target]=nil end
	end
	if #self.projectiles==0 then return end
	local params=self:_params()
	for index=#self.projectiles,1,-1 do
		local projectile=self.projectiles[index]
		if not self:_root(projectile.player) or not projectile.part.Parent or now<projectile.born
			or now-projectile.born>self.config.projectileRange/self.config.projectileSpeed+0.5 then
			self:_retire(index)
		else
			local distance=math.min(self.config.projectileSpeed*dt,self.config.projectileRange-projectile.travelled)
			if distance>0 then
				local segment=projectile.direction*distance
				local result=self.workspace:Raycast(projectile.position,segment,params)
				if result then self:_hit(projectile,result,now);self:_retire(index)
				else
					projectile.position+=segment;projectile.travelled+=distance;projectile.part.Position=projectile.position
					if projectile.travelled>=self.config.projectileRange then self:_retire(index) end
				end
			end
		end
	end
end
function Blaster:snapshot(player)
	local state=self.states[player]
	return if state then self.rules.snapshot(state) else nil
end
function Blaster:destroy()
	if self.destroyed then return end
	self.destroyed=true
	for _,connection in self.connections do connection:Disconnect() end
	table.clear(self.connections)
	for player in self.states do self:remove(player) end
	for target,pulse in self.pulses do
		if target.Parent then target.Color,target.Material=pulse.color,pulse.material end
	end
	table.clear(self.pulses)
end
return Blaster
