local Players=game:GetService("Players")
local Rep=game:GetService("ReplicatedStorage")
local Test=game:GetService("StudioTestService")
local Log=game:GetService("LogService")
local Http=game:GetService("HttpService")
local probe=Instance.new("RemoteEvent");probe.Name,probe.Parent="__RollboxOceanProbe",Rep
local reports={}
local result={fixture="ocean-engine-v1",assertions={},stages={},finished=false}
task.spawn(function()
	local remotes=Rep:WaitForChild("Remotes",20)
	remotes.CannonFire.OnServerEvent:Connect(function(player,direction)
		if typeof(direction)=="Vector3" then
			result.lastFire={direction={direction.X,direction.Y,direction.Z},at=os.clock()}
		end
	end)
end)
probe.OnServerEvent:Connect(function(player,payload)
	if type(payload)~="table" then return end
	reports[player]=reports[player] or {};reports[player][payload.stage]=payload
end)
local function waitFor(fn,seconds)
	local deadline=os.clock()+seconds
	repeat local value=fn();if value then return value end;task.wait(0.05) until os.clock()>deadline
	error("Ocean fixture timed out")
end
local function finish(reason)
	if result.finished then return end
	result.finished,result.reason=true,reason;result.serverErrors={}
	for _,row in Log:GetLogHistory() do if row.messageType==Enum.MessageType.MessageError and #result.serverErrors<12 then table.insert(result.serverErrors,row.message) end end
	Test:EndTest(Http:JSONEncode(result))
end
local function ask(player,stage,command)
	probe:FireClient(player,stage,command or {kind="inspect"})
	local reply=waitFor(function() return reports[player] and reports[player][stage] end,25)
	assert(reply.ok,reply.data and reply.data.problem)
	result.stages[stage]=reply.data;return reply.data
end
local function move(player,point)
	local char=player.Character;char:PivotTo(CFrame.new(point));char.HumanoidRootPart.AssemblyLinearVelocity=Vector3.zero;task.wait(0.7)
