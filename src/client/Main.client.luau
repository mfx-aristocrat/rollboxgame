local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local intent, snapshot = remotes:WaitForChild("Intent"), remotes:WaitForChild("Snapshot")
local screen = Instance.new("ScreenGui")
screen.Name, screen.ResetOnSpawn, screen.ZIndexBehavior = "CourierHUD", false, Enum.ZIndexBehavior.Sibling
screen.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
screen.Parent = player:WaitForChild("PlayerGui")
local ink = Color3.fromRGB(19, 29, 47)
local white, muted = Color3.fromRGB(241, 246, 255), Color3.fromRGB(185, 201, 224)
local mint, amber, cyan = Color3.fromRGB(114, 245, 182), Color3.fromRGB(255, 182, 64), Color3.fromRGB(63, 219, 240)
local gold = Color3.fromRGB(255, 217, 88)
local function round(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius, c.Parent = UDim.new(0, radius or 12), parent
end
local function text(parent, name, y, height, size, color)
    local label = Instance.new("TextLabel")
    label.Name, label.BackgroundTransparency = name, 1
    label.Position, label.Size = UDim2.new(0, 14, 0, y), UDim2.new(1, -28, 0, height)
    label.TextSize, label.TextColor3, label.Font = size, color or white, Enum.Font.GothamMedium
    label.TextXAlignment, label.TextWrapped = Enum.TextXAlignment.Left, true
    label.Text, label.Parent = "", parent
    return label
end
local function button(parent, name, caption, position, size, color, action)
    local b = Instance.new("TextButton")
    b.Name, b.Text, b.Position, b.Size = name, caption, position, size
    b.BackgroundColor3, b.TextColor3, b.Font, b.TextSize = color or mint, ink, Enum.Font.GothamBold, 16
    b.TextWrapped, b.AutoButtonColor, b.Parent = true, true, parent
    round(b)
    b.Activated:Connect(action)
    return b
end
local hud = Instance.new("Frame")
hud.Name, hud.AnchorPoint = "StatusPanel", Vector2.new(0.5, 0)
hud.Position, hud.Size = UDim2.new(0.5, 0, 0, 8), UDim2.new(0.94, 0, 0, 204)
hud.BackgroundColor3, hud.BackgroundTransparency, hud.Parent = ink, 0.06, screen
round(hud, 16)
local outline = Instance.new("UIStroke")
outline.Color, outline.Thickness, outline.Transparency, outline.Parent = gold, 2, 0.2, hud
local limit = Instance.new("UISizeConstraint")
limit.MaxSize, limit.Parent = Vector2.new(620, 204), hud
local title = text(hud, "Title", 8, 24, 18, gold)
title.Text = "SWITCHBACK COURIERS"
local status = text(hud, "Route", 35, 26, 17)
status.Text = "Connecting to the delivery depot…"
local goal = text(hud, "Goal", 62, 25, 16)
local message = text(hud, "Message", 89, 39, 14, white)
local expedition = text(hud, "Expedition", 130, 23, 14, gold)
expedition.Text = "EXPLORE • Follow the golden trails beyond the depot"
local ability = text(hud, "Ability", 154, 20, 13, mint)
ability.Text = "MUSHROOM • Find the crate on the west trail"
local saving = text(hud, "Saving", 178, 18, 11, muted)
saving.Text = "Practice • Session progress is not saved"

local actions = Instance.new("Frame")
actions.Name, actions.BackgroundTransparency, actions.AnchorPoint = "Actions", 1, Vector2.new(0.5, 1)
actions.Position, actions.Size, actions.Parent = UDim2.new(0.5, 0, 1, -24), UDim2.fromOffset(300, 68), screen
local latest
local function takeParcel()
    intent:FireServer(if latest and latest.state == "Completed" then "Retry" else "Start")
end
local start = button(actions, "Start", "Take parcel", UDim2.fromOffset(80, 0), UDim2.fromOffset(140, 68), mint, function()
    takeParcel()
end)
local switch = button(actions, "Switch", "Switch [Q]", UDim2.fromOffset(76, 0), UDim2.fromOffset(148, 68), amber, function()
    intent:FireServer("Switch")
end)
local modal = Instance.new("Frame")
modal.Name, modal.Size, modal.BackgroundColor3 = "ShellModal", UDim2.fromScale(1, 1), ink
modal.BackgroundTransparency, modal.Visible, modal.Active, modal.ZIndex, modal.Parent = 0.15, false, true, 20, screen
local setShop
local shop = Instance.new("Frame")
shop.Name, shop.AnchorPoint = "Shells", Vector2.new(0.5, 0.5)
shop.Position, shop.Size = UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(316, 230)
shop.BackgroundColor3, shop.Parent = ink, modal
round(shop, 16)
text(shop, "Title", 12, 30, 21, mint).Text = "Your parcel shells"
local shopStatus = text(shop, "Balance", 47, 44, 15)
local mintButton = button(shop, "Mint", "Mint • 50 coins", UDim2.fromOffset(14, 102), UDim2.fromOffset(288, 48), mint, function()
    if latest then intent:FireServer(if latest.ownsMint then "EquipMint" else "BuyMint") end
end)
button(shop, "Default", "Equip default", UDim2.fromOffset(14, 164), UDim2.fromOffset(164, 48), white, function()
    intent:FireServer("EquipDefault")
end)
button(shop, "Close", "Close", UDim2.fromOffset(190, 164), UDim2.fromOffset(112, 48), muted, function() setShop(false) end)
local shells = button(screen, "OpenShells", "Shells", UDim2.new(0.5, -62, 1, -138), UDim2.fromOffset(124, 46), white, function()
    setShop(not modal.Visible)
end)
shells.Visible = false
setShop = function(open)
    modal.Visible, hud.Visible, actions.Visible = open, not open, not open
    shells.Visible = not open and latest ~= nil and latest.tutorialComplete == true
end
local function layout()
    local camera = workspace.CurrentCamera
    local compact = camera and camera.ViewportSize.Y < 500
    local portrait = camera and camera.ViewportSize.Y > camera.ViewportSize.X
    title.Visible = not compact
    hud.Size = UDim2.new(0.94, 0, 0, if compact then 148 else 204)
    status.Position, status.TextSize = UDim2.new(0, 14, 0, if compact then 3 else 35), if compact then 14 else 17
    goal.Position, goal.TextSize = UDim2.new(0, 14, 0, if compact then 26 else 62), if compact then 14 else 16
    message.Position, message.Size, message.TextSize = UDim2.new(0, 14, 0, if compact then 52 else 89), UDim2.new(1, -28, 0, if compact then 29 else 39), if compact then 12 else 14
    expedition.Position, expedition.Size = UDim2.new(0, 14, 0, if compact then 83 else 130), UDim2.new(1, -28, 0, if compact then 18 else 23)
    expedition.TextSize = if compact or (camera and camera.ViewportSize.X < 420) then 12 else 14
    ability.Position, ability.TextSize = UDim2.new(0, 14, 0, if compact then 104 else 154), if compact then 11 else 13
    saving.Position, saving.TextSize = UDim2.new(0, 14, 0, if compact then 127 else 178), if compact then 10 else 11
    -- One centered action; portrait lifts it above the default thumbstick/jump row.
    actions.Position = UDim2.new(0.5, 0, 1, if portrait then -120 elseif compact then -12 else -24)
    shells.Position = UDim2.new(1, -138, 0, if compact then 164 else 220)
end
local viewportConnection
local function watchCamera()
    if viewportConnection then viewportConnection:Disconnect() end
    if workspace.CurrentCamera then viewportConnection = workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layout) end
    layout()
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
watchCamera()
local collectedIds, adventureVisuals, powerupVisuals = {}, {}, {}
local function showCollected(item)
    local id = item:GetAttribute("AdventureId")
    if not id and item.Parent then id = item.Parent:GetAttribute("AdventureId") end
    if not id then return end
    if item:IsA("BasePart") then
        item.LocalTransparencyModifier = if collectedIds[id] then 0.8 else 0
    elseif item:IsA("ProximityPrompt") or item:IsA("BillboardGui") then
        item.Enabled = not collectedIds[id]
    end
