script_name = "Komari"
script_description = "Mark dialogue lines that contain stutter patterns"
script_author = "Kiterow"
script_version = "1.0.0"
script_namespace = "kite.Komari"
local HOTKEY_MENU_ROOT = ": Kite Hotkeys :"
local HOTKEY_MENU_SCRIPT = script_name
local EFFECT_MARKER = "Komari"

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

local lower_map = {
    ["Á"] = "á", ["É"] = "é", ["Í"] = "í", ["Ó"] = "ó", ["Ú"] = "ú", ["Ü"] = "ü", ["Ñ"] = "ñ",
    ["À"] = "à", ["È"] = "è", ["Ì"] = "ì", ["Ò"] = "ò", ["Ù"] = "ù",
}

local function split_utf8(text)
    local out = {}
    for char in tostring(text or ""):gmatch("[%z\1-\127\194-\244][\128-\191]*") do out[#out + 1] = char end
    return out
end

local function lower_char(char)
    return lower_map[char] or tostring(char or ""):lower()
end

local function is_letter(char)
    if tostring(char or ""):match("^%a$") then return true end
    local lowered = lower_char(char)
    return lowered:match("^[áéíóúüñàèìòù]$") ~= nil
end

local function visible_text(text)
    local out = tostring(text or ""):gsub("{[^}]*}", "")
    out = out:gsub("\\[NnHh]", " ")
    return out
end

local function has_stutter(text)
    local clean = visible_text(text)
    for word in clean:gmatch("%S+") do
        local chars = split_utf8(word)
        for i = 1, #chars - 2 do
            if chars[i + 1] == "-" and is_letter(chars[i]) and is_letter(chars[i + 2])
                and lower_char(chars[i]) == lower_char(chars[i + 2]) then
                return true
            end
        end
    end
    return false
end

local function mark_effect(line)
    local effect = tostring(line.effect or "")
    if effect == "" then
        line.effect = EFFECT_MARKER
    elseif not effect:find(EFFECT_MARKER, 1, true) then
        line.effect = effect .. " " .. EFFECT_MARKER
    end
end

local function main(subs, sel)
    local changed = 0
    for _, i in ipairs(sel or {}) do
        local line = subs[i]
        if line and line.class == "dialogue" and has_stutter(line.text) then
            local before = tostring(line.effect or "")
            mark_effect(line)
            if tostring(line.effect or "") ~= before then
                subs[i] = line
                changed = changed + 1
            end
        end
    end
    if changed > 0 and aegisub and aegisub.set_undo_point then aegisub.set_undo_point(script_name) end
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
