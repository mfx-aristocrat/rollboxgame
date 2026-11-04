-- Original primitive-built courier costume. Only the live game character changes.
-- Call after CharacterAppearanceLoaded and again for each respawn. No asset requests/yields.
local CourierAppearance = {}
local colors = {
	red = Color3.fromRGB(227, 58, 52), blue = Color3.fromRGB(35, 105, 216),
	yellow = Color3.fromRGB(255, 211, 65), white = Color3.fromRGB(255, 249, 229),
	brown = Color3.fromRGB(98, 53, 35), dark = Color3.fromRGB(48, 30, 25),
	skin = Color3.fromRGB(255, 204, 155), cyan = Color3.fromRGB(50, 196, 209),
}
local function limb(character, ...)
	for _, name in { ... } do
		local part = character:FindFirstChild(name)
		if part and part:IsA("BasePart") then return part end
	end
	return nil
end
local function costumePart(model, name, anchor, size, offset, color, shape)
	local part = Instance.new("Part")
	part.Name, part.Size, part.Color = name, size, color
	part.Material, part.Shape = Enum.Material.SmoothPlastic, shape or Enum.PartType.Block
	part.Anchored, part.Massless = false, true
	part.CanCollide, part.CanTouch, part.CanQuery, part.CastShadow = false, false, false, false
	part.CFrame = anchor.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1, weld.Parent = anchor, part, part
	part.Parent = model
	return part
end
function CourierAppearance.apply(character)
	local head = limb(character, "Head")
	local torso = limb(character, "UpperTorso", "Torso")
	if not head or not torso or not character:FindFirstChildOfClass("Humanoid") then return false end
	local old = character:FindFirstChild("CourierOutfit")
	if old then old:Destroy() end
	for _, child in character:GetChildren() do
		if child:IsA("Accessory") or child:IsA("Shirt") or child:IsA("Pants") or child:IsA("ShirtGraphic") then
			child:Destroy()
		elseif child:IsA("BasePart") and child.Name ~= "HumanoidRootPart" and child.Name ~= "CourierParcel" then
			local name = child.Name
			child.Color = if name == "Head" then colors.skin
				elseif string.find(name, "Leg") or string.find(name, "Foot") or name == "LowerTorso" then colors.blue
				elseif string.find(name, "Hand") then colors.white else colors.red
			-- Package textures/layered clothing must not cover the source-authored colors.
			if child:IsA("MeshPart") then child.TextureID = "" end
			for _, surface in child:GetChildren() do
				if surface:IsA("SurfaceAppearance") or (name == "Head" and surface:IsA("Decal")) then surface:Destroy()
				elseif surface:IsA("SpecialMesh") then surface.TextureId = "" end
			end
		end
	end
	local model = Instance.new("Model")
	model.Name = "CourierOutfit"
	local function piece(name, anchor, size, offset, color, shape)
		return costumePart(model, name, anchor, size, offset, color, shape)
	end
	local width, height, depth = torso.Size.X, torso.Size.Y, torso.Size.Z
	-- Red shirt surrounds the existing rig while a shallow blue bib leaves arms free.
	piece("RedShirt", torso, Vector3.new(width * 1.03, height * 0.96, depth * 1.04), CFrame.new(), colors.red)
	piece("OverallBib", torso, Vector3.new(width * 0.72, height * 0.65, 0.12),
		CFrame.new(0, -height * 0.14, -depth * 0.53), colors.blue)
	for _, side in { -1, 1 } do
		piece("OverallStrap", torso, Vector3.new(width * 0.13, height * 0.85, 0.13),
			CFrame.new(side * width * 0.29, height * 0.05, -depth * 0.55), colors.blue)
		piece("YellowButton", torso, Vector3.new(0.18, 0.18, 0.1),
			CFrame.new(side * width * 0.29, height * 0.06, -depth * 0.65), colors.yellow, Enum.PartType.Ball)
	end
	for _, side in { "Left", "Right" } do
		local arm = limb(character, side .. "UpperArm", side .. " Arm")
		if arm then
			piece(side .. "RedSleeve", arm, arm.Size * Vector3.new(1.035, 0.85, 1.035), CFrame.new(0, arm.Size.Y * 0.04, 0), colors.red)
		end
		local hand = limb(character, side .. "Hand", side .. " Arm")
		if hand then
			local r6 = hand.Name == side .. " Arm"
			piece(side .. "WhiteGlove", hand, Vector3.new(hand.Size.X * 1.08, if r6 then hand.Size.Y * 0.28 else hand.Size.Y * 1.08, hand.Size.Z * 1.08),
				CFrame.new(0, if r6 then -hand.Size.Y * 0.36 else 0, 0), colors.white)
		end
		local foot = limb(character, side .. "Foot", side .. " Leg")
		if foot then
			local r6 = foot.Name == side .. " Leg"
			piece(side .. "BrownBoot", foot, Vector3.new(foot.Size.X * 1.08, if r6 then foot.Size.Y * 0.30 else foot.Size.Y * 1.1, foot.Size.Z * 1.2),
				CFrame.new(0, if r6 then -foot.Size.Y * 0.35 else 0, -foot.Size.Z * 0.09), colors.brown)
		end
	end
	local hx, hy, hz = head.Size.X, head.Size.Y, head.Size.Z
	piece("RedCapCrown", head, Vector3.new(hx * 1.1, hy * 0.65, hz * 1.1), CFrame.new(0, hy * 0.48, 0), colors.red, Enum.PartType.Ball)
	piece("RedCapBrim", head, Vector3.new(hx * 1.1, 0.13, hz * 0.85), CFrame.new(0, hy * 0.25, -hz * 0.45), colors.red)
	-- Own courier badge: a cyan parcel on cream, with a gold address strip.
	piece("CourierCapBadge", head, Vector3.new(hx * 0.32, hy * 0.32, 0.11), CFrame.new(0, hy * 0.48, -hz * 0.51), colors.white, Enum.PartType.Ball)
	piece("CourierBadgeParcel", head, Vector3.new(hx * 0.16, hy * 0.14, 0.12), CFrame.new(0, hy * 0.48, -hz * 0.57), colors.cyan)
	piece("CourierBadgeAddress", head, Vector3.new(hx * 0.025, hy * 0.14, 0.13), CFrame.new(0, hy * 0.48, -hz * 0.58), colors.yellow)
	for _, side in { -1, 1 } do
		piece("EyeWhite", head, Vector3.new(hx * 0.15, hy * 0.25, 0.12), CFrame.new(side * hx * 0.17, hy * 0.04, -hz * 0.49), colors.white, Enum.PartType.Ball)
		piece("EyePupil", head, Vector3.new(hx * 0.065, hy * 0.13, 0.13), CFrame.new(side * hx * 0.17, hy * 0.025, -hz * 0.55), colors.dark, Enum.PartType.Ball)
		piece("Moustache", head, Vector3.new(hx * 0.33, hy * 0.18, 0.2),
			CFrame.new(side * hx * 0.13, -hy * 0.19, -hz * 0.53) * CFrame.Angles(0, 0, side * math.rad(12)), colors.dark, Enum.PartType.Ball)
	end
	piece("CourierNose", head, Vector3.new(hx * 0.23, hy * 0.23, hz * 0.28), CFrame.new(0, -hy * 0.08, -hz * 0.57), colors.skin, Enum.PartType.Ball)
	model.Parent = character
	return true
end
return CourierAppearance
