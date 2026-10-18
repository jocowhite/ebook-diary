local path = debug.getinfo(1, "S").source:sub(2):match("(.*/)")
local Model = dofile(path .. "model.lua")
local Storage = {}
Storage.__index = Storage

function Storage:new(directory, json)
    return setmetatable({ directory = directory, json = json }, self)
end

function Storage:readFile(name, default)
    local file_path = self.directory .. "/" .. name
    local file, err = io.open(file_path, "rb")
    if not file then
        local _, _, code = os.rename(file_path, file_path)
        if code == 2 then return default end
        error(err or "Datei nicht lesbar")
    end
    local text = file:read("*a")
    file:close()
    return self.json.decode(text)
end

function Storage:writeFile(name, value)
    local file_path = self.directory .. "/" .. name
    local temp = file_path .. ".pending"
    local encoded = self.json.encode(value)
    local file = assert(io.open(temp, "wb"))
    local ok, err = file:write(encoded)
    if not ok then file:close(); os.remove(temp); error(err) end
    local closed, close_err = file:close()
    if not closed then os.remove(temp); error(close_err) end
    local renamed, rename_err = os.rename(temp, file_path)
    if not renamed then os.remove(temp); error(rename_err) end
end

function Storage:read(month)
    local count = Model.monthDays(month)
    local entries = self:readFile(month .. ".json", {})
    assert(type(entries) == "table", "Ungültige Monatsdatei")
    for date, entry in pairs(entries) do
        assert(type(date) == "string" and date:match("^%d%d%d%d%-%d%d%-%d%d$") and date:sub(1,7) == month, "Ungültiges Eintragsdatum")
        local day = tonumber(date:sub(9,10))
        assert(day >= 1 and day <= count, "Ungültiger Tag")
        Model.validateEntry(entry)
    end
    return entries
end

function Storage:save(date, entry)
    assert(type(date) == "string" and date:match("^%d%d%d%d%-%d%d%-%d%d$"), "Ungültiges Datum")
    local count = Model.monthDays(date:sub(1,7))
    local day = tonumber(date:sub(9,10))
    assert(day >= 1 and day <= count, "Ungültiger Tag")
    Model.validateEntry(entry)
    local entries = self:read(date:sub(1,7))
    entry=Model.copy(entry)
    entry._sync_dirty=true
    entries[date] = entry
    self:writeFile(date:sub(1,7) .. ".json", entries)
end

function Storage:readConfig()
    local config = self:readFile("columns.json", Model.defaultConfig())
    Model.validateConfig(config)
    return config
end

function Storage:saveConfig(config)
    Model.validateConfig(config)
    -- Check existing data first: never silently overwrite corrupt configuration.
    self:readConfig()
    self:writeFile("columns.json", config)
end

function Storage:readMetrics(month)
    local count=Model.monthDays(month)
    local cached=self:readFile("metrics-" .. month .. ".json",{days={}})
    assert(type(cached)=="table" and type(cached.days)=="table","Ungültiger Messwert-Cache")
    for date,metric in pairs(cached.days) do
        assert(type(date)=="string" and date:match("^%d%d%d%d%-%d%d%-%d%d$") and date:sub(1,7)==month and type(metric)=="table","Ungültiger Cache-Tag")
        local day=tonumber(date:sub(9,10));assert(day>=1 and day<=count,"Ungültiger Cache-Tag")
        Model.validateEntry({text="",habits={false,false,false},sleep_score=metric.sleep_score,sports=metric.sports})
    end
    return cached
end

return Storage
