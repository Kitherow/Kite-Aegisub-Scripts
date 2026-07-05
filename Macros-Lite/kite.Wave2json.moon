export script_name        = "Wave2json"
export script_description = "Export the active audio waveform to JSON."
export script_author      = "Kiterow"
export script_version     = "1.2.0"
export script_namespace   = "kite.Wave2json"
HOTKEY_MENU_ROOT = ": Kite Hotkeys :"
HOTKEY_MENU_SCRIPT = "Wave2json"

SAMPLE_RATE       = 48000
CHANNELS          = 1
BITS              = 16
BYTES_PER_SAMPLE  = 2
BASE_POINT_MS     = 1
SAMPLES_PER_POINT = SAMPLE_RATE / 1000
READ_BYTES        = 262144
MAX_STREAM_INDEX  = 63

haveDepCtrl, DependencyControl = pcall require, "l0.DependencyControl"
depctrl = nil
if haveDepCtrl and DependencyControl
  depctrl = DependencyControl{
    name: script_name
    description: script_description
    author: script_author
    version: script_version
    namespace: script_namespace
    feed: "https://raw.githubusercontent.com/Kitherow/Kite-Aegisub-Scripts/main/DependencyControl.json"
  }

is_windows = package.config\sub(1, 1) == "\\"
path_sep = is_windows and "\\" or "/"

trim = (value) ->
  text = if value == nil then "" else tostring value
  text = text\gsub "^%s+", ""
  text\gsub "%s+$", ""

round_int = (value) ->
  math.floor((tonumber(value) or 0) + 0.5)

ffmpeg_time = (ms) ->
  string.format "%.3f", math.max(0, tonumber(ms) or 0) / 1000

file_exists = (path) ->
  return false if trim(path) == ""
  file = io.open path, "rb"
  if file
    file\close!
    true
  else
    false

dir_name = (path) ->
  tostring(path or "")\match("^(.*)[\\/]") or ""

base_name = (path) ->
  name = tostring(path or "")\match("([^\\/]+)$") or tostring(path or "")
  name = name\gsub "%.[^%.\\/]*$", ""
  if name == "" then "waveform" else name

join_path = (left, right) ->
  left = tostring(left or "")
  right = tostring(right or "")
  return right if left == ""
  tail = left\sub -1
  if tail == "\\" or tail == "/"
    left .. right
  else
    left .. path_sep .. right

safe_name = (value, fallback = "wave2json") ->
  out = trim(value)\gsub("[\\/:*?\"<>|]+", "_")\gsub("%s+", "_")
  out = out\gsub "_+", "_"
  out = out\gsub "^_+", ""
  out = out\gsub "_+$", ""
  out = out\gsub "[%.%s]+$", ""
  lower = out\lower!
  reserved = lower == "con" or lower == "prn" or lower == "aux" or lower == "nul" or lower\match("^com[1-9]$") or lower\match("^lpt[1-9]$")
  return fallback if out == "" or out == "." or out == ".." or out\match("^%.+$") or reserved
  out

decoded_path = (spec) ->
  return "" unless aegisub and aegisub.decode_path
  ok, path = pcall aegisub.decode_path, spec
  if ok and type(path) == "string" and path != spec then path else ""

project_props = ->
  return {} unless aegisub and aegisub.project_properties
  ok, props = pcall aegisub.project_properties
  if ok and type(props) == "table" then props else {}

script_file_path = ->
  path = decoded_path "?script"
  if path != "" and file_exists path then path else ""

selection_range = (subs, sel) ->
  return nil, "Select at least one timed subtitle line." unless sel and #sel > 0
  start_ms, end_ms = nil, nil
  count = 0
  for index in *sel
    line = subs and subs[index]
    if line and line.class == "dialogue"
      line_start = tonumber line.start_time
      line_end = tonumber line.end_time
      if line_start and line_end and line_end > line_start
        start_ms = line_start if start_ms == nil or line_start < start_ms
        end_ms = line_end if end_ms == nil or line_end > end_ms
        count += 1
  return nil, "Select at least one subtitle line with valid timing." if count == 0
  start_ms = math.max 0, round_int start_ms
  end_ms = math.max start_ms, round_int end_ms
  return nil, "The selected subtitle time range is empty." unless end_ms > start_ms
  {
    :start_ms
    :end_ms
    duration_ms: end_ms - start_ms
    line_count: count
  }

