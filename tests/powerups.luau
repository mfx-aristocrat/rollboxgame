-- Actual module adapters with engine boundaries; not a device/physics playtest.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local Config = require("../src/shared/PowerupConfig")
local Rules = require("../src/shared/PowerupRules")
local V, E = roblox.Vector3, roblox.Enum
local function signal()
	local handlers = {}
	return {
		Connect = function(_, fn)
			local entry = { fn = fn, active = true }; table.insert(handlers, entry)
			return { Disconnect = function() entry.active = false end }
		end,
		Fire = function(_, ...) for _, entry in handlers do if entry.active then entry.fn(...) end end end,
	}
end
local function loadModule(path, environment)
	return luau.load(fs.readFile(path), {debugName=path, injectGlobals=true, environment=environment})()
end
local function sample(grounded, y)
	return { alive = true, position = {0, 12, 0}, velocity = {0,y or 0,0}, grounded = grounded }
end
local function armed()
	local state = Rules.newState(); state.unlocked = true
	Rules.observe(Config, state, sample(true), 1)
	Rules.observe(Config, state, sample(true), 1.2)
	return state
end
local function serverHarness(r6)
	local now, grounded, raycasts, lastParams, lastDirection = 10, true, 0, nil, nil
	local prompt = { Triggered = signal() }
	local world = {prompt=prompt, crate={Anchored=true, Parent={}, Position=V.new(table.unpack(Config.cratePosition))}}
	local module = loadModule("src/server/Powerups.luau", {
		Vector3 = V, Enum = E, RaycastParams = { new = function() return {} end },
	})
	local mockWorld = { Raycast = function(_, _, direction, params)
		raycasts += 1; lastParams, lastDirection = params, direction
		return if grounded then {Normal=V.new(0,1,0)} else nil
	end }
	local service = module.new(world, Config, {rules=Rules,workspace=mockWorld,clock=function() return now end})
	local function player()
		local root = {Position=world.crate.Position, AssemblyLinearVelocity=V.zero, Size=V.new(2,2,1), CollisionGroup="Couriers", Anchored=false,
			IsA=function(_, name) return name=="BasePart" end}
		local humanoid = { Health=100, HipHeight=if r6 then 0 else 2, RigType=if r6 then E.HumanoidRigType.R6 else E.HumanoidRigType.R15 }
		local leg = {Size=V.new(1,2,1), IsA=root.IsA}
		local character = {
			FindFirstChildOfClass=function(_, name) return if name=="Humanoid" then humanoid else nil end,
			FindFirstChild=function(_, name) return if name=="HumanoidRootPart" then root elseif name=="Left Leg" then leg else nil end,
		}
		local p = {Character=character}; service:add(p)
		return p, root, humanoid
	end
	return {service=service, world=world, prompt=prompt, player=player,
		time=function(value) now=value end, ground=function(value) grounded=value end,
		rays=function() return raycasts,lastParams,lastDirection end}
end
local function clientHarness()
	local now, requests, unlocked, blocked = 1, 0, true, false
	local humanoid = {Health=100, FloorMaterial=E.Material.Grass, state=E.HumanoidStateType.Running,
		GetState=function(self) return self.state end}
	local root = {AssemblyLinearVelocity=V.zero}
	local playerGui = {DescendantAdded=signal(), DescendantRemoving=signal(), children={}}
	function playerGui:FindFirstChild(name) return self.children[name] end
	local player = {CharacterAdded=signal(), CharacterRemoving=signal(), WaitForChild=function() return playerGui end}
	player.Character = {FindFirstChildOfClass=function() return humanoid end,FindFirstChild=function() return root end}
	local input = {InputEnded=signal(),WindowFocusReleased=signal(),TextBoxFocused=signal(),GamepadDisconnected=signal(),LastInputTypeChanged=signal(),focused=nil,
		GetFocusedTextBox=function(self) return self.focused end}
	local gui = {MenuOpened=signal(),MenuIsOpen=false,SelectedObject=nil}
	local heartbeat, callback, unbound = signal(), nil, false
	local actions = {
		BindActionAtPriority=function(_, _, fn, createButton, priority, space, pad)
			assert(not createButton and priority > E.ContextActionPriority.High.Value)
			assert(space==E.KeyCode.Space and pad==E.KeyCode.ButtonA); callback=fn
		end,
		UnbindAction=function() unbound=true end,
	}
	local module = loadModule("src/client/JumpController.luau", {Enum=E,Vector3=V})
	local controller = module.new({player=player, requestJump=function() requests+=1 end,
		isUnlocked=function() return unlocked end,isBlocked=function() return blocked end,clock=function() return now end,
		services={UserInputService=input,GuiService=gui,ContextActionService=actions,RunService={Heartbeat=heartbeat}}})
	local function tick(value) now=value; heartbeat:Fire() end
	local function edge(state, key) return callback("MushroomDoubleJump",state,{KeyCode=key or E.KeyCode.Space}) end
	local function jump()
		humanoid.state, humanoid.FloorMaterial, root.AssemblyLinearVelocity = E.HumanoidStateType.Jumping,E.Material.Air,V.new(0,30,0)
	end
	local function land()
		humanoid.state, humanoid.FloorMaterial, root.AssemblyLinearVelocity = E.HumanoidStateType.Running,E.Material.Grass,V.zero
	end
	local function button()
		local b = {InputBegan=signal(),InputEnded=signal()}
		local controls = {FindFirstChild=function(_, name) return if name=="JumpButton" then b else nil end}
		playerGui.children.TouchGui = {FindFirstChild=function(_, name) return if name=="TouchControlFrame" then controls else nil end}
		playerGui.DescendantAdded:Fire(b)
		return b
	end
	return {controller=controller, input=input,gui=gui,root=root,humanoid=humanoid,player=player,playerGui=playerGui,
		tick=tick,edge=edge,jump=jump,land=land,button=button,
		requests=function() return requests end,unbound=function() return unbound end,
		unlock=function(value) unlocked=value end,block=function(value) blocked=value end}
