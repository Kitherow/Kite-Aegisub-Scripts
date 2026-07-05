local function tryRequire(m) local ok, r = pcall(require, m); if ok then return r end end
local DependencyControl = tryRequire("l0.DependencyControl")
local depctrl
if DependencyControl then
    depctrl = DependencyControl({
        name = "Timing",
        version = "1.0.1",
        description = "Voice-timing engines: multi-signal/waveform onset detection and legacy silence timing",
        author = "Kiterow",
        url = "https://github.com/Kitherow/Kite-Aegisub-Scripts",
        moduleName = "kite.Timing",
        feed = "https://raw.githubusercontent.com/Kitherow/Kite-Aegisub-Scripts/main/DependencyControl.json",
    })
end

local TUNE = {
    vote_fraction = 0.5,     
    w_vad = 1.0,             
    w_sil30 = 0.9,           
    w_sil40 = 0.85,
    w_sil50 = 0.6,           
    w_flux = 0.7,            
    min_voice_run_ms = 50,   
    bridge_gap_ms = 320,     
    max_pause_ms = 900,      
    tiny_span_ms = 120,      
    flux_start_ms = 160,     
    flux_end_ms = 200,       
    spread_search_ms = 450,  
    spread_flag_ms = 350,    
    min_voice_ms = 80,       
    stack_eps_ms = 40,       
    keep_min_out_ms = 200,   
    flash_gap_ms = 250,      
    cap_grace_ms = 120,      
    frame_grace_ms = 45,     
    orig_end_cut_ms = 150,   
                             
    
    max_sane_cps = 40,       
    relax_vote = 0.38,       
    relax_bridge_ms = 480,   
    relax_tiny_ms = 60,      
    relax_pause_ms = 1200,   
    relax_run_ms = 30,       
    
    onset_soft_ms = 140,     
    loud_tail_ms = 300,      
    tail_keep_ms = 80,       
    
    w_env = 1.0,
    env_refine_ms = 220,     
    env_min_range_db = 6,    
    env_thr_frac = 0.35,     
}
local function trim(s)
    return (tostring(s or ""):match("^%s*(.-)%s*$")) or ""
end

local function round(x)
    x = tonumber(x) or 0
    if x >= 0 then return math.floor(x + 0.5) end
    return math.ceil(x - 0.5)
end

local function clamp(x, lo, hi)
    if x < lo then return lo end
    if x > hi then return hi end
    return x
end

local function lower_bound(list, value)
    local lo, hi = 1, #list + 1
    while lo < hi do
        local mid = math.floor((lo + hi) / 2)
        if list[mid] < value then lo = mid + 1 else hi = mid end
    end
    return lo
end

local function overlap_len(a0, a1, b0, b1)
    return math.min(a1, b1) - math.max(a0, b0)
end

local function progress(task, pct)
    if aegisub and aegisub.progress then
        if task and aegisub.progress.task then pcall(aegisub.progress.task, task) end
        if pct and aegisub.progress.set then pcall(aegisub.progress.set, pct) end
    end
end

local PATH_KEYS = { "sil30", "sil40", "sil50", "vad", "flux", "env", "keyframes" }
local IS_WINDOWS = package.config:sub(1, 1) == "\\"

local function script_dir_and_base()
    local dir, name
    if aegisub and aegisub.decode_path then
        local ok, d = pcall(aegisub.decode_path, "?script")
        if ok and d and d ~= "" and not d:find("?script", 1, true) then dir = d end
    end
    if aegisub and aegisub.file_name then
        local ok, n = pcall(aegisub.file_name)
        if ok and n and n ~= "" then name = n end
    end
    local base = name and name:gsub("%.[^%.]+$", "") or nil
    return dir, base, name
end

