local Storage = {}
Storage.__index = Storage

function Storage:new(directory, json)
    return setmetatable({ directory = directory, json = json }, self)
end

function Storage:read(month)
    assert(month:match("^%d%d%d%d%-%d%d$"), "Ungültiger Monat")
    local path = self.directory .. "/" .. month .. ".json"
    local file, err = io.open(path, "rb")
    if not file then
        -- A missing file is an empty month; other errors must remain visible.
        local _, _, code = os.rename(path, path)
        if code == 2 then return {} end
        error(err or "Monatsdatei nicht lesbar")
    end
    local text = file:read("*a")
    file:close()
    local entries = self.json.decode(text)
    assert(type(entries) == "table", "Ungültige Monatsdatei")
    for date, entry in pairs(entries) do
        assert(type(date) == "string" and date:sub(1, 7) == month, "Ungültiges Eintragsdatum")
        assert(type(entry) == "table" and type(entry.text) == "string", "Ungültiger Eintrag")
        assert(type(entry.habits) == "table", "Ungültige Tracker")
        for i = 1, 3 do assert(type(entry.habits[i]) == "boolean", "Ungültiger Tracker") end
    end
    return entries
end

function Storage:save(date, entry)
    assert(date:match("^%d%d%d%d%-%d%d%-%d%d$"), "Ungültiges Datum")
    assert(type(entry.text) == "string" and #entry.text <= 20000, "Text zu lang (max. 20.000 Bytes)")
    local entries = self:read(date:sub(1, 7))
    entries[date] = entry
    local path = self.directory .. "/" .. date:sub(1, 7) .. ".json"
    local temp = path .. ".pending"
    local encoded = self.json.encode(entries)
    local file = assert(io.open(temp, "wb"))
    local ok, err = file:write(encoded)
    if not ok then file:close(); os.remove(temp); error(err) end
    local closed, close_err = file:close()
    if not closed then os.remove(temp); error(close_err) end
    local renamed, rename_err = os.rename(temp, path)
    if not renamed then os.remove(temp); error(rename_err) end
end

return Storage
