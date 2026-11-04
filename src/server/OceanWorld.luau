local OceanWorld = {}

-- Only empty Air is filled. Writing only the liquid channel preserves all solid
-- material/occupancy, including mixed solid/water and partial authored water.
-- No terrain presentation properties, Clear or Fill APIs are used.
function OceanWorld.fillWater(terrain, water)
    local result = { chunksRead = 0, chunksWritten = 0, voxelsAdded = 0 }
    local resolution = water.resolution
    assert(resolution == 4 and water.chunkSize > 0 and water.chunkSize % resolution == 0, "Invalid ocean voxel grid")
    for _, number in { water.minX, water.maxX, water.minZ, water.maxZ, water.bottomY, water.surfaceY } do
        assert(number % resolution == 0, "Ocean bounds must align to the voxel grid")
    end
    assert(water.minX < water.maxX and water.minZ < water.maxZ and water.bottomY < water.surfaceY, "Invalid ocean bounds")
    for x = water.minX, water.maxX - resolution, water.chunkSize do
        for z = water.minZ, water.maxZ - resolution, water.chunkSize do
            local region = Region3.new(Vector3.new(x, water.bottomY, z), Vector3.new(math.min(x + water.chunkSize, water.maxX), water.surfaceY, math.min(z + water.chunkSize, water.maxZ)))
            local channels = terrain:ReadVoxelChannels(region, resolution, { "SolidMaterial", "SolidOccupancy", "LiquidOccupancy" })
            local materials, occupancies, liquid = channels.SolidMaterial, channels.SolidOccupancy, channels.LiquidOccupancy
            result.chunksRead += 1
            local added = 0
            for ix, column in ipairs(materials) do
                for iy, row in ipairs(column) do
                    for iz, material in ipairs(row) do
                        if material == Enum.Material.Air and occupancies[ix][iy][iz] == 0 and liquid[ix][iy][iz] == 0 then
                            liquid[ix][iy][iz] = 1
                            added += 1
                        end
                    end
                end
            end
            if added > 0 then
                terrain:WriteVoxelChannels(region, resolution, { LiquidOccupancy = liquid })
                result.chunksWritten += 1
                result.voxelsAdded += added
            end
        end
    end
    return result
end

