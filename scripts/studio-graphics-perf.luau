-- Execute through official Studio MCP in this task's Client VM only.
-- Warm A/B of original decoration/materials versus the new presentation under
-- identical Realistic lighting. Resident assets/Studio overhead remain in both.
local Http = game:GetService("HttpService")
local Run = game:GetService("RunService")
local player = game:GetService("Players").LocalPlayer
assert(Run:IsClient() and player, "Client VM required")
local gui = player:WaitForChild("PlayerGui")
assert(not gui:FindFirstChild("__RollboxGraphicsPerf"), "Inspect previous probe first")
local marker = Instance.new("StringValue")
marker.Name, marker.Value = "__RollboxGraphicsPerf", "RUNNING"
marker:SetAttribute("RollboxTestFixture", true)
marker.Parent = gui
task.spawn(function()
    local camera = workspace.CurrentCamera
    local originalFrame, originalType = camera.CFrame, camera.CameraType
    local root = workspace:WaitForChild("SwitchbackWorld", 20)
    local folder = root and root:FindFirstChild("WorldPresentation")
    local snapshots = {}
    if root then
        for _, p in root:GetDescendants() do
            if p:IsA("BasePart") and p:GetAttribute("RollboxPresentationOwner") == "WorldPresentation/v1" then
                table.insert(snapshots, { part = p, color = p.Color, variant = p.MaterialVariant, transparency = p.Transparency })
            end
        end
    end
    local function restore()
        for _, s in snapshots do
            if s.part.Parent then s.part.Color = s.color; s.part.MaterialVariant = s.variant; s.part.Transparency = s.transparency end
        end
        if folder and root then folder.Parent = root end
        camera.CameraType, camera.CFrame = originalType, originalFrame
    end
    local ok, result = pcall(function()
        assert(root and folder and #snapshots > 0, "Source presentation not ready")
        local stats = game:GetService("Stats")
        local views = {
            { name = "depot", p = Vector3.new(65, 35, 80), look = Vector3.new(0, 6, -25) },
            { name = "meadow", p = Vector3.new(-265, 24, 130), look = Vector3.new(-220, 1, 210) },
            { name = "coast", p = Vector3.new(515, 38, 330), look = Vector3.new(390, 1, 275) },
        }
        local rows = {}
        camera.CameraType = Enum.CameraType.Scriptable
        for _, mode in { "baselineAppearance", "graphics" } do
            if mode == "baselineAppearance" then
                folder.Parent = nil
                for _, s in snapshots do
                    s.part.Color = s.part:GetAttribute("RollboxOriginalColor")
                    s.part.MaterialVariant = s.part:GetAttribute("RollboxOriginalVariant")
                    s.part.Transparency = s.part:GetAttribute("RollboxOriginalTransparency")
                end
            else
                restore()
                camera.CameraType = Enum.CameraType.Scriptable
            end
            for _, v in views do
                camera.CFrame = CFrame.lookAt(v.p, v.look)
                task.wait(2)
                local frames, total, start = {}, 0, os.clock()
                for _ = 1, 180 do
                    local dt = Run.RenderStepped:Wait()
                    table.insert(frames, dt * 1000)
                    total += dt
                    if os.clock() - start >= 15 then break end
                end
                table.sort(frames)
                local function percentile(p) return frames[math.clamp(math.ceil(#frames * p), 1, #frames)] end
                local row = { mode = mode, view = v.name, frames = #frames, seconds = total,
                    meanMs = total / #frames * 1000, medianMs = percentile(0.5), p95Ms = percentile(0.95),
                    maxMs = frames[#frames], fpsFromMean = #frames / total,
                    viewport = { camera.ViewportSize.X, camera.ViewportSize.Y },
                    totalMemoryMb = stats:GetTotalMemoryUsageMb() }
                local hasTexture, texture = pcall(function() return stats:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.GraphicsTexture) end)
                if hasTexture then row.textureMemoryMb = texture end
                table.insert(rows, row)
            end
        end
        return { finished = true, rows = rows, lighting = game:GetService("Lighting").LightingStyle.Name,
            method = "Warm single-client RenderStepped A/B; identical lighting; three Studio processes open; assets remain resident in both modes" }
    end)
    restore()
    marker.Value = Http:JSONEncode(if ok then result else { finished = true, error = tostring(result) })
end)
return "Graphics performance probe started"
