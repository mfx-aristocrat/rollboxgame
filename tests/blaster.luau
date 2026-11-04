-- Production modules at mocked engine boundaries; these are not Studio playtests.
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local roblox=require("@lune/roblox")
local Config=require("../src/shared/BlasterConfig")
local Rules=require("../src/shared/BlasterRules")
local V,E=roblox.Vector3,roblox.Enum
local function loadModule(path)
	return luau.load(fs.readFile(path),{debugName=path,injectGlobals=true,environment={
		Vector3=V,Color3=roblox.Color3,CFrame=roblox.CFrame,Enum=E,Instance=roblox.Instance,
		RaycastParams={new=function() return {} end},
	}})()
end
local function signal()
	local entries={}
	return {Connect=function(_,fn)
		local entry={fn=fn,active=true};table.insert(entries,entry)
		return {Disconnect=function() entry.active=false end}
	end,Fire=function(_,...)
		for _,entry in entries do if entry.active then entry.fn(...) end end
	end}
end
local function harness()
	local now,rays,lastParams,lastSegment,result,equipped=10,0,nil,nil,nil,0
	local people={}
	local prompt={Triggered=signal()}
	local target={Parent={},Color=roblox.Color3.fromRGB(255,149,51),Material=E.Material.SmoothPlastic,attributes={HitCount=0}}
	function target:GetAttribute(key) return self.attributes[key] end
	function target:SetAttribute(key,value) self.attributes[key]=value end
	local world={root={},prompt=prompt,crate={Parent={},Anchored=true,Position=V.new(table.unpack(Config.cratePosition))},targets={{part=target,spec=Config.targets[1]}}}
	local function object(parent)
		return {Parent=parent,Destroy=function(self) self.Parent=nil end}
	end
	local service=loadModule("src/server/Blaster.luau").new(world,Config,{
		rules=Rules,clock=function() return now end,players={GetPlayers=function() return people end},
		workspace={Raycast=function(_,_,segment,params)
			rays+=1;lastParams,lastSegment=params,segment;return result
		end},equip=function(character) equipped+=1;return object(character) end,
		makeProjectile=function(position,parent) local part=object(parent);part.Position=position;return part end,
	})
	local function player()
		local root={Position=world.crate.Position,Anchored=false,IsA=function(_,name) return name=="BasePart" end}
		local humanoid={Health=100}
		local character={FindFirstChild=function(_,name) return if name=="HumanoidRootPart" then root else nil end,
			FindFirstChildOfClass=function(_,name) return if name=="Humanoid" then humanoid else nil end}
		local person={Character=character};table.insert(people,person);service:add(person)
		return person,root,humanoid
	end
	return {service=service,world=world,prompt=prompt,target=target,player=player,
		time=function(value) now=value end,hit=function(value) result=value end,
		rays=function() return rays,lastParams,lastSegment end,equips=function() return equipped end}
