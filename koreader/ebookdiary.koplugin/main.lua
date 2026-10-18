local WidgetContainer = require("ui/widget/container/widgetcontainer")
local UIManager = require("ui/uimanager")
local Menu = require("ui/widget/menu")
local InputDialog = require("ui/widget/inputdialog")
local InfoMessage = require("ui/widget/infomessage")
local ConfirmBox = require("ui/widget/confirmbox")
local DataStorage = require("datastorage")
local lfs = require("libs/libkoreader-lfs")
local json = require("rapidjson")
local path = debug.getinfo(1, "S").source:sub(2):match("(.*/)")
local Storage = dofile(path .. "storage.lua")
local Model = dofile(path .. "model.lua")
local TableView = dofile(path .. "tableview.lua")
local SleepDialog = dofile(path .. "sleepdialog.lua")
local Sync = dofile(path .. "sync.lua")
local Diary = WidgetContainer:extend{ name="ebookdiary", is_doc_only=false }

function Diary:init() self.ui.menu:registerToMainMenu(self) end
function Diary:addToMainMenu(items)
    items.ebookdiary = {text="Ein Tag. Eine Zeile.",sorting_hint="more_tools",callback=function() self:today() end}
end
function Diary:notify(text) UIManager:show(InfoMessage:new{text=text}) end
function Diary:getStorage()
    if not self.storage then
        local directory = DataStorage:getDataDir() .. "/ebook-diary"
        if not lfs.attributes(directory,"mode") then assert(lfs.mkdir(directory),"Datenordner konnte nicht erstellt werden") end
        self.storage = Storage:new(directory,json)
    end
    return self.storage
end
function Diary:today()
    self.month=os.date("%Y-%m")
    self.half=tonumber(os.date("%d"))<=15 and 1 or 2
    self:refresh()
end
function Diary:moveMonth(offset)
    local year,month=self.month:match("(%d+)%-(%d+)")
    month=tonumber(month)+offset; year=tonumber(year)
    if month==0 then year=year-1; month=12 elseif month==13 then year=year+1; month=1 end
    if year<1900 or year>9998 then return end
    self.month=string.format("%04d-%02d",year,month); self.half=1; self:refresh()
end
function Diary:refresh()
    local ok,err=pcall(function()
        self.entries=self:getStorage():read(self.month)
        self.config=self:getStorage():readConfig()
        self.metrics=self:getStorage():readMetrics(self.month)
        self.conflicts=self:getStorage():readFile("conflicts-" .. self.month .. ".json",{})
        self.journal_status=self:getStorage():readFile("journal-status-" .. self.month .. ".json",{})
    end)
    if not ok then self:notify("Tagebuch konnte nicht geladen werden:\n" .. tostring(err)); return end
    if self.view then
        self.view.month=self.month; self.view.half=self.half
        self.view.entries=self.entries; self.view.config=self.config; self.view.metrics=self.metrics
        UIManager:setDirty(self.view,"full")
    else
        self.view=TableView:new{owner=self,month=self.month,half=self.half,entries=self.entries,config=self.config,metrics=self.metrics}
        UIManager:show(self.view)
    end
end
function Diary:entry(date) return Model.entry(date,self.entries[date]) end
function Diary:save(date,entry)
    local ok,err=pcall(function() self:getStorage():save(date,entry) end)
    if not ok then self:notify("Nicht gespeichert:\n" .. tostring(err)); return false end
    self:refresh(); return true
end
function Diary:saveConfig(config)
    local ok,err=pcall(function() self:getStorage():saveConfig(config) end)
    if not ok then self:notify("Spalten nicht geändert:\n" .. tostring(err)); return false end
    self:refresh(); return true
end
function Diary:input(title,initial,save,options)
    options=options or {}
    local dialog
    dialog=InputDialog:new{
        title=title,input=initial,input_type=options.number and "number" or nil,
        description=options.description,
        text_type=options.password and "password" or nil,
        allow_newline=options.multiline or false,fullscreen=options.multiline or false,
        add_nav_bar=options.multiline or false,
        buttons={{
            {text="Abbrechen",callback=function() UIManager:close(dialog) end},
            {text="Speichern",is_enter_default=not options.multiline,callback=function()
                if save(dialog:getInputText()) then UIManager:close(dialog) end
            end},
        }},
    }
    UIManager:show(dialog); dialog:onShowKeyboard()
end
function Diary:editText(date)
    local entry=self:entry(date)
    self:input("Tagebuch · " .. date,entry.text,function(value)
        entry.text=value; return self:save(date,entry)
    end,{multiline=true,description="Änderungen ausdrücklich speichern. Abbrechen verwirft sie."})
