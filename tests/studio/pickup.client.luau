-- Real client/VirtualInput integration fixture. Never part of the shipped project.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local Log = game:GetService("LogService")
local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("__RollboxPickupProbe", 12)
if not remote then return end
local evidence = { eEvents = 0, promptEvents = 0, promptShown = 0 }
UIS.InputBegan:Connect(function(input, processed)
    if input.KeyCode == Enum.KeyCode.E then evidence.eEvents += 1; evidence.processed = processed end
end)
game:GetService("ProximityPromptService").PromptShown:Connect(function(prompt)
    if prompt.Name == "TakeParcel" then evidence.promptShown += 1 end
end)
game:GetService("ProximityPromptService").PromptTriggered:Connect(function(prompt)
    if prompt.Name == "TakeParcel" then evidence.promptEvents += 1 end
end)
local remotes = ReplicatedStorage:WaitForChild("Remotes", 8)
if remotes and remotes:FindFirstChild("Snapshot") then
    remotes.Snapshot.OnClientEvent:Connect(function(data)
        evidence.snapshot = { state = data.state, message = data.message, nearPickup = data.nearPickup, mode = data.mode }
    end)
end
remote.OnClientEvent:Connect(function(command)
    if command ~= "press_e" then return end
    local focused = UIS:GetFocusedTextBox()
    evidence.focusedTextBox = focused and focused:GetFullName() or "none"
    local inputOk, inputError = pcall(function()
        local virtual = UIS:CreateVirtualInput()
        assert(virtual, "CreateVirtualInput unavailable")
        virtual:SendKey(true, Enum.KeyCode.E, false)
        task.wait(0.15)
        virtual:SendKey(false, Enum.KeyCode.E, false)
    end)
    evidence.inputOk, evidence.inputError = inputOk, if inputOk then nil else tostring(inputError)
    task.wait(1.2)
    local gui = player.PlayerGui:FindFirstChild("CourierHUD")
    local status = gui and gui:FindFirstChild("StatusPanel")
    evidence.guiPresent = gui ~= nil
    evidence.routeText = status and status:FindFirstChild("Route") and status.Route.Text or "missing"
    evidence.message = status and status:FindFirstChild("Message") and status.Message.Text or "missing"
    evidence.clientErrors = {}
    for _, row in Log:GetLogHistory() do
        if row.messageType == Enum.MessageType.MessageError and #evidence.clientErrors < 12 then table.insert(evidence.clientErrors, row.message) end
    end
    remote:FireServer({ kind = "report", data = evidence })
end)
task.wait(2)
remote:FireServer({ kind = "ready" })
