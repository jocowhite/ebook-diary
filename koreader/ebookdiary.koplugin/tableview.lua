local InputContainer = require("ui/widget/container/inputcontainer")
local UIManager = require("ui/uimanager")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local Screen = require("device").screen
local Blitbuffer = require("ffi/blitbuffer")
local TextWidget = require("ui/widget/textwidget")
local ImageWidget = require("ui/widget/imagewidget")
local Font = require("ui/font")
local path = debug.getinfo(1, "S").source:sub(2):match("(.*/)")
local Model = dofile(path .. "model.lua")
local Layout = dofile(path .. "layout.lua")
local View = InputContainer:extend{ fullscreen = true, covers_fullscreen = true }
local months = {"Januar","Februar","März","April","Mai","Juni","Juli","August","September","Oktober","November","Dezember"}
local days = {"So","Mo","Di","Mi","Do","Fr","Sa"}

function View:init()
    self.dimen = Geom:new{x=0,y=0,w=Screen:getWidth(),h=Screen:getHeight()}
    self.ges_events = { DiaryTap = {GestureRange:new{ges="tap",range=self.dimen}} }
    self.key_events = { Close = {{"Back"}} }
    self.children = {}
end

function View:freePaintWidgets()
    for _, child in ipairs(self.children) do child:free() end
    self.children = {}
end
function View:onCloseWidget()
    self:freePaintWidgets()
    if self.owner.view==self then self.owner.view=nil end
end
function View:onScreenResize()
    self.dimen.w, self.dimen.h = Screen:getWidth(), Screen:getHeight()
    UIManager:setDirty(self,"full")
    return true
end
function View:onClose() self.owner.view=nil; UIManager:close(self); return true end
function View:onDiaryTap(_, gesture)
    local px, py = gesture.pos.x-self.dimen.x, gesture.pos.y-self.dimen.y
    for _, box in ipairs(self.hits or {}) do
        if px >= box.x and px < box.x+box.w and py >= box.y and py < box.y+box.h then
            box.callback(); return true
        end
    end
    return true
