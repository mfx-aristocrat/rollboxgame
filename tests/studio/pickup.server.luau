-- Studio-only fixture, injected temporarily by the test driver, never mapped by Rojo.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Test = game:GetService("StudioTestService")
local Http = game:GetService("HttpService")
local Log = game:GetService("LogService")
if not game:GetService("RunService"):IsStudio() then return end
local remote = Instance.new("RemoteEvent")
remote.Name, remote.Parent = "__RollboxPickupProbe", ReplicatedStorage
local result = { fixture = "pickup-engine-v1", intents = 0, prompts = 0, snapshots = {}, finished = false }
local function errors()
    local found = {}
    for _, row in Log:GetLogHistory() do
        if row.messageType == Enum.MessageType.MessageError and #found < 12 then table.insert(found, row.message) end
    end
    return found
end
local function finish(reason)
    if result.finished then return end
    result.finished, result.reason, result.serverErrors = true, reason, errors()
    result.worldPresent = workspace:FindFirstChild("SwitchbackWorld") ~= nil
    result.fallenPartsDestroyHeight = workspace.FallenPartsDestroyHeight
    result.remoteFolders = 0
    for _, child in ReplicatedStorage:GetChildren() do if child.Name == "Remotes" then result.remoteFolders += 1 end end
    Test:EndTest(Http:JSONEncode(result))
end
local function state(player)
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local p = root and root.Position
    return { parcel = character ~= nil and character:FindFirstChild("CourierParcel") ~= nil,
        health = humanoid and humanoid.Health or -1, position = p and { p.X, p.Y, p.Z } or {} }
end
remote.OnServerEvent:Connect(function(player, payload)
    if type(payload) ~= "table" or result.finished then return end
    if payload.kind == "ready" then
        task.spawn(function()
            local character = player.Character or player.CharacterAdded:Wait()
            local root = character:WaitForChild("HumanoidRootPart", 8)
            if not root then finish("no_character"); return end
            character:PivotTo(CFrame.lookAt(Vector3.new(7, 12, 6), Vector3.new(7, 12, 0)))
            root.AssemblyLinearVelocity = Vector3.zero
            task.wait(0.8)
            result.before = state(player)
            remote:FireClient(player, "press_e")
        end)
    elseif payload.kind == "report" then
        result.client = payload.data
        result.immediate = state(player)
        task.delay(1.2, function()
            result.delayed = state(player)
            finish(if result.delayed.parcel then "pickup_succeeded" else "pickup_failed")
        end)
    end
end)
task.spawn(function()
    local remotes = ReplicatedStorage:WaitForChild("Remotes", 12)
    if remotes then
        local intent = remotes:WaitForChild("Intent", 3)
        if intent then intent.OnServerEvent:Connect(function(_, action) if action == "Start" or action == "Retry" then result.intents += 1 end end) end
    end
    local world = workspace:FindFirstChild("SwitchbackWorld")
    local depot = world and world:FindFirstChild("ParcelDepot")
    local prompt = depot and depot:FindFirstChild("TakeParcel")
    if prompt then prompt.Triggered:Connect(function() result.prompts += 1 end) end
end)
task.delay(24, function() finish("fixture_timeout") end)
