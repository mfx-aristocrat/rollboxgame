-- Original primitive-built orange mushroom and striped targets. No external asset IDs.
local BlasterWorld = {}
function BlasterWorld.build(parent, config)
	local previous = parent:FindFirstChild("OrangeMushroomBlaster")
	if previous then previous:Destroy() end
	local model = Instance.new("Model")
	model.Name = "OrangeMushroomBlaster"
	local cream, orange = Color3.fromRGB(255, 244, 205), Color3.fromRGB(255, 149, 51)
	local at = Vector3.new(table.unpack(config.cratePosition))
	local count = 0
	local function part(name, size, position, color, ball, query)
		local p = Instance.new("Part")
		p.Name, p.Size, p.Position, p.Color = name, size, position, color
		p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, query == true
		p.Material = Enum.Material.SmoothPlastic
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		if ball then p.Shape = Enum.PartType.Ball end
		p:SetAttribute("PowerupId", config.id)
		p.Parent = model; count += 1
		return p
	end
	local crate = part("OrangeMushroomCrate", Vector3.new(4, 3.5, 4), at, Color3.fromRGB(148,94,64))
	crate.Material = Enum.Material.WoodPlanks
	part("CrateLid", Vector3.new(4.4,0.45,4.4), at+Vector3.new(0,1.65,0), orange)
	for _, z in {-2.04,2.04} do part("CrateBand", Vector3.new(0.65,3.5,0.12),at+Vector3.new(0,0,z),cream) end
	part("OrangeMushroomStem",Vector3.new(1.4,2.2,1.4),at+Vector3.new(0,2.8,0),cream,true)
	part("OrangeMushroomCap",Vector3.new(4.1,2.1,4.1),at+Vector3.new(0,4,0),orange,true)
	for _, offset in {Vector3.new(0,5.01,0),Vector3.new(-1.25,4.65,-0.5),Vector3.new(1.15,4.65,0.65),Vector3.new(-0.5,4.4,1.7),Vector3.new(0.65,4.45,-1.6)} do
		part("OrangeMushroomSpot",Vector3.new(0.75,0.3,0.75),at+offset,cream,true)
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name, prompt.ActionText, prompt.ObjectText = "OpenOrangeMushroomCrate", "Take orange mushroom", "Practice cannon"
	prompt.KeyboardKeyCode, prompt.GamepadKeyCode = Enum.KeyCode.E, Enum.KeyCode.ButtonX
	prompt.MaxActivationDistance, prompt.HoldDuration, prompt.RequiresLineOfSight = config.pickupRadius, 0, false
	prompt.ClickablePrompt = true
	prompt:SetAttribute("PowerupId",config.id); prompt.Parent = crate
	local targets = {}
	for _, spec in config.targets do
		local center = Vector3.new(table.unpack(spec.position))
		local target = part("PracticeTarget_"..spec.id,Vector3.new(5,5,0.7),center,orange,false,true)
		target:SetAttribute("TargetId",spec.id); target:SetAttribute("HitCount",0)
		-- Faces west toward the crate. Cosmetic rings remain non-queryable.
		target.CFrame = CFrame.new(center) * CFrame.Angles(0,math.rad(90),0)
		for index, size in {3.5,1.7} do
			local ring = part("TargetRing",Vector3.new(size,size,0.12),center,if index==1 then cream else orange,false,false)
			ring.CFrame = target.CFrame * CFrame.new(0,0,-0.42 - index*0.02)
		end
		part("TargetPost",Vector3.new(0.65,10,0.65),center-Vector3.new(0,7.5,0),Color3.fromRGB(139,96,66))
		table.insert(targets,{part=target,spec=spec})
	end
	model:SetAttribute("SourcePartCount",count)
	model.Parent=parent
	return {root=model,model=model,crate=crate,prompt=prompt,targets=targets}
end
return BlasterWorld
