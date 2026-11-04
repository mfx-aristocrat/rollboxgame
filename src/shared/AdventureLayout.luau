-- Numeric, deterministic source specification. Heights describe visible part centers.
-- All rewards sit above ordinary walking paths; springs are optional shortcuts.
local AdventureLayout = {}

function AdventureLayout.create(config)
    local origin = config.route.depot
    local layout = { items = {}, springs = {}, partBudget = 240 }
    local function position(x, y, z)
        return { origin[1] + x, origin[2] - 12 + y, origin[3] + z }
    end
    local function item(kind, index, x, top, z, name)
        table.insert(layout.items, {
            id = string.format("%s-%02d", kind, index), kind = kind,
            position = position(x, top + (if kind == "crate" then 2 else 3), z),
            score = if kind == "token" then 1 elseif kind == "crate" then 5 else 10,
            name = name or (if kind == "token" then "Trail token" else "Free bonus crate"),
        })
    end
    -- Five tokens on each of six routes, including the graded Mesa ascent.
    local trails = {
        { { -80, 9.5, 8 }, { -98, 9.5, 32 } },
        { { -145, 0, 90 }, { -275, 0, 230 } },
        { { 275, -2, 230 }, { 145, -2, 90 } },
        { { -180, 0, 460 }, { -290, 0, 600 } },
        { { -290, 0, 600 }, { -420, 0, 720 } },
        { { 290, 12, 600 }, { 390, 32, 610 } },
    }
    for trailIndex, trail in trails do
        local a, b = trail[1], trail[2]
        local dx, dz = b[1] - a[1], b[3] - a[3]
        local distance = math.sqrt(dx * dx + dz * dz)
        for step = 1, 5 do
            local t = (step - 1) / 5
            local along = distance * t
            -- TerrainWorld renders sixteen-stud level approaches at graded junctions.
            local rise = if a[2] == b[2] then t else math.clamp((along - 16) / (distance - 32), 0, 1)
            item("token", (trailIndex - 1) * 5 + step,
                a[1] + dx * t, a[2] + (b[2] - a[2]) * rise, a[3] + dz * t)
        end
    end
    for index, at in { { -275, 0, 238 }, { 275, -2, 222 }, { -420, 0, 720 }, { 390, 32, 730 } } do
        item("crate", index, at[1], at[2], at[3])
    end
    for index, at in {
        { -275, 0, 230, "Willow picnic pennant" },
        { 340, -1.5, 210, "Lagoon pennant" },
        { -325, 36.4, -310, "Redstone pennant" },
        { 330, 64.4, -340, "Frostpeak pennant" },
        { -290, 0, 608, "Sunpetal pennant" },
        { 390, 32, 738, "Cloudstep pennant" },
    } do
        item("landmark", index, at[1], at[2], at[3], at[4])
    end
    for index, at in { { -180, 0, 470 }, { -290, 0, 590 }, { 290, 12, 520 }, { 390, 32, 710 } } do
        table.insert(layout.springs, {
            id = string.format("spring-%02d", index),
            position = position(at[1], at[2] + 0.6, at[3]), launchSpeed = 70,
        })
    end
    return layout
end

return AdventureLayout
