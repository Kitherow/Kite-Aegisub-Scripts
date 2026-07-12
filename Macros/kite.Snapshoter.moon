export script_name        = "Snapshoter"
export script_description = "Capture subtitle frames, frame lists, frame sequences, and clip crops from the loaded video"
export script_author      = "Kiterow"
export script_version     = "1.5.9"
export script_namespace   = "kite.Snapshoter"
HOTKEY_MENU_ROOT = ": Kite Hotkeys :"
HOTKEY_MENU_SCRIPT = "Snapshoter"

DependencyControl = require "l0.DependencyControl"
depctrl = DependencyControl{
  feed: "https://raw.githubusercontent.com/Kitherow/Kite-Aegisub-Scripts/main/DependencyControl.json",
  {
    {"a-mo.LineCollection", version: "1.3.0", url: "https://github.com/TypesettingTools/Aegisub-Motion",
      feed: "https://raw.githubusercontent.com/TypesettingTools/Aegisub-Motion/DepCtrl/DependencyControl.json"}
    {"kite.UI", version: "1.0.0", url: "https://github.com/Kitherow/Kite-Aegisub-Scripts",
      feed: "https://raw.githubusercontent.com/Kitherow/Kite-Aegisub-Scripts/main/DependencyControl.json"}
    {"a-mo.Tags", version: "1.3.4", url: "https://github.com/TypesettingTools/Aegisub-Motion",
      feed: "https://raw.githubusercontent.com/TypesettingTools/Aegisub-Motion/DepCtrl/DependencyControl.json"}
    {"a-mo.Log", version: "1.0.0", url: "https://github.com/TypesettingTools/Aegisub-Motion",
      feed: "https://raw.githubusercontent.com/TypesettingTools/Aegisub-Motion/DepCtrl/DependencyControl.json"}
    {"l0.ASSFoundation", version: "0.5.0", url: "https://github.com/TypesettingTools/ASSFoundation",
      feed: "https://raw.githubusercontent.com/TypesettingTools/ASSFoundation/master/DependencyControl.json"}
  }
}
LineCollection, KiteUI, Tags, log, ASS = depctrl\requireModules!

ConfigHandler = (interface, file_name, _has_sections, version) ->
  KiteUI.dialogHandler interface, script_namespace, version, {
    {path: "?user/" .. file_name, format: "json_sections"}
  }

CONFIG_FILE = "kite-snapshoter.json"

isWindows = package.config\sub(1, 1) == "\\"
sep = isWindows and "\\" or "/"

CAPTURE_MODES = {
  "Selected lines"
  "Frame list"
  "Frame sequence"
  "Clip crop"
  "Manual rectangle"
  "Densest subtitle frame"
}

TIMING_MODES = {
  "Midpoint"
  "Start and end"
  "Start, middle, end"
  "Current video frame"
}

CLIP_OUTPUTS = {
  "Rectangle crop"
  "Clip alpha crop"
  "Clip alpha full frame"
  "Drawing alpha crop"
  "Drawing alpha full frame"
}

choice_or_default = (value, items, defaultValue) ->
  for item in *items
    return item if value == item
  defaultValue

normalize_mode = (value) ->
  if value == "Rectangular clip" then "Clip crop" else value

normalize_clip_output = (value) ->
  switch value
    when "Vector alpha crop" then "Clip alpha crop"
    when "Vector alpha full frame" then "Clip alpha full frame"
    else value

round_ms = (value) ->
  math.floor((tonumber(value) or 0) + 0.5)

trim = (value) ->
  text = tostring(value or "")
  text = text\gsub "^%s+", ""
  text = text\gsub "%s+$", ""
  text

file_exists = (path) ->
  file = io.open path, "rb"
  if file
    file\close!
    return true
  false

dir_name = (path) ->
  tostring(path or "")\match("^(.*)[\\/]") or ""

base_name = (path) ->
  name = tostring(path or "")\match("([^\\/]+)$") or tostring(path or "")
  name\gsub "%.[^%.]*$", ""

safe_name = (text, defaultValue = "snapshoter") ->
  value = trim(text)\gsub("[\\/:*?\"<>|]+", "_")\gsub("%s+", "_")
  value = value\gsub "_+", "_"
  value = value\gsub "^_+", ""
  value = value\gsub "_+$", ""
  value = value\gsub "[%.%s]+$", ""
  lower = value\lower!
  reserved = lower == "con" or lower == "prn" or lower == "aux" or lower == "nul" or lower\match("^com[1-9]$") or lower\match("^lpt[1-9]$")
  return defaultValue if value == "." or value == ".." or value\match("^%.+$") or reserved
  if value == "" then defaultValue else value

join_path = (left, right) ->
  left = tostring(left or "")
  right = tostring(right or "")
  return right if left == ""
  tail = left\sub -1
  if tail == "\\" or tail == "/"
    left .. right
  else
    left .. sep .. right

write_file = (path, content) ->
  file = io.open path, "w"
  return false unless file
  file\write content or ""
  file\close!
  true

read_file = (path, maxBytes = 8192) ->
  file = io.open path, "rb"
  return "" unless file
  content = file\read(maxBytes) or ""
  file\close!
  content

decoded_path = (spec) ->
  return "" unless aegisub.decode_path
  ok, path = pcall aegisub.decode_path, spec
  if ok and type(path) == "string" and path != spec
    path
  else
    ""

shell_quote = (value) ->
  value = tostring(value or "")
  if isWindows
    '"' .. value\gsub('"', '""') .. '"'
  else
    "'" .. value\gsub("'", "'\\''") .. "'"

arg_quote = (value) ->
  shell_quote value

filter_path_quote = (value) ->
  value = tostring(value or "")\gsub "\\", "/"
  value = value\gsub ":", "\\:"
  value = value\gsub "'", "\\'"
  "'" .. value .. "'"

ffmpeg_executable = (value) ->
  exe = trim value
  exe = "ffmpeg" if exe == ""
  lower = exe\lower!
  if isWindows and (lower == "ffmpeg" or lower == "ffmpeg.exe")
    for candidate in *{
      "C:\\Windows\\ffmpeg.exe"
      "C:\\Program Files\\ffmpeg\\bin\\ffmpeg.exe"
    }
      return candidate if file_exists candidate
  exe

command_quote = (value) ->
  exe = ffmpeg_executable value
  arg_quote exe

os_command = (command) ->
  command = tostring(command or "")
  if isWindows then '"' .. command .. '"' else command

ensure_dir = (path) ->
  return false if trim(path) == ""
  if isWindows
    os.execute 'cmd /c if not exist ' .. shell_quote(path) .. ' mkdir ' .. shell_quote(path)
  else
    os.execute 'mkdir -p ' .. shell_quote(path)
  true

command_ok = (status) ->
  status == true or status == 0

show_message = (text) ->
  aegisub.dialog.display {
    { class: "label", label: tostring(text or ""), x: 0, y: 0, width: 52, height: 4 }
  }, { "OK" }

