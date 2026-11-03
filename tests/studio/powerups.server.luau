-- Server coordinates real clients; does not grant power-up state or fake jumps.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Test = game:GetService("StudioTestService")
local Http = game:GetService("HttpService")
local Log = game:GetService("LogService")
local probe=Instance.new("RemoteEvent")
probe.Name,probe.Parent="__RollboxPowerupsProbe",ReplicatedStorage
local reports,ready,activeStage={},{},{}
local result={fixture="powerups-engine-v1",assertions={},stages={},intents={},finished=false}
task.spawn(function()
    local remotes=ReplicatedStorage:WaitForChild("Remotes",15)
    if not remotes then return end
    remotes.Intent.OnServerEvent:Connect(function(player,action,...)
        if action~="DoubleJump" then return end
        local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        table.insert(result.intents,{stage=activeStage[player],arguments=select("#",...),
            y=root and root.Position.Y,vy=root and root.AssemblyLinearVelocity.Y})
    end)
end)
probe.OnServerEvent:Connect(function(player,payload)
    if type(payload)~="table" or type(payload.stage)~="string" then return end
    reports[player]=reports[player] or {}
    reports[player][payload.stage]=payload
    if payload.stage=="ready" then ready[player]=true end
end)
local function waitFor(fn,seconds)
    local deadline=os.clock()+seconds
    repeat local value=fn(); if value then return value end; task.wait(0.05) until os.clock()>=deadline
    error("Power-up fixture condition timed out")
end
local function finish(reason)
    if result.finished then return end
    result.finished,result.reason=true,reason
    result.serverErrors={}
    result.livePlayers=#Players:GetPlayers()
    result.readyPlayers=0;for _ in ready do result.readyPlayers+=1 end
    for _,row in Log:GetLogHistory() do
        if row.messageType==Enum.MessageType.MessageError and #result.serverErrors<12 then table.insert(result.serverErrors,row.message) end
    end
    Test:EndTest(Http:JSONEncode(result))
end
local function ask(player,stage,command)
    activeStage[player]=stage
    probe:FireClient(player,stage,command or "inspect")
    local reply=waitFor(function() return reports[player] and reports[player][stage] end,5)
    assert(reply.ok,reply.data and reply.data.problem)
    result.stages[stage]=reply.data
    return reply.data
end
local function move(player,point)
    local character=waitFor(function() return player.Character and player.Character:FindFirstChild("HumanoidRootPart") and player.Character end,6)
    character:PivotTo(CFrame.new(point))
    character.HumanoidRootPart.AssemblyLinearVelocity=Vector3.zero
    task.wait(0.65)
    return character
end
local function walk(player,point)
    local character=player.Character
    character.Humanoid:MoveTo(point)
    waitFor(function() return (character.HumanoidRootPart.Position-point).Magnitude<3 end,8)
    task.wait(0.3)
