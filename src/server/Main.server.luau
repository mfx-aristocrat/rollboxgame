local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")
local HttpService = game:GetService("HttpService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Rules = require(Shared.RunRules)
local Progression = require(Shared.Progression)
local Profile = require(Shared.Profile)
local codec = Profile.createCodec(Config)
local Settings = require(script.Parent.ServerSettings)
local Persistence = require(script.Parent.Persistence)
local persistence, configurationError
if Settings.persistenceEnabled then
    local environment = Settings.dataEnvironment
    local expected = if environment == "test" then Settings.testUniverseId elseif environment == "production" then Settings.productionUniverseId else 0
    if expected == 0 or game.GameId ~= expected or Settings.testUniverseId == Settings.productionUniverseId then
        configurationError = "Verify distinct universe IDs and the test/production data environment."
        warn(configurationError)
    else
        local store = game:GetService("DataStoreService"):GetDataStore(Persistence.storeName(environment))
        persistence = Persistence.new({
            environment = environment, profile = codec, now = os.time, sleep = task.wait,
            makeToken = function() return HttpService:GenerateGUID(false) end,
            update = function(key, transform) return store:UpdateAsync(key, transform) end,
        })
    end
end
local playerData = require(script.Parent.PlayerData).new(Settings, codec, {
    persistence = persistence, configurationError = configurationError,
    scheduler = task, clock = os, warn = warn,
})
local world = require(script.Parent.World).build(Config)
local adventure = require(script.Parent.Adventure).new(world.adventure, Config)
local powerups
local CourierAppearance = require(script.Parent.CourierAppearance)

local remotes = Instance.new("Folder")
remotes.Name, remotes.Parent = "Remotes", ReplicatedStorage
local intent = Instance.new("RemoteEvent")
intent.Name, intent.Parent = "Intent", remotes
local snapshot = Instance.new("RemoteEvent")
snapshot.Name, snapshot.Parent = "Snapshot", remotes
local jumpApproval=Instance.new("RemoteEvent")
jumpApproval.Name,jumpApproval.Parent="JumpApproval",remotes
powerups=require(script.Parent.Powerups).new(world.powerups,require(Shared.PowerupConfig),{
    notify=function(player,data) jumpApproval:FireClient(player,data) end,
})
local sessions = {}
local function vector(array) return Vector3.new(table.unpack(array)) end
local function array(v) return { v.X, v.Y, v.Z } end
local function nearPickup(root)
    return root ~= nil and (root.Position - vector(Config.pickup.position)).Magnitude <= Config.pickup.radius
end
local function alive(player)
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if humanoid and humanoid.Health > 0 and root then return character, root end
    return nil, nil
end
pcall(function() PhysicsService:RegisterCollisionGroup("Couriers") end)
PhysicsService:CollisionGroupSetCollidable("Couriers", "Couriers", false)

local function send(player)
    local session = sessions[player]
    if not session then return end
    local now, run, data = os.clock(), session.run, session.data.profile
    session.profile = data
    local _, root = alive(player)
    local nextGate = if run then run.nextGate else 1
    local gate = Config.route.gates[nextGate]
    snapshot:FireClient(player, {
        mode = session.data.mode, persistence = session.data.message,
        state = if run then run.state else "Idle", message = session.message,
        coins = data.coins, completedRuns = data.completedRuns, tutorialComplete = data.tutorialComplete,
        equippedCosmetic = data.equippedCosmetic, ownsMint = data.cosmetics.mint == true,
        polarity = if run then run.polarity else "Amber", nextGate = nextGate, gateCount = #Config.route.gates,
        nextPolarity = if gate then gate.polarity else "Deliver", elapsed = if run then (run.resultTime or Rules.elapsed(run, now)) else 0,
        cooldownRemaining = if run then math.max(0, Config.switchCooldown - (now - run.lastSwitchAt)) else 0,
        bestTime = data.bestTimes.training, resultTime = run and run.resultTime,
        routeId = "training", routeName = "Training",
        nextUnlock = "More routes planned after playtesting",
        nearDepot = root ~= nil and (root.Position - vector(Config.route.depot)).Magnitude <= Config.depotRadius,
        nearPickup = nearPickup(root), carryingParcel = run ~= nil and run.state == "Running",
        adventure = adventure:snapshot(player),
        powerup = powerups:snapshot(player),
    })
end
local function parcel(player)
    local session, character = sessions[player], player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not session or not root then return end
    local old = character:FindFirstChild("CourierParcel")
    if not session.run or session.run.state ~= "Running" then
        if old then old:Destroy() end
        return
    end
    local item = old
    if not item then
        item = Instance.new("Part")
        item.Name, item.Size = "CourierParcel", Vector3.new(2.2, 2.2, 1.2)
        item.CanCollide, item.CanTouch, item.CanQuery, item.Massless = false, false, false, true
        -- Roblox characters face local -Z. Keep the parcel visible in front.
        item.CFrame = root.CFrame * CFrame.new(0, -0.25, -2)
        item.Parent = character
        local weld = Instance.new("WeldConstraint")
        weld.Part0, weld.Part1, weld.Parent = root, item, item
    end
    local shell = if session.profile.equippedCosmetic == "mint" then "mint" else "default"
    item.Color = Color3.fromRGB(table.unpack(Config.colors[shell]))
    -- Polarity uses a separate glow marker so cosmetic shell never hides its state.
    local marker = item:FindFirstChild("Polarity")
    if not marker then
        marker = Instance.new("PointLight")
        marker.Name, marker.Range, marker.Brightness, marker.Parent = "Polarity", 8, 1, item
    end
    marker.Color = Color3.fromRGB(table.unpack(Config.colors[session.run.polarity]))
end
local function teleport(player, position)
    local session = sessions[player]
    local character, root = alive(player)
    if not session or not character then return end
    character:PivotTo(CFrame.new(position) * CFrame.Angles(0, 0, 0))
    root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
    powerups:resetAir(player)
    session.previous, session.previousAt = array(root.Position), os.clock()
end
local function recover(player, message)
    local session = sessions[player]
    if not session or not session.run then return end
    local checkpoint = session.run.checkpoint
    local position = if checkpoint == 0 then Config.route.depot else Config.route.gates[checkpoint].checkpoint
    teleport(player, vector(position))
    session.message = message
    send(player)
end
local function abort(player, message)
    local session = sessions[player]
    if not session then return end
    Rules.abort(session.run)
    session.run = nil
    session.message = message
    parcel(player)
    send(player)
end
local function handle(player, action, ...)
    local session = sessions[player]
    if not session then return end
    local argumentCount, argument = select("#", ...), ...
    local now = os.clock()
    if not Rules.admitIntent(session.limiter, action, argument, now) then return end
    if action == "DoubleJump" then
        if argumentCount ~= 1 or type(argument)~="number" or argument~=argument or argument%1~=0 or argument<1 or argument>1e9 then return end
        local ok,approval=powerups:requestJump(player,now,argument)
        if ok then jumpApproval:FireClient(player,approval) end
        send(player)
        return
    end
    if action == "Snapshot" then send(player); return end
    if not playerData.canWrite(player.UserId) then
        session.message = session.data.message
        send(player)
        return
    end
    session.profile = session.data.profile
    local _, root = alive(player)
    if not root then
        session.message = "Wait for your character to respawn, then take a parcel."
        send(player)
        return
    end
    if action == "Start" or action == "Retry" then
        if session.run and session.run.state == "Running" then
            session.message = "Already carrying a parcel. Continue to the next gate."
            parcel(player)
            send(player)
            return
        end
        if not nearPickup(root) then
            session.message = "Move closer to the parcel box at the depot, then press E or Take parcel."
            send(player)
            return
        end
        session.run = Rules.start(now, HttpService:GenerateGUID(false))
        session.previous, session.previousAt = array(root.Position), now
        session.message = "Parcel picked up! Carry it through gate 1: A / SUN."
    elseif action == "Switch" then
        if Rules.toggle(session.run, now, Config) then
            session.message = "Parcel set to " .. session.run.polarity .. ". Match the next gate."
        end
    elseif action == "BuyMint" then
        local ok, why = Progression.buyMint(session.profile, Config)
        if ok then playerData.changed(player.UserId) end
        session.message = if ok then "Mint unlocked! Equip it below." elseif why == "already_owned" then "Mint is already yours." else "Mint costs 50 coins. Deliver twice to earn it."
    elseif action == "EquipMint" or action == "EquipDefault" then
        local id = if action == "EquipMint" then "mint" else "default"
        if Progression.equip(session.profile, id) then
            playerData.changed(player.UserId)
            session.message = "Equipped " .. id .. " parcel shell."
        end
    end
    parcel(player)
    send(player)
end
intent.OnServerEvent:Connect(handle)
world.prompt.Triggered:Connect(function(player) handle(player, "Start", nil) end)

local function joined(player)
    if sessions[player] then return end
    local data = playerData.open(player.UserId)
    if not data then player:Kick("Previous save session is closing. Please rejoin shortly."); return end
    sessions[player] = { data = data, profile = data.profile, limiter = Rules.newLimiter(os.clock()), message = "Take a parcel at the depot. Match each gate using Q or Switch." }
    adventure:add(player)
    powerups:add(player)
    local function characterAdded(character)
        powerups:resetAir(player)
        abort(player, "Take a parcel at the depot. Resets cancel the delivery; earned coins stay.")
        local function setCollision(item)
            if item:IsA("BasePart") then item.CollisionGroup = "Couriers" end
        end
        for _, item in character:GetDescendants() do setCollision(item) end
        local session = sessions[player]
        if session.descendantConnection then session.descendantConnection:Disconnect() end
        session.descendantConnection = character.DescendantAdded:Connect(setCollision)
        task.spawn(function()
            local humanoid = character:WaitForChild("Humanoid", 10)
            if humanoid and sessions[player] == session then
                CourierAppearance.apply(character)
                if session.deathConnection then session.deathConnection:Disconnect() end
                session.deathConnection = humanoid.Died:Connect(function()
                    powerups:resetAir(player)
                    abort(player, "Delivery cancelled. Restart free at the depot.")
                end)
            end
        end)
    end
    sessions[player].characterConnection = player.CharacterAdded:Connect(characterAdded)
    sessions[player].appearanceConnection = player.CharacterAppearanceLoaded:Connect(function(character)
        if player.Character == character and sessions[player] then CourierAppearance.apply(character) end
    end)
    if player.Character then characterAdded(player.Character) end
end
Players.PlayerAdded:Connect(joined)
Players.PlayerRemoving:Connect(function(player)
    local session = sessions[player]
    if session then
        for _, key in { "characterConnection", "appearanceConnection", "deathConnection", "descendantConnection" } do
            if session[key] then session[key]:Disconnect() end
        end
        sessions[player] = nil
        adventure:remove(player)
        powerups:remove(player)
        playerData.close(player.UserId, os.time() + 20)
    end
end)
for _, player in Players:GetPlayers() do joined(player) end
game:BindToClose(function() adventure:destroy(); powerups:destroy(); playerData.shutdown() end)

local sampleAccumulator, snapshotAccumulator = 0, 0
RunService.Heartbeat:Connect(function(dt)
    sampleAccumulator += dt
    snapshotAccumulator += dt
    local sample, broadcast = sampleAccumulator >= Config.sampleSeconds, snapshotAccumulator >= Config.snapshotSeconds
    if sample then sampleAccumulator = 0 end
    if broadcast then snapshotAccumulator = 0 end
    if sample then playerData.tick() end
    local now = os.clock()
    for player, session in pairs(sessions) do
        local run = session.run
        local _, root = alive(player)
        if sample then powerups:step(player, now) end
        if sample then adventure:step(player, root, root ~= nil, run ~= nil and run.state == "Running", now) end
        if sample and root and run and run.state == "Running" and not playerData.canWrite(player.UserId) then
            abort(player, session.data.message)
        elseif sample and root and run and run.state == "Running" then
            local current = array(root.Position)
            if not Rules.active(run, now, Config) then
                abort(player, "Delivery time limit reached. Retry free at the depot.")
                teleport(player, vector(Config.route.depot))
            elseif root.Position.Y < Config.fallY then
                recover(player, "Safe recovery — your timer continues. Try the left path.")
            elseif session.previous and not Rules.validMovement(session.previous, current, now - session.previousAt, Config) then
                abort(player, "Run reset after an unexpected movement. Please retry.")
                teleport(player, vector(Config.route.depot))
            else
                local gate = Config.route.gates[run.nextGate]
                if gate and session.previous and Rules.crossedGate(session.previous, current, gate) then
                    local ok, why = Rules.gate(run, run.nextGate, now, Config)
                    if ok then
                        session.message = if run.nextGate > #Config.route.gates then "All gates matched. Reach the green delivery pad!" else "Gate cleared. Next: " .. Config.route.gates[run.nextGate].polarity .. "."
                    elseif why == "wrong_polarity" then
                        recover(player, "Wrong polarity. Switch to " .. gate.polarity .. " and try again.")
                        current = session.previous
                    else
                        abort(player, "Run validation failed. Retry free at the depot.")
                        teleport(player, vector(Config.route.depot))
                        current = session.previous
                    end
                elseif gate and current[3] < gate.position[3] - 5 then
                    recover(player, "Pass through the next numbered gate — no skipping.")
                    current = session.previous
                end
                if run.state == "Running" and not gate and (root.Position - vector(Config.route.destination)).Magnitude <= 9 then
                    if Rules.finish(run, now, Config) and Progression.reward(session.profile, run, Config) then
                        playerData.changed(player.UserId)
                        session.message = "Delivered! +25 coins. Retry for a faster time or earn Mint."
                        parcel(player)
                        teleport(player, vector(Config.route.depot))
                        current = session.previous
                    end
                end
                session.previous, session.previousAt = current, now
            end
        end
        if broadcast then send(player) end
    end
end)