function OceanWorld.build(parent, config, terrain)
    local model = Instance.new("Model")
    model.Name = config.modelName
    model:SetAttribute("OceanSourceOwned", true)
    local count = 0
    local function v(values) return Vector3.new(table.unpack(values)) end
    local colors = {
        wood = Color3.fromRGB(146, 104, 69), sand = Color3.fromRGB(221, 194, 136),
        stone = Color3.fromRGB(136, 155, 146), cream = Color3.fromRGB(255, 242, 205),
        red = Color3.fromRGB(231, 105, 94), green = Color3.fromRGB(72, 135, 76),
        yellow = Color3.fromRGB(255, 219, 92), blue = Color3.fromRGB(91, 203, 219),
    }
    local function part(name, size, position, color, material, collidable)
        count += 1
        assert(count <= config.partBudget, "Ocean source part budget exceeded")
        local p = Instance.new("Part")
        p.Name, p.Size, p.Position = name, size, position
        p.Anchored, p.CanCollide = true, collidable == true
        p.CanTouch, p.CanQuery, p.CastShadow = false, collidable == true, collidable == true
        p.Color, p.Material = color, material or Enum.Material.SmoothPlastic
        p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
        p.Parent = model
        return p
    end
    local function beam(name, a, b, width, height, color, collidable)
        local frame = CFrame.lookAt((a + b) / 2, b)
        local p = part(name, Vector3.new(width, height, (b - a).Magnitude), Vector3.zero, color, Enum.Material.WoodPlanks, collidable)
        -- Endpoints describe the top of the deck, rather than the beam center.
        p.CFrame = frame - frame.UpVector * height / 2
        return p
    end
    local function sign(name, at, text)
        local post = part(name .. "Sign", Vector3.new(0.75, 8, 0.75), at + Vector3.new(0, 4, 0), colors.wood, Enum.Material.Wood)
        local board = Instance.new("BillboardGui")
        board.Name, board.Size = "OceanWayfinding", UDim2.fromOffset(240, 72)
        board.StudsOffsetWorldSpace, board.MaxDistance = Vector3.new(0, 6, 0), 150
        board.AlwaysOnTop, board.Parent = false, post
        local label = Instance.new("TextLabel")
        label.Size = UDim2.fromScale(1, 1)
        label.BackgroundColor3, label.BackgroundTransparency = Color3.fromRGB(29, 64, 74), 0.08
        label.TextColor3, label.Text, label.TextWrapped = colors.cream, text, true
        label.Font, label.TextSize, label.Parent = Enum.Font.GothamBold, 17, board
    end
    local water = config.water
    local floor = part("OceanSeafloor", Vector3.new(water.maxX - water.minX, 4, water.maxZ - water.minZ), Vector3.new((water.minX + water.maxX) / 2, config.seafloorTop - 2, (water.minZ + water.maxZ) / 2), colors.sand, Enum.Material.Sand, true)
    local exits = {}
    for _, exit in config.exits do
        local land, high, low = v(exit.land), v(exit.rampTop), v(exit.water)
        local outward = Vector3.new(low.X - high.X, 0, low.Z - high.Z).Unit
        local side = Vector3.new(-outward.Z, 0, outward.X)
        local approach = beam(exit.id .. "ShoreApproach", land, high, exit.width, 1, colors.wood, true)
        local ramp = beam(exit.id .. "SwimRamp", low, high, exit.width, 1, colors.wood, true)
        ramp:SetAttribute("OceanExitId", exit.id)
        -- The dock extends outward from the ramp, with a 0.125-stud separation
        -- from its plane. The gentle seam is hidden beneath native water.
        local dockTop = low + outward * 11 - Vector3.new(0, 0.125, 0)
        local dock = part(exit.id .. "SwimDock", Vector3.new(24, 1, 24), dockTop - Vector3.new(0, 0.5, 0), colors.wood, Enum.Material.WoodPlanks, true)
        for _, direction in { -1, 1 } do
            local offset = side * direction * (exit.width / 2 - 0.5)
            beam(exit.id .. "RampGuide", low + offset + Vector3.new(0, 2.7, 0), high + offset + Vector3.new(0, 2.7, 0), 0.4, 0.4, colors.cream, false)
            for _, endpoint in { low, high } do
                part("RampPost", Vector3.new(0.7, 3, 0.7), endpoint + offset + Vector3.new(0, 1.5, 0), colors.wood, Enum.Material.Wood)
            end
            local buoyAt = dockTop + outward * 13 + side * direction * 13 + Vector3.new(0, 1, 0)
            local buoy = part("OceanExitBuoy", Vector3.new(4, 3, 4), buoyAt, colors.yellow)
            buoy.Shape = Enum.PartType.Ball
            part("BuoyPennant", Vector3.new(0.4, 7, 0.4), buoyAt + Vector3.new(0, 4, 0), colors.cream)
            part("BuoyFlag", Vector3.new(4, 2.5, 0.25), buoyAt + Vector3.new(1.8, 6, 0), colors.red, Enum.Material.Fabric)
        end
        sign(exit.id, dockTop + side * 16, "SWIM EXIT → RAMP\n" .. exit.name)
        sign(exit.id .. "Shore", land + side * 13, "OCEAN WALK\nGentle ramp to the water")
        exits[exit.id] = { ramp = ramp, approach = approach, dock = dock, landing = v(exit.landing) }
    end

    -- Irregular shoreline rocks break up the straight island foundations. All
    -- scenery is original primitives and cannot trap swimmers or block paths.
    for index, row in {
        { -452, 45 }, { -458, 110 }, { -455, 285 }, { -450, 365 },
        { 451, 30 }, { 459, 105 }, { 453, 185 }, { 452, 355 },
        { -539, 490 }, { -544, 570 }, { -541, 650 }, { -540, 820 },
        { 542, 510 }, { 540, 695 }, { 539, 795 }, { 485, 886 },
        { -430, 880 }, { -310, 884 }, { -190, 881 }, { 200, 888 },
    } do
        local height = 8 + index % 4 * 2
        local rock = part("OceanShoreRock", Vector3.new(13 + index % 3 * 3, height, 12 + index % 4 * 2), Vector3.new(row[1], -14.5, row[2]), colors.stone, Enum.Material.Rock)
        rock.Shape = Enum.PartType.Ball
        rock.CFrame = CFrame.new(rock.Position) * CFrame.Angles(0.12, index * 0.8, -0.15)
    end
    for _, row in { { -442, -2, 85 }, { -440, -2, 305 }, { 440, -4, 135 }, { 440, -4, 325 }, { -528, -2, 525 }, { -527, -2, 810 }, { 527, 12, 675 } } do
        local at = v(row)
        for blade = 1, 4 do
            local reed = part("ShoreReed", Vector3.new(0.3, 3.8 + blade * 0.5, 0.3), at + Vector3.new((blade - 2.5) * 0.7, 2 + blade * 0.25, blade % 2 * 0.8), colors.green, Enum.Material.Grass)
            reed.CFrame = CFrame.new(reed.Position) * CFrame.Angles(0, blade, (blade - 2) * 0.12)
            part("ReedSeedhead", Vector3.new(0.65, 1.3, 0.65), at + Vector3.new((blade - 2.5) * 0.7, 4.5 + blade * 0.5, blade % 2 * 0.8), colors.wood, Enum.Material.Grass)
        end
    end
    for index, row in { { -395, -2, 320 }, { -350, -2, 400 }, { -470, -2, 780 }, { -475, -2, 475 }, { 480, 12, 820 }, { 480, 12, 530 } } do
        local at = v(row)
        for flower = 1, 3 do
            local offset = Vector3.new((flower - 2) * 4, 0, flower % 2 * 3)
            part("CoastalFlowerStem", Vector3.new(0.3, 2.5, 0.3), at + offset + Vector3.new(0, 1.25, 0), colors.green, Enum.Material.Grass)
            local bloom = part("CoastalFlowerBloom", Vector3.new(2.4, 0.8, 2.4), at + offset + Vector3.new(0, 2.7, 0), if index % 2 == 0 then colors.red else colors.yellow)
            bloom.Shape = Enum.PartType.Ball
        end
    end
    for _, row in { { -395, -2, 345 }, { -470, -2, 800 } } do
        local at = v(row)
        part("ShorePicnicTable", Vector3.new(12, 0.75, 6), at + Vector3.new(0, 3, 0), colors.wood, Enum.Material.WoodPlanks)
        for _, side in { -1, 1 } do
            part("PicnicLeg", Vector3.new(1, 3, 5), at + Vector3.new(side * 4, 1.5, 0), colors.cream, Enum.Material.Wood)
            part("PicnicBench", Vector3.new(12, 0.75, 1.5), at + Vector3.new(0, 1.8, side * 4), colors.wood, Enum.Material.WoodPlanks)
        end
    end
    local lighthouse = Vector3.new(409, -4, 365)
    for level = 0, 3 do
        part("LighthouseTower", Vector3.new(15 - level * 2, 9, 15 - level * 2), lighthouse + Vector3.new(0, 4.5 + level * 9, 0), if level % 2 == 0 then colors.cream else colors.red, Enum.Material.Brick)
    end
    local glass = part("LighthouseLantern", Vector3.new(11, 7, 11), lighthouse + Vector3.new(0, 39.5, 0), colors.blue, Enum.Material.Glass)
    glass.Transparency = 0.25
    part("LighthouseRoof", Vector3.new(15, 2, 15), lighthouse + Vector3.new(0, 44, 0), colors.red, Enum.Material.Metal)
    part("LighthouseLamp", Vector3.new(3, 4, 3), lighthouse + Vector3.new(0, 39, 0), colors.yellow, Enum.Material.Neon)
    part("LighthouseDoor", Vector3.new(4, 7, 0.5), lighthouse + Vector3.new(0, 3.5, 7.6), colors.blue, Enum.Material.Wood)
    sign("Lighthouse", lighthouse + Vector3.new(-13, 0, 0), "TIDAL LIGHTHOUSE\nLook for the yellow exit buoys")

    local waterResult = { chunksRead = 0, chunksWritten = 0, voxelsAdded = 0 }
    if terrain ~= false then waterResult = OceanWorld.fillWater(terrain or workspace.Terrain, water) end
    model:SetAttribute("SourcePartCount", count)
    model:SetAttribute("SourcePartBudget", config.partBudget)
    model:SetAttribute("WaterSurfaceY", water.surfaceY)
    local previous = parent:FindFirstChild(config.modelName)
    if previous then
        assert(previous:GetAttribute("OceanSourceOwned") == true, "Refusing to replace unowned ocean scenery")
        previous:Destroy()
    end
    model.Parent = parent
    return { model = model, exits = exits, seafloor = floor, water = waterResult }
end

return OceanWorld