video_path = ->
  path = decoded_path "?video"
  return path if path != "" and file_exists path
  props = aegisub.project_properties and aegisub.project_properties! or {}
  path = props.video_file or ""
  return path if path != "" and file_exists path
  nil

project_props = ->
  return {} unless aegisub and aegisub.project_properties
  ok, props = pcall aegisub.project_properties
  if ok and type(props) == "table" then props else {}

folder_from_file = (path) ->
  path = trim path
  return "" if path == ""
  folder = dir_name path
  if folder != "" then folder else ""

project_folder = (video) ->
  props = project_props!
  for key in *{ "filename", "script_file" }
    folder = folder_from_file props[key]
    return folder if folder != ""
  scriptDir = decoded_path "?script"
  return scriptDir if scriptDir != ""
  dir_name video

snapshots_folder = (video) ->
  join_path project_folder(video), "Snapshots"

temp_folder = (fallback) ->
  fallback

ass_time = (ms) ->
  ms = math.max 0, round_ms(ms)
  h = math.floor(ms / 3600000)
  m = math.floor((ms % 3600000) / 60000)
  s = math.floor((ms % 60000) / 1000)
  cs = math.floor((ms % 1000) / 10)
  string.format "%d:%02d:%02d.%02d", h, m, s, cs

file_time = (ms) ->
  ms = math.max 0, round_ms(ms)
  h = math.floor(ms / 3600000)
  m = math.floor((ms % 3600000) / 60000)
  s = math.floor((ms % 60000) / 1000)
  mm = ms % 1000
  string.format "%02d-%02d-%02d-%03d", h, m, s, mm

ffmpeg_time = (ms) ->
  string.format "%.3f", math.max(0, tonumber(ms) or 0) / 1000

clean_text = (text) ->
  text = tostring(text or "")\gsub "%b{}", ""
  text = text\gsub "\\[Nnh]", " "
  text = text\gsub "%s+", " "
  trim(text)

frame_duration_ms = (ms) ->
  frame = aegisub.frame_from_ms(ms)
  now = aegisub.ms_from_frame(frame)
  nextMs = aegisub.ms_from_frame(frame + 1)
  if nextMs and now and nextMs > now then nextMs - now else 1

current_video_frame = ->
  return nil unless aegisub.project_properties
  ok, props = pcall aegisub.project_properties
  return nil unless ok and props
  return nil if props.video_position == nil
  tonumber props.video_position

