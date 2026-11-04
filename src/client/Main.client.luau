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
hud.Position, hud.Size = UDim2.new(0.5, 0, 0, 8), UDim2.new(0.94, 0, 0, 228)
hud.BackgroundColor3, hud.BackgroundTransparency, hud.Parent = ink, 0.06, screen
round(hud, 16)
local outline = Instance.new("UIStroke")
outline.Color, outline.Thickness, outline.Transparency, outline.Parent = gold, 2, 0.2, hud
local limit = Instance.new("UISizeConstraint")
limit.MaxSize, limit.Parent = Vector2.new(620, 228), hud
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
local weapon = text(hud, "Weapon", 178, 20, 13, gold)
weapon.Text = "CANNON • Find the orange crate on the east trail"
local saving = text(hud, "Saving", 202, 18, 11, muted)
saving.Text = "Practice • Session progress is not saved"

local actions = Instance.new("Frame")
actions.Name, actions.BackgroundTransparency, actions.AnchorPoint = "Actions", 1, Vector2.new(0.5, 1)
actions.Position, actions.Size, actions.Parent = UDim2.new(0.5, 0, 1, -24), UDim2.fromOffset(300, 68), screen
local latest
local blasterController
local function takeParcel()
    intent:FireServer(if latest and latest.state == "Completed" then "Retry" else "Start")
end
local start = button(actions, "Start", "Take parcel", UDim2.fromOffset(80, 0), UDim2.fromOffset(140, 68), mint, function()
    if latest and latest.inWater then intent:FireServer("ReturnLand") else takeParcel() end
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
local fireButton = button(screen,"FireCannon","Fire [F]",UDim2.new(1,-158,1,-210),UDim2.fromOffset(140,58),gold,function()
    if blasterController then blasterController:fire() end
end)
fireButton.Visible=false
local crosshair=text(screen,"CannonCrosshair",0,30,24,gold)
crosshair.AnchorPoint,crosshair.Position,crosshair.Size=Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.5),UDim2.fromOffset(30,30)
crosshair.Text,crosshair.TextXAlignment,crosshair.Visible="+",Enum.TextXAlignment.Center,false
setShop = function(open)
    modal.Visible, hud.Visible, actions.Visible = open, not open, not open
    shells.Visible = not open and latest ~= nil and latest.tutorialComplete == true
    fireButton.Visible=not open and latest~=nil and latest.blaster~=nil and latest.blaster.unlocked==true
    crosshair.Visible=fireButton.Visible and UserInputService.PreferredInput~=Enum.PreferredInput.KeyboardAndMouse
end
local function layout()
    local camera = workspace.CurrentCamera
    local compact = camera and camera.ViewportSize.Y < 500
    local portrait = camera and camera.ViewportSize.Y > camera.ViewportSize.X
    title.Visible = not compact
    hud.Size = UDim2.new(0.94, 0, 0, if compact then 172 else 228)
    status.Position, status.TextSize = UDim2.new(0, 14, 0, if compact then 3 else 35), if compact then 14 else 17
    status.Size=UDim2.new(1,if compact then -130 else -28,0,26)
    goal.Position, goal.TextSize = UDim2.new(0, 14, 0, if compact then 26 else 62), if compact then 14 else 16
    message.Position, message.Size, message.TextSize = UDim2.new(0, 14, 0, if compact then 52 else 89), UDim2.new(1, -28, 0, if compact then 29 else 39), if compact then 12 else 14
    expedition.Position, expedition.Size = UDim2.new(0, 14, 0, if compact then 83 else 130), UDim2.new(1, -28, 0, if compact then 18 else 23)
    expedition.TextSize = if compact or (camera and camera.ViewportSize.X < 420) then 12 else 14
    ability.Position, ability.TextSize = UDim2.new(0, 14, 0, if compact then 104 else 154), if compact then 11 else 13
    weapon.Position, weapon.TextSize = UDim2.new(0,14,0,if compact then 127 else 178),if compact then 11 else 13
    saving.Position, saving.TextSize = UDim2.new(0, 14, 0, if compact then 151 else 202), if compact then 10 else 11
    -- One centered action; portrait lifts it above the default thumbstick/jump row.
    actions.Position = UDim2.new(0.5, 0, 1, if portrait then -120 elseif compact then -12 else -24)
    shells.Position = UDim2.new(1, if compact then -98 else -138, 0, if compact then 8 else 244)
    shells.Size,shells.TextSize=UDim2.fromOffset(if compact then 80 else 124,if compact then 26 else 46),if compact then 12 else 16
    fireButton.Position=UDim2.new(1,-158,1,if compact then -150 elseif portrait then -240 else -210)
end
local viewportConnection
local function watchCamera()
    if viewportConnection then viewportConnection:Disconnect() end
    if workspace.CurrentCamera then viewportConnection = workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layout) end
    layout()
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
watchCamera()
local collectedIds, adventureVisuals, powerupVisuals, cannonVisuals = {}, {}, {}, {}
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
task.spawn(function()
    local world=workspace:WaitForChild("SwitchbackWorld",15)
    local model=world and world:WaitForChild("OrangeMushroomBlaster",15)
    if not model then return end
    local function index(item)
        if item:GetAttribute("PowerupId")=="orangeMushroom" and not string.find(item.Name,"Target") then table.insert(cannonVisuals,item) end
    end
    model.DescendantAdded:Connect(index)
    for _,item in model:GetDescendants() do index(item) end
end)
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
    local cannon=type(data.blaster)=="table" and data.blaster.unlocked==true
    local fireHint=if preferred==Enum.PreferredInput.Touch then "Aim at + • tap Fire" elseif preferred==Enum.PreferredInput.Gamepad then "Aim at + • R2" else "Aim mouse • click / F"
    weapon.Text=if cannon then string.format("CANNON • %s • %d hits",fireHint,data.blaster.hits or 0) else "CANNON • Orange mushroom on the east trail"
    fireButton.Visible=cannon and not modal.Visible
    fireButton.Text=if preferred==Enum.PreferredInput.Touch then "Fire cannon" elseif preferred==Enum.PreferredInput.Gamepad then "Fire [R2]" else "Fire [F]"
    crosshair.Visible=fireButton.Visible and preferred~=Enum.PreferredInput.KeyboardAndMouse
    for _,item in cannonVisuals do
        if item.Parent then
            if item:IsA("ProximityPrompt") then item.Enabled=not cannon
            elseif item:IsA("BasePart") then item.LocalTransparencyModifier=if cannon then 0.55 else 0 end
        end
    end
    if data.inWater then goal.Text="SWIM • Move toward the shore flags or return to land" end
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
    local returnHint=if preferred==Enum.PreferredInput.Touch then "Return to shore" elseif preferred==Enum.PreferredInput.Gamepad then "Return to shore [Y]" else "Return to shore [R]"
    start.Text = if data.inWater then returnHint elseif not data.nearPickup then "Move to parcel box" elseif data.state == "Completed" then "Retry delivery [E]" else "Take parcel [E]"
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
blasterController=require(script.Parent.BlasterController).new({
    player=player,isBlocked=function() return modal.Visible end,
    aimPoint=function() return crosshair.AbsolutePosition+crosshair.AbsoluteSize/2 end,
    isUnlocked=function() return latest~=nil and latest.blaster~=nil and latest.blaster.unlocked==true end,
    inWater=function() return latest~=nil and latest.inWater==true end,
    fire=function(direction) remotes:WaitForChild("CannonFire"):FireServer(direction) end,
    returnLand=function() intent:FireServer("ReturnLand") end,
})
script.Destroying:Connect(function() jumpController:destroy(); blasterController:destroy() end)
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
