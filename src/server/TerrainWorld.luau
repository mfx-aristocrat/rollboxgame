local TerrainWorld = {}

function TerrainWorld.build(model, layout)
    local folder = Instance.new("Folder")
    folder.Name, folder.Parent = "ExplorationLandscape", model
    local function block(name, size, position, color, material)
        local p = Instance.new("Part")
        p.Name, p.Size, p.Position = name, size, position
        p.Anchored = true
        p.Color, p.Material = color, material or Enum.Material.SmoothPlastic
        p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
        p.Parent = folder
        return p
    end
    local function vector(value) return Vector3.new(table.unpack(value)) end
    local function rgb(value) return Color3.fromRGB(table.unpack(value)) end
    local wood = Color3.fromRGB(133, 99, 67)
    local function beam(name, a, b, width, height, color, material)
        local frame = CFrame.lookAt((a + b) / 2, b)
        local p = block(name, Vector3.new(width, height, (b - a).Magnitude), Vector3.zero, color, material)
        -- Endpoints describe the walkable upper surface, including on ramps.
        p.CFrame = frame - frame.UpVector * height / 2
        return p
    end
    local function navigation(name, at, text, color)
        local post = block(name .. "Post", Vector3.new(0.7, 7, 0.7), at + Vector3.new(0, 3.5, 0), wood, Enum.Material.Wood)
        local gui = Instance.new("BillboardGui")
        gui.Name, gui.Size = "Navigation", UDim2.fromOffset(240, 76)
        gui.StudsOffsetWorldSpace = Vector3.new(0, 6, 0)
        gui.AlwaysOnTop, gui.MaxDistance = false, 65
        gui.Parent = post
        local label = Instance.new("TextLabel")
        label.Size = UDim2.fromScale(1, 1)
        label.BackgroundColor3, label.BackgroundTransparency = Color3.fromRGB(31, 46, 53), 0.06
        label.Text, label.TextColor3 = text, color
        label.Font, label.TextSize, label.TextWrapped = Enum.Font.GothamBold, 17, true
        label.Parent = gui
    end
    for _, spec in layout.surfaces do
        block(spec.id, vector(spec.size), vector(spec.position), rgb(spec.color), Enum.Material[spec.material])
    end
    for index, path in layout.segments do
        local a, b = vector(path.a), vector(path.b)
        local bridge = path.style == "bridge"
        local color = if bridge then wood else Color3.fromRGB(188, 181, 155)
        local material = if bridge then Enum.Material.WoodPlanks else Enum.Material.Cobblestone
        beam("WalkingPath" .. index, a, b, path.width, 1, color, material)
        if bridge then
            local side = Vector3.new(-(b - a).Z, 0, (b - a).X).Unit * (path.width / 2 - 0.5)
            for _, direction in { -1, 1 } do
                local offset = side * direction
                beam("BridgeRail" .. index, a + offset + Vector3.new(0, 3, 0), b + offset + Vector3.new(0, 3, 0), 0.7, 0.7, wood, Enum.Material.Wood)
                local intervals = math.max(1, math.ceil((b - a).Magnitude / 24))
                for step = 0, intervals do
                    local at = a:Lerp(b, step / intervals) + offset
                    block("BridgePost", Vector3.new(0.8, 3, 0.8), at + Vector3.new(0, 1.5, 0), wood, Enum.Material.Wood)
                end
            end
        end
    end
    -- No flat collidable junction slabs: they would create steps across incoming ramps.
    for _, region in layout.regions do
        local at = vector(layout.nodes[region.node])
        navigation(region.id, at + vector(region.signOffset), region.name .. "\n" .. region.description, rgb(region.color))
    end
    navigation("WestWayfinding", vector(layout.nodes.westEntry) + Vector3.new(0, 0, 14), "EXPLORE ←\nMeadow • Redstone Heights", Color3.fromRGB(172, 235, 145))
    navigation("EastWayfinding", vector(layout.nodes.eastEntry) + Vector3.new(0, 0, 14), "EXPLORE →\nCoast • Frostpeak Uplands", Color3.fromRGB(191, 237, 250))
    for _, spec in layout.props do
        local at, scale = vector(spec.position), spec.scale
        local function piece(name, size, offset, color, material)
            return block(name, size * scale, at + offset * scale, color, material)
        end
        if spec.kind == "tree" or spec.kind == "palm" then
            local palm = spec.kind == "palm"
            piece("TreeTrunk", Vector3.new(3, 17, 3), Vector3.new(0, 8.5, 0), wood, Enum.Material.Wood)
            if palm then
                for index = 0, 3 do
                    local leaf = piece("PalmFrond", Vector3.new(4, 1.5, 18), Vector3.new(0, 17, 0), Color3.fromRGB(66, 136, 83), Enum.Material.Grass)
                    leaf.CFrame *= CFrame.Angles(0, index * math.pi / 2, 0)
                    leaf.CanCollide = false
                end
            else
                local crown = piece("MeadowCanopy", Vector3.new(20, 19, 20), Vector3.new(0, 21, 0), Color3.fromRGB(62, 121, 68), Enum.Material.Grass)
                crown.Shape, crown.CanCollide = Enum.PartType.Ball, false
            end
        elseif spec.kind == "redRock" or spec.kind == "snowRock" then
            local snow = spec.kind == "snowRock"
            local stone = piece("LandscapeBoulder", Vector3.new(27, 32, 25), Vector3.new(0, 10, 0), if snow then Color3.fromRGB(137, 157, 164) else Color3.fromRGB(139, 89, 66), Enum.Material.Rock)
            stone.Shape = Enum.PartType.Ball
            if snow then
                local cap = piece("SnowCap", Vector3.new(26, 9, 24), Vector3.new(0, 23, 0), Color3.fromRGB(238, 249, 250), Enum.Material.Snow)
                cap.Shape = Enum.PartType.Ball
            end
        elseif spec.kind == "lagoon" then
            -- Glass avoids Terrain-only Water material and never modifies workspace.Terrain.
            local water = piece("TidalLagoon", Vector3.new(110, 0.4, 110), Vector3.zero, Color3.fromRGB(52, 164, 191), Enum.Material.Glass)
            water.Transparency, water.CanCollide = 0.28, false
            for _, offset in { Vector3.new(-57, -0.15, 0), Vector3.new(57, -0.15, 0) } do
                piece("LagoonShore", Vector3.new(4, 0.8, 118), offset, Color3.fromRGB(244, 226, 174), Enum.Material.Sand)
            end
        elseif spec.kind == "dock" then
            piece("LagoonBoardwalk", Vector3.new(12, 1, 72), Vector3.new(0, 0, -22), wood, Enum.Material.WoodPlanks)
            for _, x in { -5, 5 } do
                for _, z in { -55, 5 } do
                    piece("DockPiling", Vector3.new(2, 8, 2), Vector3.new(x, -2, z), wood, Enum.Material.Wood)
                end
            end
        elseif spec.kind == "picnic" then
            piece("PicnicTable", Vector3.new(12, 1, 7), Vector3.new(0, 3, 0), wood, Enum.Material.WoodPlanks)
            for _, x in { -4, 4 } do
                piece("TableLeg", Vector3.new(1, 3, 5), Vector3.new(x, 1.5, 0), wood, Enum.Material.Wood)
            end
        elseif spec.kind == "lookout" then
            piece("SummitMarker", Vector3.new(1, 14, 1), Vector3.new(0, 7, 0), Color3.fromRGB(91, 120, 138), Enum.Material.Metal)
            piece("SummitFlag", Vector3.new(7, 4, 0.4), Vector3.new(3.5, 12, 0), Color3.fromRGB(106, 218, 234), Enum.Material.Fabric)
        end
    end
    return folder
end

return TerrainWorld