line_intervals = (lines) ->
  raw = {}
  for line in *lines
    startFrame = aegisub.frame_from_ms line.start_time
    endFrame = aegisub.frame_from_ms math.max(line.start_time, line.end_time - 1)
    if startFrame and endFrame
      endFrame = startFrame if endFrame < startFrame
      table.insert raw, { first: startFrame, last: endFrame }
  table.sort raw, (a, b) ->
    if a.first == b.first then a.last < b.last else a.first < b.first
  merged = {}
  for item in *raw
    last = merged[#merged]
    if last and item.first <= last.last + 1
      last.last = item.last if item.last > last.last
    else
      table.insert merged, { first: item.first, last: item.last }
  merged

frame_in_intervals = (frame, intervals) ->
  for item in *(intervals or {})
    return true if frame >= item.first and frame <= item.last
  false

collect_effect_frames = (lines, intervals) ->
  seen, out = {}, {}
  for line in *lines
    effect = tostring line.effect or ""
    for token in effect\gmatch "[^;,%s]+"
      raw = token\match "^[Ff]?(%d+)$"
      raw = token\match("^[Ff]?(%d+)[Ff]?$") unless raw
      if raw
        frame = tonumber raw
        if frame and frame_in_intervals(frame, intervals) and not seen[frame]
          seen[frame] = true
          table.insert out, frame
  table.sort out
  out

default_frame_list = (lines) ->
  unless lines and #lines > 0
    frame = current_video_frame!
    return if frame then { frame } else {}
  intervals = line_intervals lines
  effectFrames = collect_effect_frames lines, intervals
  return effectFrames if #effectFrames > 0
  frame = current_video_frame!
  return { frame } if frame and frame_in_intervals frame, intervals
  out = {}
  for item in *intervals
    table.insert out, item.first
  out

parse_frame_token = (token) ->
  token = trim token
  return nil if token == ""
  raw = token\match "^[Ff]?(%d+)[Ff]?$"
  if raw then tonumber raw else nil

parse_frame_list = (text) ->
  frames, seen, errors = {}, {}, {}
  for rawLine in tostring(text or "")\gmatch "[^\n]+"
    line = trim rawLine\gsub("^%-%-%s*", "")
    if line != ""
      line = line\gsub "%f[%a][Ff][Aa][Dd][Ee]%f[%A]%s+[^,%s;]+", ""
      line = line\match("^(.-)>") or line
      for token in line\gmatch "[^,%s;]+"
        frame = parse_frame_token token
        if frame
          unless seen[frame]
            seen[frame] = true
            table.insert frames, frame
        else
          table.insert errors, "Invalid frame token: #{token}"
  table.sort frames
  frames, errors

build_frame_defaults = (frames) ->
  items = {}
  for frame in *(frames or {})
    table.insert items, "#{frame}f"
  table.concat items, " "

line_contains_frame = (line, frame) ->
  return false unless line and frame
  startMs = tonumber(line.start_time) or 0
  endMs = tonumber(line.end_time) or startMs
  startFrame = aegisub.frame_from_ms startMs
  endFrame = aegisub.frame_from_ms math.max(startMs, endMs - 1)
  startFrame and endFrame and frame >= startFrame and frame <= endFrame

line_points = (line, timingMode, currentFrame = nil) ->
  startMs = tonumber(line.start_time) or 0
  endMs = tonumber(line.end_time) or startMs
  midMs = startMs + (endMs - startMs) / 2
  if timingMode == "Current video frame"
    frame = currentFrame or current_video_frame!
    return {} unless frame
    frame = math.floor((tonumber(frame) or 0) + 0.5)
    return {} unless line_contains_frame line, frame
    time = aegisub.ms_from_frame frame
    return {} unless time
    {
      { key: "current", label: "current frame", time: time, frame: frame }
    }
  elseif timingMode == "Start and end"
    lastMs = math.max startMs, endMs - frame_duration_ms(endMs)
    {
      { key: "start", label: "start", time: startMs }
      { key: "end", label: "end", time: lastMs }
    }
  elseif timingMode == "Start, middle, end"
    lastMs = math.max startMs, endMs - frame_duration_ms(endMs)
    {
      { key: "start", label: "start", time: startMs }
      { key: "mid", label: "midpoint", time: midMs }
      { key: "end", label: "end", time: lastMs }
    }
  else
    {
      { key: "mid", label: "midpoint", time: midMs }
    }

selected_lines = (subs, sel) ->
  collection = LineCollection subs, sel, ((line) -> line.class == "dialogue" and not line.comment and line.end_time and line.end_time > line.start_time), true
  lines = {}
  for line in *collection.lines
    table.insert lines, line if line.end_time > line.start_time
  table.sort lines, (a, b) -> (a.number or 0) < (b.number or 0)
  collection, lines

video_size = ->
  width, height = aegisub.video_size!
  tonumber(width) or 0, tonumber(height) or 0

normalize_crop = (x, y, w, h, padding, videoW, videoH) ->
  padding = math.max 0, tonumber(padding) or 0
  x1 = math.floor((tonumber(x) or 0) - padding)
  y1 = math.floor((tonumber(y) or 0) - padding)
  x2 = math.ceil((tonumber(x) or 0) + (tonumber(w) or 0) + padding)
  y2 = math.ceil((tonumber(y) or 0) + (tonumber(h) or 0) + padding)
  x1 = math.max 0, math.min(videoW - 1, x1)
  y1 = math.max 0, math.min(videoH - 1, y1)
  x2 = math.max x1 + 1, math.min(videoW, x2)
  y2 = math.max y1 + 1, math.min(videoH, y2)
  {
    x: x1
    y: y1
    w: x2 - x1
    h: y2 - y1
  }

scale_clip_rect = (rect, collection, cfg) ->
  videoW, videoH = cfg.videoW, cfg.videoH
  playX = tonumber(collection.meta and collection.meta.PlayResX) or videoW
  playY = tonumber(collection.meta and collection.meta.PlayResY) or videoH
  sx = if playX > 0 then videoW / playX else 1
  sy = if playY > 0 then videoH / playY else 1
  x1 = math.min(rect.x1, rect.x2) * sx
  y1 = math.min(rect.y1, rect.y2) * sy
  x2 = math.max(rect.x1, rect.x2) * sx
  y2 = math.max(rect.y1, rect.y2) * sy
  normalize_crop x1, y1, x2 - x1, y2 - y1, cfg.cropPadding, videoW, videoH

manual_crop = (cfg) ->
  normalize_crop cfg.manualX, cfg.manualY, cfg.manualW, cfg.manualH, cfg.cropPadding, cfg.videoW, cfg.videoH

extend_bounds = (bounds, x, y) ->
  x, y = tonumber(x), tonumber(y)
  return false unless x and y
  if bounds.x1 == nil
    bounds.x1, bounds.x2 = x, x
    bounds.y1, bounds.y2 = y, y
  else
    bounds.x1 = math.min bounds.x1, x
    bounds.y1 = math.min bounds.y1, y
    bounds.x2 = math.max bounds.x2, x
    bounds.y2 = math.max bounds.y2, y
  true

bounds_rect = (bounds) ->
  return nil unless bounds and bounds.x1 != nil and bounds.y1 != nil and bounds.x2 != nil and bounds.y2 != nil
  { x1: bounds.x1, y1: bounds.y1, x2: bounds.x2, y2: bounds.y2 }

rect_from_payload = (payload) ->
  x1, y1, x2, y2 = tostring(payload or "")\match "^%s*([%+%-]?%d*%.?%d+)%s*,%s*([%+%-]?%d*%.?%d+)%s*,%s*([%+%-]?%d*%.?%d+)%s*,%s*([%+%-]?%d*%.?%d+)%s*$"
  x1, y1, x2, y2 = tonumber(x1), tonumber(y1), tonumber(x2), tonumber(y2)
  return nil unless x1 and y1 and x2 and y2
  { :x1, :y1, :x2, :y2 }

vector_payload_parts = (payload) ->
  body = trim payload
  scale = 1
  rawScale, rest = body\match "^([%+%-]?%d*%.?%d+)%s*,%s*(.+)$"
  if rawScale and rest and rest\match "^%s*[mM]%s"
    scale = tonumber(rawScale) or 1
    body = rest
  body, scale

clip_vector_rect_from_payload = (payload) ->
  body, scale = vector_payload_parts payload
  return nil unless body\match "^%s*[mM]%s"
  divisor = math.pow 2, scale - 1
  divisor = 1 unless divisor and divisor > 0
  bounds = {}
  pattern = "([%+%-]?%d*%.?%d+)%s+([%+%-]?%d*%.?%d+)"
  for rawX, rawY in body\gmatch pattern
    x, y = tonumber(rawX), tonumber(rawY)
    extend_bounds bounds, x / divisor, y / divisor if x and y
  bounds_rect bounds

clip_info_from_payload = (name, payload) ->
  name = tostring(name or "clip")
  payload = trim payload
  rect = if payload\match "^%s*[mM]%s" or payload\match "^%s*[%+%-]?%d*%.?%d+%s*,%s*[mM]%s"
    clip_vector_rect_from_payload payload
  else
    rect_from_payload payload
  return nil unless rect
  { rect: rect, tag: "\\#{name}(#{payload})", isVector: payload\match("[mM]") != nil }

clip_info_from_tags = (text) ->
  for name, raw in tostring(text or "")\gmatch "\\(i?clip)%s*(%b())"
    info = clip_info_from_payload name, raw\sub 2, -2
    return info if info
  nil

assf_tag_name = (tag) ->
  if tag and tag.__tag then tag.__tag.name else nil

clip_info_from_assf = (clip) ->
  name = assf_tag_name clip
  return nil unless name
  tagName = if name\match "^iclip" then "iclip" else "clip"
  if name == "clip_rect" or name == "iclip_rect"
    x1, y1, x2, y2 = clip\getTagParams!
    payload = "#{x1},#{y1},#{x2},#{y2}"
    return clip_info_from_payload tagName, payload
  if name == "clip_vect" or name == "iclip_vect"
    if clip.getTagParams
      ok, a, b = pcall -> clip\getTagParams!
      if ok
        if type(a) == "string"
          return clip_info_from_payload tagName, a
        elseif type(b) == "string"
          return clip_info_from_payload tagName, "#{a},#{b}"
  nil

line_clip_info = (line) ->
  info = clip_info_from_tags line.text
  return info if info
  ok, data = pcall -> ASS\parse line
  return nil unless ok and data
  clips = data\getTags { "clip_rect", "iclip_rect", "clip_vect", "iclip_vect" }
  return nil unless clips and #clips > 0
  clip_info_from_assf clips[1]

last_drawing_level = (tagBody) ->
  level = nil
  for raw in tostring(tagBody or "")\gmatch "\\p([%+%-]?%d*%.?%d+)"
    number = tonumber raw
    level = number if number
  level

mask_tag_block = (block) ->
  body = tostring(block or "")\sub 2, -2
  "{#{body}\\1c&HFFFFFF&\\2c&HFFFFFF&\\3c&HFFFFFF&\\4c&HFFFFFF&\\alpha&H00&}"

drawing_mask_text = (line) ->
  text = tostring(line and line.text or "")
  parts, drawingLevel, hasDrawing, index = {}, 0, false, 1
  while index <= #text
    startPos, endPos = text\find "{[^}]*}", index
    if startPos
      chunk = text\sub index, startPos - 1
      if drawingLevel > 0 and trim(chunk) != ""
        table.insert parts, chunk
        hasDrawing = true
      block = text\sub startPos, endPos
      table.insert parts, mask_tag_block block
      level = last_drawing_level(block\sub(2, -2))
      drawingLevel = level if level
      index = endPos + 1
    else
      chunk = text\sub index
      if drawingLevel > 0 and trim(chunk) != ""
        table.insert parts, chunk
        hasDrawing = true
      break
  if hasDrawing then table.concat(parts, "") else nil

line_drawing_info = (line) ->
  text = drawing_mask_text line
  return nil unless text
  { text: text }

densest_frame = (lines) ->
  events = {}
  for line in *lines
    log.checkCancellation!
    startFrame = aegisub.frame_from_ms line.start_time
    endFrame = math.max startFrame, aegisub.frame_from_ms(line.end_time) - 1
    table.insert events, { frame: startFrame, delta: 1 }
    table.insert events, { frame: endFrame + 1, delta: -1 }
  table.sort events, (a, b) ->
    if a.frame == b.frame then a.delta > b.delta else a.frame < b.frame
  active, bestCount, bestFrame = 0, 0, nil
  i = 1
  while i <= #events
    frame = events[i].frame
    while i <= #events and events[i].frame == frame
      active += events[i].delta
      i += 1
    if active > bestCount
      bestCount = active
      bestFrame = frame
  bestFrame, bestCount

shot_name = (seq, line, point, mode, includeText, extra = nil) ->
  parts = {
    string.format "%04d", seq
    line and string.format("L%04d", line.number or 0) or "dense"
    point.key
    file_time(point.time)
  }
  table.insert parts, extra if extra
  if includeText and line
    label = safe_name(clean_text(line.text), "")\sub 1, 48
    table.insert parts, label if label != ""
  table.concat(parts, "_") .. ".png"

frame_shot_name = (seq, frame, time) ->
  string.format "%04d_F%06d_%s.png", seq, frame, file_time(time)

clip_output_extra = (clipOutput) ->
  switch clipOutput
    when "Clip alpha crop" then "clip_alpha_crop"
    when "Clip alpha full frame" then "clip_alpha_full"
    when "Drawing alpha crop" then "drawing_alpha_crop"
    when "Drawing alpha full frame" then "drawing_alpha_full"
    else "crop"

draw_rect_shape = (w, h) ->
  w = math.floor((tonumber(w) or 1) + 0.5)
  h = math.floor((tonumber(h) or 1) + 0.5)
  "m 0 0 l #{w} 0 #{w} #{h} 0 #{h}"

clip_mask_text = (clipTag, playX, playY) ->
  "{\\an7\\pos(0,0)\\p1\\bord0\\shad0\\blur0\\1c&HFFFFFF&\\alpha&H00&#{clipTag}}#{draw_rect_shape playX, playY}"

make_jobs = (collection, lines, cfg) ->
  jobs, skipped, errors, seq = {}, {}, {}, 0
  mode = normalize_mode cfg.mode
  if mode == "Frame list"
    frames, parseErrors = parse_frame_list cfg.frameText
    return jobs, skipped, parseErrors if #parseErrors > 0
    return jobs, skipped, { "No valid frames were listed." } if #frames == 0
    for frame in *frames
      time = aegisub.ms_from_frame frame
      if time
        seq += 1
        table.insert jobs, {
          time: time
          frame: frame
          name: frame_shot_name seq, frame, time
          subtitle: ""
          label: "frame #{frame}"
          mode: mode
        }
      else
        table.insert errors, "Could not convert frame to milliseconds: #{frame}"
    return jobs, skipped, errors

  return jobs, skipped, { "Select at least one timed dialogue line." } unless lines and #lines > 0

  manualRect = manual_crop(cfg) if mode == "Manual rectangle"
  currentFrame = nil
  if cfg.timing == "Current video frame"
    currentFrame = current_video_frame!
    return jobs, skipped, { "Current video frame is unavailable. Open a video and place the playhead on the frame you want." } unless currentFrame

  if mode == "Densest subtitle frame"
    frame, count = densest_frame lines
    return jobs, skipped, errors unless frame
    time = aegisub.ms_from_frame(frame)
    seq += 1
    table.insert jobs, {
      time: time
      frame: frame
      name: shot_name seq, nil, { key: "dense", time: time }, mode, false, "#{count}lines"
      subtitle: ""
      label: "densest frame"
      mode: mode
      overlap: count
    }
    return jobs, skipped, errors

  currentFrameTouchesLine = false
  for line in *lines
    log.checkCancellation!
    rect = nil
    alphaMaskText, alphaCrop, alphaDetectCrop = nil, nil, false
    currentFrameTouchesLine = true if currentFrame and line_contains_frame line, currentFrame
    if mode == "Clip crop"
      if cfg.clipOutput == "Drawing alpha crop" or cfg.clipOutput == "Drawing alpha full frame"
        drawingInfo = line_drawing_info line
        if drawingInfo
          alphaMaskText = drawingInfo.text
          alphaDetectCrop = cfg.clipOutput == "Drawing alpha crop"
        else
          table.insert skipped, line.number
          continue
      else
        clipInfo = line_clip_info line
        if clipInfo and clipInfo.rect
          scaledRect = scale_clip_rect clipInfo.rect, collection, cfg
          if cfg.clipOutput == "Clip alpha crop"
            alphaMaskText = clip_mask_text clipInfo.tag, cfg.playX, cfg.playY
            alphaCrop = scaledRect
          elseif cfg.clipOutput == "Clip alpha full frame"
            alphaMaskText = clip_mask_text clipInfo.tag, cfg.playX, cfg.playY
          else
            rect = scaledRect
        else
          table.insert skipped, line.number
          continue
    elseif mode == "Manual rectangle"
      rect = manualRect

    points = line_points line, cfg.timing, currentFrame
    continue if #points == 0
    for point in *points
      seq += 1
      extra = if rect or alphaMaskText then clip_output_extra(cfg.clipOutput) else nil
      table.insert jobs, {
        time: point.time
        frame: point.frame or aegisub.frame_from_ms(point.time)
        name: shot_name seq, line, point, mode, cfg.includeText, extra
        subtitle: line.number
        label: point.label
        mode: mode
        crop: rect
        alphaMaskText: alphaMaskText
        alphaCrop: alphaCrop
        alphaDetectCrop: alphaDetectCrop
      }
  if cfg.timing == "Current video frame" and #jobs == 0 and not currentFrameTouchesLine
    table.insert errors, "The current video frame is not inside any selected line."
  jobs, skipped, errors

crop_filter = (crop) ->
  string.format "crop=%d:%d:%d:%d", crop.w, crop.h, crop.x, crop.y

run_command = (command, errPath = nil) ->
  if errPath and errPath != ""
    return nil unless write_file errPath, ""
    os.execute os_command("#{command} 2> #{arg_quote(errPath)}")
  else
    os.execute os_command(command)

ffmpeg_error_path = (outDir, job, suffix = "error") ->
  join_path temp_folder(outDir), "_snapshoter_ffmpeg_#{safe_name(base_name(job.name), "capture")}_#{suffix}.txt"

ffmpeg_error_message = (label, path, errPath) ->
  details = trim(read_file(errPath, 6000))
  message = "FFmpeg returned an error while #{label}:\n#{path}"
  if details != ""
    message ..= "\n\nFFmpeg:\n#{details}"
  else
    message ..= "\n\nFFmpeg did not write stderr. Check that the output folder can create temporary files and PNG files."
  message

run_ffmpeg = (command, outDir, job, label, path) ->
  errPath = ffmpeg_error_path outDir, job, safe_name(label, "error")
  status = run_command command, errPath
  if status == nil and not file_exists errPath
    return false, "Snapshoter could not create a temporary FFmpeg stderr file:\n#{errPath}\n\nCheck write access to the output folder."
  if command_ok status
    os.remove errPath
    return true, nil
  message = ffmpeg_error_message label, path, errPath
  os.remove errPath
  false, message

mask_ass_path = (outDir, job) ->
  join_path temp_folder(outDir), "_snapshoter_mask_#{safe_name(base_name(job.name), "mask")}.ass"

alpha_temp_path = (outDir, job) ->
  join_path temp_folder(outDir), "_snapshoter_alpha_#{safe_name(base_name(job.name), "alpha")}.png"

mask_ass_text = (text) ->
  text = tostring(text or "")\gsub "\r\n", "\\N"
  text\gsub "[\r\n]", "\\N"

write_mask_ass = (path, maskText, playX, playY) ->
  playX = math.floor((tonumber(playX) or 0) + 0.5)
  playY = math.floor((tonumber(playY) or 0) + 0.5)
  return false if playX <= 0 or playY <= 0
  rows = {
    "[Script Info]"
    "ScriptType: v4.00+"
    "PlayResX: #{playX}"
    "PlayResY: #{playY}"
    ""
    "[V4+ Styles]"
    "Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding"
    "Style: Mask,Arial,20,&H00FFFFFF&,&H00FFFFFF&,&H00000000&,&H00000000&,0,0,0,0,100,100,0,0,1,0,0,7,0,0,0,1"
    ""
    "[Events]"
    "Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text"
    "Dialogue: 0,0:00:00.00,0:00:01.00,Mask,,0000,0000,0000,,#{mask_ass_text maskText}"
  }
  write_file path, table.concat(rows, "\n")

capture_command = (video, ffmpeg, job, outPath) ->
  command = command_quote(ffmpeg) ..
    " -hide_banner -loglevel error -y -ss " .. ffmpeg_time(job.time) ..
    " -i " .. arg_quote(video) ..
    " -frames:v 1"
  if job.crop
    command ..= " -vf " .. arg_quote(crop_filter job.crop)
  command ..= " " .. arg_quote(outPath)
  command

alpha_capture_command = (video, ffmpeg, job, outPath, maskPath, videoW, videoH) ->
  assFilter = filter_path_quote maskPath
  filter = "[1:v]format=rgb24,subtitles=#{assFilter},format=gray,lut=y='min(255,val*255/235)'[mask];[0:v]format=rgba[base];[base][mask]alphamerge"
  filter ..= ",#{crop_filter job.alphaCrop}" if job.alphaCrop
  filter ..= "[out]"
  sourceW = math.floor((tonumber(videoW) or 1) + 0.5)
  sourceH = math.floor((tonumber(videoH) or 1) + 0.5)
  source = "color=c=black:s=#{sourceW}x#{sourceH}:d=1"
  command_quote(ffmpeg) ..
    " -hide_banner -loglevel error -y -ss " .. ffmpeg_time(job.time) ..
    " -i " .. arg_quote(video) ..
    " -f lavfi -i " .. arg_quote(source) ..
    " -filter_complex " .. arg_quote(filter) ..
    " -map " .. arg_quote("[out]") ..
    " -frames:v 1 " .. arg_quote(outPath)

cropdetect_command = (ffmpeg, imagePath) ->
  command_quote(ffmpeg) ..
    " -hide_banner -loglevel info -y" ..
    " -i " .. arg_quote(imagePath) ..
    " -vf " .. arg_quote("alphaextract,cropdetect=limit=1:round=2:reset=0:skip=0") ..
    " -frames:v 1 -f null -"

parse_cropdetect = (text) ->
  crop = nil
  for w, h, x, y in tostring(text or "")\gmatch "crop=(%d+):(%d+):(%d+):(%d+)"
    crop = { w: tonumber(w), h: tonumber(h), x: tonumber(x), y: tonumber(y) }
  crop

detect_alpha_crop = (ffmpeg, imagePath, outDir, job) ->
  errPath = ffmpeg_error_path outDir, job, "cropdetect"
  command = cropdetect_command ffmpeg, imagePath
  status = run_command command, errPath
  details = read_file errPath, 12000
  os.remove errPath
  detailsText = trim details
  return nil, "FFmpeg returned an error while detecting alpha bounds:\n#{imagePath}\n\nFFmpeg:\n#{detailsText}" unless command_ok status
  crop = parse_cropdetect details
  return nil, "FFmpeg could not detect a non-transparent alpha area in:\n#{imagePath}" unless crop
  crop, nil

crop_png_command = (ffmpeg, imagePath, crop, outPath) ->
  command_quote(ffmpeg) ..
    " -hide_banner -loglevel error -y" ..
    " -i " .. arg_quote(imagePath) ..
    " -vf " .. arg_quote(crop_filter crop) ..
    " -frames:v 1 " .. arg_quote(outPath)

job_without_alpha_crop = (job) ->
  copy = {}
  for key, value in pairs job
    copy[key] = value
  copy.alphaCrop = nil
  copy

run_capture_jobs = (video, outDir, cfg, jobs) ->
  ensure_dir outDir
  for job in *jobs
    outPath = join_path outDir, job.name
    if job.alphaMaskText
      maskPath = mask_ass_path outDir, job
      ok = write_mask_ass maskPath, job.alphaMaskText, cfg.playX, cfg.playY
      return false, "Snapshoter could not write the temporary vector mask." unless ok
      if job.alphaDetectCrop
        tempPath = alpha_temp_path outDir, job
        fullJob = job_without_alpha_crop job
        ok, message = run_ffmpeg alpha_capture_command(video, cfg.ffmpeg, fullJob, tempPath, maskPath, cfg.videoW, cfg.videoH), outDir, job, "writing alpha mask", tempPath
        unless ok
          os.remove maskPath
          os.remove tempPath
          return false, message
        crop, message = detect_alpha_crop cfg.ffmpeg, tempPath, outDir, job
        unless crop
          os.remove maskPath
          os.remove tempPath
          return false, message
        ok, message = run_ffmpeg crop_png_command(cfg.ffmpeg, tempPath, crop, outPath), outDir, job, "writing cropped PNG", outPath
        os.remove tempPath
        unless ok
          os.remove maskPath
          return false, message
      else
        ok, message = run_ffmpeg alpha_capture_command(video, cfg.ffmpeg, job, outPath, maskPath, cfg.videoW, cfg.videoH), outDir, job, "writing PNG", outPath
        unless ok
          os.remove maskPath
          return false, message
      os.remove maskPath
    else
      ok, message = run_ffmpeg capture_command(video, cfg.ffmpeg, job, outPath), outDir, job, "writing PNG", outPath
      return false, message unless ok
  true, nil

ass_field = (value, fallback = "") ->
  value = tostring(value or fallback)
  value = value\gsub "[\r\n]", " "
  value\gsub ",", " "

ass_text = (value) ->
  value = tostring(value or "")
  value = value\gsub "\r\n", "\\N"
  value\gsub "[\r\n]", "\\N"

ass_number = (value, fallback = 0) ->
  number = tonumber value
  if number then number else fallback

ass_int = (value, fallback = 0) ->
  math.floor(ass_number(value, fallback) + 0.5)

ass_bool = (value) ->
  if value == true
    -1
  elseif value == false or value == nil
    0
  else
    ass_int value, 0

ass_color = (value, fallback = "&H00FFFFFF&") ->
  if type(value) == "number"
    number = value
    number += 4294967296 if number < 0
    return string.format "&H%08X&", number % 4294967296
  text = trim value
  if text == "" then fallback else text

style_ass_line = (style) ->
  values = {
    ass_field style.name, "Default"
    ass_field style.fontname, "Arial"
    tostring ass_number(style.fontsize, 20)
    ass_color style.color1, "&H00FFFFFF&"
    ass_color style.color2, "&H000000FF&"
    ass_color style.color3, "&H00000000&"
    ass_color style.color4, "&H00000000&"
    tostring ass_bool(style.bold)
    tostring ass_bool(style.italic)
    tostring ass_bool(style.underline)
    tostring ass_bool(style.strikeout)
    tostring ass_number(style.scale_x, 100)
    tostring ass_number(style.scale_y, 100)
    tostring ass_number(style.spacing, 0)
    tostring ass_number(style.angle, 0)
    tostring ass_int(style.borderstyle, 1)
    tostring ass_number(style.outline, 2)
    tostring ass_number(style.shadow, 0)
    tostring ass_int(style.align, 2)
    tostring ass_int(style.margin_l, 10)
    tostring ass_int(style.margin_r, 10)
    tostring ass_int(style.margin_t or style.margin_v, 10)
    tostring ass_int(style.encoding, 1)
  }
  "Style: " .. table.concat values, ","

default_style_line = ->
  "Style: Default,Arial,20,&H00FFFFFF&,&H000000FF&,&H00000000&,&H00000000&,0,0,0,0,100,100,0,0,1,2,0,2,10,10,10,1"

dialogue_ass_line = (line, range) ->
  return nil unless line and line.class == "dialogue" and not line.comment
  lineStart = ass_int line.start_time, 0
  lineEnd = ass_int line.end_time, lineStart
  return nil if lineEnd <= range.startMs or lineStart >= range.endMs
  startMs = math.max 0, ass_int(lineStart - range.startMs, 0)
  endMs = math.min range.durationMs, ass_int(lineEnd - range.startMs, range.durationMs)
  endMs = math.min range.durationMs, math.max(startMs + 1, endMs)
  return nil if endMs <= startMs
  values = {
    "Dialogue: " .. tostring(ass_int(line.layer, 0))
    ass_time startMs
    ass_time endMs
    ass_field line.style, "Default"
    ass_field line.actor, ""
    string.format "%04d", ass_int(line.margin_l, 0)
    string.format "%04d", ass_int(line.margin_r, 0)
    string.format "%04d", ass_int(line.margin_t or line.margin_v, 0)
    ass_field line.effect, ""
    ass_text line.text
  }
  table.concat values, ","

sequence_range = (lines) ->
  intervals = line_intervals lines
  return nil unless #intervals > 0
  startFrame = intervals[1].first
  endFrame = intervals[1].last
  for item in *intervals
    startFrame = math.min startFrame, item.first
    endFrame = math.max endFrame, item.last
  startMs = aegisub.ms_from_frame startFrame
  endMs = aegisub.ms_from_frame(endFrame + 1)
  return nil unless startMs and endMs and endMs > startMs
  {
    :startFrame
    :endFrame
    frameCount: endFrame - startFrame + 1
    :startMs
    :endMs
    durationMs: endMs - startMs
  }

write_sequence_ass = (subs, assPath, range, videoW, videoH) ->
  rows = { "[Script Info]" }
  hasScriptType, hasPlayResX, hasPlayResY = false, false, false
  for i = 1, #subs
    line = subs[i]
    if line and line.class == "info" and line.key
      key = trim line.key
      value = tostring(line.value or "")
      if key != ""
        lower = key\lower!
        hasScriptType = true if lower == "scripttype"
        hasPlayResX = true if lower == "playresx"
        hasPlayResY = true if lower == "playresy"
        table.insert rows, "#{key}: #{value}"
  table.insert rows, "ScriptType: v4.00+" unless hasScriptType
  table.insert rows, "PlayResX: #{ass_int(videoW, 0)}" unless hasPlayResX or ass_int(videoW, 0) <= 0
  table.insert rows, "PlayResY: #{ass_int(videoH, 0)}" unless hasPlayResY or ass_int(videoH, 0) <= 0
  table.insert rows, ""
  table.insert rows, "[V4+ Styles]"
  table.insert rows, "Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding"
  styleCount = 0
  for i = 1, #subs
    line = subs[i]
    if line and line.class == "style"
      table.insert rows, style_ass_line line
      styleCount += 1
  table.insert rows, default_style_line! if styleCount == 0
  table.insert rows, ""
  table.insert rows, "[Events]"
  table.insert rows, "Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text"
  rendered = 0
  for i = 1, #subs
    line = subs[i]
    row = dialogue_ass_line line, range
    if row
      table.insert rows, row
      rendered += 1
  ok = write_file assPath, table.concat(rows, "\n")
  ok, rendered

sequence_outputs = (cfg) ->
  {
    clean: if cfg.captureClean == nil then true else cfg.captureClean == true
    withSubtitles: cfg.captureWithSubtitles == true
    subtitlesOnly: cfg.captureSubtitlesOnly == true
  }

sequence_output_count = (outputs) ->
  count = 0
  count += 1 if outputs.clean
  count += 1 if outputs.withSubtitles
  count += 1 if outputs.subtitlesOnly
  count

run_id = (prefix) ->
  safe_name("#{prefix}_#{os.date("%Y%m%d_%H%M%S")}", "snapshoter")

prefix_job_names = (jobs, prefix) ->
  return unless jobs and prefix and prefix != ""
  for job in *jobs
    job.name = "#{prefix}_#{job.name}" if job and job.name

capture_batch_folder = (jobs) ->
  first = jobs and jobs[1]
  prefix = if first and first.mode then first.mode else "captures"
  run_id prefix

sequence_folder_name = (range) ->
  run_id string.format("sequence_%06d-%06d", range.startFrame, range.endFrame)

sequence_output_items = (outputs, assPath) ->
  items = {}
  table.insert items, { key: "clean", label: "No subtitles", filter: "" } if outputs.clean
  if outputs.withSubtitles or outputs.subtitlesOnly
    assFilter = filter_path_quote assPath
    table.insert items, { key: "with_subtitles", label: "With subtitles", filter: "setpts=PTS-STARTPTS,subtitles=#{assFilter}" } if outputs.withSubtitles
    table.insert items, { key: "subtitles_only", label: "Subtitles only", filter: "setpts=PTS-STARTPTS,format=rgba,colorchannelmixer=aa=0,subtitles=#{assFilter}:alpha=1,format=rgba" } if outputs.subtitlesOnly
  items

sequence_command = (video, ffmpeg, range, filter, pattern) ->
  command = command_quote(ffmpeg) ..
    " -hide_banner -loglevel error -y -ss " .. ffmpeg_time(range.startMs) ..
    " -i " .. arg_quote(video) ..
    " -an -frames:v " .. tostring(range.frameCount) ..
    " -start_number " .. tostring(range.startFrame) ..
    " -vsync 0"
  command ..= " -vf " .. arg_quote(filter) if filter and filter != ""
  command ..= " " .. arg_quote(pattern)
  command

sequence_output_dir = (snapshotsDir, sequenceDir, itemCount, item, flatten) ->
  return snapshotsDir if flatten
  return sequenceDir if itemCount == 1
  join_path sequenceDir, item.key

sequence_output_pattern = (dir, item, range, flatten, sequenceName) ->
  if flatten
    join_path dir, "#{sequenceName}_#{item.key}_%06d.png"
  else
    join_path dir, "frame_%06d.png"

run_frame_sequence = (subs, lines, video, outDir, cfg) ->
  return false, "Select at least one timed dialogue line for Frame sequence." unless lines and #lines > 0
  range = sequence_range lines
  return false, "Could not build a frame range from the selected lines." unless range
  ensure_dir outDir

  outputs = sequence_outputs cfg
  return false, "Select at least one Frame sequence output." if sequence_output_count(outputs) == 0

  assPath, rendered = "", 0
  if outputs.withSubtitles or outputs.subtitlesOnly
    assPath = join_path temp_folder(outDir), "_snapshoter_sequence_#{range.startFrame}_#{range.endFrame}_#{os.date("%Y%m%d_%H%M%S")}.ass"
    ok, count = write_sequence_ass subs, assPath, range, cfg.videoW, cfg.videoH
    return false, "Snapshoter could not write the temporary ASS file." unless ok
    rendered = count

  aegisub.progress.title "Snapshoter"
  aegisub.progress.task "Extracting frame sequence with FFmpeg"
  sequenceName = sequence_folder_name range
  sequenceDir = if cfg.flatSnapshots then outDir else join_path outDir, sequenceName
  ensure_dir sequenceDir unless cfg.flatSnapshots
  items = sequence_output_items outputs, assPath
  outputDirs = {}
  for item in *items
    dir = sequence_output_dir outDir, sequenceDir, #items, item, cfg.flatSnapshots
    ensure_dir dir
    outputDirs[item.key] = dir
    pattern = sequence_output_pattern dir, item, range, cfg.flatSnapshots, sequenceName
    status = os.execute sequence_command video, cfg.ffmpeg, range, item.filter, pattern
    unless command_ok status
      os.remove assPath if assPath != ""
      return false, "FFmpeg returned an error while writing sequence frames to:\n#{dir}"
  os.remove assPath if assPath != ""

  message = "Frame sequence written to:\n#{outDir}"
  message ..= "\nFrames: #{range.startFrame}-#{range.endFrame} (#{range.frameCount})"
  message ..= "\nSubtitle lines rendered: #{rendered or 0}"
  unless cfg.flatSnapshots
    folders = {}
    if #items == 1
      table.insert folders, sequenceDir
    else
      for item in *items
        table.insert folders, outputDirs[item.key]
    message ..= "\nFolders:\n" .. table.concat folders, "\n"
  else
    message ..= "\nImages were written directly in Snapshots."
  true, message

build_interface = (video, lineCount, frameDefaults) ->
  {
    main: {
      title: { class: "label", label: "Snapshoter", x: 0, y: 0, width: 4, height: 1 }
      count: { class: "label", label: "Selected dialogue lines: #{lineCount}", x: 4, y: 0, width: 8, height: 1 }
      modeLabel: { class: "label", label: "Capture", x: 0, y: 1, width: 2, height: 1 }
      mode: { class: "dropdown", value: "Selected lines", items: CAPTURE_MODES, config: true, x: 2, y: 1, width: 5, height: 1 }
      timingLabel: { class: "label", label: "Timing", x: 7, y: 1, width: 2, height: 1 }
      timing: { class: "dropdown", value: "Midpoint", items: TIMING_MODES, config: true, x: 9, y: 1, width: 5, height: 1 }
      clipOutputLabel: { class: "label", label: "Vector output", x: 0, y: 2, width: 2, height: 1 }
      clipOutput: { class: "dropdown", value: "Rectangle crop", items: CLIP_OUTPUTS, config: true, x: 2, y: 2, width: 6, height: 1 }
      outputInfo: { class: "label", label: "Output: project folder / Snapshots", x: 0, y: 3, width: 14, height: 1 }
      includeText: { class: "checkbox", label: "Add subtitle text to filenames", value: true, config: true, x: 2, y: 4, width: 6, height: 1 }
      flatSnapshots: { class: "checkbox", label: "All images in Snapshots", value: false, config: true, x: 12, y: 4, width: 5, height: 1 }
      sequenceInfo: { class: "label", label: "Frame sequence outputs", x: 0, y: 5, width: 4, height: 1 }
      captureClean: { class: "checkbox", label: "No subtitles", value: true, config: true, x: 4, y: 5, width: 4, height: 1 }
      captureWithSubtitles: { class: "checkbox", label: "With subtitles", value: false, config: true, x: 8, y: 5, width: 4, height: 1 }
      captureSubtitlesOnly: { class: "checkbox", label: "Subtitles only", value: false, config: true, x: 12, y: 5, width: 4, height: 1 }
      frameInfo: { class: "label", label: "Frame list mode accepts: 120f, 130f or 120f > P1 fade 6f.", x: 0, y: 6, width: 14, height: 1 }
      frameText: { class: "textbox", value: frameDefaults or "", config: false, x: 2, y: 7, width: 12, height: 4 }
      rectInfo: { class: "label", label: "Rectangle uses \\clip/\\iclip bounds. Drawing alpha uses selected \\p vector lines.", x: 0, y: 11, width: 14, height: 1 }
      paddingLabel: { class: "label", label: "Padding", x: 0, y: 12, width: 2, height: 1 }
      cropPadding: { class: "intedit", value: 0, min: 0, max: 256, config: true, x: 2, y: 12, width: 3, height: 1 }
      xLabel: { class: "label", label: "X", x: 5, y: 12, width: 1, height: 1 }
      manualX: { class: "intedit", value: 0, min: 0, max: 20000, config: true, x: 6, y: 12, width: 3, height: 1 }
      yLabel: { class: "label", label: "Y", x: 9, y: 12, width: 1, height: 1 }
      manualY: { class: "intedit", value: 0, min: 0, max: 20000, config: true, x: 10, y: 12, width: 3, height: 1 }
      wLabel: { class: "label", label: "W", x: 0, y: 13, width: 1, height: 1 }
      manualW: { class: "intedit", value: 320, min: 1, max: 20000, config: true, x: 1, y: 13, width: 3, height: 1 }
      hLabel: { class: "label", label: "H", x: 4, y: 13, width: 1, height: 1 }
      manualH: { class: "intedit", value: 180, min: 1, max: 20000, config: true, x: 5, y: 13, width: 3, height: 1 }
    }
    config: {
      title: { class: "label", label: "Snapshoter Config", x: 0, y: 0, width: 6, height: 1 }
      ffmpegLabel: { class: "label", label: "FFmpeg", x: 0, y: 1, width: 2, height: 1 }
      ffmpeg: { class: "edit", value: "ffmpeg", config: true, x: 2, y: 1, width: 12, height: 1 }
    }
  }

read_config = (video, lineCount, frameDefaults) ->
  interface = build_interface video, lineCount, frameDefaults
  options = ConfigHandler interface, CONFIG_FILE, true, script_version
  options\read!
  options\updateInterface "main"
  options\updateInterface "config"
  interface.main.clipOutput.value = normalize_clip_output(interface.main.clipOutput.value)
  while true
    button, result = aegisub.dialog.display interface.main, { "Execute", "Config...", "Cancel" }, { ok: "Execute", close: "Cancel" }
    return nil if button == "Cancel" or button == false
    if button == "Config..."
      cfgButton, cfgResult = aegisub.dialog.display interface.config, { "Execute", "Cancel" }, { ok: "Execute", close: "Cancel" }
      if cfgButton == "Execute"
        options\updateConfiguration cfgResult, "config"
        options\write!
        options\updateInterface "config"
      continue
    if button == "Execute"
      options\updateConfiguration result, "main"
      options\write!
      return {
        mode: choice_or_default(normalize_mode(result.mode), CAPTURE_MODES, "Selected lines")
        timing: choice_or_default(result.timing, TIMING_MODES, "Midpoint")
        clipOutput: choice_or_default(normalize_clip_output(result.clipOutput), CLIP_OUTPUTS, "Rectangle crop")
        ffmpeg: trim(interface.config.ffmpeg.value)
        includeText: result.includeText == true
        flatSnapshots: result.flatSnapshots == true
        captureClean: result.captureClean == true
        captureWithSubtitles: result.captureWithSubtitles == true
        captureSubtitlesOnly: result.captureSubtitlesOnly == true
        frameText: tostring(result.frameText or "")
        cropPadding: tonumber(result.cropPadding) or 0
        manualX: tonumber(result.manualX) or 0
        manualY: tonumber(result.manualY) or 0
        manualW: tonumber(result.manualW) or 1
        manualH: tonumber(result.manualH) or 1
      }

can_run = (subs, sel) ->
  if not aegisub.frame_from_ms or not aegisub.ms_from_frame
    return false, "Load a video before running Snapshoter."
  if not video_path!
    return false, "Load a video before running Snapshoter."
  true

snapshoter = (subs, sel) ->
  video = video_path!
  unless video
    show_message "Load a video before running Snapshoter."
    return

  collection, lines = selected_lines subs, sel or {}

  frameDefaults = build_frame_defaults default_frame_list(lines)
  cfg = read_config video, #lines, frameDefaults
  return unless cfg
  cfg.ffmpeg = "ffmpeg" if cfg.ffmpeg == ""
  cfg.videoW, cfg.videoH = video_size!
  cfg.playX = tonumber(collection.meta and collection.meta.PlayResX) or cfg.videoW
  cfg.playY = tonumber(collection.meta and collection.meta.PlayResY) or cfg.videoH

  outDir = snapshots_folder video
  ensure_dir outDir

  if cfg.mode == "Frame sequence"
    ok, message = run_frame_sequence subs, lines, video, outDir, cfg
    show_message message
    return

  jobs, skipped, errors = make_jobs collection, lines, cfg
  if #errors > 0
    show_message table.concat errors, "\n"
    return
  if #jobs == 0
    show_message "No captures were queued. Clip modes need \\clip/\\iclip; drawing modes need a selected \\p vector line."
    return
  captureDir = if cfg.flatSnapshots or #jobs == 1 then outDir else join_path outDir, capture_batch_folder jobs
  prefix_job_names jobs, run_id("capture") if captureDir == outDir
  log.debug "Snapshoter queued %d capture job(s) in %s", #jobs, captureDir

  aegisub.progress.title "Snapshoter"
  aegisub.progress.task "Capturing PNG frames with FFmpeg"
  ok, errorMessage = run_capture_jobs video, captureDir, cfg, jobs

  if ok
    message = "#{#jobs} PNG capture"
    message ..= "s" if #jobs != 1
    message ..= " written to:\n#{captureDir}"
    if captureDir != outDir
      message ..= "\nSnapshots root:\n#{outDir}"
    if #skipped > 0
      message ..= "\nSkipped #{#skipped} line(s) without usable \\clip/\\iclip."
    show_message message
  else
    show_message errorMessage

hotkey_path = HOTKEY_MENU_ROOT .. "/" .. HOTKEY_MENU_SCRIPT .. "/Execute"
if depctrl and depctrl.registerMacro
  depctrl\registerMacro script_name, script_description, snapshoter, can_run, nil, false
  depctrl\registerMacro hotkey_path, "Hotkey action. " .. script_description, snapshoter, can_run, nil, false
else
  aegisub.register_macro script_name, script_description, snapshoter, can_run
  aegisub.register_macro hotkey_path, "Hotkey action. " .. script_description, snapshoter, can_run
