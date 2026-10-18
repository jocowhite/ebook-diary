local path=debug.getinfo(1,"S").source:sub(2):match("(.*/)")
local Model=dofile(path .. "model.lua")
local Sync={}
Sync.default_url="http://192.168.178.98:8477"
function Sync.url(base,month)
    Model.monthDays(month)
    base=base:match("^%s*(.-)%s*$"):gsub("/+$","")
    assert(base:match("^http://[%w%.%-]+:?%d*$"),"Bitte http://IP:Port ohne Pfad eingeben (Heimnetz).")
    return base .. "/api/kindle/days?month=" .. month
end
function Sync.validate(payload,month,json)
    local count=Model.monthDays(month)
    assert(type(payload)=="table" and payload.month==month and type(payload.days)=="table","Ungültige Monatsantwort")
    local days,seen={},0
    local function null(value) return value==nil or value==json.null end
    for key,day in pairs(payload.days) do
        assert(type(key)=="number" and key%1==0 and key>=1 and key<=count,"Ungültige Tagesliste")
        seen=seen+1; assert(seen<=count,"Zu viele Tage")
        assert(type(day)=="table" and type(day.date)=="string" and day.date:match("^%d%d%d%d%-%d%d%-%d%d$") and day.date:sub(1,7)==month,"Ungültiger Tag")
        local number=tonumber(day.date:sub(9,10));assert(number>=1 and number<=count and not days[day.date],"Falscher oder doppelter Tag")
        local metric={}
        if not null(day.sleep_score) then
            local score=day.sleep_score
            assert(type(score)=="number" and score%1==0 and score>=0 and score<=100,"Ungültiger Sleep Score")
            metric.sleep_score=score
        end
        if not null(day.activities) then
            assert(type(day.activities)=="table","Ungültige Sportliste")
            metric.sports={}
            local valid={};for _,sport in ipairs(Model.sports) do valid[sport.id]=true end
            local n=0
            for index,activity in pairs(day.activities) do
                n=n+1;assert(type(index)=="number" and index%1==0 and index>=1 and index<=30 and n<=30,"Ungültige Sportliste")
                assert(type(activity)=="table" and type(activity.type)=="string" and #activity.type<=60,"Ungültige Sportart")
                local duration=activity.duration_minutes
                assert(type(duration)=="number" and duration>=0 and duration<=10080,"Ungültige Sportdauer")
                if valid[activity.type] then metric.sports[activity.type]=true end
            end
        end
        days[day.date]=metric
    end
    return days
end
function Sync.request(url,json,method,value,token,transport,limit)
    local body=value and json.encode(value) or nil
    local response
    limit=limit or 500000
    if transport then response=transport(url,method,body,token) else
        local http=require("socket.http")
        local socket=require("socket")
        local socketutil=require("socketutil")
        local headers={Accept="application/json",Authorization=token and token~="" and ("Bearer " .. token) or nil}
        local source
        if body then
            headers["Content-Type"]="application/json";headers["Content-Length"]=tostring(#body)
            source=require("ltn12").source.string(body)
        end
        local chunks,total={},0;local start=socket.gettime()
        socketutil:set_timeout(5,8)
        local ok,result,code=pcall(http.request,{
            url=url,method=method,redirect=false,headers=headers,source=source,
            sink=function(chunk)
                if chunk then
                    total=total+#chunk
                    if total>limit or socket.gettime()-start>8 then return nil,"Antwort zu groß oder Timeout" end
                    chunks[#chunks+1]=chunk
                end
                return 1
            end,
        })
        socketutil:reset_timeout()
        if tonumber(code)==302 or tonumber(code)==301 or tonumber(code)==303 then
            error("Umbrel-Anmeldung: Health Dashboard auf 0.4.0 aktualisieren und /kindle-setup öffnen.")
        end
        if tonumber(code)==401 then error("Verbindungsschlüssel fehlt oder ist falsch. /kindle-setup im angemeldeten Dashboard öffnen und Schlüssel unter Umbrel eintragen.") end
        assert(ok and result and tonumber(code)==200,"Umbrel nicht erreichbar oder HTTP-Fehler " .. (tonumber(code) or "(Verbindung)"))
        response=table.concat(chunks)
    end
    assert(type(response)=="string" and #response<=limit,"Ungültige Antwortgröße")
    return json.decode(response)
end
function Sync.fetch(base,month,json,transport,token)
    local fields={"text","habits","trackers","sports","sleep_score","sleep_manual","sports_manual"}
function Sync.clean(entry)
    local value={}
    for _,key in ipairs(fields) do value[key]=Model.copy(entry[key]) end
    return value
end
function Sync.journal(storage,base,month,json,token,transport)
    local url=Sync.url(base,month):gsub("/days%?","/journal?")
    local entries=storage:read(month)
    local pending={}
    for date,entry in pairs(entries) do
        if entry._sync_dirty~=false or entry._sync_revision==nil then
            pending[#pending+1]={date=date,entry=Sync.clean(entry),base_revision=entry._sync_revision or 0}
        end
    end
    local columns={}
    for _,col in ipairs(storage:readConfig().columns) do if col.kind=="habit" then columns[col.id]=col.label end end
    local payload=Sync.request(url,json,"POST",{month=month,entries=pending,columns=columns},token,transport,2000000)
    assert(type(payload)=="table" and payload.month==month and type(payload.entries)=="table" and type(payload.conflicts)=="table","Ungültige Tagebuch-Antwort")
    local conflict_dates={}
    for _,date in ipairs(payload.conflicts) do assert(type(date)=="string" and date:sub(1,7)==month,"Ungültiger Konflikt");conflict_dates[date]=true end
    local remote={}
    for _,record in pairs(payload.entries) do
        assert(type(record)=="table" and type(record.date)=="string" and record.date:match("^%d%d%d%d%-%d%d%-%d%d$") and record.date:sub(1,7)==month and not remote[record.date],"Ungültiges Eintragsdatum")
        local day=tonumber(record.date:sub(9,10));assert(day>=1 and day<=Model.monthDays(month),"Ungültiger Tag")
        assert(type(record.revision)=="number" and record.revision>=1 and record.revision%1==0,"Ungültige Revision")
        Model.validateEntry(record.entry);remote[record.date]=record
    end
    -- Validate the complete response before touching any local file.
    for date in pairs(conflict_dates) do assert(remote[date] and entries[date],"Konflikt ohne Fassungen") end
    for _,item in ipairs(pending) do assert(remote[item.date],"Bestätigung eines Eintrags fehlt") end
    local conflicts={}
    for date,record in pairs(remote) do
        if conflict_dates[date] then conflicts[date]=record
        else
            local value=Model.entry(date,record.entry)
            value._sync_revision=record.revision;value._sync_dirty=false
            entries[date]=value
        end
    end
    storage:writeFile("conflicts-" .. month .. ".json",conflicts)
    storage:writeFile(month .. ".json",entries)
    storage:writeFile("journal-status-" .. month .. ".json",{synced_at=os.date("!%Y-%m-%dT%H:%M:%SZ")})
    local count=0;for _ in pairs(conflicts) do count=count+1 end
    return count
end
function Sync.all(storage,base,month,json,token,transport)
    local count=Sync.journal(storage,base,month,json,token,transport)
    local ok,err=pcall(Sync.run,storage,base,month,json,transport,token)
    return {conflicts=count,metrics_error=not ok and tostring(err) or nil}
end
return Sync.validate(Sync.request(Sync.url(base,month),json,"GET",nil,token,transport),month,json)
end
function Sync.run(storage,base,month,json,transport,token)
    local days=Sync.fetch(base,month,json,transport,token)
    local cached=storage:readMetrics(month)
    for date,value in pairs(days) do cached.days[date]=value end
    cached.synced_at=os.date("!%Y-%m-%dT%H:%M:%SZ")
    storage:writeFile("metrics-" .. month .. ".json",cached)
    return cached
end
local fields={"text","habits","trackers","sports","sleep_score","sleep_manual","sports_manual"}
function Sync.clean(entry)
    local value={}
    for _,key in ipairs(fields) do value[key]=Model.copy(entry[key]) end
    return value
end
function Sync.journal(storage,base,month,json,token,transport)
    local url=Sync.url(base,month):gsub("/days%?","/journal?")
    local entries=storage:read(month)
    local pending={}
    for date,entry in pairs(entries) do
        if entry._sync_dirty~=false or entry._sync_revision==nil then
            pending[#pending+1]={date=date,entry=Sync.clean(entry),base_revision=entry._sync_revision or 0}
        end
    end
    local columns={}
    for _,col in ipairs(storage:readConfig().columns) do if col.kind=="habit" then columns[col.id]=col.label end end
    local payload=Sync.request(url,json,"POST",{month=month,entries=pending,columns=columns},token,transport,2000000)
    assert(type(payload)=="table" and payload.month==month and type(payload.entries)=="table" and type(payload.conflicts)=="table","Ungültige Tagebuch-Antwort")
    local conflict_dates={}
    for _,date in ipairs(payload.conflicts) do assert(type(date)=="string" and date:sub(1,7)==month,"Ungültiger Konflikt");conflict_dates[date]=true end
    local remote={}
    for _,record in pairs(payload.entries) do
        assert(type(record)=="table" and type(record.date)=="string" and record.date:match("^%d%d%d%d%-%d%d%-%d%d$") and record.date:sub(1,7)==month and not remote[record.date],"Ungültiges Eintragsdatum")
        local day=tonumber(record.date:sub(9,10));assert(day>=1 and day<=Model.monthDays(month),"Ungültiger Tag")
        assert(type(record.revision)=="number" and record.revision>=1 and record.revision%1==0,"Ungültige Revision")
        Model.validateEntry(record.entry);remote[record.date]=record
    end
    -- Validate the complete response before touching any local file.
    for date in pairs(conflict_dates) do assert(remote[date] and entries[date],"Konflikt ohne Fassungen") end
    for _,item in ipairs(pending) do assert(remote[item.date],"Bestätigung eines Eintrags fehlt") end
    local conflicts={}
    for date,record in pairs(remote) do
        if conflict_dates[date] then conflicts[date]=record
        else
            local value=Model.entry(date,record.entry)
            value._sync_revision=record.revision;value._sync_dirty=false
            entries[date]=value
        end
    end
    storage:writeFile("conflicts-" .. month .. ".json",conflicts)
    storage:writeFile(month .. ".json",entries)
    storage:writeFile("journal-status-" .. month .. ".json",{synced_at=os.date("!%Y-%m-%dT%H:%M:%SZ")})
    local count=0;for _ in pairs(conflicts) do count=count+1 end
    return count
end
function Sync.all(storage,base,month,json,token,transport)
    local count=Sync.journal(storage,base,month,json,token,transport)
    local ok,err=pcall(Sync.run,storage,base,month,json,transport,token)
    return {conflicts=count,metrics_error=not ok and tostring(err) or nil}
end
return Sync
