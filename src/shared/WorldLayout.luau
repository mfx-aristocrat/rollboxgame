-- Pure numeric world specification: also loaded by Lune without Roblox globals.
local WorldLayout = {}

function WorldLayout.create(config)
    local origin = config.route.depot
    local function position(x, y, z)
        return { origin[1] + x, origin[2] - 12 + y, origin[3] + z }
    end
    local layout = {
        bounds = { minX = -460, maxX = 460, minZ = -460, maxZ = 460 },
        -- New geometry cannot catch a falling runner before server recovery.
        courseClearance = { minX = -56, maxX = 56, minZ = -185, maxZ = -14, maxTop = config.fallY - 4 },
        surfaces = {}, nodes = {}, paths = {}, props = {}, regions = {}, segments = {},
        junctionsCollidable = false,
    }
    local function surface(id, x, z, width, depth, top, material, color)
        table.insert(layout.surfaces, {
            id = id, position = position(x, top - 9, z), size = { width, 18, depth },
            material = material, color = color,
        })
    end
    -- The empty central channel preserves the suspended rooftop course.
    surface("MeadowFoundation", -275, 135, 350, 590, -18, "Rock", { 103, 116, 94 })
    surface("MeadowGrass", -275, 135, 340, 580, -2, "Grass", { 103, 159, 88 })
    surface("CoastFoundation", 275, 135, 350, 590, -18, "Sandstone", { 190, 164, 112 })
    surface("CoastBeach", 275, 135, 340, 580, -4, "Sand", { 235, 212, 151 })
    surface("RedstoneBase", -275, -310, 350, 280, 16, "Rock", { 152, 104, 78 })
    surface("RedstoneTerrace", -275, -310, 190, 180, 26, "Sandstone", { 179, 122, 88 })
    surface("RedstoneSummit", -325, -310, 60, 100, 36, "Rock", { 164, 109, 78 })
    surface("FrostBase", 275, -310, 350, 280, 28, "Slate", { 121, 144, 157 })
    surface("FrostTerrace", 275, -315, 200, 180, 46, "Snow", { 226, 239, 242 })
    surface("FrostSummit", 330, -340, 70, 90, 64, "Snow", { 243, 249, 249 })
    -- Side entry plazas meet the existing depot deck without occupying its approach.
    surface("WestPlaza", -53, 8, 70, 24, 9.5, "Cobblestone", { 117, 131, 128 })
    surface("EastPlaza", 53, 8, 70, 24, 9.5, "Cobblestone", { 117, 131, 128 })

    local function node(id, x, y, z)
        layout.nodes[id] = position(x, y, z)
    end
    node("hub", 0, 9.5, 8)
    node("westEntry", -80, 9.5, 8)
    node("westRamp", -98, 9.5, 32)
    node("westFork", -145, 0, 90)
    node("meadow", -275, 0, 230)
    node("meadowSouth", -120, 0, 350)
    node("eastSouth", 120, -2, 350)
    node("coast", 275, -2, 230)
    node("eastFork", 145, -2, 90)
    node("eastEntry", 80, 9.5, 8)
    node("eastRamp", 98, 9.5, 32)
    node("lagoonDock", 340, -1.5, 210)
    node("westPass", -165, 0, -75)
    node("rockFoot", -160, 16.4, -165)
    node("rockRamp", -275, 26.4, -210)
    node("rockPeak", -275, 36.4, -310)
    node("rockLookout", -325, 36.4, -310)
    node("northWest", -135, 36.4, -395)
    node("northEast", 135, 42.4, -395)
    node("snowPeak", 275, 64.4, -315)
    node("snowLookout", 330, 64.4, -340)
    node("snowRamp", 275, 46.4, -205)
    node("snowFoot", 160, 28.4, -165)
    node("eastPass", 165, -2, -20)
    local function path(a, b, style, width)
        table.insert(layout.paths, { a = a, b = b, width = width or 18, style = style or "trail" })
    end
    path("hub", "westEntry", "plaza", 20)
    path("westEntry", "westRamp")
    path("westRamp", "westFork")
    path("westFork", "meadow")
    path("meadow", "meadowSouth")
    path("meadowSouth", "eastSouth", "bridge", 20)
    path("eastSouth", "coast")
    path("coast", "eastFork")
    path("coast", "lagoonDock", "bridge", 16)
    path("eastFork", "eastRamp")
    path("eastRamp", "eastEntry")
    path("eastEntry", "hub", "plaza", 20)
    path("westFork", "westPass")
    path("westPass", "rockFoot")
    path("rockFoot", "rockRamp")
    path("rockRamp", "rockPeak")
    path("rockPeak", "rockLookout")
    path("rockPeak", "northWest")
    path("northWest", "northEast", "bridge", 20)
    path("northEast", "snowPeak")
    path("snowPeak", "snowLookout")
    path("snowPeak", "snowRamp")
    path("snowRamp", "snowFoot")
    path("snowFoot", "eastPass")
    path("eastPass", "eastFork")
    layout.regions = {
        { id = "meadow", name = "WILLOW MEADOW", node = "meadow", signOffset = { -18, 0, -18 }, color = { 144, 220, 111 }, description = "Forest trails • picnic clearing" },
        { id = "coast", name = "TIDAL COAST", node = "coast", signOffset = { 18, 0, 18 }, color = { 245, 213, 145 }, description = "Sandy shore • lagoon boardwalk" },
        { id = "heights", name = "REDSTONE HEIGHTS", node = "rockPeak", signOffset = { 15, 0, 8 }, color = { 240, 164, 103 }, description = "Stone terraces • northern bridge" },
        { id = "snow", name = "FROSTPEAK UPLANDS", node = "snowPeak", signOffset = { 15, 0, 8 }, color = { 209, 244, 255 }, description = "Snowfields • summit lookout" },
    }
    local function prop(kind, x, y, z, scale)
        table.insert(layout.props, { kind = kind, position = position(x, y, z), scale = scale or 1 })
    end
    -- Authored deterministic groves leave the path network and landmarks open.
    for _, row in { { -400, 50 }, { -390, 140 }, { -400, 260 }, { -350, 350 }, { -200, 390 }, { -180, 180 }, { -350, -80 }, { -240, 60 }, { -390, -110 }, { -360, 220 } } do
        prop("tree", row[1], -2, row[2], 1)
        prop("tree", row[1] + 22, -2, row[2] + 25, 0.75)
    end
    for _, row in { { -400, -240 }, { -390, -380 }, { -175, -420 }, { -340, -420 }, { -120, -315 } } do
        prop("redRock", row[1], 16, row[2], 1)
    end
    for _, row in { { 395, -230 }, { 400, -380 }, { 185, -430 }, { 350, -430 }, { 125, -315 } } do
        prop("snowRock", row[1], 28, row[2], 1)
    end
    for _, row in { { 150, 240 }, { 390, 300 }, { 390, 80 }, { 230, 0 }, { 390, 390 } } do
        prop("palm", row[1], -4, row[2], 1)
    end
    prop("lagoon", 340, -3.7, 120)
    prop("dock", 340, -2, 202)
    prop("picnic", -310, -2, 200)
    prop("lookout", 345, 64, -360)
    for _, path in layout.paths do
        local a, b = layout.nodes[path.a], layout.nodes[path.b]
        local dx, dz = b[1] - a[1], b[3] - a[3]
        local distance = math.sqrt(dx * dx + dz * dz)
        local points = { a, b }
        if a[2] ~= b[2] then
            -- Flat approaches keep intersecting ramps from forming walls at junctions.
            local inset = 16
            points = { a, { a[1] + dx * inset / distance, a[2], a[3] + dz * inset / distance },
                { b[1] - dx * inset / distance, b[2], b[3] - dz * inset / distance }, b }
        end
        for index = 1, #points - 1 do
            table.insert(layout.segments, { a = points[index], b = points[index + 1], width = path.width, style = path.style, name = path.a .. "->" .. path.b })
        end
    end
    return layout
end

return WorldLayout
