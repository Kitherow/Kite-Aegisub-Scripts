script_name = "Insert Coñete"
script_description = "Clone selected lines and replace visible text with Coñete"
script_author = "Kiterow"
script_version = "1.0.0"
script_namespace = "kite.InsertConete"
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

local function copy_line(line)
    local out = {}
    for k, v in pairs(line or {}) do out[k] = v end
    return out
end

local function leading_tags(text)
    text = tostring(text or "")
    local pos = 1
    local tags = {}
    while text:sub(pos, pos) == "{" do
        local close = text:find("}", pos, true)
        if not close then break end
        local block = text:sub(pos, close)
        if block:find("\\", 1, true) then tags[#tags + 1] = block end
        pos = close + 1
    end
    return table.concat(tags)
end

local function main(subs, sel)
    local targets = {}
    for _, i in ipairs(sel or {}) do
        local line = subs[i]
        if line and line.class == "dialogue" then targets[#targets + 1] = i end
    end
    if #targets == 0 then return sel end
    table.sort(targets, function(a, b) return a > b end)
    local inserted = {}
    for _, i in ipairs(targets) do
        local clone = copy_line(subs[i])
        clone.text = leading_tags(clone.text) .. "Coñete"
        subs.insert(i + 1, clone)
        inserted[#inserted + 1] = i + 1
    end
    table.sort(inserted)
    if aegisub and aegisub.set_undo_point then aegisub.set_undo_point(script_name) end
    return inserted
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
