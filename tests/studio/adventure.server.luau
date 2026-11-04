-- Tests actual server sampling, native crate prompt, physics and character lifecycle.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Test = game:GetService("StudioTestService")
local Log = game:GetService("LogService")
local Http = game:GetService("HttpService")
if not game:GetService("RunService"):IsStudio() then return end
local probe = Instance.new("RemoteEvent")
probe.Name, probe.Parent = "__RollboxAdventureProbe", ReplicatedStorage
local result = { fixture = "adventure-engine-v1", assertions = {}, finished = false }
local reports, activePlayer = {}, nil
probe.OnServerEvent:Connect(function(player, payload)
    if type(payload) == "table" and type(payload.stage) == "string" then reports[payload.stage], activePlayer = payload, player end
end)
local function finish(reason)
    if result.finished then return end
    result.finished, result.reason = true, reason
    result.serverErrors = {}
    for _, row in Log:GetLogHistory() do
        if row.messageType == Enum.MessageType.MessageError and #result.serverErrors < 12 then table.insert(result.serverErrors, row.message) end
    end
    Test:EndTest(Http:JSONEncode(result))
end
local function waitFor(fn, seconds)
    local deadline = os.clock() + seconds
    repeat
        local value = fn()
        if value then return value end
        task.wait(0.05)
    until os.clock() >= deadline
    error("Fixture condition timed out")
end
local function ask(stage, pressE)
    probe:FireClient(activePlayer, stage, pressE == true)
    return waitFor(function() return reports[stage] end, 4)
end
local function move(character, at)
    character:PivotTo(CFrame.lookAt(at, at + Vector3.new(0, 0, -1)))
    character.HumanoidRootPart.AssemblyLinearVelocity = Vector3.zero
    task.wait(0.4)