local function list_dir(dir)
    if not dir then return {} end
    local cmd
    if IS_WINDOWS then cmd = 'dir /b "' .. dir .. '"'
    else cmd = 'ls -1 "' .. dir .. '"' end
    local ok, p = pcall(io.popen, cmd)
    if not ok or not p then return {} end
    local out = {}
    for line in p:lines() do
        line = trim(line)
        if line ~= "" then out[#out + 1] = line end
    end
    p:close()
    return out
end

local function classify_data_file(name)
    local n = tostring(name or ""):lower()
    if not (n:match("%.txt$") or n:match("%.log$") or n:match("%.tsv$") or n:match("%.csv$")) then return nil end
    if n:find("key", 1, true) or n:find("kf", 1, true) or n:find("scene", 1, true) then return "keyframes" end
    if n:find("vad", 1, true) then return "vad" end
    if n:find("flux", 1, true) or n:find("onset", 1, true) then return "flux" end
    if n:find("env", 1, true) or n:find("rms", 1, true) or n:find("loud", 1, true) then return "env" end
    if n:find("sil", 1, true) or n:find("silence", 1, true) or n:find("retime", 1, true) then
        if n:find("30", 1, true) then return "sil30" end
        if n:find("40", 1, true) then return "sil40" end
        if n:find("50", 1, true) then return "sil50" end
        return "sil30"
    end
    local th = n:match("[_%-]([345]0)%.%w+$")
    if th then return "sil" .. th end
    return nil
end

local function chapter_of(name)
    local digits = tostring(name or ""):match("^(%d+)")
    if digits then return tonumber(digits) end
    return nil
end

local function discover_paths(paths)
    local dir, base = script_dir_and_base()
    if not dir then return paths end
    local sep = IS_WINDOWS and "\\" or "/"
    local subs_ch = base and tonumber(base:match("(%d+)")) or nil
    local best = {}
    for _, fname in ipairs(list_dir(dir)) do
        local slot = classify_data_file(fname)
        if slot and (paths[slot] == nil or paths[slot] == "") then
            local score = 1
            if base and fname:lower():find(base:lower(), 1, true) then score = score + 2 end
            if subs_ch and chapter_of(fname) == subs_ch then score = score + 3 end
            if not best[slot] or score > best[slot].score then
                best[slot] = { name = fname, score = score }
            end
        end
    end
    for slot, rec in pairs(best) do
        paths[slot] = dir .. sep .. rec.name
    end
    return paths
end
local function visible_text(text)
    local s = tostring(text or "")
    s = s:gsub("{[^}]*}", "")
    s = s:gsub("\\[Nn]", " ")
    s = s:gsub("\\h", " ")
    return trim(s)
end

local function utf8_len(s)
    s = tostring(s or "")
    local _, continuation = s:gsub("[\128-\191]", "")
    return #s - continuation
end

local function readable_chars(text)
    local clean = visible_text(text)
    clean = clean:gsub("[%s%p]", "")
    clean = clean:gsub("\194\191", ""):gsub("\194\161", ""):gsub("\226\128\166", "")
    return utf8_len(clean)
end

local function style_ok(style, flt, extra)
    flt = tostring(flt or "All")
    if flt == "" or flt == "All" then return true end
    style = tostring(style or "")
    local extra_hit = extra ~= nil and extra ~= "" and style == extra
    if flt == "All Default" then return style:find("Defa", 1, true) ~= nil or extra_hit end
    if flt == "Default+Alt" then
        return style:find("Defa", 1, true) ~= nil or style:find("Alt", 1, true) ~= nil or extra_hit
    end
    return style == flt or extra_hit
end

local function is_spoken(line, cfg)
    if not line or line.comment then return false end
    local raw = tostring(line.text or "")
    if raw:find("\\p%d") then return false end 
    if visible_text(raw) == "" then return false end
    local effect = tostring(line.effect or ""):lower()
    if effect:find("template", 1, true) or effect:find("karaoke", 1, true) or effect:find("code", 1, true) then return false end
    if cfg.skip_signs then
        local style = tostring(line.style or ""):lower()
        if style:find("sign", 1, true) or style:find("kara", 1, true) or style:find("fx", 1, true) then return false end
    end
    if not style_ok(line.style, cfg.style_filter, cfg.extra_style) then return false end
    return true
end

local function split_fields(line)
    local fields = {}
    line = tostring(line or "")
    if line:find("\t", 1, true) then
        for f in line:gmatch("[^\t]+") do fields[#fields + 1] = trim(f) end
    elseif line:find(",", 1, true) then
        for f in line:gmatch("[^,]+") do fields[#fields + 1] = trim(f) end
    else
        for f in line:gmatch("%S+") do fields[#fields + 1] = trim(f) end
    end
    return fields
end

local function detect_time_scale(header, values)
    header = tostring(header or ""):lower()
    if header:find("ms", 1, true) or header:find("millisecond", 1, true) then return 1 end
    if header:find("sec", 1, true) or header:find("time_s", 1, true) then return 1000 end
    local max_abs, n, fractional = 0, 0, false
    for _, v in ipairs(values) do
        local x = tonumber(v)
        if x then
            n = n + 1
            max_abs = math.max(max_abs, math.abs(x))
            if x ~= math.floor(x) then fractional = true end
        end
    end
    if fractional then return 1000 end
    if n >= 4 then return 1 end
    if max_abs > 100000 then return 1 end
    return 1000
end

local function merge_intervals(list)
    table.sort(list, function(a, b) return a.b < b.b end)
    local out = {}
    for _, iv in ipairs(list) do
        if iv.e > iv.b then
            local last = out[#out]
            if last and iv.b <= last.e then
                if iv.e > last.e then last.e = iv.e end
            else
                out[#out + 1] = { b = iv.b, e = iv.e }
            end
        end
    end
    return out
end

local function parse_interval_rows(path)
    local rows, nums, header = {}, {}, nil
    local f = io.open(path, "r")
    if not f then return rows end
    local first = true
    for line in f:lines() do
        local fields = split_fields(line)
        local s, e = tonumber(fields[1]), tonumber(fields[2])
        if first then
            first = false
            header = line
            if s and e then rows[#rows + 1] = { b = s, e = e }; nums[#nums + 1] = s; nums[#nums + 1] = e end
        elseif s and e and e > s then
            rows[#rows + 1] = { b = s, e = e }; nums[#nums + 1] = s; nums[#nums + 1] = e
        end
    end
    f:close()
    local scale = detect_time_scale(header, nums)
    for _, r in ipairs(rows) do r.b = r.b * scale; r.e = r.e * scale end
    return merge_intervals(rows)
end

local function parse_silence_file(path)
    if not path or path == "" then return {} end
    local out = {}
    local f = io.open(path, "r")
    if not f then return out end
    local cur = nil
    for line in f:lines() do
        local ss = line:match("silence_start:%s*(-?[%d%.]+)")
        if ss then cur = tonumber(ss) and tonumber(ss) * 1000 or nil end
        local se = line:match("silence_end:%s*(-?[%d%.]+)")
        if se and cur then
            local e = tonumber(se) * 1000
            if e > cur then out[#out + 1] = { b = cur, e = e } end
            cur = nil
        end
    end
    f:close()
    if #out == 0 then
        
        return parse_interval_rows(path)
    end
    return merge_intervals(out)
end

local function parse_vad_file(path)
    if not path or path == "" then return {} end
    return parse_interval_rows(path)
end

local function parse_flux_file(path)
    local on, off = {}, {}
    if not path or path == "" then return on, off end
    local rows, nums, header = {}, {}, nil
    local f = io.open(path, "r")
    if not f then return on, off end
    local first = true
    for line in f:lines() do
        local fields = split_fields(line)
        local t = tonumber(fields[1])
        if first then
            first = false
            header = line
        end
        if t then
            rows[#rows + 1] = { t = t, kind = tostring(fields[2] or "onset"):lower() }
            nums[#nums + 1] = t
        end
    end
    f:close()
    local scale = detect_time_scale(header, nums)
    for _, r in ipairs(rows) do
        local t = r.t * scale
        if r.kind == "offset" or r.kind == "end" then off[#off + 1] = t else on[#on + 1] = t end
    end
    table.sort(on); table.sort(off)
    return on, off
end

local function parse_env_file(path)
    if not path or path == "" then return nil end
    local f = io.open(path, "r")
    if not f then return nil end
    local rows, nums, header, first = {}, {}, nil, true
    for line in f:lines() do
        local fields = split_fields(line)
        local t, v = tonumber(fields[1]), tonumber(fields[2])
        if first then first = false; header = line end
        if t and v then
            rows[#rows + 1] = { t = t, v = v }
            nums[#nums + 1] = t
        end
    end
    f:close()
    if #rows < 8 then return nil end
    local scale = detect_time_scale(header, nums)
    table.sort(rows, function(x, y) return x.t < y.t end)
    local ts, vs = {}, {}
    for i, r in ipairs(rows) do ts[i] = r.t * scale; vs[i] = r.v end
    return { t = ts, v = vs }
end

local function env_window(env, w0, w1)
    local i0 = lower_bound(env.t, w0)
    local i1 = lower_bound(env.t, w1) - 1
    return i0, i1
end

local function env_threshold(env, i0, i1)
    if i1 - i0 < 7 then return nil end
    local vals = {}
    for i = i0, i1 do vals[#vals + 1] = env.v[i] end
    table.sort(vals)
    local floor_db = vals[math.max(1, math.floor(#vals * 0.10))]
    local peak_db = vals[math.max(1, math.floor(#vals * 0.90))]
    if peak_db - floor_db < TUNE.env_min_range_db then return nil end
    return floor_db + (peak_db - floor_db) * TUNE.env_thr_frac
end

local function env_acts(env, w0, w1)
    local i0, i1 = env_window(env, w0, w1)
    local thr = env_threshold(env, i0, i1)
    if not thr then return nil end
    local out, since = {}, nil
    for i = i0, i1 do
        local active = env.v[i] >= thr
        if active and not since then
            since = env.t[i]
        elseif not active and since then
            out[#out + 1] = { b = since, e = env.t[i] }
            since = nil
        end
    end
    if since then out[#out + 1] = { b = since, e = w1 } end
    return out
end

local function env_refine_edge(env, t, which, w0, w1)
    local i0, i1 = env_window(env, w0, w1)
    local thr = env_threshold(env, i0, i1)
    if not thr then return nil end
    local best, bestd
    for i = math.max(i0 + 1, 2), i1 do
        local up = env.v[i - 1] < thr and env.v[i] >= thr
        local down = env.v[i - 1] >= thr and env.v[i] < thr
        if (which == "start" and up) or (which == "end" and down) then
            local d = math.abs(env.t[i] - t)
            if d <= TUNE.env_refine_ms and (not bestd or d < bestd) then
                best, bestd = env.t[i], d
            end
        end
    end
    return best
end

local function frame_to_ms(frame, cfg)
    frame = tonumber(frame)
    if not frame then return nil end
    if aegisub and type(aegisub.ms_from_frame) == "function" then
        local ok, ms = pcall(aegisub.ms_from_frame, frame)
        if ok and ms then return ms end
    end
    return round(frame * 1000 / ((cfg and cfg.fps) or DEFAULTS.fps))
end

local function parse_keyframe_file(path, cfg)
    local raw_lines = {}
    if not path or path == "" then return {} end
    local f = io.open(path, "r")
    if not f then return {} end
    local has_frame_tokens = false
    for line in f:lines() do
        local raw = trim(line)
        if raw ~= "" and not raw:match("^#") then
            raw_lines[#raw_lines + 1] = raw
            local kind = tostring(raw:match("^(%S+)") or ""):lower()
            if kind == "i" or kind == "p" or kind == "b" then has_frame_tokens = true end
        end
    end
    f:close()
    local frames = {}
    if has_frame_tokens then
        
        local frame = 0
        for _, raw in ipairs(raw_lines) do
            local kind = tostring(raw:match("^(%S+)") or ""):lower()
            if kind == "i" or kind == "p" or kind == "b" then
                if kind == "i" then frames[#frames + 1] = frame end
                frame = frame + 1
            end
        end
    else
        for _, raw in ipairs(raw_lines) do
            local n = tonumber(raw:match("^(-?%d+%.?%d*)"))
            if n then frames[#frames + 1] = round(n) end
        end
    end
    local ms, seen = {}, {}
    for _, fr in ipairs(frames) do
        local t = frame_to_ms(fr, cfg)
        if t and not seen[t] then seen[t] = true; ms[#ms + 1] = t end
    end
    table.sort(ms)
    return ms
end

local function get_keyframes(cfg)
    local ms
    if aegisub and type(aegisub.keyframes) == "function" then
        local ok, kf = pcall(aegisub.keyframes)
        if ok and type(kf) == "table" and #kf > 0 then
            local seen = {}
            ms = {}
            for _, fr in ipairs(kf) do
                local t = frame_to_ms(fr, cfg)
                if t and not seen[t] then seen[t] = true; ms[#ms + 1] = t end
            end
            table.sort(ms)
        end
    end
    if not ms then ms = parse_keyframe_file(cfg.keyframes, cfg) end
    local set = {}
    for _, t in ipairs(ms) do set[t] = true end
    return ms, set
end

local function kf_in(kfs, lo, hi, target)
    if not kfs or #kfs == 0 or hi < lo then return nil end
    local pos = lower_bound(kfs, lo)
    local best, bestd
    while pos <= #kfs do
        local t = kfs[pos]
        if t > hi then break end
        local d = math.abs(t - target)
        if not bestd or d < bestd then best, bestd = t, d end
        pos = pos + 1
    end
    return best
end

local function nearest_in(arr, target, max_d)
    if not arr or #arr == 0 then return nil end
    local pos = lower_bound(arr, target)
    local best, bestd
    for off = -1, 0 do
        local t = arr[pos + off]
        if t then
            local d = math.abs(t - target)
            if d <= max_d and (not bestd or d < bestd) then best, bestd = t, d end
        end
    end
    return best
end

local function make_interval_source(kind, label, weight, list)
    local starts, ends = {}, {}
    for _, iv in ipairs(list) do
        if kind == "sil" then
            starts[#starts + 1] = iv.e
            ends[#ends + 1] = iv.b
        else
            starts[#starts + 1] = iv.b
            ends[#ends + 1] = iv.e
        end
    end
    table.sort(starts); table.sort(ends)
    return { kind = kind, label = label, weight = weight, list = list, starts = starts, ends = ends, cur = 1 }
end

local function flux_intervals(on, off)
    local out, oi = {}, 1
    for _, t in ipairs(on) do
        while off[oi] and off[oi] <= t do oi = oi + 1 end
        if off[oi] then out[#out + 1] = { b = t, e = off[oi] } end
    end
    return merge_intervals(out)
end

local function build_signals(paths)
    local sig = { sources = {}, flux_on = {}, flux_off = {} }
    local silspecs = {
        { paths.sil30, TUNE.w_sil30, "sil30" },
        { paths.sil40, TUNE.w_sil40, "sil40" },
        { paths.sil50, TUNE.w_sil50, "sil50" },
    }
    for _, sp in ipairs(silspecs) do
        if sp[1] ~= "" then
            local list = parse_silence_file(sp[1])
            if #list > 0 then
                sig.sources[#sig.sources + 1] = make_interval_source("sil", sp[3], sp[2], list)
            end
        end
    end
    if paths.vad ~= "" then
        local list = parse_vad_file(paths.vad)
        if #list > 0 then
            sig.sources[#sig.sources + 1] = make_interval_source("vad", "vad", TUNE.w_vad, list)
        end
    end
    if paths.flux ~= "" then
        sig.flux_on, sig.flux_off = parse_flux_file(paths.flux)
    end
    if paths.env ~= "" then
        sig.env = parse_env_file(paths.env)
    end
    if paths.waveEnv then sig.env = paths.waveEnv end
    if #sig.sources == 0 and #sig.flux_on > 0 and #sig.flux_off > 0 then
        local list = flux_intervals(sig.flux_on, sig.flux_off)
        if #list > 0 then
            sig.sources[#sig.sources + 1] = make_interval_source("vad", "flux-span", TUNE.w_flux, list)
        end
    end
    return sig
end

local function window_overlaps(src, w0, w1)
    local list = src.list
    local cur = src.cur or 1
    if src.last_w0 and w0 < src.last_w0 then cur = 1 end
    src.last_w0 = w0
    while cur <= #list and list[cur].e <= w0 do cur = cur + 1 end
    src.cur = cur
    local out, i = {}, cur
    while i <= #list and list[i].b < w1 do
        if list[i].e > w0 then out[#out + 1] = list[i] end
        i = i + 1
    end
    return out
end

local function clip_intervals(list, w0, w1)
    local out = {}
    for _, iv in ipairs(list) do
        local b, e = math.max(iv.b, w0), math.min(iv.e, w1)
        if e > b then out[#out + 1] = { b = b, e = e } end
    end
    return out
end

local function complement_intervals(list, w0, w1)
    local out, cur = {}, w0
    for _, iv in ipairs(list) do
        local b, e = math.max(iv.b, w0), math.min(iv.e, w1)
        if e > b then
            if b > cur then out[#out + 1] = { b = cur, e = b } end
            if e > cur then cur = e end
        end
    end
    if cur < w1 then out[#out + 1] = { b = cur, e = w1 } end
    return out
end

local function vote_activity(sources, need, w0, w1)
    local events = {}
    for _, src in ipairs(sources) do
        for _, iv in ipairs(src.acts) do
            local b, e = math.max(iv.b, w0), math.min(iv.e, w1)
            if e > b then
                events[#events + 1] = { t = b, d = src.weight }
                events[#events + 1] = { t = e, d = -src.weight }
            end
        end
    end
    if #events == 0 or need <= 0 then return {} end
    table.sort(events, function(x, y) return x.t < y.t end)
    need = need - 1e-9
    local out, level, since = {}, 0, nil
    local i, n = 1, #events
    while i <= n do
        local t = events[i].t
        while i <= n and events[i].t == t do
            level = level + events[i].d
            i = i + 1
        end
        local active = level >= need
        if active and not since then
            since = t
        elseif not active and since then
            if t > since then out[#out + 1] = { b = since, e = t } end
            since = nil
        end
    end
    if since and w1 > since then out[#out + 1] = { b = since, e = w1 } end
    return out
end

local function edge_spread(sig, t, which)
    local vals = {}
    for _, src in ipairs(sig.sources) do
        local arr = (which == "start") and src.starts or src.ends
        local v = nearest_in(arr, t, TUNE.spread_search_ms)
        if v then vals[#vals + 1] = v end
    end
    local f = nearest_in(which == "start" and sig.flux_on or sig.flux_off, t, TUNE.spread_search_ms)
    if f then vals[#vals + 1] = f end
    if #vals < 2 then return false end
    local mn, mx = vals[1], vals[1]
    for _, v in ipairs(vals) do
        if v < mn then mn = v end
        if v > mx then mx = v end
    end
    return (mx - mn) > TUNE.spread_flag_ms
end

local function detect_voice(it, sig, cfg, kfs, relax)
    local fraction = relax and TUNE.relax_vote or TUNE.vote_fraction
    local bridge = relax and TUNE.relax_bridge_ms or TUNE.bridge_gap_ms
    local tiny = relax and TUNE.relax_tiny_ms or TUNE.tiny_span_ms
    local pause = relax and TUNE.relax_pause_ms or TUNE.max_pause_ms
    local min_run = relax and TUNE.relax_run_ms or TUNE.min_voice_run_ms

    
    
    local w0 = math.max(it.os, 0)
    local w1 = it.oe
    if w1 <= w0 then return nil end

    local sources, total = {}, 0
    for _, src in ipairs(sig.sources) do
        local within = window_overlaps(src, w0, w1)
        local acts
        if src.kind == "sil" then
            acts = complement_intervals(within, w0, w1)
        else
            acts = clip_intervals(within, w0, w1)
        end
        sources[#sources + 1] = { weight = src.weight, acts = acts }
        total = total + src.weight
    end
    if sig.env then
        local acts = env_acts(sig.env, w0, w1)
        if acts then
            sources[#sources + 1] = { weight = TUNE.w_env, acts = acts }
            total = total + TUNE.w_env
        end
    end
    if total <= 0 then return nil end

    local voted = vote_activity(sources, total * fraction, w0, w1)
    local runs = {}
    for _, r in ipairs(voted) do
        if r.e - r.b >= min_run then runs[#runs + 1] = r end
    end
    if #runs == 0 then runs = voted end
    if #runs == 0 then return nil end

    
    local spans = {}
    for _, r in ipairs(runs) do
        local last = spans[#spans]
        if last and r.b - last.e <= bridge then
            if r.e > last.e then last.e = r.e end
        else
            spans[#spans + 1] = { b = r.b, e = r.e }
        end
    end

    
    local cands = {}
    for _, sp in ipairs(spans) do
        if sp.e > it.os and sp.b < it.oe then cands[#cands + 1] = sp end
    end
    if #cands == 0 then return nil end

    
    
    local anchor, best = 1, nil
    for i, sp in ipairs(cands) do
        local score = overlap_len(sp.b, sp.e, it.os, it.oe) + 0.2 * (sp.e - sp.b)
        if not best or score > best then best, anchor = score, i end
    end
    local lo, hi = anchor, anchor
    while lo > 1 do
        local prev = cands[lo - 1]
        if cands[lo].b - prev.e <= pause and prev.e - prev.b >= tiny then
            lo = lo - 1
        else break end
    end
    while hi < #cands do
        local nxt = cands[hi + 1]
        if nxt.b - cands[hi].e <= pause and nxt.e - nxt.b >= tiny then
            hi = hi + 1
        else break end
    end
    local vs, ve = cands[lo].b, cands[hi].e

    
    
    for _, src in ipairs(sig.sources) do
        if src.label == "sil40" or src.label == "sil50" then
            local v = nearest_in(src.starts, vs, TUNE.onset_soft_ms)
            if v and v < vs then vs = v end
        end
    end
    
    
    for _, src in ipairs(sig.sources) do
        if src.label == "sil30" then
            local loud_end = nearest_in(src.ends, ve, TUNE.loud_tail_ms)
            if loud_end and loud_end < ve - TUNE.tail_keep_ms and loud_end > vs then
                ve = loud_end + TUNE.tail_keep_ms
            end
        end
    end
    
    if sig.env then
        local r = env_refine_edge(sig.env, vs, "start", w0, w1)
        if r and r < ve then vs = r end
        r = env_refine_edge(sig.env, ve, "end", w0, w1)
        if r and r > vs then ve = r end
    end
    local on = nearest_in(sig.flux_on, vs, TUNE.flux_start_ms)
    if on and on < ve then vs = on end
    local off = nearest_in(sig.flux_off, ve, TUNE.flux_end_ms)
    if off and off > vs then ve = off end

    
    
    
    
    
    local hit_lo = vs <= w0 + 1
    local hit_hi = ve >= w1 - 1
    vs = clamp(vs, it.os, it.oe)
    ve = clamp(ve, it.os, it.oe)
    
    
    if hit_hi and kfs then
        local k = kf_in(kfs, it.oe - TUNE.orig_end_cut_ms, it.oe, it.oe)
        if k and k > vs then ve = k end
    end
    if ve - vs < TUNE.min_voice_ms then return nil end

    local weak = hit_lo or hit_hi
        or edge_spread(sig, vs, "start") or edge_spread(sig, ve, "end")
    return { vs = round(vs), ve = round(ve), weak = weak }
end
local LZ = {}

LZ.lazyConfig = {
    weights = { proximity = 0.30, silence_q = 0.22, source_c = 0.13, clarity = 0.08, vad = 0.30, flux = 0.30 },
    cluster_max_dist = 120, min_cluster_mass = 0.6, min_score_threshold = 0.25,
    min_duration = 200, max_duration = 8000, epsilon = 50,
    thresholds = {
        [30] = { min_silence_dur = 350, reliability = 1.0 },
        [40] = { min_silence_dur = 120, reliability = 0.9 },
        [50] = { min_silence_dur = 120, reliability = 0.6 },
    },
}
LZ.tableConfig = {
    merge_gap_ms = 120, min_noise_ms = 80, edge_drop_ms = 60,
    w_cov = 0.65, w_prox = 0.25, w_frag = 0.10, sigma_ms = 200, eps = 1,
}
LZ.auxVad  = nil
LZ.auxFlux = nil

function LZ.normalizeProximity(d, w) if w <= 0 then return 0 end; return math.exp(-(d*d)/(w*w)) end
function LZ.normalizeSilenceQuality(d)
    if d < 100 then return 0.1
    elseif d < 500 then return 0.3 + 0.4 * (d - 100) / 400
    elseif d < 1500 then return 0.7 + 0.2 * (d - 500) / 1000
    else return 0.9 + 0.1 * (1 - math.exp(-(d - 1500) / 1000)) end
end
function LZ.getSourceConfidence(t) return (LZ.lazyConfig.thresholds[t] and LZ.lazyConfig.thresholds[t].reliability) or 0.5 end
function LZ.normalizeContextClarity(d) return 1 / (1 + d * d) end
function LZ.calculateScore(c, rt, sw, sd)
    local d = math.abs(c.time - rt)
    local fp = LZ.normalizeProximity(d, sw)
    local fq = LZ.normalizeSilenceQuality(c.duration or 0)
    local fc = LZ.getSourceConfidence(c.threshold)
    local fl = LZ.normalizeContextClarity(sd)
    local fflux, fvad = (c.flux_boost or 0), (c.vad_align or 0)
    local W = LZ.lazyConfig.weights
    return (fp*W.proximity)+(fq*W.silence_q)+(fc*W.source_c)+(fl*W.clarity)+(fflux*W.flux)+(fvad*W.vad)
end
function LZ.findClusters(cs, md)
    if not cs or #cs == 0 then return {} end
    if #cs < 2 then return { cs } end
    table.sort(cs, function(a, b) return a.time < b.time end)
    local cls, ccl = {}, { cs[1] }
    for i = 2, #cs do
        if cs[i].time - ccl[#ccl].time <= md then table.insert(ccl, cs[i])
        else table.insert(cls, ccl); ccl = { cs[i] } end
    end
    table.insert(cls, ccl); return cls
end
function LZ.weightedMedianTime(cl)
    table.sort(cl, function(a, b) return a.time < b.time end)
    local sum = 0; for _, p in ipairs(cl) do sum = sum + (p.score or 0) end
    if sum <= 0 then local mid = math.floor((#cl + 1) / 2); return cl[mid].time end
    local acc = 0
    for _, p in ipairs(cl) do acc = acc + (p.score or 0); if acc >= sum * 0.5 then return p.time end end
    return cl[#cl].time
end
function LZ.addLazyTag(l, t)
    local tag = "[LZ " .. t .. "]"
    local e = l.effect or ""
    if e:find(tag, 1, true) then return end
    l.effect = (e == "") and tag or (e .. " " .. tag)
end
function LZ.lowerBound(arr, t)
    local lo, hi = 1, #arr + 1
    while lo < hi do
        local mid = math.floor((lo + hi) / 2)
        if arr[mid].time < t then lo = mid + 1 else hi = mid end
    end
    return lo
end
function LZ.validateIntra(ns, ne, os, oe)
    if ns < os or ne > oe then return false, "out_of_range" end
    if ne - ns < LZ.lazyConfig.min_duration then return false, "min_dur" end
    return true
end
function LZ.clampIntra(ns, ne, os, oe)
    local ns2, ne2 = math.max(ns, os), math.min(ne, oe)
    if ne2 - ns2 < LZ.lazyConfig.min_duration then return false, "min_dur", ns, ne end
    return true, nil, ns2, ne2
end
function LZ.getDensity(t, s, ws)
    ws = ws or 5000
    local c, sw, ew = 0, t - ws/2, t + ws/2
    for _, seg in ipairs(s) do
        if not (seg["end"] <= sw or seg.start >= ew) then c = c + 1 end
    end
    return c / (ws / 1000)
end

function LZ.parseLazyFile(fp, t)
    local segs = {}; local fh = io.open(fp, "r"); if not fh then return segs end
    local cs = nil
    for l in fh:lines() do
        local ss = l:match("silence_start:%s*([%d%.]+)")
        if ss then cs = tonumber(ss) * 1000 end
        local se, sd = l:match("silence_end:%s*([%d%.]+)%s*|%s*silence_duration:%s*([%d%.]+)")
        if se and cs then
            local dms = tonumber(sd) * 1000
            if dms >= ((LZ.lazyConfig.thresholds[t] and LZ.lazyConfig.thresholds[t].min_silence_dur) or 100) then
                table.insert(segs, { start = cs, ["end"] = tonumber(se) * 1000, duration = dms, threshold = t })
            end
            cs = nil
        end
    end
    fh:close(); return segs
end

function LZ.parseVADtsv(path)
    local segs, f = {}, io.open(path, "r"); if not f then return segs end
    local first = true
    for line in f:lines() do
        if first then first = false
        else
            local a, b = line:match("([%d%.]+)%s+([%d%.]+)")
            if a and b then table.insert(segs, { start = tonumber(a), ["end"] = tonumber(b) }) end
        end
    end
    f:close(); return segs
end

function LZ.parseFLUXtsv(path)
    local cands, f = {}, io.open(path, "r"); if not f then return cands end
    local first = true
    for line in f:lines() do
        if first then first = false
        else
            local t, ty, sc = line:match("([%d%.]+)%s+(%a+)%s+([%d%.]+)")
            if t and ty and sc then table.insert(cands, { time = tonumber(t), type = ty, score = tonumber(sc) }) end
        end
    end
    f:close(); return cands
end

function LZ.enrichWithAux(cands, flux, vad, want_type)
    local function nearest_flux(t)
        local best_d, best_s = math.huge, 0
        for _, c in ipairs(flux or {}) do
            if c.type == want_type then
                local d = math.abs(c.time - t)
                if d < best_d then best_d, best_s = d, c.score end
            end
        end
        if best_d <= 40 then return (1 - best_d / 40) * best_s else return 0 end
    end
    local function vad_margin(t)
        local best = math.huge
        for _, s in ipairs(vad or {}) do
            local d1 = math.abs((s.start or 0) - t); local d2 = math.abs((s["end"] or 0) - t)
            local d = (d1 < d2) and d1 or d2
            if d < best then best = d end
        end
        if best == math.huge then return 0 end
        return math.exp(-(best * best) / 1600)
    end
    for _, c in ipairs(cands) do c.flux_boost = nearest_flux(c.time); c.vad_align = vad_margin(c.time) end
end

function LZ.loadLazyData(fps)
    local rs = {}
    for t, p in pairs(fps) do for _, s in ipairs(LZ.parseLazyFile(p, t)) do table.insert(rs, s) end end
    table.sort(rs, function(a, b) return a.start < b.start end)
    local ss, se = {}, {}
    for _, s in ipairs(rs) do
        table.insert(ss, { time = s["end"],   duration = s.duration, threshold = s.threshold })
        table.insert(se, { time = s.start,    duration = s.duration, threshold = s.threshold })
    end
    local byTime = function(a, b) return a.time < b.time end
    table.sort(ss, byTime); table.sort(se, byTime)
    return ss, se, rs
end

function LZ.copyCandidate(ev) return { time = ev.time, duration = ev.duration, threshold = ev.threshold } end
function LZ.roundMs(x) return math.floor(x + 0.5) end
function LZ.orderedByStart(subs, sel)
    local arr = {}
    for _, i in ipairs(sel) do table.insert(arr, { i = i, st = subs[i].start_time }) end
    table.sort(arr, function(a, b) return a.st < b.st end)
    local out = {}; for _, e in ipairs(arr) do table.insert(out, e.i) end; return out
end
function LZ.stripLZ(effect) effect = effect or ""; return (effect:gsub("%s*%[LZ[^%]]*%]", "")) end

function LZ.tagDecider(l, os, oe, ns, ne, apply_start, apply_end, enable_tagging, tag_mode, tag_scope)
    if not enable_tagging or tag_mode == "None" then return end
    local chs = (apply_start and ns ~= os)
    local che = (apply_end and ne ~= oe)
    local scope_s = (tag_scope == "Both" or tag_scope == "Start only")
    local scope_e = (tag_scope == "Both" or tag_scope == "End only")
    if tag_mode == "Only 0ms" then
        if scope_s and apply_start and not chs then LZ.addLazyTag(l, "~0ms-s") end
        if scope_e and apply_end   and not che then LZ.addLazyTag(l, "~0ms-e") end
    elseif tag_mode == "Only changes" then
        if scope_s and chs then LZ.addLazyTag(l, string.format("Δs=%+dms", ns - os)) end
        if scope_e and che then LZ.addLazyTag(l, string.format("Δe=%+dms", ne - oe)) end
    elseif tag_mode == "Both" then
        if scope_s and apply_start then LZ.addLazyTag(l, chs and string.format("Δs=%+dms", ns - os) or "~0ms-s") end
        if scope_e and apply_end   then LZ.addLazyTag(l, che and string.format("Δe=%+dms", ne - oe) or "~0ms-e") end
    end
end

function LZ.rankFusionPick(cands, rt, is_start)
    local M = #cands; if M == 0 then return nil end; if M == 1 then return cands[1] end
    local function rank_by(fn, desc)
        local t = {}; for i, c in ipairs(cands) do t[i] = { i = i, v = fn(c) } end
        table.sort(t, function(a, b) if desc then return a.v > b.v else return a.v < b.v end end)
        local r = {}; for k, rec in ipairs(t) do r[rec.i] = k end; return r
    end
    local r_flux = rank_by(function(c) return c.flux_boost or 0 end, true)
    local r_vad  = rank_by(function(c) return c.vad_align  or 0 end, true)
    local r_prox = rank_by(function(c) return math.abs(c.time - rt) end, false)
    local r_dur  = rank_by(function(c) return c.duration or 0 end, true)
    local r_src  = rank_by(function(c) return LZ.getSourceConfidence(c.threshold) end, true)
    local best_i, best_sum = 1, 1e9
    for i = 1, M do
        local s = (r_flux[i]/M) + (r_vad[i]/M) + (r_prox[i]/M) + (r_dur[i]/M) + (r_src[i]/M)
        if s < best_sum then best_sum = s; best_i = i end
    end
    return cands[best_i]
end

function LZ.pickTime(cands, ref, is_start)
    local cls = LZ.findClusters(cands, LZ.lazyConfig.cluster_max_dist)
    local bc, bcm = nil, 0
    for _, cl in ipairs(cls) do
        local cm = 0; for _, p in ipairs(cl) do cm = cm + (p.score or 0) end
        if cm > bcm then bcm = cm; bc = cl end
    end
    if bc then
        local k = math.min(3, #bc); local nm = bcm / k
        if nm > LZ.lazyConfig.min_cluster_mass then return LZ.weightedMedianTime(bc), true end
    end
    table.sort(cands, function(a, b) return (a.score or 0) > (b.score or 0) end)
    if cands[1] and (cands[1].score or 0) > LZ.lazyConfig.min_score_threshold then return cands[1].time, true end
    local alt = LZ.rankFusionPick(cands, ref, is_start); if alt then return alt.time, true end
    return ref, false
end

function LZ.runClusterAnalysis(subs, sel, lim, files, opts)
    local ss, se, asg = LZ.loadLazyData(files); if #ss == 0 then return 0 end
    local modified = 0
    local apply_start, apply_end = opts.apply_start, opts.apply_end
    local enable_tagging, tag_mode, tag_scope = opts.enable_tagging, opts.tag_mode, opts.tag_scope
    aegisub.progress.task("Analyzing (Cluster, intra ±" .. tostring(lim) .. " ms)...")
    local seq = LZ.orderedByStart(subs, sel)
    for idx, ii in ipairs(seq) do
        aegisub.progress.set(idx / #seq * 100)
        local l = subs[ii]
        if l.class == "dialogue" then
            local os, oe = l.start_time, l.end_time
            local ns, ne = os, oe
            local den = LZ.getDensity((os + oe) / 2, asg)
            if apply_start then
                local sc = {}
                local hi = math.min(os + lim, oe - LZ.lazyConfig.min_duration)
                local k = LZ.lowerBound(ss, os)
                while ss[k] and ss[k].time <= hi do
                    table.insert(sc, LZ.copyCandidate(ss[k])); k = k + 1
                end
                if LZ.auxFlux or LZ.auxVad then LZ.enrichWithAux(sc, LZ.auxFlux, LZ.auxVad, "onset") end
                for _, cv in ipairs(sc) do cv.score = LZ.calculateScore(cv, os, lim, den) end
                if #sc > 0 then
                    local pt, ok = LZ.pickTime(sc, os, true)
                    if ok then ns = LZ.roundMs(pt) end
                end
            end
            if apply_end then
                local ec = {}
                local lo = math.max(oe - lim, os + LZ.lazyConfig.min_duration)
                local k = LZ.lowerBound(se, lo)
                while se[k] and se[k].time <= oe do
                    table.insert(ec, LZ.copyCandidate(se[k])); k = k + 1
                end
                if LZ.auxFlux or LZ.auxVad then LZ.enrichWithAux(ec, LZ.auxFlux, LZ.auxVad, "offset") end
                for _, cv in ipairs(ec) do cv.score = LZ.calculateScore(cv, oe, lim, den) end
                if #ec > 0 then
                    local pt, ok = LZ.pickTime(ec, oe, false)
                    if ok then ne = LZ.roundMs(pt) end
                end
            end
            if apply_start or apply_end then
                local changed = (ns ~= os) or (ne ~= oe)
                if changed then
                    local ok, why = LZ.validateIntra(ns, ne, os, oe)
                    if not ok then
                        local ok2, why2, ns2, ne2 = LZ.clampIntra(ns, ne, os, oe)
                        if ok2 then
                            l.start_time = ns2; l.end_time = ne2; modified = modified + 1
                            LZ.tagDecider(l, os, oe, ns2, ne2, apply_start, apply_end, enable_tagging, tag_mode, tag_scope)
                        else
                            if enable_tagging then LZ.addLazyTag(l, "Reject:" .. (why2 or why)) end
                        end
                    else
                        l.start_time = ns; l.end_time = ne; modified = modified + 1
                        LZ.tagDecider(l, os, oe, ns, ne, apply_start, apply_end, enable_tagging, tag_mode, tag_scope)
                    end
                else
                    LZ.tagDecider(l, os, oe, ns, ne, apply_start, apply_end, enable_tagging, tag_mode, tag_scope)
                end
                subs[ii] = l
            end
        end
    end
    return modified
end

function LZ.normalizeVadToMs(vad_data)
    if not vad_data or #vad_data == 0 then return {} end
    local vmax = 0
    for _, s in ipairs(vad_data) do if s["end"] and s["end"] > vmax then vmax = s["end"] end end
    local in_ms = (vmax > 10000)
    local out = {}
    for _, s in ipairs(vad_data) do
        local a = in_ms and s.start    or (s.start    * 1000)
        local b = in_ms and s["end"]   or (s["end"]   * 1000)
        table.insert(out, { start = a, ["end"] = b })
    end
    table.sort(out, function(a, b) return a.start < b.start end)
    return out
end

function LZ.normalizeFluxToMs(flux_data)
    if not flux_data or #flux_data == 0 then return flux_data end
    local fmax = 0
    for _, c in ipairs(flux_data) do if c.time and c.time > fmax then fmax = c.time end end
    if fmax > 10000 then return flux_data end
    local out = {}
    for _, c in ipairs(flux_data) do out[#out+1] = { time = (c.time or 0) * 1000, type = c.type, score = c.score } end
    return out
end

function LZ.containingSilence(t, silences)
    local lo, hi, cand = 1, #silences, nil
    while lo <= hi do
        local mid = math.floor((lo + hi) / 2)
        if silences[mid].start <= t then cand = silences[mid]; lo = mid + 1
        else hi = mid - 1 end
    end
    if cand and t <= cand["end"] then return cand end
end

function LZ.mergeSilenceToIntervals(files)
    local all = {}
    for threshold, path in pairs(files or {}) do
        local fh = io.open(path, "r")
        if fh then
            local cur
            for line in fh:lines() do
                local ss = line:match("silence_start:%s*([%d%.]+)")
                if ss then cur = tonumber(ss) * 1000 end
                local se = line:match("silence_end:%s*([%d%.]+)")
                if se and cur then
                    table.insert(all, { start = cur, ["end"] = tonumber(se) * 1000, threshold = threshold })
                    cur = nil
                end
            end
            fh:close()
        end
    end
    table.sort(all, function(a, b) return a.start < b.start end)
    local merged = {}
    for _, sil in ipairs(all) do
        if #merged == 0 then
            table.insert(merged, { start = sil.start, ["end"] = sil["end"], count = 1 })
        else
            local last = merged[#merged]
            if sil.start <= last["end"] + 50 then
                last["end"] = math.max(last["end"], sil["end"])
                last.count = (last.count or 1) + 1
            else
                table.insert(merged, { start = sil.start, ["end"] = sil["end"], count = 1 })
            end
        end
    end
    return merged
end

function LZ.findFluxExact(t, flux_data, want_type, tol)
    tol = tol or 20
    for _, f in ipairs(flux_data or {}) do
        if f.type == want_type and math.abs((f.time or 0) - t) <= tol then return f.time end
    end
end
function LZ.findActivityBounds(os_ms, oe_ms, silences, flux_data)
    local t_start, t_end, has_fs, has_fe = nil, nil, false, false
    local s0 = LZ.containingSilence(os_ms, silences)
    local cand = s0 and (s0["end"] + 1) or os_ms
    if cand <= oe_ms then
        t_start = cand
        local fx = LZ.findFluxExact(t_start, flux_data, "onset", 30)
        if fx and fx >= os_ms then t_start = fx; has_fs = true end
    end
    local s1 = LZ.containingSilence(oe_ms, silences)
    cand = s1 and (s1.start - 1) or oe_ms
    if cand >= os_ms then
        t_end = cand
        local fx = LZ.findFluxExact(t_end, flux_data, "offset", 30)
        if fx and fx <= oe_ms then t_end = fx; has_fe = true end
    end
    return t_start, t_end, has_fs, has_fe
end

function LZ.runLazyFusionAnalysis(subs, sel, files, opts, flux_data)
    local silences = LZ.mergeSilenceToIntervals(files)
    local apply_start, apply_end = opts.apply_start, opts.apply_end
    local enable_tagging, tag_mode, tag_scope = opts.enable_tagging, opts.tag_mode, opts.tag_scope
    local modified = 0
    local seq = LZ.orderedByStart(subs, sel)
    aegisub.progress.task("Analyzing (LazyFusion v2 EFS)...")
    for idx, ii in ipairs(seq) do
        aegisub.progress.set(idx / #seq * 100)
        local l = subs[ii]
        if l.class == "dialogue" then
            local os_ms, oe_ms = l.start_time, l.end_time
            local ns, ne = os_ms, oe_ms
            local t_s, t_e, has_fs, has_fe = LZ.findActivityBounds(os_ms, oe_ms, silences, flux_data)
            if t_s and t_e then
                local ps = has_fs and 0 or 15
                local pe = has_fe and 0 or 15
                if apply_start then ns = t_s - ps; if ns < 0 then ns = 0 end end
                if apply_end   then ne = t_e + pe end
                if ne - ns < LZ.lazyConfig.min_duration then
                    local center = (t_s + t_e) / 2; local hm = LZ.lazyConfig.min_duration / 2
                    ns = center - hm; ne = center + hm
                    if ns < 0 then ns = 0 end
                end
            else
                if enable_tagging then LZ.addLazyTag(l, "NoActivity") end
            end
            local changed = (math.abs(ns - os_ms) > 1) or (math.abs(ne - oe_ms) > 1)
            if changed then
                local ok, why = LZ.validateIntra(ns, ne, os_ms, oe_ms)
                if not ok then
                    local ok2, why2, ns2, ne2 = LZ.clampIntra(ns, ne, os_ms, oe_ms)
                    if ok2 then
                        l.start_time = LZ.roundMs(ns2); l.end_time = LZ.roundMs(ne2)
                        modified = modified + 1
                        LZ.tagDecider(l, os_ms, oe_ms, ns2, ne2, apply_start, apply_end, enable_tagging, tag_mode, tag_scope)
                    else
                        if enable_tagging then LZ.addLazyTag(l, "Reject:" .. (why2 or why)) end
                    end
                else
                    l.start_time = LZ.roundMs(ns); l.end_time = LZ.roundMs(ne)
                    modified = modified + 1
                    LZ.tagDecider(l, os_ms, oe_ms, ns, ne, apply_start, apply_end, enable_tagging, tag_mode, tag_scope)
                end
            else
                LZ.tagDecider(l, os_ms, oe_ms, ns, ne, apply_start, apply_end, enable_tagging, tag_mode, tag_scope)
            end
            subs[ii] = l
        end
    end
    return modified
end

function LZ.clamp(x, a, b) if x < a then return a elseif x > b then return b else return x end end
function LZ.mergeIntervals(ints, eps)
    table.sort(ints, function(a, b) return a.start < b.start end)
    local out = {}
    for _, it in ipairs(ints) do
        if #out == 0 then out[1] = { start = it.start, ["end"] = it["end"] }
        else
            local L = out[#out]
            if it.start <= L["end"] + (eps or 0) then
                if it["end"] > L["end"] then L["end"] = it["end"] end
            else
                out[#out+1] = { start = it.start, ["end"] = it["end"] }
            end
        end
    end
    return out
end
function LZ.intersect(a1, a2, b1, b2) local s = math.max(a1, b1); local e = math.min(a2, b2); if s < e then return s, e end end
function LZ.noiseInWindow(merged_silence, W1, W2, eps)
    local cut = {}
    for _, si in ipairs(merged_silence) do
        local s, e = LZ.intersect(W1, W2, si.start, si["end"])
        if s and e then cut[#cut+1] = { start = s, ["end"] = e } end
    end
    cut = LZ.mergeIntervals(cut, eps)
    local noise = {}; local cur = W1
    for _, si in ipairs(cut) do
        if si.start > cur + (eps or 0) then noise[#noise+1] = { start = cur, ["end"] = si.start } end
        cur = math.max(cur, si["end"])
    end
    if cur < W2 - (eps or 0) then noise[#noise+1] = { start = cur, ["end"] = W2 } end
    return noise
end
function LZ.totalMs(ints) local s = 0; for _, x in ipairs(ints) do s = s + (x["end"] - x.start) end; return s end
function LZ.mergeNoiseSmallGaps(noise, gap_ms)
    if #noise <= 1 then return noise end
    local out = { { start = noise[1].start, ["end"] = noise[1]["end"] } }
    for i = 2, #noise do
        local L = out[#out]
        local g = noise[i].start - L["end"]
        if g <= gap_ms then if noise[i]["end"] > L["end"] then L["end"] = noise[i]["end"] end
        else out[#out+1] = { start = noise[i].start, ["end"] = noise[i]["end"] } end
    end
    return out
end
function LZ.dropEdgeInconclusives(noise, W1, W2, edge_ms)
    if #noise == 0 then return noise end
    local has_inner = false
    for _, n in ipairs(noise) do if n.start > W1 and n["end"] < W2 then has_inner = true; break end end
    if not has_inner then return noise end
    local out = {}
    for _, n in ipairs(noise) do
        local len = n["end"] - n.start
        local el = (n.start <= W1 + LZ.tableConfig.eps); local er = (n["end"] >= W2 - LZ.tableConfig.eps)
        if (el or er) and len <= edge_ms then else out[#out+1] = n end
    end
    return (#out > 0) and out or noise
end
function LZ.center(t1, t2) return (t1 + t2) / 2 end
function LZ.groupNoise(noise, merge_gap_ms)
    if #noise == 0 then return {} end
    local groups, cur = {}, { noise[1] }
    for i = 2, #noise do
        local g = noise[i].start - noise[i-1]["end"]
        if g <= merge_gap_ms then cur[#cur+1] = noise[i]
        else groups[#groups+1] = cur; cur = { noise[i] } end
    end
    groups[#groups+1] = cur; return groups
end
function LZ.clusterSpan(G) return G[1].start, G[#G]["end"] end
function LZ.clusterScore(G, W1, W2)
    local gs = LZ.totalMs(G); local s, e = LZ.clusterSpan(G); local width = math.max(1, e - s)
    local cov = gs / width
    local prox = math.exp(-((LZ.center(s, e) - LZ.center(W1, W2))^2) / (LZ.tableConfig.sigma_ms^2))
    local frag = (#G - 1) / #G
    return LZ.tableConfig.w_cov * cov + LZ.tableConfig.w_prox * prox - LZ.tableConfig.w_frag * frag
end
function LZ.parseLazyFileTable(fp, t)
    local segs, dur = {}, nil
    local fh = io.open(fp, "r"); if not fh then return segs, dur end
    local cur
    for l in fh:lines() do
        local H, M, S = l:match("Duration:%s*(%d+):(%d+):([%d%.]+)")
        if H then dur = (tonumber(H)*3600 + tonumber(M)*60 + tonumber(S)) * 1000 end
        local ss = l:match("silence_start:%s*([%d%.]+)"); if ss then cur = tonumber(ss) * 1000 end
        local se, sd = l:match("silence_end:%s*([%d%.]+)%s*|%s*silence_duration:%s*([%d%.]+)")
        if se and cur then
            local dms = tonumber(sd) * 1000
            if dms >= ((LZ.lazyConfig.thresholds[t] and LZ.lazyConfig.thresholds[t].min_silence_dur) or 100) then
                table.insert(segs, { start = cur, ["end"] = tonumber(se) * 1000, duration = dms, threshold = t })
            end
            cur = nil
        end
    end
    fh:close(); return segs, dur
end
function LZ.loadLazyDataTable(fps)
    local rs, maxdur = {}, 0
    for t, p in pairs(fps) do
        local lst, dur = LZ.parseLazyFileTable(p, t)
        if dur and dur > maxdur then maxdur = dur end
        for _, s in ipairs(lst) do table.insert(rs, s) end
    end
    table.sort(rs, function(a, b) return a.start < b.start end)
    local ss, se = {}, {}
    for _, s in ipairs(rs) do
        table.insert(ss, { time = s["end"],  duration = s.duration, threshold = s.threshold })
        table.insert(se, { time = s.start,   duration = s.duration, threshold = s.threshold })
    end
    return ss, se, rs, maxdur
end
function LZ.buildNoiseTable(merged_silences, W1, W2, save_path)
    local noise = LZ.noiseInWindow(merged_silences, W1, W2, LZ.tableConfig.eps)
    noise = LZ.mergeNoiseSmallGaps(noise, LZ.tableConfig.merge_gap_ms)
    if save_path then
        local f = io.open(save_path, "w")
        if f then
            f:write("start_ms,end_ms,duration_ms\n")
            for _, n in ipairs(noise) do f:write(string.format("%d,%d,%d\n", n.start, n["end"], n["end"] - n.start)) end
            f:close()
        end
    end
    return noise
end

function LZ.runTableAnalysis(subs, sel, lim, files, opts)
    local _, _, rs, maxdur = LZ.loadLazyDataTable(files)
    if not rs or #rs == 0 then return 0 end
    local raw = {}
    for _, s in ipairs(rs) do raw[#raw+1] = { start = s.start, ["end"] = s["end"] } end
    local merged = LZ.mergeIntervals(raw, LZ.tableConfig.eps)
    local base = files[40] or files[30] or files[50]
    if opts.table_csv and base and maxdur and maxdur > 0 then
        local folder = base:gsub("[^\\/]+$", "")
        LZ.buildNoiseTable(merged, 0, maxdur, folder .. "noise_table_global.csv")
    end
    local apply_start, apply_end = opts.apply_start, opts.apply_end
    local enable_tag, tag_mode, tag_scope = opts.enable_tagging, opts.tag_mode, opts.tag_scope
    local modified = 0
    local seq = LZ.orderedByStart(subs, sel)
    aegisub.progress.task("Analyzing (Table, intra ±" .. tostring(lim) .. " ms)...")
    for idx, ii in ipairs(seq) do
        aegisub.progress.set(idx / #seq * 100)
        local l = subs[ii]
        if l.class == "dialogue" then
            local os, oe = l.start_time, l.end_time
            local min_d = LZ.lazyConfig.min_duration
            local Slo, Shi = os, math.min(oe - min_d, os + lim)
            local Elo, Ehi = math.max(os + min_d, oe - lim), oe
            if Shi < Slo then Shi = Slo end
            if Ehi < Elo then Elo = Ehi end
            local noise = LZ.noiseInWindow(merged, os, oe, LZ.tableConfig.eps)
            noise = LZ.mergeNoiseSmallGaps(noise, LZ.tableConfig.merge_gap_ms)
            noise = LZ.dropEdgeInconclusives(noise, os, oe, LZ.tableConfig.edge_drop_ms)
            if #noise > 1 then
                local pruned = {}
                for _, n in ipairs(noise) do if (n["end"] - n.start) >= LZ.tableConfig.min_noise_ms then pruned[#pruned+1] = n end end
                if #pruned > 0 then noise = pruned end
            end
            local ns, ne = os, oe; local changed = false
            if #noise == 0 then
            elseif #noise == 1 then
                local n = noise[1]
                if apply_start then ns = LZ.clamp(n.start, Slo, Shi) end
                if apply_end   then ne = LZ.clamp(n["end"], Elo, Ehi) end
                if ne - ns < min_d then
                    local c = LZ.center(n.start, n["end"])
                    ns = LZ.clamp(math.floor(c - min_d/2 + 0.5), Slo, Shi)
                    ne = LZ.clamp(ns + min_d, Elo, Ehi)
                end
                changed = (ns ~= os) or (ne ~= oe)
            else
                local groups = LZ.groupNoise(noise, LZ.tableConfig.merge_gap_ms)
                local bestG, bestScore = groups[1], -1e9
                for _, G in ipairs(groups) do
                    local sc = LZ.clusterScore(G, os, oe)
                    if sc > bestScore then bestScore = sc; bestG = G end
                end
                local cs, ce = LZ.clusterSpan(bestG)
                if bestG[1].start <= os + LZ.tableConfig.eps and (bestG[1]["end"] - bestG[1].start) <= LZ.tableConfig.edge_drop_ms and #bestG > 1 then
                    cs = bestG[2].start
                end
                if bestG[#bestG]["end"] >= oe - LZ.tableConfig.eps and (bestG[#bestG]["end"] - bestG[#bestG].start) <= LZ.tableConfig.edge_drop_ms and #bestG > 1 then
                    ce = bestG[#bestG-1]["end"]
                end
                if apply_start then ns = LZ.clamp(cs, Slo, Shi) end
                if apply_end   then ne = LZ.clamp(ce, Elo, Ehi) end
                if ne - ns < min_d then
                    local big = bestG[1]; local blen = big["end"] - big.start
                    for _, n in ipairs(bestG) do
                        local len = n["end"] - n.start
                        if len > blen then big = n; blen = len end
                    end
                    ns = LZ.clamp(big.start, Slo, Shi); ne = LZ.clamp(big["end"], Elo, Ehi)
                    if ne - ns < min_d then
                        local c = LZ.center(ns, ne)
                        ns = LZ.clamp(math.floor(c - min_d/2 + 0.5), Slo, Shi)
                        ne = LZ.clamp(ns + min_d, Elo, Ehi)
                    end
                end
                changed = (ns ~= os) or (ne ~= oe)
            end
            if apply_start or apply_end then
                if changed then
                    local ok, why = LZ.validateIntra(ns, ne, os, oe)
                    if not ok then
                        local ok2, why2, ns2, ne2 = LZ.clampIntra(ns, ne, os, oe)
                        if ok2 then
                            l.start_time, l.end_time = ns2, ne2
                            modified = modified + 1
                            LZ.tagDecider(l, os, oe, ns2, ne2, apply_start, apply_end, enable_tag, tag_mode, tag_scope)
                        else
                            if enable_tag then LZ.addLazyTag(l, "Reject:" .. (why2 or why)) end
                        end
                    else
                        l.start_time, l.end_time = ns, ne
                        modified = modified + 1
                        LZ.tagDecider(l, os, oe, ns, ne, apply_start, apply_end, enable_tag, tag_mode, tag_scope)
                    end
                    subs[ii] = l
                else
                    LZ.tagDecider(l, os, oe, ns, ne, apply_start, apply_end, enable_tag, tag_mode, tag_scope)
                    subs[ii] = l
                end
            end
        end
    end
    return modified
end

function LZ.run(subs, sel, paths, opts)
    opts = opts or {}
    local files = {}
    if paths.sil30 and paths.sil30 ~= "" then files[30] = paths.sil30 end
    if paths.sil40 and paths.sil40 ~= "" then files[40] = paths.sil40 end
    if paths.sil50 and paths.sil50 ~= "" then files[50] = paths.sil50 end
    if not (files[30] or files[40] or files[50]) then return nil end
    for _, i in ipairs(sel) do
        local line = subs[i]
        if line and line.class == "dialogue" then
            line.effect = LZ.stripLZ(line.effect)
            subs[i] = line
        end
    end
    if opts.silences_only then
        return LZ.runLazyFusionAnalysis(subs, sel, files, opts, nil)
    end
    local method = opts.method
    local flux = (paths.flux and paths.flux ~= "") and LZ.normalizeFluxToMs(LZ.parseFLUXtsv(paths.flux)) or nil
    if method == "LazyFusion" then
        return LZ.runLazyFusionAnalysis(subs, sel, files, opts, flux)
    elseif method == "Table (±ms)" then
        local single = {}
        if files[40] then single[40] = files[40]
        elseif files[30] then single[30] = files[30]
        else single[50] = files[50] end
        local lim = tonumber(opts.limit) or 500
        return LZ.runTableAnalysis(subs, sel, lim, single, opts)
    else
        LZ.auxVad  = (paths.vad and paths.vad ~= "") and LZ.normalizeVadToMs(LZ.parseVADtsv(paths.vad)) or nil
        LZ.auxFlux = flux
        local lim = tonumber(opts.limit) or 500
        local modified = LZ.runClusterAnalysis(subs, sel, lim, files, opts)
        LZ.auxVad, LZ.auxFlux = nil, nil
        return modified
    end
end

local Timing = {
    version = "1.0.0",
    round = round, clamp = clamp, lowerBound = lower_bound, overlapLen = overlap_len,
    visibleText = visible_text, utf8Len = utf8_len, readableChars = readable_chars,
    styleOk = style_ok, isSpoken = is_spoken, frameToMs = frame_to_ms,
    mergeIntervals = merge_intervals,
    parseSilenceFile = parse_silence_file, parseVadFile = parse_vad_file,
    parseFluxFile = parse_flux_file, parseEnvFile = parse_env_file,
    parseKeyframeFile = parse_keyframe_file, getKeyframes = get_keyframes,
    scriptDirAndBase = script_dir_and_base, listDir = list_dir,
    classifyDataFile = classify_data_file, chapterOf = chapter_of,
    discoverPaths = discover_paths, pathKeys = PATH_KEYS,
    buildSignals = build_signals, detectVoice = detect_voice, tune = TUNE,
    lzt = LZ,
}

if depctrl then return depctrl:register(Timing) end
return Timing
