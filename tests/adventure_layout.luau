local Config = require("../src/shared/Config")
local WorldLayout = require("../src/shared/WorldLayout")
local AdventureLayout = require("../src/shared/AdventureLayout")
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

return function()
    local count = 0
    local function test(name, fn)
        local ok, err = pcall(fn)
        assert(ok, name .. ": " .. tostring(err))
        count += 1
    end
    local world, adventure = WorldLayout.create(Config), AdventureLayout.create(Config)
    local function finite(n) return type(n) == "number" and n == n and math.abs(n) < math.huge end
    -- Independent world geometry query: rendered paths have flat approaches already expanded.
    local function supportTop(position)
        local highest = -math.huge
        for _, surface in world.surfaces do
            local p, s = surface.position, surface.size
            if math.abs(position[1] - p[1]) <= s[1] / 2 and math.abs(position[3] - p[3]) <= s[3] / 2 then
                highest = math.max(highest, p[2] + s[2] / 2)
            end
        end
        for _, path in world.segments do
            local a, b = path.a, path.b
            local dx, dz = b[1] - a[1], b[3] - a[3]
            local length = math.sqrt(dx * dx + dz * dz)
            local along = ((position[1] - a[1]) * dx + (position[3] - a[3]) * dz) / length
            local across = math.abs((position[1] - a[1]) * dz - (position[3] - a[3]) * dx) / length
            if along >= -0.00001 and along <= length + 0.00001 and across <= path.width / 2 then
                highest = math.max(highest, a[2] + (b[2] - a[2]) * math.clamp(along / length, 0, 1))
            end
        end
        return highest
    end
    test("bounded unique deterministic items and springs", function()
        local again = AdventureLayout.create(Config)
        local ids, kinds = {}, { token = 0, crate = 0, landmark = 0 }
        assert(#adventure.items <= 60 and #adventure.springs >= 4 and #adventure.springs <= 8)
        assert(adventure.partBudget <= 240)
        for index, spec in adventure.items do
            assert(type(spec.id) == "string" and not ids[spec.id] and kinds[spec.kind] ~= nil)
            ids[spec.id], kinds[spec.kind] = true, kinds[spec.kind] + 1
            assert(finite(spec.score) and spec.score > 0 and spec.score % 1 == 0)
            assert(spec.score == ({ token = 1, crate = 5, landmark = 10 })[spec.kind], "fixed public reward catalog mismatch")
            assert(spec.id == again.items[index].id and spec.score == again.items[index].score)
            for axis = 1, 3 do
                assert(finite(spec.position[axis]) and spec.position[axis] == again.items[index].position[axis])
            end
        end
        assert(kinds.token >= 24 and kinds.crate >= 4 and kinds.landmark >= 6)
        for index, spring in adventure.springs do
            assert(not ids[spring.id] and finite(spring.launchSpeed) and spring.launchSpeed >= 60 and spring.launchSpeed <= 80)
            ids[spring.id] = true
            assert(spring.id == again.springs[index].id)
            for axis = 1, 3 do assert(finite(spring.position[axis]) and spring.position[axis] == again.springs[index].position[axis]) end
        end
    end)
    test("every reward sits above a reachable walking surface and outside Training", function()
        for _, spec in adventure.items do
            local p, top = spec.position, supportTop(spec.position)
            assert(top > -math.huge, spec.id .. " has no walking surface")
            local clearance = p[2] - top
            assert(clearance >= 1.7 and clearance <= 4, spec.id .. " buried or beyond ordinary collection reach: " .. clearance)
            local b, c = world.bounds, world.courseClearance
            assert(p[1] >= b.minX + 3 and p[1] <= b.maxX - 3 and p[3] >= b.minZ + 3 and p[3] <= b.maxZ - 3)
            assert(not (p[1] >= c.minX - 4 and p[1] <= c.maxX + 4 and p[3] >= c.minZ - 4 and p[3] <= c.maxZ + 4))
            assert(math.sqrt((p[1] - Config.pickup.position[1])^2 + (p[3] - Config.pickup.position[3])^2) >= 30)
        end
    end)
    test("all rewards have a connected ordinary walking route with no spring dependency", function()
        local reached = { hub = true }
        for _ = 1, #world.paths do
            for _, path in world.paths do
                if reached[path.a] then reached[path.b] = true end
                if reached[path.b] then reached[path.a] = true end
            end
        end
        for _, spec in adventure.items do
            local nearby = false
            for _, path in world.segments do
                local a, b, p = path.a, path.b, spec.position
                local dx, dz = b[1] - a[1], b[3] - a[3]
                local t = math.clamp(((p[1] - a[1]) * dx + (p[3] - a[3]) * dz) / (dx * dx + dz * dz), 0, 1)
                local distance = math.sqrt((p[1] - a[1] - t * dx)^2 + (p[3] - a[3] - t * dz)^2)
                if distance <= path.width / 2 then nearby = true end
            end
            assert(nearby, spec.id .. " requires leaving the accessible path network")
        end
        for id in world.nodes do assert(reached[id], "isolated path component: " .. id) end
    end)
    test("spring pads touch safe ground and do not form path walls", function()
        for _, spring in adventure.springs do
            local top = supportTop(spring.position)
            assert(top > -math.huge and math.abs(spring.position[2] - 0.6 - top) < 0.01, spring.id .. " floats or is buried")
            -- 1.2-stud pad with noncolliding surface markings is a normal Humanoid step.
            assert(spring.position[2] + 0.6 - top <= 1.25)
        end
    end)
    test("configuration origin translates every interactive consistently", function()
        local config = { route = { depot = { 100, 22, -200 } } }
        local moved = AdventureLayout.create(config)
        for _, key in { "items", "springs" } do
            for index, spec in adventure[key] do
                local p = moved[key][index].position
                assert(p[1] - spec.position[1] == 100 and math.abs(p[2] - spec.position[2] - 10) < 0.00001 and p[3] - spec.position[3] == -200)
            end
        end
    end)
    test("native scene builders respect collision budgets prompts and personal visibility tags", function()
        -- Lune's real Roblox serialization datatypes/property schema, not Studio physics.
        local environment = {
            Instance = roblox.Instance, Enum = roblox.Enum, CFrame = roblox.CFrame,
            Vector3 = roblox.Vector3, Color3 = roblox.Color3, UDim2 = roblox.UDim2,
        }
        local terrainBuilder = luau.load(fs.readFile("src/server/TerrainWorld.luau"), { injectGlobals = true, environment = environment })()
        local adventureBuilder = luau.load(fs.readFile("src/server/AdventureWorld.luau"), { injectGlobals = true, environment = environment })()
        local root = roblox.Instance.new("Model")
        local terrain = terrainBuilder.build(root, world)
        assert(terrain:GetAttribute("SourcePartCount") <= world.partBudget)
        local surfaces = {}
        for _, surface in world.surfaces do surfaces[surface.id] = true end
        for _, part in terrain:GetDescendants() do
            if part:IsA("BasePart") then
                assert(part.Anchored and not part.CanTouch)
                local walkable = surfaces[part.Name] or string.match(part.Name, "^WalkingPath") or part.Name == "LagoonBoardwalk" or part.Name == "DockPiling"
                assert(part.CanCollide == not not walkable, "unexpected scenery collision: " .. part.Name)
            end
        end
        local result = adventureBuilder.build(root, adventure)
        assert(#result.items == #adventure.items and #result.springs == #adventure.springs)
        assert(result.root:GetAttribute("SourcePartCount") <= adventure.partBudget)
        for _, entry in result.items do
            for _, part in entry.part.Parent:GetDescendants() do
                if part:IsA("BasePart") then
                    assert(part.Anchored and not part.CanCollide and not part.CanTouch)
                    assert(part:GetAttribute("AdventureId") == entry.spec.id, "personal completion must hide every visual")
                end
            end
            if entry.spec.kind == "crate" then
                assert(entry.prompt and entry.prompt.ActionText == "Open crate" and entry.prompt.HoldDuration == 0)
            else
                assert(not entry.prompt, "walking collection must not need a prompt")
            end
        end
        for _, entry in result.springs do assert(entry.part.CanCollide and entry.part.Anchored and not entry.part.CanTouch) end
        adventureBuilder.build(root, adventure)
        local roots = 0
        for _, child in root:GetChildren() do if child.Name == "PlatformerAdventure" then roots += 1 end end
        assert(roots == 1, "rebuild must not duplicate adventure objects")
        root:Destroy()
    end)
    return count
end