selected_line_ranges = (subs, sel) ->
  return nil, "Select at least one timed subtitle line." unless sel and #sel > 0
  ranges = {}
  for index in *sel
    line = subs and subs[index]
    if line and line.class == "dialogue"
      line_start = tonumber line.start_time
      line_end = tonumber line.end_time
      if line_start and line_end and line_end > line_start
        start_ms = math.max 0, round_int line_start
        end_ms = math.max start_ms, round_int line_end
        if end_ms > start_ms
          ranges[#ranges + 1] = {
            :start_ms
            :end_ms
            duration_ms: end_ms - start_ms
            line_count: 1
            line_index: index
          }
  return nil, "Select at least one subtitle line with valid timing." if #ranges == 0
  ranges

media_candidate = ->
  props = project_props!
  audio = trim props.audio_file
  return audio, "audio" if audio != "" and file_exists audio
  path = decoded_path "?audio"
  return path, "audio" if path != "" and file_exists path
  "", "manual"

range_suffix = (range) ->
  return "" unless range
  "_#{round_int range.start_ms}-#{round_int range.end_ms}ms"

default_output_path = (media, range = nil) ->
  ass = script_file_path!
  root = if ass != "" then dir_name ass else dir_name media
  source = if ass != "" then ass else media
  join_path root, "#{safe_name base_name(source), "waveform"}#{range_suffix range}.waveform.json"

output_stem = (path) ->
  name = tostring(path or "")\match("([^\\/]+)$") or ""
  name = name\gsub "%.waveform%.json$", ""
  name = name\gsub "%.[^%.\\/]*$", ""
  safe_name name, "waveform"

output_root = (output_path, media) ->
  folder = dir_name output_path
  return folder if folder != ""
  folder = dir_name media
  if folder != "" then folder else decoded_path("?temp")

line_output_path = (base_output, media, range, order) ->
  folder = dir_name base_output
  folder = output_root base_output, media if folder == ""
  stem = output_stem base_output
  line_no = string.format "%03d", math.max(1, tonumber(order) or 1)
  join_path folder, "#{stem}_line#{line_no}#{range_suffix range}.waveform.json"

shell_quote = (value) ->
  value = tostring(value or "")
  if is_windows
    '"' .. value\gsub('"', '""') .. '"'
  else
    "'" .. value\gsub("'", "'\\''") .. "'"

batch_escape = (value) ->
  tostring(value or "")\gsub "%%", "%%%%"

script_quote = (value) ->
  if is_windows
    shell_quote batch_escape value
  else
    shell_quote value

command_quote = (value) ->
  exe = trim value
  exe = "ffmpeg" if exe == ""
  script_quote exe

write_file = (path, content) ->
  file = io.open path, "wb"
  return false unless file
  file\write content or ""
  file\close!
  true

remove_file = (path) ->
  os.remove path if path and path != ""

progress_title = (text) ->
  return unless aegisub and aegisub.progress and aegisub.progress.title
  pcall aegisub.progress.title, text

progress_task = (text) ->
  return unless aegisub and aegisub.progress and aegisub.progress.task
  pcall aegisub.progress.task, text

progress_set = (value) ->
  return unless aegisub and aegisub.progress and aegisub.progress.set
  pcall aegisub.progress.set, math.max(0, math.min(100, tonumber(value) or 0))

progress_cancelled = ->
  return false unless aegisub and aegisub.progress and aegisub.progress.is_cancelled
  ok, cancelled = pcall aegisub.progress.is_cancelled
  ok and cancelled == true

