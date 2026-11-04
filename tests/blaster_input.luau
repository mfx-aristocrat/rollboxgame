local fs=require("@lune/fs")
local luau=require("@lune/luau")
local r=require("@lune/roblox")
local V,E=r.Vector3,r.Enum
local function signal()
	local callbacks={}
	return {Connect=function(_,fn) local row={fn=fn,active=true};table.insert(callbacks,row);return {Disconnect=function() row.active=false end} end,
		Fire=function(_,...) for _,row in callbacks do if row.active then row.fn(...) end end end}
end
return function()
	local count=0
	local function test(name,fn) local ok,err=pcall(fn);assert(ok,name..": "..tostring(err));count+=1 end
	local function harness()
		local now,unlocked,blocked,wet,shots,returns=10,false,false,false,{},0
		local input={InputBegan=signal(),PreferredInput=E.PreferredInput.KeyboardAndMouse,
			GetFocusedTextBox=function(self) return self.focused end,GetMouseLocation=function() return r.Vector2.new(300,300) end}
		local gui={MenuIsOpen=false,GetGuiInset=function() return r.Vector2.new(0,36) end}
		local camera={ViewportSize=r.Vector2.new(600,600)}
		function camera:ScreenPointToRay(x,y) assert(x==300 and y==264);return {Origin=V.new(0,8,15),Direction=V.new(0,0,-1)} end
		local root={Position=V.new(0,12,0)}
		local h={Health=100}
		local player={Character={FindFirstChild=function() return root end,FindFirstChildOfClass=function() return h end}}
		local module=luau.load(fs.readFile("src/client/BlasterController.luau"),{injectGlobals=true,environment={Enum=E,Vector3=V,RaycastParams={new=function() return {} end}}})()
		local controller=module.new({services={UserInputService=input,GuiService=gui},player=player,clock=function() return now end,
			aimPoint=function() return r.Vector2.new(300,264) end,
			workspace={CurrentCamera=camera,Raycast=function() return {Position=V.new(20,13,0)} end},
			isUnlocked=function() return unlocked end,isBlocked=function() return blocked end,inWater=function() return wet end,
			fire=function(direction) table.insert(shots,direction) end,returnLand=function() returns+=1 end})
		return {controller=controller,input=input,gui=gui,h=h,shots=shots,returns=function() return returns end,
			set=function(u,b,w,t) unlocked,blocked,wet,now=u,b,w,t or now end,
			edge=function(key,processed,kind) input.InputBegan:Fire({KeyCode=key,UserInputType=kind},processed) end}
	end
	test("cannon controls require unlock, unprocessed gameplay input and local cooldown",function()
		local h=harness();h.edge(E.KeyCode.F);assert(#h.shots==0)
		h.set(true,false,false);h.edge(E.KeyCode.F,true);assert(#h.shots==0)
		h.edge(E.KeyCode.F);assert(#h.shots==1 and math.abs(h.shots[1].Magnitude-1)<0.001)
		h.edge(E.KeyCode.F);assert(#h.shots==1)
		h.set(true,false,false,10.5);h.edge(nil,false,E.UserInputType.MouseButton1);assert(#h.shots==2)
	end)
	test("touch action and gamepad use center aim, text/menu/shop/death suppress fire",function()
		local h=harness();h.set(true,false,false);h.input.PreferredInput=E.PreferredInput.Touch;h.controller:fire();assert(#h.shots==1)
		h.set(true,false,false,11);h.input.PreferredInput=E.PreferredInput.Gamepad;h.edge(E.KeyCode.ButtonR2);assert(#h.shots==2)
		for _,mode in {"focus","menu","shop","death"} do
			h.set(true,mode=="shop",false,12);h.input.focused=if mode=="focus" then {} else nil;h.gui.MenuIsOpen=mode=="menu";h.h.Health=if mode=="death" then 0 else 100
			h.controller:fire();assert(#h.shots==2)
		end
	end)
	test("shore shortcuts require water and teardown disconnects input",function()
		local h=harness();h.edge(E.KeyCode.R);assert(h.returns()==0)
		h.set(false,false,true);h.edge(E.KeyCode.ButtonY);assert(h.returns()==1)
		h.set(false,true,true);h.edge(E.KeyCode.R);assert(h.returns()==1)
		h.controller:destroy();h.controller:destroy();h.set(true,false,true);h.edge(E.KeyCode.R);h.edge(E.KeyCode.F);assert(h.returns()==1 and #h.shots==0)
	end)
	return count
end
