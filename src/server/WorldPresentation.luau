local PresentationLayout = require(game:GetService("ReplicatedStorage").Shared.PresentationLayout)
local WorldPresentation = {}
local OWNER = "WorldPresentation/v1"
local OWNER_KEY = "RollboxPresentationOwner"
local PREFIX = "RollboxOriginal"

local materialRoles = {
    grass = { name = "Rollbox_MeadowGrass", material = "Grass", tint = { 245, 250, 239 } },
    rock = { name = "Rollbox_CoastalRock", material = "Rock", tint = { 235, 239, 235 } },
    sandstone = { name = "Rollbox_StrataSandstone", material = "Sandstone", tint = { 239, 226, 204 } },
    path = { name = "Rollbox_FieldstonePath", material = "Cobblestone", tint = { 245, 242, 231 } },
    timber = { name = "Rollbox_WeatheredTimber", material = "WoodPlanks", tint = { 247, 240, 225 } },
    wood = { name = "Rollbox_WeatheredWood", material = "Wood", tint = { 244, 236, 220 } },
}
local decks = { DepotRoof = { 0, 2, 38, 26 }, FirstLane = { 0, -34, 20, 58 }, SafeDetour = { -14, -76, 12, 36 },
    DetourEntry = { -7, -60, 26, 10 }, DetourExit = { -7, -94, 26, 10 }, ShortcutTakeoff = { 0, -65, 10, 6 },
    ShortcutLanding = { 0, -81, 10, 10 }, ShortcutExit = { 0, -92, 10, 8 }, FinalLane = { 0, -125, 20, 66 } }
local hiddenNames = { TreeTrunk = true, MeadowCanopy = true, PalmFrond = true, LandscapeBoulder = true,
    SnowCap = true, RoundedGrassHill = true, HillSpot = true, CloudPuff = true }
local landscapeWood = { BridgePost = true, LagoonBoardwalk = true, DockPiling = true, PicnicTable = true,
    TableLeg = true }
local oceanWood = { RampPost = true, PicnicLeg = true, ShorePicnicTable = true, PicnicBench = true }

local function vector(p) return Vector3.new(table.unpack(p)) end
local function rgb(c) return Color3.fromRGB(table.unpack(c)) end
local function inScope(part, scope)
    return PresentationLayout.inScope({ part.Position.X, part.Position.Y, part.Position.Z }, scope)
end

local function sourceLandscape(child, layout)
    return child:IsA("Folder") and child.Name == "ExplorationLandscape"
        and type(child:GetAttribute("SourcePartCount")) == "number" and child:GetAttribute("SourcePartBudget") == layout.partBudget
end

local function sourceDeck(part, spec, cliff)
    return spec and part.Position == Vector3.new(spec[1], if cliff then 4.5 else 8.5, spec[2])
        and part.Size == Vector3.new(spec[3], if cliff then 6 else 2, spec[4])
end

local function replacedSourceParts(layout)
    local expected = {}
    local function add(name, prop, size, offset)
        local entries = expected[name] or {}
        expected[name] = entries
        table.insert(entries, { position = vector(prop.position) + offset * prop.scale, size = size * prop.scale })
    end
    for _, prop in layout.props do
        if prop.kind == "tree" or prop.kind == "palm" then
            add("TreeTrunk", prop, Vector3.new(3, 17, 3), Vector3.new(0, 8.5, 0))
            if prop.kind == "tree" then add("MeadowCanopy", prop, Vector3.new(20, 19, 20), Vector3.new(0, 21, 0))
            else add("PalmFrond", prop, Vector3.new(4, 1.5, 18), Vector3.new(0, 17, 0)) end
        elseif prop.kind == "redRock" or prop.kind == "snowRock" then
            add("LandscapeBoulder", prop, Vector3.new(27, 32, 25), Vector3.new(0, 10, 0))
            if prop.kind == "snowRock" then add("SnowCap", prop, Vector3.new(26, 9, 24), Vector3.new(0, 23, 0)) end
        elseif prop.kind == "roundHill" then
            add("RoundedGrassHill", prop, Vector3.new(54, 62, 46), Vector3.new(0, 15, 0))
            for _, x in { -9, 9 } do add("HillSpot", prop, Vector3.new(4, 7, 1), Vector3.new(x, 33, 20)) end
        elseif prop.kind == "cloud" then
            for i = -1, 1 do add("CloudPuff", prop, Vector3.new(28, 17 + (if i == 0 then 8 else 0), 18), Vector3.new(i * 17, 0, 0)) end
        end
    end
    return function(part)
        if not hiddenNames[part.Name] then return false end
        for _, spec in expected[part.Name] or {} do
            if (part.Position - spec.position).Magnitude < 0.001 and (part.Size - spec.size).Magnitude < 0.001 then return true end
        end
        return false
    end
