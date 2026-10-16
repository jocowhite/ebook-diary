local InputContainer=require("ui/widget/container/inputcontainer")
local UIManager=require("ui/uimanager")
local Geom=require("ui/geometry")
local GestureRange=require("ui/gesturerange")
local Screen=require("device").screen
local BB=require("ffi/blitbuffer")
local TextWidget=require("ui/widget/textwidget")
local Font=require("ui/font")
local Slider=InputContainer:extend{fullscreen=true,covers_fullscreen=true}
function Slider:init()
    self.dimen=Geom:new{x=0,y=0,w=Screen:getWidth(),h=Screen:getHeight()}
    self.value=self.score or 75; self.missing=self.score==nil
    self.ges_events={SliderTap={GestureRange:new{ges="tap",range=self.dimen}},SliderPan={GestureRange:new{ges="pan",range=self.dimen}},SliderPanRelease={GestureRange:new{ges="pan_release",range=self.dimen}}}
    self.key_events={Close={{"Back"}}}
end
function Slider:onClose() UIManager:close(self); return true end
function Slider:change(value)
    self.value=math.max(0,math.min(100,math.floor(value+.5))); self.missing=false
    UIManager:setDirty(self,"ui")
end
function Slider:onSliderTap(_,gesture)
    local x,y=gesture.pos.x-self.dimen.x,gesture.pos.y-self.dimen.y
    for _,hit in ipairs(self.hits or {}) do
        if x>=hit.x and x<hit.x+hit.w and y>=hit.y and y<hit.y+hit.h then hit.callback(x); return true end
    end
    return true
end
function Slider:onSliderPan(_,gesture)
    local x,y=gesture.pos.x-self.dimen.x,gesture.pos.y-self.dimen.y
    local r=self.track
    if r and y>=r.y-20*self.scale and y<=r.y+40*self.scale then self:change((x-r.x)/r.w*100) end
    return true
end
function Slider:onSliderPanRelease(_,gesture) return self:onSliderPan(nil,gesture) end
function Slider:paintTo(bb,ox,oy)
    ox,oy=ox or 0,oy or 0; self.dimen.x,self.dimen.y=ox,oy
    local s=math.min(self.dimen.w/600,self.dimen.h/800); self.scale=s
    local w,h=self.dimen.w,self.dimen.h; local p=40*s
    self.hits={}
    local function rect(x,y,ww,hh,color) bb:paintRect(ox+math.floor(x),oy+math.floor(y),math.floor(ww),math.floor(hh),color) end
    local function text(value,x,y,ww,hh,size)
        local t=TextWidget:new{text=tostring(value),face=Font:getFace("cfont",math.floor(size*s)),max_width=math.floor(ww),padding=0}
        local d=t:getSize(); t:paintTo(bb,ox+math.floor(x+(ww-d.w)/2),oy+math.floor(y+(hh-d.h)/2));t:free()
    end
    local function button(label,x,y,ww,hh,callback)
        rect(x,y,ww,hh,BB.COLOR_BLACK);rect(x+1,y+1,ww-2,hh-2,BB.COLOR_WHITE);text(label,x,y,ww,hh,15)
        self.hits[#self.hits+1]={x=x,y=y,w=ww,h=hh,callback=callback}
    end
    rect(0,0,w,h,BB.COLOR_WHITE)
    text("Sleep Score · " .. self.date,p,90*s,w-2*p,44*s,23)
    text("0 = niedrig · 100 = hoch",p,145*s,w-2*p,30*s,14)
    text(self.missing and "—" or self.value,p,205*s,w-2*p,95*s,58)
    local tx,tw=p+60*s,w-2*p-120*s; local ty=350*s
    self.track={x=tx,y=ty,w=tw}
    rect(tx,ty,tw,8*s,BB.Color8(200));rect(tx,ty,tw*self.value/100,8*s,BB.COLOR_BLACK)
    rect(tx+tw*self.value/100-7*s,ty-9*s,14*s,26*s,BB.COLOR_BLACK)
    self.hits[#self.hits+1]={x=tx-5*s,y=ty-24*s,w=tw+10*s,h=56*s,callback=function(x) self:change((x-tx)/tw*100) end}
    button("−",p,ty-15*s,40*s,40*s,function() self:change(self.value-1) end)
    button("+",w-p-40*s,ty-15*s,40*s,40*s,function() self:change(self.value+1) end)
    text("0",tx-10*s,ty+30*s,20*s,25*s,12);text("100",tx+tw-20*s,ty+30*s,40*s,25*s,12)
    button("Keinen Wert eintragen",p,440*s,w-2*p,42*s,function() self.missing=true;UIManager:setDirty(self,"ui") end)
    button("Umbrel-Wert verwenden",p,492*s,w-2*p,42*s,function() if self.onAuto() then self:onClose() end end)
    button("Abbrechen",p,h-125*s,(w-2*p-12*s)/2,46*s,function() self:onClose() end)
    button("Speichern",w/2+6*s,h-125*s,(w-2*p-12*s)/2,46*s,function()
        local value=nil; if not self.missing then value=self.value end
        if self.onSave(value) then self:onClose() end
    end)
end
return Slider
