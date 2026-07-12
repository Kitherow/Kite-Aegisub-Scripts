script_name = "Alecto KFX"
script_description = "Karaoke por silaba con fases Intro, Active y Outro configurables por lineas comentadas"
script_author = "Kiterow"
script_version = "1.0.1"
script_namespace = "kite.AlectoKFX"
local HOTKEY_MENU_ROOT = ": Kite Hotkeys :"
local HOTKEY_MENU_SCRIPT = script_name

if not karaskel then
    pcall(require, "karaskel")
end

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

local HWF = {}

local CONFIG = {
    lead_ms = 200,
    stagger_ms = 40,
    fade_ms = 300,
    active_scale = 1.4,
    min_duration_ms = 10,
}

local COLOR_WHITE = "&HFFFFFF&"
local COLOR_BLACK = "&H000000&"

local function trim(value)
    return (tostring(value or ""):match("^%s*(.-)%s*$")) or ""
end

local function show_message(title, msg)
    if aegisub and aegisub.log then
        pcall(aegisub.log, tostring(title or script_name) .. ": " .. tostring(msg or "") .. "\n")
    end
end

local function is_dialogue(line)
    return type(line) == "table" and (line.class == nil or line.class == "dialogue") and line.comment ~= true
end

local function copy_line(line)
    local out = {}
    for k, v in pairs(line or {}) do out[k] = v end
    return out
end

local function normalize_color(value, fallback)
    fallback = fallback or COLOR_WHITE
    if value == nil or value == "" then return fallback end
    if type(value) == "number" then
        if value < 0 then value = value + 4294967296 end
        return string.format("&H%06X&", value % 0x1000000)
    end

    local s = trim(value)
    local hex = s:match("&[Hh](%x+)&?")
    if hex then
        if #hex > 6 then hex = hex:sub(-6) end
        while #hex < 6 do hex = "0" .. hex end
        return "&H" .. hex:upper() .. "&"
    end

    local r, g, b = s:match("#?(%x%x)(%x%x)(%x%x)")
    if r then
        return string.format("&H%s%s%s&", b:upper(), g:upper(), r:upper())
    end

    local plain = s:match("^(%x%x%x%x%x%x)$")
    if plain then return "&H" .. plain:upper() .. "&" end

    return fallback
end

local function style_color(style, slot)
    if type(style) ~= "table" then
        return slot == 1 and COLOR_WHITE or COLOR_BLACK
    end

    local value = style["color" .. tostring(slot)] or style["colour" .. tostring(slot)]
    if slot == 1 then
        value = value or style.primary or style.primary_color or style.primary_colour
    elseif slot == 2 then
        value = value or style.secondary or style.secondary_color or style.secondary_colour
    elseif slot == 3 then
        value = value or style.outline or style.outline_color or style.outline_colour
    elseif slot == 4 then
        value = value or style.shadow or style.shadow_color or style.shadow_colour
    end

    return normalize_color(value, slot == 1 and COLOR_WHITE or COLOR_BLACK)
end

local function style_scale(style, axis)
    if type(style) ~= "table" then return 100 end
    local keys = axis == "x"
        and {"scale_x", "scalex", "ScaleX", "scaleX"}
        or  {"scale_y", "scaley", "ScaleY", "scaleY"}

    for _, key in ipairs(keys) do
        local value = tonumber(style[key])
        if value then return value end
    end
    return 100
end

local function strip_ass_tags(text)
    return tostring(text or ""):gsub("{[^}]*}", "")
end

local function visible_syllable_text(syl)
    if type(syl) ~= "table" then return "" end
    local text = syl.text_stripped
    if text == nil then text = strip_ass_tags(syl.text or syl.text_spacestripped or "") end
    return tostring(text or ""):gsub("\\h", " ")
end

local function fmt_num(value)
    value = tonumber(value) or 0
    local text = string.format("%.2f", value)
    text = text:gsub("0+$", ""):gsub("%.$", "")
    if text == "-0" then text = "0" end
    return text
end

