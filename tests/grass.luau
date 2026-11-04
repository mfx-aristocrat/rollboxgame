local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local Config = require("../src/shared/Config")
local WorldLayout = require("../src/shared/WorldLayout")
local AdventureLayout = require("../src/shared/AdventureLayout")
local PowerupConfig = require("../src/shared/PowerupConfig")
local BlasterConfig = require("../src/shared/BlasterConfig")
local OceanConfig = require("../src/shared/OceanConfig")

return function()
    -- Execute the actual production builders; the adapter supplies only Roblox globals/services.
    local terrainKey, adventureKey, layoutKey, adventureLayoutKey, powerupKey, powerupConfigKey = {}, {}, {}, {}, {}, {}
    local blasterKey, blasterConfigKey, oceanKey, oceanConfigKey = {}, {}, {}, {}
    local modules = { [blasterConfigKey]=BlasterConfig, [oceanConfigKey]=OceanConfig, [layoutKey] = WorldLayout, [adventureLayoutKey] = AdventureLayout, [powerupConfigKey] = PowerupConfig }
    local environment = {
        Instance = roblox.Instance, Enum = roblox.Enum, CFrame = roblox.CFrame,
        Vector3 = roblox.Vector3, Color3 = roblox.Color3, UDim2 = roblox.UDim2, UDim = roblox.UDim,
        workspace = roblox.Instance.new("Folder"), script = { Parent = { TerrainWorld = terrainKey, AdventureWorld = adventureKey, PowerupWorld = powerupKey, BlasterWorld=blasterKey, OceanWorld=oceanKey } },
        game = { GetService = function(_, name)
            if name == "ReplicatedStorage" then return { Shared = { WorldLayout = layoutKey, AdventureLayout = adventureLayoutKey, PowerupConfig = powerupConfigKey, BlasterConfig=blasterConfigKey, OceanConfig=oceanConfigKey } } end
            assert(name == "Lighting", name)
            return {}
        end },
        require = function(key) return assert(modules[key], "unexpected production dependency") end,
    }
    local function load(path)
        return luau.load(fs.readFile(path), { injectGlobals = true, environment = environment })()
    end
    modules[terrainKey] = load("src/server/TerrainWorld.luau")
    modules[adventureKey] = load("src/server/AdventureWorld.luau")
    modules[powerupKey] = load("src/server/PowerupWorld.luau")
    modules[blasterKey] = load("src/server/BlasterWorld.luau")
    local ocean = load("src/server/OceanWorld.luau")
    modules[oceanKey] = {build=function(parent,config) return ocean.build(parent,config,false) end}
    local model = load("src/server/World.luau").build(Config).model
    for _, name in { "DepotRoof", "FirstLane", "SafeDetour", "DetourEntry", "DetourExit", "ShortcutTakeoff", "ShortcutLanding", "ShortcutExit", "FinalLane" } do
        local floor = assert(model:FindFirstChild(name), name)
        assert(floor.Material == roblox.Enum.Material.Grass and floor.CanCollide, name .. " must remain solid grass")
        assert(floor.Position.Y + floor.Size.Y / 2 == 9.5, name .. " walking height changed")
    end
    local landscape = model.ExplorationLandscape
    for _, name in { "MeadowGrass", "GardensGrass", "MesaGrass", "MesaCrownGrass" } do
        assert(landscape:FindFirstChild(name).Material == roblox.Enum.Material.Grass, name .. " must retain grass material")
    end
    local blades, parts = 0, 0
    for _, part in landscape:GetDescendants() do
        if not part:IsA("Part") then continue end
        parts += 1
        if part.Name == "GrassBlade" then
            blades += 1
            assert(part.Anchored and not part.CanCollide and not part.CanTouch and not part.CanQuery and not part.CastShadow, "grass must not alter movement, input or ground queries")
            assert(part.Size.X < 0.5 and part.Size.Z < 0.5 and part.Size.Y <= 1.5, "grass detail must remain slender and low")
        end
    end
    assert(blades > 0 and blades <= 180 and blades == landscape:GetAttribute("GrassDetailPartCount"), "grass blade budget/count mismatch")
    assert(parts == landscape:GetAttribute("SourcePartCount") and parts <= landscape:GetAttribute("SourcePartBudget"), "actual landscape exceeds source budget")
    local layout = WorldLayout.create(Config)
    for _, tuft in layout.grassDetails do
        local p = tuft.position
        for _, segment in layout.segments do
            local a, b = segment.a, segment.b
            local dx, dz = b[1] - a[1], b[3] - a[3]
            local t = math.clamp(((p[1] - a[1]) * dx + (p[3] - a[3]) * dz) / (dx * dx + dz * dz), 0, 1)
            local distance = math.sqrt((p[1] - a[1] - dx * t)^2 + (p[3] - a[3] - dz * t)^2)
            assert(distance > segment.width / 2 + 1, "grass hides a walking path")
        end
        for _, item in AdventureLayout.create(Config).items do
            local at = item.position
            assert(math.sqrt((p[1] - at[1])^2 + (p[3] - at[3])^2) >= 5, "grass crowds an exploration pickup")
        end
    end
    model:Destroy()
    return 3
end
