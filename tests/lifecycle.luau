local PlayerData = require("../src/server/PlayerData")
local Profile = require("../src/shared/Profile")
local Config = require("../src/shared/Config")
local codec = Profile.createCodec(Config)

local function fixture(enabled, configured)
    local f = { time = 1000, queue = {}, delays = {}, durable = codec.default(), saves = 0, releases = 0, warnings = 0, canWrite = true }
    local scheduler = {}
    function scheduler.spawn(fn) table.insert(f.queue, fn) end
    function scheduler.delay(delay, fn) table.insert(f.delays, { at = f.time + delay, fn = fn }) end
    function f.drain()
        if f.blockQueue then return end
        while #f.queue > 0 do table.remove(f.queue, 1)() end
    end
    function scheduler.wait(seconds)
        f.time += seconds
        f.drain()
    end
    local persistence = {
        load = function()
            if f.failLoad then return { ok = false, reason = "store_unavailable" } end
            return { ok = true, profile = codec.copy(f.durable) }
        end,
        status = function() return { canWrite = f.canWrite } end,
        save = function(_, profile)
            f.saves += 1
            if f.onSave then f.onSave() end
            if f.failSave then return { ok = false, reason = "store_unavailable" } end
            f.durable = codec.copy(profile)
            return { ok = true }
        end,
        release = function(_, profile)
            f.releases += 1
            if f.failRelease then return { ok = false, reason = "store_unavailable" } end
            f.durable = codec.copy(profile)
            return { ok = true }
        end,
        forget = function() return { ok = true } end,
    }
    f.service = PlayerData.new({ persistenceEnabled = enabled }, codec, {
        scheduler = scheduler,
        clock = { time = function() return f.time end, clock = function() return f.time end },
        warn = function() f.warnings += 1 end,
        persistence = if configured then persistence else nil,
    })
    return f
end

return function()
    local count = 0
    local function test(name, fn)
        local ok, err = pcall(fn)
        assert(ok, "Lifecycle " .. name .. ": " .. tostring(err))
        count += 1
    end
    test("explicit practice never touches persistent store", function()
        local f = fixture(false, true)
        local entry = f.service.open(7)
        assert(entry.mode == "Practice" and f.service.canWrite(7))
        entry.profile.coins = 25
        f.service.changed(7)
        f.service.save(7)
        f.service.close(7, f.time + 10)
        assert(f.saves == 0 and f.releases == 0 and f.durable.coins == 0)
    end)
    test("invalid configuration has no writable fallback", function()
        local f = fixture(true, false)
        local entry = f.service.open(7)
        assert(entry.mode == "Unavailable" and not f.service.canWrite(7))
    end)
    test("async load gates progression then exposes returning data", function()
        local f = fixture(true, true)
        f.durable.coins = 100
        local entry = f.service.open(7)
        assert(not f.service.canWrite(7) and entry.mode == "Loading")
        f.drain()
        assert(f.service.canWrite(7) and entry.profile.coins == 100)
    end)
    test("failed load cannot save or replace durable data", function()
        local f = fixture(true, true)
        f.durable.coins, f.failLoad = 250, true
        local entry = f.service.open(7)
        f.drain()
        assert(not f.service.canWrite(7) and entry.mode == "Unavailable")
        f.service.save(7)
        f.service.close(7, f.time + 10)
        assert(f.saves == 0 and f.releases == 0 and f.durable.coins == 250)
    end)
    test("autosave snapshots latest revision and close persists final progress", function()
        local f = fixture(true, true)
        local entry = f.service.open(7)
        f.drain()
        entry.profile.coins = 25
        f.service.changed(7)
        f.time += 61
        f.service.tick()
        f.drain()
        assert(f.durable.coins == 25 and entry.savedRevision == entry.revision)
        entry.profile.coins = 50
        f.service.changed(7)
        assert(f.service.close(7, f.time + 10))
        assert(f.durable.coins == 50 and not f.service.canWrite(7))
    end)
    test("failed save is visible and later save recovers", function()
        local f = fixture(true, true)
        local entry = f.service.open(7)
        f.drain()
        entry.profile.coins = 25
        f.service.changed(7)
        f.failSave = true
        f.service.save(7)
        assert(entry.savedRevision == 0 and string.find(entry.message, "not confirmed"))
        assert(f.durable.coins == 0)
        f.failSave = false
        f.service.save(7)
        assert(f.durable.coins == 25 and entry.message == "Progress saved")
    end)
    test("lease loss disables mutations", function()
        local f = fixture(true, true)
        local entry = f.service.open(7)
        f.drain()
        f.canWrite = false
        assert(not f.service.canWrite(7) and entry.mode == "Unavailable")
        f.service.save(7)
        assert(f.saves == 0)
    end)
    test("lease renewed by in-flight save resumes progression and final release", function()
        local f = fixture(true, true)
        local entry = f.service.open(7)
        f.drain()
        entry.profile.coins = 25
        f.service.changed(7)
        f.onSave = function()
            f.canWrite = false
            assert(not f.service.canWrite(7))
            f.canWrite = true -- Store confirms the renewed lease after the sample.
        end
        f.service.save(7)
        assert(f.service.canWrite(7) and entry.mode == "Saved progress")
        entry.profile.coins = 50
        f.service.changed(7)
        assert(f.service.close(7, f.time + 10))
        assert(f.releases == 1 and f.durable.coins == 50)
    end)
    test("disconnect during load joins worker and releases exactly once", function()
        local f = fixture(true, true)
        f.service.open(7)
        assert(f.service.close(7, f.time + 10))
        assert(f.releases == 1 and not f.service.canWrite(7))
    end)
    test("load completing after close deadline releases loaded data safely", function()
        local f = fixture(true, true)
        f.durable.coins = 75
        f.service.open(7)
        f.blockQueue = true
        assert(not f.service.close(7, f.time + 0.2))
        assert(not f.service.canWrite(7) and f.releases == 0)
        f.blockQueue = false
        f.drain()
        assert(f.releases == 1 and f.durable.coins == 75)
        assert(not f.service.canWrite(7))
    end)
    test("save completing after close deadline performs late final release", function()
        local f = fixture(true, true)
        local entry = f.service.open(7)
        f.drain()
        entry.profile.coins = 75
        f.service.changed(7)
        f.onSave = function()
            assert(not f.service.close(7, f.time + 0.2))
            assert(not f.service.canWrite(7))
        end
        f.service.save(7)
        assert(f.releases == 1 and f.durable.coins == 75)
        assert(not f.service.canWrite(7))
    end)
    test("uncertain final release freezes mutations and defers cleanup", function()
        local f = fixture(true, true)
        f.service.open(7)
        f.drain()
        f.failRelease = true
        assert(not f.service.close(7, f.time + 10))
        assert(not f.service.canWrite(7) and #f.delays == 1)
        assert(f.service.open(7) == nil)
        f.time += 186
        f.delays[1].fn()
        assert(f.service.open(7) ~= nil)
    end)
    test("shutdown closes every player with bounded shared deadline", function()
        local f = fixture(true, true)
        f.service.open(7)
        f.service.open(8)
        f.drain()
        f.service.shutdown()
        assert(f.releases == 2 and not f.service.canWrite(7) and not f.service.canWrite(8))
    end)
    return count
end
