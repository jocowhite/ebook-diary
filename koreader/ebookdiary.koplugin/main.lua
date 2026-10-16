local WidgetContainer = require("ui/widget/container/widgetcontainer")
local UIManager = require("ui/uimanager")
local Menu = require("ui/widget/menu")
local InputDialog = require("ui/widget/inputdialog")
local InfoMessage = require("ui/widget/infomessage")
local DataStorage = require("datastorage")
local lfs = require("libs/libkoreader-lfs")
local json = require("rapidjson")
local plugin_dir = debug.getinfo(1, "S").source:sub(2):match("(.*/)")
local Storage = dofile(plugin_dir .. "storage.lua")
local Diary = WidgetContainer:extend{ name = "ebookdiary", is_doc_only = false }
local habits = { "Draußen", "Lesen", "Gut gegessen" }

function Diary:init()
    self.ui.menu:registerToMainMenu(self)
end

function Diary:addToMainMenu(items)
    items.ebookdiary = {
        text = "Ein Tag. Eine Zeile.",
        sorting_hint = "more_tools",
        callback = function() self:showMonth(os.date("%Y-%m")) end,
    }
end

function Diary:notify(text)
    UIManager:show(InfoMessage:new{ text = text })
end

function Diary:getStorage()
    if not self.storage then
        local directory = DataStorage:getDataDir() .. "/ebook-diary"
        if not lfs.attributes(directory, "mode") then
            assert(lfs.mkdir(directory), "Datenordner konnte nicht erstellt werden")
        end
        self.storage = Storage:new(directory, json)
    end
    return self.storage
end

function Diary:showMonth(month)
    local ok, entries = pcall(function() return self:getStorage():read(month) end)
    if not ok then self:notify("Tagebuch konnte nicht geladen werden:\n" .. tostring(entries)); return end
    local year, number = month:match("^(%d+)%-(%d+)$")
    year, number = tonumber(year), tonumber(number)
    local count = tonumber(os.date("%d", os.time{ year = year, month = number + 1, day = 0, hour = 12 }))
    local items, menu = {}, nil
    local function move(offset)
        local target = os.date("%Y-%m", os.time{ year = year, month = number + offset, day = 1, hour = 12 })
        UIManager:close(menu); self:showMonth(target)
    end
    items[#items + 1] = { text = "← Voriger Monat", callback = function() move(-1) end }
    items[#items + 1] = { text = "Nächster Monat →", callback = function() move(1) end }
    for day = 1, count do
        local date = string.format("%s-%02d", month, day)
        local entry = entries[date] or { date = date, text = "", habits = {false, false, false} }
        local line = entry.text:match("[^\r\n]+") or "Eintrag hinzufügen"
        items[#items + 1] = {
            text = string.format("%02d · %s", day, line),
            callback = function()
                UIManager:close(menu)
                self:showDay(date, entry)
            end,
        }
    end
    menu = Menu:new{ title = "Tagebuch · " .. month, item_table = items, is_popout = false, is_borderless = true }
    UIManager:show(menu)
end

function Diary:save(date, entry)
    local ok, err = pcall(function() self:getStorage():save(date, entry) end)
    if not ok then self:notify("Nicht gespeichert:\n" .. tostring(err)); return false end
    return true
end

function Diary:showDay(date, entry)
    local menu
    local items = {
        { text = "Text schreiben / bearbeiten", callback = function()
            UIManager:close(menu); self:edit(date, entry)
        end },
    }
    for index, label in ipairs(habits) do
        local i = index
        items[#items + 1] = {
            text = (entry.habits[i] and "[x] " or "[ ] ") .. label,
            callback = function()
                local updated = { date = date, text = entry.text, habits = {entry.habits[1], entry.habits[2], entry.habits[3]} }
                updated.habits[i] = not updated.habits[i]
                if self:save(date, updated) then
                    UIManager:close(menu); self:showDay(date, updated)
                end
            end,
        }
    end
    items[#items + 1] = { text = "Zur Monatsliste", callback = function()
        UIManager:close(menu); self:showMonth(date:sub(1, 7))
    end }
    menu = Menu:new{ title = date, item_table = items, is_popout = false, is_borderless = true }
    UIManager:show(menu)
end

function Diary:edit(date, entry)
    local dialog
    dialog = InputDialog:new{
        title = "Tagebuch · " .. date,
        input = entry.text,
        input_type = "text",
        allow_newline = true,
        fullscreen = true,
        add_nav_bar = true,
        buttons = {{
            { text = "Abbrechen", callback = function()
                UIManager:close(dialog); self:showDay(date, entry)
            end },
            { text = "Speichern", is_enter_default = false, callback = function()
                local updated = { date = date, text = dialog:getInputText(), habits = entry.habits }
                if self:save(date, updated) then
                    UIManager:close(dialog); self:showDay(date, updated)
                    self:notify("Lokal gespeichert")
                end
            end },
        }},
    }
    UIManager:show(dialog)
    dialog:onShowKeyboard()
end

return Diary
