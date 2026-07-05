script_name = "Fad-Continuity"
script_description = "Remove internal fade edges between continuous selected timing groups"
script_author = "Kiterow"
script_version = "1.0.0"
script_namespace = "kite.FadContinuity"
local HOTKEY_MENU_ROOT = ": Kite Hotkeys :"
local HOTKEY_MENU_SCRIPT = script_name

local depctrl
local ok_depctrl, DependencyControl = pcall(require, "l0.DependencyControl")
if ok_depctrl and DependencyControl then
    local ok_record, record = pcall(DependencyControl, {
        name = script_name,
        description = script_description,
        author = script_author,
        version = script_version,
        namespace = script_namespace,
        feed = "https://raw.githubusercontent.com/Kitherow/Kite-Aegisub-Scripts/main/DependencyControl.json",
    })
    if ok_record then depctrl = record end
end

local function trim(value)
    return (tostring(value or ""):match("^%s*(.-)%s*$")) or ""
end

local function is_zero(value)
    local n = tonumber(trim(value))
    return n ~= nil and n == 0
end

local function notify(message)
    if aegisub and aegisub.log then pcall(aegisub.log, tostring(message or "") .. "\n") end
end

local function adjust_fad_edges(text, remove_in, remove_out)
    local changed = false
    local new_text = tostring(text or ""):gsub("%b{}", function(block)
        local block_changed = false
        local new_block = block:gsub("(\\fad%s*%(([^)]*)%))", function(tag, args)
            local first, second = tostring(args or ""):match("^%s*([^,]+)%s*,%s*([^,]+)%s*$")
            if not first or not second then return tag end
            first = trim(first)
            second = trim(second)
            local tag_changed = false
            if remove_in and not is_zero(first) then
                first = "0"
                tag_changed = true
            end
            if remove_out and not is_zero(second) then
                second = "0"
                tag_changed = true
            end
            if not tag_changed then return tag end
            block_changed = true
            changed = true
            if is_zero(first) and is_zero(second) then return "" end
            return "\\fad(" .. first .. "," .. second .. ")"
        end)
        if block_changed and new_block:match("^%{%s*%}$") then return "" end
        return new_block
    end)
    return new_text, changed
end

local function main(subs, sel)
    local groups = {}
    local by_time = {}
    for _, i in ipairs(sel or {}) do
        local line = subs[i]
        if line and line.class == "dialogue" then
            local key = tostring(line.start_time) .. "|" .. tostring(line.end_time)
            local group = by_time[key]
            if not group then
                group = {start_time = line.start_time, end_time = line.end_time, first_index = i, indexes = {}}
                by_time[key] = group
                groups[#groups + 1] = group
            elseif i < group.first_index then
                group.first_index = i
            end
            group.indexes[#group.indexes + 1] = i
        end
    end
    if #groups < 2 then
        notify("Fad-Continuity needs at least two selected timing groups.")
        return sel
    end
    table.sort(groups, function(a, b)
        if a.start_time ~= b.start_time then return a.start_time < b.start_time end
        if a.end_time ~= b.end_time then return a.end_time < b.end_time end
        return a.first_index < b.first_index
    end)
    local remove_in = {}
    local remove_out = {}
    for i = 1, #groups - 1 do
        if groups[i].end_time == groups[i + 1].start_time then
            remove_out[i] = true
            remove_in[i + 1] = true
        end
    end
    local modified = 0
    for group_index, group in ipairs(groups) do
        if remove_in[group_index] or remove_out[group_index] then
            for _, line_index in ipairs(group.indexes) do
                local line = subs[line_index]
                local new_text, changed = adjust_fad_edges(line.text, remove_in[group_index], remove_out[group_index])
                if changed then
                    line.text = new_text
                    subs[line_index] = line
                    modified = modified + 1
                end
            end
        end
    end
    if modified > 0 and aegisub and aegisub.set_undo_point then aegisub.set_undo_point(script_name) end
    return sel
end

if aegisub and aegisub.register_macro then
    local hotkey_path = HOTKEY_MENU_ROOT .. "/" .. HOTKEY_MENU_SCRIPT .. "/Execute"
    if depctrl and depctrl.registerMacro then
        depctrl:registerMacro(script_name, script_description, main, nil, nil, false)
        depctrl:registerMacro(hotkey_path, script_description, main, nil, nil, false)
    else
        aegisub.register_macro(script_name, script_description, main)
        aegisub.register_macro(hotkey_path, script_description, main)
    end
end
