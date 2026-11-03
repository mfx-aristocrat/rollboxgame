-- Observe physical Begin edges; JumpRequest repeats while held and is unsuitable.
-- Apply one owner-side boost only after a matching, fresh server approval.
local JumpController = {}
JumpController.__index = JumpController
local ACTION = "MushroomDoubleJump"
local function disconnect(connections)
	for _, connection in connections do connection:Disconnect() end
	table.clear(connections)
end
function JumpController.new(options)
	local services = options.services or {}
	local function service(name) return services[name] or game:GetService(name) end
	local self = setmetatable({ options = options, player = options.player,
		input = service("UserInputService"), gui = service("GuiService"),
		actions = service("ContextActionService"), clock = options.clock or os.clock,
		connections = {}, buttonConnections = {}, held = {}, suppressed = {}, touches = {},
		phase = "unarmed", groundSince = nil, firstPress = false, destroyed = false }, JumpController)
	local function connect(signal, callback)
		table.insert(self.connections, signal:Connect(callback))
	end
	self.actions:BindActionAtPriority(ACTION, function(_, state, input)
		local key = input and input.KeyCode
		if state == Enum.UserInputState.Cancel then
			self:_cancel()
		elseif state == Enum.UserInputState.End then
			if key then self.held[key], self.suppressed[key] = nil, nil end
		elseif state == Enum.UserInputState.Begin and key and not self.held[key] and not self.suppressed[key] then
			self.held[key] = true
			self:_press()
		end
		-- Retain Roblox's ordinary first jump and standard gamepad controls.
		return Enum.ContextActionResult.Pass
	end, false, Enum.ContextActionPriority.High.Value + 1, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
	connect(service("RunService").Heartbeat, function() self:_observe() end)
	connect(self.input.InputEnded, function(input)
		self.touches[input] = nil
		if input.KeyCode then self.held[input.KeyCode], self.suppressed[input.KeyCode] = nil, nil end
	end)
	connect(self.input.WindowFocusReleased, function() self:_cancel() end)
	connect(self.input.TextBoxFocused, function() self:_cancel() end)
	connect(self.input.GamepadDisconnected, function() self:_cancel() end)
	connect(self.input.LastInputTypeChanged, function() self:_cancel() end)
	connect(self.gui.MenuOpened, function() self:_cancel() end)
	connect(self.player.CharacterAdded, function() self:_resetCharacter() end)
	connect(self.player.CharacterRemoving, function() self:_resetCharacter() end)
	self.playerGui = self.player:WaitForChild("PlayerGui")
	connect(self.playerGui.DescendantAdded, function() self:_refreshButton() end)
	connect(self.playerGui.DescendantRemoving, function(descendant)
		if descendant == self.button then
			disconnect(self.buttonConnections)
			self.button = nil
			table.clear(self.touches)
		end
	end)
	self:_refreshButton()
	if options.approvals then connect(options.approvals,function(data) self:_approve(data) end) end
	return self
end
function JumpController:_approve(data)
	if type(data)~="table" then return end
	if data.kind=="reset" then
		self.epoch=math.max(self.epoch or 0,data.epoch or 0)
		self.pending=nil; self.phase="unarmed"; self.groundSince=nil; self.firstPress=false
		return
	end
	local pending=self.pending
	if data.kind~="jump" or not pending or data.nonce~=pending.nonce or data.character~=self.player.Character
		or data.character~=pending.character or self.clock()-pending.at>0.4 or data.epoch<(self.epoch or 0) then return end
	self.pending=nil; self.epoch=data.epoch
	local character=self.player.Character
	local root=character and character:FindFirstChild("HumanoidRootPart")
	local humanoid=character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health<=0 or self.phase~="consumed" or self:_blocked() then return end
	local velocity=root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity=Vector3.new(math.clamp(velocity.X,-40,40),52,math.clamp(velocity.Z,-40,40))
end
function JumpController:_cancel()
	self.pending=nil
	-- Focus/menu cancellation clears active holds but a still-down key cannot be
	-- mistaken for a new physical press when gameplay regains focus.
	for key in self.held do self.suppressed[key] = true end
	table.clear(self.held)
	table.clear(self.touches)
end
function JumpController:_resetCharacter()
	self:_cancel()
	self.character, self.phase, self.groundSince, self.firstPress = nil, "unarmed", nil, false
end
function JumpController:_blocked()
	return self.input:GetFocusedTextBox() ~= nil or self.gui.MenuIsOpen
		or self.gui.SelectedObject ~= nil or (self.options.isBlocked and self.options.isBlocked())
end
function JumpController:_observe()
	local character = self.player.Character
	if self.character ~= character then
		self.character, self.phase, self.groundSince, self.firstPress = character, "unarmed", nil, false
	end
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root then
		self.phase, self.groundSince, self.firstPress = "unarmed", nil, false
		return
	end
	local state, now = humanoid:GetState(), self.clock()
	local vertical = root.AssemblyLinearVelocity.Y
	local standing = state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.Landed
	if standing and humanoid.FloorMaterial ~= Enum.Material.Air and math.abs(vertical) <= 5 then
		if not self.groundSince then self.groundSince = now end
		if now - self.groundSince >= 0.12 and self.phase ~= "grounded" then
			self.phase, self.firstPress = "grounded", false
			self.pending=nil
		end
	else
		self.groundSince = nil
		if self.phase == "grounded" then
			self.phase,self.takeoffAt="pending",now
		end
		if self.phase=="pending" then
			if vertical>=8 then self.phase="air"
			elseif vertical < 0 or now-self.takeoffAt>0.25 then self.phase="falling" end
		end
	end
end
function JumpController:_press()
	if self.destroyed then return end
	self:_observe()
	if self:_blocked() then return end
	-- The native touch controller can start takeoff before this observer runs.
	-- Count a first physical press even in that ordering; only a later edge boosts.
	if not self.firstPress then self.firstPress = true; return end
	if not self.options.isUnlocked() or self.phase ~= "air" then return end
	self.phase = "consumed"
	self.serial=(self.serial or 0)+1
	self.pending={nonce=self.serial,character=self.player.Character,at=self.clock()}
	self.options.requestJump(self.serial)
end
function JumpController:_refreshButton()
	local touchGui = self.playerGui:FindFirstChild("TouchGui")
	local controls = touchGui and touchGui:FindFirstChild("TouchControlFrame")
	local button = controls and controls:FindFirstChild("JumpButton")
	if button == self.button then return end
	disconnect(self.buttonConnections)
	self.button = button
	table.clear(self.touches)
	if not button then return end
	table.insert(self.buttonConnections, button.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Touch or self.touches[input] then return end
		local alreadyHeld = next(self.touches) ~= nil
		self.touches[input] = true
		-- Only touches beginning on the native button count; camera drags do not.
		if not alreadyHeld then self:_press() end
	end))
	table.insert(self.buttonConnections, button.InputEnded:Connect(function(input) self.touches[input] = nil end))
end
function JumpController:destroy()
	if self.destroyed then return end
	self.destroyed = true
	self.actions:UnbindAction(ACTION)
	disconnect(self.connections)
	disconnect(self.buttonConnections)
	self:_cancel()
	table.clear(self.suppressed)
end
return JumpController