end

local function remember(part)
    if part:GetAttribute(OWNER_KEY) == OWNER then return end
    part:SetAttribute(OWNER_KEY, OWNER)
    part:SetAttribute(PREFIX .. "Transparency", part.Transparency)
    part:SetAttribute(PREFIX .. "Color", part.Color)
    part:SetAttribute(PREFIX .. "Variant", part.MaterialVariant)
    local role = part:GetAttribute("VisualRole")
    part:SetAttribute(PREFIX .. "HadRole", role ~= nil)
    part:SetAttribute(PREFIX .. "Role", role)
end

local function restore(root)
    for _, part in root:GetDescendants() do
        if part:IsA("BasePart") and part:GetAttribute(OWNER_KEY) == OWNER then
            part.Transparency = part:GetAttribute(PREFIX .. "Transparency")
            part.Color = part:GetAttribute(PREFIX .. "Color")
            part.MaterialVariant = part:GetAttribute(PREFIX .. "Variant")
            part:SetAttribute("VisualRole", if part:GetAttribute(PREFIX .. "HadRole") then part:GetAttribute(PREFIX .. "Role") else nil)
            for _, suffix in { "Transparency", "Color", "Variant", "HadRole", "Role" } do
                part:SetAttribute(PREFIX .. suffix, nil)
            end
            part:SetAttribute(OWNER_KEY, nil)
        end
    end
end

local function roleForMaterial(part)
    for role, spec in materialRoles do
        if part.Material == Enum.Material[spec.material] then return role end
    end
    return nil
end

-- Does not change a source part's base material, CFrame, size or physical flags.
local function applyMaterials(root, visualConfig, options, stats)
    local scope, layout = options.scope, options.layout
    local surfaces = {}
    for _, spec in layout.surfaces do surfaces[spec.id] = spec end
    local missing = {}
    local function apply(part, role)
        if not inScope(part, scope) then return end
        if role == "sand" then
            remember(part)
            part.Color = Color3.fromRGB(209, 194, 154)
            part:SetAttribute("VisualRole", "sand")
            stats.materialParts += 1
            return
        end
        local defaults = materialRoles[role]
        if not defaults or part.Material ~= Enum.Material[defaults.material] then return end
        local configured = visualConfig.materials and visualConfig.materials[role]
        local name = if configured then configured.name else defaults.name
        local variant = options.materialService and options.materialService:FindFirstChild(name)
        if not variant or not variant:IsA("MaterialVariant") or variant.BaseMaterial ~= part.Material then
            missing[name] = true
            return
        end
        remember(part)
        part.MaterialVariant = name
        local surfaceTint = visualConfig.surfaceTints and visualConfig.surfaceTints[part.Name]
        part.Color = rgb(surfaceTint or (if configured and configured.tint then configured.tint else defaults.tint))
        part:SetAttribute("VisualRole", role)
        stats.materialParts += 1
    end
    for _, child in root:GetChildren() do
        if child:IsA("BasePart") then
            if sourceDeck(child, decks[child.Name], false) then apply(child, "grass")
            elseif string.sub(child.Name, -5) == "Cliff" and sourceDeck(child, decks[string.sub(child.Name, 1, -6)], true) then
                apply(child, "sandstone")
            end
        elseif sourceLandscape(child, layout) then
            for _, part in child:GetChildren() do
                if not part:IsA("BasePart") then continue end
                local source = surfaces[part.Name]
                if source and part.Position == vector(source.position) and part.Size == vector(source.size)
                    and part.Material == Enum.Material[source.material] then
                    local role = roleForMaterial(part)
                    if role then apply(part, role)
                    elseif source.material == "Sand" then apply(part, "sand") end
                elseif string.match(part.Name, "^WalkingPath%d+$") or string.match(part.Name, "^BridgeRail%d+$")
                    or landscapeWood[part.Name] then
                    local role = roleForMaterial(part)
                    if role then apply(part, role) end
                end
            end
        elseif child:IsA("Model") and child.Name == "OceanEnvironment" and child:GetAttribute("OceanSourceOwned") == true then
            for _, part in child:GetChildren() do
                if not part:IsA("BasePart") then continue end
                if part.Name == "OceanShoreRock" then apply(part, "rock")
                elseif oceanWood[part.Name] or string.match(part.Name, "^[%a]+ShoreApproach$")
                    or string.match(part.Name, "^[%a]+SwimRamp$") or string.match(part.Name, "^[%a]+SwimDock$") then
                    local role = roleForMaterial(part)
                    if role then apply(part, role) end
                end
            end
        end
    end
    for name in missing do table.insert(stats.missingVariants, name) end
    table.sort(stats.missingVariants)
