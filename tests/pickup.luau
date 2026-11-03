-- Execute the actual client/server entrypoints with engine boundary fakes.
-- These are behavioral adapter tests, not Studio input/physics validation.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local Config = require("../src/shared/Config")
local Rules = require("../src/shared/RunRules")
local Progression = require("../src/shared/Progression")
local Profile = require("../src/shared/Profile")

local function signal()
    local callbacks = {}
    return {
        Connect = function(_, fn)
            table.insert(callbacks, fn)
            return { Disconnect = function() end }
        end,
        Fire = function(_, ...)
            for _, fn in callbacks do fn(...) end
        end,
    }
end

local function clientHarness(forward)
    local objects, requests = {}, {}
    local input, received, properties, focused = signal(), signal(), signal(), false
    local intent = { FireServer = function(_, action, argument)
        table.insert(requests, { action, argument })
        if forward then forward(action, argument) end
    end }
    local remotes = { WaitForChild = function(_, name) return if name == "Intent" then intent else { OnClientEvent = received } end }
    local player = { WaitForChild = function() return {} end }
    local function dimensions(...) return { ... } end
    local enum = setmetatable({}, { __index = function(_, category)
        return setmetatable({}, { __index = function(_, name) return category .. "." .. name end })
    end })
    local services = {
        Players = { LocalPlayer = player },
        ReplicatedStorage = { WaitForChild = function() return remotes end },
        UserInputService = { InputBegan = input, GetFocusedTextBox = function() return if focused then {} else nil end },
    }
    local instance = { new = function(class)
        local item = { ClassName = class, Activated = signal() }
        table.insert(objects, item)
        return item
    end }
    luau.load(fs.readFile("src/client/Main.client.luau"), {
        debugName = "Main.client.luau", injectGlobals = true,
        environment = {
            game = { GetService = function(_, name) assert(services[name], name); return services[name] end },
            Instance = instance, Enum = enum,
            Color3 = { fromRGB = dimensions }, Vector2 = { new = dimensions },
            UDim = { new = dimensions }, UDim2 = { new = dimensions, fromOffset = dimensions, fromScale = dimensions },
            workspace = { CurrentCamera = nil, GetPropertyChangedSignal = function() return properties end },
            task = { spawn = function() end, wait = function() end },
        },
    })()
    local function find(name)
        for _, item in objects do if item.Name == name then return item end end
        error("Missing UI " .. name)
    end
    return { input = input, received = received, requests = requests, find = find, enum = enum,
        focused = function(value) focused = value end }
end

local function serverHarness()
    local objects, messages, now, writable, ids = {}, {}, 10, true, 0
    local function object(class)
        local item = { ClassName = class, children = {} }
        function item:FindFirstChild(name)
            for _, child in objects do if child.Parent == self and child.Name == name and not child.destroyed then return child end end
            return self.children[name]
        end
        function item:FindFirstChildOfClass(name) return self.children[name] end
        function item:Destroy() self.destroyed = true end
        if class == "RemoteEvent" then
            item.OnServerEvent = signal()
            function item:FireClient(recipient, data) messages[recipient] = data end
        end
        table.insert(objects, item)
        return item
    end
    local player = { UserId = 123, CharacterAdded = signal(), CharacterAppearanceLoaded = signal() }
    local data = { profile = Profile.createCodec(Config).default(), mode = "Practice", message = "Not saved" }
    local playerData = {
        open = function() return data end, canWrite = function() return writable end,
        changed = function() error("pickup must never change saved progression") end,
    }
    local prompt = { Triggered = signal() }
    local modules = {
        Config = Config, RunRules = Rules, Progression = Progression, Profile = Profile,
        ServerSettings = { persistenceEnabled = false }, Persistence = {},
        PlayerData = { new = function() return playerData end },
        World = { build = function() return { prompt = prompt } end },
        Adventure = { new = function() return { add = function() end, remove = function() end, step = function() end, snapshot = function() return nil end, destroy = function() end } end },
        CourierAppearance = { apply = function() end },
    }
    local shared = setmetatable({}, { __index = function(_, name) return name end })
    local parent = setmetatable({}, { __index = function(_, name) return name end })
    local services = {
        Players = { PlayerAdded = signal(), PlayerRemoving = signal(), GetPlayers = function() return { player } end },
        ReplicatedStorage = { WaitForChild = function() return shared end },
        RunService = { Heartbeat = signal() },
        PhysicsService = { RegisterCollisionGroup = function() end, CollisionGroupSetCollidable = function() end },
        HttpService = { GenerateGUID = function() ids += 1; return "run-" .. ids end },
    }
    luau.load(fs.readFile("src/server/Main.server.luau"), {
        debugName = "Main.server.luau", injectGlobals = true,
        environment = {
            game = { GetService = function(_, name) assert(services[name], name); return services[name] end, BindToClose = function() end },
            script = { Parent = parent }, require = function(name) assert(modules[name], name); return modules[name] end,
            Instance = { new = object }, Vector3 = roblox.Vector3, CFrame = roblox.CFrame, Color3 = roblox.Color3,
            os = { clock = function() return now end }, task = { spawn = function() end },
        },
    })()
    local root = object("Part")
    root.Name, root.Position, root.CFrame = "HumanoidRootPart", roblox.Vector3.new(7, 12, 0), roblox.CFrame.new(7, 12, 0)
    local humanoid = { Health = 100 }
    local character = object("Model")
    character.children = { HumanoidRootPart = root, Humanoid = humanoid }
    player.Character = character
    local intent
    for _, item in objects do if item.Name == "Intent" then intent = item end end
    return {
        player = player, prompt = prompt, root = root, humanoid = humanoid, character = character, data = data,
        request = function(action, argument) intent.OnServerEvent:Fire(player, action, argument) end,
        latest = function(recipient) return messages[recipient or player] end,
        time = function(value) now = value end,
        writable = function(value) writable = value end,
        ids = function() return ids end,
        addPlayer = function()
            local other = { UserId = 456, CharacterAdded = signal(), CharacterAppearanceLoaded = signal() }
            services.Players.PlayerAdded:Fire(other)
            local otherRoot = object("Part")
            otherRoot.Position, otherRoot.CFrame = root.Position, root.CFrame
            local otherCharacter = object("Model")
            otherCharacter.children = { HumanoidRootPart = otherRoot, Humanoid = { Health = 100 } }
            other.Character = otherCharacter
            return other
        end,
    }
