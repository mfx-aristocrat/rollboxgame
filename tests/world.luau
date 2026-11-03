local Config = require("../src/shared/Config")
local WorldLayout = require("../src/shared/WorldLayout")

return function()
    local count = 0
    local function test(name, fn)
        local ok, err = pcall(fn)
        assert(ok, name .. ": " .. tostring(err))
        count += 1
    end
    local layout = WorldLayout.create(Config)
    local function finite(value) return type(value) == "number" and value == value and math.abs(value) < math.huge end
    local function within(x, z, margin)
        local b = layout.bounds
        return x - margin >= b.minX and x + margin <= b.maxX and z - margin >= b.minZ and z + margin <= b.maxZ
    end
    local function intersects(x, z, halfX, halfZ, area)
        return x + halfX > area.minX and x - halfX < area.maxX and z + halfZ > area.minZ and z - halfZ < area.maxZ
    end
    local function distanceToSegment(point, a, b)
        local dx, dz = b[1] - a[1], b[3] - a[3]
        local t = math.clamp(((point[1] - a[1]) * dx + (point[3] - a[3]) * dz) / (dx * dx + dz * dz), 0, 1)
        return math.sqrt((point[1] - a[1] - dx * t)^2 + (point[3] - a[3] - dz * t)^2)
    end
    test("bounded finite deterministic source geometry", function()
        local again = WorldLayout.create(Config)
        assert(#layout.surfaces == #again.surfaces and #layout.paths == #again.paths and #layout.props == #again.props)
        assert(#layout.surfaces <= 24 and #layout.paths <= 32 and #layout.props <= 60, "generation budget exceeded")
        for index, surface in layout.surfaces do
            for axis = 1, 3 do
                assert(finite(surface.position[axis]) and finite(surface.size[axis]) and surface.size[axis] > 0)
                assert(surface.position[axis] == again.surfaces[index].position[axis])
            end
            assert(within(surface.position[1], surface.position[3], 0))
            assert(surface.position[1] - surface.size[1] / 2 >= layout.bounds.minX)
            assert(surface.position[1] + surface.size[1] / 2 <= layout.bounds.maxX)
            assert(surface.position[3] - surface.size[3] / 2 >= layout.bounds.minZ)
            assert(surface.position[3] + surface.size[3] / 2 <= layout.bounds.maxZ)
        end
        for _, prop in layout.props do
            assert(within(prop.position[1], prop.position[3], if prop.kind == "lagoon" then 60 else 16 * prop.scale))
        end
        assert(layout.bounds.maxX - layout.bounds.minX >= 800 and layout.bounds.maxZ - layout.bounds.minZ >= 800)
    end)
    test("every region reachable from hub without a mandatory gate", function()
        local reached = { hub = true }
        for _ = 1, #layout.paths do
            for _, path in layout.paths do
                if reached[path.a] then reached[path.b] = true end
                if reached[path.b] then reached[path.a] = true end
            end
        end
        assert(#layout.regions >= 4)
        local names, elevations = {}, {}
        for _, region in layout.regions do
            assert(not names[region.name] and reached[region.node])
            names[region.name] = true
            table.insert(elevations, layout.nodes[region.node][2])
        end
        table.sort(elevations)
        assert(elevations[#elevations] - elevations[1] >= 60, "distinct walkable topography required")
        for id in layout.nodes do assert(reached[id], "unreachable node: " .. id) end
    end)
    test("paths join at identical surface endpoints and permit ordinary walking", function()
        for _, path in layout.paths do
            local a, b = layout.nodes[path.a], layout.nodes[path.b]
            assert(a and b and a ~= b and path.width >= 16)
            local distance = math.sqrt((a[1] - b[1])^2 + (a[3] - b[3])^2)
            assert(distance > 0 and math.abs(a[2] - b[2]) / distance <= 0.3, path.a .. " ramp too steep")
            for _, p in { a, b } do
                assert(finite(p[1]) and finite(p[2]) and finite(p[3]) and within(p[1], p[3], path.width / 2))
            end
        end
        local hub = layout.nodes.hub
        assert(hub[1] == Config.route.depot[1] and hub[2] == Config.route.depot[2] - 2.5)
    end)
    test("terrain never forms a wall across the walkable path center", function()
        -- Sample a player-width corridor against every actual solid terrain plate.
        for _, path in layout.segments do
            local a, b = path.a, path.b
            local dx, dz = b[1] - a[1], b[3] - a[3]
            local length = math.sqrt(dx * dx + dz * dz)
            for step = 0, math.ceil(length / 2) do
                local t = step / math.ceil(length / 2)
                for _, offset in { -3, 0, 3 } do
                    local x, y, z = a[1] + dx * t - dz / length * offset, a[2] + (b[2] - a[2]) * t, a[3] + dz * t + dx / length * offset
                    for _, surface in layout.surfaces do
                        local p, s = surface.position, surface.size
                        if math.abs(x - p[1]) < s[1] / 2 and math.abs(z - p[3]) < s[3] / 2 then
                            assert(p[2] + s[2] / 2 <= y + 0.5, path.name .. " blocked by " .. surface.id)
                        end
                    end
                end
            end
        end
    end)
    test("rendered ramp segments and junction crossings do not form walking walls", function()
        assert(layout.junctionsCollidable == false, "broad flat junction slabs must not collide")
        for _, segment in layout.segments do
            local a, b = segment.a, segment.b
            local dx, dz = b[1] - a[1], b[3] - a[3]
            local length = math.sqrt(dx * dx + dz * dz)
            assert(length > 0 and math.abs(b[2] - a[2]) / length <= 0.3, segment.name .. " rendered ramp too steep")
            for step = 0, math.ceil(length) do
                local t = step / math.ceil(length)
                local x, y, z = a[1] + dx * t, a[2] + (b[2] - a[2]) * t, a[3] + dz * t
                for _, other in layout.segments do
                    local oa, ob = other.a, other.b
                    local ox, oz = ob[1] - oa[1], ob[3] - oa[3]
                    local ol = math.sqrt(ox * ox + oz * oz)
                    local along = ((x - oa[1]) * ox + (z - oa[3]) * oz) / ol
                    local across = math.abs((x - oa[1]) * oz - (z - oa[3]) * ox) / ol
                    if along >= 0 and along <= ol and across <= other.width / 2 then
                        local top = oa[2] + (ob[2] - oa[2]) * along / ol
                        assert(top <= y + 0.5, segment.name .. " blocked by junction with " .. other.name)
                    end
                end
            end
        end
        for _, region in layout.regions do
            local n, o = layout.nodes[region.node], region.signOffset
            local at = { n[1] + o[1], n[2] + o[2], n[3] + o[3] }
            for _, path in layout.paths do
                assert(distanceToSegment(at, layout.nodes[path.a], layout.nodes[path.b]) > path.width / 2 + 1, region.id .. " sign obstructs path")
            end
        end
    end)
    test("training fall corridor remains clear until recovery", function()
        local area = layout.courseClearance
        assert(area.maxTop < Config.fallY)
        for _, surface in layout.surfaces do
            if intersects(surface.position[1], surface.position[3], surface.size[1] / 2, surface.size[3] / 2, area) then
                assert(surface.position[2] + surface.size[2] / 2 <= area.maxTop, surface.id .. " catches falling runner")
            end
        end
        for _, path in layout.paths do
            local a, b = layout.nodes[path.a], layout.nodes[path.b]
            local halfWidth = path.width / 2
            local minX, maxX, minZ, maxZ = math.min(a[1], b[1]) - halfWidth, math.max(a[1], b[1]) + halfWidth, math.min(a[3], b[3]) - halfWidth, math.max(a[3], b[3]) + halfWidth
            assert(not (maxX > area.minX and minX < area.maxX and maxZ > area.minZ and minZ < area.maxZ), "exploration path intrudes into Training")
        end
    end)
    test("new props keep spawn pickup and walking corridors clear", function()
        local spawn = { Config.route.depot[1], Config.route.depot[2] - 2, Config.route.depot[3] + 5 }
        for _, prop in layout.props do
            local radius = if prop.kind == "lagoon" then 60 elseif prop.kind == "dock" then 8 elseif prop.kind == "lookout" then 5 else 14 * prop.scale
            assert(distanceToSegment(prop.position, spawn, Config.pickup.position) > radius + 12, "spawn/station obstructed")
            if prop.kind ~= "lagoon" and prop.kind ~= "dock" and prop.kind ~= "lookout" then
                for _, path in layout.paths do
                    assert(distanceToSegment(prop.position, layout.nodes[path.a], layout.nodes[path.b]) > radius + path.width / 2 + 2, prop.kind .. " at " .. prop.position[1] .. "," .. prop.position[3] .. " obstructs " .. path.a .. "->" .. path.b)
                end
            end
        end
    end)
    return count
end
