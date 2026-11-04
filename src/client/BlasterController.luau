-- One shot per fresh action. The server owns entitlement, origin, hits and limits.
local Controller = {}
Controller.__index = Controller
function Controller.new(options)
	local services = options.services or {}
	local function service(name) return services[name] or game:GetService(name) end
	local self=setmetatable({options=options,input=service("UserInputService"),gui=service("GuiService"),
		clock=options.clock or os.clock,world=options.workspace or workspace,last=-math.huge,connections={}},Controller)
	table.insert(self.connections,self.input.InputBegan:Connect(function(input,processed)
		if processed then return end
		if input.KeyCode==Enum.KeyCode.F or input.KeyCode==Enum.KeyCode.ButtonR2 or input.UserInputType==Enum.UserInputType.MouseButton1 then self:fire() end
		if input.KeyCode==Enum.KeyCode.R or input.KeyCode==Enum.KeyCode.ButtonY then self:returnLand() end
	end))
	return self
end
function Controller:blocked()
	return self.destroyed or self.input:GetFocusedTextBox()~=nil or self.gui.MenuIsOpen or self.gui.SelectedObject~=nil
		or (self.options.isBlocked and self.options.isBlocked())
end
function Controller:fire()
	if self:blocked() or not self.options.isUnlocked() then return end
	local now=self.clock()
	if now-self.last<0.4 then return end
	local character=self.options.player.Character
	local root=character and character:FindFirstChild("HumanoidRootPart")
	local humanoid=character and character:FindFirstChildOfClass("Humanoid")
	local camera=self.world.CurrentCamera
	if not root or not humanoid or humanoid.Health<=0 or not camera then return end
	local ray
	if self.input.PreferredInput==Enum.PreferredInput.KeyboardAndMouse then
		local pointer=self.input:GetMouseLocation()-self.gui:GetGuiInset()
		ray=camera:ScreenPointToRay(pointer.X,pointer.Y)
	elseif self.options.aimPoint then
		local point=self.options.aimPoint()
		ray=camera:ScreenPointToRay(point.X,point.Y)
	else
		ray=camera:ViewportPointToRay(camera.ViewportSize.X/2,camera.ViewportSize.Y/2)
	end
	local params=RaycastParams.new()
	params.FilterType=Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances={character}
	local hit=self.world:Raycast(ray.Origin,ray.Direction*150,params)
	local point=if hit then hit.Position else ray.Origin+ray.Direction*150
	local direction=point-(root.Position+Vector3.new(0,1,0))
	if direction.Magnitude<0.01 then return end
	self.last=now
	self.options.fire(direction.Unit)
end
function Controller:returnLand()
	if not self:blocked() and self.options.inWater() then self.options.returnLand() end
end
function Controller:destroy()
	if self.destroyed then return end
	self.destroyed=true
	for _,connection in self.connections do connection:Disconnect() end
	table.clear(self.connections)
end
return Controller