end

return function()
    local count = 0
    local function test(name, fn)
        local ok, err = pcall(fn)
        assert(ok, name .. ": " .. tostring(err))
        count += 1
    end
    test("actual prompt near visible station starts pickup", function()
        local server = serverHarness()
        server.root.Position = roblox.Vector3.new(18, 12, 0)
        server.prompt.Triggered:Fire(server.player)
        server.request("Snapshot")
        assert(server.latest().state == "Running", "native prompt fired 11 studs from box but server rejected pickup")
    end)
    test("actual client E sends pickup request", function()
        local client = clientHarness()
        client.input:Fire({ KeyCode = client.enum.KeyCode.E }, false)
        assert(#client.requests == 1 and client.requests[1][1] == "Start", "pressing advertised E sent no Start intent")
    end)
    test("actual client E reaches actual server pickup handler", function()
        local server = serverHarness()
        server.root.Position = roblox.Vector3.new(18, 12, 0)
        local client = clientHarness(server.request)
        server.request("Snapshot")
        client.received:Fire(server.latest())
        client.input:Fire({ KeyCode = client.enum.KeyCode.E }, false)
        client.received:Fire(server.latest())
        assert(server.latest().state == "Running" and server.character:FindFirstChild("CourierParcel"))
        assert(client.find("Route").Text == "CARRYING PARCEL • 0 coins")
    end)
    test("actual client touch button shares pickup request", function()
        local client = clientHarness()
        client.find("Start").Activated:Fire()
        assert(client.requests[1][1] == "Start")
    end)
    test("processed keyboard input never double triggers", function()
        local client = clientHarness()
        client.input:Fire({ KeyCode = client.enum.KeyCode.E }, true)
        assert(#client.requests == 0)
    end)
    test("typing E never triggers pickup", function()
        local client = clientHarness()
        client.focused(true)
        client.input:Fire({ KeyCode = client.enum.KeyCode.E }, false)
        assert(#client.requests == 0)
    end)
    test("shop modal blocks keyboard pickup", function()
        local client = clientHarness()
        client.find("OpenShells").Activated:Fire()
        client.input:Fire({ KeyCode = client.enum.KeyCode.E }, false)
        assert(#client.requests == 0)
    end)
    test("actual prompt and remote cannot restart active run", function()
        local server = serverHarness()
        server.prompt.Triggered:Fire(server.player)
        local held = server.character:FindFirstChild("CourierParcel")
        server.time(12)
        server.request("Start")
        assert(server.ids() == 1 and server.latest().elapsed == 2)
        assert(server.character:FindFirstChild("CourierParcel") == held)
        assert(server.data.profile.coins == 0 and server.data.profile.completedRuns == 0)
    end)
    test("actual server pickup is held in front with carrying confirmation", function()
        local server = serverHarness()
        server.request("Start")
        local held = server.character:FindFirstChild("CourierParcel")
        assert(held and server.root.CFrame:ToObjectSpace(held.CFrame).Z < -1)
        assert(not held.CanCollide and not held.CanTouch and held.Massless)
        assert(server.latest().carryingParcel and string.find(server.latest().message, "picked up"))
    end)
    test("actual server rejects outside box radius even inside old depot radius", function()
        local server = serverHarness()
        server.root.Position = roblox.Vector3.new(-14, 12, 0)
        server.request("Start")
        local state = server.latest()
        assert(state.state == "Idle" and state.nearDepot and not state.nearPickup)
        assert(string.find(state.message, "Move closer") and server.ids() == 0)
        assert(server.character:FindFirstChild("CourierParcel") == nil)
    end)
    test("actual server accepts box radius boundary", function()
        local server = serverHarness()
        server.root.Position = roblox.Vector3.new(Config.pickup.position[1] + Config.pickup.radius, Config.pickup.position[2], Config.pickup.position[3])
        server.request("Start")
        assert(server.latest().state == "Running" and server.latest().nearPickup)
    end)
    test("actual server rejects dead character visibly", function()
        local server = serverHarness()
        server.humanoid.Health = 0
        server.request("Start")
        assert(server.latest().state == "Idle" and string.find(server.latest().message, "respawn"))
        assert(server.ids() == 0)
    end)
    test("actual server blocks pickup when profile is unavailable", function()
        local server = serverHarness()
        server.writable(false)
        server.data.message = "Data not ready; rejoin."
        server.prompt.Triggered:Fire(server.player)
        assert(server.latest().state == "Idle" and server.latest().message == server.data.message)
        assert(server.ids() == 0)
    end)
    test("actual handler rejects malformed and flooded pickup intents", function()
        local server = serverHarness()
        server.request("Start", { coins = 1000 })
        server.request("Snapshot")
        assert(server.latest().state == "Idle")
        for _ = 1, 100 do server.request("Start") end
        assert(server.ids() == 1 and server.data.profile.coins == 0)
    end)
    test("shared station remains available for a second player", function()
        local server = serverHarness()
        server.prompt.Triggered:Fire(server.player)
        local other = server.addPlayer()
        server.prompt.Triggered:Fire(other)
        assert(server.latest().state == "Running" and server.latest(other).state == "Running")
        assert(server.ids() == 2)
        assert(server.character:FindFirstChild("CourierParcel") ~= other.Character:FindFirstChild("CourierParcel"))
    end)
    test("actual server snapshot drives carrying UI and correct pickup eligibility", function()
        local server, client = serverHarness(), clientHarness()
        server.request("Start")
        client.received:Fire(server.latest())
        assert(string.find(client.find("Route").Text, "CARRYING PARCEL"))
        assert(not client.find("Start").Visible and client.find("Switch").Visible)
        client.input:Fire({ KeyCode = client.enum.KeyCode.E }, false)
        assert(#client.requests == 0)
        server = serverHarness()
        server.root.Position = roblox.Vector3.new(-14, 12, 0)
        server.request("Snapshot")
        client.received:Fire(server.latest())
        assert(client.find("Start").Text == "Move to parcel box")
    end)
    test("completed run E requests free retry", function()
        local server, client = serverHarness(), clientHarness()
        server.request("Snapshot")
        local state = server.latest()
        state.state, state.resultTime = "Completed", 25
        client.received:Fire(state)
        client.input:Fire({ KeyCode = client.enum.KeyCode.E }, false)
        assert(client.requests[1][1] == "Retry")
    end)
    test("exploration snapshot updates HUD without changing delivery balance", function()
        local server, client = serverHarness(), clientHarness()
        server.request("Snapshot")
        local state = server.latest()
        state.adventure = { collected = 3, total = 40, score = 12, landmarks = 1, message = "Garden pennant found!", collectedIds = { "token-01" } }
        client.received:Fire(state)
        assert(client.find("Expedition").Text == "EXPLORE 3/40  |  12 session pts  |  1/6 flags")
        assert(client.find("Message").Text == "Garden pennant found!")
        assert(string.find(client.find("Route").Text, "0 coins"))
        server.request("Start")
        state = server.latest()
        state.adventure = { collected = 3, total = 40, score = 12, landmarks = 1, message = "Old exploration hint", collectedIds = {} }
        client.received:Fire(state)
        assert(client.find("Route").Text == "CARRYING PARCEL • 0 coins")
        assert(client.find("Message").Text == state.message, "delivery guidance must remain visible while carrying")
    end)
    return count
end
