export script_name        = "Cope Optimizer"
export script_description = "Optimize selected PNG2ASS color drawing lines by merging similar colors or reducing detected gradients."
export script_author      = "Kiterow"
export script_version     = "1.0.2"
export script_namespace   = "kite.CopeOptimizer"
HOTKEY_MENU_ROOT = ": Kite Hotkeys :"
HOTKEY_MENU_SCRIPT = "Cope Optimizer"

haveDepCtrl, DependencyControl = pcall require, "l0.DependencyControl"
depctrl = nil
if haveDepCtrl and DependencyControl
  depctrl = DependencyControl{
    feed: "https://raw.githubusercontent.com/Kitherow/Kite-Aegisub-Scripts/main/DependencyControl.json",
  }

MODES = { "Auto", "Colores similares", "Gradiente completo" }
INTENSITIES = { "Equilibrado", "Fidelidad", "Agresivo" }
EPSILON = 0.000001

copy_line = (line) ->
  out = {}
  for k, v in pairs line
    out[k] = v
  out

clamp = (value, low, high) ->
  value = tonumber(value) or 0
  math.max low, math.min high, value

format_number = (value) ->
  value = tonumber(value) or 0
  value = 0 if math.abs(value) < 0.0005
  nearest = math.floor(value + 0.5)
  return tostring nearest if math.abs(value - nearest) < 0.0005
  text = ("%.3f")\format value
  text = text\gsub "0+$", ""
  text = text\gsub "%.$", ""
  text

show_message = (message) ->
  aegisub.dialog.display {
    { class: "textbox", value: tostring(message or ""), x: 0, y: 0, width: 56, height: 10 }
  }, { "OK" }

cancel_with = (message) ->
  show_message message
  aegisub.cancel!

profile_threshold = (intensity) ->
  switch intensity
    when "Fidelidad" then 0.035
    when "Agresivo" then 0.100
    else 0.065

normalize_options = (opts = {}) ->
  mode = opts.mode or "Auto"
  known_mode = false
  for value in *MODES
    if mode == value
      known_mode = true
      break
  mode = "Auto" unless known_mode

  intensity = opts.intensity or "Equilibrado"
  known_intensity = false
  for value in *INTENSITIES
    if intensity == value
      known_intensity = true
      break
  intensity = "Equilibrado" unless known_intensity

  threshold = tonumber(opts.threshold) or 0
  threshold = profile_threshold intensity if threshold <= 0
  threshold = clamp threshold, 0.005, 0.25

  {
    mode: mode
    intensity: intensity
    threshold: threshold
    max_bands: math.max 2, math.min 64, math.floor((tonumber(opts.max_bands) or 8) + 0.5)
    show_summary: opts.show_summary and true or false
  }

normalize_ass_color = (value) ->
  hex = tostring(value or "")\match "&[Hh](%x+)&?"
  return nil unless hex
  hex = hex\upper!
  hex = ("000000" .. hex)\sub -6
  "&H#{hex}&"

rgb_to_ass = (r, g, b) ->
  local clamp8
  clamp8 = (v) ->
    v = math.floor((tonumber(v) or 0) + 0.5)
    return 0 if v < 0
    return 255 if v > 255
    v
  ("&H%02X%02X%02X&")\format clamp8(b), clamp8(g), clamp8(r)

ass_to_rgb = (color) ->
  color = normalize_ass_color color
  return nil unless color
  hex = color\match "&H(%x%x)(%x%x)(%x%x)&"
  return nil unless hex
  b, g, r = color\match "&H(%x%x)(%x%x)(%x%x)&"
  {
    r: tonumber(r, 16)
    g: tonumber(g, 16)
    b: tonumber(b, 16)
  }

srgb8_to_linear = (v) ->
  v = (tonumber(v) or 0) / 255
  return 0 if v <= 0
  return 1 if v >= 1
  return v / 12.92 if v <= 0.04045
  ((v + 0.055) / 1.055) ^ 2.4

cbrt = (value) ->
  return value ^ (1 / 3) if value >= 0
  -((-value) ^ (1 / 3))

rgb_to_oklab = (r, g, b) ->
  lr = srgb8_to_linear r
  lg = srgb8_to_linear g
  lb = srgb8_to_linear b
  lp = 0.4122214708 * lr + 0.5363325363 * lg + 0.0514459929 * lb
  mp = 0.2119034982 * lr + 0.6806995451 * lg + 0.1073969566 * lb
  sp = 0.0883024619 * lr + 0.2817188376 * lg + 0.6299787005 * lb
  lc, mc, sc = cbrt(lp), cbrt(mp), cbrt(sp)
  {
    l: 0.2104542553 * lc + 0.7936177850 * mc - 0.0040720468 * sc
    a: 1.9779984951 * lc - 2.4285922050 * mc + 0.4505937099 * sc
    b: 0.0259040371 * lc + 0.7827717662 * mc - 0.8086757660 * sc
  }

