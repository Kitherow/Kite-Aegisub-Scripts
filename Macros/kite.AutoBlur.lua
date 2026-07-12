script_name = "Auto Blur"
script_description = "Match a sign's \\blur to frame sharpness with fixed or tracked sample points and time-varying blur curves."
script_author = "Kiterow"
script_version = "2.0.3"
script_namespace = "kite.AutoBlur"
local HOTKEY_MENU_ROOT = ": Kite Hotkeys :"
local HOTKEY_MENU_SCRIPT = script_name

local function safeRequire(m)
    local ok, mod = pcall(require, m)
    if ok then return mod end
    return nil
end

local function safeInclude(path)
    if type(include) == "function" then pcall(include, path) end
end

local DependencyControl = safeRequire("l0.DependencyControl")
local depctrl
if DependencyControl then
    local okRecord, record = pcall(DependencyControl, {
        name = script_name,
        description = script_description,
        author = script_author,
        version = script_version,
        namespace = script_namespace,
        feed = "https://raw.githubusercontent.com/Kitherow/Kite-Aegisub-Scripts/main/DependencyControl.json",
        {
            { "kite.UI", version = "1.0.0", url = "https://github.com/Kitherow/Kite-Aegisub-Scripts",
              feed = "https://raw.githubusercontent.com/Kitherow/Kite-Aegisub-Scripts/main/DependencyControl.json" },
        },
    })
    if okRecord then depctrl = record end
end

local KiteUI
if depctrl and depctrl.requireModules then
    local ok, module = pcall(function() return depctrl:requireModules() end)
    if ok then KiteUI = module end
end
KiteUI = KiteUI or safeRequire("kite.UI")

local DataWrapper = safeRequire("a-mo.DataWrapper")
local clipboard = safeRequire("aegisub.clipboard")
safeInclude("karaskel.lua")

local AUTO_SETTINGS = KiteUI.settings(script_namespace, script_version, {
    main = {
        radius = 8,
        max_blur = 5.0,
        curve = 0.5,
        quant_step = 0.25,
        smooth = 5,
        min_run = 3,
        trans_ms = 0,
        mode = "Discrete (RLE transitions)",
        use_tracking = false,
        remove_existing = true,
    },
}, {})

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function extractRGB(color)
    if type(color) ~= "string" then return 0, 0, 0 end
    color = color:gsub("%s+", "")
    local b, g, r = color:match("&[Hh](%x%x)(%x%x)(%x%x)&?")
    if b then return tonumber(r, 16), tonumber(g, 16), tonumber(b, 16) end
    r, g, b = color:match("#?(%x%x)(%x%x)(%x%x)")
    if r then return tonumber(r, 16), tonumber(g, 16), tonumber(b, 16) end
    r, g, b = color:match("(%d+),(%d+),(%d+)")
    if r then
        return clamp(tonumber(r) or 0, 0, 255),
               clamp(tonumber(g) or 0, 0, 255),
               clamp(tonumber(b) or 0, 0, 255)
    end
    return 0, 0, 0
end

local function lum(r, g, b)
    return 0.299 * r + 0.587 * g + 0.114 * b
end

local function formatBlurValue(v)
    if math.abs(v - math.floor(v + 0.5)) < 1e-6 then
        return string.format("%d", math.floor(v + 0.5))
    end
    local s = string.format("%.2f", v)
    s = s:gsub("0+$", "")
    s = s:gsub("%.$", "")
    return s
end

