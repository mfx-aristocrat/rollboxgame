-- Pure presentation placement. WorldLayout remains the authority for traversal.
local PresentationLayout = {}

PresentationLayout.hero = { minX = -110, maxX = 540, minZ = -170, maxZ = 440 }
PresentationLayout.partBudget = 700

function PresentationLayout.inScope(position, scope)
    assert(scope == "hero" or scope == "all", "Unknown presentation scope")
    local b = PresentationLayout.hero
    return scope == "all" or (position[1] >= b.minX and position[1] <= b.maxX
        and position[3] >= b.minZ and position[3] <= b.maxZ)
end

local function distanceToSegment(p, a, b)
    local dx, dz = b[1] - a[1], b[3] - a[3]
    local t = math.clamp(((p[1] - a[1]) * dx + (p[3] - a[3]) * dz) / (dx * dx + dz * dz), 0, 1)
    return math.sqrt((p[1] - a[1] - dx * t)^2 + (p[3] - a[3] - dz * t)^2)
end

function PresentationLayout.clearOfPaths(layout, position, radius)
    for _, segment in layout.segments do
        if distanceToSegment(position, segment.a, segment.b) < segment.width / 2 + radius + 3 then
            return false
        end
    end
    return true
end

function PresentationLayout.create(layout, scope)
    assert(scope == "hero" or scope == "all", "Unknown presentation scope")
    local result = { trees = {}, rocks = {}, plants = {}, partBudget = PresentationLayout.partBudget }
    local function insert(list, spec)
        if PresentationLayout.inScope(spec.position, scope) then table.insert(list, spec) end
    end
    for index, prop in layout.props do
        if prop.kind == "tree" or prop.kind == "palm" then
            local radius = 13 * prop.scale
            if PresentationLayout.clearOfPaths(layout, prop.position, radius) then
                insert(result.trees, { id = "Tree" .. index, kind = prop.kind, position = table.clone(prop.position),
                    scale = prop.scale, yaw = index * 2.399963, radius = radius })
            end
        elseif prop.kind == "redRock" or prop.kind == "snowRock" then
            if PresentationLayout.clearOfPaths(layout, prop.position, 18) then
                insert(result.rocks, { id = "Stone" .. index, position = table.clone(prop.position), scale = 1.6,
                    snow = prop.kind == "snowRock", warm = prop.kind == "redRock", yaw = index * 1.9, radius = 18 })
            end
        elseif prop.kind == "roundHill" then
            -- Replace oversized spherical hills with low, grounded outcrops.
            if PresentationLayout.clearOfPaths(layout, prop.position, 19) then
                insert(result.rocks, { id = "Outcrop" .. index, position = table.clone(prop.position), scale = 1.7,
                    warm = false, yaw = index * 1.9, radius = 19 })
            end
        end
    end
    local hub = layout.nodes.hub
    local ox, oy, oz = hub[1], hub[2] - 9.5, hub[3] - 8
    -- Small authored groves soften the broad southern terraces. Keep the
    -- traversal layout authoritative and reject any pocket near its paths.
    for index, row in {
        { -490, -2, 485, 0.7 }, { -480, -2, 535, 0.55 }, { -490, -2, 770, 0.75 },
        { -470, -2, 805, 0.6 }, { -120, -2, 530, 0.65 }, { -100, -2, 800, 0.7 },
        { 95, 12, 500, 0.55 }, { 110, 12, 530, 0.7 }, { 500, 12, 530, 0.65 },
        { 505, 12, 820, 0.6 }, { 130, 12, 820, 0.7 }, { 175, 12, 850, 0.6 },
    } do
        local p = { row[1] + ox, row[2] + oy, row[3] + oz }
        local radius = 13 * row[4]
        if PresentationLayout.clearOfPaths(layout, p, radius) then
            insert(result.trees, { id = "Grove" .. index, kind = "tree", position = p,
                scale = row[4], yaw = index * 2.399963, radius = radius })
        end
    end
    -- Authored coast edges and planting pockets; no scatter or per-frame work.
    for index, row in {
        { 432, -4, 34 }, { 432, -4, 104 }, { 432, -4, 178 }, { 435, -4, 348 },
        { 130, -4, 400 }, { 310, -4, 402 }, { -430, -2, 40 }, { -430, -2, 270 },
        { -510, -2, 500 }, { -510, -2, 830 }, { 510, 12, 500 }, { 490, 12, 840 },
    } do
        local p = { row[1] + ox, row[2] + oy, row[3] + oz }
        if PresentationLayout.clearOfPaths(layout, p, 10) then
            insert(result.rocks, { id = "Edge" .. index, position = p, scale = 0.75 + index % 3 * 0.12,
                warm = row[1] > 0, yaw = index * 1.9, radius = 10 })
        end
    end
    for index, row in {
        { -48, 9.25, 0 }, { 48, 9.25, 0 }, { 121, -4, 58 }, { 180, -4, 155 },
        { 255, -4, 62 }, { 365, -4, 35 }, { 405, -4, 120 }, { 410, -4, 335 },
        { 170, -4, 385 }, { 350, -4, 400 }, { -385, -2, 75 }, { -235, -2, 180 },
        { -390, -2, 370 }, { -465, -2, 560 }, { -370, -2, 680 }, { -145, -2, 825 },
        { 110, 12, 555 }, { 450, 12, 560 }, { 450, 32, 770 }, { 335, 32, 800 },
    } do
        local p = { row[1] + ox, row[2] + oy, row[3] + oz }
        if PresentationLayout.clearOfPaths(layout, p, 3.5) then
            insert(result.plants, { id = "Plant" .. index, position = p, scale = 0.8 + index % 3 * 0.15,
                yaw = index * 2.399963, radius = 3.5 })
        end
    end
    return result
end

return PresentationLayout
