local World = {}
local WorldLayout = require(game:GetService("ReplicatedStorage").Shared.WorldLayout)
local TerrainWorld = require(script.Parent.TerrainWorld)
local AdventureLayout = require(game:GetService("ReplicatedStorage").Shared.AdventureLayout)
local AdventureWorld = require(script.Parent.AdventureWorld)
local PowerupWorld = require(script.Parent.PowerupWorld)
local PowerupConfig = require(game:GetService("ReplicatedStorage").Shared.PowerupConfig)
local BlasterWorld = require(script.Parent.BlasterWorld)
local BlasterConfig = require(game:GetService("ReplicatedStorage").Shared.BlasterConfig)
local OceanWorld = require(script.Parent.OceanWorld)
local OceanConfig = require(game:GetService("ReplicatedStorage").Shared.OceanConfig)
local VisualConfig = require(game:GetService("ReplicatedStorage").Shared.VisualConfig)
local LightingPresentation = require(script.Parent.LightingPresentation)
local WorldPresentation = require(script.Parent.WorldPresentation)

function World.build(config)
    local existing = workspace:FindFirstChild("SwitchbackWorld")
    if existing then existing:Destroy() end
    local model = Instance.new("Model")
    model.Name = "SwitchbackWorld"
    model.Parent = workspace
    local function part(name, size, position, color, material)
        local p = Instance.new("Part")
        p.Name, p.Size, p.Position = name, size, position
        p.Anchored = true
        p.Color = color
        p.Material = material or Enum.Material.SmoothPlastic
        p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
        p.Parent = model
        return p
    end
    local function sign(name, position, text, color, width)
        local anchor = part(name, Vector3.new(1, 1, 1), position, color)
        anchor.Transparency, anchor.CanCollide, anchor.CanQuery = 1, false, false
        local gui = Instance.new("BillboardGui")
        gui.Size = UDim2.fromOffset(width or 260, 90)
        gui.AlwaysOnTop, gui.MaxDistance = false, 80
        gui.Parent = anchor
        local label = Instance.new("TextLabel")
        label.Size, label.BackgroundTransparency = UDim2.fromScale(1, 1), 0.12
        label.BackgroundColor3 = Color3.fromRGB(20, 29, 48)
        label.TextColor3, label.Text = color, text
        label.TextSize, label.Font = 20, Enum.Font.GothamBold
        label.TextWrapped = true
        label.Parent = gui
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 12)
        corner.Parent = label
        return anchor
    end
    local meadow = Color3.fromRGB(98, 158, 72)
    local rail = Color3.fromRGB(224, 159, 93)
    local mint = Color3.fromRGB(114, 245, 182)
    local layout=WorldLayout.create(config)
    TerrainWorld.build(model, layout)
    -- Root height is ~12; deck top is 9.5. All landings are ordinary anchored parts.
    local function deck(name, x, z, width, length)
        part(name .. "Cliff", Vector3.new(width, 6, length), Vector3.new(x, 4.5, z), Color3.fromRGB(204, 134, 76), Enum.Material.Sandstone)
        part(name, Vector3.new(width, 2, length), Vector3.new(x, 8.5, z), meadow, Enum.Material.Grass)
    end
    deck("DepotRoof", 0, 2, 38, 26)
    deck("FirstLane", 0, -34, 20, 58)
    deck("SafeDetour", -14, -76, 12, 36)
    deck("DetourEntry", -7, -60, 26, 10)
    deck("DetourExit", -7, -94, 26, 10)
    deck("ShortcutTakeoff", 0, -65, 10, 6)
    deck("ShortcutLanding", 0, -81, 10, 10)
    deck("ShortcutExit", 0, -92, 10, 8)
    deck("FinalLane", 0, -125, 20, 66)
    -- Begin beyond the hub's crossing path; tiles under that path nearly shared its plane.
    for index = 2, 5 do
        part("DepotPaver" .. index, Vector3.new(5, 0.12, 2.4), Vector3.new(0, 9.56, 8 - index * 6), Color3.fromRGB(255, 226, 163))
    end
    -- Buildings below the deck are decorative and do not supply alternate gates.
    for index = 1, 8 do
        local side = if index % 2 == 0 then 1 else -1
        local z = -20 - math.floor(index / 2) * 30
        local height = 12 + (index % 3) * 5
        part("Skyline" .. index, Vector3.new(15, height, 20), Vector3.new(side * 38, height / 2 - 18, z), rail)
    end
    local spawn = Instance.new("SpawnLocation")
    spawn.Name, spawn.Size = "DepotSpawn", Vector3.new(7, 1, 7)
    local depotOrigin = Vector3.new(table.unpack(config.route.depot))
    spawn.Position, spawn.Anchored, spawn.Neutral = depotOrigin + Vector3.new(0, -2, 5), true, true
    spawn.Color, spawn.Material, spawn.Duration = mint, Enum.Material.Neon, 0
    spawn.Parent = model
    local stationPosition = Vector3.new(table.unpack(config.pickup.position))
    local depot = part("ParcelDepot", Vector3.new(5, 3, 3), stationPosition, Color3.fromRGB(210, 157, 87), Enum.Material.Wood)
    part("ParcelTapeTop", Vector3.new(0.7, 0.08, 3.08), stationPosition + Vector3.new(0, 1.54, 0), mint)
    part("ParcelTapeFront", Vector3.new(0.7, 3, 0.08), stationPosition + Vector3.new(0, 0, 1.54), mint)
    part("ParcelLabel", Vector3.new(1.4, 0.9, 0.08), stationPosition + Vector3.new(1.25, 0.3, 1.54), Color3.fromRGB(246, 242, 224))
    local prompt = Instance.new("ProximityPrompt")
    prompt.Name, prompt.ActionText, prompt.ObjectText = "TakeParcel", "Take parcel", "Training delivery"
    prompt.KeyboardKeyCode, prompt.MaxActivationDistance, prompt.HoldDuration = Enum.KeyCode.E, config.pickup.radius, 0
    prompt.GamepadKeyCode, prompt.ClickablePrompt = Enum.KeyCode.ButtonX, true
    prompt.RequiresLineOfSight = false
    prompt.Parent = depot
    sign("DepotSign", depotOrigin + Vector3.new(-9, 12, 9), "SWITCHBACK COURIERS\nTake a parcel • Match the gate", mint, 320)
    sign("PathChoice", Vector3.new(-10, 17, -67), "SAFE PATH ←\nJump shortcut ahead", Color3.fromRGB(235, 239, 249), 220)
    for index, gate in config.route.gates do
        local position = Vector3.new(table.unpack(gate.position))
        local color = Color3.fromRGB(table.unpack(config.colors[gate.polarity]))
        part("Gate" .. index .. "Left", Vector3.new(1, 10, 1), position + Vector3.new(-7.5, 2, 0), color, Enum.Material.Neon)
        part("Gate" .. index .. "Right", Vector3.new(1, 10, 1), position + Vector3.new(7.5, 2, 0), color, Enum.Material.Neon)
        part("Gate" .. index .. "Top", Vector3.new(16, 1, 1), position + Vector3.new(0, 7, 0), color, Enum.Material.Neon)
        local symbol = if gate.polarity == "Amber" then "A / SUN" else "C / MOON"
        sign("Gate" .. index .. "Sign", position + Vector3.new(0, 11, 0), index .. "  " .. symbol .. "\n" .. gate.polarity, color, 170)
    end
    part("DeliveryPad", Vector3.new(14, 0.3, 9), Vector3.new(0, 9.7, -148), mint, Enum.Material.Neon)
    sign("DestinationSign", Vector3.new(0, 19, -148), "DELIVER HERE\nAll four gates → 25 coins", mint)
    local adventure = AdventureWorld.build(model, AdventureLayout.create(config))
    local lighting = game:GetService("Lighting")
    LightingPresentation.apply(lighting,VisualConfig,workspace:FindFirstChildOfClass("Terrain"))
    local powerups = PowerupWorld.build(model, PowerupConfig)
    local blaster = BlasterWorld.build(model, BlasterConfig)
    local ocean = OceanWorld.build(model, OceanConfig)
    local presentation=WorldPresentation.apply(model,VisualConfig,{
        scope=VisualConfig.scope,layout=layout,
        templates=game:GetService("ServerStorage"):FindFirstChild("VisualAssets"),
        materialService=game:GetService("MaterialService"),
    })
    return { model = model, prompt = prompt, adventure = adventure, powerups = powerups, blaster = blaster, ocean = ocean, presentation=presentation }
end

return World