show_message = (text) ->
  pcall aegisub.log, tostring(text or "") .. "\n" if aegisub and aegisub.log

command_ok = (status) ->
  status == true or status == 0

unique_prefix = (folder) ->
  seed = "#{os.time!}_#{math.random 100000, 999999}"
  join_path folder, "wave2json_#{seed}"

write_ffmpeg_script = (cfg, pcm_path, log_path, script_path) ->
  stream = math.max 0, math.min MAX_STREAM_INDEX, math.floor(tonumber(cfg.stream) or 0)
  trim_args = ""
  if cfg.range and (tonumber(cfg.range.duration_ms) or 0) > 0
    trim_args = " -ss " .. ffmpeg_time(cfg.range.start_ms) .. " -t " .. ffmpeg_time(cfg.range.duration_ms)
  cmd = command_quote(cfg.ffmpeg) ..
    " -hide_banner -nostdin -loglevel error -y" ..
    " -i " .. script_quote(cfg.media) ..
    trim_args ..
    " -map 0:a:" .. tostring(stream) ..
    " -vn -ac #{CHANNELS} -ar #{SAMPLE_RATE} -f s16le " ..
    script_quote(pcm_path)
  if is_windows
    rows = {
      "@echo off"
      "setlocal"
      cmd .. " > " .. script_quote(log_path) .. " 2>&1"
      "exit /b %ERRORLEVEL%"
      ""
    }
    write_file script_path, table.concat rows, "\r\n"
  else
    rows = {
      "#!/bin/sh"
      cmd .. " > " .. script_quote(log_path) .. " 2>&1"
      "exit $?"
      ""
    }
    ok = write_file script_path, table.concat rows, "\n"
    os.execute "chmod +x " .. script_quote(script_path) if ok
    ok

run_script = (script_path) ->
  if is_windows
    os.execute 'cmd /c ' .. shell_quote(script_path)
  else
    os.execute script_quote script_path

read_config = ->
  media = media_candidate!
  return nil, "No active audio file is loaded." if trim(media) == ""
  {
    media: media
    output: default_output_path media
    ffmpeg: "ffmpeg"
    stream: 0
    range: nil
  }

new_pyramid = (temp_prefix) ->
  pyramid = {
    levels: {}
    temp_prefix: temp_prefix
  }

  pyramid.ensure_level = (self, index) ->
    state = self.levels[index]
    unless state
      scale = 2 ^ (index - 1)
      path = "#{self.temp_prefix}_level_#{index}.tmp"
      file = io.open path, "wb"
      error "Could not create temporary level file: #{path}" unless file
      state = {
        index: index
        scale: scale
        point_ms: BASE_POINT_MS * scale
        samples_per_point: SAMPLES_PER_POINT * scale
        points: 0
        path: path
        file: file
        pending_count: 0
        pending_min: 0
        pending_max: 0
      }
      self.levels[index] = state
    state

  pyramid.emit_pair = (self, index, min_value, max_value) ->
    state = self\ensure_level index
    state.file\write tostring(round_int(min_value)), ",", tostring(round_int(max_value)), "\n"
    state.points += 1
    if state.pending_count == 0
      state.pending_min = min_value
      state.pending_max = max_value
      state.pending_count = 1
    else
      cmin = math.min state.pending_min, min_value
      cmax = math.max state.pending_max, max_value
      state.pending_count = 0
      state.pending_min = 0
      state.pending_max = 0
      self\emit_pair index + 1, cmin, cmax

  pyramid.flush = (self) ->
    index = 1
    while index <= #self.levels
      state = self.levels[index]
      if state and state.pending_count == 1 and index < #self.levels
        min_value, max_value = state.pending_min, state.pending_max
        state.pending_count = 0
        state.pending_min = 0
        state.pending_max = 0
        self\emit_pair index + 1, min_value, max_value
      index += 1
    for state in *self.levels
      state.file\close! if state.file
      state.file = nil

  pyramid.cleanup = (self) ->
    for state in *(self.levels or {})
      pcall -> state.file\close! if state.file
      remove_file state.path

  pyramid