end

local function safeTemplate(template, maxParts)
    if not template or not template:IsA("Model") then return false end
    local height = template:GetAttribute("SourceHeight")
    if type(height) ~= "number" or height ~= height or height <= 0 or height == math.huge then return false end
    local count = 0
    for _, child in template:GetDescendants() do
        if child:IsA("BasePart") then count += 1
        elseif not (child:IsA("Model") or child:IsA("Folder") or child:IsA("SurfaceAppearance")
            or child:IsA("Decal") or child:IsA("Texture")) then return false end
    end
    return count > 0 and count <= maxParts
end

function WorldPresentation.apply(root, visualConfig, options)
    assert(root and root:IsA("Model") and root.Name == "SwitchbackWorld", "Expected the source-generated world root")
    assert(options and options.layout, "WorldLayout is required")
    local scope = options.scope or "hero"
    local plan = PresentationLayout.create(options.layout, scope)
    options = table.clone(options)
    options.scope = scope
    local stats = { scope = scope, partCount = 0, templateCount = 0, fallbackCount = 0,
        rockTemplateCount = 0, rockFallbackCount = 0, hiddenParts = 0, materialParts = 0,
        missingVariants = {}, templateFailures = 0 }
    local folder = Instance.new("Folder")
    folder.Name = "WorldPresentation"
    folder:SetAttribute(OWNER_KEY, OWNER)
    folder:SetAttribute("Scope", scope)
    local function part(parent, name, size, frame, color, material, className)
        assert(stats.partCount < plan.partBudget, "Presentation part budget exceeded")
        local p = Instance.new(className or "Part")
        p.Name, p.Size, p.CFrame = name, size, frame
        p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
        p.Color, p.Material = color, material
        p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
        p:SetAttribute("VisualRole", name)
        p.Parent = parent
        stats.partCount += 1
        return p
    end
    local function model(spec)
        local m = Instance.new("Model")
        m.Name = spec.id
        m:SetAttribute("SourceX", spec.position[1])
        m:SetAttribute("SourceZ", spec.position[3])
        m.Parent = folder
        return m, CFrame.new(vector(spec.position)) * CFrame.Angles(0, spec.yaw, 0)
    end
    local function cloneTemplate(template, spec, frame, targetHeight, role, meshRole, maxParts)
        if safeTemplate(template, maxParts) then
            local clone = template:Clone()
            local factor = targetHeight * spec.scale / template:GetAttribute("SourceHeight")
            local ok = pcall(function()
                if options.placeModel then options.placeModel(clone, factor, frame)
                else clone:ScaleTo(factor); clone:PivotTo(frame) end
            end)
            if ok then
                clone.Name = spec.id
                clone:SetAttribute("VisualRole", role)
                clone:SetAttribute("SourceX", spec.position[1])
                clone:SetAttribute("SourceZ", spec.position[3])
                for _, p in clone:GetDescendants() do
                    if p:IsA("BasePart") then
                        stats.partCount += 1
                        assert(stats.partCount <= plan.partBudget, "Presentation template part budget exceeded")
                        p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
                        p:SetAttribute("VisualRole", meshRole)
                    end
                end
                clone.Parent = folder
                return clone
            end
            clone:Destroy()
            stats.templateFailures += 1
        end
        return nil
    end
    local function tree(spec)
        local palm = spec.kind == "palm"
        local template = options.templates and options.templates:FindFirstChild(if palm then "Palm" else "Oak")
        -- The curved generated palm's visual trunk root sits above its bounding
        -- box minimum; a small authored inset removes that visible ground gap.
        local frame = CFrame.new(vector(spec.position) - Vector3.new(0, if palm then 2.4 * spec.scale else 0, 0))
            * CFrame.Angles(0, spec.yaw, 0)
        if cloneTemplate(template, spec, frame, if palm then 30 else 32, if palm then "palm" else "oak", "treeMesh", 16) then
            stats.templateCount += 1
            return
        end
        stats.fallbackCount += 1
        local m, base = model(spec)
        local scale = spec.scale
        local wood = rgb(visualConfig.palette.timber)
        local function beam(name, a, b, width)
            local av, bv = base:PointToWorldSpace(a * scale), base:PointToWorldSpace(b * scale)
            return part(m, name, Vector3.new(width * scale, width * scale, (bv - av).Magnitude),
                CFrame.lookAt((av + bv) / 2, bv), wood, Enum.Material.Wood)
        end
        if spec.kind == "palm" then
            for i = 0, 2 do beam("PalmBark", Vector3.new(i * 0.7, i * 7, 0), Vector3.new((i + 1) * 0.7, (i + 1) * 7, 0), 1.8 - i * 0.25) end
            for i = 0, 5 do
                local angle = i * math.pi / 3
                local dx, dz = math.cos(angle), math.sin(angle)
                for segment = 1, 2 do
                    local frame = base * CFrame.new((2.1 + dx * (segment * 4 - 1)) * scale,
                        (22 - segment * 1.3) * scale, dz * (segment * 4 - 1) * scale)
                        * CFrame.Angles(0, -angle, -0.18 * segment)
                    part(m, "PalmLeaf", Vector3.new(6, 0.35, if segment == 1 then 3 else 2) * scale,
                        frame, rgb(if i % 2 == 0 then visualConfig.palette.grassDark else visualConfig.palette.grass), Enum.Material.Grass, "WedgePart")
                end
            end
        else
            beam("TreeBark", Vector3.zero, Vector3.new(0.7, 18, 0), 2.4)
            for i = 0, 2 do
                local angle = i * math.pi * 2 / 3 + 0.4
                beam("TreeBranch", Vector3.new(0.3, 10 + i, 0), Vector3.new(math.cos(angle) * 6, 21 + i, math.sin(angle) * 6), 1.1)
            end
            for i = 0, 5 do
                local angle = i * 2.399963
                local frame = base * CFrame.new(math.cos(angle) * 5.3 * scale, (23 + i % 3 * 2.3) * scale, math.sin(angle) * 5.3 * scale)
                local crown = part(m, "OakLeaves", Vector3.new(12 - i % 2, 8, 11) * scale, frame,
                    rgb(if i % 2 == 0 then visualConfig.palette.grassDark else visualConfig.palette.grass), Enum.Material.Grass)
                crown.Shape = Enum.PartType.Ball
            end
        end
    end
    for _, spec in plan.trees do tree(spec) end
    for _, spec in plan.rocks do
        local template = options.templates and options.templates:FindFirstChild("Boulder")
        local rockBase = CFrame.new(vector(spec.position)) * CFrame.Angles(0, spec.yaw, 0)
        local clone = cloneTemplate(template, spec, rockBase, 8, "boulder", "rockMesh", 2)
        if clone then
            stats.rockTemplateCount += 1
            for _, p in clone:GetDescendants() do
                if p:IsA("BasePart") then
                    p.Color = if spec.warm then Color3.fromRGB(241, 226, 206) else Color3.new(1, 1, 1)
                end
            end
            if spec.snow then
                for i = 0, 1 do
                    local capFrame = rockBase * CFrame.new((i - 0.5) * 2.6 * spec.scale, (6.8 - i * 0.3) * spec.scale, 0)
                        * CFrame.Angles(0, i * 1.2, 0.06 * (i * 2 - 1))
                    part(clone, "SnowLedge", Vector3.new(6, 0.8, 6) * spec.scale, capFrame,
                        rgb(visualConfig.palette.snow), Enum.Material.Snow, "WedgePart")
                end
            end
            continue
        end
        stats.rockFallbackCount += 1
        local m, base = model(spec)
        for i = 0, 3 do
            local scale = spec.scale * (1 - i * 0.16)
            local size = Vector3.new(9 + i % 2 * 2, 6 + i % 3 * 2, 8 + (i + 1) % 2 * 3) * scale
            local frame = base * CFrame.new((i - 1.5) * 3.4 * spec.scale, size.Y * 0.36, (i % 2 - 0.5) * 4 * spec.scale)
                * CFrame.Angles(0.09 * (i - 1), i * 0.74, 0.1 * (i % 2 - 0.5))
            local stone = part(m, "FacetedRock", size, frame, rgb(if spec.warm then visualConfig.palette.stoneWarm else visualConfig.palette.stone),
                Enum.Material.Rock, if i % 2 == 0 then "WedgePart" else "Part")
            local variant = options.materialService and options.materialService:FindFirstChild("Rollbox_CoastalRock")
            if variant and variant:IsA("MaterialVariant") and variant.BaseMaterial == Enum.Material.Rock then
                stone.MaterialVariant, stone.Color = variant.Name, Color3.fromRGB(239, 239, 232)
            end
            if spec.snow and i < 2 then
                part(m, "SnowLedge", Vector3.new(size.X * 0.8, 0.8, size.Z * 0.8), frame + Vector3.new(0, size.Y * 0.48, 0),
                    rgb(visualConfig.palette.snow), Enum.Material.Snow, "WedgePart")
            end
        end
    end
    for _, spec in plan.plants do
        local m, base = model(spec)
        for i = 0, 5 do
            local angle = i * math.pi / 3
            local frame = base * CFrame.Angles(0, angle, 0) * CFrame.new(1.2 * spec.scale, 0.6 * spec.scale, 0)
                * CFrame.Angles(0, 0, 0.32)
            local p = part(m, "FernLeaf", Vector3.new(3, 0.2, 1.1) * spec.scale, frame,
                rgb(if i % 2 == 0 then visualConfig.palette.grassDark else visualConfig.palette.grass), Enum.Material.Grass, "WedgePart")
            p.CastShadow = false
        end
    end
    folder:SetAttribute("PartCount", stats.partCount)
    folder:SetAttribute("PartBudget", plan.partBudget)
    -- Build first, then replace only our marked folder and undo previous scope.
    for _, old in root:GetChildren() do
        if old.Name == folder.Name and old:GetAttribute(OWNER_KEY) == OWNER then old:Destroy() end
    end
    restore(root)
    applyMaterials(root, visualConfig, options, stats)
    local replaceSource = replacedSourceParts(options.layout)
    for _, landscape in root:GetChildren() do
        local isLandscape = sourceLandscape(landscape, options.layout)
        local isOcean = landscape.Name == "OceanEnvironment" and landscape:IsA("Model")
            and landscape:GetAttribute("OceanSourceOwned") == true
        if not isLandscape and not isOcean then continue end
        for _, p in landscape:GetChildren() do
            if p:IsA("BasePart") and ((isLandscape and replaceSource(p)) or (isOcean and p.Name == "OceanShoreRock"))
                and not p.CanCollide and inScope(p, scope) then
                remember(p)
                p.Transparency = 1
                p:SetAttribute("VisualRole", "replacedScenery")
                stats.hiddenParts += 1
            end
        end
    end
    folder.Parent, stats.folder = root, folder
    return stats
end

return WorldPresentation