end
function Diary:editCell(date,column)
    if column.kind=="habit" then
        local entry=self:entry(date); Model.toggle(entry,column.id); self:save(date,entry)
    elseif column.kind=="sleep" then
        local raw=self:entry(date)
        local effective=Model.withMetrics(date,raw,self.metrics.days[date])
        UIManager:show(SleepDialog:new{date=date,score=effective.sleep_score,
            onSave=function(value)
                raw.sleep_score=value;raw.sleep_manual=true;return self:save(date,raw)
            end,
            onAuto=function() raw.sleep_manual=false;raw.sleep_score=nil;return self:save(date,raw) end,
        })
    elseif column.kind=="sport" then self:showSports(date) end
end
function Diary:showSports(date)
    local entry=Model.withMetrics(date,self:entry(date),self.metrics.days[date])
    local items,menu={},nil
    for _,sport in ipairs(Model.sports) do
        local id,label=sport.id,sport.label
        items[#items+1]={text=(entry.sports[id] and "☑ " or "☐ ") .. label,callback=function()
            local updated=self:entry(date); updated.sports=Model.copy(entry.sports); updated.sports[id]=not updated.sports[id]; updated.sports_manual=true
            if self:save(date,updated) then UIManager:close(menu); self:showSports(date) end
        end}
    end
    items[#items+1]={text="Alle Sportarten leeren",callback=function()
        local updated=self:entry(date); updated.sports={}; updated.sports_manual=true
        if self:save(date,updated) then UIManager:close(menu); self:showSports(date) end
    end}
    items[#items+1]={text="Umbrel-Sportwerte verwenden",callback=function()
        local updated=self:entry(date);updated.sports_manual=false;updated.sports={}
        if self:save(date,updated) then UIManager:close(menu);self:showSports(date) end
    end}
    items[#items+1]={text="Fertig",callback=function() UIManager:close(menu) end}
    menu=Menu:new{title="Sport · " .. date,item_table=items}
    UIManager:show(menu)
end
function Diary:showColumns()
    local items,menu={},nil
    for index,column in ipairs(self.config.columns) do
        local i,col=index,column
        items[#items+1]={text=(col.visible and "☑ " or "☐ ") .. col.label,callback=function()
            UIManager:close(menu); self:columnOptions(i)
        end}
    end
    items[#items+1]={text="+ Eigene Tracker-Spalte",callback=function()
        UIManager:close(menu)
        self:input("Neue Tracker-Spalte","",function(label)
            local ok,config=pcall(Model.addColumn,self.config,label)
            if not ok then self:notify(tostring(config)); return false end
            return self:saveConfig(config)
        end,{description="Name mit höchstens 60 Bytes. Bis zu sechs Kachelspalten gleichzeitig sichtbar."})
    end}
    menu=Menu:new{title="Spalten · auswählen zum Bearbeiten",item_table=items}
    UIManager:show(menu)
end
function Diary:columnOptions(index)
    local col=self.config.columns[index]
    local menu,items=nil,{}
    local function update(change)
        local config=Model.copy(self.config); change(config)
        if self:saveConfig(config) then UIManager:close(menu); self:showColumns() end
    end
    items[#items+1]={text=col.visible and "Spalte ausblenden" or "Spalte einblenden",callback=function()
        update(function(config) config.columns[index].visible=not col.visible end)
    end}
    items[#items+1]={text="Umbenennen",callback=function()
        UIManager:close(menu)
        self:input("Spaltenname",col.label,function(label)
            local config=Model.copy(self.config)
            config.columns[index].label=label:match("^%s*(.-)%s*$")
            return self:saveConfig(config)
        end)
    end}
    if index>1 then items[#items+1]={text="Nach links verschieben",callback=function()
        update(function(config) config.columns[index],config.columns[index-1]=config.columns[index-1],config.columns[index] end)
    end} end
    if index<#self.config.columns then items[#items+1]={text="Nach rechts verschieben",callback=function()
        update(function(config) config.columns[index],config.columns[index+1]=config.columns[index+1],config.columns[index] end)
    end} end
    if col.id:match("^custom_") then items[#items+1]={text="Eigene Spalte entfernen",callback=function()
        UIManager:show(ConfirmBox:new{text="Spalte „" .. col.label .. "“ entfernen? Vorhandene Tageswerte bleiben in den Dateien; zum späteren Wiedereinblenden bitte stattdessen ausblenden.",ok_callback=function()
            update(function(config) table.remove(config.columns,index) end)
        end})
    end} end
    items[#items+1]={text="Zur Spaltenliste",callback=function() UIManager:close(menu); self:showColumns() end}
    menu=Menu:new{title=col.label,item_table=items}
    UIManager:show(menu)
end
function Diary:showSync()
    local items,menu={},nil
    items[#items+1]={text="Jetzt abgleichen (" .. self.month .. ")",callback=function()
        UIManager:close(menu)
        local NetworkMgr=require("ui/network/manager")
        NetworkMgr:runWhenConnected(function()
            local base=self.config.sync_url or Sync.default_url
            local ok,err=pcall(Sync.all,self:getStorage(),base,self.month,json,self.config.sync_token)
            if ok then
                self:refresh()
                local message="Tagebuch mit Umbrel abgeglichen."
                if err.conflicts>0 then message=message .. "\n" .. err.conflicts .. " Konflikt(e): unter Umbrel → Konflikte entscheiden." end
                if err.metrics_error then message=message .. "\nSchlaf-/Sportabruf fehlgeschlagen; alte Messwerte bleiben erhalten." end
                self:notify(message)
            else self:notify("Kein Abgleich. Letzte Werte bleiben erhalten.\n" .. tostring(err)) end
        end)
    end}
    items[#items+1]={text="Server: " .. (self.config.sync_url or Sync.default_url),callback=function()
        UIManager:close(menu)
        self:input("Umbrel-Server",self.config.sync_url or Sync.default_url,function(value)
            local ok=pcall(Sync.url,value,self.month)
            if not ok then self:notify("Bitte http://IP:Port eingeben.");return false end
            local config=Model.copy(self.config);config.sync_url=value:gsub("/+$","")
            return self:saveConfig(config)
        end,{description="Heimnetzadresse inkl. Port; Einträge werden auf deinem Umbrel gespeichert."})
    end}
    items[#items+1]={text="Verbindungsschlüssel: " .. (self.config.sync_token and self.config.sync_token~="" and "hinterlegt" or "fehlt"),callback=function()
        UIManager:close(menu)
        self:input("Umbrel-Verbindungsschlüssel",self.config.sync_token or "",function(value)
            value=value:gsub("%s",""):lower()
            if value~="" and (not value:match("^[a-f0-9]+$") or #value~=24) then
                self:notify("Bitte die 24 Zeichen von der Kindle-Verbindungsseite übernehmen.");return false
            end
            local config=Model.copy(self.config);config.sync_token=value
            return self:saveConfig(config)
        end,{password=true,description="Im angemeldeten Dashboard /kindle-setup öffnen. Nicht das Umbrel-Passwort eingeben."})
    end}
    local conflict_count=0;for _ in pairs(self.conflicts or {}) do conflict_count=conflict_count+1 end
    items[#items+1]={text="Konflikte: " .. conflict_count,callback=function() UIManager:close(menu);self:showConflicts() end}
    items[#items+1]={text="Letzter Kontakt: " .. (self.journal_status.synced_at or self.metrics.synced_at or "noch keiner"),callback=function() end}
    menu=Menu:new{title="Umbrel · Tagebuch und Messwerte",item_table=items};UIManager:show(menu)
end
function Diary:showConflicts()
    local items,menu={},nil
    for date in pairs(self.conflicts or {}) do
        local day=date
        items[#items+1]={text=day,callback=function() UIManager:close(menu);self:resolveConflict(day) end}
    end
    if #items==0 then self:notify("Keine offenen Konflikte.");return end
    table.sort(items,function(a,b)return a.text<b.text end)
    menu=Menu:new{title="Konflikte · beide Fassungen bleiben erhalten",item_table=items};UIManager:show(menu)
end
function Diary:resolveConflict(date)
    local remote=self.conflicts[date]
    if not remote then return end
    local menu
    local function choose(use_remote)
        local ok,err=pcall(function()
            local store=self:getStorage();local entries=store:read(self.month)
            local value=use_remote and Model.entry(date,remote.entry) or entries[date]
            value._sync_revision=remote.revision;value._sync_dirty=not use_remote
            entries[date]=value;store:writeFile(self.month .. ".json",entries)
            local conflicts=Model.copy(self.conflicts);conflicts[date]=nil
            store:writeFile("conflicts-" .. self.month .. ".json",conflicts)
        end)
        if ok then UIManager:close(menu);self:refresh();self:notify(use_remote and "Umbrel-Fassung übernommen" or "Kindle-Fassung vorgemerkt; jetzt erneut abgleichen.")
        else self:notify("Konflikt nicht aufgelöst: " .. tostring(err)) end
    end
    menu=Menu:new{title="Konflikt · " .. date,item_table={
        {text="Beide Fassungen ansehen",callback=function()
            local TextViewer=require("ui/widget/textviewer")
            UIManager:show(TextViewer:new{title=date,text="KINDLE\n" .. json.encode(Sync.clean(self:entry(date))) .. "\n\nUMBREL\n" .. json.encode(remote.entry)})
        end},
        {text="Umbrel-Fassung übernehmen",callback=function() UIManager:show(ConfirmBox:new{text="Lokale Fassung durch Umbrel ersetzen?",ok_callback=function()choose(true)end})end},
        {text="Kindle-Fassung behalten und hochladen",callback=function()UIManager:show(ConfirmBox:new{text="Kindle-Fassung beim nächsten Abgleich über die angezeigte Umbrel-Fassung speichern?",ok_callback=function()choose(false)end})end},
    }};UIManager:show(menu)
end
return Diary
