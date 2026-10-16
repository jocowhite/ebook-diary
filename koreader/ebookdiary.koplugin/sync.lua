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
function Sync.fetch(base,month,json,transport)
    local url=Sync.url(base,month)
    local body
    if transport then body=transport(url) else
        local http=require("socket.http")
        local socket=require("socket")
        local socketutil=require("socketutil")
        local chunks,total={},0;local start=socket.gettime()
        socketutil:set_timeout(5,8)
        local ok,result,code=pcall(http.request,{
            url=url,method="GET",redirect=false,headers={Accept="application/json"},
            sink=function(chunk)
                if chunk then
                    total=total+#chunk
                    if total>500000 or socket.gettime()-start>8 then return nil,"Antwort zu groß oder Timeout" end
                    chunks[#chunks+1]=chunk
                end
                return 1
            end,
        })
        socketutil:reset_timeout()
        assert(ok and result and tonumber(code)==200,"Umbrel nicht erreichbar oder HTTP-Fehler " .. (tonumber(code) or "(Verbindung)"))
        body=table.concat(chunks)
    end
    assert(type(body)=="string" and #body<=500000,"Ungültige Antwortgröße")
    return Sync.validate(json.decode(body),month,json)
end
function Sync.run(storage,base,month,json,transport)
    local days=Sync.fetch(base,month,json,transport)
    local cached=storage:readMetrics(month)
    for date,value in pairs(days) do cached.days[date]=value end
    cached.synced_at=os.date("!%Y-%m-%dT%H:%M:%SZ")
    storage:writeFile("metrics-" .. month .. ".json",cached)
    return cached
end
return Sync