process_pcm = (pcm_path, temp_prefix, total_bytes = nil) ->
  input = io.open pcm_path, "rb"
  return nil, "Could not open decoded PCM." unless input

  pyramid = new_pyramid temp_prefix
  current_min, current_max = 32767, -32768
  samples_in_point = 0
  total_samples = 0
  bytes_read = 0
  leftover = ""

  progress_task "Reading PCM and building waveform"
  while true
    if progress_cancelled!
      input\close!
      pyramid\cleanup!
      return nil, "Cancelled."
    data = input\read READ_BYTES
    break unless data and #data > 0
    if leftover != ""
      data = leftover .. data
      leftover = ""
    if (#data % BYTES_PER_SAMPLE) == 1
      leftover = data\sub #data
      data = data\sub 1, #data - 1
    bytes_read += #data
    if total_bytes and total_bytes > 0
      progress_set 20 + 70 * math.min(1, bytes_read / total_bytes)

    pos = 1
    limit = #data
    while pos < limit
      lo = data\byte(pos)
      hi = data\byte(pos + 1)
      sample = lo + hi * 256
      sample -= 65536 if sample >= 32768
      current_min = sample if sample < current_min
      current_max = sample if sample > current_max
      samples_in_point += 1
      total_samples += 1
      if samples_in_point >= SAMPLES_PER_POINT
        pyramid\emit_pair 1, current_min, current_max
        current_min, current_max = 32767, -32768
        samples_in_point = 0
      pos += 2

  input\close!
  if samples_in_point > 0
    pyramid\emit_pair 1, current_min, current_max
  pyramid\flush!

  duration_ms = round_int total_samples * 1000 / SAMPLE_RATE
  { :pyramid, :duration_ms, :total_samples }, nil

copy_level_peaks = (out, level) ->
  file = io.open level.path, "rb"
  return false unless file
  first = true
  while true
    line = file\read "*l"
    break unless line
    if first
      first = false
    else
      out\write ","
    out\write line
  file\close!
  true

write_json = (output_path, result) ->
  out = io.open output_path, "wb"
  return false, "Could not write JSON output." unless out
  pyramid = result.pyramid
  out\write "{\n"
  out\write '  "type": "waveform",\n'
  out\write '  "version": 1,\n'
  out\write '  "sampleRate": ', tostring(SAMPLE_RATE), ",\n"
  out\write '  "channels": ', tostring(CHANNELS), ",\n"
  out\write '  "bits": ', tostring(BITS), ",\n"
  out\write '  "amplitudeFormat": "s16",\n'
  out\write '  "amplitudeMin": -32768,\n'
  out\write '  "amplitudeMax": 32767,\n'
  out\write '  "pointLayout": "interleavedMinMax",\n'
  if result.range
    out\write '  "sourceStartMs": ', tostring(result.range.start_ms), ",\n"
    out\write '  "sourceEndMs": ', tostring(result.range.end_ms), ",\n"
    out\write '  "sourceDurationMs": ', tostring(result.range.duration_ms), ",\n"
    out\write '  "sourceLineCount": ', tostring(result.range.line_count), ",\n"
  out\write '  "durationMs": ', tostring(result.duration_ms), ",\n"
  out\write '  "totalSamples": ', tostring(result.total_samples), ",\n"
  out\write '  "levels": [\n'
  for i, level in ipairs pyramid.levels
    out\write ",\n" if i > 1
    out\write "    {\n"
    out\write '      "scale": ', tostring(level.scale), ",\n"
    out\write '      "pointMs": ', tostring(level.point_ms), ",\n"
    out\write '      "samplesPerPoint": ', tostring(level.samples_per_point), ",\n"
    out\write '      "points": ', tostring(level.points), ",\n"
    out\write '      "peaks": ['
    ok = copy_level_peaks out, level
    unless ok
      out\close!
      return false, "Could not read temporary level file."
    out\write "]\n"
    out\write "    }"
  out\write "\n  ]\n"
  out\write "}\n"
  out\close!
  true, nil

file_size = (path) ->
  file = io.open path, "rb"
  return 0 unless file
  size = file\seek "end"
  file\close!
  tonumber(size) or 0

export_waveform = (cfg) ->
  return false, "Choose an audio or video file." if trim(cfg.media) == ""
  return false, "Media file does not exist:\n#{cfg.media}" unless file_exists cfg.media
  return false, "Choose a JSON output path." if trim(cfg.output) == ""

  root = output_root cfg.output, cfg.media
  return false, "Could not resolve an output folder." if trim(root) == ""
  prefix = unique_prefix root
  pcm_path = "#{prefix}.s16le"
  log_path = "#{prefix}.ffmpeg.log"
  script_path = if is_windows then "#{prefix}.bat" else "#{prefix}.sh"

  cleanup_paths = { pcm_path, log_path, script_path }
  pcall_ok, success, message = pcall ->
    progress_title script_name
    progress_task "Decoding audio with FFmpeg"
    progress_set 5
    unless write_ffmpeg_script cfg, pcm_path, log_path, script_path
      return false, "Could not write the FFmpeg script."
    status = run_script script_path
    unless command_ok status
      return false, "FFmpeg could not decode the selected audio stream.\nLog:\n#{log_path}"
    size = file_size pcm_path
    return false, "FFmpeg produced an empty PCM file.\nLog:\n#{log_path}" if size <= 0
    progress_set 20
    result, err = process_pcm pcm_path, prefix, size
    return false, err if err
    result.range = cfg.range
    progress_task "Writing JSON"
    progress_set 95
    ok_json, json_err = write_json cfg.output, result
    result.pyramid\cleanup!
    return false, json_err unless ok_json
    progress_set 100
    range_text = if cfg.range then "\nRange: #{cfg.range.start_ms} ms - #{cfg.range.end_ms} ms" else ""
    true, "Waveform JSON written:\n#{cfg.output}\n#{range_text}\n\nDuration: #{result.duration_ms} ms\nLevels: #{#result.pyramid.levels}"

  for path in *cleanup_paths
    remove_file path

  if pcall_ok
    success, message
  else
    false, tostring success

export_line_ranges = (cfg, ranges) ->
  return false, "Select at least one subtitle line with valid timing." unless ranges and #ranges > 0
  first_output, last_output = nil, nil
  for i, range in ipairs ranges
    output = line_output_path cfg.output, cfg.media, range, i
    line_cfg = {
      media: cfg.media
      output: output
      ffmpeg: cfg.ffmpeg
      stream: cfg.stream
      range: range
    }
    ok, message = export_waveform line_cfg
    unless ok
      return false, "Line #{range.line_index or i} failed:\n#{message}"
    first_output = output unless first_output
    last_output = output
  folder = dir_name(first_output or cfg.output)
  true, "Waveform JSON files written: #{#ranges}\nFolder: #{folder}\nFirst: #{first_output}\nLast: #{last_output}"

main = (subs, sel) ->
  cfg, cfg_err = read_config!
  unless cfg
    show_message cfg_err
    return
  ok, message = export_waveform cfg
  show_message message

can_run = (subs, sel) ->
  true, script_description

if aegisub and aegisub.register_macro
  hotkey_path = HOTKEY_MENU_ROOT .. "/" .. HOTKEY_MENU_SCRIPT .. "/Execute"
  if depctrl and depctrl.registerMacro
    depctrl\registerMacro script_name, script_description, main, can_run, nil, false
    depctrl\registerMacro hotkey_path, "Hotkey action. " .. script_description, main, can_run, nil, false
  else
    aegisub.register_macro script_name, script_description, main, can_run
    aegisub.register_macro hotkey_path, "Hotkey action. " .. script_description, main, can_run
