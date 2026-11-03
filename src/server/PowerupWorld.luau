local PowerupWorld = {}
function PowerupWorld.build(parent, config)
	local previous = parent:FindFirstChild("MushroomPowerup")
	if previous then previous:Destroy() end
	local folder = Instance.new("Folder")
	folder.Name = "MushroomPowerup"
	local at = Vector3.new(table.unpack(config.cratePosition))
	local cream, red = Color3.fromRGB(255, 244, 205), Color3.fromRGB(222, 57, 67)
	local count = 0
	local function part(name, size, offset, color, ball)
		local p = Instance.new("Part")
		p.Name, p.Size, p.Position, p.Color = name, size, at + offset, color
		p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
		p.Material = Enum.Material.SmoothPlastic
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		if ball then p.Shape = Enum.PartType.Ball end
		p:SetAttribute("PowerupId", config.id)
		p.Parent = folder
		count += 1
		return p
	end
	local crate = part("MushroomCrate", Vector3.new(4, 3.5, 4), Vector3.zero, Color3.fromRGB(148, 94, 64))
	crate.Material = Enum.Material.WoodPlanks
	part("CrateLid", Vector3.new(4.4, 0.45, 4.4), Vector3.new(0, 1.65, 0), Color3.fromRGB(239, 186, 99))
	for _, z in { -2.04, 2.04 } do
		part("CreamCrateBand", Vector3.new(0.65, 3.5, 0.12), Vector3.new(0, 0, z), cream)
	end
	part("MushroomStem", Vector3.new(1.4, 2.2, 1.4), Vector3.new(0, 2.8, 0), cream, true)
	part("MushroomCap", Vector3.new(4.1, 2.1, 4.1), Vector3.new(0, 4, 0), red, true)
	for _, offset in { Vector3.new(0, 5.01, 0), Vector3.new(-1.25, 4.65, -0.5),
		Vector3.new(1.15, 4.65, 0.65), Vector3.new(-0.5, 4.4, 1.7), Vector3.new(0.65, 4.45, -1.6) } do
		part("MushroomSpot", Vector3.new(0.75, 0.3, 0.75), offset, cream, true)
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name, prompt.ActionText, prompt.ObjectText = "OpenMushroomCrate", "Take mushroom", "Double jump"
	prompt.KeyboardKeyCode, prompt.GamepadKeyCode = Enum.KeyCode.E, Enum.KeyCode.ButtonX
	prompt.MaxActivationDistance, prompt.HoldDuration, prompt.RequiresLineOfSight = config.pickupRadius, 0, false
	prompt.ClickablePrompt = true
	prompt:SetAttribute("PowerupId", config.id)
	prompt.Parent = crate
	folder:SetAttribute("SourcePartCount", count)
	folder.Parent = parent
	return { crate = crate, prompt = prompt, root = folder }
end
return PowerupWorld