end
local function v(a) return Vector3.new(table.unpack(a)) end
task.spawn(function()
	local ok,problem=pcall(function()
		local player=waitFor(function() for p,rows in reports do if rows.ready then return p end end end,45)
		local shared=Rep.Shared
		local config=require(shared.BlasterConfig)
		local ocean=require(shared.OceanConfig)
		-- Native channel preservation probe; all edits are in the disposable test VM.
		local terrain=workspace.Terrain
		local min=Vector3.new(ocean.water.minX,ocean.water.bottomY,ocean.water.minZ)
		local region=Region3.new(min,min+Vector3.new(4,4,4))
		local channels={"SolidMaterial","SolidOccupancy","LiquidOccupancy"}
		local saved=terrain:ReadVoxelChannels(region,4,channels)
		terrain:WriteVoxelChannels(region,4,{SolidMaterial={{{Enum.Material.Rock}}},SolidOccupancy={{{0.5}}},LiquidOccupancy={{{0.25}}}})
		local bounded=table.clone(ocean.water)
		bounded.maxX,bounded.maxZ,bounded.surfaceY=bounded.minX+4,bounded.minZ+4,bounded.bottomY+4
		local builder=require(game:GetService("ServerScriptService").Server.OceanWorld)
		local preserved=builder.fillWater(terrain,bounded)
		local mixed=terrain:ReadVoxelChannels(region,4,channels)
		terrain:WriteVoxelChannels(region,4,{SolidMaterial={{{Enum.Material.Air}}},SolidOccupancy={{{0}}},LiquidOccupancy={{{0}}}})
		local filled=builder.fillWater(terrain,bounded)
		local repeated=builder.fillWater(terrain,bounded)
		terrain:WriteVoxelChannels(region,4,{SolidMaterial=saved.SolidMaterial,SolidOccupancy=saved.SolidOccupancy,LiquidOccupancy=saved.LiquidOccupancy})
		result.assertions.terrainPreservation=preserved.voxelsAdded==0 and mixed.SolidMaterial[1][1][1]==Enum.Material.Rock
			and math.abs(mixed.SolidOccupancy[1][1][1]-0.5)<0.01 and math.abs(mixed.LiquidOccupancy[1][1][1]-0.25)<0.01
			and filled.voxelsAdded==1 and repeated.voxelsAdded==0
		local shores=require(game:GetService("ServerScriptService").Server.Shores).new(ocean)
		result.assertions.seafloorWaterProbe=shores:inWater({Position=Vector3.new(80,-51,-76)})
		local target=config.targets[1].position
		local initial=ask(player,"initial")
		result.assertions.locked=initial.snapshot.blaster.unlocked==false
		local locked=ask(player,"lockedFire",{kind="burst",target=target})
		result.assertions.lockedFire=locked.snapshot.blaster.shots==0
		move(player,Vector3.new(50,13,24));ask(player,"farCrate",{kind="e"})
		local far=ask(player,"farState")
		result.assertions.farCrate=far.snapshot.blaster.unlocked==false
		move(player,v(config.cratePosition)+Vector3.new(-5,1.4,2))
		local opened=ask(player,"opened",{kind="e"})
		result.assertions.nativeCrate=opened.crateEvents>=1 and opened.snapshot.blaster.unlocked==true and opened.cannon
		result.assertions.independentAbilities=opened.snapshot.powerup.unlocked==false
		local duplicate=ask(player,"duplicate",{kind="e"})
		result.assertions.noEconomy=duplicate.snapshot.coins==0 and duplicate.snapshot.adventure.score==opened.snapshot.adventure.score
		local fired=ask(player,"nativeFire",{kind="shoot",target=target})
		result.assertions.nativeFire=fired.fireEvents>=1 and fired.snapshot.blaster.shots==1
		result.assertions.targetHit=fired.snapshot.blaster.hits==1
		result.nativeAimFire=result.lastFire
		local args=Test:GetTestArgs()
		if type(args)=="table" and args.aimOnly then finish("aim_diagnostic");return end
		local invalid=ask(player,"malformed",{kind="invalid"})
		result.assertions.invalidRejected=invalid.snapshot.blaster.shots==fired.snapshot.blaster.shots
		local focus=ask(player,"focus",{kind="focus",target=target})
		result.assertions.focusBlocked=focus.snapshot.blaster.shots==invalid.snapshot.blaster.shots
		local burst=ask(player,"burst",{kind="burst",target=target})
		result.assertions.cooldown=burst.snapshot.blaster.shots==focus.snapshot.blaster.shots+1
		result.assertions.projectilesRetired=burst.snapshot.blaster.activeProjectiles==0
		local dryBefore=player.Character.HumanoidRootPart.Position
		ask(player,"dryReturn",{kind="r"})
		result.assertions.dryReturn=(player.Character.HumanoidRootPart.Position-dryBefore).Magnitude<2
		-- Actual walk off the Training shortcut into native water while carrying.
		move(player,Vector3.new(7,12.5,6));ask(player,"takeParcel",{kind="e"})
		ask(player,"leaveDepot",{kind="walk",target={0,12.5,3}})
        ask(player,"gateOne",{kind="walk",target={0,12.5,-32}})
		ask(player,"switchTwo",{kind="q"})
		ask(player,"gateTwo",{kind="walk",target={0,12.5,-58}})
		local fall=ask(player,"fall",{kind="walk",target={0,12.5,-74},seconds=4})
		local swim=ask(player,"swim",{kind="swim"})
		result.assertions.fallCancelled=swim.snapshot.state=="Idle" and swim.snapshot.coins==0 and not player.Character:FindFirstChild("CourierParcel")
		result.assertions.nativeSwimming=swim.swimFrames>0 and swim.state=="Swimming" and swim.snapshot.inWater==true
		result.assertions.swimMotion=swim.distance>5
		local returned=ask(player,"return",{kind="r"})
		result.assertions.returnLand=returned.position[2]>0 and returned.snapshot.inWater==false and returned.snapshot.state=="Idle"
		result.assertions.retainedAfterWater=returned.snapshot.blaster.unlocked==true and returned.cannon and returned.snapshot.coins==0
		result.assertions.shoreRamps=true
		for _,exit in ocean.exits do
			local low,high=v(exit.water),v(exit.rampTop)
			local out=Vector3.new(low.X-high.X,0,low.Z-high.Z).Unit
			move(player,low+out*20+Vector3.new(0,1,0))
			local before=ask(player,exit.id.."Water")
			local up=ask(player,exit.id.."Ramp",{kind="walk",target={high.X,high.Y+3,high.Z},seconds=18})
			local landed=ask(player,exit.id.."Land",{kind="walk",target=exit.landing,seconds=8})
			local reached=(player.Character.HumanoidRootPart.Position-v(exit.landing)).Magnitude<5
			result.assertions.shoreRamps=result.assertions.shoreRamps and before.snapshot.inWater==true and reached and landed.snapshot.inWater==false
		end
		local old=player.Character;old.Humanoid.Health=0
		waitFor(function() return player.Character~=old and player.Character and player.Character:FindFirstChild("HumanoidRootPart") end,10);task.wait(0.8)
		local respawn=ask(player,"respawn")
		result.assertions.respawn=respawn.snapshot.blaster.unlocked==true and respawn.cannon
		result.assertions.noClientErrors=#respawn.errors==0
		local all=true;for _,passed in result.assertions do all=all and passed end
		finish(if all then "ocean_succeeded" else "ocean_failed")
	end)
	if not ok then result.problem=tostring(problem);finish("fixture_error") end
end)
task.delay(220,function() finish("fixture_timeout") end)
