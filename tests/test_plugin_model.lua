local Model=dofile("koreader/ebookdiary.koplugin/model.lua")
local Layout=dofile("koreader/ebookdiary.koplugin/layout.lua")
assert(Model.sleepScore("0")==0)
assert(Model.sleepScore(" 100 ")==100)
assert(Model.sleepScore("")==nil)
for _,bad in ipairs({"-1","101","NaN","1.5","1e2","0x64","abc"}) do
    assert(not pcall(Model.sleepScore,bad),bad)
end
local original={text="Alt",habits={true,false,true}}
local entry=Model.entry("2026-10-16",original)
assert(entry.trackers.outside and entry.trackers.food and not entry.trackers.reading)
Model.toggle(entry,"outside")
assert(not entry.trackers.outside and not entry.habits[1] and original.habits[1])
Model.toggle(entry,"custom_1"); assert(entry.trackers.custom_1)
entry.sleep_score=100; entry.sports={swimming=true,padel=true}; Model.validateEntry(entry)
entry.sports.unknown=true; assert(not pcall(Model.validateEntry,entry)); entry.sports.unknown=nil
local config=Model.defaultConfig()
local yoga=Model.addColumn(config,"  Yoga  ")
assert(#config.columns==5 and yoga.columns[6].label=="Yoga")
assert(not pcall(Model.addColumn,yoga,"Seventh"))
assert(not pcall(Model.addColumn,config,"  "))
config.columns[3].visible=false
assert(#Model.visibleColumns(config)==4)
local oldid=config.columns[4].id
config.columns[3],config.columns[4]=config.columns[4],config.columns[3]
assert(config.columns[3].id==oldid)
for _,size in ipairs({{600,800},{1072,1448},{800,600}}) do
    for count=0,6 do
        local l=Layout.build(size[1],size[2],count)
        assert(l.note_width>=size[1]*.3 and l.row_height>20)
        assert(l.bottom<=size[2]-50*l.scale)
        assert(l.pad+l.day_width+l.note_width+count*l.metric_width==size[1]-l.pad)
    end
end
assert(Model.monthDays("2028-02")==29 and Model.monthDays("2026-02")==28)
assert(Model.monthDays("2100-02")==28 and Model.monthDays("2000-02")==29)
assert(not pcall(Model.monthDays,"2026-13"))
print("PASS: manual scores, migration, isolated edits, sports validation, configurable columns, leap years, 0–6 column layout at three sizes")
