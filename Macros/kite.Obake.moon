export script_name = "Obake"
export script_description = "Build and maintain ASS transform/tag effects."
export script_author = "Kiterow"
export script_namespace = "kite.Obake"
export script_version = "0.2.2"

Core = {}
local ASS, AMLine, ConfigHandler

DependencyControl = require "l0.DependencyControl"
depctrl = DependencyControl{
  feed: "https://raw.githubusercontent.com/Kitherow/Kite-Aegisub-Scripts/main/DependencyControl.json"
  {
    {"l0.ASSFoundation", version: "0.5.0", url: "https://github.com/TypesettingTools/ASSFoundation",
      feed: "https://raw.githubusercontent.com/TypesettingTools/ASSFoundation/master/DependencyControl.json"}
    {"a-mo.Line", version: "1.5.3", url: "https://github.com/TypesettingTools/Aegisub-Motion",
      feed: "https://raw.githubusercontent.com/TypesettingTools/Aegisub-Motion/DepCtrl/DependencyControl.json"}
    {"a-mo.ConfigHandler", version: "1.1.4", url: "https://github.com/TypesettingTools/Aegisub-Motion",
      feed: "https://raw.githubusercontent.com/TypesettingTools/Aegisub-Motion/DepCtrl/DependencyControl.json"}
  }
}
ASS, AMLine, ConfigHandler = depctrl\requireModules!

HOTKEY_MENU_ROOT = ": Kite Hotkeys :"
HOTKEY_MENU_SCRIPT = "Obake"
CONFIG_FILE = "kite-obake.json"
DEFAULT_LANGUAGE = "en"
current_language = DEFAULT_LANGUAGE
language_config_handler = nil

OPERATIONS = {
  "Apply chain"
  "Retime transforms"
  "In-Out tags"
  "Gunfight of Tags"
  "ZigZag lines"
  "Animation FX"
  "Border layers"
  "Color preset"
}

OPERATION_LABELS = {
  en: {
    ["Apply chain"]: "build t() chain"
    ["Retime transforms"]: "retime t() tags"
    ["In-Out tags"]: "create in/out t() tags"
    ["Gunfight of Tags"]: "randomize numeric tags / FBF"
    ["ZigZag lines"]: "alternate selected lines by frames"
    ["Animation FX"]: "apply animation presets"
    ["Border layers"]: "create border layers"
    ["Color preset"]: "apply color-layer preset"
  }
  es: {
    ["Apply chain"]: "crear cadena de t()"
    ["Retime transforms"]: "recalcular tiempos de t()"
    ["In-Out tags"]: "crear tags in/out con t()"
    ["Gunfight of Tags"]: "randomizar tags numericos / FBF"
    ["ZigZag lines"]: "alternar lineas por frames"
    ["Animation FX"]: "aplicar presets de animación"
    ["Border layers"]: "crear capas de borde"
    ["Color preset"]: "aplicar preset de color por capas"
  }
}

ACTION_HELP = {
  en: {
    ["Apply chain"]: "Builds one or more transform segments and injects them in the first override block. Add+ and Rem- control the number of keyframes. In manual mode, the first row is the initial state and each later row becomes one timed \\t()."
    ["Retime transforms"]: "Directly scales every timed \\t(t1,t2,...) in each selected line. Source duration is inferred from the largest existing transform time; target duration is the current line duration."
    ["In-Out tags"]: "With exactly two selected dialogue lines, creates one line spanning both timings, comments the originals, and turns differing leading tags into \\t() transitions."
    ["Gunfight of Tags"]: "Randomizes selected numeric/hex ASS override tags. With one source line it splits the line into FBF chunks using the frame period. With multiple selected lines, Count selection as FBF unit treats the selection itself as the tag-change sequence; disabling it splits each line into its own FBF chunks."
    ["ZigZag lines"]: "Uses the selected lines as visual states and emits FBF chunks that alternate through them every N frames. If their times differ, the generated range covers the combined min start to max end."
    ["Animation FX"]: "Applies ready-made animation presets. Color and frame-driven presets use the selected lines, the active frame when needed, and the current line duration."
    ["Border layers"]: "Creates layered border copies from the selected lines. B1-B4 are cumulative outlines, with fill kept above the generated border layers."
    ["Color preset"]: "Creates color-layer presets: fill/border decomposition, glow, shadtrick, double border blur, or clean flatten."
  }
  es: {
    ["Apply chain"]: "Crea uno o varios tramos de transform y los inserta en el primer bloque de tags. Add+ y Rem- controlan la cantidad de keyframes. En modo manual, la primera fila es el estado inicial y las siguientes filas generan \\t() cronometrados."
    ["Retime transforms"]: "Escala directamente cada \\t(t1,t2,...) de las líneas seleccionadas. La duración origen sale del mayor tiempo existente y la duración destino sale de la línea actual."
    ["In-Out tags"]: "Con exactamente dos líneas de diálogo seleccionadas, crea una línea que cubre ambos tiempos, comenta los originales y convierte los tags iniciales distintos en transiciones \\t()."
    ["Animation FX"]: "Aplica presets de animación. Los presets de color y de frame usan las líneas seleccionadas, el frame activo cuando corresponde y la duración actual de cada línea."
    ["Border layers"]: "Crea copias en capas con borde a partir de las líneas seleccionadas. B1-B4 son bordes acumulados y el relleno queda encima."
    ["Color preset"]: "Crea presets por capas: relleno/borde, glow, shadtrick, doble borde con blur o limpieza por reemplazo de la línea."
  }
}

DIRECT_ACTIONS = {
  ["Retime transforms"]: true
  ["In-Out tags"]: true
}

FX_ITEMS = {
  ""
  "Blur In", "Blur Out"
  "Fade In", "Fade Out"
  "Scale Up", "Scale Down"
  "Pop In", "Pop Out"
  "Color Flash", "Color Pulse", "To Color (frame)"
  "To Style (frame)"
  "Border Pulse", "Glow Pulse"
  "Shake V", "Shake H", "Shake XY"
  "Wobble (frz)"
  "Glitch"
  "Dramatic Pulse"
  "Flashback (fad)"
  "Split Line", "Split Line Fad", "Split Title"
}

LANG = {
  en: {
    run: "Execute"
    help: "Help"
    cancel: "Cancel"
    close: "Cancel"
    apply: "Execute"
    reset: "Reset"
    language: "Español"
    action: "Action:"
    time_unit: "Time unit:"
    strip_existing_t: "Strip existing \\t"
    shape: "Shape:"
    value: "Value:"
    accel: "Accel"
    delay: "Delay:"
    time: "T"
    tags: "Tags"
    common_tags: "Common tags"
    color1: "Color 1:"
    color2: "Color 2:"
    step_ms: "Step ms:"
    amount: "Amount:"
    preset: "Preset:"
    select_action: "Select an action and press Execute."
    no_transform_chain: "No transform chain was applied."
    no_border_layers: "No border layers were created."
    no_color_preset: "No color preset was applied."
    no_fx_preset: "Select an FX preset."
    no_lines_changed: "No lines were changed."
    no_t_ret: "No timed \\t() tags were retimed."
    no_numeric_tags: "No numeric override tags were found."
    select_gun_tag: "Select at least one tag."
    gun_no_change: "No selected numeric tags were changed."
    fbf_period: "FBF period:"
    selection_as_fbf_unit: "Count selection as FBF unit"
    frame_api_missing: "Frame timing API is unavailable. Open a video or run this inside Aegisub with frame_from_ms/ms_from_frame."
    no_fbf_slices: "No FBF slices were produced."
    zigzag_period: "Frames:"
    zigzag_need_lines: "ZigZag lines needs at least two dialogue lines."
    zigzag_created: "ZigZag lines created"
    use_line1: "Use line 1"
    use_line2: "Use line 2"
    choose_text: "The two lines have different text. Which text should be kept?"
    in_out_need_two: "In-Out tags needs exactly two selected dialogue lines."
    in_out_created: "In-Out tags created one line."
    line: "Line"
    zero_duration: "zero duration."
    transform_s: "transform(s)."
  }
  es: {
    ["Manual keyframes"]: "Keyframes manuales"
    ["Once (one-way)"]: "Una vez"
    ["Out and back"]: "Ida y vuelta"
    ["Yoyo (N cycles)"]: "Yoyo (N ciclos)"
    ["Pulse (ms)"]: "Pulso (ms)"
    ["Steps (N)"]: "Pasos (N)"
    ["No delay"]: "Sin retardo"
    ["ms from start"]: "ms desde inicio"
    ["Current frame"]: "Frame actual"
    ["Percent (%)"]: "Porcentaje (%)"
    ["Percent"]: "Porcentaje"
    ["Blur In"]: "Blur de entrada"
    ["Blur Out"]: "Blur de salida"
    ["Fade In"]: "Fade de entrada"
    ["Fade Out"]: "Fade de salida"
    ["Scale Up"]: "Escalar arriba"
    ["Scale Down"]: "Escalar abajo"
    ["Pop In"]: "Pop de entrada"
    ["Pop Out"]: "Pop de salida"
    ["Color Flash"]: "Flash de color"
    ["Color Pulse"]: "Pulso de color"
    ["To Color (frame)"]: "A color (frame)"
    ["To Style (frame)"]: "A estilo (frame)"
    ["Border Pulse"]: "Pulso de borde"
    ["Glow Pulse"]: "Pulso de brillo"
    ["Shake V"]: "Sacudida V"
    ["Shake H"]: "Sacudida H"
    ["Shake XY"]: "Sacudida XY"
    ["Wobble (frz)"]: "Tambaleo (frz)"
    ["Glitch"]: "Glitch"
    ["Dramatic Pulse"]: "Pulso dramático"
    ["Flashback (fad)"]: "Flashback (fad)"
    ["Split Line"]: "dividir línea"
    ["Split Line Fad"]: "dividir línea con fad"
    ["Split Title"]: "dividir título"
    ["Decompose (Fill + Border)"]: "Separar relleno + borde"
    ["Blur + Glow"]: "Blur + glow"
    ["Shadtrick (Shadow Layer)"]: "Shadtrick"
    ["Double Border Blur"]: "Doble borde con blur"
    ["Clean Layers (Flatten)"]: "Limpiar capas"
    run: "Execute"
    help: "Ayuda"
    cancel: "Cancel"
    close: "Cancel"
    apply: "Execute"
    reset: "Reset"
    language: "English"
    action: "Acción:"
    time_unit: "Unidad:"
    strip_existing_t: "Quitar \\t existentes"
    shape: "Forma:"
    value: "Valor:"
    accel: "Accel"
    delay: "Retardo:"
    time: "T"
    tags: "Tags"
    common_tags: "Tags comunes"
    color1: "Color 1:"
    color2: "Color 2:"
    step_ms: "Paso ms:"
    amount: "Cantidad:"
    preset: "Preset:"
    select_action: "Selecciona una accion y pulsa Execute."
    no_transform_chain: "No se aplicó ninguna cadena de transforms."
    no_border_layers: "No se crearon capas de borde."
    no_color_preset: "No se aplicó ningún preset de color."
    no_fx_preset: "Selecciona un preset de FX."
    no_lines_changed: "No cambió ninguna línea."
    no_t_ret: "No se recalculó ningún \\t() con tiempo."
    use_line1: "Usar línea 1"
    use_line2: "Usar línea 2"
    choose_text: "Las dos líneas tienen texto distinto. ¿Cuál texto quieres conservar?"
    in_out_need_two: "In-Out tags necesita exactamente dos líneas de diálogo seleccionadas."
    in_out_created: "In-Out tags creó una línea."
    line: "Línea"
    zero_duration: "duración cero."
    transform_s: "transform(s)."
  }
}

CHAIN_SHAPES = {
  "Manual keyframes"
  "Once (one-way)"
  "Out and back"
  "Yoyo (N cycles)"
  "Pulse (ms)"
  "Steps (N)"
}

DELAY_MODES = {
  "No delay"
  "ms from start"
  "Current frame"
  "Percent (%)"
}

TIME_UNITS = {"Percent", "ms from start"}

CAL_PRESETS = {
  "Decompose (Fill + Border)"
  "Blur + Glow"
  "Shadtrick (Shadow Layer)"
  "Double Border Blur"
  "Clean Layers (Flatten)"
}

COMMON_TAGS = {
  "\\fscx100\\fscy100"
  "\\fs50"
  "\\fsp0"
  "\\bord1"
  "\\shad1"
  "\\blur1"
  "\\be1"
  "\\frz0"
  "\\frx0"
  "\\fry0"
  "\\fax0"
  "\\fay0"
  "\\alpha&H00&"
  "\\c&HFFFFFF&"
  "\\3c&H000000&"
  "\\4c&H000000&"
}

CHAIN_DIALOG_W = 24
COMMON_TAG_COLUMNS = 4
COMMON_TAG_W = CHAIN_DIALOG_W / COMMON_TAG_COLUMNS

DEFAULTS = {
  operation: "Apply chain"
  time_unit: "Percent"
  chain_shape: "Manual keyframes"
  strip_existing: true
  use_accel: false
  accel: 1.0
  shape_val: 3
  delay_mode: "No delay"
  delay_val: 0
  fx_preset: ""
  fx_step_ms: 50
  fx_amount: 0.12
  fx_color: "#FFCC00"
  fx_color2: "#00CCFF"
  cal_preset: CAL_PRESETS[1]
  bord1: 2
  bord2: 4
  bord3: 0
  bord4: 0
  use_bord1: true
  use_bord2: false
  use_bord3: false
  use_bord4: false
  color1: "#FFFFFF"
  color2: "#000000"
  color3: "#FF0000"
  color4: "#00FF00"
}

GUN_CONFIG_FILE = "kite-gunfight.json"
GUN_CONFIG_VERSION = "1.0.0"
ZIGZAG_CONFIG_FILE = "kite-obake-zigzag.json"

GUN_RANDOM_SCOPES = {
  "Each value"
  "Same per tag"
  "Same per line"
  "Axis per tag"
  "Axis per line"
}