end
return function()
	local count = 0
	local function test(name, fn)
		local ok, err = pcall(fn); assert(ok,name..": "..tostring(err)); count+=1
	end
	test("config is pure frozen and distinct from scored items", function()
		assert(table.isfrozen(Config) and table.isfrozen(Config.cratePosition))
		assert(Config.jumpSpeed==52 and Config.pickupRadius==9 and Config.id=="mushroom")
	end)
	test("collection exact sphere, finite live pose and once-only entitlement", function()
		local at=Config.cratePosition
		for _, point in {{at[1]+9.001,at[2],at[3]},{at[1]+7,at[2],at[3]+7},{0,0/0,0},{0,math.huge,0}} do
			assert(not Rules.collect(Config,Rules.newState(),point,true))
		end
		local state=Rules.newState()
		assert(not Rules.collect(Config,state,at,false))
		assert(Rules.collect(Config,state,{at[1]+9,at[2],at[3]},true))
		assert(not Rules.collect(Config,state,at,true))
		local copy=Rules.snapshot(state); copy.unlocked=false; assert(state.unlocked)
	end)
	test("rate checks reject nonfinite backwards and burst times before observation", function()
		local state=Rules.newState()
		for _, now in {math.huge,0/0,-math.huge,"10"} do assert(not Rules.admit(Config,state,"jump",now)) end
		assert(Rules.admit(Config,state,"jump",10))
		assert(not Rules.admit(Config,state,"jump",10) and not Rules.admit(Config,state,"jump",9))
		assert(Rules.admit(Config,state,"jump",10.1))
	end)
	test("stable ground then upward takeoff grants precisely one fixed cycle", function()
		local state=armed()
		assert(not Rules.consume(Config,state,1.2))
		Rules.observe(Config,state,sample(false,30),1.3)
		assert(Rules.consume(Config,state,1.3))
		Rules.observe(Config,state,sample(false,-5),1.6)
		assert(not Rules.consume(Config,state,1.6))
		Rules.observe(Config,state,sample(true),2)
		assert(not Rules.consume(Config,state,2))
		Rules.observe(Config,state,sample(true),2.2)
		Rules.observe(Config,state,sample(false,30),2.3)
		assert(Rules.consume(Config,state,2.3))
	end)
	test("zero integration frame before upward takeoff still grants one air jump", function()
		local state=armed()
		Rules.observe(Config,state,sample(false,0),1.3)
		assert(not Rules.consume(Config,state,1.3),"zero-speed frame is not proof of takeoff")
		Rules.observe(Config,state,sample(false,52),1.32)
		assert(Rules.consume(Config,state,1.32),"ordinary takeoff integrated after the zero-speed frame")
		Rules.observe(Config,state,sample(false,52),1.34)
		assert(not Rules.consume(Config,state,1.34),"observing upward speed cannot restore a consumed charge")
	end)
	test("a short ground flicker never refills a consumed air jump", function()
		local state=armed()
		Rules.observe(Config,state,sample(false,30),1.3); assert(Rules.consume(Config,state,1.3))
		Rules.observe(Config,state,sample(true),1.4)
		Rules.observe(Config,state,sample(false,30),1.45)
		assert(not Rules.consume(Config,state,1.45))
	end)
	test("ledge fall, midair spawn, locked and nonfinite samples cannot boost", function()
		local state=armed()
		Rules.observe(Config,state,sample(false,-2),1.3)
		Rules.observe(Config,state,sample(false,30),1.4)
		assert(not Rules.consume(Config,state,1.4))
		local fresh=Rules.newState(); fresh.unlocked=true
		Rules.observe(Config,fresh,sample(false,30),2); assert(not Rules.consume(Config,fresh,2))
		state=armed(); state.unlocked=false
		Rules.observe(Config,state,sample(false,30),2); assert(not Rules.consume(Config,state,2))
		state=armed(); local bad=sample(false,30); bad.position[1]=0/0
		assert(not Rules.observe(Config,state,bad,2) and not Rules.consume(Config,state,2))
	end)
	test("near-floor upward takeoff is sampled freshly; landing refuses a boost", function()
		local state=armed()
		Rules.observe(Config,state,sample(true,30),1.3)
		assert(Rules.consume(Config,state,1.3))
		state=armed(); Rules.observe(Config,state,sample(false,30),1.3)
		Rules.observe(Config,state,sample(true),1.5)
		assert(not Rules.consume(Config,state,1.5))
	end)
	test("death/reset keeps entitlement but requires a new observed landing", function()
		local state=armed(); Rules.observe(Config,state,sample(false,30),2)
		Rules.resetAir(state)
		assert(state.unlocked and not Rules.consume(Config,state,2))
		Rules.observe(Config,state,sample(false,30),3); assert(not Rules.consume(Config,state,3))
		assert(not Rules.observe(Config,state,nil,4) and state.unlocked)
	end)
	test("source crate is reproducible noncolliding original mushroom geometry", function()
		local module=loadModule("src/server/PowerupWorld.luau",{Instance=roblox.Instance,Vector3=V,Color3=roblox.Color3,Enum=E})
		local parent=roblox.Instance.new("Folder"); local world=module.build(parent,Config)
		assert(world.root.Name=="MushroomPowerup" and world.crate.Position==V.new(table.unpack(Config.cratePosition)))
		assert(world.prompt.MaxActivationDistance==9 and world.prompt.Parent==world.crate)
		local parts,spots=0,0
		for _, part in world.root:GetChildren() do
			if part:IsA("BasePart") then
				parts+=1; assert(part.Anchored and not part.CanCollide and not part.CanTouch and not part.CanQuery)
				assert(part:GetAttribute("PowerupId")=="mushroom")
				if part.Name=="MushroomSpot" then spots+=1 end
			end
		end
		assert(parts==11 and spots==5)
		local old=world.root; module.build(parent,Config); assert(old.Parent==nil and #parent:GetChildren()==1)
	end)
	test("adapter refuses spoofed far, dead and moved/unanchored crate prompts", function()
		local h=serverHarness(); local p,root,humanoid=h.player()
		root.Position+=V.new(10,0,0); h.prompt.Triggered:Fire(p); assert(not h.service:snapshot(p).unlocked)
		h.time(11); root.Position=h.world.crate.Position; humanoid.Health=0
		h.prompt.Triggered:Fire(p); assert(not h.service:snapshot(p).unlocked)
		h.time(12); humanoid.Health=100; h.world.crate.Anchored=false
		h.prompt.Triggered:Fire(p); assert(not h.service:snapshot(p).unlocked)
		h.time(13); h.world.crate.Anchored=true; h.world.crate.Position+=V.new(1,0,0)
		h.prompt.Triggered:Fire(p); assert(not h.service:snapshot(p).unlocked)
		h.time(14); h.world.crate.Position=V.new(table.unpack(Config.cratePosition)); h.prompt.Triggered:Fire(p)
		assert(h.service:snapshot(p).unlocked)
	end)
	test("adapter rate limits precede raycasts and two players unlock independently", function()
		local h=serverHarness(); local a=h.player(); local b=h.player()
		h.prompt.Triggered:Fire(a); local before=h.rays()
		h.prompt.Triggered:Fire(a); assert(h.rays()==before)
		assert(h.service:snapshot(a).unlocked and not h.service:snapshot(b).unlocked)
		h.prompt.Triggered:Fire(b); assert(h.service:snapshot(b).unlocked)
		h.service:requestJump(a,11); before=h.rays()
		for _=1,50 do assert(not h.service:requestJump(a,11)) end
		assert(h.rays()==before)
	end)
	for _, r6 in {false,true} do
		test((if r6 then "R6" else "R15").." adapter uses collision aware standing ray and excludes whole character", function()
			local h=serverHarness(r6); local p=h.player(); h.service:step(p,10)
			local _,params,direction=h.rays()
			assert(params.RespectCanCollide and params.CollisionGroup=="Couriers")
			assert(params.FilterType==E.RaycastFilterType.Exclude and params.FilterDescendantsInstances[1]==p.Character)
			assert(math.abs(direction.Y+3.35)<0.001)
		end)
	end
	test("adapter quick second press replaces Y once and bounds horizontal motion", function()
		local h=serverHarness(); local p,root=h.player()
		h.prompt.Triggered:Fire(p); h.service:step(p,10.2)
		root.AssemblyLinearVelocity=V.new(100,30,-100)
		assert(h.service:requestJump(p,10.25))
		assert(root.AssemblyLinearVelocity==V.new(100,30,-100),"server must approve without a second force executor")
		h.ground(false); assert(not h.service:requestJump(p,10.5))
		root.AssemblyLinearVelocity=V.zero; h.ground(true)
		h.service:step(p,11); h.service:step(p,11.2); h.ground(false)
		root.AssemblyLinearVelocity=V.new(0,30,0)
		assert(h.service:requestJump(p,11.3))
	end)
	test("adapter resets stale character, recovery, dead and nonfinite root state", function()
		local h=serverHarness(); local p,root,humanoid=h.player()
		h.prompt.Triggered:Fire(p); h.service:step(p,10.2)
		root.AssemblyLinearVelocity=V.new(0,30,0); h.ground(false)
		h.service:resetAir(p); assert(not h.service:requestJump(p,10.3))
		h.ground(true); root.AssemblyLinearVelocity=V.zero; h.service:step(p,11); h.service:step(p,11.2)
		p.Character={FindFirstChildOfClass=function() return humanoid end,FindFirstChild=function() return root end}
		root.AssemblyLinearVelocity=V.new(0,30,0); h.ground(false)
		assert(not h.service:requestJump(p,11.3) and h.service:snapshot(p).unlocked)
		humanoid.Health=0; assert(not h.service:requestJump(p,12))
		humanoid.Health=100; root.Position=V.new(0/0,0,0); assert(not h.service:requestJump(p,13))
		h.service:remove(p); h.service:add(p); assert(not h.service:snapshot(p).unlocked)
		h.service:destroy(); h.service:destroy(); h.prompt.Triggered:Fire(p)
		h.service:add(p); assert(h.service:snapshot(p)==nil)
	end)
	test("actual input adapter passes first jump, suppresses hold/third press, recharges on landing", function()
		local h=clientHarness(); h.tick(1); h.tick(1.2)
		assert(h.edge(E.UserInputState.Begin)==E.ContextActionResult.Pass and h.requests()==0)
		h.jump(); h.tick(1.3); h.edge(E.UserInputState.Begin); assert(h.requests()==0)
		h.edge(E.UserInputState.End); h.edge(E.UserInputState.Begin); assert(h.requests()==1)
		h.edge(E.UserInputState.End); h.edge(E.UserInputState.Begin); assert(h.requests()==1)
		h.land(); h.tick(2); h.tick(2.2); h.edge(E.UserInputState.End)
		h.edge(E.UserInputState.Begin); h.edge(E.UserInputState.End); h.jump(); h.tick(2.3)
		h.edge(E.UserInputState.Begin); assert(h.requests()==2)
		assert(h.root.AssemblyLinearVelocity.Y==30,"client must not add ack/predicted physics")
	end)
	test("actual input adapter accepts takeoff after a zero integration frame", function()
		local h=clientHarness(); h.tick(1); h.tick(1.2)
		h.edge(E.UserInputState.Begin); h.edge(E.UserInputState.End)
		h.jump(); h.root.AssemblyLinearVelocity=V.zero; h.tick(1.3)
		h.root.AssemblyLinearVelocity=V.new(0,52,0); h.tick(1.32)
		h.edge(E.UserInputState.Begin); assert(h.requests()==1,"second press after integrated takeoff must send intent")
		h.edge(E.UserInputState.End); h.tick(1.34); h.edge(E.UserInputState.Begin)
		assert(h.requests()==1,"third press cannot gain another jump")
	end)
	test("actual input adapter respects lock, focus, selected GUI, menu and custom shop gate", function()
		for _, gate in {"locked","text","selected","menu","custom"} do
			local h=clientHarness(); h.tick(1); h.tick(1.2); h.jump(); h.tick(1.3)
			if gate=="locked" then h.unlock(false) elseif gate=="text" then h.input.focused={}
			elseif gate=="selected" then h.gui.SelectedObject={} elseif gate=="menu" then h.gui.MenuIsOpen=true else h.block(true) end
			h.edge(E.UserInputState.Begin,E.KeyCode.ButtonA); assert(h.requests()==0,gate)
		end
	end)
	test("touch first press stays ordinary if default touch handler starts takeoff first", function()
		local h=clientHarness(); local b=h.button(); h.tick(1); h.tick(1.2)
		h.jump()
		local touch={UserInputType=E.UserInputType.Touch}
		b.InputBegan:Fire(touch); assert(h.requests()==0)
		b.InputEnded:Fire(touch)
		b.InputBegan:Fire({UserInputType=E.UserInputType.Touch}); assert(h.requests()==1)
	end)
	test("Cancel without a matching key suppresses gamepad repeats until physical release", function()
		local h=clientHarness(); h.tick(1); h.tick(1.2)
		h.edge(E.UserInputState.Begin,E.KeyCode.ButtonA)
		h.jump(); h.tick(1.3); h.edge(E.UserInputState.Cancel,E.KeyCode.Space)
		h.edge(E.UserInputState.Begin,E.KeyCode.ButtonA); assert(h.requests()==0)
		h.edge(E.UserInputState.End,E.KeyCode.ButtonA)
		h.edge(E.UserInputState.Begin,E.KeyCode.ButtonA); assert(h.requests()==1)
	end)
	test("focus cancellation cannot convert a still-held key into a fresh jump", function()
		local h=clientHarness(); h.tick(1); h.tick(1.2)
		h.edge(E.UserInputState.Begin); h.jump(); h.tick(1.3)
		h.input.TextBoxFocused:Fire(); h.edge(E.UserInputState.Begin); assert(h.requests()==0)
		h.edge(E.UserInputState.End); h.edge(E.UserInputState.Begin); assert(h.requests()==1)
	end)
	test("native touch accepts only fresh touches beginning on button and reconnects safely", function()
		local h=clientHarness(); local old=h.button(); h.tick(1); h.tick(1.2)
		local touch={UserInputType=E.UserInputType.Touch}; old.InputBegan:Fire(touch)
		h.jump(); h.tick(1.3); old.InputBegan:Fire(touch); assert(h.requests()==0)
		local second={UserInputType=E.UserInputType.Touch}; old.InputBegan:Fire(second); assert(h.requests()==0)
		h.input.InputEnded:Fire(touch); h.input.InputEnded:Fire(second)
		-- A new native button replaces the old observer, as on touch UI recreation.
		h.playerGui.DescendantRemoving:Fire(old); local current=h.button()
		old.InputBegan:Fire({UserInputType=E.UserInputType.Touch}); assert(h.requests()==0)
		current.InputBegan:Fire({UserInputType=E.UserInputType.MouseMovement}); assert(h.requests()==0)
		current.InputBegan:Fire({UserInputType=E.UserInputType.Touch}); assert(h.requests()==1)
	end)
	test("client ledge fall, respawn and teardown never reuse the old air cycle", function()
		local h=clientHarness(); h.tick(1); h.tick(1.2)
		h.humanoid.state,h.humanoid.FloorMaterial=E.HumanoidStateType.Freefall,E.Material.Air
		h.root.AssemblyLinearVelocity=V.new(0,-2,0); h.tick(1.3)
		h.edge(E.UserInputState.Begin); assert(h.requests()==0)
		h.player.CharacterAdded:Fire(); h.jump(); h.tick(2)
		h.edge(E.UserInputState.End); h.edge(E.UserInputState.Begin); assert(h.requests()==0)
		h.controller:destroy(); h.controller:destroy(); assert(h.unbound())
		h.edge(E.UserInputState.End); h.edge(E.UserInputState.Begin); assert(h.requests()==0)
	end)
	test("owner executes one matching fresh approval and rejects duplicates or reset epochs",function()
		local h=clientHarness();h.tick(1);h.tick(1.2)
		h.edge(E.UserInputState.Begin);h.edge(E.UserInputState.End);h.jump();h.tick(1.3);h.edge(E.UserInputState.Begin)
		local data={kind="jump",nonce=1,character=h.player.Character,epoch=1}
		h.controller:_approve(data);assert(h.root.AssemblyLinearVelocity.Y==52)
		h.root.AssemblyLinearVelocity=V.new(0,5,0);h.controller:_approve(data);assert(h.root.AssemblyLinearVelocity.Y==5)
		h.controller.pending={nonce=2,character=h.player.Character,at=1.3}
		h.controller:_approve({kind="reset",epoch=2})
		h.controller:_approve({kind="jump",nonce=2,character=h.player.Character,epoch=1})
		assert(h.root.AssemblyLinearVelocity.Y==5)
	end)
	return count
end
