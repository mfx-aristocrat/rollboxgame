-- Scheduler/store-injected lifecycle. Roblox wiring lives in Main.server.luau.
local PlayerData = {}
function PlayerData.new(settings, codec, deps)
    local entries, service = {}, {}
    local task, os, warn = deps.scheduler, deps.clock, deps.warn
    local persistence = if settings.persistenceEnabled then deps.persistence else nil
    local configurationError = if settings.persistenceEnabled and not persistence then (deps.configurationError or "Verify datastore configuration before progressing.") else nil
    local function forgetWhenExpired(userId, entry)
        -- Leave workers are joined first; uncertain releases keep their lock until
        -- expiry. Retire bookkeeping later without replaying any stale profile.
        task.delay(185, function()
            if entries[userId] == entry and not entry.operation then
                if persistence then persistence.forget(userId) end
                entries[userId] = nil
            end
        end)
    end
    function service.open(userId)
        if entries[userId] then return nil, "previous_session_closing" end
        local entry = {
            profile = codec.default(), ready = not settings.persistenceEnabled,
            closing = false, operation = false, revision = 0, savedRevision = 0,
            mode = if settings.persistenceEnabled then "Loading" else "Practice",
            message = if settings.persistenceEnabled then "Loading saved progress…" else "Session only — progress resets on leave",
            nextSave = os.clock() + 45 + (userId % 15),
        }
        entries[userId] = entry
        if configurationError then
            entry.mode, entry.message = "Unavailable", configurationError
        elseif persistence then
            entry.operation = true
            task.spawn(function()
                local loaded = persistence.load(userId)
                entry.operation = false
                if loaded.ok then
                    entry.profile, entry.ready, entry.mode = loaded.profile, true, "Saved progress"
                    entry.message = "Progress loaded"
                else
                    entry.mode, entry.message = "Unavailable", "Progress could not load (" .. loaded.reason .. "). Rejoin to retry."
                    warn("Profile load failed:", userId, loaded.reason)
                end
                if entry.closing and not entry.closeWorker then service.close(userId, os.time() + 10) end
            end)
        end
        return entry
    end
    function service.canWrite(userId)
        local entry = entries[userId]
        if not entry or not entry.ready or entry.closing then return false end
        if persistence and not persistence.status(userId).canWrite then
            -- ready records successful load, not the cached lease. An in-flight
            -- save can renew ownership after this sample; every call rechecks it.
            entry.mode, entry.message = "Unavailable", "Save session expired. Rejoin before progressing."
            return false
        end
        return true
    end
    function service.changed(userId)
        local entry = entries[userId]
        entry.revision += 1
        if persistence then entry.message = "Unsaved changes • autosave within 60 seconds" end
    end
    function service.save(userId)
        local entry = entries[userId]
        if not persistence or not service.canWrite(userId) or entry.operation then return end
        entry.operation = true
        local revision = entry.revision
        local outcome = persistence.save(userId, entry.profile)
        entry.operation = false
        if outcome.ok then
            entry.savedRevision = revision
            entry.mode = "Saved progress"
            entry.message = if entry.revision == revision then "Progress saved" else "Unsaved changes • autosave within 60 seconds"
        else
            entry.message = "Save not confirmed (" .. outcome.reason .. "). Retrying; avoid leaving."
            warn("Profile save failed:", userId, outcome.reason)
            service.canWrite(userId)
        end
        if entry.closing and not entry.closeWorker then service.close(userId, os.time() + 10) end
    end
    function service.tick()
        local now = os.clock()
        for userId, entry in pairs(entries) do
            if not entry.closing and now >= entry.nextSave then
                entry.nextSave = now + 60
                task.spawn(function() service.save(userId) end)
            end
        end
    end
    function service.close(userId, deadline)
        local entry = entries[userId]
        if not entry then return true end
        entry.closing = true -- Freeze gameplay before waiting for in-flight saves.
        if entry.closeWorker then
            while entries[userId] == entry and entry.closeWorker and os.time() < deadline do task.wait(0.1) end
            return entries[userId] ~= entry
        end
        entry.closeWorker = true
        while entry.operation and os.time() < deadline do task.wait(0.1) end
        if entry.operation then entry.closeWorker = false; return false end -- Worker schedules late cleanup.
        if not persistence or not entry.ready then
            if persistence then persistence.forget(userId) end
            entries[userId] = nil
            return true
        end
        entry.operation = true
        local result
        repeat
            result = persistence.release(userId, entry.profile, deadline)
            if not result.ok and result.reason == "busy" then task.wait(0.1) end
        until result.ok or result.reason ~= "busy" or os.time() >= deadline
        entry.operation = false
        if result.ok then
            persistence.forget(userId)
            entries[userId] = nil
            return true
        end
        entry.closeWorker = false
        warn("Final save not confirmed:", userId, result.reason)
        forgetWhenExpired(userId, entry)
        return false
    end
    function service.shutdown()
        local deadline, pending = os.time() + 25, 0
        for userId in pairs(entries) do
            pending += 1
            task.spawn(function()
                service.close(userId, deadline)
                pending -= 1
            end)
        end
        while pending > 0 and os.time() < deadline do task.wait(0.1) end
    end
    return service
end
return PlayerData
