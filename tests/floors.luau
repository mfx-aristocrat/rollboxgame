local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local Config = require("../src/shared/Config")
local WorldLayout = require("../src/shared/WorldLayout")
local AdventureLayout = require("../src/shared/AdventureLayout")
local PowerupConfig = require("../src/shared/PowerupConfig")
local BlasterConfig = require("../src/shared/BlasterConfig")
local OceanConfig = require("../src/shared/OceanConfig")

-- Execute the complete production builder with native Roblox instances/datatype schemas.
-- Only service/module lookup is adapted; all rendered geometry comes from source.
local function buildWorld()
    local terrainKey, adventureKey = {}, {}
    local layoutKey, adventureLayoutKey, powerupKey, powerupConfigKey = {}, {}, {}, {}
    local blasterKey, blasterConfigKey, oceanKey, oceanConfigKey = {}, {}, {}, {}
    local visualKey,lightingKey,presentationKey={},{},{}
    local modules = { [visualKey]=require("../src/shared/VisualConfig"), [lightingKey]={apply=function() end}, [presentationKey]={apply=function() end}, [blasterConfigKey]=BlasterConfig, [oceanConfigKey]=OceanConfig, [layoutKey] = WorldLayout, [adventureLayoutKey] = AdventureLayout, [powerupConfigKey] = PowerupConfig }
    local environment = {
        Instance = roblox.Instance, Enum = roblox.Enum, CFrame = roblox.CFrame,
        Vector3 = roblox.Vector3, Color3 = roblox.Color3, UDim2 = roblox.UDim2, UDim = roblox.UDim,
        workspace = roblox.Instance.new("Folder"), script = { Parent = { TerrainWorld = terrainKey, AdventureWorld = adventureKey, PowerupWorld = powerupKey, BlasterWorld=blasterKey, OceanWorld=oceanKey,LightingPresentation=lightingKey, WorldPresentation=presentationKey } },
        game = { GetService = function(_, name)
            if name == "ReplicatedStorage" then return { Shared = { WorldLayout = layoutKey, AdventureLayout = adventureLayoutKey, PowerupConfig = powerupConfigKey, BlasterConfig=blasterConfigKey, OceanConfig=oceanConfigKey,VisualConfig=visualKey } } end
            if name=="ServerStorage" then return {FindFirstChild=function() return nil end} end
            assert(name=="Lighting" or name=="MaterialService",name)
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
    return load("src/server/World.luau").build(Config).model
end

local function cross(a, b, c)
    return (b.x - a.x) * (c.z - a.z) - (b.z - a.z) * (c.x - a.x)
end

local function intersection(subject, clip)
    local output = subject
    for index, edge in clip do
        local nextEdge = clip[index % #clip + 1]
        local input = output
        output = {}
        if #input == 0 then break end
        local previous = input[#input]
        local previousSide = cross(edge, nextEdge, previous)
        for _, current in input do
            local currentSide = cross(edge, nextEdge, current)
            if (currentSide >= 0) ~= (previousSide >= 0) then
                local t = previousSide / (previousSide - currentSide)
                table.insert(output, { x = previous.x + (current.x - previous.x) * t, z = previous.z + (current.z - previous.z) * t })
            end
            if currentSide >= 0 then table.insert(output, current) end
            previous, previousSide = current, currentSide
        end
    end
    return output
end

local function area(polygon)
    local twice = 0
    for index, p in polygon do
        local q = polygon[index % #polygon + 1]
        twice += p.x * q.z - q.x * p.z
    end
    return math.abs(twice) / 2
end

local function contains(polygon, at)
    for index, p in polygon do
        local q = polygon[index % #polygon + 1]
        local length = math.sqrt((q.x - p.x)^2 + (q.z - p.z)^2)
        if cross(p, q, at) < -0.001 * length then return false end
    end
    return true
end

local function floors(model)
    local result = {}
    for _, part in model:GetDescendants() do
        if not part:IsA("Part") or not part.CanCollide or part.Transparency > 0 or part.Shape ~= roblox.Enum.PartType.Block then continue end
        local frame = part.CFrame
        -- Lune stores Position and CFrame independently; Roblox aliases these properties.
        -- Builders set Position for blocks and CFrame for beams (whose Position starts at zero).
        if frame.Position == roblox.Vector3.zero then frame += part.Position end
        local up = frame.UpVector
        if up.Y < 0.7 then continue end
        local top = frame.Position + up * part.Size.Y / 2
        local polygon = {}
        -- Counterclockwise in the XZ projection.
        for _, corner in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
            local point = frame:PointToWorldSpace(roblox.Vector3.new(corner[1] * part.Size.X / 2, part.Size.Y / 2, corner[2] * part.Size.Z / 2))
            table.insert(polygon, { x = point.X, z = point.Z })
        end
        local surface = { part = part, up = up, top = top, polygon = polygon }
        surface.height = function(x, z) return top.Y - (up.X * (x - top.X) + up.Z * (z - top.Z)) / up.Y end
        table.insert(result, surface)
    end
    return result
end

local function conflicts(surfaces)
    local result = {}
    for index, a in surfaces do
        for j = index + 1, #surfaces do
            local b = surfaces[j]
            if a.part.Color == b.part.Color and a.part.Material == b.part.Material then continue end
            if a.up:Dot(b.up) < 0.999999 then continue end
            if math.abs(a.up:Dot(b.top - a.top)) > 0.015 then continue end
            local overlap = intersection(a.polygon, b.polygon)
            if #overlap < 3 or area(overlap) < 0.01 then continue end
            -- Buried foundation intersections are not visible floor flicker.
            local center = { x = 0, z = 0 }
            for _, p in overlap do center.x += p.x / #overlap; center.z += p.z / #overlap end
            local samples = { center }
            -- Also probe inset vertices/edges so a covered midpoint cannot hide visible edges.
            for k, p in overlap do
                local q = overlap[k % #overlap + 1]
                for _, point in { p, { x = (p.x + q.x) / 2, z = (p.z + q.z) / 2 } } do
                    table.insert(samples, { x = point.x * 0.99 + center.x * 0.01, z = point.z * 0.99 + center.z * 0.01 })
                end
            end
            local exposed = false
            for _, sample in samples do
                local hidden = false
                for _, covering in surfaces do
                    if covering == a or covering == b then continue end
                    if contains(covering.polygon, sample) and covering.height(sample.x, sample.z) > a.height(sample.x, sample.z) + 0.015 then hidden = true; break end
                end
                if not hidden then exposed = true; break end
            end
            if exposed then
                table.insert(result, string.format("%s / %s at (%.2f, %.2f, %.2f), overlap %.2f stud^2", a.part.Name, b.part.Name, center.x, a.height(center.x, center.z), center.z, area(overlap)))
            end
        end
    end
    table.sort(result)
    return result
end

return function()
    local model = buildWorld()
    local surfaces = floors(model)
    local found = conflicts(surfaces)
    for _, detail in found do print(detail) end
    assert(#found == 0, string.format("%d exposed floor pairs can flicker between different colors/materials", #found))

    local function support(x, z)
        local top = -math.huge
        for _, surface in surfaces do
            if surface.part.Parent.Name == "ExplorationLandscape" and contains(surface.polygon, { x = x, z = z }) then
                top = math.max(top, surface.height(x, z))
            end
        end
        return top
    end
    -- Query production-rendered planes, independently of the renderer's chosen offsets.
    for _, path in WorldLayout.create(Config).segments do
        local a, b = path.a, path.b
        local dx, dz = b[1] - a[1], b[3] - a[3]
        local length = math.sqrt(dx * dx + dz * dz)
        for step = 0, math.ceil(length / 2) do
            local t = step / math.ceil(length / 2)
            for _, offset in { -3, 0, 3 } do
                local x, y, z = a[1] + dx * t - dz / length * offset, a[2] + (b[2] - a[2]) * t, a[3] + dz * t + dx / length * offset
                local top = support(x, z)
                assert(top >= y - 0.001 and top <= y + 0.5, path.name .. " has a walking gap or step above 0.5 studs: " .. top - y)
            end
        end
    end
    local adventure = AdventureLayout.create(Config)
    for _, item in adventure.items do
        local p = item.position
        local clearance = p[2] - support(p[1], p[3])
        -- A four-stud noncolliding crate may inset by at most a normal 0.5-stud step.
        assert(clearance >= 1.5 and clearance <= 4, item.id .. " is buried or outside collection reach")
    end
    for _, spring in adventure.springs do
        local p = spring.position
        local inset = support(p[1], p[3]) - (p[2] - 0.6)
        assert(inset >= -0.001 and inset <= 0.5, spring.id .. " floats or is excessively buried")
    end
    model:Destroy()
    return 2
end