end
task.spawn(function()
    local world = workspace:WaitForChild("SwitchbackWorld", 15)
    local adventure = world and world:WaitForChild("PlatformerAdventure", 15)
    if not adventure then return end
    local function index(item)
        local id = item:GetAttribute("AdventureId")
        if not id and item.Parent then id = item.Parent:GetAttribute("AdventureId") end
        if id then table.insert(adventureVisuals, item); showCollected(item) end
    end
    adventure.DescendantAdded:Connect(index)
    for _, item in adventure:GetDescendants() do index(item) end
end)
task.spawn(function()
    local world = workspace:WaitForChild("SwitchbackWorld", 15)
    local mushroom = world and world:WaitForChild("MushroomPowerup", 15)
    if not mushroom then return end
    local function index(item)
        if item:GetAttribute("PowerupId") then table.insert(powerupVisuals, item) end
    end
    mushroom.DescendantAdded:Connect(index)
    for _, item in mushroom:GetDescendants() do index(item) end
end)
local function seconds(value)
    return if type(value) == "number" then string.format("%.1fs", value) else "—"
end
snapshot.OnClientEvent:Connect(function(data)
    if type(data) ~= "table" then return end
    latest = data
    local running = data.state == "Running"
    status.Text = if running then string.format("CARRYING PARCEL • %d coins", data.coins)
        else string.format("%s • %d coins • %d deliveries", data.routeName, data.coins, data.completedRuns)
    if running then
        local symbol = if data.polarity == "Amber" then "A / SUN" else "C / MOON"
        goal.Text = if data.nextGate <= data.gateCount then string.format("%s → Gate %d: %s   |   %s", symbol, data.nextGate, data.nextPolarity, seconds(data.elapsed)) else "All gates cleared → Green delivery pad!  " .. seconds(data.elapsed)
    elseif data.state == "Completed" then
        goal.Text = "Delivered in " .. seconds(data.resultTime) .. "  •  Best " .. seconds(data.bestTime)
    else
        goal.Text = "Go to the parcel box. Press E or tap Take parcel."
    end
    message.Text, saving.Text = data.message, data.mode .. " • " .. data.persistence
    local powerup = data.powerup
    local unlocked = type(powerup) == "table" and powerup.unlocked == true
    local preferred = UserInputService.PreferredInput
    local jumpHint = if preferred == Enum.PreferredInput.Touch then "Tap jump twice" elseif preferred == Enum.PreferredInput.Gamepad then "Press jump twice" else "Press Space twice"
    ability.Text = if unlocked then "DOUBLE JUMP • " .. jumpHint else "MUSHROOM • Find the crate on the west trail"
    ability.TextColor3 = if unlocked then mint else muted
    for _, item in powerupVisuals do
        if item.Parent then
            if item:IsA("ProximityPrompt") then item.Enabled = not unlocked
            elseif item:IsA("BasePart") then item.LocalTransparencyModifier = if unlocked then 0.55 else 0 end
        end
    end
    local exploration = data.adventure
    if type(exploration) == "table" then
        expedition.Text = string.format("EXPLORE %d/%d  |  %d session pts  |  %d/6 flags", exploration.collected, exploration.total, exploration.score, exploration.landmarks)
        if not running and exploration.message and exploration.message ~= "" then message.Text = exploration.message end
        collectedIds = {}
        for _, id in exploration.collectedIds or {} do collectedIds[id] = true end
        for _, item in adventureVisuals do if item.Parent then showCollected(item) end end
    end
    goal.TextColor3 = if data.polarity == "Cyan" then cyan else amber
    start.Visible, switch.Visible = not running, running
    start.Text = if not data.nearPickup then "Move to parcel box" elseif data.state == "Completed" then "Retry delivery [E]" else "Take parcel [E]"
    switch.Text = if data.cooldownRemaining > 0 then "Switch ready soon" else "Switch [Q]\n" .. data.polarity
    switch.BackgroundColor3 = if data.polarity == "Cyan" then cyan else amber
    shells.Visible = not modal.Visible and data.tutorialComplete == true
    shopStatus.Text = data.coins .. " coins  •  Equipped: " .. data.equippedCosmetic .. "\nMint changes appearance only."
    mintButton.Text = if data.ownsMint then "Equip Mint" else "Unlock Mint • 50 coins"
end)
local jumpController = require(script.Parent.JumpController).new({
    player = player,
    requestJump = function(nonce) intent:FireServer("DoubleJump",nonce) end,
    approvals = remotes:WaitForChild("JumpApproval").OnClientEvent,
    isUnlocked = function() return latest ~= nil and latest.powerup ~= nil and latest.powerup.unlocked == true end,
    isBlocked = function() return modal.Visible end,
})
script.Destroying:Connect(function() jumpController:destroy() end)
UserInputService.InputBegan:Connect(function(input, processed)
    if processed or modal.Visible or UserInputService:GetFocusedTextBox() then return end
    if input.KeyCode == Enum.KeyCode.Q then
        intent:FireServer("Switch")
    elseif input.KeyCode == Enum.KeyCode.E and (not latest or latest.state ~= "Running") then
        -- Native prompt remains available for keyboard, touch and gamepad.
        -- This HUD shortcut shares its server handler; duplicate requests are safe.
        takeParcel()
    end
end)
-- Connect the listener first; request a fresh snapshot after the server is ready.
task.spawn(function()
    for _ = 1, 5 do
        if latest then return end
        intent:FireServer("Snapshot")
        task.wait(1)
    end
    if not latest then message.Text = "No server response. Stop and restart the playtest; inspect Output." end
end)