end
return function()
	local count=0
	local function test(name,fn) local ok,err=pcall(fn);assert(ok,name..": "..tostring(err));count+=1 end
	test("frozen separate configuration fixes bounds and rate",function()
		assert(table.isfrozen(Config) and table.isfrozen(Config.targets[1].position))
		assert(Config.cratePosition[1]==92 and Config.cooldown==0.4)
		assert(Config.projectileSpeed==90 and Config.projectileRange==150)
	end)
	test("near-only live once-only collection and independent snapshots",function()
		local state=Rules.newState();local at=Config.cratePosition
		for _,point in {{at[1]+9.001,at[2],at[3]},{at[1]+7,at[2],at[3]+7},{0,0/0,0},{0,math.huge,0}} do
			assert(not Rules.collect(Config,state,point,true))
		end
		assert(not Rules.collect(Config,state,at,false))
		assert(Rules.collect(Config,state,{at[1]+9,at[2],at[3]},true))
		assert(not Rules.collect(Config,state,at,true))
		local copy=Rules.snapshot(state);copy.unlocked=false;assert(state.unlocked)
	end)
	test("directions require finite near-unit triples",function()
		for _,direction in {false,{}, {1,0}, {0,0,0},{100,0,0},{1,0/0,0},{math.huge,0,0},{0.94,0,0},{1.06,0,0}} do
			assert(not Rules.direction(direction))
		end
		local unit=Rules.direction({1.02,0,0});assert(unit and unit[1]==1)
	end)
	test("request throttle bounds duplicates backwards malformed and burst time",function()
		local state=Rules.newState()
		for _,now in {0/0,math.huge,-1,"10"} do assert(not Rules.admit(Config,state,"fire",now)) end
		assert(Rules.admit(Config,state,"fire",10))
		for _=1,100 do assert(not Rules.admit(Config,state,"fire",10)) end
		assert(not Rules.admit(Config,state,"fire",9))
		assert(Rules.admit(Config,state,"fire",10.1))
	end)
	test("fire rejects locked dead cooldown personal/global caps without consuming shot",function()
		local state=Rules.newState();local direction={1,0,0}
		assert(not Rules.fire(Config,state,direction,true,10,0));state.unlocked=true
		assert(not Rules.fire(Config,state,direction,false,10,0))
		assert(Rules.fire(Config,state,direction,true,10,0))
		assert(not Rules.fire(Config,state,direction,true,10.39,0))
		state.activeProjectiles=Config.maxPerPlayer
		assert(not Rules.fire(Config,state,direction,true,11,0));state.activeProjectiles=0
		assert(not Rules.fire(Config,state,direction,true,11,Config.maxProjectiles))
		assert(state.shots==1 and Rules.fire(Config,state,direction,true,11,0))
		Rules.retire(state);Rules.retire(state);assert(state.activeProjectiles==0)
	end)
	test("orange mushroom source is fixed nonblocking and rebuild replaces root",function()
		local module=loadModule("src/server/BlasterWorld.luau")
		local parent=roblox.Instance.new("Folder");local world=module.build(parent,Config)
		assert(world.crate.Position==V.new(table.unpack(Config.cratePosition)))
		assert(world.prompt.KeyboardKeyCode==E.KeyCode.E and world.prompt.GamepadKeyCode==E.KeyCode.ButtonX)
		assert(world.prompt.MaxActivationDistance==9 and #world.targets==3)
		local queryable=0
		for _,part in world.root:GetDescendants() do
			if part:IsA("BasePart") then
				assert(part.Anchored and not part.CanCollide and not part.CanTouch)
				if part.CanQuery then queryable+=1;assert(part:GetAttribute("TargetId")) end
			end
		end
		assert(queryable==3)
		local old=world.root;module.build(parent,Config);assert(old.Parent==nil and #parent:GetChildren()==1)
	end)
	test("production prompt checks far dead moved unanchored duplicate and unregistered",function()
		local h=harness();local p,root,humanoid=h.player()
		h.prompt.Triggered:Fire({});root.Position+=V.new(10,0,0);h.prompt.Triggered:Fire(p)
		assert(not h.service:snapshot(p).unlocked)
		h.time(11);root.Position=h.world.crate.Position;humanoid.Health=0;h.prompt.Triggered:Fire(p)
		assert(not h.service:snapshot(p).unlocked)
		h.time(12);humanoid.Health=100;h.world.crate.Anchored=false;h.prompt.Triggered:Fire(p)
		assert(not h.service:snapshot(p).unlocked)
		h.time(13);h.world.crate.Anchored=true;h.world.crate.Position+=V.new(1,0,0);h.prompt.Triggered:Fire(p)
		assert(not h.service:snapshot(p).unlocked)
		h.time(14);h.world.crate.Position=V.new(table.unpack(Config.cratePosition));h.prompt.Triggered:Fire(p)
		assert(h.service:snapshot(p).unlocked and h.equips()==1)
		h.time(15);h.prompt.Triggered:Fire(p);assert(h.equips()==1)
	end)
	test("production fire enforces Vector3 authority and floods create no rays",function()
		local h=harness();local p,root,humanoid=h.player()
		assert(not h.service:fire(p,V.xAxis,10))
		h.prompt.Triggered:Fire(p)
		for index,direction in {{1,0,0},V.zero,V.new(0/0,0,0),V.new(math.huge,0,0),V.new(5,0,0)} do
			assert(not h.service:fire(p,direction,11+index))
		end
		humanoid.Health=0;assert(not h.service:fire(p,V.xAxis,20));humanoid.Health=100
		root.Anchored=true;assert(not h.service:fire(p,V.xAxis,21));root.Anchored=false
		assert(h.service:fire(p,V.xAxis,22))
		for _=1,100 do assert(not h.service:fire(p,V.xAxis,22)) end
		assert(h.rays()==1 and h.service:snapshot(p).activeProjectiles==1)
	end)
	test("segment ray sees whole travel excludes every player and target hit is once only",function()
		local h=harness();local a=h.player();local b=h.player();h.prompt.Triggered:Fire(a)
		assert(h.service:fire(a,V.xAxis,10))
		h.hit({Instance=h.target});h.service:step(0.1,10.1)
		local rays,params,segment=h.rays()
		assert(rays==2 and math.abs(segment.Magnitude-9)<0.001)
		assert(params.FilterType==E.RaycastFilterType.Exclude and params.IgnoreWater)
		assert(params.FilterDescendantsInstances[1]==a.Character and params.FilterDescendantsInstances[2]==b.Character)
		local snapshot=h.service:snapshot(a)
		assert(snapshot.hits==1 and snapshot.activeProjectiles==0 and h.target:GetAttribute("HitCount")==1)
		assert(h.target.Material==E.Material.Neon and h.service:snapshot(b).hits==0)
		h.service:step(1,11);assert(h.service:snapshot(a).hits==1 and h.target.Material==E.Material.SmoothPlastic)
		assert(snapshot.coins==nil and snapshot.damage==nil)
	end)
	test("walls retire without hit and long frame never exceeds configured range",function()
		local h=harness();local p=h.player();h.prompt.Triggered:Fire(p)
		assert(h.service:fire(p,V.xAxis,10));h.hit({Instance={}});h.service:step(0.1,10.1)
		assert(h.service:snapshot(p).hits==0 and h.service:snapshot(p).activeProjectiles==0)
		h.hit(nil);assert(h.service:fire(p,V.xAxis,11));h.service:step(100,11.1)
		local _,_,segment=h.rays();assert(segment.Magnitude==150)
		assert(#h.service.projectiles==0)
	end)
	test("root to muzzle obstruction retires before spawning beyond thin wall",function()
		local h=harness();local p=h.player();h.prompt.Triggered:Fire(p)
		h.hit({Instance={}})
		assert(h.service:fire(p,V.xAxis,10))
		local rays,_,segment=h.rays()
		assert(rays==1 and segment==V.new(0,1,0) and #h.service.projectiles==0)
		assert(h.service:snapshot(p).activeProjectiles==0 and h.service:snapshot(p).hits==0)
	end)
	test("production adapter caps six per owner and forty eight globally",function()
		local h=harness()
		local owners={}
		for _=1,9 do local p=h.player();h.prompt.Triggered:Fire(p);table.insert(owners,p) end
		for owner=1,8 do
			for shot=1,6 do assert(h.service:fire(owners[owner],V.xAxis,10+shot*0.5)) end
			assert(not h.service:fire(owners[owner],V.xAxis,14))
		end
		local before=h.rays()
		assert(#h.service.projectiles==48 and not h.service:fire(owners[9],V.xAxis,14))
		assert(h.rays()==before,"caps must reject before raycasts")
		h.service:remove(owners[1]);assert(#h.service.projectiles==42)
		assert(h.service:fire(owners[9],V.xAxis,15))
		h.service:destroy();assert(#h.service.projectiles==0)
	end)
	test("real source cannon parts are massless noncolliding welded and cleaned",function()
		local h=harness()
		local character=roblox.Instance.new("Model")
		local root=roblox.Instance.new("Part");root.Name="HumanoidRootPart";root.Anchored=false;root.Position=V.zero;root.Parent=character
		local hand=roblox.Instance.new("Part");hand.Name="RightHand";hand.CFrame=roblox.CFrame.new();hand.Parent=character
		local humanoid=roblox.Instance.new("Humanoid");humanoid.Health=100;humanoid.Parent=character
		local p={Character=character}
		local service=loadModule("src/server/Blaster.luau").new(h.world,Config,{
			rules=Rules,clock=function() return 10 end,workspace={},players={GetPlayers=function() return {p} end},
		})
		service:add(p);service.states[p].unlocked=true;service:characterAdded(p)
		local cannon=character:FindFirstChild("PracticeCannon");assert(cannon)
		local parts,welds=0,0
		for _,item in cannon:GetDescendants() do
			if item:IsA("BasePart") then
				parts+=1;assert(item.Massless and not item.Anchored and not item.CanCollide and not item.CanQuery and not item.CanTouch)
			elseif item:IsA("WeldConstraint") then welds+=1;assert(item.Part0==hand and item.Part1.Parent==cannon) end
		end
		assert(parts==3 and welds==3)
		service:characterAdded(p);assert(cannon.Parent==nil and #character:GetChildren()==4)
		service:destroy();assert(not character:FindFirstChild("PracticeCannon"))
	end)
	test("projectiles expire on stalls death removal and teardown without stale counts",function()
		for _,kind in {"stall","death","remove","destroy"} do
			local h=harness();local p,_,humanoid=h.player();h.prompt.Triggered:Fire(p)
			assert(h.service:fire(p,V.xAxis,10))
			if kind=="death" then humanoid.Health=0;h.service:step(0.1,10.1)
			elseif kind=="remove" then h.service:remove(p)
			elseif kind=="destroy" then h.service:destroy();h.service:destroy()
			else h.service:step(0,20) end
			assert(#h.service.projectiles==0)
			local state=h.service:snapshot(p);assert(not state or state.activeProjectiles==0)
		end
	end)
	test("session unlock equips after respawn isolates players and resets on leave",function()
		local h=harness();local a=h.player();local b=h.player();h.prompt.Triggered:Fire(a)
		assert(h.service:snapshot(a).unlocked and not h.service:snapshot(b).unlocked)
		local original=a.Character;a.Character=nil;h.service:step(0.1,11);assert(h.equips()==1)
		a.Character={FindFirstChild=original.FindFirstChild,FindFirstChildOfClass=original.FindFirstChildOfClass}
		h.service:step(0.1,12);h.service:step(0.1,12.1)
		assert(h.equips()==2 and h.service:snapshot(a).unlocked)
		h.service:remove(a);h.service:add(a);assert(not h.service:snapshot(a).unlocked)
		h.service:destroy();h.prompt.Triggered:Fire(b);h.service:add(a)
		assert(not h.service:snapshot(a) and not h.service:fire(a,V.xAxis,20))
	end)
	return count
end
