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
    text(months[tonumber(month)] .. " " .. year,pad,34*s,l.w-2*pad-188*s,42*s,25,false)
    local nav = l.w-pad-183*s
    button("‹",nav,35*s,32*s,34*s,function() self.owner:moveMonth(-1) end)
    button("Heute",nav+37*s,35*s,58*s,34*s,function() self.owner:today() end)
    button("›",nav+100*s,35*s,32*s,34*s,function() self.owner:moveMonth(1) end)
    button("×",l.w-pad-38*s,35*s,38*s,34*s,function() self:onClose() end)
    rect(pad,80*s,l.w-2*pad,2*s,black)
    local count = Model.monthDays(self.month)
    local note_x = pad+l.day_width
    local metric_x = note_x+l.note_width
    text("TAG",pad,126*s,l.day_width,28*s,9,true)
    text("WAS BLEIBT VON HEUTE?",note_x,126*s,l.note_width,28*s,9,false)
    for index, col in ipairs(cols) do
        local x = metric_x+(index-1)*l.metric_width
        local label = TextWidget:new{text=col.label,face=Font:getFace("cfont",math.floor(11*s)),
            max_width=math.floor(70*s),padding=0}
        local dim=label:getSize()
        local buffer=Blitbuffer.new(math.max(1,dim.w),math.max(1,dim.h),Blitbuffer.TYPE_BB8)
        buffer:fill(white); label:paintTo(buffer,0,0); label:free()
        local rotated=buffer:rotatedCopy(270); buffer:free()
        local image=ImageWidget:new{image=rotated,is_icon=true,image_disposable=true}
        self.children[#self.children+1]=image
        image:paintTo(bb,ox+math.floor(x+(l.metric_width-dim.h)/2),oy+math.floor(82*s+(70*s-dim.w)/2))
    end
    rect(pad,l.top-1,l.w-2*pad,1,black)
    local start = self.half==1 and 1 or 16
    local last = self.half==1 and 15 or count
    for day=start,last do
        local date = string.format("%s-%02d",self.month,day)
        local entry = Model.withMetrics(date,self.entries[date],self.metrics and self.metrics.days[date])
        local y = l.top+(day-start)*l.row_height
        local h = l.row_height
        local is_today = date==os.date("%Y-%m-%d")
        if is_today then rect(pad,y,l.day_width,h,black) end
        text(day,pad,y+2*s,l.day_width,h*.55,13,true,is_today and white or black)
        local weekday = tonumber(os.date("%w",os.time{year=tonumber(year),month=tonumber(month),day=day,hour=12}))+1
        text(days[weekday],pad,y+h*.52,l.day_width,h*.4,9,true,is_today and white or black)
        text(entry.text:match("[^\r\n]+") or "Eintrag hinzufügen",note_x+4*s,y,l.note_width-8*s,h,13,false,
            entry.text=="" and Blitbuffer.Color8(125) or black)
        self:hit(note_x,y,l.note_width,h,function() self.owner:editText(date) end)
        rect(note_x,y,1,h,gray)
        for index,col in ipairs(cols) do
            local x = metric_x+(index-1)*l.metric_width
            local side=math.floor(math.min(32*s,l.metric_width-6*s,h-4*s))
            local tile_x,tile_y=x+(l.metric_width-side)/2,y+(h-side)/2
            if col.kind=="habit" then
                rect(tile_x,tile_y,side,side,entry.trackers[col.id] and black or gray)
                if not entry.trackers[col.id] then rect(tile_x+1,tile_y+1,side-2,side-2,white) end
            elseif col.kind=="sleep" then
                local score = entry.sleep_score
                if score ~= nil then
                    local shade = 255-math.floor(score*2.35)
                    rect(tile_x,tile_y,side,side,Blitbuffer.Color8(shade))
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
    button("Umbrel",pad+98*s,footer,72*s,34*s,function() self.owner:showSync() end)
    button("1–15",l.w-pad-125*s,footer,58*s,34*s,function() self.owner.half=1; self.owner:refresh() end,self.half==1)
    button("16–" .. count,l.w-pad-61*s,footer,61*s,34*s,function() self.owner.half=2; self.owner:refresh() end,self.half==2)
end
return View