local function positive_window(start_ms, end_ms)
    start_ms = math.max(0, math.floor((tonumber(start_ms) or 0) + 0.5))
    end_ms = math.max(0, math.floor((tonumber(end_ms) or 0) + 0.5))
    if end_ms <= start_ms then end_ms = start_ms + CONFIG.min_duration_ms end
    return start_ms, end_ms
end

local function collect_syllables(line)
    local out = {}
    local kara = line and line.kara
    if type(kara) ~= "table" then return out end

    local first_index = type(kara.n) == "number" and 0 or 1
    local last_index = type(kara.n) == "number" and kara.n or #kara

    for i = first_index, last_index do
        local syl = kara[i]
        local text = visible_syllable_text(syl)
        local start_rel = tonumber(syl and syl.start_time) or 0
        local end_rel = tonumber(syl and syl.end_time)
        local duration = tonumber(syl and syl.duration)
        if not end_rel then end_rel = start_rel + (duration or 0) end
        if not duration then duration = end_rel - start_rel end

        if syl and text ~= "" and duration and duration > 0 then
            local width = tonumber(syl.width) or 0
            local left = tonumber(syl.left)
            local right = tonumber(syl.right)
            local center = tonumber(syl.center)
            if not left and center then left = center - width / 2 end
            if not right and left then right = left + width end
            if not center then
                left = left or 0
                center = left + width / 2
            end
            if width <= 0 and left and right then width = right - left end

            out[#out + 1] = {
                text = text,
                start_rel = start_rel,
                end_rel = end_rel,
                duration = duration,
                left_rel = left,
                right_rel = right,
                center_rel = center,
                width = width,
                height = tonumber(syl.height),
            }
        end
    end

    return out
end

local function make_generated_line(base, layer, effect, start_ms, end_ms, text)
    local line = copy_line(base)
    line.layer = layer
    line.start_time = start_ms
    line.end_time = end_ms
    line.text = text
    line.effect = ""
    return line
end

local function tag_block(tags, text)
    return "{" .. tostring(tags or "") .. "}" .. tostring(text or "")
end

local function normalize_phase(value)
    value = trim(value):lower():gsub("%s+", "")
    if value == "intro" then return "intro" end
    if value == "active" then return "active" end
    if value == "outro" then return "outro" end
    return nil
end

local function extract_override_tags(text)
    local tags = tostring(text or ""):match("{([^}]*)}")
    if tags then return trim(tags) end

    local raw = trim(text)
    if raw:sub(1, 1) == "\\" then return raw end
    return nil
end

local function phase_override_from_line(line)
    if type(line) ~= "table" or line.class ~= "dialogue" or line.comment ~= true then return nil end
    local phase = normalize_phase(line.effect)
    if not phase then return nil end

    local tags = extract_override_tags(line.text)
    if not tags or tags == "" then return nil end
    return phase, tags
end

local function add_override_candidate(overrides, line)
    local phase, tags = phase_override_from_line(line)
    if phase and tags then overrides[phase] = tags end
end