local function samplePatchLuminance(frame, cx, cy, radius, vw, vh)
    local L = {}
    cx = math.floor(cx + 0.5)
    cy = math.floor(cy + 0.5)
    for dy = -radius, radius do
        local row = {}
        for dx = -radius, radius do
            local x = clamp(cx + dx, 0, vw - 1)
            local y = clamp(cy + dy, 0, vh - 1)
            local ok, color = pcall(function() return frame:getPixelFormatted(x, y) end)
            if not ok or not color then
                row[#row + 1] = 128
            else
                local r, g, b = extractRGB(color)
                row[#row + 1] = lum(r, g, b)
            end
        end
        L[#L + 1] = row
    end
    return L
end

local function laplacianVariance(L)
    local rows = #L
    if rows < 3 then return 0 end
    local cols = #L[1]
    if cols < 3 then return 0 end
    local laps = {}
    for y = 2, rows - 1 do
        for x = 2, cols - 1 do
            local c = L[y][x]
            laps[#laps + 1] = 4 * c - L[y - 1][x] - L[y + 1][x] - L[y][x - 1] - L[y][x + 1]
        end
    end
    local n = #laps
    if n == 0 then return 0 end
    local mean = 0
    for _, v in ipairs(laps) do mean = mean + v end
    mean = mean / n
    local var = 0
    for _, v in ipairs(laps) do
        local d = v - mean
        var = var + d * d
    end
    return var / n
end

local function robustMean(values)
    local n = #values
    if n == 0 then return 0 end
    local sorted = {}
    for i, v in ipairs(values) do sorted[i] = v end
    table.sort(sorted)
    local first, last = 1, n
    if n >= 5 then
        first = 2
        last = n - 1
    end
    local sum, count = 0, 0
    for i = first, last do
        sum = sum + sorted[i]
        count = count + 1
    end
    return sum / math.max(1, count)
end

local SAMPLE_OFFSETS = {
    {0, 0},
    {1, 0},
    {-1, 0},
    {0, 1},
    {0, -1},
}

local function sampleSharpness(frame, cx, cy, radius, vw, vh)
    local scores = {}
    local spread = math.max(1, radius * 0.75)
    for _, offset in ipairs(SAMPLE_OFFSETS) do
        local L = samplePatchLuminance(frame, cx + offset[1] * spread, cy + offset[2] * spread, radius, vw, vh)
        scores[#scores + 1] = laplacianVariance(L)
    end
    return robustMean(scores)
end

local function percentile(arr, p)
    local values = {}
    for _, v in ipairs(arr) do
        if type(v) == "number" and v == v then
            values[#values + 1] = v
        end
    end
    local n = #values
    if n == 0 then return 0 end
    table.sort(values)
    if n == 1 then return values[1] end
    local pos = 1 + (n - 1) * clamp(p, 0, 1)
    local lo = math.floor(pos)
    local hi = math.ceil(pos)
    if lo == hi then return values[lo] end
    local t = pos - lo
    return values[lo] * (1 - t) + values[hi] * t
end

local function robustReference(arr)
    local ref = percentile(arr, 0.95)
    if ref > 0 then return ref end
    for _, v in ipairs(arr) do
        if v > ref then ref = v end
    end
    return ref
end

local function blurFromVarianceRelative(v, ref, max_blur, curve)
    if ref <= 0 then return 0 end
    local ratio = clamp(v / ref, 0, 1)
    return max_blur * (1 - math.pow(ratio, curve))
end

local function smoothMovingAverage(arr, window)
    if window <= 1 then return arr end
    local n = #arr
    local out = {}
    local half = math.floor(window / 2)
    for i = 1, n do
        local sum, count = 0, 0
        for j = math.max(1, i - half), math.min(n, i + half) do
            sum = sum + arr[j]
            count = count + 1
        end
        out[i] = sum / count
    end
    return out
end

local function quantize(arr, ref, max_blur, curve, quantStep)
    local out = {}
    for i, v in ipairs(arr) do
        local raw = blurFromVarianceRelative(v, ref, max_blur, curve)
        if quantStep and quantStep > 0 then
            raw = math.floor(raw / quantStep + 0.5) * quantStep
        end
        out[i] = raw
    end
    return out
end

local function suppressShortRuns(arr, minRunLen)
    if minRunLen <= 1 then return arr end
    local out = {}
    for i = 1, #arr do out[i] = arr[i] end
    local i = 1
    while i <= #out do
        local v = out[i]
        local j = i
        while j <= #out and out[j] == v do j = j + 1 end
        local runLen = j - i
        if runLen < minRunLen then
            local replacement = nil
            if i > 1 then
                replacement = out[i - 1]
            elseif j <= #out then
                replacement = out[j]
            end
            if replacement ~= nil then
                for k = i, j - 1 do out[k] = replacement end
            end
        end
        i = j
    end
    return out
end

local function findRuns(arr)
    local runs = {}
    if #arr == 0 then return runs end
    local cur = arr[1]
    local startIdx = 1
    for i = 2, #arr do
        if arr[i] ~= cur then
            runs[#runs + 1] = {startIdx = startIdx, endIdx = i - 1, value = cur}
            cur = arr[i]
            startIdx = i
        end
    end
    runs[#runs + 1] = {startIdx = startIdx, endIdx = #arr, value = cur}
    return runs
end

local function buildDiscreteTransform(runs, lineStartFrame, lineStartMs, transitionMs)
    if #runs == 0 then return "" end
    local out = "\\blur" .. formatBlurValue(runs[1].value)
    for k = 2, #runs do
        local r = runs[k]
        local frameMs = aegisub.ms_from_frame(lineStartFrame + r.startIdx - 1) - lineStartMs
        local half = math.floor(transitionMs / 2)
        local t1 = math.max(0, frameMs - half)
        local t2 = t1 + math.max(1, transitionMs)
        out = out .. string.format("\\t(%d,%d,\\blur%s)", t1, t2, formatBlurValue(r.value))
    end
    return out
end

local function buildContinuousTransform(quantized, lineStartFrame, lineStartMs, transitionMs)
    if #quantized == 0 then return "" end
    local out = "\\blur" .. formatBlurValue(quantized[1])
    local prev = quantized[1]
    for i = 2, #quantized do
        local b = quantized[i]
        if b ~= prev then
            local frameMs = aegisub.ms_from_frame(lineStartFrame + i - 1) - lineStartMs
            local half = math.floor(transitionMs / 2)
            local t1 = math.max(0, frameMs - half)
            local t2 = t1 + math.max(1, transitionMs)
            out = out .. string.format("\\t(%d,%d,\\blur%s)", t1, t2, formatBlurValue(b))
            prev = b
        end
    end
    return out
end

local function stripBlurTransforms(block)
    local out = {}
    local i = 1
    while i <= #block do
        if block:sub(i, i + 2) == "\\t(" then
            local depth = 0
            local j = i + 2
            while j <= #block do
                local ch = block:sub(j, j)
                if ch == "(" then
                    depth = depth + 1
                elseif ch == ")" then
                    depth = depth - 1
                    if depth == 0 then break end
                end
                j = j + 1
            end
            if depth == 0 then
                local chunk = block:sub(i, j)
                if not chunk:find("\\blur", 1, true) and not chunk:find("\\be", 1, true) then
                    out[#out + 1] = chunk
                end
                i = j + 1
            else
                out[#out + 1] = block:sub(i, i)
                i = i + 1
            end
        else
            out[#out + 1] = block:sub(i, i)
            i = i + 1
        end
    end
    return table.concat(out)
end

local function stripBlurFromFirstBlock(text)
    local fs, fe = text:find("^{[^}]*}")
    if not fs then return text end
    local first = text:sub(fs, fe)
    first = stripBlurTransforms(first)
    first = first:gsub("\\blur%-?[%d%.]+", "")
    first = first:gsub("\\be%-?[%d%.]+", "")
    if first:match("^%{%s*%}$") then
        return text:sub(1, fs - 1) .. text:sub(fe + 1)
    end
    return text:sub(1, fs - 1) .. first .. text:sub(fe + 1)
end

local function injectTransform(text, transform)
    if transform == "" then return text end
    local fs = text:find("^{[^}]*}")
    if fs then
        return text:sub(1, fs) .. transform .. text:sub(fs + 1)
    end
    return "{" .. transform .. "}" .. text
end

local function getPlayRes(subs)
    if karaskel and type(karaskel.collect_head) == "function" then
        local ok, meta = pcall(karaskel.collect_head, subs, false)
        if ok and meta and meta.res_x and meta.res_y then
            return tonumber(meta.res_x), tonumber(meta.res_y)
        end
    end
    return nil, nil
end

local function getVideoSize()
    local vw, vh
    if aegisub.video_size then
        local ok, w, h = pcall(aegisub.video_size)
        if ok and w and h then return w, h end
    end
    local props = aegisub.project_properties() or {}
    vw = props.video_width or 1920
    vh = props.video_height or 1080
    return vw, vh
end

local function parseMoveAtTime(text, relMs, durationMs)
    local x1, y1, x2, y2, t1, t2 = text:match("\\move%(%s*([%-%d%.]+)%s*,%s*([%-%d%.]+)%s*,%s*([%-%d%.]+)%s*,%s*([%-%d%.]+)%s*,%s*([%-%d%.]+)%s*,%s*([%-%d%.]+)%s*%)")
    if not x1 then
        x1, y1, x2, y2 = text:match("\\move%(%s*([%-%d%.]+)%s*,%s*([%-%d%.]+)%s*,%s*([%-%d%.]+)%s*,%s*([%-%d%.]+)%s*%)")
        t1, t2 = 0, durationMs
    end
    if not x1 then return nil, nil end
    x1, y1, x2, y2 = tonumber(x1), tonumber(y1), tonumber(x2), tonumber(y2)
    t1, t2 = tonumber(t1) or 0, tonumber(t2) or durationMs
    if not x1 or not y1 or not x2 or not y2 then return nil, nil end
    if t2 <= t1 then return x2, y2 end
    local p = clamp((relMs - t1) / (t2 - t1), 0, 1)
    return x1 + (x2 - x1) * p, y1 + (y2 - y1) * p
end

local function autoDetectCoord(line, currentMs)
    local x, y = line.text:match("\\i?clip%(m%s+([%-%d%.]+)%s+([%-%d%.]+)%s*%)")
    if x then return x, y end
    x, y = line.text:match("\\pos%(%s*([%-%d%.]+)%s*,%s*([%-%d%.]+)%s*%)")
    if x then return x, y end
    x, y = parseMoveAtTime(line.text, currentMs - line.start_time, line.end_time - line.start_time)
    if x then return x, y end
    if clipboard and clipboard.get then
        local ok, data = pcall(clipboard.get)
        if ok and type(data) == "string" then
            x, y = data:match("([%-%d%.]+),([%-%d%.]+)")
            if x then return x, y end
        end
    end
    return nil, nil
end

local function readClipboardData()
    if not (clipboard and clipboard.get) then return "" end
    local ok, data = pcall(clipboard.get)
    if ok and type(data) == "string" then return data end
    return ""
end

local function showDialog(initialCoord, initialData, defaults)
    defaults = defaults or {}
    local dlg = {
        {class = "label", x = 0, y = 0, width = 9, height = 1,
         label = "AUTO BLUR"},

        {class = "label", x = 0, y = 1, width = 9,
         label = "BG sample point  x,y  (auto-filled from \\clip pin, \\pos, \\move, or clipboard):"},
        {class = "edit", name = "coord", x = 0, y = 2, width = 9, value = initialCoord or ""},

        {class = "label", x = 0, y = 3, width = 9,
         label = "Tracking data  (paste AE Position export - optional):"},
        {class = "textbox", name = "data", x = 0, y = 4, width = 9, height = 4,
         value = initialData or ""},

        {class = "label", x = 0, y = 8, width = 3, label = "Patch radius (px):"},
        {class = "intedit", name = "radius", x = 3, y = 8, width = 2,
         value = defaults.radius or 8, min = 2, max = 32},
        {class = "label", x = 5, y = 8, width = 2, label = "Max blur:"},
        {class = "floatedit", name = "max_blur", x = 7, y = 8, width = 2,
         value = defaults.max_blur or 5.0, min = 0.5, max = 20},

        {class = "label", x = 0, y = 9, width = 3, label = "Curve exponent:"},
        {class = "floatedit", name = "curve", x = 3, y = 9, width = 2,
         value = defaults.curve or 0.5, min = 0.1, max = 5.0},
        {class = "label", x = 5, y = 9, width = 2, label = "Quant step:"},
        {class = "floatedit", name = "quant_step", x = 7, y = 9, width = 2,
         value = defaults.quant_step or 0.25, min = 0, max = 2.0},

        {class = "label", x = 0, y = 10, width = 3, label = "Smooth window (frames):"},
        {class = "intedit", name = "smooth", x = 3, y = 10, width = 2,
         value = defaults.smooth or 5, min = 1, max = 31},
        {class = "label", x = 5, y = 10, width = 2, label = "Min run (frames):"},
        {class = "intedit", name = "min_run", x = 7, y = 10, width = 2,
         value = defaults.min_run or 3, min = 1, max = 60},

        {class = "label", x = 0, y = 11, width = 3, label = "Transition (ms):"},
        {class = "intedit", name = "trans_ms", x = 3, y = 11, width = 2,
         value = defaults.trans_ms or 0, min = 0, max = 2000},
        {class = "label", x = 5, y = 11, width = 4,
         label = "0 = step / e.g. 80 = soft fade between levels"},

        {class = "label", x = 0, y = 12, width = 2, label = "Mode:"},
        {class = "dropdown", name = "mode", x = 2, y = 12, width = 7,
         items = {"Discrete (RLE transitions)", "Continuous (per-frame \\t)"},
         value = defaults.mode or "Discrete (RLE transitions)"},

        {class = "checkbox", name = "use_tracking", x = 0, y = 13, width = 9,
         label = "Use tracking data (off = sample stays at the fixed coord above)",
         value = defaults.use_tracking or false},
        {class = "checkbox", name = "remove_existing", x = 0, y = 14, width = 9,
         label = "Strip existing \\blur / \\be / \\t(blur) from first tag block before applying",
         value = defaults.remove_existing ~= false},
    }
    return aegisub.dialog.display(dlg, {"Execute", "Cancel"}, {ok = "Execute", cancel = "Cancel"})
end

local function showError(msg)
    aegisub.dialog.display({{class = "label", label = msg}}, {"OK"})
end

local function main(subs, sel)
    if not aegisub.get_frame then
        showError("Need an Aegisub fork with aegisub.get_frame.")
        return
    end
    local props = aegisub.project_properties() or {}
    if not props.video_file or props.video_file == "" then
        showError("No video open.")
        return
    end
    if #sel ~= 1 then
        showError("Select exactly one line.")
        return
    end

    local line = subs[sel[1]]
    local startFrame = aegisub.frame_from_ms(line.start_time)
    local endFrame = aegisub.frame_from_ms(line.end_time)
    if endFrame <= startFrame then
        showError("Line has zero or negative duration.")
        return
    end
    local currentFrame = props.video_position or startFrame
    if currentFrame < startFrame or currentFrame >= endFrame then
        showError("Move the video playhead inside the line first.\n(The current frame is the reference for tracking offsets and the BG color.)")
        return
    end

    local currentMs = aegisub.ms_from_frame(currentFrame)
    local autoX, autoY = autoDetectCoord(line, currentMs)
    local initialCoord = (autoX and (autoX .. "," .. autoY)) or ""
    local clipboardData = readClipboardData()
    if not clipboardData:find("\n") then clipboardData = "" end

    local btn, res = showDialog(initialCoord, clipboardData, AUTO_SETTINGS:values("main"))
    if btn ~= "Execute" then return end
    local cx, cy = res.coord:match("([%-%d%.]+),([%-%d%.]+)")
    if not cx then
        showError("Invalid coordinate. Format: x,y (e.g. 960,540).")
        return
    end
    cx, cy = tonumber(cx), tonumber(cy)
    if not cx or not cy then
        showError("Coordinate parse error.")
        return
    end

    local numFrames = endFrame - startFrame
    if numFrames < 1 then
        showError("Not enough frames.")
        return
    end

    local positions = {x = {}, y = {}}
    if res.use_tracking and res.data and res.data ~= "" then
        if not DataWrapper then
            showError("a-mo.DataWrapper not installed; cannot parse tracking data.\nInstall Aegisub-Motion or disable 'Use tracking data'.")
            return
        end
        local prx, pry = getPlayRes(subs)
        local tdata = DataWrapper()
        local ok = tdata:bestEffortParsingAttempt(res.data, prx or 1920, pry or 1080)
        if not ok then
            showError("Could not parse tracking data. Expected After Effects Position export.")
            return
        end
        if not tdata.dataObject:checkLength(numFrames) then
            showError(string.format(
                "Tracking data length (%d frames) doesn't match line length (%d frames).",
                tdata.dataObject.length, numFrames))
            return
        end
        tdata.dataObject:addReferenceFrame(currentFrame - startFrame + 1)
        local d = tdata.dataObject
        for i = 1, numFrames do
            positions.x[i] = cx + (d.xPosition[i] - d.xStartPosition)
            positions.y[i] = cy + (d.yPosition[i] - d.yStartPosition)
        end
    else
        for i = 1, numFrames do
            positions.x[i] = cx
            positions.y[i] = cy
        end
    end

    local vw, vh = getVideoSize()
    local prx, pry = getPlayRes(subs)
    local sx = (prx and prx > 0) and (vw / prx) or 1
    local sy = (pry and pry > 0) and (vh / pry) or 1

    local radius = math.max(2, math.floor(tonumber(res.radius) or 8))
    local variances = {}
    aegisub.progress.task("AutoBlur: sampling frames")
    for i = 1, numFrames do
        if aegisub.progress.is_cancelled and aegisub.progress.is_cancelled() then
            return
        end
        local f = startFrame + i - 1
        local ok, frame = pcall(aegisub.get_frame, f, false)
        if ok and frame then
            local px = positions.x[i] * sx
            local py = positions.y[i] * sy
            variances[i] = sampleSharpness(frame, px, py, radius, vw, vh)
        else
            variances[i] = variances[i - 1] or 0
        end
        aegisub.progress.set((i / numFrames) * 100)
    end
    aegisub.progress.task("AutoBlur: building transforms")

    local smoothWindow = math.max(1, math.floor(tonumber(res.smooth) or 5))
    local smoothed = smoothMovingAverage(variances, smoothWindow)
    local ref = robustReference(smoothed)
    if ref <= 0 then
        showError("All sampled frames returned zero variance.\nCheck the sample coordinate / patch radius.")
        return
    end
    aegisub.log("AutoBlur: reference variance = %.2f\n", ref)

    local maxBlur = math.max(0, tonumber(res.max_blur) or 5.0)
    local curve = math.max(0.01, tonumber(res.curve) or 0.5)
    local quantStep = math.max(0, tonumber(res.quant_step) or 0.25)
    local transitionMs = math.max(0, math.floor(tonumber(res.trans_ms) or 0))
    local quantized = quantize(smoothed, ref, maxBlur, curve, quantStep)

    local transform
    if res.mode and res.mode:find("Continuous") then
        transform = buildContinuousTransform(quantized, startFrame, line.start_time, transitionMs)
    else
        local minRun = math.max(1, math.floor(tonumber(res.min_run) or 3))
        local cleaned = suppressShortRuns(quantized, minRun)
        local runs = findRuns(cleaned)
        transform = buildDiscreteTransform(runs, startFrame, line.start_time, transitionMs)
    end

    local newText = res.remove_existing and stripBlurFromFirstBlock(line.text) or line.text
    line.text = injectTransform(newText, transform)
    subs[sel[1]] = line
    AUTO_SETTINGS:update("main", res)
    AUTO_SETTINGS:write()
    aegisub.set_undo_point(script_name)
end

local function canRun(subs, sel)
    return sel and #sel == 1
end

if aegisub and aegisub.register_macro then
    local hotkey_path = HOTKEY_MENU_ROOT .. "/" .. HOTKEY_MENU_SCRIPT .. "/Execute"
    if depctrl and depctrl.registerMacro then
        depctrl:registerMacro(script_name, script_description, main, canRun, nil, false)
        depctrl:registerMacro(hotkey_path, "Hotkey action. " .. script_description, main, canRun, nil, false)
    else
        aegisub.register_macro(script_name, script_description, main, canRun)
        aegisub.register_macro(hotkey_path, "Hotkey action. " .. script_description, main, canRun)
    end
end