color_to_oklab = (color) ->
  rgb = ass_to_rgb color
  return nil unless rgb
  rgb_to_oklab rgb.r, rgb.g, rgb.b

delta_lab = (left, right) ->
  return 999 unless left and right
  dl = left.l - right.l
  da = left.a - right.a
  db = left.b - right.b
  math.sqrt dl * dl + da * da + db * db

delta_color = (left, right) ->
  delta_lab color_to_oklab(left), color_to_oklab(right)

extract_tag = (tags, name, fallback = nil) ->
  value = tags\match "\\#{name}([%-%d%.]+)"
  value or fallback

parse_drawing_bounds = (drawing, pos_x, pos_y, scale) ->
  nums = {}
  for token in tostring(drawing or "")\gmatch "%S+"
    n = tonumber token
    nums[#nums + 1] = n if n
  return nil, "drawing has no coordinates" if #nums < 4
  return nil, "drawing has an odd coordinate count" if #nums % 2 != 0

  left, top, right, bottom = nil, nil, nil, nil
  i = 1
  while i <= #nums
    x = pos_x + nums[i] / scale
    y = pos_y + nums[i + 1] / scale
    left = x if not left or x < left
    right = x if not right or x > right
    top = y if not top or y < top
    bottom = y if not bottom or y > bottom
    i += 2
  {
    left: left
    top: top
    right: right
    bottom: bottom
    width: math.max 0, right - left
    height: math.max 0, bottom - top
    center_x: (left + right) / 2
    center_y: (top + bottom) / 2
    area: math.max(1, (right - left) * (bottom - top))
  }

parse_png2ass_line = (text) ->
  text = tostring text or ""
  return nil, "line is not a simple {tags}drawing{\\p0} PNG2ASS drawing" unless text\match "^%s*{"
  return nil, "animated transforms are not supported" if text\find "\\t%("
  return nil, "\\move is not supported" if text\find "\\move%("
  return nil, "clips are not supported" if text\find "\\i?clip%("
  return nil, "alpha tags are not supported" if text\find "\\[1234]?a&[Hh]"
  return nil, "\\alpha is not supported" if text\find "\\alpha&[Hh]"

  tags, drawing = text\match "^%s*{([^}]*)}(.-){\\p0}%s*$"
  return nil, "line is not a simple {tags}drawing{\\p0} PNG2ASS drawing" unless tags and drawing
  return nil, "extra override tags inside the drawing are not supported" if drawing\find "[{}]"
  return nil, "drawing path is empty" if drawing\match "^%s*$"

  residue = tags
  residue = residue\gsub "\\an%d+", ""
  residue = residue\gsub "\\pos%([^)]*%)", ""
  residue = residue\gsub "\\bord[%-%d%.]+", ""
  residue = residue\gsub "\\shad[%-%d%.]+", ""
  residue = residue\gsub "\\blur[%-%d%.]+", ""
  residue = residue\gsub "\\p%d+", ""
  residue = residue\gsub "\\1?c&[Hh]%x+&?", ""
  residue = residue\gsub "%s+", ""
  return nil, "unsupported tag block content: #{residue}" if residue\find "\\"

  p_scale = tonumber tags\match "\\p(%d+)"
  return nil, "missing \\p scale" unless p_scale and p_scale >= 1
  return nil, "unsupported \\p scale" if p_scale > 6
  pos_x, pos_y = tags\match "\\pos%(%s*([%-%d%.]+)%s*,%s*([%-%d%.]+)%s*%)"
  return nil, "missing \\pos" unless pos_x and pos_y
  pos_x, pos_y = tonumber(pos_x), tonumber(pos_y)
  return nil, "invalid \\pos" unless pos_x and pos_y

  color_hex = tags\match "\\1?c&[Hh](%x+)&?"
  return nil, "missing \\c or \\1c color" unless color_hex
  color = normalize_ass_color "&H#{color_hex}&"
  rgb = ass_to_rgb color
  lab = color_to_oklab color
  return nil, "invalid color" unless rgb and lab

  scale = 2 ^ (p_scale - 1)
  bounds, bounds_err = parse_drawing_bounds drawing, pos_x, pos_y, scale
  return nil, bounds_err unless bounds

  an = tags\match "\\an(%d+)" or "7"
  bord = extract_tag tags, "bord", "0"
  shad = extract_tag tags, "shad", "0"
  blur = extract_tag tags, "blur", nil

  {
    tags: tags
    drawing: drawing\match "^%s*(.-)%s*$"
    p_scale: p_scale
    coord_scale: scale
    pos_x: pos_x
    pos_y: pos_y
    color: color
    rgb: rgb
    lab: lab
    an: an
    bord: bord
    shad: shad
    blur: blur
    bounds: bounds
    visual_key: table.concat { tostring(p_scale), an, bord, shad, blur or "" }, "|"
  }

line_key = (line, parsed) ->
  fields = {
    line.start_time or ""
    line.end_time or ""
    line.style or ""
    line.actor or ""
    line.effect or ""
    line.layer or 0
    line.margin_l or ""
    line.margin_r or ""
    line.margin_t or line.margin_v or ""
    line.comment and "1" or "0"
    parsed.visual_key
  }
  table.concat fields, "\31"

collect_items = (subs, sel) ->
  return nil, "Select at least two PNG2ASS drawing lines." unless sel and #sel >= 2
  sorted = [index for index in *sel]
  table.sort sorted
  for i = 2, #sorted
    return nil, "Selection must be contiguous for direct replacement." if sorted[i] != sorted[i - 1] + 1

  items = {}
  common_key = nil
  for _, index in ipairs sorted
    line = subs[index]
    return nil, "Selected row #{index} is not a dialogue line." unless line and line.class == "dialogue"
    parsed, err = parse_png2ass_line line.text
    return nil, "Line #{index}: #{err}" unless parsed
    key = line_key line, parsed
    common_key = key unless common_key
    return nil, "Selection mixes timing, style, layer, margins, or visual tags." if key != common_key
    parsed.index = index
    parsed.line = line
    parsed.weight = math.max 1, parsed.bounds.area
    items[#items + 1] = parsed
  items

unique_color_count = (items) ->
  seen, count = {}, 0
  for item in *items
    unless seen[item.color]
      seen[item.color] = true
      count += 1
  count

average_color = (items) ->
  total, r, g, b = 0, 0, 0, 0
  for item in *items
    w = item.weight or 1
    total += w
    r += item.rgb.r * w
    g += item.rgb.g * w
    b += item.rgb.b * w
  total = 1 if total <= 0
  rgb_to_ass r / total, g / total, b / total

offset_drawing = (drawing, dx, dy) ->
  out, is_x = {}, true
  for token in tostring(drawing or "")\gmatch "%S+"
    n = tonumber token
    if n
      value = n + (is_x and dx or dy)
      out[#out + 1] = format_number value
      is_x = not is_x
    else
      out[#out + 1] = token
  table.concat out, " "

merged_text = (items, color) ->
  first = items[1]
  base_x, base_y = first.pos_x, first.pos_y
  for item in *items
    base_x = item.pos_x if item.pos_x < base_x
    base_y = item.pos_y if item.pos_y < base_y

  drawings = {}
  for item in *items
    dx = (item.pos_x - base_x) * item.coord_scale
    dy = (item.pos_y - base_y) * item.coord_scale
    drawings[#drawings + 1] = offset_drawing item.drawing, dx, dy

  blur_tag = ""
  if first.blur and math.abs(tonumber(first.blur) or 0) > EPSILON
    blur_tag = "\\blur#{first.blur}"
  "{\\an#{first.an}\\pos(#{format_number(base_x)},#{format_number(base_y)})\\bord#{first.bord}\\shad#{first.shad}#{blur_tag}\\p#{first.p_scale}\\1c#{color}}#{table.concat(drawings, " ")}{\\p0}"

new_cluster = (item) ->
  cluster = {
    items: {}
    total: 0
    r: 0
    g: 0
    b: 0
    first_index: item.index or 0
    color: item.color
    lab: item.lab
  }
  cluster

add_to_cluster = (cluster, item) ->
  cluster.items[#cluster.items + 1] = item
  w = item.weight or 1
  cluster.total += w
  cluster.r += item.rgb.r * w
  cluster.g += item.rgb.g * w
  cluster.b += item.rgb.b * w
  cluster.first_index = item.index if item.index and item.index < cluster.first_index
  cluster.color = rgb_to_ass cluster.r / cluster.total, cluster.g / cluster.total, cluster.b / cluster.total
  cluster.lab = color_to_oklab cluster.color

similar_optimize = (items, opts) ->
  clusters = {}
  for item in *items
    best, best_delta = nil, 999
    for cluster in *clusters
      delta = delta_lab item.lab, cluster.lab
      if delta < best_delta
        best, best_delta = cluster, delta
    if best and best_delta <= opts.threshold
      add_to_cluster best, item
    else
      cluster = new_cluster item
      add_to_cluster cluster, item
      clusters[#clusters + 1] = cluster

  table.sort clusters, (a, b) -> a.first_index < b.first_index
  texts = {}
  for cluster in *clusters
    table.sort cluster.items, (a, b) -> a.index < b.index
    texts[#texts + 1] = merged_text cluster.items, cluster.color
  {
    mode: "Colores similares"
    texts: texts
    colors_after: #clusters
    details: "umbral OKLab #{("%.3f")\format opts.threshold}"
  }

projection_value = (item, axis) ->
  if axis == "Vertical" then item.bounds.center_y else item.bounds.center_x

gradient_score = (items, axis) ->
  min_p, max_p = nil, nil
  sorted = [item for item in *items]
  table.sort sorted, (a, b) -> projection_value(a, axis) < projection_value(b, axis)
  for item in *sorted
    p = projection_value item, axis
    min_p = p if not min_p or p < min_p
    max_p = p if not max_p or p > max_p
  span = (max_p or 0) - (min_p or 0)
  return nil if span < EPSILON

  first, last = sorted[1], sorted[#sorted]
  endpoint_delta = delta_lab first.lab, last.lab
  return nil if endpoint_delta < 0.03

  total_w, total_err, max_err = 0, 0, 0
  for item in *sorted
    t = (projection_value(item, axis) - min_p) / span
    predicted = {
      l: first.lab.l + (last.lab.l - first.lab.l) * t
      a: first.lab.a + (last.lab.a - first.lab.a) * t
      b: first.lab.b + (last.lab.b - first.lab.b) * t
    }
    err = delta_lab item.lab, predicted
    w = item.weight or 1
    total_w += w
    total_err += err * w
    max_err = err if err > max_err
  {
    axis: axis
    sorted: sorted
    avg_err: total_err / math.max(1, total_w)
    max_err: max_err
    endpoint_delta: endpoint_delta
    span: span
  }

detect_gradient = (items, opts) ->
  return nil unless #items >= 4
  horizontal = gradient_score items, "Horizontal"
  vertical = gradient_score items, "Vertical"
  best = horizontal
  if vertical and (not best or vertical.avg_err < best.avg_err)
    best = vertical
  return nil unless best
  avg_limit = math.max 0.075, opts.threshold * 1.6
  max_limit = math.max 0.180, opts.threshold * 3.0
  return nil if best.avg_err > avg_limit or best.max_err > max_limit
  best

gradient_optimize = (items, opts) ->
  score = detect_gradient items, opts
  return nil, "No reliable gradient was detected." unless score
  target_bands = math.min opts.max_bands, #items
  return nil, "Gradient already has no more bands than the target." if target_bands >= #items

  bands = [{} for i = 1, target_bands]
  for rank, item in ipairs score.sorted
    band = math.floor((rank - 1) * target_bands / #score.sorted) + 1
    bands[band][#bands[band] + 1] = item

  texts, used_bands = {}, 0
  for band_items in *bands
    if #band_items > 0
      used_bands += 1
      texts[#texts + 1] = merged_text band_items, average_color band_items
  {
    mode: "Gradiente completo"
    texts: texts
    colors_after: used_bands
    details: "#{score.axis}, error medio #{("%.3f")\format score.avg_err}"
  }

optimize_items = (items, opts = {}) ->
  opts = normalize_options opts
  result, err = nil, nil
  if opts.mode == "Auto"
    result, err = gradient_optimize items, opts
    if not result or #result.texts >= #items
      result = similar_optimize items, opts
      result.mode = "Auto -> " .. result.mode
  elseif opts.mode == "Gradiente completo"
    result, err = gradient_optimize items, opts
    unless result
      result = similar_optimize items, opts
      result.mode = "Gradiente completo -> Colores similares"
      result.details ..= " (fallback: #{err})" if err
  else
    result = similar_optimize items, opts

  return nil, "Optimizer produced no output." unless result and result.texts and #result.texts > 0
  result

analyze_selection = (subs, sel, opts = {}) ->
  opts = normalize_options opts
  items, err = collect_items subs, sel
  return nil, err unless items
  result, opt_err = optimize_items items, opts
  return nil, opt_err unless result

  chars_before = 0
  for item in *items
    chars_before += #(item.line.text or "")
  chars_after = 0
  for text in *result.texts
    chars_after += #text

  before_lines = #items
  after_lines = #result.texts
  before_colors = unique_color_count items
  after_colors = result.colors_after or before_colors
  changed = after_lines != before_lines or chars_after != chars_before or after_colors != before_colors
  {
    items: items
    texts: result.texts
    mode: result.mode
    details: result.details
    before_lines: before_lines
    after_lines: after_lines
    before_colors: before_colors
    after_colors: after_colors
    chars_before: chars_before
    chars_after: chars_after
    changed: changed
  }

summary_text = (report) ->
  lines = {
    "Cope Optimizer"
    ""
    "Modo: #{report.mode}"
    "Detalle: #{report.details or ""}"
    ""
    "Lineas: #{report.before_lines} -> #{report.after_lines}"
    "Colores: #{report.before_colors} -> #{report.after_colors}"
    "Caracteres: #{report.chars_before} -> #{report.chars_after}"
  }
  table.concat lines, "\n"

apply_report = (subs, sel, report) ->
  sorted = [index for index in *sel]
  table.sort sorted
  first_index = sorted[1]
  template = report.items[1].line

  for i = #sorted, 1, -1
    subs.delete sorted[i]

  new_sel = {}
  for i, text in ipairs report.texts
    new_line = copy_line template
    new_line.text = text
    insert_at = first_index + i - 1
    subs.insert insert_at, new_line
    new_sel[#new_sel + 1] = insert_at
  new_sel

build_dialog = ->
  {
    { class: "label", label: "Modo", x: 0, y: 0, width: 3, height: 1 }
    { class: "dropdown", name: "mode", items: MODES, value: "Auto", x: 3, y: 0, width: 6, height: 1 }
    { class: "label", label: "Intensidad", x: 0, y: 1, width: 3, height: 1 }
    { class: "dropdown", name: "intensity", items: INTENSITIES, value: "Equilibrado", x: 3, y: 1, width: 6, height: 1 }
    { class: "label", label: "Umbral OKLab (0 = intensidad)", x: 0, y: 2, width: 4, height: 1 }
    { class: "floatedit", name: "threshold", value: 0, min: 0, max: 0.25, step: 0.005, x: 4, y: 2, width: 3, height: 1 }
    { class: "label", label: "Bandas max.", x: 0, y: 3, width: 3, height: 1 }
    { class: "intedit", name: "max_bands", value: 8, min: 2, max: 64, x: 3, y: 3, width: 3, height: 1 }
    { class: "checkbox", name: "show_summary", label: "Mostrar resumen antes de aplicar", value: false, x: 0, y: 4, width: 9, height: 1 }
  }

main = (subs, sel) ->
  unless sel and #sel >= 2
    cancel_with "Selecciona al menos dos lineas PNG2ASS de dibujo."

  button, res = aegisub.dialog.display build_dialog!, { "Execute", "Cancel" }, { ok: "Execute", close: "Cancel" }
  return sel unless button == "Execute"
  opts = normalize_options res
  report, err = analyze_selection subs, sel, opts
  cancel_with err unless report

  unless report.changed
    show_message "No se encontro una reduccion segura con estos parametros.\n\n#{summary_text report}"
    return sel

  if opts.show_summary
    confirm = aegisub.dialog.display {
      { class: "textbox", value: summary_text(report) .. "\n\nAplicar reemplazo directo?", x: 0, y: 0, width: 56, height: 10 }
    }, { "Execute", "Cancel" }, { ok: "Execute", close: "Cancel" }
    return sel unless confirm == "Execute"

  new_sel = apply_report subs, sel, report
  aegisub.set_undo_point script_name
  show_message summary_text report
  new_sel

validate = (subs, sel) ->
  return false unless sel and #sel >= 2
  for index in *sel
    line = subs[index]
    return true if line and line.class == "dialogue" and tostring(line.text or "")\find "\\p%d"
  false

if aegisub and aegisub.register_macro
  hotkey_path = HOTKEY_MENU_ROOT .. "/" .. HOTKEY_MENU_SCRIPT .. "/Execute"
  if depctrl and depctrl.registerMacro
    depctrl\registerMacro script_name, script_description, main, validate, nil, false
    depctrl\registerMacro hotkey_path, "Hotkey action. " .. script_description, main, validate, nil, false
  else
    aegisub.register_macro script_name, script_description, main, validate
    aegisub.register_macro hotkey_path, "Hotkey action. " .. script_description, main, validate
