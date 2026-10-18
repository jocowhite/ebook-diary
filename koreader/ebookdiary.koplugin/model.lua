local Model = {}
Model.sports = {
    { id = "swimming", label = "Schwimmen" },
    { id = "cycling", label = "Radfahren" },
    { id = "running", label = "Laufen" },
    { id = "football", label = "Fußball" },
    { id = "padel", label = "Padel" },
}
Model.max_visible = 6

function Model.copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for k, v in pairs(value) do result[k] = Model.copy(v) end
    return result
end

function Model.defaultConfig()
    return { version = 2, next_id = 1, columns = {
        {id="sport", label="Sport", kind="sport", visible=true},
        {id="sleep", label="Schlaf", kind="sleep", visible=true},
        {id="outside", label="Draußen", kind="habit", visible=true},
        {id="reading", label="Lesen", kind="habit", visible=true},
        {id="food", label="Gut gegessen", kind="habit", visible=true},
    }}
end

function Model.entry(date, original)
    local entry = Model.copy(original or {text="", habits={false,false,false}})
    entry.date = date
    entry.trackers = entry.trackers or {}
    -- Migrate the three original tracker positions without discarding their values.
    for i, id in ipairs({"outside", "reading", "food"}) do
        if entry.trackers[id] == nil then entry.trackers[id] = entry.habits[i] end
    end
    entry.sports = entry.sports or {}
    return entry
end

function Model.withMetrics(date, original, metric)
    local entry=Model.entry(date,original)
    metric=metric or {}
    local manual_sleep=entry.sleep_manual
    if manual_sleep==nil then manual_sleep=entry.sleep_score~=nil end
    local manual_sports=entry.sports_manual
    if manual_sports==nil then manual_sports=next(entry.sports)~=nil end
    if not manual_sleep then entry.sleep_score=metric.sleep_score end
    if not manual_sports then entry.sports=Model.copy(metric.sports or {}) end
    return entry
end

function Model.validateEntry(entry)
    assert(type(entry) == "table" and type(entry.text) == "string" and #entry.text <= 20000, "Ungültiger oder zu langer Text (max. 20.000 Bytes)")
    assert(type(entry.habits) == "table", "Ungültige Tracker")
    for i=1,3 do assert(type(entry.habits[i]) == "boolean", "Ungültiger Tracker") end
    assert(entry._sync_revision==nil or (type(entry._sync_revision)=="number" and entry._sync_revision>=0 and entry._sync_revision%1==0),"Ungültige Sync-Revision")
    assert(entry._sync_dirty==nil or type(entry._sync_dirty)=="boolean","Ungültiger Sync-Status")
    for _,flag in ipairs({"sleep_manual","sports_manual"}) do
        assert(entry[flag]==nil or type(entry[flag])=="boolean","Ungültiger manueller Status")
    end
    if entry.trackers ~= nil then
        assert(type(entry.trackers) == "table", "Ungültige Tracker")
        for id, value in pairs(entry.trackers) do
            assert(type(id) == "string" and type(value) == "boolean", "Ungültiger Trackerwert")
        end
    end
    if entry.sleep_score ~= nil then
        assert(type(entry.sleep_score) == "number" and entry.sleep_score % 1 == 0 and entry.sleep_score >= 0 and entry.sleep_score <= 100, "Sleep Score: ganze Zahl von 0 bis 100")
    end
    if entry.sports ~= nil then
        assert(type(entry.sports) == "table", "Ungültige Sportwerte")
        local valid = {}
        for _, sport in ipairs(Model.sports) do valid[sport.id] = true end
        for id, selected in pairs(entry.sports) do
            assert(valid[id] and type(selected) == "boolean", "Ungültige Sportart")
        end
    end
end

function Model.sleepScore(text)
    text = text:match("^%s*(.-)%s*$")
    if text == "" then return nil end
    local number = tonumber(text)
    assert(text:match("^%d+$") and number >= 0 and number <= 100, "Bitte eine ganze Zahl von 0 bis 100 eingeben oder das Feld leeren.")
    return number
end

function Model.visibleColumns(config)
    local columns = {}
    for _, col in ipairs(config.columns) do if col.visible then columns[#columns+1] = col end end
    return columns
end

function Model.validateConfig(config)
    assert(type(config) == "table" and type(config.columns) == "table", "Ungültige Spaltenkonfiguration")
    assert(type(config.next_id) == "number" and config.next_id >= 1 and config.next_id % 1 == 0, "Ungültige Spalten-ID")
    assert(config.sync_url==nil or (type(config.sync_url)=="string" and config.sync_url:match("^http://[%w%.%-]+:?%d*/*$")),"Ungültige Serveradresse")
    local ids, visible = {}, 0
    for _, col in ipairs(config.columns) do
        assert(type(col.id) == "string" and col.id:match("^[a-z][a-z0-9_]*$") and not ids[col.id], "Ungültige oder doppelte Spalte")
        assert(type(col.label) == "string" and col.label:match("%S") and #col.label <= 60, "Spaltenname: 1–60 Bytes")
        assert(col.kind == "habit" or (col.id == "sport" and col.kind == "sport") or (col.id == "sleep" and col.kind == "sleep"), "Ungültiger Spaltentyp")
        assert(type(col.visible) == "boolean", "Ungültige Sichtbarkeit")
        ids[col.id] = true
        if col.visible then visible = visible + 1 end
    end
    assert(visible <= Model.max_visible, "Höchstens sechs Kachelspalten gleichzeitig anzeigen; zuerst eine ausblenden.")
end

function Model.addColumn(config, label)
    label = label:match("^%s*(.-)%s*$")
    local updated = Model.copy(config)
    local id = "custom_" .. updated.next_id
    updated.next_id = updated.next_id + 1
    updated.columns[#updated.columns+1] = {id=id, label=label, kind="habit", visible=true}
    Model.validateConfig(updated)
    return updated
end

function Model.toggle(entry, id)
    entry.trackers[id] = not entry.trackers[id]
    for i, legacy in ipairs({"outside", "reading", "food"}) do
        if id == legacy then entry.habits[i] = entry.trackers[id] end
    end
end

function Model.monthDays(month)
    local year, number = month:match("^(%d%d%d%d)%-(%d%d)$")
    year, number = tonumber(year), tonumber(number)
    assert(year and number and year >= 1900 and year <= 9998 and number >= 1 and number <= 12, "Ungültiger Monat")
    local days = {31,28,31,30,31,30,31,31,30,31,30,31}
    if number == 2 and year % 4 == 0 and (year % 100 ~= 0 or year % 400 == 0) then return 29 end
    return days[number]
end

return Model
