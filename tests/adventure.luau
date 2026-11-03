-- Pure rule and actual adapter boundary tests. These do not simulate Studio physics.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local Rules = require("../src/shared/AdventureRules")
local specs = {
	{ id = "token", kind = "token", score = 1, position = { 0, 3, 0 } },
	{ id = "crate", kind = "crate", score = 5, position = { 20, 3, 0 } },
	{ id = "flag", kind = "landmark", score = 10, position = { 40, 3, 0 } },
}
local springs = { { id = "spring", position = { 60, 0, 0 }, launchSpeed = 70 } }
local function catalog() return Rules.catalog(specs, springs) end
local function signal()
	local handlers = {}
	return {
		Connect = function(_, callback)
			local entry = { callback = callback, active = true }
			table.insert(handlers, entry)
			return { Disconnect = function() entry.active = false end }
		end,
		Fire = function(_, ...)
			for _, entry in handlers do if entry.active then entry.callback(...) end end
		end,
	}
end
local function adapter()
	local now = 10
	local prompt = { Triggered = signal() }
	local shared = { WaitForChild = function(_, name) return name end }
	local services = { ReplicatedStorage = { WaitForChild = function() return shared end } }
	local module = luau.load(fs.readFile("src/server/Adventure.luau"), {
		debugName = "Adventure.luau", injectGlobals = true,
		environment = {
			game = { GetService = function(_, name) return services[name] end },
			require = function(name) assert(name == "AdventureRules"); return Rules end,
			os = { clock = function() return now end }, Vector3 = roblox.Vector3,
		},
	})()
	local world = { items = {}, springs = { { spec = springs[1], part = {} } } }
	for _, spec in specs do table.insert(world.items, { spec = spec, part = {}, prompt = if spec.kind == "crate" then prompt else nil }) end
	local adventure = module.new(world, {})
	local function player()
		local root = { Position = roblox.Vector3.new(0, 3, 0), AssemblyLinearVelocity = roblox.Vector3.zero,
			IsA = function(_, class) return class == "BasePart" end }
		local humanoid = { Health = 100 }
		local character = {
			FindFirstChild = function(_, name) return if name == "HumanoidRootPart" then root else nil end,
			FindFirstChildOfClass = function(_, class) return if class == "Humanoid" then humanoid else nil end,
		}
		local p = { Character = character }
		adventure:add(p)
		return p, root, humanoid
	end
	return adventure, prompt, player, function(value) now = value end
end
local function appearanceRig(r15)
	local appearance = luau.load(fs.readFile("src/server/CourierAppearance.luau"), {
		debugName = "CourierAppearance.luau", injectGlobals = true,
		environment = { Instance = roblox.Instance, Enum = roblox.Enum,
			Color3 = roblox.Color3, Vector3 = roblox.Vector3, CFrame = roblox.CFrame },
	})()
	local character = roblox.Instance.new("Model")
	local humanoid = roblox.Instance.new("Humanoid")
	humanoid.WalkSpeed, humanoid.JumpPower, humanoid.Health, humanoid.Parent = 16, 50, 100, character
	local names = if r15 then {"Head","UpperTorso","LowerTorso","LeftUpperArm","RightUpperArm","LeftHand","RightHand","LeftFoot","RightFoot"}
		else {"Head","Torso","Left Arm","Right Arm","Left Leg","Right Leg"}
	for _, name in names do
		local part = roblox.Instance.new(if r15 then "MeshPart" else "Part")
		part.Name, part.Size = name, roblox.Vector3.new(2,2,1)
		if r15 then part.TextureID = "package://test" end
		part.Parent = character
	end
	local root = roblox.Instance.new("Part")
	root.Name, root.CanCollide, root.Massless, root.Parent = "HumanoidRootPart", true, false, character
	local parcel = roblox.Instance.new("Part")
	parcel.Name, parcel.Color, parcel.Parent = "CourierParcel", roblox.Color3.fromRGB(42,42,42), character
	for _, class in {"Accessory","Shirt","Pants","ShirtGraphic"} do roblox.Instance.new(class).Parent = character end
	local face = roblox.Instance.new("Decal")
	face.Name, face.Parent = "face", character.Head
	return appearance, character, humanoid, root, parcel
end

