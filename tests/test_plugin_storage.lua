-- Run from repository root: texlua tests/test_plugin_storage.lua
-- Tests file handling with an injected codec; KOReader supplies rapidjson on-device.
local Storage = dofile("koreader/ebookdiary.koplugin/storage.lua")
local temp = os.tmpname()
os.remove(temp)
assert(os.execute('mkdir -p "' .. temp .. '"'))
local snapshots = {}
local codec = {
    encode = function(value)
        local copy = {}
        for date, entry in pairs(value) do
            copy[date] = {text=entry.text, habits={entry.habits[1],entry.habits[2],entry.habits[3]}}
        end
        snapshots[#snapshots + 1] = copy
        return tostring(#snapshots)
    end,
    decode = function(value) return assert(snapshots[tonumber(value)], "Invalid encoded data") end,
}
local function run()
    local store = Storage:new(temp, codec)
    assert(next(store:read("2026-10")) == nil)
    store:save("2026-10-16", {text="Schöner Tag\nZweite Zeile", habits={true,false,true}})
    local restarted = Storage:new(temp, codec)
    assert(restarted:read("2026-10")["2026-10-16"].text == "Schöner Tag\nZweite Zeile")
    restarted:save("2026-10-17", {text="Nächster Tag", habits={false,true,false}})
    assert(restarted:read("2026-10")["2026-10-16"].habits[1])
    assert(restarted:read("2026-10")["2026-10-17"].habits[2])
    assert(not pcall(function() store:read("../escape") end))
    assert(not pcall(function() store:save("2026-10-16", {text=string.rep("x",20001)}) end))
    local file = assert(io.open(temp .. "/2026-10.json", "wb")); file:write("broken"); file:close()
    assert(not pcall(function() store:read("2026-10") end))
    assert(not pcall(function() store:save("2026-10-18", {text="Test", habits={false,false,false}}) end))
    file=assert(io.open(temp .. "/2026-10.json", "rb")); assert(file:read("*a") == "broken"); file:close()
    assert(not pcall(function() Storage:new(temp .. "/missing",codec):save("2026-11-01",{text="x",habits={false,false,false}}) end))
end
local ok, err = pcall(run)
os.remove(temp .. "/2026-10.json"); os.remove(temp .. "/2026-10.json.pending")
os.execute('rmdir "' .. temp .. '"')
assert(ok, err)
print("PASS: empty month, persistence, multiple days, tracker values, path rejection, text limit, corrupt-file protection, write failure")
