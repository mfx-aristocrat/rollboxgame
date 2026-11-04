local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local VisualConfig = require("../src/shared/VisualConfig")

local function near(actual, expected)
    assert(math.abs(actual - expected) < 0.00001, `{actual} differs from {expected}`)
end

local function rgb(actual, expected)
    near(actual.R, expected[1] / 255)
    near(actual.G, expected[2] / 255)
    near(actual.B, expected[3] / 255)
end

return function()
    local presentation = luau.load(fs.readFile("src/server/LightingPresentation.luau"), {
        injectGlobals = true,
        environment = { Instance = roblox.Instance, Color3 = roblox.Color3, Enum=roblox.Enum },
    })()
    local lighting = roblox.Instance.new("Lighting")
    local settings = VisualConfig.lighting
    local effects = presentation.apply(lighting, VisualConfig)
    near(lighting.ClockTime, settings.clockTime)
    near(lighting.GeographicLatitude, settings.geographicLatitude)
    near(lighting.Brightness, settings.brightness)
    near(lighting.ExposureCompensation, settings.exposureCompensation)
    rgb(lighting.Ambient, settings.ambient)
    rgb(lighting.OutdoorAmbient, settings.outdoorAmbient)
    rgb(lighting.ColorShift_Top, settings.colorShiftTop)
    rgb(lighting.ColorShift_Bottom, settings.colorShiftBottom)
    near(lighting.EnvironmentDiffuseScale, 1)
    near(lighting.EnvironmentSpecularScale, 1)
    assert(lighting.GlobalShadows)
    near(lighting.ShadowSoftness, settings.shadowSoftness)
    rgb(lighting.FogColor, settings.fogColor)
    near(lighting.FogStart, settings.fogStart)
    near(lighting.FogEnd, settings.fogEnd)

    local atmosphere, correction, bloom = effects.atmosphere, effects.colorCorrection, effects.bloom
    near(atmosphere.Density, settings.atmosphere.density)
    near(atmosphere.Offset, settings.atmosphere.offset)
    near(atmosphere.Glare, settings.atmosphere.glare)
    near(atmosphere.Haze, settings.atmosphere.haze)
    rgb(atmosphere.Color, settings.atmosphere.color)
    rgb(atmosphere.Decay, settings.atmosphere.decay)
    assert(correction.Enabled and bloom.Enabled)
    near(correction.Brightness, settings.colorCorrection.brightness)
    near(correction.Contrast, settings.colorCorrection.contrast)
    near(correction.Saturation, settings.colorCorrection.saturation)
    rgb(correction.TintColor, settings.colorCorrection.tintColor)
    near(bloom.Intensity, settings.bloom.intensity)
    near(bloom.Size, settings.bloom.size)
    near(bloom.Threshold, settings.bloom.threshold)

    -- Reapplying restores modified owned state and reuses instances: no effect
    -- accumulation or fresh allocations when source-built worlds regenerate.
    atmosphere.Density, bloom.Enabled = 0.8, false
    local repeated = presentation.apply(lighting, VisualConfig)
    assert(repeated.atmosphere == atmosphere and repeated.colorCorrection == correction and repeated.bloom == bloom)
    assert(#lighting:GetChildren() == 3 and bloom.Enabled)
    near(atmosphere.Density, settings.atmosphere.density)

    -- Same-name unowned assets, ordinary user effects and marker-only assets
    -- remain byte-for-byte unchanged. Only explicitly owned names are managed.
    local userBloom = roblox.Instance.new("BloomEffect")
    userBloom.Name, userBloom.Intensity, userBloom.Parent = "RollboxBloom", 0.27, lighting
    local userSky = roblox.Instance.new("Sky")
    userSky.Name, userSky.Parent = "UserSky", lighting
    local otherOwned = roblox.Instance.new("ColorCorrectionEffect")
    otherOwned.Name, otherOwned.Contrast = "OtherPresentation", 0.43
    otherOwned:SetAttribute("RollboxLightingOwner", "LightingPresentation/v1")
    otherOwned.Parent = lighting
    presentation.apply(lighting, VisualConfig)
    assert(userBloom.Parent == lighting and userBloom:GetAttribute("RollboxLightingOwner") == nil)
    near(userBloom.Intensity, 0.27)
    assert(userSky.Parent == lighting and otherOwned.Parent == lighting)
    near(otherOwned.Contrast, 0.43)
    assert(#lighting:GetChildren() == 6)

    -- A stale owned class or duplicate cannot accumulate. Neither deletion
    -- broadens to other names nor a same-name unowned object is adopted.
    local wrongClass = roblox.Instance.new("Folder")
    wrongClass.Name = "RollboxAtmosphere"
    wrongClass:SetAttribute("RollboxLightingOwner", "LightingPresentation/v1")
    wrongClass.Parent = lighting
    local duplicate = bloom:Clone()
    duplicate.Parent = lighting
    presentation.apply(lighting, VisualConfig)
    assert(wrongClass.Parent == nil and #lighting:GetChildren() == 6)
    local managedCount = 0
    for _, child in lighting:GetChildren() do
        if child.Name == "RollboxBloom" and child:GetAttribute("RollboxLightingOwner") == "LightingPresentation/v1" then
            managedCount += 1
        end
    end
    assert(managedCount == 1)

    -- Guard the art direction's gameplay readability limits. Render acceptance
    -- still needs the identical-camera Studio review; these are not screenshots.
    assert(settings.brightness >= 2 and settings.brightness <= 2.5)
    assert(settings.ambient[1] >= 60 and settings.ambient[3] <= 115)
    assert(settings.atmosphere.density <= 0.2 and settings.atmosphere.haze <= 0.5)
    assert(settings.bloom.intensity <= 0.06 and settings.bloom.threshold >= 1.5)
    assert(settings.colorCorrection.contrast <= 0.1 and settings.colorCorrection.saturation >= -0.1)
    for _, child in lighting:GetChildren() do
        assert(not child:IsA("DepthOfFieldEffect") and not child:IsA("BlurEffect"), "gameplay must remain sharp")
    end
    assert(table.isfrozen(VisualConfig) and table.isfrozen(settings) and table.isfrozen(VisualConfig.palette.grass))
    local names = {}
    assert(#VisualConfig.cameras == 10)
    for _, camera in VisualConfig.cameras do
        assert(not names[camera.name] and #camera.position == 3 and #camera.look == 3)
        names[camera.name] = true
    end
    local terrain = roblox.Instance.new("Terrain")
    local originalColor, originalWave = terrain.WaterColor, terrain.WaterWaveSize
    terrain.WaterReflectance = 1
    presentation.apply(lighting, VisualConfig, terrain)
    near(terrain.WaterReflectance, VisualConfig.water.reflectance)
    near(terrain.WaterTransparency, VisualConfig.water.transparency)
    assert(terrain.WaterColor == originalColor and terrain.WaterWaveSize == originalWave)
    terrain:Destroy()
    lighting:Destroy()
    return 6
end
