local AdventureWorld = {}

function AdventureWorld.build(parent, layout)
    local previous = parent:FindFirstChild("PlatformerAdventure")
    if previous then previous:Destroy() end
    local folder = Instance.new("Folder")
    folder.Name, folder.Parent = "PlatformerAdventure", parent
    local result = { items = {}, springs = {}, root = folder }
    local partCount = 0
    local function piece(owner, name, size, at, tint, id)
        partCount += 1
        assert(partCount <= layout.partBudget, "Adventure source part budget exceeded")
        local p = Instance.new("Part")
        p.Name, p.Size, p.Position, p.Color = name, size, at, tint
        p.Anchored, p.CanCollide, p.CanTouch = true, false, false
        p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
        p.Material = Enum.Material.SmoothPlastic
        if id then p:SetAttribute("AdventureId", id) end
        p.Parent = owner
        return p
    end
    local gold, cream = Color3.fromRGB(255, 207, 62), Color3.fromRGB(255, 247, 204)
    for _, spec in layout.items do
        local group = Instance.new("Model")
        group.Name, group.Parent = spec.id, folder
        local at = Vector3.new(table.unpack(spec.position))
        local function part(name, size, offset, color)
            return piece(group, name, size, at + offset, color, spec.id)
        end
        local main
        if spec.kind == "token" then
            main = part("TrailToken", Vector3.new(0.65, 2.8, 2.8), Vector3.zero, gold)
            main.Shape = Enum.PartType.Cylinder
            main.CFrame *= CFrame.Angles(0, math.pi / 2, 0)
            main.Material = Enum.Material.Metal
            local glint = part("TokenGlint", Vector3.new(0.16, 1.4, 0.3), Vector3.new(0, 0, 0.38), cream)
            glint.Material = Enum.Material.Neon
        elseif spec.kind == "crate" then
            main = part("BonusCrate", Vector3.new(4, 4, 4), Vector3.zero, Color3.fromRGB(240, 159, 77))
            main.Material = Enum.Material.WoodPlanks
            for _, z in { -2.03, 2.03 } do
                part("CrateRibbon", Vector3.new(0.8, 4.1, 0.18), Vector3.new(0, 0, z), cream)
            end
            part("CrateLid", Vector3.new(4.4, 0.45, 4.4), Vector3.new(0, 1.85, 0), gold)
            local badge = part("CrateStar", Vector3.new(1.1, 1.1, 0.2), Vector3.new(0, 0.2, 2.14), gold)
            badge.CFrame *= CFrame.Angles(0, 0, math.pi / 4)
        else
            main = part("LandmarkMedallion", Vector3.new(2.7, 2.7, 0.7), Vector3.zero, gold)
            main.Shape = Enum.PartType.Ball
            part("PennantPole", Vector3.new(0.4, 7, 0.4), Vector3.new(0, 0.5, 0), cream)
            part("CourierPennant", Vector3.new(3.5, 2.5, 0.25), Vector3.new(1.75, 2.4, 0), Color3.fromRGB(255, 119, 147))
            part("PennantStripe", Vector3.new(2.2, 0.4, 0.3), Vector3.new(1.6, 2.4, 0), cream)
        end
        group.PrimaryPart = main
        local prompt
        if spec.kind == "crate" then
            prompt = Instance.new("ProximityPrompt")
            prompt.Name, prompt.ActionText, prompt.ObjectText = "OpenBonusCrate", "Open crate", "Free • +" .. spec.score .. " exploration"
            prompt.KeyboardKeyCode, prompt.GamepadKeyCode = Enum.KeyCode.E, Enum.KeyCode.ButtonX
            prompt.MaxActivationDistance, prompt.HoldDuration, prompt.RequiresLineOfSight = 9, 0, false
            prompt.ClickablePrompt, prompt.Parent = true, main
        end
        table.insert(result.items, { spec = spec, part = main, prompt = prompt })
    end
    for _, spec in layout.springs do
        local group = Instance.new("Model")
        group.Name, group.Parent = spec.id, folder
        local at = Vector3.new(table.unpack(spec.position))
        local base = piece(group, "SpringPad", Vector3.new(6, 1.2, 6), at, Color3.fromRGB(255, 111, 133))
        base.CanCollide = true
        base:SetAttribute("SpringId", spec.id)
        piece(group, "SpringInset", Vector3.new(4.7, 0.15, 4.7), at + Vector3.new(0, 0.68, 0), cream)
        for _, x in { -1, 1 } do
            local arrow = piece(group, "SpringArrow", Vector3.new(0.45, 0.12, 2), at + Vector3.new(x * 0.6, 0.8, 0), Color3.fromRGB(76, 155, 197))
            arrow.CFrame *= CFrame.Angles(0, x * math.pi / 4, 0)
        end
        group.PrimaryPart = base
        table.insert(result.springs, { spec = spec, part = base })
    end
    folder:SetAttribute("SourcePartCount", partCount)
    folder:SetAttribute("SourcePartBudget", layout.partBudget)
    return result
end

return AdventureWorld
