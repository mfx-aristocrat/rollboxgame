-- Presentation data only. RGB triplets and camera coordinates stay usable by
-- standalone checks; no gameplay values or external asset IDs belong here.
local config = {
    scope = "all",
    -- Appearance only. Moderate reflection avoids black underside reflections
    -- below the suspended islands; native liquid and swimming stay unchanged.
    water = { reflectance = 0.15, transparency = 0.32 },
    surfaceTints = {
        RedstoneBase = { 209, 151, 114 },
        RedstoneTerrace = { 226, 173, 130 },
        RedstoneSummit = { 218, 155, 112 },
        GardensOchreCliff = { 225, 188, 137 },
        GardensCreamBand = { 249, 227, 190 },
        MesaPeachCliff = { 229, 173, 137 },
        MesaCreamBand = { 250, 227, 190 },
        MesaCrownCliff = { 235, 192, 148 },
    },
    palette = {
        grass = { 100, 129, 74 },
        grassDark = { 69, 99, 57 },
        soil = { 112, 91, 68 },
        stone = { 130, 139, 143 },
        stoneWarm = { 158, 131, 105 },
        timber = { 129, 103, 76 },
        sand = { 199, 186, 150 },
        snow = { 223, 232, 237 },
    },
    lighting = {
        -- Serialized in Rojo with the Future compatibility tag. These setters
        -- require PluginOrOpenCloud and cannot run in ordinary game scripts.
        style = "Realistic",
        prioritizeQuality = true,
        clockTime = 13.8,
        geographicLatitude = 32,
        brightness = 2.2,
        exposureCompensation = 0,
        ambient = { 70, 85, 100 },
        outdoorAmbient = { 110, 125, 145 },
        colorShiftTop = { 7, 4, 0 },
        colorShiftBottom = { 0, 0, 0 },
        environmentDiffuseScale = 1,
        environmentSpecularScale = 1,
        globalShadows = true,
        shadowSoftness = 0.25,
        -- Legacy fog stays outside the playable world if no Atmosphere renders
        -- on a device. Atmosphere supplies the intended subtle depth cue.
        fogColor = { 205, 219, 229 },
        fogStart = 3000,
        fogEnd = 10000,
        atmosphere = {
            density = 0.18,
            offset = 0.25,
            color = { 205, 219, 229 },
            decay = { 135, 153, 170 },
            glare = 0.03,
            haze = 0.45,
        },
        colorCorrection = {
            brightness = 0,
            contrast = 0.08,
            saturation = -0.05,
            tintColor = { 255, 253, 249 },
        },
        bloom = { intensity = 0.045, threshold = 1.5, size = 20 },
    },
    -- Identical edit-time viewpoints for each before/after comparison.
    -- They are evidence fixtures, never the player's camera or FOV.
    cameras = {
        { name = "depot", position = { 65, 35, 80 }, look = { 0, 6, -25 } },
        { name = "meadow", position = { -265, 24, 130 }, look = { -220, 1, 210 } },
        { name = "coast", position = { 515, 38, 330 }, look = { 390, 1, 275 } },
        { name = "redstone", position = { -300, 85, -215 }, look = { -240, 25, -330 } },
        { name = "snow", position = { 310, 90, -220 }, look = { 230, 24, -335 } },
        { name = "gardens", position = { -370, 35, 720 }, look = { -220, 8, 650 } },
        { name = "mesa", position = { 450, 85, 835 }, look = { 300, 35, 700 } },
        { name = "grassClose", position = { -230, 5, 185 }, look = { -220, -2, 200 } },
        { name = "depotPlayer", position = { 0, 16, 17 }, look = { 0, 12, -20 } },
        { name = "shorePlayer", position = { 475, 7, 290 }, look = { 425, 2, 275 } },
    },
}

local function freeze(value)
    for _, child in value do
        if type(child) == "table" then freeze(child) end
    end
    return table.freeze(value)
end

return freeze(config)