GUN_TAG_DEFS = {
  {key: "pos", label: "pos", names: {"pos"}}
  {key: "move", label: "move", names: {"move"}}
  {key: "org", label: "org", names: {"org"}}
  {key: "clip", label: "clip", names: {"clip"}}
  {key: "iclip", label: "iclip", names: {"iclip"}}
  {key: "fad", label: "fad", names: {"fad"}}
  {key: "fade", label: "fade", names: {"fade"}}
  {key: "t", label: "t args", names: {"t"}}
  {key: "an", label: "an", names: {"an"}}
  {key: "a", label: "a", names: {"a"}}
  {key: "q", label: "q", names: {"q"}}
  {key: "fs", label: "fs", names: {"fs"}}
  {key: "fsp", label: "fsp", names: {"fsp"}}
  {key: "fscx", label: "fscx", names: {"fscx"}}
  {key: "fscy", label: "fscy", names: {"fscy"}}
  {key: "frz", label: "frz/fr", names: {"frz", "fr"}}
  {key: "frx", label: "frx", names: {"frx"}}
  {key: "fry", label: "fry", names: {"fry"}}
  {key: "fax", label: "fax", names: {"fax"}}
  {key: "fay", label: "fay", names: {"fay"}}
  {key: "bord", label: "bord", names: {"bord"}}
  {key: "xbord", label: "xbord", names: {"xbord"}}
  {key: "ybord", label: "ybord", names: {"ybord"}}
  {key: "shad", label: "shad", names: {"shad"}}
  {key: "xshad", label: "xshad", names: {"xshad"}}
  {key: "yshad", label: "yshad", names: {"yshad"}}
  {key: "blur", label: "blur", names: {"blur"}}
  {key: "be", label: "be", names: {"be"}}
  {key: "b", label: "b", names: {"b"}}
  {key: "i", label: "i", names: {"i"}}
  {key: "u", label: "u", names: {"u"}}
  {key: "s", label: "s", names: {"s"}}
  {key: "c", label: "c/1c", names: {"c", "1c"}}
  {key: "2c", label: "2c", names: {"2c"}}
  {key: "3c", label: "3c", names: {"3c"}}
  {key: "4c", label: "4c", names: {"4c"}}
  {key: "alpha", label: "alpha", names: {"alpha"}}
  {key: "1a", label: "1a", names: {"1a"}}
  {key: "2a", label: "2a", names: {"2a"}}
  {key: "3a", label: "3a", names: {"3a"}}
  {key: "4a", label: "4a", names: {"4a"}}
  {key: "k", label: "k", names: {"k"}}
  {key: "kf", label: "kf/K", names: {"kf", "K"}}
  {key: "ko", label: "ko", names: {"ko"}}
  {key: "p", label: "p", names: {"p"}}
  {key: "pbo", label: "pbo", names: {"pbo"}}
  {key: "fe", label: "fe", names: {"fe"}}
}

GUN_KNOWN_NAMES = {
  "alpha", "iclip", "clip", "move", "fade", "fad", "pos", "org"
  "xbord", "ybord", "xshad", "yshad"
  "fscx", "fscy", "fsp", "frz", "frx", "fry", "fax", "fay"
  "bord", "shad", "blur", "pbo"
  "be", "kf", "ko", "fn", "fe", "an", "fs", "fr"
  "1c", "2c", "3c", "4c", "1a", "2a", "3a", "4a"
  "q", "K", "k", "p", "a", "b", "i", "u", "s", "t", "r", "c"
}

GUN_NAME_TO_KEY = {}
for def in *GUN_TAG_DEFS
  for name in *def.names
    GUN_NAME_TO_KEY[name] = def.key

GUN_COLOR_KEYS = {c: true, ["2c"]: true, ["3c"]: true, ["4c"]: true}
GUN_ALPHA_KEYS = {alpha: true, ["1a"]: true, ["2a"]: true, ["3a"]: true, ["4a"]: true}

GUN_TAG_SPEC = {
  an: {integer: true, min: 1, max: 9}
  a: {integer: true, min: 1, max: 11}
  q: {integer: true, min: 0, max: 3}
  fs: {nonnegative: true}
  fscx: {nonnegative: true}
  fscy: {nonnegative: true}
  bord: {nonnegative: true}
  xbord: {nonnegative: true}
  ybord: {nonnegative: true}
  shad: {nonnegative: true}
  blur: {nonnegative: true}
  be: {integer: true, nonnegative: true}
  i: {integer: true, min: 0, max: 1}
  u: {integer: true, min: 0, max: 1}
  s: {integer: true, min: 0, max: 1}
  b: {integer: true, min: 0, max: 900}
  k: {integer: true, nonnegative: true}
  kf: {integer: true, nonnegative: true}
  ko: {integer: true, nonnegative: true}
  p: {integer: true, nonnegative: true}
  fe: {integer: true, nonnegative: true}
  fade_alpha: {integer: true, min: 0, max: 255}
  color_channel: {integer: true, min: 0, max: 255}
  time: {integer: true, nonnegative: true}
  accel: {min: 0.001}
}

GUN_DEFAULTS = {
  min_delta: -5
  max_delta: 10
  step: 0
  decimals: 3
  seed: 0
  random_scope: "Each value"
  use_x: true
  use_y: true
  use_scalar: true
  use_time: false
  include_transform_inner: true
  include_transform_args: false
  include_auto_blocks: false
  clamp_nonnegative: true
  protect_discrete: true
  save_settings: true
  show_report: true
  fbf_period: 1
  selection_as_fbf_unit: true
}

ZIGZAG_DEFAULTS = {
  period_frames: 3
}

clone_line = (line) ->
  return nil unless type(line) == "table"
  src = {}
  src[k] = v for k, v in pairs line
  src.class = src.class or "dialogue"
  src.comment = src.comment or false
  src.layer = tonumber(src.layer) or 0
  src.start_time = tonumber(src.start_time) or 0
  src.end_time = tonumber(src.end_time) or src.start_time
  src.style = src.style or "Default"
  src.actor = src.actor or ""
  src.margin_l = tonumber(src.margin_l) or 0
  src.margin_r = tonumber(src.margin_r) or 0
  src.margin_t = tonumber(src.margin_t or src.margin_v) or 0
  src.effect = src.effect or ""
  src.text = tostring(src.text or "")
  wrapped = AMLine src, line.parentCollection or src.parentCollection, {}
  for k, v in pairs src
    wrapped[k] = v if wrapped[k] == nil
  wrapped

is_dialogue = (line) ->
  type(line) == "table" and (line.class == nil or line.class == "dialogue") and not line.comment

trim = (value) ->
  text = tostring(value or "")
  text = text\gsub "^%s+", ""
  text\gsub "%s+$", ""

finite = (value) ->
  n = tonumber value
  if n and n == n and n != math.huge and n != -math.huge then n else nil

clamp = (value, min_value, max_value) ->
  n = tonumber(value) or 0
  n = min_value if min_value != nil and n < min_value
  n = max_value if max_value != nil and n > max_value
  n

format_num = (value, decimals = 3) ->
  n = finite value
  return "0" unless n
  n = 0 if math.abs(n) < 0.0000005
  if math.abs(n - math.floor(n + 0.5)) < 0.0000005
    return tostring math.floor(n + 0.5)
  s = string.format "%." .. tostring(decimals) .. "f", n
  s = s\gsub "0+$", ""
  s = s\gsub "%.$", ""
  if s == "-0" or s == "" then "0" else s

format_ms = (value) ->
  tostring math.floor((tonumber(value) or 0) + 0.5)

TAG_NAME_ALIASES = {
  t: "transform"
  bord: "outline"
  xbord: "outline_x"
  ybord: "outline_y"
  shad: "shadow"
  xshad: "shadow_x"
  yshad: "shadow_y"
  org: "origin"
  pos: "position"
  c: "color1"
  ["1c"]: "color1"
  ["2c"]: "color2"
  ["3c"]: "color3"
  ["4c"]: "color4"
  ["1a"]: "alpha1"
  ["2a"]: "alpha2"
  ["3a"]: "alpha3"
  ["4a"]: "alpha4"
}

ass_line_for_text = (text) ->
  {
    class: "dialogue"
    comment: false
    layer: 0
    start_time: 0
    end_time: 0
    style: "Default"
    actor: ""
    margin_l: 0
    margin_r: 0
    margin_t: 0
    effect: ""
    text: tostring(text or "")
  }

parse_text = (text) ->
  ok, data = pcall -> ASS\parse ass_line_for_text text
  if ok then data else nil

