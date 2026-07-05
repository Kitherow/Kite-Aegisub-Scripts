script_name = "Line Mixer"
script_description = "Shuffle text among selected dialogue lines"
script_author = "Kiterow"
script_version = "1.0.0"
script_namespace = "kite.LineMixer"
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

local function main(subs, sel)
    local indexes = {}
    local texts = {}
    for _, i in ipairs(sel or {}) do
        local line = subs[i]
        if line and line.class == "dialogue" then
            indexes[#indexes + 1] = i
            texts[#texts + 1] = line.text
        end
    end
    if #indexes < 2 then return sel end
    math.randomseed(os.time() + #indexes)
    for i = #texts, 2, -1 do
        local j = math.random(i)
        texts[i], texts[j] = texts[j], texts[i]
    end
    for n, i in ipairs(indexes) do
        local line = subs[i]
        line.text = texts[n]
        subs[i] = line
    end
    if aegisub and aegisub.set_undo_point then aegisub.set_undo_point(script_name) end
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