local function collect_phase_overrides(subs, sel)
    local overrides = {}
    if type(subs) ~= "table" or type(sel) ~= "table" or #sel == 0 then return overrides end

    local sorted = {}
    for _, idx in ipairs(sel) do sorted[#sorted + 1] = idx end
    table.sort(sorted)

    local first = sorted[1]
    local last = sorted[#sorted]
    local candidates = {}

    local before = {}
    local idx = first - 1
    while idx >= 1 and type(subs[idx]) == "table" and subs[idx].comment == true do
        before[#before + 1] = idx
        idx = idx - 1
    end
    for i = #before, 1, -1 do candidates[#candidates + 1] = before[i] end

    for _, selected_idx in ipairs(sorted) do candidates[#candidates + 1] = selected_idx end

    idx = last + 1
    while type(subs[idx]) == "table" and subs[idx].comment == true do
        candidates[#candidates + 1] = idx
        idx = idx + 1
    end

    for _, candidate_idx in ipairs(candidates) do
        add_override_candidate(overrides, subs[candidate_idx])
    end

    return overrides
end

local function strip_tag_call(tags, name)
    return tostring(tags or ""):gsub("\\" .. name .. "%b()", "")
end

local function merge_phase_tags(base_tags, override_tags)
    base_tags = tostring(base_tags or "")
    override_tags = trim(override_tags)
    if override_tags == "" then return base_tags end

    if override_tags:find("\\fad%s*%(") then
        base_tags = strip_tag_call(base_tags, "fad")
    end
    if override_tags:find("\\t%s*%(") then
        base_tags = strip_tag_call(base_tags, "t")
    end

    return base_tags .. override_tags
end

local function pos_tags(ctx, dx, dy)
    return "\\an5\\pos(" .. fmt_num(ctx.x + (dx or 0)) .. "," .. fmt_num(ctx.y + (dy or 0)) .. ")"
end

local function phase_effect(ctx)
    return ""
end

local function phase_line(ctx, layer, tags, text, start_ms, end_ms)
    tags = merge_phase_tags(tags, ctx.override_tags)
    return make_generated_line(
        ctx.base_line,
        layer or ctx.layer,
        phase_effect(ctx),
        start_ms or ctx.start_time,
        end_ms or ctx.end_time,
        tag_block(tags, text or ctx.text)
    )
end

local PRESETS = {intro = {}, active = {}, outro = {}}
local PRESET_LOOKUP = {intro = {}, active = {}, outro = {}}

local function add_preset(phase, id, fn)
    local preset = {id = id, fn = fn}
    PRESETS[phase][#PRESETS[phase] + 1] = preset
    PRESET_LOOKUP[phase][id] = preset
end

local function preset_ids(phase)
    local ids = {}
    for _, preset in ipairs(PRESETS[phase] or {}) do ids[#ids + 1] = preset.id end
    return ids
end

add_preset("intro", "fade-2c", function(ctx)
    return {phase_line(ctx, 0, pos_tags(ctx) .. "\\fad(" .. CONFIG.fade_ms .. ",0)\\c" .. ctx.c2)}
end)

add_preset("active", "pop", function(ctx)
    return {phase_line(ctx, 1, pos_tags(ctx) .. "\\fscx" .. fmt_num(ctx.scale_x * CONFIG.active_scale) .. "\\fscy" .. fmt_num(ctx.scale_y * CONFIG.active_scale) .. "\\t(\\fscx" .. fmt_num(ctx.scale_x) .. "\\fscy" .. fmt_num(ctx.scale_y) .. ")\\fad(0," .. CONFIG.fade_ms .. ")")}
end)

add_preset("outro", "fade-1c", function(ctx)
    return {phase_line(ctx, 0, pos_tags(ctx) .. "\\fad(0," .. CONFIG.fade_ms .. ")")}
end)

local DEFAULT_OPTIONS = {
    intro_fx = "fade-2c",
    active_fx = "pop",
    outro_fx = "fade-1c",
    mark_effect = false,
}

local function normalize_options(options)
    options = options or {}
    local out = {}
    out.intro_fx = PRESET_LOOKUP.intro[options.intro_fx or options.intro or DEFAULT_OPTIONS.intro_fx]
        and (options.intro_fx or options.intro or DEFAULT_OPTIONS.intro_fx) or DEFAULT_OPTIONS.intro_fx
    out.active_fx = PRESET_LOOKUP.active[options.active_fx or options.active or DEFAULT_OPTIONS.active_fx]
        and (options.active_fx or options.active or DEFAULT_OPTIONS.active_fx) or DEFAULT_OPTIONS.active_fx
    out.outro_fx = PRESET_LOOKUP.outro[options.outro_fx or options.outro or DEFAULT_OPTIONS.outro_fx]
        and (options.outro_fx or options.outro or DEFAULT_OPTIONS.outro_fx) or DEFAULT_OPTIONS.outro_fx
    out.mark_effect = false
    out.phase_overrides = type(options.phase_overrides) == "table" and options.phase_overrides or {}
    return out
end

local function build_base_context(line, style, syl, syl_i, syl_n, options)
    local scale_x = style_scale(style, "x")
    local scale_y = style_scale(style, "y")
    local line_left = tonumber(line.left) or 0
    local line_middle = tonumber(line.middle) or tonumber(line.y) or 0
    local line_height = tonumber(line.height) or tonumber(style and style.fontsize) or 20
    local line_top = tonumber(line.top) or (line_middle - line_height / 2)
    local line_bottom = tonumber(line.bottom) or (line_top + line_height)
    local line_start = tonumber(line.start_time) or 0
    local line_end = tonumber(line.end_time) or line_start
    local width = math.max(1, tonumber(syl.width) or 1)
    local center_rel = tonumber(syl.center_rel) or 0
    local left_rel = tonumber(syl.left_rel) or (center_rel - width / 2)
    local right_rel = tonumber(syl.right_rel) or (left_rel + width)
    local height = math.max(1, tonumber(syl.height) or line_height)
    local x = line_left + center_rel
    local top = line_top
    local bottom = line_bottom

    local syl_start = line_start + syl.start_rel
    local syl_end = line_start + syl.end_rel
    local intro_start = line_start - CONFIG.lead_ms + (syl_i - 1) * CONFIG.stagger_ms
    local intro_end = syl_start
    intro_start, intro_end = positive_window(math.min(intro_start, intro_end - CONFIG.min_duration_ms), intro_end)
    local active_start, active_end = positive_window(syl_start, syl_end + CONFIG.fade_ms)
    local outro_start = syl_end
    local outro_end = line_end - CONFIG.lead_ms + syl_i * CONFIG.stagger_ms
    outro_start, outro_end = positive_window(outro_start, math.max(outro_end, outro_start + CONFIG.min_duration_ms))

    return {
        base_line = line,
        options = options,
        text = syl.text,
        syl_i = syl_i,
        syl_n = syl_n,
        x = x,
        y = line_middle,
        left = line_left + left_rel,
        right = line_left + right_rel,
        top = top,
        bottom = bottom,
        width = math.max(1, right_rel - left_rel),
        height = height,
        c1 = style_color(style, 1),
        c2 = style_color(style, 2),
        scale_x = scale_x,
        scale_y = scale_y,
        intro_start = intro_start,
        intro_end = intro_end,
        active_start = active_start,
        active_end = active_end,
        outro_start = outro_start,
        outro_end = outro_end,
    }
end

local function phase_context(base, phase, preset_id)
    local ctx = {}
    for k, v in pairs(base) do ctx[k] = v end
    ctx.phase = phase
    ctx.preset_id = preset_id
    ctx.start_time = base[phase .. "_start"]
    ctx.end_time = base[phase .. "_end"]
    ctx.duration = math.max(1, (ctx.end_time or 0) - (ctx.start_time or 0))
    ctx.layer = phase == "active" and 1 or 0
    ctx.override_tags = base.options and base.options.phase_overrides and base.options.phase_overrides[phase] or nil
    return ctx
end

local function append_phase(output, base_ctx, phase, preset_id)
    local preset = PRESET_LOOKUP[phase][preset_id] or PRESET_LOOKUP[phase][DEFAULT_OPTIONS[phase .. "_fx"]]
    local ctx = phase_context(base_ctx, phase, preset.id)
    local ok, lines = pcall(preset.fn, ctx)
    if not ok then error("No se pudo generar una fase del efecto.", 0) end
    for _, line in ipairs(lines or {}) do output[#output + 1] = line end
end

function HWF.generate_from_preprocessed_line(line, style, options)
    if not is_dialogue(line) then return {} end

    local syllables = collect_syllables(line)
    if #syllables == 0 then return {} end

    style = style or line.styleref or {}
    options = normalize_options(options)
    local leadin_lines = {}
    local active_lines = {}
    local leadout_lines = {}

    for i, syl in ipairs(syllables) do
        local base_ctx = build_base_context(line, style, syl, i, #syllables, options)
        append_phase(leadin_lines, base_ctx, "intro", options.intro_fx)
        append_phase(active_lines, base_ctx, "active", options.active_fx)
        append_phase(leadout_lines, base_ctx, "outro", options.outro_fx)
    end

    local generated = {}
    for _, l in ipairs(leadin_lines) do generated[#generated + 1] = l end
    for _, l in ipairs(active_lines) do generated[#generated + 1] = l end
    for _, l in ipairs(leadout_lines) do generated[#generated + 1] = l end
    return generated
end

local LAST_OPTIONS = normalize_options()

local function build_options(subs, sel)
    local options = normalize_options(LAST_OPTIONS)
    options.phase_overrides = collect_phase_overrides(subs, sel)
    LAST_OPTIONS = options
    return LAST_OPTIONS
end

local function preprocess_line(subs, meta, styles, line)
    if not karaskel or type(karaskel.preproc_line) ~= "function" then
        return false
    end

    local ok = pcall(karaskel.preproc_line, subs, meta, styles, line)
    return ok
end

function HWF.run(subs, sel)
    sel = sel or {}
    if #sel == 0 then
        show_message(script_name, "Selecciona una o mas lineas karaoke.")
        return
    end

    if not karaskel or type(karaskel.collect_head) ~= "function" then
        show_message(script_name, "No se pudo cargar karaskel. Revisa la instalacion de Aegisub.")
        return
    end

    local options = build_options(subs, sel)

    local ok_head, meta, styles = pcall(karaskel.collect_head, subs, false)
    if not ok_head then
        show_message(script_name, "No se pudo leer la informacion de estilos del subtitulo.")
        return
    end

    local targets = {}
    for _, idx in ipairs(sel) do targets[#targets + 1] = idx end
    table.sort(targets, function(a, b) return a > b end)

    local changed = 0
    local skipped = 0
    local errors = {}
    local plans = {}
    local cancelled = false

    for n, idx in ipairs(targets) do
        if aegisub and aegisub.progress then
            aegisub.progress.set(n / #targets * 100)
            aegisub.progress.task(script_name .. ": linea " .. tostring(n) .. "/" .. tostring(#targets))
            if aegisub.progress.is_cancelled and aegisub.progress.is_cancelled() then
                cancelled = true
                break
            end
        end

        local line = subs[idx]
        if not is_dialogue(line) then
            skipped = skipped + 1
        else
            local source = copy_line(line)
            local ok_pre = preprocess_line(subs, meta, styles, source)
            if not ok_pre then
                errors[#errors + 1] = "Linea " .. tostring(idx) .. ": no se pudo preparar la linea karaoke."
                skipped = skipped + 1
            else
                local ok_generate, generated = pcall(HWF.generate_from_preprocessed_line, source, source.styleref, options)
                if not ok_generate then
                    errors[#errors + 1] = "Linea " .. tostring(idx) .. ": no se pudo generar el efecto."
                    skipped = skipped + 1
                elseif #generated == 0 then
                    skipped = skipped + 1
                else
                    plans[#plans + 1] = { index = idx, lines = generated }
                end
            end
        end
    end

    if cancelled then return end

    for _, plan in ipairs(plans) do
        subs.delete(plan.index)
        for i = #plan.lines, 1, -1 do
            subs.insert(plan.index, plan.lines[i])
        end
    end
    changed = #plans

    if changed > 0 and aegisub and aegisub.set_undo_point then
        aegisub.set_undo_point(script_name)
    end

    if #errors > 0 then
        show_message(script_name, table.concat(errors, "\n"))
    elseif changed == 0 then
        show_message(script_name, "No se genero nada. Verifica que la seleccion tenga silabas \\k con duracion.")
    elseif skipped > 0 then
        show_message(script_name, "Lineas procesadas: " .. tostring(changed) .. "\nOmitidas: " .. tostring(skipped))
    end
end

if aegisub and aegisub.register_macro then
    local hotkey_path = HOTKEY_MENU_ROOT .. "/" .. HOTKEY_MENU_SCRIPT .. "/Execute"
    if depctrl and depctrl.registerMacro then
        depctrl:registerMacro(script_name, script_description, HWF.run, nil, nil, false)
        depctrl:registerMacro(hotkey_path, "Hotkey action. " .. script_description, HWF.run, nil, nil, false)
    else
        aegisub.register_macro(script_name, script_description, HWF.run)
        aegisub.register_macro(hotkey_path, "Hotkey action. " .. script_description, HWF.run)
    end
end