return function()
	local count = 0
	local function test(name, fn)
		local ok, err = pcall(fn)
		assert(ok, name .. ": " .. tostring(err))
		count += 1
	end
	test("fixed definitions reject unknown kind, score inflation and duplicate IDs", function()
		for _, replacement in {
			{ id = "x", kind = "coins", score = 999, position = { 0, 0, 0 } },
			{ id = "x", kind = "token", score = 999, position = { 0, 0, 0 } },
			specs[1],
		} do assert(not pcall(function() Rules.catalog({ specs[1], replacement }, {}) end)) end
		assert(not pcall(function() Rules.catalog(specs, { { id = "token", position = {0,0,0}, launchSpeed = 70 } }) end))
	end)
	test("finite positions and bounded spring speed required", function()
		for _, value in { 0/0, math.huge, -math.huge, "7" } do
			assert(not Rules.validPosition({ 0, value, 0 }))
			assert(not pcall(function() Rules.catalog({{id="bad",kind="token",score=1,position={0,value,0}}}, {}) end))
		end
		for _, speed in { 0, 47, 101, math.huge, 0/0 } do
			assert(not pcall(function() Rules.catalog({}, {{id="s",position={0,0,0},launchSpeed=speed}}) end))
		end
	end)
	test("catalog copies server definitions", function()
		local c = catalog()
		c.items.token.position[1] = 100
		assert(specs[1].position[1] == 0)
	end)
	test("session score only fixed amounts and once-only", function()
		local c, state = catalog(), Rules.newState()
		assert(Rules.collect(c, state, "token", {0,3,0}, true, 1))
		assert(not Rules.collect(c, state, "token", {0,3,0}, true, 2))
		assert(Rules.collect(c, state, "crate", {20,3,0}, true, 2))
		assert(Rules.collect(c, state, "flag", {40,3,0}, true, 3))
		assert(state.score == 16 and state.collected == 3 and state.landmarks == 1)
	end)
	test("collection distance uses a sphere and exact boundary", function()
		local c = catalog()
		assert(Rules.collect(c, Rules.newState(), "token", {5,3,0}, true, 1))
		assert(not Rules.collect(c, Rules.newState(), "token", {5.001,3,0}, true, 1))
		assert(not Rules.collect(c, Rules.newState(), "token", {4,3,4}, true, 1))
		assert(Rules.collect(c, Rules.newState(), "crate", {29,3,0}, true, 1))
		assert(not Rules.collect(c, Rules.newState(), "crate", {29.01,3,0}, true, 1))
	end)
	test("dead unknown malformed and invalid time cannot collect", function()
		local c, state = catalog(), Rules.newState()
		assert(not Rules.collect(c,state,"invented",{0,3,0},true,1))
		assert(not Rules.collect(c,state,"token",{0,3,0},false,1))
		assert(not Rules.collect(c,state,"token",{0,0/0,0},true,1))
		for _, now in { -1, math.huge, 0/0 } do assert(not Rules.collect(c,state,"token",{0,3,0},true,now)) end
		assert(state.score == 0)
	end)
	test("failed crate attempts rate limit even after moving near", function()
		local c, state = catalog(), Rules.newState()
		assert(not Rules.collect(c,state,"crate",{0,3,0},true,1))
		local ok, why = Rules.collect(c,state,"crate",{20,3,0},true,1.1)
		assert(not ok and why == "rate_limited")
		assert(Rules.collect(c,state,"crate",{20,3,0},true,1.35))
	end)
	test("success cooldown prevents same instant burst and time reversal", function()
		local c, state = catalog(), Rules.newState()
		assert(Rules.collect(c,state,"token",{0,3,0},true,2))
		assert(not Rules.collect(c,state,"flag",{40,3,0},true,2))
		assert(not Rules.collect(c,state,"flag",{40,3,0},true,1))
		assert(Rules.collect(c,state,"flag",{40,3,0},true,2.1))
	end)
	test("players independently collect and snapshot cannot mutate state", function()
		local c, a, b = catalog(), Rules.newState(), Rules.newState()
		assert(Rules.collect(c,a,"flag",{40,3,0},true,1))
		assert(b.score == 0 and not b.collectedIds.flag)
		assert(Rules.collect(c,b,"flag",{40,3,0},true,1))
		local snapshot = Rules.snapshot(c,a)
		assert(snapshot.total == 3 and snapshot.landmarkTotal == 1 and snapshot.collectedIds[1] == "flag")
		snapshot.collectedIds[1] = "bad"
		assert(a.collectedIds.flag and not a.collectedIds.bad)
	end)
	test("spring standing bounds reject undersides sides and airborne roots", function()
		local c = catalog()
		for _, point in { {60,1.49,0}, {60,6.51,0}, {64.51,3,0}, {64,3,4} } do
			assert(not Rules.spring(c,Rules.newState(),"spring",point,true,false,1))
		end
		assert(Rules.spring(c,Rules.newState(),"spring",{64.5,1.5,0},true,false,1))
		assert(Rules.spring(c,Rules.newState(),"spring",{60,6.5,0},true,false,1))
	end)
	test("spring dead running unknown and malformed are refused", function()
		local c, state = catalog(), Rules.newState()
		assert(not Rules.spring(c,state,"spring",{60,3,0},false,false,1))
		assert(not Rules.spring(c,state,"spring",{60,3,0},true,true,1))
		assert(not Rules.spring(c,state,"spring",{60,3,0},true,nil,1))
		assert(not Rules.spring(c,state,"bad",{60,3,0},true,false,1))
		assert(not Rules.spring(c,state,"spring",{60,0/0,0},true,false,1))
		assert(state.score == 0)
	end)
	test("spring fixed launch and global cooldown never award score", function()
		local c, state = catalog(), Rules.newState()
		local ok, speed = Rules.spring(c,state,"spring",{60,3,0},true,false,1)
		assert(ok and speed == 70)
		assert(not Rules.spring(c,state,"spring",{60,3,0},true,false,2.99))
		assert(Rules.spring(c,state,"spring",{60,3,0},true,false,3))
		assert(state.collected == 0 and state.score == 0)
	end)
	test("adapter crate uses current alive server root and once-only score", function()
		local a, prompt, player, time = adapter()
		local p, root, humanoid = player()
		prompt.Triggered:Fire(p)
		assert(a:snapshot(p).score == 0)
		time(11); root.Position = roblox.Vector3.new(20,3,0); humanoid.Health = 0
		prompt.Triggered:Fire(p); assert(a:snapshot(p).score == 0)
		humanoid.Health = 100; prompt.Triggered:Fire(p)
		assert(a:snapshot(p).score == 5)
		time(12); prompt.Triggered:Fire(p); assert(a:snapshot(p).score == 5)
	end)
	test("adapter sample rejects stale root and does not auto open crates", function()
		local a, _, player = adapter()
		local p, root = player()
		local stale = { Position = root.Position }
		a:step(p, stale, true, false, 1); assert(a:snapshot(p).score == 0)
		root.Position = roblox.Vector3.new(20,3,0)
		a:step(p, root, true, false, 2); assert(a:snapshot(p).score == 0)
		root.Position = roblox.Vector3.new(0,3,0)
		a:step(p, root, true, false, 3); assert(a:snapshot(p).score == 1)
		p.Character = nil
		a:step(p, nil, true, false, 4)
		assert(a:snapshot(p).score == 1)
	end)
	test("adapter idle springs clamp velocity while active delivery gets no boost", function()
		local a, _, player = adapter()
		local p, root = player()
		root.Position = roblox.Vector3.new(60,3,0)
		root.AssemblyLinearVelocity = roblox.Vector3.new(90,-5,-90)
		a:step(p,root,true,true,1)
		assert(root.AssemblyLinearVelocity.Y == -5)
		a:step(p,root,true,false,2)
		assert(root.AssemblyLinearVelocity == roblox.Vector3.new(40,70,-40))
		root.AssemblyLinearVelocity = roblox.Vector3.new(0,0,0)
		a:step(p,root,true,false,2.1); assert(root.AssemblyLinearVelocity.Y == 0)
		root.AssemblyLinearVelocity = roblox.Vector3.new(0/0,0,math.huge)
		a:step(p,root,true,false,4)
		assert(root.AssemblyLinearVelocity == roblox.Vector3.new(0,70,0))
	end)
	test("adapter respawn preserves collection; removal and teardown clean state", function()
		local a, prompt, player = adapter()
		local p, root = player()
		a:step(p,root,true,false,1)
		a:add(p); assert(a:snapshot(p).score == 1)
		local other = player(); assert(a:snapshot(other).score == 0)
		a:remove(p); assert(a:snapshot(p) == nil)
		a:add(p); assert(a:snapshot(p).score == 0)
		a:destroy(); a:destroy(); prompt.Triggered:Fire(p)
		a:add(p); assert(a:snapshot(p) == nil and a:snapshot(other) == nil)
	end)
	for _, r15 in { false, true } do
		test((if r15 then "R15" else "R6") .. " outfit is idempotent welded noncolliding geometry and preserves movement", function()
			local appearance, character, humanoid, root, parcel = appearanceRig(r15)
			assert(appearance.apply(character))
			local old = character.CourierOutfit
			local partCount = 0
			for _, part in old:GetChildren() do
				assert(part:IsA("BasePart") and not part.Anchored and part.Massless)
				assert(not part.CanCollide and not part.CanTouch and not part.CanQuery)
				local weld = part:FindFirstChildOfClass("WeldConstraint")
				assert(weld and weld.Part1 == part and weld.Part0.Parent == character)
				partCount += 1
			end
			assert(partCount >= 20 and old:FindFirstChild("CourierCapBadge") and old:FindFirstChild("OverallBib"))
			assert(not character:FindFirstChildOfClass("Accessory") and not character:FindFirstChildOfClass("Shirt"))
			assert(not character.Head:FindFirstChild("face"))
			if r15 then assert(character.UpperTorso.TextureID == "") end
			assert(humanoid.WalkSpeed == 16 and humanoid.JumpPower == 50 and humanoid.Health == 100)
			assert(root.CanCollide and not root.Massless and parcel.Color == roblox.Color3.fromRGB(42,42,42))
			assert(appearance.apply(character))
			assert(old.Parent == nil and #character.CourierOutfit:GetChildren() == partCount)
		end)
	end
	test("appearance waits for caller to supply a complete rig", function()
		local appearance, character = appearanceRig(false)
		character.Head:Destroy()
		assert(not appearance.apply(character) and not character:FindFirstChild("CourierOutfit"))
	end)
	return count
end
