local fs = require("@lune/fs")
local luau = require("@lune/luau")

local compiled = 0
local function compileTree(path)
    for _, name in fs.readDir(path) do
        local file = path .. "/" .. name
        if fs.isDir(file) then
            compileTree(file)
        elseif string.match(name, "%.luau$") then
            luau.load(fs.readFile(file), { debugName = file })
            compiled += 1
        end
    end
end
compileTree("src")
compileTree("tests")
print("Syntax compilation passed:", compiled, "Luau files")

local total = 0
for name, suite in { persistence = require("./persistence"), gameplay = require("./gameplay"), lifecycle = require("./lifecycle"), pickup = require("./pickup"), world = require("./world"), adventure = require("./adventure"), adventure_layout = require("./adventure_layout"), floors = require("./floors"), grass = require("./grass"), powerups = require("./powerups"), blaster = require("./blaster"), ocean = require("./ocean"), shores = require("./shores"), blaster_input = require("./blaster_input") } do
    local passed = suite()
    print(name .. ":", passed, "cases passed")
    total += passed
end
print("Behavior tests passed:", total)