normalize_tag_names = (names) ->
  names = {names} unless type(names) == "table"
  out = {}
  for name in *(names or {})
    raw = tostring(name or "")
    raw = raw\gsub "^\\", ""
    out[#out + 1] = TAG_NAME_ALIASES[raw] or raw
  out

remove_ass_tags = (text, names) ->
  data = parse_text text
  return tostring(text or "") unless data
  ok = pcall -> data\removeTags normalize_tag_names names
  return tostring(text or "") unless ok
  data\getString!

tag_text = (name, ...) ->
  tostring ASS\createTag name, ...

rgb_from_color = (value) ->
  raw = tostring(value or "")
  hex = raw\match "&[Hh]([%xA-Fa-f]+)&?"
  if hex
    hex = hex\sub(-6) if #hex > 6
    hex = string.rep("0", 6 - #hex) .. hex if #hex < 6
    b, g, r = hex\sub(1, 2), hex\sub(3, 4), hex\sub(5, 6)
    return tonumber(r, 16) or 0, tonumber(g, 16) or 0, tonumber(b, 16) or 0
  r, g, b = raw\match "^#?(%x%x)(%x%x)(%x%x)"
  return tonumber(r, 16) or 0, tonumber(g, 16) or 0, tonumber(b, 16) or 0 if r
  255, 255, 255

color_tag_text = (name, value) ->
  r, g, b = rgb_from_color value
  tag_text name, b, g, r

ass_color_value = (value) ->
  color_tag_text("color1", value)\match("&H%x%x%x%x%x%x&") or "&HFFFFFF&"

Core.L = (key) ->
  lang = LANG[current_language] or LANG.en
  lang[key] or LANG.en[key] or tostring(key or "")

Core.choice_label = (value) ->
  raw = tostring(value or "")
  return raw if raw == ""
  lang = LANG[current_language] or LANG.en
  lang[raw] or raw

Core.choice_raw = (value) ->
  shown = tostring(value or "")
  return shown if current_language == DEFAULT_LANGUAGE
  for raw, label in pairs LANG[current_language] or {}
    return raw if label == shown
  shown

Core.localized_items = (items) ->
  [Core.choice_label item for item in *(items or {})]

Core.valid_language = (value) ->
  if value == "es" then "es" else "en"

Core.config_interface = ->
  {
    main: {
      language: {class: "edit", name: "language", value: current_language, config: true}
    }
  }

Core.language_config = ->
  return nil unless ConfigHandler
  language_config_handler or= ConfigHandler Core.config_interface!, CONFIG_FILE, true, script_version
  language_config_handler

Core.load_language = ->
  options = Core.language_config!
  return current_language unless options
  pcall -> options\read!
  lang = options.configuration and options.configuration.main and options.configuration.main.language
  current_language = Core.valid_language lang
  current_language

Core.save_language = ->
  options = Core.language_config!
  return false unless options
  pcall -> options\read!
  options.configuration or= {}
  options.configuration.main or= {}
  options.configuration.main.language = Core.valid_language current_language
  pcall -> options\write!

Core.toggle_language = ->
  current_language = if current_language == "es" then "en" else "es"
  Core.save_language!
  current_language

Core.load_language!

show_message = (message) ->
  aegisub.dialog.display {
    {class: "textbox", text: tostring(message), x: 0, y: 0, width: 34, height: 8}
  }, {Core.L("close")}, close: Core.L("close")

enum_value = (value, items, fallback) ->
  value = Core.choice_raw value
  for item in *(items or {})
    return item if value == item
  fallback or (items and items[1]) or value

Core.operation_label = (operation) ->
  labels = OPERATION_LABELS[current_language] or OPERATION_LABELS.en
  labels[operation] or OPERATION_LABELS.en[operation] or tostring(operation or "")

Core.action_help = (operation) ->
  help = ACTION_HELP[current_language] or ACTION_HELP.en
  help[operation] or ACTION_HELP.en[operation] or ""

Core.normalize_operation = (operation) ->
  enum_value operation, OPERATIONS, DEFAULTS.operation

Core.dropdown_data = (items, labeler) ->
  out, to_raw, to_shown = {""}, {[""]: ""}, {[""]: ""}
  n = 1
  for raw in *(items or {})
    if raw != nil and raw != ""
      shown = "#{n}. #{if labeler then labeler(raw) else Core.choice_label(raw)}"
      out[#out + 1] = shown
      to_raw[shown] = raw
      to_raw[raw] = raw
      to_shown[raw] = shown
      n += 1
  out, to_raw, to_shown

Core.shown_choice = (to_shown, raw) ->
  (to_shown and to_shown[raw]) or raw or ""

Core.raw_choice = (to_raw, shown) ->
  (to_raw and to_raw[shown]) or Core.choice_raw(shown) or ""

Core.raw_operation_choice = (to_raw, shown) ->
  Core.normalize_operation Core.raw_choice(to_raw, shown)

first_block = (text) ->
  tostring(text or "")\match("^({[^}]*})") or ""

inject_first = (text, payload) ->
  return text unless payload and payload != ""
  text = tostring text or ""
  fb = first_block text
  if fb != ""
    return "{" .. payload .. fb\sub(2, -2) .. "}" .. text\sub(#fb + 1)
  "{" .. payload .. "}" .. text

remove_simple_tag = (text, tag) ->
  remove_ass_tags text, tag

remove_alpha_tags = (text) ->
  remove_ass_tags text, {"alpha", "alpha1", "alpha2", "alpha3", "alpha4"}

strip_karaoke_tags = (text) ->
  tostring(text or "")\gsub "%b{}", (block) ->
    body = block\sub(2, -2)\gsub "\\[kK][fo]?[%d%.]+", ""
    if trim(body) == "" then "" else "{" .. body .. "}"

first_transform_open = (text, from_pos) ->
  text\find "\\t%(", from_pos

find_matching_paren = (text, open_pos) ->
  depth = 0
  i = open_pos
  n = #text
  while i <= n
    ch = text\sub i, i
    if ch == "("
      depth += 1
    elseif ch == ")"
      depth -= 1
      return i if depth == 0
    i += 1
  nil

split_top_commas = (value) ->
  parts = {}
  text = tostring value or ""
  start, depth, i, n = 1, 0, 1, #text
  while i <= n
    ch = text\sub i, i
    if ch == "("
      depth += 1
    elseif ch == ")" and depth > 0
      depth -= 1
    elseif ch == "," and depth == 0
      parts[#parts + 1] = trim text\sub(start, i - 1)
      start = i + 1
    i += 1
  parts[#parts + 1] = trim text\sub(start)
  parts

map_transforms = (text, fn) ->
  text = tostring text or ""
  out, changed = {}, 0
  i, n = 1, #text
  while i <= n
    s, e = first_transform_open text, i
    unless s
      out[#out + 1] = text\sub i
      break
    out[#out + 1] = text\sub i, s - 1
    close_pos = find_matching_paren text, s + 2
    unless close_pos
      out[#out + 1] = text\sub s
      break
    body = text\sub s + 3, close_pos - 1
    replacement, did_change = fn body, text\sub(s, close_pos)
    out[#out + 1] = replacement
    changed += 1 if did_change
    i = close_pos + 1
  table.concat(out), changed

strip_transforms = (text) ->
  out = map_transforms text, -> "", true
  out

transform_tag = (t1, t2, tags, accel = nil) ->
  tags = tostring tags or ""
  return "" if tags == ""
  a = math.floor((tonumber(t1) or 0) + 0.5)
  b = math.floor((tonumber(t2) or 0) + 0.5)
  a, b = b, a if b < a
  if accel and accel > 0 and accel != 1
    return tostring ASS\createTag "transform", tags, a, b, accel
  tostring ASS\createTag "transform", tags, a, b

max_transform_end = (text) ->
  max_end = 0
  map_transforms text, (body) ->
    parts = split_top_commas body
    if #parts >= 3
      t1 = finite parts[1]
      t2 = finite parts[2]
      if t1 and t2
        max_end = math.max max_end, t1, t2
    "\\t(" .. body .. ")", false
  max_end

retime_transform_text = (text, source_duration, target_duration) ->
  source = finite(source_duration) or 0
  target = finite(target_duration) or 0
  return text, 0 unless source > 0 and target >= 0
  scale = target / source
  map_transforms text, (body) ->
    parts = split_top_commas body
    return "\\t(" .. body .. ")", false unless #parts >= 3
    t1 = finite parts[1]
    t2 = finite parts[2]
    return "\\t(" .. body .. ")", false unless t1 and t2
    parts[1] = format_ms t1 * scale
    parts[2] = format_ms t2 * scale
    "\\t(" .. table.concat(parts, ",") .. ")", true

NUM_PATTERN = "[%+%-]?%d*%.?%d+"

strip_tags = (text) ->
  tostring(text or "")\gsub "{[^}]*}", ""

split_leading_tag_blocks = (text) ->
  text = tostring text or ""
  blocks, i = {}, 1
  while i <= #text and text\sub(i, i) == "{"
    close_pos = text\find "}", i + 1, true
    break unless close_pos
    blocks[#blocks + 1] = text\sub i, close_pos
    i = close_pos + 1
  table.concat(blocks), text\sub(i)

parse_tag_block = (block) ->
  text = tostring(block or "")\gsub "[{}]", ""
  tags, i, n = {}, 1, #text
  while i <= n
    start_pos = text\find "\\", i, true
    break unless start_pos
    name = text\sub(start_pos + 1)\match "^[1-4]?%a+"
    unless name
      i = start_pos + 1
      continue
    value_pos = start_pos + 1 + #name
    value_end = value_pos - 1
    if text\sub(value_pos, value_pos) == "("
      value_end = find_matching_paren(text, value_pos) or n
    else
      next_tag = text\find "\\", value_pos, true
      value_end = if next_tag then next_tag - 1 else n
    raw = text\sub start_pos, value_end
    value = text\sub value_pos, value_end
    tags[#tags + 1] = {name: name, value: value, raw: raw}
    i = value_end + 1
  tags

tag_numbers = (value) ->
  nums = {}
  for raw in tostring(value or "")\gmatch NUM_PATTERN
    nums[#nums + 1] = tonumber raw
  nums

round_int = (value) ->
  value = tonumber(value) or 0
  if value >= 0
    math.floor value + 0.5
  else
    math.ceil value - 0.5

gun_choice_or_default = (value, items, default_value) ->
  for item in *(items or {})
    return item if value == item
  default_value

gun_balanced_paren_end = (text, start_pos) ->
  depth = 0
  for i = start_pos, #text
    c = text\sub i, i
    if c == "("
      depth += 1
    elseif c == ")"
      depth -= 1
      return i if depth == 0
  #text

gun_iter_tag_blocks = (text) ->
  blocks = {}
  text = tostring text or ""
  i = 1
  while true
    s = text\find "{", i, true
    break unless s
    e = text\find "}", s + 1, true
    break unless e
    blocks[#blocks + 1] = {
      open_pos: s
      close_pos: e
      content: text\sub s + 1, e - 1
    }
    i = e + 1
  blocks

gun_parse_tag_block = (block) ->
  block = tostring block or ""
  tags = {}
  i = 1
  while i <= #block
    if block\sub(i, i) == "\\"
      name_start = i + 1
      name = nil
      for known in *GUN_KNOWN_NAMES
        if block\sub(name_start, name_start + #known - 1) == known
          name = known
          break
      name or= block\sub(name_start)\match "^[1-4]?[A-Za-z]+"
      if name and name != ""
        j = name_start + #name
        token_end = nil
        if block\sub(j, j) == "("
          token_end = gun_balanced_paren_end block, j
        else
          token_end = j - 1
          while token_end + 1 <= #block and block\sub(token_end + 1, token_end + 1) != "\\"
            token_end += 1
        tags[#tags + 1] = {
          name: name
          raw: block\sub i, token_end
          value: block\sub j, token_end
          start_pos: i
          end_pos: token_end
        }
        i = token_end + 1
      else
        i += 1
    else
      i += 1
  tags

gun_is_digit = (c) ->
  c and c\match("%d") != nil

gun_scan_numbers = (text) ->
  text = tostring text or ""
  tokens = {}
  i = 1
  while i <= #text
    c = text\sub i, i
    next_c = text\sub i + 1, i + 1
    can_start = gun_is_digit(c) or ((c == "+" or c == "-") and (gun_is_digit(next_c) or next_c == ".")) or (c == "." and gun_is_digit(next_c))
    unless can_start
      i += 1
      continue
    start_pos = i
    i += 1 if c == "+" or c == "-"
    digits = 0
    while i <= #text and gun_is_digit text\sub(i, i)
      i += 1
      digits += 1
    if i <= #text and text\sub(i, i) == "."
      i += 1
      while i <= #text and gun_is_digit text\sub(i, i)
        i += 1
        digits += 1
    if digits == 0
      i = start_pos + 1
      continue
    exp_start = i
    if i <= #text and (text\sub(i, i) == "e" or text\sub(i, i) == "E")
      j = i + 1
      j += 1 if text\sub(j, j) == "+" or text\sub(j, j) == "-"
      exp_digits = 0
      while j <= #text and gun_is_digit text\sub(j, j)
        j += 1
        exp_digits += 1
      if exp_digits > 0
        i = j
      else
        i = exp_start
    raw = text\sub start_pos, i - 1
    tokens[#tokens + 1] = {
      start_pos: start_pos
      end_pos: i - 1
      raw: raw
      value: tonumber raw
    }
  tokens

gun_is_selected = (key, selected) ->
  selected and selected[key] == true

gun_category_enabled = (category, cfg) ->
  switch category
    when "x" then cfg.use_x
    when "y" then cfg.use_y
    when "time" then cfg.use_time
    when "accel" then cfg.use_scalar and cfg.include_transform_args
    when "pathscale" then cfg.use_scalar
    when "discrete" then cfg.use_scalar
    else cfg.use_scalar

gun_clip_has_vector_commands = (value) ->
  stripped = tostring(value or "")\gsub "^%(", ""
  stripped = stripped\gsub "%)$", ""
  stripped\match("[mnlbspcMNLBSPC]") != nil

gun_clip_has_scale_prefix = (value) ->
  return false unless gun_clip_has_vector_commands value
  body = tostring(value or "")\gsub "^%(", ""
  body = body\gsub "%)$", ""
  body\match("^%s*[%+%-]?%d*%.?%d+%s*,%s*[mnlbspcMNLBSPC]") != nil

gun_classify_number = (key, index, value) ->
  return "x" if key == "fscx" or key == "xbord" or key == "xshad" or key == "fax"
  return "y" if key == "fscy" or key == "ybord" or key == "yshad" or key == "fay"
  return "discrete" if key == "an" or key == "a" or key == "q" or key == "b" or key == "i" or key == "u" or key == "s" or key == "p" or key == "fe" or key == "be"
  return "time" if key == "fad" or key == "k" or key == "kf" or key == "ko"
  if key == "pos" or key == "org"
    return if index % 2 == 1 then "x" else "y"
  if key == "move"
    return "time" if index >= 5
    return if index % 2 == 1 then "x" else "y"
  if key == "clip" or key == "iclip"
    offset = if gun_clip_has_scale_prefix(value) then 1 else 0
    return "pathscale" if offset == 1 and index == 1
    coord_index = index - offset
    return if coord_index % 2 == 1 then "x" else "y"
  if key == "fade"
    return if index <= 3 then "scalar" else "time"
  "scalar"

gun_spec_for = (key, category) ->
  return GUN_TAG_SPEC.time if category == "time"
  return GUN_TAG_SPEC.accel if category == "accel"
  return GUN_TAG_SPEC.fade_alpha if key == "fade" and category == "scalar"
  GUN_TAG_SPEC[key] or {}

gun_delta_key = (ctx, key, category, token_index, cfg) ->
  scope = cfg.random_scope or "Each value"
  if scope == "Each value"
    ctx.value_counter = (ctx.value_counter or 0) + 1
    return "v:" .. tostring(ctx.line_index) .. ":" .. tostring(ctx.value_counter)
  if scope == "Same per line"
    return "line:" .. tostring(ctx.line_index)
  if scope == "Same per tag"
    return "tag:" .. tostring(ctx.line_index) .. ":" .. tostring(ctx.block_index) .. ":" .. tostring(ctx.tag_index)
  if scope == "Axis per line"
    if category == "x" or category == "y"
      return "line-axis:" .. tostring(ctx.line_index) .. ":" .. category
    return "line:" .. tostring(ctx.line_index)
  if scope == "Axis per tag"
    if category == "x" or category == "y"
      return "tag-axis:" .. tostring(ctx.line_index) .. ":" .. tostring(ctx.block_index) .. ":" .. tostring(ctx.tag_index) .. ":" .. category
    return "tag:" .. tostring(ctx.line_index) .. ":" .. tostring(ctx.block_index) .. ":" .. tostring(ctx.tag_index)
  "fallback:" .. tostring(ctx.line_index) .. ":" .. tostring(ctx.block_index) .. ":" .. tostring(ctx.tag_index) .. ":" .. tostring(token_index)

gun_random_delta = (ctx, key, category, token_index, cfg) ->
  cache_key = gun_delta_key ctx, key, category, token_index, cfg
  return ctx.cache[cache_key] if ctx.cache[cache_key] != nil
  min_delta, max_delta = tonumber(cfg.min_delta) or 0, tonumber(cfg.max_delta) or 0
  if min_delta > max_delta
    min_delta, max_delta = max_delta, min_delta
  delta = min_delta + math.random! * (max_delta - min_delta)
  step = tonumber(cfg.step) or 0
  if step > 0
    delta = round_int(delta / step) * step
    delta = clamp delta, min_delta, max_delta
  ctx.cache[cache_key] = delta
  delta

gun_apply_limits = (value, spec, cfg) ->
  spec or= {}
  if cfg.protect_discrete and spec.integer
    value = round_int value
  if cfg.clamp_nonnegative and spec.nonnegative
    value = math.max 0, value
  value = math.max spec.min, value if spec.min != nil
  value = math.min spec.max, value if spec.max != nil
  value

gun_apply_number = (token, key, category, index, cfg, ctx) ->
  return token.raw unless gun_category_enabled category, cfg
  value = tonumber token.value
  return token.raw unless value
  delta = gun_random_delta ctx, key, category, index, cfg
  spec = gun_spec_for key, category
  value = gun_apply_limits value + delta, spec, cfg
  decimals = tonumber(cfg.decimals) or 3
  decimals = 0 if cfg.protect_discrete and spec.integer
  format_num value, decimals

gun_normalize_hex = (hex, width) ->
  hex = tostring(hex or "")\upper!
  hex = hex\gsub "[^0-9A-F]", ""
  hex = hex\sub -width if #hex > width
  while #hex < width
    hex = "0" .. hex
  hex

gun_hex_byte = (hex, start_pos) ->
  tonumber(hex\sub(start_pos, start_pos + 1), 16) or 0

gun_apply_byte = (value, key, index, cfg, ctx) ->
  return value unless gun_category_enabled "scalar", cfg
  delta = gun_random_delta ctx, key, "scalar", index, cfg
  round_int gun_apply_limits value + delta, GUN_TAG_SPEC.color_channel, cfg

gun_process_alpha_tag = (tag, key, cfg, ctx) ->
  hex = tag.raw\match "&[Hh]([%x]+)&?"
  return tag.raw, 0 unless hex
  hex = gun_normalize_hex hex, 2
  old = gun_hex_byte hex, 1
  new_value = gun_apply_byte old, key, 1, cfg, ctx
  return tag.raw, 0 if new_value == old
  next_hex = ("&H%02X&")\format new_value
  (tag.raw\gsub "&[Hh][%x]+&?", next_hex, 1), 1

gun_process_color_tag = (tag, key, cfg, ctx) ->
  hex = tag.raw\match "&[Hh]([%x]+)&?"
  return tag.raw, 0 unless hex
  hex = gun_normalize_hex hex, 6
  values = {gun_hex_byte(hex, 1), gun_hex_byte(hex, 3), gun_hex_byte(hex, 5)}
  changed = 0
  for i = 1, 3
    new_value = gun_apply_byte values[i], key, i, cfg, ctx
    if new_value != values[i]
      values[i] = new_value
      changed += 1
  return tag.raw, 0 if changed == 0
  next_hex = ("&H%02X%02X%02X&")\format values[1], values[2], values[3]
  (tag.raw\gsub "&[Hh][%x]+&?", next_hex, 1), changed

gun_replace_number_tokens = (raw, numbers, key, cfg, ctx, value) ->
  return raw, 0 unless numbers and #numbers > 0
  out = {}
  pos = 1
  changed = 0
  for index, token in ipairs numbers
    out[#out + 1] = raw\sub pos, token.start_pos - 1
    category = gun_classify_number key, index, value
    next_raw = gun_apply_number token, key, category, index, cfg, ctx
    out[#out + 1] = next_raw
    changed += 1 if next_raw != token.raw
    pos = token.end_pos + 1
  out[#out + 1] = raw\sub pos
  table.concat(out), changed

gun_transform_parts = (raw) ->
  inner = tostring(raw or "")\match "^\\t%((.*)%)$"
  return nil unless inner
  tag_start = inner\find "\\", 1, true
  unless tag_start
    return inner, "", ""
  inner\sub(1, tag_start - 1), inner\sub(tag_start), inner

gun_classify_transform_arg = (index, total) ->
  if total == 1
    "accel"
  elseif total == 2
    "time"
  elseif index <= 2
    "time"
  elseif index == 3
    "accel"
  else
    "scalar"

gun_replace_transform_args = (prefix, cfg, ctx) ->
  numbers = gun_scan_numbers prefix
  return prefix, 0 unless #numbers > 0
  out = {}
  pos = 1
  changed = 0
  for index, token in ipairs numbers
    out[#out + 1] = prefix\sub pos, token.start_pos - 1
    category = gun_classify_transform_arg index, #numbers
    next_raw = if gun_category_enabled(category, cfg) then gun_apply_number(token, "t", category, index, cfg, ctx) else token.raw
    out[#out + 1] = next_raw
    changed += 1 if next_raw != token.raw
    pos = token.end_pos + 1
  out[#out + 1] = prefix\sub pos
  table.concat(out), changed

gun_process_block_content = nil

gun_process_transform_tag = (tag, selected, cfg, ctx) ->
  prefix, mods = gun_transform_parts tag.raw
  return tag.raw, 0 unless prefix != nil
  changed = 0
  next_prefix = prefix
  if gun_is_selected("t", selected) and cfg.include_transform_args
    next_prefix, c = gun_replace_transform_args prefix, cfg, ctx
    changed += c
  next_mods = mods
  if mods != "" and cfg.include_transform_inner
    next_mods, c = gun_process_block_content mods, selected, cfg, ctx, true
    changed += c
  "\\t(" .. next_prefix .. next_mods .. ")", changed

gun_process_tag = (tag, selected, cfg, ctx) ->
  key = GUN_NAME_TO_KEY[tag.name]
  return gun_process_transform_tag tag, selected, cfg, ctx if tag.name == "t"
  return tag.raw, 0 unless key and gun_is_selected key, selected
  return gun_process_color_tag tag, key, cfg, ctx if GUN_COLOR_KEYS[key]
  return gun_process_alpha_tag tag, key, cfg, ctx if GUN_ALPHA_KEYS[key]
  numbers = gun_scan_numbers tag.raw
  gun_replace_number_tokens tag.raw, numbers, key, cfg, ctx, tag.value

gun_process_block_content = (content, selected, cfg, ctx) ->
  content = tostring content or ""
  tags = gun_parse_tag_block content
  return content, 0 if #tags == 0
  out = {}
  pos = 1
  changed = 0
  for tag_index, tag in ipairs tags
    ctx.tag_index = tag_index
    out[#out + 1] = content\sub pos, tag.start_pos - 1
    next_raw, c = gun_process_tag tag, selected, cfg, ctx
    out[#out + 1] = next_raw
    changed += c
    pos = tag.end_pos + 1
  out[#out + 1] = content\sub pos
  table.concat(out), changed

gun_process_text = (text, selected, cfg, line_index = 1, shared_cache = nil) ->
  text = tostring text or ""
  out = {}
  pos = 1
  changed = 0
  ctx = {line_index: line_index, cache: shared_cache or {}, value_counter: 0}
  blocks = gun_iter_tag_blocks text
  for block_index, block in ipairs blocks
    ctx.block_index = block_index
    out[#out + 1] = text\sub pos, block.open_pos - 1
    first = block.content\sub 1, 1
    if (first == "*" or first == ">") and not cfg.include_auto_blocks
      out[#out + 1] = text\sub block.open_pos, block.close_pos
    else
      next_content, c = gun_process_block_content block.content, selected, cfg, ctx
      out[#out + 1] = "{" .. next_content .. "}"
      changed += c
    pos = block.close_pos + 1
  out[#out + 1] = text\sub pos
  table.concat(out), changed

gun_mark_key = (found, key) ->
  return unless key
  found[key] or= {count: 0}
  found[key].count += 1

gun_collect_from_block = nil

gun_collect_from_transform = (tag, found, include_auto) ->
  prefix, mods = gun_transform_parts tag.raw
  gun_mark_key found, "t" if prefix != nil and #gun_scan_numbers(prefix) > 0
  gun_collect_from_block mods, found, include_auto if mods and mods != ""

gun_collect_from_block = (content, found, include_auto) ->
  for tag in *gun_parse_tag_block content
    if tag.name == "t"
      gun_collect_from_transform tag, found, include_auto
    else
      key = GUN_NAME_TO_KEY[tag.name]
      if key and (GUN_COLOR_KEYS[key] or GUN_ALPHA_KEYS[key])
        gun_mark_key found, key if tag.raw\match "&[Hh][%x]+&?"
      elseif key and #gun_scan_numbers(tag.raw) > 0
        gun_mark_key found, key

gun_collect_numeric_tags = (subs, sel, include_auto = false) ->
  found = {}
  for index in *(sel or {})
    line = subs[index]
    if is_dialogue line
      for block in *gun_iter_tag_blocks(line.text or "")
        first = block.content\sub 1, 1
        continue if (first == "*" or first == ">") and not include_auto
        gun_collect_from_block block.content, found, include_auto
  found

gun_has_any_selected = (selected) ->
  for _, value in pairs selected or {}
    return true if value
  false

gun_seed_random = (seed) ->
  seed = tonumber(seed) or 0
  seed = os.time! if seed <= 0
  math.randomseed seed
  math.random!
  math.random!
  seed

TRANSITION_CANON = {fr: "frz", ["1c"]: "c"}

TRANSITION_ANIMATABLE = {
  clip: true, iclip: true
  fs: true, fsp: true, fscx: true, fscy: true
  frz: true, frx: true, fry: true, fax: true, fay: true
  bord: true, xbord: true, ybord: true
  shad: true, xshad: true, yshad: true
  blur: true, be: true
  c: true, ["2c"]: true, ["3c"]: true, ["4c"]: true
  alpha: true, ["1a"]: true, ["2a"]: true, ["3a"]: true, ["4a"]: true
}

TRANSITION_STATIC = {
  an: true, a: true, q: true, fn: true, r: true
  b: true, i: true, u: true, s: true
  p: true, pbo: true, fe: true
}

transition_canonical = (name) ->
  TRANSITION_CANON[name] or name

parse_transition_tags = (blocks) ->
  tags, order = {}, {}
  for t in *parse_tag_block blocks
    continue if t.name == "t"
    key = transition_canonical t.name
    order[#order + 1] = key unless tags[key]
    tags[key] = {name: t.name, key: key, value: t.value, raw: t.raw}
  tags, order

transition_position = (tags, final) ->
  t = tags.pos
  if t
    nums = tag_numbers t.value
    return {x: nums[1], y: nums[2]} if nums[1] and nums[2]
  t = tags.move
  if t
    nums = tag_numbers t.value
    if nums[1] and nums[2] and nums[3] and nums[4]
      x_index = if final then 3 else 1
      y_index = if final then 4 else 2
      return {x: nums[x_index], y: nums[y_index]}
  nil

transition_fad_value = (tag, slot) ->
  return 0 unless tag and tag.key == "fad"
  nums = tag_numbers tag.value
  math.max 0, math.floor((nums[slot] or 0) + 0.5)

transition_tag_text = (tag) ->
  "\\" .. tag.name .. tostring(tag.value or "")

choose_transition_body = (body1, body2) ->
  return body1 if strip_tags(body1) == strip_tags(body2)
  b1, b2, bc = Core.L("use_line1"), Core.L("use_line2"), Core.L("cancel")
  button = aegisub.dialog.display {
    {class: "textbox", text: Core.L("choose_text"), x: 0, y: 0, width: 34, height: 4}
  }, {b1, b2, bc}, {cancel: bc, close: bc}
  if button == b2 then body2 elseif button == b1 then body1 else nil

apply_in_out_tags = (subs, sel, cfg = {}) ->
  indices = [i for i in *(sel or {})]
  table.sort indices
  unless #indices == 2
    show_message Core.L("in_out_need_two")
    return false
  idx1, idx2 = indices[1], indices[2]
  line1 = clone_line subs[idx1]
  line2 = clone_line subs[idx2]
  unless is_dialogue(line1) and is_dialogue(line2)
    show_message Core.L("in_out_need_two")
    return false
  tags_text1, body1 = split_leading_tag_blocks line1.text
  tags_text2, body2 = split_leading_tag_blocks line2.text
  final_text = choose_transition_body body1, body2
  return false unless final_text

  tags1, order1 = parse_transition_tags tags_text1
  tags2, order2 = parse_transition_tags tags_text2
  parts, used = {}, {}
  pos1 = transition_position tags1, false
  pos2 = transition_position tags2, true
  if pos1 and pos2 and (pos1.x != pos2.x or pos1.y != pos2.y)
    parts[#parts + 1] = "\\move(" .. format_num(pos1.x, 3) .. "," .. format_num(pos1.y, 3) .. "," .. format_num(pos2.x, 3) .. "," .. format_num(pos2.y, 3) .. ")"
  elseif pos1
    parts[#parts + 1] = "\\pos(" .. format_num(pos1.x, 3) .. "," .. format_num(pos1.y, 3) .. ")"

  for key in *order1
    t1, t2 = tags1[key], tags2[key]
    if TRANSITION_ANIMATABLE[key]
      parts[#parts + 1] = transition_tag_text t1
      parts[#parts + 1] = "\\t(" .. transition_tag_text(t2) .. ")" if t2 and t1.raw != t2.raw
      used[key] = true
    elseif TRANSITION_STATIC[key]
      parts[#parts + 1] = transition_tag_text t1
      used[key] = true

  for key in *order2
    if TRANSITION_ANIMATABLE[key] and not used[key]
      parts[#parts + 1] = "\\t(" .. transition_tag_text(tags2[key]) .. ")"
      used[key] = true

  fad_in = transition_fad_value tags1.fad, 1
  fad_out = transition_fad_value tags2.fad, 2
  parts[#parts + 1] = "\\fad(" .. fad_in .. "," .. fad_out .. ")" if fad_in > 0 or fad_out > 0

  new_line = clone_line line1
  new_line.start_time = line1.start_time
  new_line.end_time = line2.end_time
  new_line.comment = false
  new_line.text = (if #parts > 0 then "{" .. table.concat(parts) .. "}" else "") .. final_text
  line1.comment = true
  line2.comment = true
  subs[idx1] = line1
  subs[idx2] = line2
  subs.insert idx2 + 1, new_line
  aegisub.set_undo_point "Obake - In-Out tags"
  show_message Core.L("in_out_created") unless cfg.quiet
  true

html_to_ass = (value) ->
  ass_color_value value

color_norm = (value) ->
  ass_color_value value

color_from_style = (value) ->
  if type(value) == "string"
    return ass_color_value value
  if type(value) == "number"
    n = value
    n += 4294967296 if n < 0
    return ass_color_value string.format("&H%06X&", n % 16777216)
  "&HFFFFFF&"

style_map = (subs) ->
  styles = {}
  for i = 1, #subs
    line = subs[i]
    if line and line.class == "style" and line.name
      styles[line.name] = line
  styles

line_duration = (line) ->
  math.max 0, (tonumber(line and line.end_time) or 0) - (tonumber(line and line.start_time) or 0)

current_frame_ms = ->
  return nil, "No video frame API." unless aegisub and aegisub.project_properties
  props = aegisub.project_properties!
  frame = props and props.video_position
  return nil, "No active video frame." unless frame
  if aegisub.ms_from_frame
    return aegisub.ms_from_frame(frame), nil
  nil, "aegisub.ms_from_frame is unavailable."

frame_slices = (start_ms, end_ms, period_frames = 1) ->
  unless aegisub and aegisub.frame_from_ms and aegisub.ms_from_frame
    return nil, Core.L("frame_api_missing")
  start_ms = math.floor((tonumber(start_ms) or 0) + 0.5)
  end_ms = math.floor((tonumber(end_ms) or start_ms) + 0.5)
  return {}, nil unless end_ms > start_ms
  period = math.max 1, math.floor((tonumber(period_frames) or 1) + 0.5)
  start_frame = tonumber aegisub.frame_from_ms start_ms
  last_frame = tonumber aegisub.frame_from_ms math.max(start_ms, end_ms - 1)
  return nil, Core.L("frame_api_missing") unless start_frame and last_frame
  slices = {}
  frame = start_frame
  while frame <= last_frame
    next_frame = math.min frame + period, last_frame + 1
    slice_start = tonumber(aegisub.ms_from_frame frame) or start_ms
    slice_end = tonumber(aegisub.ms_from_frame next_frame) or end_ms
    slice_start = math.max start_ms, math.floor(slice_start + 0.5)
    slice_end = math.min end_ms, math.floor(slice_end + 0.5)
    slice_end = math.min end_ms, slice_start + 1 if slice_end <= slice_start
    slices[#slices + 1] = {start_time: slice_start, end_time: slice_end} if slice_end > slice_start
    frame = next_frame
  slices, nil

line_is_single_frame = (line) ->
  slices = frame_slices line.start_time, line.end_time, 1
  slices and #slices == 1

selection_is_single_frame_fbf = (subs, indices) ->
  return false unless aegisub and aegisub.frame_from_ms and aegisub.ms_from_frame
  return false unless indices and #indices > 0
  for index in *indices
    return false unless line_is_single_frame subs[index]
  true

resolve_offset = (line, dur, cfg) ->
  mode = cfg.delay_mode or "No delay"
  return 0 if mode == "No delay"
  if mode == "ms from start"
    return clamp cfg.delay_val, 0, dur
  if mode == "Percent (%)"
    return math.floor(dur * clamp((tonumber(cfg.delay_val) or 0) / 100, 0, 1) + 0.5)
  if mode == "Current frame"
    fms = current_frame_ms!
    return clamp((fms or line.start_time) - line.start_time, 0, dur) if fms
  0

interpolate_simple = (ini, fin, factor) ->
  ini, fin = tostring(ini or ""), tostring(fin or "")
  return fin if ini == "" or fin == ""
  prefix1, num1 = ini\match "^(.-)([%-%d%.]+)$"
  prefix2, num2 = fin\match "^(.-)([%-%d%.]+)$"
  if num1 and num2 and prefix1 == prefix2
    n1, n2 = tonumber(num1), tonumber(num2)
    if n1 and n2
      return prefix2 .. format_num(n1 + (n2 - n1) * factor, 2)
  fin

chain_default_rows = ->
  {
    {time: 0, tags: "\\fscx100\\fscy100"}
    {time: 100, tags: "\\fscx110\\fscy110"}
  }

normalize_chain_state = (state) ->
  state or= {}
  state.time_unit = enum_value state.time_unit, TIME_UNITS, DEFAULTS.time_unit
  state.chain_shape = enum_value state.chain_shape, CHAIN_SHAPES, DEFAULTS.chain_shape
  state.strip_existing = state.strip_existing != false
  state.use_accel = state.use_accel and true or false
  state.accel = math.max 0.01, tonumber(state.accel) or DEFAULTS.accel
  state.shape_val = tonumber(state.shape_val) or DEFAULTS.shape_val
  state.delay_mode = enum_value state.delay_mode, DELAY_MODES, DEFAULTS.delay_mode
  state.delay_val = tonumber(state.delay_val) or 0
  rows = {}
  for row in *(state.rows or chain_default_rows!)
    tags = tostring(row.tags or "")
    time = tonumber(row.time)
    if time != nil or tags != ""
      rows[#rows + 1] = {time: time or 0, tags: tags}
  rows = chain_default_rows! if #rows < 2
  state.rows = rows
  state

build_shape_chain = (line, state) ->
  dur = line_duration line
  return "" unless dur > 0
  rows = state.rows or chain_default_rows!
  tags_ini = rows[1] and rows[1].tags or ""
  tags_fin = rows[#rows] and rows[#rows].tags or ""
  accel = if state.use_accel then state.accel else nil
  offset = resolve_offset line, dur, state
  eff_dur = dur - offset
  return "" unless eff_dur > 0
  t_end = offset + eff_dur
  payload = tags_ini
  switch state.chain_shape
    when "Once (one-way)"
      payload ..= transform_tag offset, t_end, tags_fin, accel if tags_fin != ""
    when "Out and back"
      mid = offset + eff_dur / 2
      payload ..= transform_tag offset, mid, tags_fin, accel if tags_fin != ""
      payload ..= transform_tag mid, t_end, tags_ini, accel if tags_ini != ""
    when "Yoyo (N cycles)"
      cycles = math.max 1, math.floor(tonumber(state.shape_val) or 1)
      seg = eff_dur / (cycles * 2)
      for i = 0, cycles * 2 - 1
        t1 = offset + seg * i
        t2 = offset + seg * (i + 1)
        payload ..= transform_tag(t1, t2, if i % 2 == 0 then tags_fin else tags_ini, accel)
    when "Pulse (ms)"
      half = math.max 20, math.floor(tonumber(state.shape_val) or 200)
      t, forward = offset, true
      while t < t_end
        t2 = math.min t + half, t_end
        payload ..= transform_tag(t, t2, if forward then tags_fin else tags_ini, accel)
        t = t2
        forward = not forward
    when "Steps (N)"
      steps = math.max 2, math.floor(tonumber(state.shape_val) or 4)
      for i = 1, steps
        factor = (i - 1) / (steps - 1)
        t1 = offset + (eff_dur / steps) * (i - 1)
        t2 = offset + (eff_dur / steps) * i
        payload ..= transform_tag t1, t2, interpolate_simple(tags_ini, tags_fin, factor), accel
  payload

build_manual_chain = (line, state) ->
  dur = line_duration line
  return "" unless dur > 0
  rows = {}
  for row in *(state.rows or {})
    tags = tostring(row.tags or "")
    continue if tags == ""
    raw_time = tonumber(row.time) or 0
    t = if state.time_unit == "Percent" then dur * raw_time / 100 else raw_time
    t = clamp t, 0, dur
    rows[#rows + 1] = {time: t, tags: tags}
  table.sort rows, (a, b) -> a.time < b.time
  return "" if #rows == 0
  accel = if state.use_accel then state.accel else nil
  payload = rows[1].tags
  for i = 2, #rows
    prev = rows[i - 1]
    row = rows[i]
    payload ..= transform_tag prev.time, row.time, row.tags, accel
  payload

build_chain = (line, state) ->
  state = normalize_chain_state state
  if state.chain_shape == "Manual keyframes"
    build_manual_chain line, state
  else
    build_shape_chain line, state

apply_chain = (subs, sel, state) ->
  count, errors = 0, {}
  state = normalize_chain_state state
  for i in *(sel or {})
    line = clone_line subs[i]
    if is_dialogue line
      dur = line_duration line
      if dur <= 0
        errors[#errors + 1] = "#{Core.L('line')} #{i}: #{Core.L('zero_duration')}"
      else
        payload = build_chain line, state
        if payload != ""
          text = line.text or ""
          text = strip_transforms text if state.strip_existing
          line.text = inject_first text, payload
          subs[i] = line
          count += 1
  if count > 0
    aegisub.set_undo_point "Obake - Apply chain"
    return true
  show_message if #errors > 0 then table.concat(errors, "\n") else Core.L("no_transform_chain")
  false

read_chain_state = (res, count) ->
  state = {
    time_unit: res.time_unit
    chain_shape: res.chain_shape
    strip_existing: res.strip_existing
    use_accel: res.use_accel
    accel: res.accel
    shape_val: res.shape_val
    delay_mode: res.delay_mode
    delay_val: res.delay_val
    rows: {}
  }
  for i = 1, count
    state.rows[#state.rows + 1] = {
      time: tonumber(res["time#{i}"]) or 0
      tags: tostring(res["tags#{i}"] or "")
    }
  normalize_chain_state state

common_tag_rows = ->
  math.ceil #COMMON_TAGS / COMMON_TAG_COLUMNS

add_common_tag_grid = (gui, y) ->
  gui[#gui + 1] = {class: "label", label: Core.L("common_tags"), x: 0, y: y, width: CHAIN_DIALOG_W}
  for i, tag in ipairs COMMON_TAGS
    index = i - 1
    col = index % COMMON_TAG_COLUMNS
    row = math.floor index / COMMON_TAG_COLUMNS
    gui[#gui + 1] = {
      class: "textbox"
      name: "common#{i}"
      text: tag
      x: col * COMMON_TAG_W
      y: y + 1 + row
      width: COMMON_TAG_W
      height: 1
    }
  y + 1 + common_tag_rows!

build_chain_gui = (state) ->
  state = normalize_chain_state state
  shape_items, shape_map, shape_shown = Core.dropdown_data CHAIN_SHAPES
  delay_items, delay_map, delay_shown = Core.dropdown_data DELAY_MODES
  gui = {}
  controls_y = add_common_tag_grid(gui, 0) + 1
  gui[#gui + 1] = {class: "label", label: Core.L("time_unit"), x: 0, y: controls_y, width: 3}
  gui[#gui + 1] = {class: "dropdown", name: "time_unit", items: Core.localized_items(TIME_UNITS), value: Core.choice_label(state.time_unit), x: 3, y: controls_y, width: 5}
  gui[#gui + 1] = {class: "checkbox", name: "strip_existing", label: Core.L("strip_existing_t"), value: state.strip_existing, x: 9, y: controls_y, width: 8}
  gui[#gui + 1] = {class: "checkbox", name: "use_accel", label: Core.L("accel"), value: state.use_accel, x: 18, y: controls_y, width: 2}
  gui[#gui + 1] = {class: "floatedit", name: "accel", value: state.accel, min: 0.01, max: 10, x: 20, y: controls_y, width: 3}
  gui[#gui + 1] = {class: "label", label: Core.L("shape"), x: 0, y: controls_y + 1, width: 3}
  gui[#gui + 1] = {class: "dropdown", name: "chain_shape", items: shape_items, value: Core.shown_choice(shape_shown, state.chain_shape), x: 3, y: controls_y + 1, width: 7}
  gui[#gui + 1] = {class: "label", label: Core.L("value"), x: 11, y: controls_y + 1, width: 3}
  gui[#gui + 1] = {class: "floatedit", name: "shape_val", value: state.shape_val, min: 0, x: 14, y: controls_y + 1, width: 3}
  gui[#gui + 1] = {class: "label", label: Core.L("delay"), x: 0, y: controls_y + 2, width: 3}
  gui[#gui + 1] = {class: "dropdown", name: "delay_mode", items: delay_items, value: Core.shown_choice(delay_shown, state.delay_mode), x: 3, y: controls_y + 2, width: 7}
  gui[#gui + 1] = {class: "floatedit", name: "delay_val", value: state.delay_val, min: 0, x: 11, y: controls_y + 2, width: 3}
  header_y = controls_y + 4
  gui[#gui + 1] = {class: "label", label: Core.L("time"), x: 0, y: header_y, width: 3}
  gui[#gui + 1] = {class: "label", label: Core.L("tags"), x: 3, y: header_y, width: CHAIN_DIALOG_W - 3}
  y = header_y + 1
  for i, row in ipairs state.rows
    gui[#gui + 1] = {class: "edit", name: "time#{i}", value: format_num(row.time, 3), x: 0, y: y + i - 1, width: 3}
    gui[#gui + 1] = {class: "textbox", name: "tags#{i}", text: row.tags, x: 3, y: y + i - 1, width: CHAIN_DIALOG_W - 3, height: 1}
  gui, shape_map, delay_map

show_chain_options = ->
  state = normalize_chain_state {}
  while true
    gui, shape_map, delay_map = build_chain_gui state
    button, res = aegisub.dialog.display gui, {Core.L("apply"), "Add+", "Rem-", Core.L("reset"), Core.L("cancel")}, {ok: Core.L("apply"), close: Core.L("cancel")}
    return nil if button == Core.L("cancel") or not button
    if button == Core.L("reset")
      state = normalize_chain_state {}
      continue
    res.time_unit = Core.choice_raw res.time_unit
    res.chain_shape = Core.raw_choice shape_map, res.chain_shape
    res.delay_mode = Core.raw_choice delay_map, res.delay_mode
    state = read_chain_state res, #state.rows
    switch button
      when "Add+"
        if #state.rows < 12
          last = state.rows[#state.rows]
          state.rows[#state.rows + 1] = {time: last.time, tags: last.tags}
      when "Rem-"
        table.remove state.rows if #state.rows > 2
      when Core.L("apply")
        return state

html_color_controls = (x, y, color1, color2 = nil) ->
  out = {
    {class: "label", label: Core.L("color1"), x: x, y: y, width: 2}
    {class: "color", name: "fx_color", value: color1, x: x + 2, y: y, width: 2, height: 2}
  }
  if color2 != nil
    out[#out + 1] = {class: "label", label: Core.L("color2"), x: x + 5, y: y, width: 2}
    out[#out + 1] = {class: "color", name: "fx_color2", value: color2, x: x + 7, y: y, width: 2, height: 2}
  out

show_fx_options = ->
  fx_items, fx_map, fx_shown = Core.dropdown_data FX_ITEMS
  gui = {
    {class: "label", label: "FX:", x: 0, y: 0, width: 2}
    {class: "dropdown", name: "fx_preset", items: fx_items, value: Core.shown_choice(fx_shown, DEFAULTS.fx_preset), x: 2, y: 0, width: 8}
    {class: "checkbox", name: "strip_existing", label: Core.L("strip_existing_t"), value: DEFAULTS.strip_existing, x: 0, y: 1, width: 6}
    {class: "checkbox", name: "use_accel", label: Core.L("accel"), value: DEFAULTS.use_accel, x: 6, y: 1, width: 2}
    {class: "floatedit", name: "accel", value: DEFAULTS.accel, min: 0.01, max: 10, x: 8, y: 1, width: 3}
    {class: "label", label: Core.L("step_ms"), x: 0, y: 2, width: 2}
    {class: "intedit", name: "fx_step_ms", value: DEFAULTS.fx_step_ms, min: 1, x: 2, y: 2, width: 3}
    {class: "label", label: Core.L("amount"), x: 6, y: 2, width: 2}
    {class: "floatedit", name: "fx_amount", value: DEFAULTS.fx_amount, x: 8, y: 2, width: 3}
  }
  for item in *html_color_controls 0, 4, DEFAULTS.fx_color, DEFAULTS.fx_color2
    gui[#gui + 1] = item
  button, res = aegisub.dialog.display gui, {Core.L("apply"), Core.L("cancel")}, {ok: Core.L("apply"), close: Core.L("cancel")}
  return nil unless button == Core.L("apply")
  res.fx_preset = Core.raw_choice fx_map, res.fx_preset
  res.fx_color = html_to_ass res.fx_color
  res.fx_color2 = html_to_ass res.fx_color2
  res

show_preset_options = ->
  preset_items, preset_map, preset_shown = Core.dropdown_data CAL_PRESETS
  gui = {
    {class: "label", label: Core.L("preset"), x: 0, y: 0, width: 2}
    {class: "dropdown", name: "cal_preset", items: preset_items, value: Core.shown_choice(preset_shown, DEFAULTS.cal_preset), x: 2, y: 0, width: 9}
  }
  button, res = aegisub.dialog.display gui, {Core.L("apply"), Core.L("cancel")}, {ok: Core.L("apply"), close: Core.L("cancel")}
  return nil unless button == Core.L("apply")
  res.cal_preset = Core.raw_choice preset_map, res.cal_preset
  res

show_border_options = ->
  gui = {
    {class: "checkbox", name: "use_bord1", label: "B1", value: DEFAULTS.use_bord1, x: 0, y: 0, width: 2}
    {class: "floatedit", name: "bord1", value: DEFAULTS.bord1, min: 0, x: 2, y: 0, width: 3}
    {class: "color", name: "color1", value: DEFAULTS.color1, x: 5, y: 0, width: 2, height: 2}
    {class: "checkbox", name: "use_bord2", label: "B2", value: DEFAULTS.use_bord2, x: 0, y: 2, width: 2}
    {class: "floatedit", name: "bord2", value: DEFAULTS.bord2, min: 0, x: 2, y: 2, width: 3}
    {class: "color", name: "color2", value: DEFAULTS.color2, x: 5, y: 2, width: 2, height: 2}
    {class: "checkbox", name: "use_bord3", label: "B3", value: DEFAULTS.use_bord3, x: 0, y: 4, width: 2}
    {class: "floatedit", name: "bord3", value: DEFAULTS.bord3, min: 0, x: 2, y: 4, width: 3}
    {class: "color", name: "color3", value: DEFAULTS.color3, x: 5, y: 4, width: 2, height: 2}
    {class: "checkbox", name: "use_bord4", label: "B4", value: DEFAULTS.use_bord4, x: 0, y: 6, width: 2}
    {class: "floatedit", name: "bord4", value: DEFAULTS.bord4, min: 0, x: 2, y: 6, width: 3}
    {class: "color", name: "color4", value: DEFAULTS.color4, x: 5, y: 6, width: 2, height: 2}
  }
  button, res = aegisub.dialog.display gui, {Core.L("apply"), Core.L("cancel")}, {ok: Core.L("apply"), close: Core.L("cancel")}
  return nil unless button == Core.L("apply")
  res.color1 = html_to_ass res.color1
  res.color2 = html_to_ass res.color2
  res.color3 = html_to_ass res.color3
  res.color4 = html_to_ass res.color4
  res

gun_config_state = (interface) ->
  state = {}
  for _, item in pairs interface.main
    if item.config and item.name
      state[item.name] = item.value
  state

gun_build_interface = (found, state) ->
  state or= GUN_DEFAULTS
  main = {
    title: {class: "label", label: "Gunfight of Tags - numeric override tags", x: 0, y: 0, width: 16, height: 1}
    min_label: {class: "label", label: "Min", x: 0, y: 1, width: 2, height: 1}
    min_delta: {class: "floatedit", name: "min_delta", value: state.min_delta, config: true, x: 2, y: 1, width: 3, height: 1}
    max_label: {class: "label", label: "Max", x: 5, y: 1, width: 2, height: 1}
    max_delta: {class: "floatedit", name: "max_delta", value: state.max_delta, config: true, x: 7, y: 1, width: 3, height: 1}
    step_label: {class: "label", label: "Step", x: 10, y: 1, width: 2, height: 1}
    step: {class: "floatedit", name: "step", value: state.step, min: 0, config: true, x: 12, y: 1, width: 3, height: 1}
    dec_label: {class: "label", label: "Dec", x: 0, y: 2, width: 2, height: 1}
    decimals: {class: "intedit", name: "decimals", value: state.decimals, min: 0, max: 8, config: true, x: 2, y: 2, width: 2, height: 1}
    seed_label: {class: "label", label: "Seed", x: 4, y: 2, width: 2, height: 1}
    seed: {class: "intedit", name: "seed", value: state.seed, min: 0, max: 999999999, config: true, x: 6, y: 2, width: 4, height: 1}
    fbf_label: {class: "label", label: Core.L("fbf_period"), x: 10, y: 2, width: 3, height: 1}
    fbf_period: {class: "intedit", name: "fbf_period", value: state.fbf_period, min: 1, max: 999, config: true, x: 13, y: 2, width: 3, height: 1}
    scope_label: {class: "label", label: "Link", x: 0, y: 3, width: 2, height: 1}
    random_scope: {class: "dropdown", name: "random_scope", items: GUN_RANDOM_SCOPES, value: gun_choice_or_default(state.random_scope, GUN_RANDOM_SCOPES, GUN_DEFAULTS.random_scope), config: true, x: 2, y: 3, width: 4, height: 1}
    save_settings: {class: "checkbox", name: "save_settings", label: "Save", value: state.save_settings, config: true, x: 6, y: 3, width: 2, height: 1}
    show_report: {class: "checkbox", name: "show_report", label: "Report", value: state.show_report, config: true, x: 8, y: 3, width: 3, height: 1}
    selection_as_fbf_unit: {class: "checkbox", name: "selection_as_fbf_unit", label: Core.L("selection_as_fbf_unit"), value: state.selection_as_fbf_unit != false, config: true, x: 0, y: 4, width: 10, height: 1}
    use_x: {class: "checkbox", name: "use_x", label: "X coords", value: state.use_x, config: true, x: 0, y: 5, width: 2, height: 1}
    use_y: {class: "checkbox", name: "use_y", label: "Y coords", value: state.use_y, config: true, x: 2, y: 5, width: 2, height: 1}
    use_scalar: {class: "checkbox", name: "use_scalar", label: "Scalar/discrete", value: state.use_scalar, config: true, x: 4, y: 5, width: 3, height: 1}
    use_time: {class: "checkbox", name: "use_time", label: "Times", value: state.use_time, config: true, x: 7, y: 5, width: 2, height: 1}
    include_transform_inner: {class: "checkbox", name: "include_transform_inner", label: "Inside \\t", value: state.include_transform_inner, config: true, x: 0, y: 6, width: 2, height: 1}
    include_transform_args: {class: "checkbox", name: "include_transform_args", label: "\\t args", value: state.include_transform_args, config: true, x: 2, y: 6, width: 2, height: 1}
    include_auto_blocks: {class: "checkbox", name: "include_auto_blocks", label: "{*} blocks", value: state.include_auto_blocks, config: true, x: 4, y: 6, width: 2, height: 1}
    clamp_nonnegative: {class: "checkbox", name: "clamp_nonnegative", label: "Clamp >=0", value: state.clamp_nonnegative, config: true, x: 6, y: 6, width: 2, height: 1}
    protect_discrete: {class: "checkbox", name: "protect_discrete", label: "Discrete safe", value: state.protect_discrete, config: true, x: 8, y: 6, width: 2, height: 1}
    note: {class: "label", label: "Tags shown are numeric/hex tags found in the current selection.", x: 0, y: 7, width: 16, height: 1}
  }
  row0 = 9
  shown = 0
  for def in *GUN_TAG_DEFS
    meta = found[def.key]
    if meta
      col = shown % 6
      row = math.floor shown / 6
      main["tag_" .. def.key] = {
        class: "checkbox"
        name: "tag_" .. def.key
        label: def.label .. " (" .. tostring(meta.count) .. ")"
        value: state["tag_" .. def.key] == true
        config: true
        x: col * 2
        y: row0 + row
        width: 2
        height: 1
      }
      shown += 1
  main.no_tags = {class: "label", label: Core.L("no_numeric_tags"), x: 0, y: row0, width: 8, height: 1} if shown == 0
  {main: main}

gun_read_state_from_result = (result, found) ->
  state = {}
  for key, value in pairs GUN_DEFAULTS
    state[key] = value
  state.min_delta = tonumber(result.min_delta) or GUN_DEFAULTS.min_delta
  state.max_delta = tonumber(result.max_delta) or GUN_DEFAULTS.max_delta
  state.step = math.max 0, tonumber(result.step) or GUN_DEFAULTS.step
  state.decimals = clamp round_int(result.decimals), 0, 8
  state.seed = clamp round_int(result.seed), 0, 999999999
  state.random_scope = gun_choice_or_default result.random_scope, GUN_RANDOM_SCOPES, GUN_DEFAULTS.random_scope
  state.use_x = result.use_x == true
  state.use_y = result.use_y == true
  state.use_scalar = result.use_scalar == true
  state.use_time = result.use_time == true
  state.include_transform_inner = result.include_transform_inner == true
  state.include_transform_args = result.include_transform_args == true
  state.include_auto_blocks = result.include_auto_blocks == true
  state.clamp_nonnegative = result.clamp_nonnegative == true
  state.protect_discrete = result.protect_discrete == true
  state.save_settings = result.save_settings == true
  state.show_report = result.show_report == true
  state.fbf_period = math.max 1, round_int(result.fbf_period)
  state.selection_as_fbf_unit = result.selection_as_fbf_unit == true
  for def in *GUN_TAG_DEFS
    state["tag_" .. def.key] = result["tag_" .. def.key] == true if found[def.key]
  state

show_gunfight_options = (subs, sel) ->
  include_auto = GUN_DEFAULTS.include_auto_blocks
  found = gun_collect_numeric_tags subs or {}, sel or {}, include_auto
  cfg = nil
  while true
    interface = gun_build_interface found, GUN_DEFAULTS
    options = ConfigHandler interface, GUN_CONFIG_FILE, true, GUN_CONFIG_VERSION
    options\read!
    options\updateInterface "main"
    state = gun_config_state interface
    if cfg
      for key, value in pairs cfg
        state[key] = value
    while true
      interface = gun_build_interface found, state
      button, result = aegisub.dialog.display interface.main, {Core.L("apply"), "All", "Clear", Core.L("cancel")}, {ok: Core.L("apply"), close: Core.L("cancel")}
      return nil unless button and button != Core.L("cancel")
      state = gun_read_state_from_result result, found
      if button == "All"
        for def in *GUN_TAG_DEFS
          state["tag_" .. def.key] = true if found[def.key]
        continue
      if button == "Clear"
        for def in *GUN_TAG_DEFS
          state["tag_" .. def.key] = false if found[def.key]
        continue
      cfg = state
      break
    if cfg.include_auto_blocks == include_auto
      if cfg.save_settings
        options = ConfigHandler (gun_build_interface found, cfg), GUN_CONFIG_FILE, true, GUN_CONFIG_VERSION
        options\updateConfiguration cfg, "main"
        options\write!
      cfg.operation = "Gunfight of Tags"
      return cfg
    include_auto = cfg.include_auto_blocks
    found = gun_collect_numeric_tags subs or {}, sel or {}, include_auto

show_zigzag_options = ->
  gui = {
    period_label: {class: "label", label: Core.L("zigzag_period"), x: 0, y: 0, width: 2}
    period_frames: {class: "intedit", name: "period_frames", value: ZIGZAG_DEFAULTS.period_frames, min: 1, max: 999, x: 2, y: 0, width: 2, config: true}
  }
  options = ConfigHandler {main: gui}, ZIGZAG_CONFIG_FILE, true, script_version
  options\read!
  options\updateInterface "main"
  button, res = aegisub.dialog.display gui, {Core.L("apply"), Core.L("cancel")}, {ok: Core.L("apply"), close: Core.L("cancel")}
  return nil unless button == Core.L("apply")
  res.period_frames = math.max 1, round_int res.period_frames
  options\updateConfiguration res, "main"
  options\write!
  res

WINDOW_W = 24
PICKER_HELP_H = 10

Core.picker_help_text = (operation) ->
  Core.action_help(operation) or Core.L("select_action")

Core.action_picker_gui = (operation) ->
  items, to_raw, to_shown = Core.dropdown_data OPERATIONS, Core.operation_label
  gui = {
    {class: "label", label: Core.L("action"), x: 0, y: 0, width: 3}
    {class: "dropdown", name: "operation", items: items, value: Core.shown_choice(to_shown, operation or DEFAULTS.operation), x: 3, y: 0, width: WINDOW_W - 3}
    {class: "textbox", value: Core.picker_help_text(operation or DEFAULTS.operation), x: 0, y: 1, width: WINDOW_W, height: PICKER_HELP_H}
  }
  gui, to_raw, to_shown

Core.action_picker = ->
  current = DEFAULTS.operation
  while true
    gui, to_raw, to_shown = Core.action_picker_gui current
    btn_run, btn_help, btn_language, btn_cancel = Core.L("run"), Core.L("help"), Core.L("language"), Core.L("cancel")
    button, res = aegisub.dialog.display gui, {btn_run, btn_help, btn_language, btn_cancel}, {ok: btn_run, close: btn_cancel}
    chosen = Core.raw_operation_choice to_raw, res and res.operation or current
    if button == btn_help
      current = chosen
    elseif button == btn_language
      Core.toggle_language!
      current = chosen
    elseif button == btn_run
      return chosen or DEFAULTS.operation
    else
      aegisub.cancel!

Core.action_help_picker = ->
  current = DEFAULTS.operation
  while true
    gui, to_raw, to_shown = Core.action_picker_gui current
    btn_help, btn_language, btn_close = Core.L("help"), Core.L("language"), Core.L("close")
    button, res = aegisub.dialog.display gui, {btn_help, btn_language, btn_close}, {ok: btn_help, close: btn_close}
    if button == btn_help
      current = Core.raw_operation_choice to_raw, res and res.operation or current
    elseif button == btn_language
      current = Core.raw_operation_choice to_raw, res and res.operation or current
      Core.toggle_language!
    else
      return

Core.show_action_options = (operation, subs = nil, sel = nil, active = nil) ->
  return {operation: operation} if DIRECT_ACTIONS[operation]
  switch operation
    when "Apply chain" then show_chain_options!
    when "Animation FX" then show_fx_options!
    when "Color preset" then show_preset_options!
    when "Border layers" then show_border_options!
    when "Gunfight of Tags" then show_gunfight_options subs, sel
    when "ZigZag lines" then show_zigzag_options!
    else nil

selected_desc = (sel) ->
  out = [i for i in *(sel or {})]
  table.sort out, (a, b) -> a > b
  out

replace_line_with_many = (subs, index, lines) ->
  return false unless lines and #lines > 0
  subs.delete index
  for i = #lines, 1, -1
    subs.insert index, lines[i]
  true

gun_selected_tags = (cfg) ->
  selected = {}
  for def in *GUN_TAG_DEFS
    selected[def.key] = true if cfg["tag_" .. def.key]
  selected

selected_asc = (sel) ->
  out = [i for i in *(sel or {})]
  table.sort out
  out

gun_dialogue_indices = (subs, sel) ->
  out = {}
  for i in *selected_asc sel
    out[#out + 1] = i if is_dialogue subs[i]
  out

gun_process_line = (line, selected, cfg, sequence_index, cache = nil) ->
  next_text, count = gun_process_text line.text or "", selected, cfg, sequence_index, cache
  out = clone_line line
  out.text = next_text
  out, count, next_text != (line.text or "")

gun_fbf_lines_for_line = (line, selected, cfg, sequence_start = 1) ->
  slices, err = frame_slices line.start_time, line.end_time, cfg.fbf_period
  return nil, err if err
  return nil, Core.L("no_fbf_slices") unless slices and #slices > 0
  out = {}
  changed_tags = 0
  changed_text = 0
  for n, slice in ipairs slices
    next_line, count, changed = gun_process_line line, selected, cfg, sequence_start + n - 1
    next_line.start_time = slice.start_time
    next_line.end_time = slice.end_time
    out[#out + 1] = next_line
    changed_tags += count
    changed_text += 1 if changed
  out, nil, changed_tags, changed_text

apply_gunfight_of_tags = (subs, sel, cfg) ->
  cfg or= GUN_DEFAULTS
  selected = gun_selected_tags cfg
  unless gun_has_any_selected selected
    show_message Core.L("select_gun_tag")
    return false
  indices = gun_dialogue_indices subs, sel
  unless #indices > 0
    show_message Core.L("no_lines_changed")
    return false
  seed_used = gun_seed_random cfg.seed
  changed_lines, changed_tags, produced_lines, skipped = 0, 0, 0, 0
  period = math.max 1, tonumber(cfg.fbf_period) or 1
  recognized_fbf = cfg.selection_as_fbf_unit and #indices > 1 and selection_is_single_frame_fbf(subs, indices)
  if cfg.selection_as_fbf_unit and #indices > 1
    group_caches = {}
    for n, index in ipairs indices
      line = subs[index]
      group = math.floor((n - 1) / period) + 1
      group_caches[group] or= {}
      next_line, count, changed = gun_process_line line, selected, cfg, group, group_caches[group]
      if changed
        subs[index] = next_line
        changed_lines += 1
      changed_tags += count
      aegisub.progress.set math.floor 100 * n / math.max(1, #indices)
  else
    for index in *selected_desc indices
      line = subs[index]
      unless is_dialogue line
        skipped += 1
        continue
      lines, err, count = gun_fbf_lines_for_line line, selected, cfg, 1
      if err
        show_message "#{Core.L('line')} #{index}: #{err}"
        return false
      if lines and replace_line_with_many subs, index, lines
        produced_lines += #lines
        changed_lines += 1
        changed_tags += count or 0
      aegisub.progress.set math.floor 100 * (#indices - skipped) / math.max(1, #indices)
  if changed_lines == 0 and produced_lines == 0
    show_message Core.L("gun_no_change")
    return false
  aegisub.set_undo_point "Obake - Gunfight of Tags"
  if cfg.show_report
    detail = "Gunfight of Tags changed #{changed_tags} value(s) in #{changed_lines} source line(s).\nSeed: #{seed_used}"
    detail ..= "\nRecognized one-frame FBF selection." if recognized_fbf
    detail ..= "\nProduced FBF lines: #{produced_lines}" if produced_lines > 0
    detail ..= "\nSkipped non-dialogue lines: #{skipped}" if skipped > 0
    show_message detail
  true

apply_zigzag_lines = (subs, sel, cfg) ->
  cfg or= ZIGZAG_DEFAULTS
  indices = gun_dialogue_indices subs, sel
  unless #indices >= 2
    show_message Core.L("zigzag_need_lines")
    return false
  templates = {}
  start_ms, end_ms = nil, nil
  for index in *indices
    line = clone_line subs[index]
    templates[#templates + 1] = line
    start_ms = line.start_time if not start_ms or line.start_time < start_ms
    end_ms = line.end_time if not end_ms or line.end_time > end_ms
  slices, err = frame_slices start_ms, end_ms, cfg.period_frames
  if err
    show_message err
    return false
  unless slices and #slices > 0
    show_message Core.L("no_fbf_slices")
    return false
  out = {}
  for n, slice in ipairs slices
    source = templates[((n - 1) % #templates) + 1]
    line = clone_line source
    line.start_time = slice.start_time
    line.end_time = slice.end_time
    line.comment = false
    out[#out + 1] = line
  insert_at = indices[1]
  for index in *selected_desc indices
    subs.delete index
  for n, line in ipairs out
    subs.insert insert_at + n - 1, line
  aegisub.set_undo_point "Obake - ZigZag lines"
  show_message "#{Core.L('zigzag_created')} #{#out} line(s)."
  true

stamp_marker = (line, prefix, seq) ->
  line.effect = line.effect or ""
  cleaned = trim tostring(line.effect)\gsub("%[" .. prefix .. "%-%d+%]", "")\gsub("%s+", " ")
  marker = string.format "[%s-%03d]", prefix, tonumber(seq) or 1
  line.effect = if cleaned != "" then marker .. " " .. cleaned else marker

marker_counter = 0
next_marker = ->
  marker_counter += 1
  marker_counter = 1 if marker_counter > 9999
  marker_counter

reset_markers = ->
  marker_counter = 0

line_layer = (line) ->
  tonumber(line and line.layer) or 0

ensure_tag_block = (line) ->
  line.text = "{}" .. tostring(line.text or "") unless tostring(line.text or "")\sub(1, 1) == "{"
  line

strip_bord = (text) ->
  remove_ass_tags text, "outline"

strip_blur = (text) ->
  remove_ass_tags text, "blur"

strip_color3 = (text) ->
  remove_ass_tags text, "color3"

make_border_layers = (line, cfg) ->
  base_layer = line_layer line
  layers = {
    {use: cfg.use_bord1, size: tonumber(cfg.bord1) or 0, color: cfg.color1}
    {use: cfg.use_bord2, size: tonumber(cfg.bord2) or 0, color: cfg.color2}
    {use: cfg.use_bord3, size: tonumber(cfg.bord3) or 0, color: cfg.color3}
    {use: cfg.use_bord4, size: tonumber(cfg.bord4) or 0, color: cfg.color4}
  }
  used = [layer for layer in *layers when layer.use]
  return nil if #used == 0
  mid = next_marker!
  out = {}
  fill = clone_line line
  ensure_tag_block fill
  fill.text = strip_bord fill.text
  fill.text = inject_first fill.text, tag_text("outline", 0)
  fill.layer = base_layer + #used + 1
  stamp_marker fill, "CAL", mid
  out[#out + 1] = fill
  accumulated = 0
  depth = #used
  for layer in *used
    accumulated += tonumber(layer.size) or 0
    border = clone_line line
    ensure_tag_block border
    border.text = strip_bord border.text
    border.text = inject_first border.text, tag_text("outline", accumulated)
    border.text = strip_color3 border.text
    border.text = inject_first border.text, tag_text("alpha1", 255) .. color_tag_text("color3", layer.color)
    border.layer = base_layer + depth
    depth -= 1
    stamp_marker border, "CAL", mid
    out[#out + 1] = border
  table.sort out, (a, b) -> line_layer(a) < line_layer(b)
  out

apply_border_layers = (subs, sel, cfg) ->
  cfg or= DEFAULTS
  reset_markers!
  changed = 0
  for index in *selected_desc sel
    line = subs[index]
    if is_dialogue line
      layers = make_border_layers line, cfg
      if layers and replace_line_with_many subs, index, layers
        changed += 1
  if changed > 0
    aegisub.set_undo_point "Obake - Border layers"
    return true
  show_message Core.L("no_border_layers")
  false

preset_layers = (line, preset) ->
  mid = next_marker!
  base = line_layer line
  switch preset
    when "Decompose (Fill + Border)"
      border = clone_line line
      fill = clone_line line
      ensure_tag_block border
      ensure_tag_block fill
      border.text = inject_first border.text, tag_text("alpha1", 255)
      border.layer = base
      stamp_marker border, "CAL", mid
      fill.text = strip_bord fill.text
      fill.text = inject_first fill.text, tag_text("outline", 0)
      fill.layer = base + 1
      stamp_marker fill, "CAL", mid
      {border, fill}
    when "Blur + Glow"
      glow = clone_line line
      fill = clone_line line
      ensure_tag_block glow
      ensure_tag_block fill
      glow.text = strip_blur glow.text
      glow.text = inject_first glow.text, tag_text("blur", 3) .. tag_text("alpha", 128)
      glow.layer = base
      stamp_marker glow, "CAL", mid
      fill.text = inject_first fill.text, tag_text("blur", 0.6) unless fill.text\match "\\blur"
      fill.layer = base + 1
      stamp_marker fill, "CAL", mid
      {glow, fill}
    when "Shadtrick (Shadow Layer)"
      shad = clone_line line
      ensure_tag_block shad
      shad.text = remove_alpha_tags shad.text
      shad.text = remove_ass_tags shad.text, {"shadow", "shadow_x", "shadow_y"}
      shad.text = inject_first shad.text, tag_text("alpha", 255) .. tag_text("alpha4", 0) .. tag_text("shadow_x", 0.001)
      shad.layer = base
      stamp_marker shad, "CAL", mid
      {shad}
    when "Double Border Blur"
      top = clone_line line
      middle = clone_line line
      bottom = clone_line line
      ensure_tag_block top
      ensure_tag_block middle
      ensure_tag_block bottom
      bord = tonumber(tostring(line.text or "")\match("\\bord([%d%.]+)")) or 2
      top.text = strip_bord top.text
      top.text = inject_first top.text, tag_text("outline", 0)
      top.layer = base + 2
      stamp_marker top, "CAL", mid
      middle.text = inject_first middle.text, tag_text("alpha1", 255)
      middle.text = inject_first middle.text, tag_text("blur", 0.4) unless middle.text\match "\\blur"
      middle.layer = base + 1
      stamp_marker middle, "CAL", mid
      bottom.text = strip_bord bottom.text
      bottom.text = inject_first bottom.text, tag_text("outline", bord * 2) .. tag_text("alpha1", 255) .. tag_text("blur", 2)
      bottom.layer = base
      stamp_marker bottom, "CAL", mid
      {bottom, middle, top}
    when "Clean Layers (Flatten)"
      clean = clone_line line
      clean.text = remove_alpha_tags clean.text
      clean.layer = 0
      {clean}
    else
      nil

apply_color_preset = (subs, sel, cfg) ->
  cfg or= DEFAULTS
  reset_markers!
  changed = 0
  for index in *selected_desc sel
    line = subs[index]
    if is_dialogue line
      layers = preset_layers line, cfg.cal_preset
      if layers and replace_line_with_many subs, index, layers
        changed += 1
  if changed > 0
    aegisub.set_undo_point "Obake - Color preset"
    return true
  show_message Core.L("no_color_preset")
  false

karaoke_cue = (text) ->
  elapsed, seen = 0, 0
  text = tostring text or ""
  for s, block, e in text\gmatch("()(%b{})()")
    for value in block\gmatch "\\[kK][fo]?([%d%.]+)"
      seen += 1
      if seen == 2
        return elapsed, strip_karaoke_tags(text\sub(1, s - 1)), strip_karaoke_tags(text\sub(s))
      elapsed += math.floor((tonumber(value) or 0) * 10 + 0.5)
  nil

fx_offset = (line) ->
  offset = karaoke_cue line.text
  dur = line_duration line
  if offset and offset > 0 and offset < dur then offset, true else 0, false

fx_text = (line, uses_karaoke) ->
  if uses_karaoke then strip_karaoke_tags(line.text) else line.text

inject_fx = (line, payload, strip) ->
  line.text = strip_transforms line.text if strip
  line.text = inject_first line.text, payload
  line

fx_from_ini_fin = (ini, fin) ->
  (line, cfg) ->
    dur = line_duration line
    return nil unless dur > 0
    offset, uses_karaoke = fx_offset line
    line.text = fx_text line, uses_karaoke
    accel = if cfg.use_accel then cfg.accel else nil
    payload = ini .. transform_tag(offset, dur, fin, accel)
    inject_fx line, payload, cfg.strip_existing

simple_fx = {
  ["Blur In"]: fx_from_ini_fin "\\blur8", "\\blur0"
  ["Blur Out"]: fx_from_ini_fin "\\blur0", "\\blur8"
  ["Fade In"]: fx_from_ini_fin "\\alpha&HFF&", "\\alpha&H00&"
  ["Fade Out"]: fx_from_ini_fin "\\alpha&H00&", "\\alpha&HFF&"
  ["Scale Up"]: fx_from_ini_fin "\\fscx100\\fscy100", "\\fscx115\\fscy115"
  ["Scale Down"]: fx_from_ini_fin "\\fscx115\\fscy115", "\\fscx100\\fscy100"
  ["Pop In"]: fx_from_ini_fin "\\fscx40\\fscy40\\alpha&HFF&", "\\fscx100\\fscy100\\alpha&H00&"
  ["Pop Out"]: fx_from_ini_fin "\\fscx100\\fscy100\\alpha&H00&", "\\fscx40\\fscy40\\alpha&HFF&"
  ["Border Pulse"]: fx_from_ini_fin "\\bord2", "\\bord6"
  ["Glow Pulse"]: fx_from_ini_fin "\\blur1\\bord2", "\\blur8\\bord4"
}

apply_color_flash = (line, cfg) ->
  dur = line_duration line
  return nil unless dur > 0
  offset, uses_karaoke = fx_offset line
  line.text = fx_text line, uses_karaoke
  c1 = color_norm cfg.fx_color or "&HFFFFFF&"
  c2 = color_norm cfg.fx_color2 or "&H0000FF&"
  mid = offset + math.floor((dur - offset) * 0.3)
  payload = "\\c" .. c1 .. transform_tag(offset, mid, "\\c" .. c2) .. transform_tag(mid, dur, "\\c" .. c1)
  inject_fx line, payload, cfg.strip_existing

apply_color_pulse_fx = (line, cfg) ->
  dur = line_duration line
  return nil unless dur > 0
  offset, uses_karaoke = fx_offset line
  line.text = fx_text line, uses_karaoke
  c1 = color_norm cfg.fx_color or "&HFFFFFF&"
  c2 = color_norm cfg.fx_color2 or "&H00CCFF&"
  step = math.max 80, math.floor(tonumber(cfg.fx_step_ms) or 250)
  payload = "\\c" .. c1
  t, to_fin = offset, true
  while t < dur
    t2 = math.min t + step, dur
    payload ..= transform_tag t, t2, "\\c" .. (if to_fin then c2 else c1)
    t = t2
    to_fin = not to_fin
  inject_fx line, payload, cfg.strip_existing

apply_to_color_frame = (line, cfg) ->
  dur = line_duration line
  return nil unless dur > 0
  offset, uses_karaoke = fx_offset line
  unless uses_karaoke
    fms, err = current_frame_ms!
    return nil, err unless fms
    offset = clamp fms - line.start_time, 0, dur
  line.text = fx_text line, uses_karaoke
  color = color_norm cfg.fx_color or "&HFFCC00&"
  inject_fx line, transform_tag(offset, dur, "\\c" .. color .. "\\3c" .. color .. "\\4c" .. color), cfg.strip_existing

apply_to_style_frame = (line, cfg, styles) ->
  dur = line_duration line
  return nil unless dur > 0
  offset, uses_karaoke = fx_offset line
  unless uses_karaoke
    fms, err = current_frame_ms!
    return nil, err unless fms
    return nil, "Frame is outside the line." if fms < line.start_time or fms > line.end_time
    offset = fms - line.start_time
  style = styles[line.style] or styles.Default
  return nil, "Style not found." unless style
  line.text = fx_text line, uses_karaoke
  color = color_norm cfg.fx_color or "&HFFCC00&"
  sc1 = color_from_style style.color1
  sc3 = color_from_style style.color3
  sc4 = color_from_style style.color4
  init = "\\c" .. color .. "\\3c" .. color .. "\\4c" .. color
  inject_fx line, init .. transform_tag(0, offset, "\\c" .. sc1 .. "\\3c" .. sc3 .. "\\4c" .. sc4), cfg.strip_existing

apply_shake = (line, cfg, axis) ->
  dur = line_duration line
  return nil unless dur > 0
  offset, uses_karaoke = fx_offset line
  line.text = fx_text line, uses_karaoke
  px, py = line.text\match "\\pos%(%s*([%-%d%.]+)%s*,%s*([%-%d%.]+)%s*%)"
  px, py = tonumber(px) or 960, tonumber(py) or 540
  line.text = remove_simple_tag line.text, "org"
  distance = 1500
  org_x, org_y = math.floor(px), math.floor(py)
  org_x -= distance if axis == "V" or axis == "XY"
  org_y -= distance if axis == "H" or axis == "XY"
  step = math.max 20, math.floor(tonumber(cfg.fx_step_ms) or 50)
  amount = tonumber(cfg.fx_amount) or 0.12
  payload = string.format "\\org(%d,%d)", org_x, org_y
  t, dir = offset, 1
  while t < dur
    t2 = math.min t + step, dur
    payload ..= transform_tag t, t2, string.format("\\frz%.3f", amount * dir)
    t = t2
    dir = -dir
  inject_fx line, payload, cfg.strip_existing

apply_wobble = (line, cfg) ->
  dur = line_duration line
  return nil unless dur > 0
  offset, uses_karaoke = fx_offset line
  line.text = fx_text line, uses_karaoke
  step = math.max 40, math.floor(tonumber(cfg.fx_step_ms) or 120)
  amount = tonumber(cfg.fx_amount) or 4.0
  payload, t, dir = "", offset, 1
  while t < dur
    t2 = math.min t + step, dur
    payload ..= transform_tag t, t2, string.format("\\frz%.2f", amount * dir)
    t = t2
    dir = -dir
  inject_fx line, payload, cfg.strip_existing

apply_glitch = (line, cfg) ->
  dur = line_duration line
  return nil unless dur > 0
  offset, uses_karaoke = fx_offset line
  line.text = fx_text line, uses_karaoke
  step = math.max 30, math.floor(tonumber(cfg.fx_step_ms) or 60)
  amount = tonumber(cfg.fx_amount) or 6.0
  payload, t = "", offset
  while t < dur
    t2 = math.min t + step, dur
    fax = (math.random! - 0.5) * amount * 0.05
    fsp = math.floor((math.random! - 0.5) * amount)
    payload ..= transform_tag t, t2, string.format("\\fax%.3f\\fsp%d", fax, fsp)
    t = t2
  inject_fx line, payload, cfg.strip_existing

dramatic_pulse_lines = (line, cfg) ->
  dur = line_duration line
  return nil unless dur > 0
  offset, uses_karaoke = fx_offset line
  base = fx_text line, uses_karaoke
  pulse_end = math.min dur, offset + math.max(120, math.floor(tonumber(cfg.fx_step_ms) or 220))
  settle_end = math.min dur, offset + math.max(180, math.floor((tonumber(cfg.fx_step_ms) or 220) * 1.8))
  color = color_norm cfg.fx_color or "&HFFFFFF&"
  glow = clone_line line
  top = clone_line line
  glow.layer = line_layer line
  top.layer = line_layer(line) + 1
  glow.text = base
  top.text = base
  glow_tags = "\\c" .. color .. "\\3c" .. color .. "\\blur2\\bord3\\alpha&H20&" .. transform_tag(offset, pulse_end, "\\fscx170\\fscy170\\blur9\\bord8\\alpha&HFF&")
  top_tags = "\\alpha&H00&" .. transform_tag(offset, pulse_end, "\\fscx122\\fscy122") .. transform_tag(pulse_end, settle_end, "\\fscx100\\fscy100")
  {inject_fx(glow, glow_tags, cfg.strip_existing), inject_fx(top, top_tags, cfg.strip_existing)}

split_line_lines = (line, mode) ->
  k_offset, k_before, k_after = karaoke_cue line.text
  fms = nil
  unless k_offset
    fms = current_frame_ms!
    return nil unless fms and fms > line.start_time and fms < line.end_time
  split_time = if k_offset then line.start_time + k_offset else fms
  head = first_block line.text
  body = line.text\sub(#head + 1)
  before, after = body\match "^(.-)%|(.*)$"
  if k_offset
    head, before, after = "", k_before, k_after
  return nil unless before and after
  l1 = clone_line line
  l2 = clone_line line
  if mode == "Split Line"
    l1.end_time = split_time
    l1.text = head .. before .. "{\\alpha&HFF&}" .. after
    l2.start_time = split_time
    l2.text = head .. before .. after
  else
    l1.text = head .. before .. "{\\alpha&HFF&}" .. after
    l2.layer = line_layer(line) + 1
    l2.start_time = split_time
    fad = "\\fad(250,0)\\alpha&HFF&"
    if head != ""
      l2.text = head\gsub("^{", "{" .. fad, 1) .. before .. "{\\alpha&H00&}" .. after
    else
      l2.text = "{" .. fad .. "}" .. before .. "{\\alpha&H00&}" .. after
  {l1, l2}

split_title_lines = (line) ->
  head = first_block line.text
  body = line.text\sub(#head + 1)
  l1 = clone_line line
  l2 = clone_line line
  l1.layer = line_layer line
  l2.layer = line_layer(line) + 1
  if head != ""
    l1.text = head\gsub("^{", "{\\1a&HFF&", 1) .. body
    l2.text = head\gsub("^{", "{\\bord0", 1) .. body
  else
    l1.text = "{\\1a&HFF&}" .. body
    l2.text = "{\\bord0}" .. body
  {l1, l2}

apply_fx = (subs, sel, cfg) ->
  cfg or= DEFAULTS
  preset = cfg.fx_preset
  unless preset and preset != ""
    show_message Core.L("no_fx_preset")
    return false
  math.randomseed os.time!
  styles = style_map subs
  changed, errors = 0, {}
  if preset == "Dramatic Pulse" or preset == "Split Line" or preset == "Split Line Fad" or preset == "Split Title"
    for index in *selected_desc sel
      line = subs[index]
      continue unless is_dialogue line
      lines = switch preset
        when "Dramatic Pulse" then dramatic_pulse_lines line, cfg
        when "Split Line" then split_line_lines line, "Split Line"
        when "Split Line Fad" then split_line_lines line, "Split Line Fad"
        when "Split Title" then split_title_lines line
      if lines and replace_line_with_many subs, index, lines
        changed += 1
    if changed > 0
      aegisub.set_undo_point "Obake - Animation FX " .. preset
      return true
    show_message Core.L("no_lines_changed")
    return false
  for i in *(sel or {})
    line = clone_line subs[i]
    continue unless is_dialogue line
    out, err = nil, nil
    if simple_fx[preset]
      out, err = simple_fx[preset] line, cfg
    else
      switch preset
        when "Color Flash" then out, err = apply_color_flash line, cfg
        when "Color Pulse" then out, err = apply_color_pulse_fx line, cfg
        when "To Color (frame)" then out, err = apply_to_color_frame line, cfg
        when "To Style (frame)" then out, err = apply_to_style_frame line, cfg, styles
        when "Shake V" then out, err = apply_shake line, cfg, "V"
        when "Shake H" then out, err = apply_shake line, cfg, "H"
        when "Shake XY" then out, err = apply_shake line, cfg, "XY"
        when "Wobble (frz)" then out, err = apply_wobble line, cfg
        when "Glitch" then out, err = apply_glitch line, cfg
        when "Flashback (fad)"
          line.text = inject_first line.text, "\\fad(200,200)"
          out = line
    if out
      subs[i] = out
      changed += 1
    elseif err
      errors[#errors + 1] = "#{Core.L('line')} #{i}: #{err}"
  if changed > 0
    aegisub.set_undo_point "Obake - Animation FX " .. preset
    return true
  show_message if #errors > 0 then table.concat(errors, "\n") else Core.L("no_lines_changed")
  false

apply_retime = (subs, sel, cfg) ->
  cfg or= {}
  changed = 0
  report = {}
  for i in *(sel or {})
    line = clone_line subs[i]
    continue unless is_dialogue line
    target = tonumber(cfg.retime_target) or 0
    target = line_duration line if target <= 0
    continue if target <= 0
    source = tonumber(cfg.retime_source) or 0
    source = max_transform_end(line.text) if source <= 0
    if source > 0 and target >= 0
      new_text, tags_changed = retime_transform_text line.text, source, target
      if tags_changed > 0 and new_text != line.text
        line.text = new_text
        subs[i] = line
        changed += 1
        report[#report + 1] = "#{Core.L('line')} #{i}: #{format_ms(source)} -> #{format_ms(target)} ms, #{tags_changed} #{Core.L('transform_s')}"
  if changed > 0
    aegisub.set_undo_point "Obake - Retime transforms"
    show_message table.concat(report, "\n") if cfg.retime_info
    return true
  show_message Core.L("no_t_ret")
  false

Core.dispatch = (subs, sel, active, operation, opts) ->
  switch operation
    when "Apply chain" then apply_chain subs, sel, opts
    when "Animation FX" then apply_fx subs, sel, opts
    when "Color preset" then apply_color_preset subs, sel, opts
    when "Border layers" then apply_border_layers subs, sel, opts
    when "Retime transforms" then apply_retime subs, sel, opts
    when "In-Out tags" then apply_in_out_tags subs, sel, opts
    when "Gunfight of Tags" then apply_gunfight_of_tags subs, sel, opts
    when "ZigZag lines" then apply_zigzag_lines subs, sel, opts
    else false

Core.run_operation = (subs, sel, active, operation) ->
  opts = Core.show_action_options operation, subs, sel, active
  return unless opts
  opts.operation = operation
  ok = Core.dispatch subs, sel, active, operation, opts
  aegisub.cancel! unless ok

Core.main = (subs, sel, active) ->
  operation = Core.action_picker!
  Core.run_operation subs, sel, active, operation

Core.validate = (subs, sel) ->
  sel and #sel > 0

Core.validate_any = ->
  true

Core.validate_in_out = (subs, sel) ->
  sel and #sel == 2

Core.validate_zigzag = (subs, sel) ->
  sel and #sel >= 2

Core.validate_action = (operation) ->
  if operation == "In-Out tags"
    Core.validate_in_out
  elseif operation == "ZigZag lines"
    Core.validate_zigzag
  else
    Core.validate

Core.action_macro = (operation) ->
  (subs, sel, active) ->
    Core.run_operation subs, sel, active, operation

Core.hotkey_menu_path = (operation) ->
  HOTKEY_MENU_ROOT .. "/" .. HOTKEY_MENU_SCRIPT .. "/" .. operation

Core.help_macro = ->
  Core.action_help_picker!

register_macro = (name, description, process, validate) ->
  depctrl\registerMacro name, description, process, validate, nil, false

register_macro "Obake", script_description, Core.main, Core.validate
register_macro "Obake/Help", "Show the Obake action help.", Core.help_macro, Core.validate_any
for operation in *OPERATIONS
  register_macro Core.hotkey_menu_path(operation), Core.action_help(operation), Core.action_macro(operation), Core.validate_action(operation)
