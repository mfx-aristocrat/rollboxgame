local LightingPresentation = {}

local OWNER_ATTRIBUTE = "RollboxLightingOwner"
local OWNER_VALUE = "LightingPresentation/v1"

local function color(rgb)
    return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

local function ownedEffect(lighting, className, name)
    local selected
    for _, child in lighting:GetChildren() do
        -- Both the name and marker are necessary: preserve unowned collisions
        -- and unrelated objects, even if another subsystem shares the marker.
        if child.Name == name and child:GetAttribute(OWNER_ATTRIBUTE) == OWNER_VALUE then
            if child.ClassName == className and not selected then
                selected = child
            else
                child:Destroy()
            end
        end
    end
    if not selected then
        selected = Instance.new(className)
        selected.Name = name
        selected:SetAttribute(OWNER_ATTRIBUTE, OWNER_VALUE)
    end
    return selected
end

function LightingPresentation.apply(lighting, config, terrain)
    local settings = config.lighting
    lighting.ClockTime = settings.clockTime
    lighting.GeographicLatitude = settings.geographicLatitude
    lighting.Brightness = settings.brightness
    lighting.ExposureCompensation = settings.exposureCompensation
    lighting.Ambient = color(settings.ambient)
    lighting.OutdoorAmbient = color(settings.outdoorAmbient)
    lighting.ColorShift_Top = color(settings.colorShiftTop)
    lighting.ColorShift_Bottom = color(settings.colorShiftBottom)
    lighting.EnvironmentDiffuseScale = settings.environmentDiffuseScale
    lighting.EnvironmentSpecularScale = settings.environmentSpecularScale
    lighting.GlobalShadows = settings.globalShadows
    lighting.ShadowSoftness = settings.shadowSoftness
    lighting.FogColor = color(settings.fogColor)
    lighting.FogStart = settings.fogStart
    lighting.FogEnd = settings.fogEnd

    local atmosphere = ownedEffect(lighting, "Atmosphere", "RollboxAtmosphere")
    local air = settings.atmosphere
    atmosphere.Density = air.density
    atmosphere.Offset = air.offset
    atmosphere.Color = color(air.color)
    atmosphere.Decay = color(air.decay)
    atmosphere.Glare = air.glare
    atmosphere.Haze = air.haze
    atmosphere.Parent = lighting

    local correction = ownedEffect(lighting, "ColorCorrectionEffect", "RollboxColorCorrection")
    local grade = settings.colorCorrection
    correction.Enabled = true
    correction.Brightness = grade.brightness
    correction.Contrast = grade.contrast
    correction.Saturation = grade.saturation
    correction.TintColor = color(grade.tintColor)
    correction.Parent = lighting

    local bloom = ownedEffect(lighting, "BloomEffect", "RollboxBloom")
    bloom.Enabled = true
    bloom.Intensity = settings.bloom.intensity
    bloom.Threshold = settings.bloom.threshold
    bloom.Size = settings.bloom.size
    bloom.Parent = lighting

    if terrain and config.water then
        terrain.WaterReflectance = config.water.reflectance
        terrain.WaterTransparency = config.water.transparency
    end
    return { atmosphere = atmosphere, colorCorrection = correction, bloom = bloom }
end

return LightingPresentation
