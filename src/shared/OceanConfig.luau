-- Original scenery and native water, kept numeric for standalone geometry checks.
local config = {
    modelName = "OceanEnvironment",
    partBudget = 350,
    water = {
        minX = -640, maxX = 640, minZ = -560, maxZ = 1000,
        bottomY = -52, surfaceY = -12, resolution = 4, chunkSize = 128,
    },
    seafloorTop = -54,
    -- Level approaches cross the shoreline before any ramp descends. Lower ends
    -- are submerged one stud so a swimmer can walk up without a jump or ladder.
    exits = {
        { id = "meadow", name = "WILLOW MEADOW", land = { -420, -1.75, 200 }, rampTop = { -458, -1.75, 200 }, water = { -530, -13, 200 }, landing = { -420, 2.25, 200 }, width = 16 },
        { id = "coast", name = "TIDAL COAST", land = { 420, -3.75, 275 }, rampTop = { 458, -3.75, 275 }, water = { 530, -13, 275 }, landing = { 420, 0.25, 275 }, width = 16 },
        { id = "gardens", name = "SUNPETAL GARDENS", land = { -510, -1.75, 740 }, rampTop = { -548, -1.75, 740 }, water = { -612, -13, 740 }, landing = { -510, 2.25, 740 }, width = 16 },
        { id = "mesa", name = "CLOUDSTEP MESA", land = { 510, 12.25, 600 }, rampTop = { 548, 12.25, 600 }, water = { 610, -13, 700 }, landing = { 510, 16.25, 600 }, width = 16 },
    },
    -- Server return destinations are allowlisted positions, never client positions.
    returnLandings = {
        { id = "depot", position = { 0, 13.5, 8 } },
        { id = "meadow", position = { -420, 2.25, 200 } },
        { id = "coast", position = { 420, 0.25, 275 } },
        { id = "gardens", position = { -510, 2.25, 740 } },
        { id = "mesa", position = { 510, 16.25, 600 } },
    },
}
local function freeze(value)
    for _, child in pairs(value) do
        if type(child) == "table" then freeze(child) end
    end
    return table.freeze(value)
end
return freeze(config)
