local fs=require("@lune/fs")
local luau=require("@lune/luau")
local roblox=require("@lune/roblox")
local Rules=require("../src/shared/ShoreRules")
local Config=require("../src/shared/OceanConfig")
return function()
	local count=0
	local function test(name,fn) local ok,err=pcall(fn);assert(ok,name..": "..tostring(err));count+=1 end
	local b=Config.water
	local function valid(p,alive,water,now,last) return Rules.canReturn(b,b.surfaceY,b.bottomY,p,alive,water,now,last) end
	test("return requires live finite position inside actual ocean and two-second cooldown",function()
		assert(valid({600,-13,250},true,true,10,nil))
		assert(not valid({600,-13,250},false,true,10,nil))
		assert(not valid({600,-13,250},true,false,10,nil))
		assert(not valid({0/0,-13,250},true,true,10,nil))
		assert(not valid({600,math.huge,250},true,true,10,nil))
		assert(not valid({641,-13,250},true,true,10,nil))
		assert(not valid({600,12,250},true,true,10,nil))
		assert(not valid({600,-13,250},true,true,11.99,10))
		assert(valid({600,-13,250},true,true,12,10))
	end)
	test("nearest safe static shore matches region rather than client destination",function()
		assert(Rules.nearest(Config.returnLandings,{610,-13,700}).id=="mesa")
		assert(Rules.nearest(Config.returnLandings,{-600,-13,740}).id=="gardens")
	end)
	test("actual shore adapter gates voxel queries, preserves partial native water, rate limits and cleans player",function()
		local reads,liquid=0,0.25
		local module=luau.load(fs.readFile("src/server/Shores.luau"),{injectGlobals=true,environment={
			Vector3=roblox.Vector3,Region3=roblox.Region3,
		}})()
		local service=module.new(Config,{rules=Rules,terrain={ReadVoxelChannels=function(_,region,res,channels)
			reads+=1;assert(region.CFrame.Position.Y>=Config.water.bottomY+2,"probe fell below native water bottom");assert(res==4 and channels[1]=="LiquidOccupancy" and region.Size==roblox.Vector3.new(4,4,4))
			return {LiquidOccupancy={{{liquid}}}}
		end}})
		local p,root={}, {Position=roblox.Vector3.new(600,-13,275)}
		assert(service:request(p,root,10)[1]==420 and reads==1)
		assert(service:request(p,root,10.1)==nil and reads==1)
		assert(service:request(p,root,11)==nil and reads==2)
		assert(service:request(p,root,12)~=nil)
		root.Position=roblox.Vector3.new(600,-51,275);assert(service:inWater(root))
        root.Position=roblox.Vector3.new(600,-13,275)
        liquid=0;assert(not service:inWater(root));liquid=1
		root.Position=roblox.Vector3.new(0/0,-13,275);local before=reads
		assert(not service:inWater(root) and reads==before)
		root.Position=roblox.Vector3.new(600,-60,275)
		assert(not service:inWater(root) and reads==before)
		service:remove(p);root.Position=roblox.Vector3.new(600,-13,275)
		assert(service:request(p,root,12.1)~=nil)
	end)
	return count
end
