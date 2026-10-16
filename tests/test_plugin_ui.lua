-- KOReader API doubles exercise the real plugin controller and drawing code.
-- This does not replace testing KOReader's widgets or the Kindle keyboard.
local Model=dofile("koreader/ebookdiary.koplugin/model.lua")
local function class(base)
    local c={}; c.__index=c; setmetatable(c,{__index=base})
    function c:extend(values)
        local child=class(self); for k,v in pairs(values or {}) do child[k]=v end; return child
    end
    function c:new(values)
        local obj=setmetatable(values or {},self)
        if obj.init then obj:init() end
        return obj
    end
    function c:free() end
    return c
end
local Base=class()
local UI={shown={},dirty=0}
function UI:show(widget) self.shown[#self.shown+1]=widget end
function UI:close(widget)
    if widget.onCloseWidget then widget:onCloseWidget() end
    for i=#self.shown,1,-1 do if self.shown[i]==widget then table.remove(self.shown,i); break end end
end
function UI:setDirty() self.dirty=self.dirty+1 end
local function last() return UI.shown[#UI.shown] end
local function escape(s) return tostring(s):gsub("&","&amp;"):gsub("<","&lt;"):gsub(">","&gt;"):gsub('"',"&quot;") end
local drawing={}
local Text=class(Base)
function Text:getSize()
    local chars=0; for _ in self.text:gmatch("[^\128-\191]") do chars=chars+1 end
    return {w=math.min(self.max_width,chars*self.face.size*.52),h=self.face.size*1.3}
end
function Text:paintTo(target,x,y)
    if target.offscreen then target.label=self.text;return end
    drawing[#drawing+1]=string.format('<text x="%s" y="%s" font-family="serif" font-size="%s" fill="rgb(%s,%s,%s)">%s</text>',x,y+self.face.size,self.face.size,self.fgcolor,self.fgcolor,self.fgcolor,escape(self.text))
end
local Image=class(Base)
function Image:paintTo(_,x,y)
    if self.image then
        drawing[#drawing+1]=string.format('<text transform="translate(%s,%s) rotate(-90)" font-size="11">%s</text>',x+10,y+60,escape(self.image.label));return
    end
    local f=assert(io.open(self.file)); local svg=f:read("*a"); f:close()
    svg=svg:gsub('width="32" height="32"',string.format('x="%s" y="%s" width="%s" height="%s"',x,y,self.width,self.height))
    drawing[#drawing+1]=svg
end
local Input=class(Base)
function Input:getInputText() return self.input end
function Input:onShowKeyboard() self.keyboard_shown=true end
local bb={}
function bb:paintRect(x,y,w,h,color)
    assert(w>=0 and h>=0)
    drawing[#drawing+1]=string.format('<rect x="%s" y="%s" width="%s" height="%s" fill="rgb(%s,%s,%s)"/>',x,y,w,h,color,color,color)
end
local modules={
    ["ui/widget/container/widgetcontainer"]=Base,["ui/widget/container/inputcontainer"]=Base,
    ["ui/uimanager"]=UI,["ui/widget/menu"]=Base,["ui/widget/inputdialog"]=Input,
    ["ui/widget/infomessage"]=Base,["ui/widget/confirmbox"]=Base,
    ["ui/geometry"]=Base,["ui/gesturerange"]=Base,
    ["ui/widget/textwidget"]=Text,["ui/widget/imagewidget"]=Image,
    ["ui/font"]={getFace=function(_,_,size) return {size=size} end},
    ["ffi/blitbuffer"]={COLOR_WHITE=255,COLOR_BLACK=0,Color8=function(v) return v end,
        new=function() return {offscreen=true,fill=function() end,free=function() end,rotatedCopy=function(self) return {label=self.label} end} end},
    ["device"]={screen={getWidth=function() return 600 end,getHeight=function() return 800 end}},
    ["datastorage"]={},["libs/libkoreader-lfs"]={},["rapidjson"]={},
}
for name,value in pairs(modules) do local v=value; package.preload[name]=function() return v end end
local Diary=dofile("koreader/ebookdiary.koplugin/main.lua")
local data,config={},Model.defaultConfig()
local fail=false
local storage={
    read=function() return Model.copy(data) end,
    readConfig=function() return Model.copy(config) end,
    readMetrics=function() return {days={}} end,
    save=function(_,date,entry)
        if fail then error("Disk full") end
        Model.validateEntry(entry); data[date]=Model.copy(entry)
    end,
    saveConfig=function(_,value) Model.validateConfig(value); config=Model.copy(value) end,
}
local registered=false
local owner=Diary:new{storage=storage,ui={menu={registerToMainMenu=function() registered=true end}}}
assert(registered)
owner.month="2026-10"; owner.half=2; owner:refresh()
local function paint()
    drawing={}; owner.view:paintTo(bb,0,0)
end
paint(); assert(#owner.view.hits==8+16*6) -- close + navigation + half selectors, cells, settings
local function tapCell(day,column)
    local l=dofile("koreader/ebookdiary.koplugin/layout.lua").build(600,800,#Model.visibleColumns(config))
    local x=l.pad+l.day_width+(column==0 and 10 or l.note_width+(column-.5)*l.metric_width)
    owner.view:onDiaryTap(nil,{pos={x=x,y=l.top+(day-16+.5)*l.row_height}})
end
-- Editing text is reached by tapping the actual row hit region.
tapCell(16,0)
local editor=last(); assert(editor.allow_newline and editor.keyboard_shown)
editor.input="Mein erster Tabellentag"; editor.buttons[1][2].callback()
assert(data["2026-10-16"].text=="Mein erster Tabellentag")
-- Slider uses bounded steps, supports zero and preserves explicit missing values.
paint(); tapCell(16,2); local score=last(); score:paintTo(bb,0,0)
score:change(101); assert(score.value==100)
score:change(-1); assert(score.value==0)
assert(score.onSave(0));UI:close(score)
assert(data["2026-10-16"].sleep_score==0 and data["2026-10-16"].sleep_manual)
paint(); tapCell(16,3); assert(data["2026-10-16"].trackers.outside)
-- Selecting each sport preserves the others and the text/trackers/score.
paint(); tapCell(16,1)
for index=1,5 do last().item_table[index].callback() end
last().item_table[8].callback()
for _,sport in ipairs(Model.sports) do assert(data["2026-10-16"].sports[sport.id]) end
assert(data["2026-10-16"].sleep_score==0 and data["2026-10-16"].text=="Mein erster Tabellentag")
paint()
local icon_count=0; for _,draw in ipairs(drawing) do if draw:match('<svg') then icon_count=icon_count+1 end end
assert(icon_count==5)
-- Spalten: create, rename, reorder, hide and remove, without touching entry values.
owner:showColumns(); last().item_table[6].callback()
local name=last(); name.input="Yoga"; name.buttons[1][2].callback()
assert(config.columns[6].label=="Yoga")
owner:columnOptions(6); last().item_table[2].callback()
name=last(); name.input="Bewegung"; name.buttons[1][2].callback()
assert(config.columns[6].label=="Bewegung")
owner:columnOptions(6); last().item_table[3].callback()
assert(config.columns[5].label=="Bewegung")
owner:columnOptions(5); last().item_table[1].callback(); assert(not config.columns[5].visible)
owner:columnOptions(5); last().item_table[5].callback(); last().ok_callback()
assert(#config.columns==5 and data["2026-10-16"].trackers.outside)
-- Failed saves keep the text dialog available and do not mutate stored entries.
owner:editText("2026-10-16"); editor=last(); editor.input="Nicht gespeichert"; fail=true
editor.buttons[1][2].callback(); assert(data["2026-10-16"].text=="Mein erster Tabellentag")
assert(last().text:match("Nicht gespeichert")); fail=false
-- Render an explicitly synthetic month for visual review of the real draw commands.
for day=16,31 do
 local date=string.format("2026-10-%02d",day)
 local e=Model.entry(date,data[date]); e.sleep_score=({0,48,68,87,100})[(day-16)%5+1]
 e.trackers.outside=day%2==0; e.trackers.reading=day%3==0; e.trackers.food=day%4==0
 if day==17 then e.sports={swimming=true} elseif day==18 then e.sports={cycling=true} elseif day==19 then e.sports={running=true} elseif day==20 then e.sports={football=true} elseif day==21 then e.sports={padel=true} end
 data[date]=e
end
owner:refresh(); paint()
local f=assert(io.open("/tmp/ebook-diary-table-test.svg","wb"))
f:write('<svg xmlns="http://www.w3.org/2000/svg" width="600" height="800">',table.concat(drawing,"\n"),'</svg>'); f:close()
owner.view:onClose(); assert(owner.view==nil)
owner:moveMonth(1); assert(owner.month=="2026-11" and owner.half==1)
owner:moveMonth(-1); assert(owner.month=="2026-10")
print("PASS: row taps, text save, score validation and zero, all five sports, tracker, column actions, save failure, close/reopen and month navigation; synthetic render saved in /tmp")