end
task.spawn(function()
    local ok, problem = pcall(function()
        waitFor(function() return reports.ready and activePlayer end, 12)
        local character = waitFor(function() return activePlayer.Character end, 5)
        local outfit = waitFor(function() return character:FindFirstChild("CourierOutfit") end, 8)
        local safe, pieces = true, 0
        for _, part in outfit:GetDescendants() do
            if part:IsA("BasePart") then
                pieces += 1
                safe = safe and not part.Anchored and not part.CanCollide and part.Massless
            end
        end
        result.assertions.outfit = outfit:FindFirstChild("RedCapCrown") ~= nil and outfit:FindFirstChild("OverallBib") ~= nil and pieces >= 20
        result.assertions.outfitPhysics = safe
        result.outfitParts = pieces
        local config = require(ReplicatedStorage.Shared.Config)
        local layout = require(ReplicatedStorage.Shared.AdventureLayout).create(config)
        result.assertions.world = workspace.SwitchbackWorld:FindFirstChild("PlatformerAdventure") ~= nil
        -- Query each real collidable floor separately so a winning ray cannot hide
        -- a second, coplanar material. Camera motion made these ties flicker.
        local floorParts = {}
        for _, item in workspace.SwitchbackWorld:GetDescendants() do
            if item:IsA("BasePart") and item.CanCollide then table.insert(floorParts, item) end
        end
        local floorSamples, separated = {}, true
        for _, point in { {-18.5,4}, {18.5,4}, {-10,8}, {290,550}, {390,700}, {176,790}, {338.5,210.46}, {-275,427.5} } do
            local hits = {}
            for _, part in floorParts do
                local params = RaycastParams.new()
                params.FilterType = Enum.RaycastFilterType.Include
                params.FilterDescendantsInstances = {part}
                local hit = workspace:Raycast(Vector3.new(point[1], 200, point[2]), Vector3.new(0,-400,0), params)
                if hit and hit.Normal.Y > 0.9 then
                    table.insert(hits, {name=part.Name, y=hit.Position.Y, material=tostring(part.Material),
                        color={part.Color.R,part.Color.G,part.Color.B}})
                end
            end
            table.sort(hits, function(a,b) return a.y > b.y end)
            local gap = 999
            if hits[1] then
                for index=2,#hits do
                    local a,b=hits[1],hits[index]
                    if a.material ~= b.material or a.color[1] ~= b.color[1] or a.color[2] ~= b.color[2] or a.color[3] ~= b.color[3] then
                        gap = a.y-b.y
                        break
                    end
                end
            end
            separated = separated and hits[1] ~= nil and gap >= 0.08
            table.insert(floorSamples, {x=point[1],z=point[2],gap=gap,top=hits[1] and hits[1].name})
        end
        result.floorSamples = floorSamples
        result.assertions.floorLayersSeparated = separated
        result.assertions.catalog = #layout.items == 40 and #layout.springs == 4
        local token, crate = layout.items[1], nil
        for _, spec in layout.items do if spec.kind == "crate" then crate = spec; break end end
        local at = Vector3.new(table.unpack(token.position))
        move(character, at + Vector3.new(8, 0, 0))
        character.Humanoid:MoveTo(at)
        result.tokenStart = {character.HumanoidRootPart.Position.X, character.HumanoidRootPart.Position.Y, character.HumanoidRootPart.Position.Z}
        waitFor(function() return (character.HumanoidRootPart.Position - at).Magnitude < 4 end, 6)
        task.wait(0.5)
        local first = ask("token")
        result.tokenSnapshot, result.duplicateSnapshot = first.snapshot.adventure, nil
        result.assertions.walkCollection = first.snapshot.adventure.collected >= 1 and first.snapshot.adventure.score >= 1
        result.assertions.hud = string.find(first.expedition, "EXPLORE") ~= nil
        local duplicate = ask("duplicate")
        result.duplicateSnapshot = duplicate.snapshot.adventure
        result.assertions.tokenOnce = first.snapshot.adventure.score == duplicate.snapshot.adventure.score
        local far = ask("far", true)
        result.assertions.farCrate = far.snapshot.adventure.score == duplicate.snapshot.adventure.score
        local crateAt = Vector3.new(table.unpack(crate.position))
        move(character, crateAt + Vector3.new(0, 1, 5))
        local opened = ask("crate", true)
        result.assertions.cratePrompt = opened.inputOk and opened.promptEvents >= 1
        result.assertions.crateReward = opened.snapshot.adventure.score == far.snapshot.adventure.score + crate.score
        local again = ask("crateAgain", true)
        result.assertions.crateOnce = again.snapshot.adventure.score == opened.snapshot.adventure.score
        result.assertions.deliveryEconomy = again.snapshot.coins == 0 and again.snapshot.completedRuns == 0
        local spring = Vector3.new(table.unpack(layout.springs[1].position))
        move(character, spring + Vector3.new(0, 3.6, 0))
        local highest, up = character.HumanoidRootPart.Position.Y, character.HumanoidRootPart.AssemblyLinearVelocity.Y
        for _ = 1, 12 do
            highest = math.max(highest, character.HumanoidRootPart.Position.Y)
            up = math.max(up, character.HumanoidRootPart.AssemblyLinearVelocity.Y)
            task.wait(0.05)
        end
        result.springMaxY, result.springUpSpeed = highest, up
        result.assertions.springMotion = highest > spring.Y + 8 and up > 20
        move(character, Vector3.new(7, 12, 6))
        local picked = ask("pickup", true)
        result.assertions.pickup = picked.snapshot.state == "Running" and character:FindFirstChild("CourierParcel") ~= nil
        local previousCharacter = character
        character.Humanoid.Health = 0
        character = waitFor(function() return activePlayer.Character ~= previousCharacter and activePlayer.Character end, 9)
        waitFor(function() return character:FindFirstChild("CourierOutfit") end, 5)
        local respawned = ask("respawn")
        result.assertions.respawn = character:FindFirstChild("CourierOutfit") ~= nil and respawned.snapshot.state ~= "Running"
        result.assertions.respawnCollection = respawned.snapshot.adventure.score == again.snapshot.adventure.score
        result.assertions.noClientErrors = #respawned.errors == 0
        result.client = { errors = respawned.errors, expedition = respawned.expedition }
        result.score = respawned.snapshot.adventure.score
        local all = true
        for _, passed in result.assertions do all = all and passed == true end
        finish(if all then "adventure_succeeded" else "adventure_failed")
    end)
    if not ok then result.problem = tostring(problem); finish("fixture_error") end
end)
task.delay(40, function() finish("fixture_timeout") end)