end
task.spawn(function()
    local ok,problem=pcall(function()
        local args=Test:GetTestArgs()
        local expected=if type(args)=="table" and args.players then args.players else 1
        waitFor(function() local n=0; for _ in ready do n+=1 end; return n>=expected end,45)
        local actors={}; for player in ready do table.insert(actors,player) end
        table.sort(actors,function(a,b) return a.UserId<b.UserId end)
        local actor,other=actors[1],actors[2]
        result.players=#actors
        local config=require(ReplicatedStorage.Shared.PowerupConfig)
        local ground=Vector3.new(0,12.5,-10)
        move(actor,ground)
        local initial=ask(actor,"initial")
        result.assertions.initiallyLocked=initial.snapshot.powerup.unlocked==false
        local single=ask(actor,"single","jump:single")
        move(actor,ground)
        local locked=ask(actor,"lockedForge","jump:lockedForge")
        result.assertions.lockedRejected=locked.height<=single.height+1.5
        local far=ask(actor,"farCrate","e")
        result.assertions.farCrate=far.snapshot.powerup.unlocked==false
        move(actor,Vector3.new(table.unpack(config.cratePosition))+Vector3.new(0,1.4,6))
        local opened=ask(actor,"opened","e")
        result.assertions.nativeMushroom=opened.crateEvents>=1 and opened.snapshot.powerup.unlocked==true
        result.assertions.hud=string.find(opened.ability,"DOUBLE JUMP")~=nil
        local duplicate=ask(actor,"duplicateCrate","e")
        result.assertions.onceOnly=duplicate.snapshot.powerup.unlocked==true and duplicate.snapshot.coins==0 and duplicate.snapshot.adventure.score==opened.snapshot.adventure.score
        if other then
            local before=ask(other,"otherLocked")
            result.assertions.independentLock=before.snapshot.powerup.unlocked==false
            move(other,Vector3.new(table.unpack(config.cratePosition))+Vector3.new(6,1.4,0))
            local own=ask(other,"otherOpened","e")
            result.assertions.independentCrate=own.snapshot.powerup.unlocked==true
        end
        for _,name in {"hold","double","third","quick","late","malformed","focus"} do
            move(actor,ground)
            ask(actor,name,"jump:"..name)
        end
        local stages=result.stages
        result.assertions.higherJump=stages.double.height>single.height+2 and stages.double.spaceEvents==2
        result.assertions.oneExtraRise=stages.double.rises==1
        result.assertions.holdBlocked=stages.hold.height<=single.height+1.5 and stages.hold.rises==0
        result.assertions.thirdBlocked=stages.third.height<=stages.double.height+1.5 and stages.third.rises==1
        result.assertions.landingRecharge=stages.quick.height>single.height+2 and stages.late.height>single.height+2
        result.assertions.malformedRejected=stages.malformed.height<=single.height+1.5
        result.assertions.focusBlocked=stages.focus.height<=single.height+1.5
        result.assertions.grass=workspace.SwitchbackWorld.DepotRoof.Material==Enum.Material.Grass
        move(actor,Vector3.new(7,12.5,6))
        local picked=ask(actor,"pickup","e")
        result.assertions.pickup=picked.snapshot.state=="Running"
        local carrying=ask(actor,"carryingJump","jump:double")
        result.assertions.poweredDelivery=carrying.height>single.height+2 and carrying.snapshot.state=="Running"
        -- Walk the original safe route using actual Humanoid movement and Q input.
        walk(actor,Vector3.new(0,12.5,3)); walk(actor,Vector3.new(0,12.5,-32))
        ask(actor,"cyanTwo","q"); walk(actor,Vector3.new(0,12.5,-58))
        walk(actor,Vector3.new(-14,12.5,-60)); walk(actor,Vector3.new(-14,12.5,-92)); walk(actor,Vector3.new(0,12.5,-92))
        ask(actor,"amberThree","q"); walk(actor,Vector3.new(0,12.5,-100))
        ask(actor,"cyanFour","q"); walk(actor,Vector3.new(0,12.5,-132))
        actor.Character.Humanoid:MoveTo(Vector3.new(0,12.5,-148))
        task.wait(1.4)
        local delivered=ask(actor,"delivered")
        result.assertions.deliveryReward=delivered.snapshot.state=="Completed" and delivered.snapshot.coins==25 and delivered.snapshot.completedRuns==1
        local old=actor.Character
        old.Humanoid.Health=0
        waitFor(function() return actor.Character~=old and actor.Character and actor.Character:FindFirstChild("HumanoidRootPart") end,9)
        task.wait(0.6)
        local respawn=ask(actor,"respawn")
        result.assertions.respawnRetention=respawn.snapshot.powerup.unlocked==true
        result.assertions.noClientErrors=#respawn.errors==0
        local all=true; for _,passed in result.assertions do all=all and passed==true end
        finish(if all then "powerups_succeeded" else "powerups_failed")
    end)
    if not ok then result.problem=tostring(problem); finish("fixture_error") end
end)
task.delay(150,function() finish("fixture_timeout") end)
