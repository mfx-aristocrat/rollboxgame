local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local Config = require("../src/shared/Config")
local OceanConfig = require("../src/shared/OceanConfig")
local WorldLayout = require("../src/shared/WorldLayout")

local function module()
    return luau.load(fs.readFile("src/server/OceanWorld.luau"), {
        injectGlobals = true,
        environment = {
            Instance = roblox.Instance, Enum = roblox.Enum, CFrame = roblox.CFrame,
            Vector3 = roblox.Vector3, Color3 = roblox.Color3, UDim2 = roblox.UDim2, Region3 = roblox.Region3,
        },
    })()
end

local function support(layout, x, z)
    local top = -math.huge
    for _, surface in layout.surfaces do
        local p, size = surface.position, surface.size
        if math.abs(x - p[1]) <= size[1] / 2 and math.abs(z - p[3]) <= size[3] / 2 then
            top = math.max(top, p[2] + size[2] / 2)
        end
    end
    return top
end

return function()
    local passed = 0
    local water, layout = OceanConfig.water, WorldLayout.create(Config)
    assert(water.surfaceY == -12 and water.bottomY == -52 and OceanConfig.seafloorTop < water.bottomY, "Water must remain below land with separated floor")
    for _, coordinate in { water.minX, water.maxX, water.minZ, water.maxZ, water.bottomY, water.surfaceY, water.chunkSize } do
        assert(coordinate % 4 == 0, "Water voxel bounds must be aligned")
    end
    assert(water.minX < layout.bounds.minX and water.maxX > layout.bounds.maxX and water.minZ < layout.bounds.minZ and water.maxZ > layout.bounds.maxZ, "Ocean must surround the islands")
    passed += 1

    assert(#OceanConfig.exits >= 4 and #OceanConfig.returnLandings == #OceanConfig.exits + 1)
    for _, exit in OceanConfig.exits do
        local high, low, land = exit.rampTop, exit.water, exit.land
        assert(exit.width >= 12 and low[2] <= water.surfaceY - 0.5 and low[2] >= water.surfaceY - 2, "Ramp must meet swimmers under water")
        local run = math.sqrt((high[1] - low[1])^2 + (high[3] - low[3])^2)
        assert((high[2] - low[2]) / run <= 0.25, "Swim ramp is too steep")
        assert(land[2] == high[2] and land[2] - support(layout, land[1], land[3]) == 0.25, "Level approach must meet existing land without coplanar floors")
        assert(exit.landing[2] == land[2] + 4 and exit.landing[1] == land[1] and exit.landing[3] == land[3], "Return landing must be above safe land")
        -- Sample the complete deck width through each shoreline crossing. A ramp
        -- buried in an island slab produces an unclimbable wall at its edge.
        local dx, dz = low[1] - high[1], low[3] - high[3]
        for step = 0, 100 do
            local t = step / 100
            for _, across in { -exit.width / 2, 0, exit.width / 2 } do
                local x, z = high[1] + dx * t - dz / run * across, high[3] + dz * t + dx / run * across
                local top = high[2] + (low[2] - high[2]) * t
                assert(top >= support(layout, x, z), exit.id .. " ramp intersects a solid island wall")
                assert(x > water.minX and x < water.maxX and z > water.minZ and z < water.maxZ, "Ramp leaves the ocean bounds")
            end
        end
    end
    passed += 1

    local ocean = module()
    local parent = roblox.Instance.new("Model")
    local unrelated = roblox.Instance.new("Part")
    unrelated.Name, unrelated.Parent = "UserScenery", parent
    local built = ocean.build(parent, OceanConfig, false)
    local count, solid = 0, 0
    for _, part in built.model:GetDescendants() do
        if not part:IsA("Part") then continue end
        count += 1
        assert(part.Anchored and not part.CanTouch, "Ocean scenery must stay anchored and touch-free")
        assert(part.Material ~= roblox.Enum.Material.Water, "Native water must not be a Part skin")
        if part.CanCollide then
            solid += 1
            assert(part.Name == "OceanSeafloor" or string.find(part.Name, "SwimRamp") or string.find(part.Name, "SwimDock") or string.find(part.Name, "ShoreApproach"), "Decoration must not obstruct players")
        else
            assert(not part.CanQuery, "Decoration must not intercept ground/range queries")
        end
    end
    assert(count == built.model:GetAttribute("SourcePartCount") and count <= OceanConfig.partBudget and solid == 13, "Scenic part budget or collision ownership changed")
    assert(built.seafloor.Position.Y + built.seafloor.Size.Y / 2 == OceanConfig.seafloorTop)
    for _, exit in OceanConfig.exits do
        local ramp = built.exits[exit.id].ramp
        local top = ramp.CFrame.Position + ramp.CFrame.UpVector * ramp.Size.Y / 2
        for _, endpoint in { exit.rampTop, exit.water } do
            local at = roblox.Vector3.new(table.unpack(endpoint))
            assert(math.abs(ramp.CFrame.UpVector:Dot(at - top)) < 0.001, "Rendered ramp disagrees with its walkable endpoints")
        end
    end
    passed += 1
    ocean.build(parent, OceanConfig, false)
    assert(#parent:GetChildren() == 2 and unrelated.Parent == parent, "Rebuild must replace only its owned scenery")
    parent:Destroy()
    passed += 1

    -- Exercise production channel reads/writes against a finite fake voxel store.
    -- Mixed and partial cells must survive byte-for-byte; only liquid is written.
    local region = { minX = 0, maxX = 20, minZ = 0, maxZ = 12, bottomY = -20, surfaceY = -12, resolution = 4, chunkSize = 8 }
    local stored, visited, writes = {}, {}, 0
    local function key(x, y, z) return string.format("%d:%d:%d", x, y, z) end
    stored[key(0, -20, 0)] = { roblox.Enum.Material.Rock, 0.75, 0.2 }
    stored[key(4, -20, 0)] = { roblox.Enum.Material.Sand, 1, 0 }
    stored[key(8, -20, 0)] = { roblox.Enum.Material.Air, 0, 0.4 }
    stored[key(12, -20, 0)] = { roblox.Enum.Material.Air, 0.2, 0 }
    local fake = {}
    function fake:ReadVoxelChannels(bounds, resolution, channels)
        assert(resolution == 4 and #channels == 3)
        local start = bounds.CFrame.Position - bounds.Size / 2
        local size = bounds.Size / resolution
        assert(size.X <= 2 and size.Y == 2 and size.Z <= 2, "Voxel call exceeded chunk budget")
        local result = { SolidMaterial = {}, SolidOccupancy = {}, LiquidOccupancy = {} }
        for x = 1, size.X do
            for _, array in pairs(result) do array[x] = {} end
            for y = 1, size.Y do
                for _, array in pairs(result) do array[x][y] = {} end
                for z = 1, size.Z do
                    local at = start + roblox.Vector3.new(x - 1, y - 1, z - 1) * resolution
                    local id = key(at.X, at.Y, at.Z)
                    assert(at.X >= region.minX and at.X < region.maxX and at.Z >= region.minZ and at.Z < region.maxZ)
                    visited[id] = (visited[id] or 0) + 1
                    local cell = stored[id] or { roblox.Enum.Material.Air, 0, 0 }
                    result.SolidMaterial[x][y][z], result.SolidOccupancy[x][y][z], result.LiquidOccupancy[x][y][z] = table.unpack(cell)
                end
            end
        end
        return result
    end
    function fake:WriteVoxelChannels(bounds, resolution, channels)
        assert(channels.SolidMaterial == nil and channels.SolidOccupancy == nil, "Writer must never roundtrip solid channels")
        local channelCount = 0
        for _ in pairs(channels) do channelCount += 1 end
        assert(channelCount == 1 and channels.LiquidOccupancy, "Only liquid writes are allowed")
        writes += 1
        local start = bounds.CFrame.Position - bounds.Size / 2
        for x, column in channels.LiquidOccupancy do
            for y, row in column do
                for z, liquid in row do
                    local at = start + roblox.Vector3.new(x - 1, y - 1, z - 1) * resolution
                    local id = key(at.X, at.Y, at.Z)
                    local cell = stored[id] or { roblox.Enum.Material.Air, 0, 0 }
                    stored[id] = { cell[1], cell[2], liquid }
                end
            end
        end
    end
    local first = ocean.fillWater(fake, region)
    assert(first.chunksRead == 6 and first.chunksWritten == 6 and first.voxelsAdded == 26, "Bounded fill coverage is incorrect")
    local cells = 0
    for _, times in visited do assert(times == 1, "Overlapping chunk writes"); cells += 1 end
    assert(cells == 30 and writes == 6)
    assert(stored[key(0, -20, 0)][1] == roblox.Enum.Material.Rock and stored[key(0, -20, 0)][2] == 0.75 and stored[key(0, -20, 0)][3] == 0.2, "Mixed authored voxel changed")
    assert(stored[key(4, -20, 0)][1] == roblox.Enum.Material.Sand and stored[key(4, -20, 0)][2] == 1 and stored[key(4, -20, 0)][3] == 0)
    assert(stored[key(8, -20, 0)][3] == 0.4 and stored[key(12, -20, 0)][2] == 0.2 and stored[key(12, -20, 0)][3] == 0, "Partial water or occupied air was changed")
    passed += 1
    local second = ocean.fillWater(fake, region)
    assert(second.chunksRead == 6 and second.chunksWritten == 0 and second.voxelsAdded == 0 and writes == 6, "Water rebuild must be idempotent")
    passed += 1
    print("Ocean geometry:", count, "Parts; four accessible ramps; mixed-channel preservation checked")
    return passed
end