end
function View:hit(x,y,w,h,callback)
    self.hits[#self.hits+1] = {x=x,y=y,w=w,h=h,callback=callback}
end
function View:paintTo(bb, ox, oy)
    ox, oy = ox or 0, oy or 0
    self.dimen.x, self.dimen.y = ox, oy
    self:freePaintWidgets()
    self.hits = {}
    local cols = Model.visibleColumns(self.config)
    local l = Layout.build(self.dimen.w,self.dimen.h,#cols)
    local s, pad = l.scale, l.pad
    local black, white = Blitbuffer.COLOR_BLACK, Blitbuffer.COLOR_WHITE
    local gray = Blitbuffer.Color8(190)
    local function rect(x,y,w,h,color) bb:paintRect(ox+math.floor(x),oy+math.floor(y),math.floor(w),math.floor(h),color) end
    local function text(value,x,y,w,h,size,center,color,bold)
        local widget = TextWidget:new{text=tostring(value),face=Font:getFace("cfont",math.floor(size*s)),
            max_width=math.max(1,math.floor(w-6*s)),padding=0,fgcolor=color or black,bold=bold or false}
        self.children[#self.children+1] = widget
        local dim = widget:getSize()
        widget:paintTo(bb,ox+math.floor(x+(center and (w-dim.w)/2 or 4*s)),oy+math.floor(y+(h-dim.h)/2))
    end
    local function button(label,x,y,w,h,callback,active)
        rect(x,y,w,h,black)
        if not active then rect(x+1,y+1,w-2,h-2,white) end
        text(label,x,y,w,h,13,true,active and white or black)
        self:hit(x,y,w,h,callback)
    end
    rect(0,0,l.w,l.h,white)
    text("EIN TAG. EINE ZEILE.",pad,12*s,l.w-2*pad,18*s,10,false)
    local year, month = self.month:match("(%d+)%-(%d+)")
    text(months[tonumber(month)] .. " " .. year,pad,34*s,l.w-2*pad-46*s,42*s,27,false)
    button("×",l.w-pad-38*s,35*s,38*s,36*s,function() self:onClose() end)
    rect(pad,84*s,l.w-2*pad,2*s,black)
    button("‹",pad,96*s,36*s,34*s,function() self.owner:moveMonth(-1) end)
    button("Heute",pad+42*s,96*s,65*s,34*s,function() self.owner:today() end)
    button("›",pad+113*s,96*s,36*s,34*s,function() self.owner:moveMonth(1) end)
    local count = Model.monthDays(self.month)
    local end_label = "16–" .. count
    button("1–15",l.w-pad-125*s,96*s,58*s,34*s,function() self.owner.half=1; self.owner:refresh() end,self.half==1)
    button(end_label,l.w-pad-61*s,96*s,61*s,34*s,function() self.owner.half=2; self.owner:refresh() end,self.half==2)
    local note_x = pad+l.day_width
    local metric_x = note_x+l.note_width
    text("TAG",pad,140*s,l.day_width,28*s,9,true)
    text("WAS BLEIBT VON HEUTE?",note_x,140*s,l.note_width,28*s,9,false)
    for index, col in ipairs(cols) do
        local x = metric_x+(index-1)*l.metric_width
        local a,b = col.label:match("^(%S+)%s+(.+)$")
        if a then
            text(a,x,140*s,l.metric_width,13*s,9,true)
            text(b,x,153*s,l.metric_width,13*s,9,true)
        else text(col.label,x,140*s,l.metric_width,26*s,9,true) end
    end
    rect(pad,l.top-1,l.w-2*pad,1,black)
    local start = self.half==1 and 1 or 16
    local last = self.half==1 and 15 or count
    for day=start,last do
        local date = string.format("%s-%02d",self.month,day)
        local entry = Model.entry(date,self.entries[date])
        local y = l.top+(day-start)*l.row_height
        local h = l.row_height
        local is_today = date==os.date("%Y-%m-%d")
        if is_today then rect(pad,y,l.day_width,h,black) end
        text(day,pad,y+2*s,l.day_width,h*.55,13,true,is_today and white or black)
        local weekday = tonumber(os.date("%w",os.time{year=tonumber(year),month=tonumber(month),day=day,hour=12}))+1
        text(days[weekday],pad,y+h*.52,l.day_width,h*.4,9,true,is_today and white or black)
        text(entry.text:match("[^\r\n]+") or "Eintrag hinzufügen",note_x+4*s,y,l.note_width-8*s,h,15,false,
            entry.text=="" and Blitbuffer.Color8(125) or black)
        self:hit(note_x,y,l.note_width,h,function() self.owner:editText(date) end)
        rect(note_x,y,1,h,gray)
        for index,col in ipairs(cols) do
            local x = metric_x+(index-1)*l.metric_width
            if col.kind=="habit" and entry.trackers[col.id] then
                rect(x+3*s,y+3*s,l.metric_width-6*s,h-6*s,black)
            elseif col.kind=="sleep" then
                local score = entry.sleep_score
                if score ~= nil then
                    local shade = 255-math.floor(score*2.35)
                    rect(x+3*s,y+3*s,l.metric_width-6*s,h-6*s,Blitbuffer.Color8(shade))
                    text(score,x,y,l.metric_width,h,14,true,shade<130 and white or black,true)
                else text("—",x,y,l.metric_width,h,14,true) end
            elseif col.kind=="sport" then
                local selected = {}
                for _,sport in ipairs(Model.sports) do if entry.sports[sport.id] then selected[#selected+1]=sport.id end end
                if #selected==0 then text("—",x,y,l.metric_width,h,14,true) else
                    local columns = #selected==1 and 1 or (#selected>4 and 3 or 2)
                    local rows = math.ceil(#selected/columns)
                    local size = math.floor(math.min(23*s,(l.metric_width-6*s)/columns,(h-6*s)/rows))
                    for i,id in ipairs(selected) do
                        local icon = ImageWidget:new{file=path .. "icons/" .. id .. ".svg",width=size,height=size,is_icon=true}
                        self.children[#self.children+1]=icon
                        local ix = x+(l.metric_width-columns*size)/2+((i-1)%columns)*size
                        local iy = y+(h-rows*size)/2+math.floor((i-1)/columns)*size
                        icon:paintTo(bb,ox+math.floor(ix),oy+math.floor(iy))
                    end
                end
            end
            rect(x,y,1,h,gray)
            local column = col
            self:hit(x,y,l.metric_width,h,function() self.owner:editCell(date,column) end)
        end
        rect(pad,y+h-1,l.w-2*pad,1,gray)
    end
    local footer = l.h-52*s
    rect(pad,footer-12*s,l.w-2*pad,1,black)
    button("Spalten",pad,footer,90*s,34*s,function() self.owner:showColumns() end)
    text("Zeile: Text · Kachel: bearbeiten",pad+100*s,footer,l.w-2*pad-100*s,34*s,10,false)
end
return View
