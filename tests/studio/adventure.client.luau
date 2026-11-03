-- Temporary engine regression fixture, excluded from the Rojo product build.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local Log = game:GetService("LogService")
local player = Players.LocalPlayer
local probe = ReplicatedStorage:WaitForChild("__RollboxAdventureProbe", 12)
if not probe then return end
local snapshot = ReplicatedStorage:WaitForChild("Remotes", 12):WaitForChild("Snapshot", 5)
local latest, promptEvents = nil, 0
snapshot.OnClientEvent:Connect(function(data) latest = data end)
game:GetService("ProximityPromptService").PromptTriggered:Connect(function(prompt)
    if prompt.Name == "OpenBonusCrate" then promptEvents += 1 end
end)
probe.OnClientEvent:Connect(function(stage, pressE)
    task.spawn(function()
        local inputOk = true
        if pressE then
            inputOk = pcall(function()
                local input = UIS:CreateVirtualInput()
                assert(input, "No virtual input")
                input:SendKey(true, Enum.KeyCode.E, false)
                task.wait(0.12)
                input:SendKey(false, Enum.KeyCode.E, false)
            end)
        end
        task.wait(0.5)
        local gui = player.PlayerGui:FindFirstChild("CourierHUD")
        local panel = gui and gui:FindFirstChild("StatusPanel")
        local errors = {}
        for _, row in Log:GetLogHistory() do
            if row.messageType == Enum.MessageType.MessageError and #errors < 12 then table.insert(errors, row.message) end
        end
        probe:FireServer({ stage = stage, snapshot = latest, inputOk = inputOk,
            promptEvents = promptEvents, errors = errors,
            expedition = panel and panel:FindFirstChild("Expedition") and panel.Expedition.Text or "missing" })
    end)
end)
probe:FireServer({ stage = "ready" })
