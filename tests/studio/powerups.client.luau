-- Temporary integration fixture. Uses actual keyboard input and production remotes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Run = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Log = game:GetService("LogService")
local player = Players.LocalPlayer
local probe = ReplicatedStorage:WaitForChild("__RollboxPowerupsProbe", 15)
if not probe then return end
local remotes = ReplicatedStorage:WaitForChild("Remotes", 15)
local latest, spaceEvents, crateEvents = nil, 0, 0
remotes.Snapshot.OnClientEvent:Connect(function(data) latest = data end)
UIS.InputBegan:Connect(function(input) if input.KeyCode == Enum.KeyCode.Space then spaceEvents += 1 end end)
game:GetService("ProximityPromptService").PromptTriggered:Connect(function(prompt)
    if prompt.Name == "OpenMushroomCrate" then crateEvents += 1 end
end)
local virtual = UIS:CreateVirtualInput()
local function key(code, duration)
    assert(virtual, "VirtualInput unavailable")
    virtual:SendKey(true, code, false)
    task.wait(duration or 0.04)
    virtual:SendKey(false, code, false)
end
probe.OnClientEvent:Connect(function(stage, command)
    task.spawn(function()
        local ok, value = pcall(function()
            local character = player.Character
            local root = character and character:FindFirstChild("HumanoidRootPart")
            local peak, rises, base = root and root.Position.Y or 0, 0, root and root.Position.Y or 0
            local startEvents, connection = spaceEvents, nil
            if string.sub(command,1,5) == "jump:" then
                local mode = string.sub(command,6)
                local previous = root.AssemblyLinearVelocity.Y
                connection = Run.Heartbeat:Connect(function()
                    peak = math.max(peak,root.Position.Y)
                    local velocity = root.AssemblyLinearVelocity.Y
                    if velocity-previous > 18 and root.Position.Y > base+2 then rises += 1 end
                    previous = velocity
                end)
                key(Enum.KeyCode.Space, if mode == "hold" then 0.35 else 0.04)
                if mode == "double" or mode == "third" or mode == "quick" or mode == "late" then
                    task.wait(if mode == "quick" then 0.06 elseif mode == "late" then 0.28 else 0.14)
                    key(Enum.KeyCode.Space)
                    if mode == "third" then task.wait(0.1); key(Enum.KeyCode.Space) end
                elseif mode == "lockedForge" then
                    task.wait(0.14); remotes.Intent:FireServer("DoubleJump",1000000)
                elseif mode == "malformed" then
                    task.wait(0.14); remotes.Intent:FireServer("DoubleJump",nil,"forged")
                elseif mode == "focus" then
                    task.wait(0.1)
                    local box=Instance.new("TextBox")
                    box.Size,box.Parent=UDim2.fromOffset(100,40),player.PlayerGui.CourierHUD
                    box:CaptureFocus(); key(Enum.KeyCode.Space); box:ReleaseFocus(); box:Destroy()
                end
                task.wait(1)
                connection:Disconnect()
            elseif command == "e" then key(Enum.KeyCode.E); task.wait(0.5)
            elseif command == "q" then key(Enum.KeyCode.Q); task.wait(0.55)
            else task.wait(0.4) end
            local errors = {}
            for _, row in Log:GetLogHistory() do
                if row.messageType == Enum.MessageType.MessageError and #errors < 12 then table.insert(errors,row.message) end
            end
            local hud = player.PlayerGui:FindFirstChild("CourierHUD")
            local panel = hud and hud:FindFirstChild("StatusPanel")
            return {snapshot=latest,peak=peak,base=base,height=peak-base,rises=rises,spaceEvents=spaceEvents-startEvents,
                crateEvents=crateEvents,errors=errors,ability=panel and panel.Ability.Text or "missing"}
        end)
        probe:FireServer({stage=stage,ok=ok,data=if ok then value else {problem=tostring(value)}})
    end)
end)
task.wait(1)
probe:FireServer({stage="ready",ok=true})
