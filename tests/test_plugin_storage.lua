-- Run from repository root: texlua tests/test_plugin_storage.lua
-- Tests file handling with an injected codec; KOReader supplies rapidjson on-device.
local Storage = dofile("koreader/ebookdiary.koplugin/storage.lua")
local Model = dofile("koreader/ebookdiary.koplugin/model.lua")
local temp = os.tmpname()
os.remove(temp)
assert(os.execute('mkdir -p "' .. temp .. '"'))
local snapshots = {}
local codec = {
    encode = function(value)
        local copy = Model.copy(value)
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
    local entry = Model.entry("2026-10-16", restarted:read("2026-10")["2026-10-16"])
    assert(entry.trackers.outside and not entry.trackers.reading and entry.trackers.food)
    entry.sleep_score=0; entry.sports={swimming=true,cycling=true,running=true,football=true,padel=true}
    entry.trackers.custom_1=true
    restarted:save("2026-10-16",entry)
    local roundtrip=Storage:new(temp,codec):read("2026-10")["2026-10-16"]
    assert(roundtrip.sleep_score==0 and roundtrip.sports.padel and roundtrip.sports.swimming and roundtrip.trackers.custom_1)
    roundtrip.sleep_score=nil; restarted:save("2026-10-16",roundtrip)
    assert(restarted:read("2026-10")["2026-10-16"].sleep_score==nil)
    local before=Model.copy(restarted:read("2026-10"))
    entry.sleep_score=101
    assert(not pcall(function() restarted:save("2026-10-16",entry) end))
    assert(restarted:read("2026-10")["2026-10-16"].sleep_score==before["2026-10-16"].sleep_score)
    assert(not pcall(function() restarted:save("2026-02-30",roundtrip) end))
    local config=restarted:readConfig()
    config=Model.addColumn(config,"Yoga")
    restarted:saveConfig(config)
    assert(Storage:new(temp,codec):readConfig().columns[6].label=="Yoga")
    assert(not pcall(function() Model.addColumn(config,"Siebte") end))
    config.columns[3].visible=false
    restarted:saveConfig(config)
    config=Model.addColumn(config,"Meditation")
    assert(config.columns[7].id=="custom_2")
    restarted:saveConfig(config)
    table.remove(config.columns,6)
    restarted:saveConfig(config)
    local again=restarted:readConfig()
    again=Model.addColumn(again,"Neuer Tracker")
    assert(again.columns[#again.columns].id=="custom_3")
    assert(restarted:read("2026-10")["2026-10-16"].trackers.custom_1)
    local file = assert(io.open(temp .. "/2026-10.json", "wb")); file:write("broken"); file:close()
    assert(not pcall(function() store:read("2026-10") end))
    assert(not pcall(function() store:save("2026-10-18", {text="Test", habits={false,false,false}}) end))
    file=assert(io.open(temp .. "/2026-10.json", "rb")); assert(file:read("*a") == "broken"); file:close()
    assert(not pcall(function() Storage:new(temp .. "/missing",codec):save("2026-11-01",{text="x",habits={false,false,false}}) end))
end
local ok, err = pcall(run)
os.remove(temp .. "/columns.json"); os.remove(temp .. "/columns.json.pending"); os.remove(temp .. "/2026-10.json"); os.remove(temp .. "/2026-10.json.pending")
os.execute('rmdir "' .. temp .. '"')
assert(ok, err)
print("PASS: empty month, persistence, multiple days, tracker values, path rejection, text limit, corrupt-file protection, write failure, legacy migration, sleep and sports roundtrip, column persistence and stable IDs")
