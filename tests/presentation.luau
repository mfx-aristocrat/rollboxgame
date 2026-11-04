local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local Config = require("../src/shared/Config")
local WorldLayout = require("../src/shared/WorldLayout")
local PresentationLayout = require("../src/shared/PresentationLayout")
local VisualConfig = require("../src/shared/VisualConfig")

return function()
    local cases = 0
    local function test(name, fn)
        local ok, err = pcall(fn)
        assert(ok, name .. ": " .. tostring(err))
        cases += 1
    end
    local modules = {
        WorldLayout = WorldLayout, PresentationLayout = PresentationLayout,
        AdventureLayout = require("../src/shared/AdventureLayout"),
        PowerupConfig = require("../src/shared/PowerupConfig"), BlasterConfig = require("../src/shared/BlasterConfig"),
        OceanConfig = require("../src/shared/OceanConfig"), VisualConfig = VisualConfig,
        LightingPresentation = { apply = function() end }, WorldPresentation = { apply = function() end },
    }
    local shared, server = {}, {}
    for _, name in { "WorldLayout", "PresentationLayout", "AdventureLayout", "PowerupConfig", "BlasterConfig", "OceanConfig", "VisualConfig" } do shared[name] = name end
    for _, name in { "TerrainWorld", "AdventureWorld", "PowerupWorld", "BlasterWorld", "OceanWorld", "LightingPresentation", "WorldPresentation" } do server[name] = name end
    local materialService = roblox.Instance.new("MaterialService")
    for _, row in { { "Rollbox_MeadowGrass", "Grass" }, { "Rollbox_CoastalRock", "Rock" },
        { "Rollbox_StrataSandstone", "Sandstone" }, { "Rollbox_FieldstonePath", "Cobblestone" },
        { "Rollbox_WeatheredTimber", "WoodPlanks" }, { "Rollbox_WeatheredWood", "Wood" } } do
        local variant = roblox.Instance.new("MaterialVariant")
        variant.Name, variant.BaseMaterial, variant.Parent = row[1], roblox.Enum.Material[row[2]], materialService
    end
    local environment = {
        Instance = roblox.Instance, Enum = roblox.Enum, Vector3 = roblox.Vector3, Color3 = roblox.Color3,
        CFrame = roblox.CFrame, UDim = roblox.UDim, UDim2 = roblox.UDim2,
        workspace = roblox.Instance.new("Folder"), script = { Parent = server },
        require = function(key) return assert(modules[key], tostring(key)) end,
        game = { GetService = function(_, name)
            if name == "ReplicatedStorage" then return { Shared = shared } end
            if name == "MaterialService" then return materialService end
            return roblox.Instance.new("Folder")
        end },
    }
    local function load(path)
        return luau.load(fs.readFile(path), { injectGlobals = true, environment = environment })()
    end
    for _, name in { "TerrainWorld", "AdventureWorld", "PowerupWorld", "BlasterWorld" } do
        modules[name] = load("src/server/" .. name .. ".luau")
    end
    local ocean = load("src/server/OceanWorld.luau")
    modules.OceanWorld = { build = function(parent, config) return ocean.build(parent, config, false) end }
    local root = load("src/server/World.luau").build(Config).model
    local presentation = load("src/server/WorldPresentation.luau")
    local layout = WorldLayout.create(Config)
    local function options(scope)
        return { scope = scope, layout = layout, materialService = materialService }
    end
    local physicalProperties = { "CanCollide", "CanQuery", "CanTouch", "Anchored", "Size", "CFrame", "Material",
        "CustomPhysicalProperties", "CollisionGroup", "Massless", "Reflectance", "CastShadow" }
    local originals = {}
    local collidable = 0
    for _, p in root:GetDescendants() do
        if not p:IsA("BasePart") then continue end
        local entry = { part = p, name = p.Name, parent = p.Parent, properties = {}, Color = p.Color,
            Transparency = p.Transparency, MaterialVariant = p.MaterialVariant }
        for _, key in physicalProperties do entry.properties[key] = p[key] end
        originals[p] = entry
        if p.CanCollide then collidable += 1 end
    end
    assert(collidable == 155, "The regression baseline must cover all original 155 collidable parts")
    local hero
    test("hero affects only its authored area and preserves every original physical field", function()
        hero = presentation.apply(root, VisualConfig, options("hero"))
        print(`Hero fallback: {hero.partCount} decorative Parts, {hero.materialParts} material Parts, {hero.hiddenParts} replaced Parts`)
        assert(hero.partCount > 0 and hero.partCount <= 700 and hero.hiddenParts > 0)
        assert(hero.materialParts > 20 and #hero.missingVariants == 0)
        for p, original in originals do
            assert(p.Parent == original.parent and p.Name == original.name, "source geometry removed or renamed")
            for key, value in original.properties do assert(p[key] == value, p.Name .. " changed " .. key) end
            if not PresentationLayout.inScope({ p.Position.X, p.Position.Y, p.Position.Z }, "hero") then
                assert(p.Color == original.Color and p.Transparency == original.Transparency and p.MaterialVariant == original.MaterialVariant,
                    p.Name .. " outside hero was changed")
            end
            if p.CanCollide then assert(p.Transparency == original.Transparency, "a collidable source surface was hidden") end
        end
        local original = root.ExplorationLandscape.CoastBeach
        assert(original.Color == roblox.Color3.fromRGB(209, 194, 154) and original.Material == roblox.Enum.Material.Sand)
        assert(root.DepotRoof.MaterialVariant == "Rollbox_MeadowGrass")
        assert(root.ExplorationLandscape.WalkingPath12.MaterialVariant == "Rollbox_FieldstonePath")
    end)
    test("new scenery is bounded, grounded and clear of paths and all exploration items", function()
        local count = 0
        for _, p in hero.folder:GetDescendants() do
            if not p:IsA("BasePart") then continue end
            count += 1
            assert(p.Anchored and not p.CanCollide and not p.CanQuery and not p.CanTouch)
            assert(p:GetAttribute("VisualRole") ~= nil)
        end
        assert(count == hero.partCount and count == hero.folder:GetAttribute("PartCount"))
        for _, scope in { "hero", "all" } do
            local plan = PresentationLayout.create(layout, scope)
            for _, list in { plan.trees, plan.rocks, plan.plants } do
                for _, spec in list do
                    assert(PresentationLayout.inScope(spec.position, scope))
                    assert(PresentationLayout.clearOfPaths(layout, spec.position, spec.radius), spec.id .. " hides a path")
                    for _, item in modules.AdventureLayout.create(Config).items do
                        local a, b = spec.position, item.position
                        assert(math.sqrt((a[1] - b[1])^2 + (a[3] - b[3])^2) >= spec.radius + 5, spec.id .. " crowds " .. item.id)
                    end
                    local grounded = false
                    for _, surface in layout.surfaces do
                        local p, size = surface.position, surface.size
                        if math.abs(spec.position[1] - p[1]) <= size[1] / 2 and math.abs(spec.position[3] - p[3]) <= size[3] / 2
                            and math.abs(spec.position[2] - (p[2] + size[2] / 2)) < 0.01 then grounded = true end
                    end
                    assert(grounded, spec.id .. " has no source ground")
                end
            end
        end
    end)
    test("parcel, gates, mushrooms, adventure rewards and signs retain original presentation", function()
        for p, original in originals do
            local ancestor = p.Parent
            local protected = ancestor ~= root and ancestor.Name ~= "ExplorationLandscape" and ancestor.Name ~= "OceanEnvironment"
            if protected or string.match(p.Name, "^Gate") or string.match(p.Name, "^Parcel") or p:IsA("SpawnLocation")
                or p.Name == "LighthouseDoor" or p.Name == "LighthouseTower" or p.Name == "OceanExitBuoy" then
                assert(p.Color == original.Color and p.MaterialVariant == original.MaterialVariant and p.Transparency == original.Transparency,
                    p.Name .. " gameplay cue was restyled")
            end
        end
    end)
    local collisionFolder = roblox.Instance.new("Folder")
    collisionFolder.Name, collisionFolder.Parent = "WorldPresentation", root
    local unrelated = roblox.Instance.new("Part")
    unrelated.Name, unrelated.Parent = "MeadowCanopy", collisionFolder
    local unrelatedLandscape = roblox.Instance.new("Folder")
    unrelatedLandscape.Name, unrelatedLandscape.Parent = "ExplorationLandscape", root
    local unrelatedTree = roblox.Instance.new("Part")
    unrelatedTree.Name, unrelatedTree.CanCollide, unrelatedTree.Parent = "MeadowCanopy", false, unrelatedLandscape
    local unrelatedDeck = roblox.Instance.new("Part")
    unrelatedDeck.Name, unrelatedDeck.Material, unrelatedDeck.Parent = "DepotRoof", roblox.Enum.Material.Grass, root
    unrelatedDeck.Position, unrelatedDeck.Size = roblox.Vector3.new(3, 4, 5), roblox.Vector3.one
    local unrelatedBoulder = roblox.Instance.new("Part")
    unrelatedBoulder.Name, unrelatedBoulder.CanCollide, unrelatedBoulder.Parent = "LandscapeBoulder", false, root.ExplorationLandscape
    unrelatedBoulder.Position, unrelatedBoulder.Size = roblox.Vector3.new(3, 4, 5), roblox.Vector3.one
    test("repeated apply cleans only marked owned scenery and is deterministic", function()
        local before = hero.folder
        local function signature(folder)
            local result = {}
            for _, p in folder:GetDescendants() do
                if p:IsA("BasePart") then
                    local values = { p.Parent.Name, p.Name, tostring(p.Size), tostring(p.Color) }
                    for _, value in { p.CFrame:GetComponents() } do table.insert(values, string.format("%.6f", value)) end
                    table.insert(result, table.concat(values, "/"))
                end
            end
            table.sort(result)
            return table.concat(result, "\n")
        end
        local positions = signature(before)
        local count = hero.partCount
        hero = presentation.apply(root, VisualConfig, options("hero"))
        assert(before.Parent == nil and collisionFolder.Parent == root and unrelated.Parent == collisionFolder)
        assert(unrelatedTree.Transparency == 0 and unrelatedTree.Parent == unrelatedLandscape)
        assert(unrelatedDeck.MaterialVariant == "" and unrelatedDeck:GetAttribute("VisualRole") == nil)
        assert(unrelatedBoulder.Transparency == 0 and unrelatedBoulder:GetAttribute("VisualRole") == nil)
        assert(hero.partCount == count, "repeat part count changed")
        assert(signature(hero.folder) == positions, "repeat geometry/appearance changed")
        local owned = 0
        for _, child in root:GetChildren() do
            if child.Name == "WorldPresentation" and child:IsA("Folder")
                and child:GetAttribute("RollboxPresentationOwner") == "WorldPresentation/v1" then owned += 1 end
        end
        assert(owned == 1)
    end)
    test("all-region fallback respects budget and narrowing scope restores out-of-scope appearance", function()
        local all = presentation.apply(root, VisualConfig, options("all"))
        print(`All fallback: {all.partCount} decorative Parts, {all.materialParts} material Parts, {all.hiddenParts} replaced Parts`)
        assert(all.partCount <= 700 and all.partCount > hero.partCount and all.fallbackCount > hero.fallbackCount)
        assert(root.ExplorationLandscape.MeadowGrass.MaterialVariant == "Rollbox_MeadowGrass")
        assert(root.ExplorationLandscape.RedstoneTerrace.Color == roblox.Color3.fromRGB(table.unpack(VisualConfig.surfaceTints.RedstoneTerrace)))
        hero = presentation.apply(root, VisualConfig, options("hero"))
        for p, original in originals do
            if not PresentationLayout.inScope({ p.Position.X, p.Position.Y, p.Position.Z }, "hero") then
                assert(p.Color == original.Color and p.Transparency == original.Transparency and p.MaterialVariant == original.MaterialVariant)
            end
        end
    end)
    test("native template path scales normalized source meshes through the explicit engine boundary", function()
        local templates = roblox.Instance.new("Folder")
        for _, name in { "Oak", "Palm" } do
            local model = roblox.Instance.new("Model")
            model.Name = name
            model:SetAttribute("SourceHeight", 10)
            local trunk = roblox.Instance.new("MeshPart")
            trunk.Name, trunk.Size, trunk.Position, trunk.Parent = "AuthoredMesh", roblox.Vector3.new(2, 10, 2), roblox.Vector3.new(0, 5, 0), model
            model.Parent = templates
        end
        local called = 0
        local opt = options("hero")
        opt.templates = templates
        opt.placeModel = function(model, factor, frame)
            called += 1
            assert(factor == 3, "hero palm target height must be 30")
            for _, p in model:GetDescendants() do
                if p:IsA("BasePart") then p.Size *= factor; p.CFrame = frame * roblox.CFrame.new(p.Position * factor) end
            end
        end
        local actual = presentation.apply(root, VisualConfig, opt)
        assert(called > 0 and actual.templateCount == called and actual.fallbackCount == 0)
        assert(actual.templateFailures == 0 and actual.partCount <= 700)
        assert(templates.Palm.AuthoredMesh.Size.Y == 10, "source templates must remain untouched")
        for _, p in actual.folder:GetDescendants() do
            if p:IsA("BasePart") then assert(p.Anchored and not p.CanCollide and not p.CanTouch and not p.CanQuery) end
        end
        templates:Destroy()
    end)
    test("native boulders replace blocks, palm roots inset, and oversized rock templates fall back", function()
        local templates = roblox.Instance.new("Folder")
        for _, name in { "Palm", "Boulder" } do
            local m = roblox.Instance.new("Model")
            m.Name = name
            m:SetAttribute("SourceHeight", 10)
            local p = roblox.Instance.new("MeshPart")
            p.Name, p.Size, p.Position, p.Parent = "Mesh", roblox.Vector3.new(8, 10, 8), roblox.Vector3.new(0, 5, 0), m
            m.Parent = templates
        end
        local opt = options("hero")
        opt.templates = templates
        local palms, rocks = 0, 0
        opt.placeModel = function(m, factor, frame)
            if m.Name == "Palm" then
                palms += 1
                assert(math.abs(frame.Position.Y - (-4 - 2.4)) < 0.001, "palm roots must be inset into sand")
            else
                rocks += 1
                assert(m.Name == "Boulder" and factor > 0 and factor <= 2)
            end
            for _, p in m:GetDescendants() do
                if p:IsA("BasePart") then p.Size *= factor; p.CFrame = frame * roblox.CFrame.new(p.Position * factor) end
            end
        end
        local actual = presentation.apply(root, VisualConfig, opt)
        assert(palms > 0 and rocks > 0 and actual.rockTemplateCount == rocks and actual.rockFallbackCount == 0)
        assert(actual.templateCount == palms and actual.templateFailures == 0)
        assert(templates.Boulder.Mesh.Size.Y == 10)
        assert(not actual.folder:FindFirstChild("FacetedRock", true))
        for i = 1, 2 do local p = roblox.Instance.new("Part"); p.Parent = templates.Boulder end
        actual = presentation.apply(root, VisualConfig, opt)
        assert(actual.rockTemplateCount == 0 and actual.rockFallbackCount == rocks)
        templates:Destroy()
    end)
    test("missing/unsafe templates and failed native transforms use deterministic fallback", function()
        local templates = roblox.Instance.new("Folder")
        local unsafe = roblox.Instance.new("Model")
        unsafe.Name = "Palm"
        unsafe:SetAttribute("SourceHeight", 20)
        local script = roblox.Instance.new("Script")
        script.Parent, unsafe.Parent = unsafe, templates
        local opt = options("hero")
        opt.templates = templates
        opt.placeModel = function() error("unsafe template must not reach native transform") end
        local actual = presentation.apply(root, VisualConfig, opt)
        assert(actual.templateCount == 0 and actual.fallbackCount > 0 and actual.templateFailures == 0)
        script:Destroy()
        local mesh = roblox.Instance.new("MeshPart")
        mesh.Parent = unsafe
        opt.placeModel = function() error("native engine failure") end
        actual = presentation.apply(root, VisualConfig, opt)
        assert(actual.templateCount == 0 and actual.templateFailures == actual.fallbackCount)
        templates:Destroy()
    end)
    test("incorrect material bases are rejected and absence never clears source appearance", function()
        materialService.Rollbox_MeadowGrass.BaseMaterial = roblox.Enum.Material.Rock
        local actual = presentation.apply(root, VisualConfig, options("hero"))
        assert(root.DepotRoof.MaterialVariant == originals[root.DepotRoof].MaterialVariant)
        assert(table.find(actual.missingVariants, "Rollbox_MeadowGrass"))
        assert(root.DepotRoof.Material == roblox.Enum.Material.Grass)
        local before = actual.folder
        local opt = options("invalid")
        assert(not pcall(presentation.apply, root, VisualConfig, opt))
        assert(before.Parent == root, "invalid scope must not mutate the world")
    end)
    root:Destroy()
    materialService:Destroy()
    print("Presentation: 155 source colliders preserved; hero/all budgets, fallback and native-template boundary checked")
    return cases
end
