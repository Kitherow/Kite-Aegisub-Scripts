export script_name = "Cliptomaniac"
export script_description = "Clip toolbox for measuring, transforming, reshaping, fitting, and projecting ASS clips."
export script_author = "Kiterow"
export script_namespace = "kite.Cliptomaniac"
export script_version = "0.2.30"


local ZF, ASS, ArchPerspective, LineCollection, Functional, Util, AMLine, depctrl, logger
Core = {}
PerspectiveTools = {}

DependencyControl = require "l0.DependencyControl"
depctrl = DependencyControl{
  feed: "https://raw.githubusercontent.com/Kitherow/Kite-Aegisub-Scripts/main/DependencyControl.json",
    {
      {"ZF.main", version: "2.3.0", url: "https://github.com/TypesettingTools/zeref-Aegisub-Scripts",
        feed: "https://raw.githubusercontent.com/TypesettingTools/zeref-Aegisub-Scripts/main/DependencyControl.json"}
      {"l0.ASSFoundation", version: "0.5.0", url: "https://github.com/TypesettingTools/ASSFoundation",
        feed: "https://raw.githubusercontent.com/TypesettingTools/ASSFoundation/master/DependencyControl.json"}
      {"arch.Perspective", version: "1.2.1", url: "https://github.com/TypesettingTools/arch1t3cht-Aegisub-Scripts",
        feed: "https://raw.githubusercontent.com/TypesettingTools/arch1t3cht-Aegisub-Scripts/main/DependencyControl.json"}
      {"kite.UI", version: "1.0.0", url: "https://github.com/Kitherow/Kite-Aegisub-Scripts",
        feed: "https://raw.githubusercontent.com/Kitherow/Kite-Aegisub-Scripts/main/DependencyControl.json"}
      {"a-mo.LineCollection", version: "1.3.0", url: "https://github.com/TypesettingTools/Aegisub-Motion",
        feed: "https://raw.githubusercontent.com/TypesettingTools/Aegisub-Motion/DepCtrl/DependencyControl.json"}
      {"l0.Functional", version: "0.6.0", url: "https://github.com/TypesettingTools/Functional",
        feed: "https://raw.githubusercontent.com/TypesettingTools/Functional/master/DependencyControl.json"}
      {"arch.Util", version: "0.1.0", url: "https://github.com/TypesettingTools/arch1t3cht-Aegisub-Scripts",
        feed: "https://raw.githubusercontent.com/TypesettingTools/arch1t3cht-Aegisub-Scripts/main/DependencyControl.json"}
      {"a-mo.Line", version: "1.5.3", url: "https://github.com/TypesettingTools/Aegisub-Motion",
        feed: "https://raw.githubusercontent.com/TypesettingTools/Aegisub-Motion/DepCtrl/DependencyControl.json"}
    }
}
ZF, ASS, ArchPerspective, Core.UI, LineCollection, Functional, Util, AMLine = depctrl\requireModules!
logger = depctrl\getLogger!

ConfigHandler = (interface, file_name, _has_sections, version) ->
  Core.UI.dialogHandler interface, script_namespace, version, {
    {path: "?user/" .. file_name, format: "json_sections"}
  }

Core.safe_require = (name) ->
  ok, mod = pcall require, name
  if ok then mod else nil

unicode = Core.safe_require "aegisub.unicode"
FunctionalString = Functional and Functional.string or nil
FunctionalMath = Functional and Functional.math or nil

CONFIG_FILE = "kite-cliptomaniac.json"
HOTKEY_MENU_ROOT = ": Kite Hotkeys :"
HOTKEY_MENU_SCRIPT = "Cliptomaniac"
DEFAULT_LANGUAGE = "en"
current_language = DEFAULT_LANGUAGE
language_config_handler = nil

OPERATIONS = {
  "Autofit clip to text"
  "Create clip around text"
  "Text to clip"
  "Expand clip margin"
  "Copy clip/iclip"
  "Shape to clip"
  "Clip to shape"
  "Toggle clip/iclip"
  "Rect clip to vector"
  "Vector clip to rect"
  "Clip boolean with text/shape"
  "Extract clip as mask line"
  "Position at clip midpoint"
  "Align to clip"
  "Clip to reposition"
  "Clip to move"
  "Clip to FRZ"
  "Clip to FAX"
  "Clip to FAY"
  "Measure clip"
  "Measure & transform clip"
  "Adjust by clip scale"
  "Rescale by rectangle clip"
  "Clip to perspective"
  "Perspective to clip"
  "Create strip clips"
  "Animated clip to FBF"
  "Calibrate clip X"
  "Calibrate clip Y"
  "Rectangle from diagonal"
  "Circle from 2 points"
  "New clip shape"
  "Add clip points"
  "Remove clip points"
  "FRZ stops for LerpByChar"
  "Clip diagnostics"
}

OPERATION_LABELS = {
  en: {
    ["Autofit clip to text"]: "autofit clip to text"
    ["Create clip around text"]: "create clip around text"
    ["Text to clip"]: "text to clip"
    ["Expand clip margin"]: "expand/shrink clip margin"
    ["Copy clip/iclip"]: "copy clip/iclip"
    ["Shape to clip"]: "shape to clip"
    ["Clip to shape"]: "clip to shape"
    ["Toggle clip/iclip"]: "toggle clip/iclip"
    ["Rect clip to vector"]: "rect clip to vector"
    ["Vector clip to rect"]: "vector clip to rect"
    ["Clip boolean with text/shape"]: "clip boolean with text/shape"
    ["Extract clip as mask line"]: "extract clip as mask line"
    ["Position at clip midpoint"]: "pos to clip center"
    ["Align to clip"]: "align pos to clip path"
    ["Clip to reposition"]: "clip to reposition"
    ["Clip to move"]: "clip to move"
    ["Clip to FRZ"]: "clip to frz"
    ["Clip to FAX"]: "clip to fax"
    ["Clip to FAY"]: "clip to fay"
    ["Measure clip"]: "measure clip guide"
    ["Measure & transform clip"]: "animate scale from clip guide"
    ["Adjust by clip scale"]: "adjust tags by clip scale"
    ["Rescale by rectangle clip"]: "rescale tags by rectangular clip"
    ["Clip to perspective"]: "clip to perspective"
    ["Perspective to clip"]: "perspective to clip"
    ["Create strip clips"]: "create strip clips"
    ["Animated clip to FBF"]: "animated clip to FBF"
    ["Calibrate clip X"]: "calibrate clip X"
    ["Calibrate clip Y"]: "calibrate clip Y"
    ["Rectangle from diagonal"]: "rectangle from diagonal"
    ["Circle from 2 points"]: "circle from diameter"
    ["New clip shape"]: "new clip shape"
    ["Add clip points"]: "add clip points"
    ["Remove clip points"]: "remove clip points"
    ["FRZ stops for LerpByChar"]: "frz stops along path"
    ["Clip diagnostics"]: "clip diagnostics"
  }
  es: {
    ["Autofit clip to text"]: "ajustar clip al texto"
    ["Create clip around text"]: "crear clip alrededor del texto"
    ["Text to clip"]: "texto a clip"
    ["Expand clip margin"]: "expandir/reducir margen de clip"
    ["Copy clip/iclip"]: "copiar clip/iclip"
    ["Shape to clip"]: "dibujo a clip"
    ["Clip to shape"]: "clip a dibujo"
    ["Toggle clip/iclip"]: "toggle clip/iclip"
    ["Rect clip to vector"]: "clip rectangular a vector"
    ["Vector clip to rect"]: "clip vectorial a rectangular"
    ["Clip boolean with text/shape"]: "booleano de clip con texto/dibujo"
    ["Extract clip as mask line"]: "extraer clip como máscara"
    ["Position at clip midpoint"]: "pos al centro del clip"
    ["Align to clip"]: "alinear pos a la ruta del clip"
    ["Clip to reposition"]: "clip para mover línea"
    ["Clip to move"]: "clip a move"
    ["Clip to FRZ"]: "clip a frz"
    ["Clip to FAX"]: "clip a fax"
    ["Clip to FAY"]: "clip a fay"
    ["Measure clip"]: "medir guía de clip"
    ["Measure & transform clip"]: "animar escala desde guía de clip"
    ["Adjust by clip scale"]: "escalar tags desde guía de clip"
    ["Rescale by rectangle clip"]: "ajustar tags a clip rectangular"
    ["Clip to perspective"]: "clip a perspectiva"
    ["Perspective to clip"]: "perspectiva a clip"
    ["Create strip clips"]: "crear franjas de clip"
    ["Animated clip to FBF"]: "clip animado a FBF"
    ["Calibrate clip X"]: "enderezar guía clip en X"
    ["Calibrate clip Y"]: "enderezar guía clip en Y"
    ["Rectangle from diagonal"]: "crear rectángulo desde diagonal"
    ["Circle from 2 points"]: "crear círculo desde diámetro"
    ["New clip shape"]: "continuar forma de clip"
    ["Add clip points"]: "anadir puntos de clip"
    ["Remove clip points"]: "quitar puntos de clip"
    ["FRZ stops for LerpByChar"]: "crear marcas frz sobre ruta"
    ["Clip diagnostics"]: "diagnóstico de clip"
  }
}

AXES = {"x", "y", "both"}
ANGLE_MODES = {"none", "first angle", "transform angle"}
CURVE_SOURCES = {"Auto", "Two guide strokes", "Path tangents"}
AUTOFIT_MODES = {
  "Whole text"
  "Auto by position"
  "Left/top half"
  "Right/bottom half"
  "Left/top third"
  "Center third"
  "Right/bottom third"
  "Custom section"
}
RESCALE_RECT_MODES = {"Fit (uniform)", "Fill (uniform)", "Stretch (per-axis)"}
STRIP_MODES = {"Horizontal", "Vertical"}
CLIP_TYPES = {"Auto", "clip", "iclip"}
FBF_SOURCES = {"Clip only", "Full line"}
BOOLEAN_MODES = {"Keep overlap", "Cut text from clip"}
POINT_INSERT_MODES = {"By distance", "By count"}
PERSPECTIVE_DATA = {
  maps: {
    {"ABCD (exact copy)", {1, 2, 3, 4}}
    {"BADC (h-mirror)", {2, 1, 4, 3}}
    {"DCBA (v-mirror)", {4, 3, 2, 1}}
    {"CDAB (rot 180)", {3, 4, 1, 2}}
    {"BCDA (rot 90 CW)", {2, 3, 4, 1}}
    {"DABC (rot 90 CCW)", {4, 1, 2, 3}}
    {"ABDC (swap CD)", {1, 2, 4, 3}}
    {"BACD (swap AB)", {2, 1, 3, 4}}
  }
  org_modes: {"1 keep dst org", "2 quad center", "3 minimize fax"}
}

PERSPECTIVE_MAP_ALIASES = {
  ["ABCD (as drawn)"]: "ABCD (exact copy)"
  ["BADC (flip left/right)"]: "BADC (h-mirror)"
  ["DCBA (flip top/bottom)"]: "DCBA (v-mirror)"
  ["CDAB (rotate 180)"]: "CDAB (rot 180)"
  ["BCDA (rotate 90 clockwise)"]: "BCDA (rot 90 CW)"
  ["DABC (rotate 90 counter-clockwise)"]: "DABC (rot 90 CCW)"
  ["ABDC (swap bottom corners)"]: "ABDC (swap CD)"
  ["BACD (swap top corners)"]: "BACD (swap AB)"
  ["AB source + CD target"]: "ABCD (exact copy)"
  ["CD source + AB target"]: "ABCD (exact copy)"
  ["AC source + BD target"]: "ABCD (exact copy)"
  ["BD source + AC target"]: "ABCD (exact copy)"
  ["AB src + CD dst"]: "ABCD (exact copy)"
  ["CD src + AB dst"]: "ABCD (exact copy)"
  ["AC src + BD dst"]: "ABCD (exact copy)"
  ["BD src + AC dst"]: "ABCD (exact copy)"
}

PERSPECTIVE_ORG_ALIASES = {
  ["1 keep current origin"]: "1 keep dst org"
  ["1 keep target org"]: "1 keep dst org"
  ["Keep target org"]: "1 keep dst org"
  ["Keep dst org"]: "1 keep dst org"
  ["Mantener org destino"]: "1 keep dst org"
  ["2 use clip center"]: "2 quad center"
  ["Quad center"]: "2 quad center"
  ["Centro del quad"]: "2 quad center"
  ["3 reduce slant"]: "3 minimize fax"
  ["Minimize fax"]: "3 minimize fax"
  ["Minimizar fax"]: "3 minimize fax"
}

UI_LANG = {
  en: {
    run: "Execute"
    help: "Help"
    cancel: "Cancel"
    close: "Cancel"
    apply: "Execute"
    language: "Español"
    action: "Action:"
    runs_now: "Runs now"
    opens_settings: "Opens settings"
    what_it_does: "What it does:"
    controls: "Controls:"
    no_extra_controls: "No extra controls. This action runs with the current selection."
    picker_refresh: "Change the dropdown and press Help to refresh this text."
    picker_run: "Execute starts the selected action."
    axis: "Axis:"
    angle_mode: "Angle mode:"
    show_report: "Show report"
    resize: "Resize:"
    width: "width"
    height: "height"
    font: "font"
    spacing: "spacing"
    outline: "outline"
    shadow: "shadow"
    blur: "blur"
    mode: "Mode:"
    scale: "Scale:"
    center: "Center"
    remove_guide_clip: "Remove guide clip"
    curve_source: "Curve source:"
    tangent_stops: "Tangent stops:"
    corner_order: "Corner order:"
    origin: "Origin:"
    section_axis: "Section axis:"
    margin: "Margin:"
    tolerance: "Tolerance:"
    sections: "Sections:"
    index: "Index:"
    bleed: "Bleed:"
    no_shrink: "No shrink"
    style_pad: "Style pad"
    replace_existing_clip: "Replace existing clip"
    clip_type: "Clip type:"
    close_paths: "Close paths"
    comment_source: "Comment source"
    point_mode: "Add by:"
    point_distance: "Distance:"
    point_count: "Points:"
    strip_mode: "Strip mode:"
    strip_size: "Strip size:"
    create_new_lines: "Create new lines"
    bake_source: "Bake source:"
    max_frames: "Max frames:"
    merge_identical: "Merge identical"
    boolean_mode: "Boolean mode:"
    select_one: "Select at least one dialogue line."
    line: "Line"
  }
  es: {
    run: "Execute"
    help: "Ayuda"
    cancel: "Cancel"
    close: "Cancel"
    apply: "Execute"
    language: "English"
    action: "Acción:"
    runs_now: "Directa"
    opens_settings: "Con opciones"
    what_it_does: "Qué hace:"
    controls: "Controles:"
    no_extra_controls: "Sin controles extra. Esta acción se ejecuta con la selección actual."
    picker_refresh: "Cambia el dropdown y pulsa Ayuda para refrescar este texto."
    picker_run: "Execute inicia la acción seleccionada."
    axis: "Eje:"
    angle_mode: "Ángulo:"
    show_report: "Mostrar reporte"
    resize: "Escalar:"
    width: "ancho"
    height: "alto"
    font: "fuente"
    spacing: "espacio"
    outline: "borde"
    shadow: "sombra"
    blur: "blur"
    mode: "Modo:"
    scale: "Escala:"
    center: "Centrar"
    remove_guide_clip: "Quitar clip guía"
    curve_source: "Fuente:"
    tangent_stops: "Marcas:"
    corner_order: "Esquinas:"
    origin: "Origen:"
    section_axis: "Eje:"
    margin: "Margen:"
    tolerance: "Tolerancia:"
    sections: "Partes:"
    index: "Índice:"
    bleed: "Solape:"
    no_shrink: "No reducir"
    style_pad: "Incluir estilo"
    replace_existing_clip: "Reemplazar clip"
    clip_type: "Tipo:"
    close_paths: "Cerrar rutas"
    comment_source: "Comentar original"
    point_mode: "Anadir por:"
    point_distance: "Distancia:"
    point_count: "Puntos:"
    strip_mode: "Franjas:"
    strip_size: "Tamaño:"
    create_new_lines: "Crear líneas"
    bake_source: "Hornear:"
    max_frames: "Frames max:"
    merge_identical: "Unir iguales"
    boolean_mode: "Booleano:"
    select_one: "Selecciona al menos una línea de diálogo."
    line: "Línea"
    ["both"]: "ambos"
    ["none"]: "ninguno"
    ["first angle"]: "primer ángulo"
    ["transform angle"]: "ángulo en transform"
    ["Auto"]: "Auto"
    ["Two guide strokes"]: "dos trazos guía"
    ["Path tangents"]: "Tangentes de ruta"
    ["Whole text"]: "Texto completo"
    ["Auto by position"]: "auto por posición"
    ["Left/top half"]: "Mitad izquierda/arriba"
    ["Right/bottom half"]: "Mitad derecha/abajo"
    ["Left/top third"]: "Tercio izquierdo/arriba"
    ["Center third"]: "Tercio central"
    ["Right/bottom third"]: "Tercio derecho/abajo"
    ["Custom section"]: "Parte personalizada"
    ["Fit (uniform)"]: "Encajar uniforme"
    ["Fill (uniform)"]: "Rellenar uniforme"
    ["Stretch (per-axis)"]: "Estirar por eje"
    ["Horizontal"]: "Horizontal"
    ["Vertical"]: "Vertical"
    ["Clip only"]: "solo clip"
    ["Full line"]: "línea completa"
    ["Keep overlap"]: "conservar intersección"
    ["Cut text from clip"]: "Recortar texto del clip"
    ["By distance"]: "por distancia"
    ["By count"]: "por cantidad"
    ["1 keep dst org"]: "1 conservar org destino"
    ["2 quad center"]: "2 centro del quad"
    ["3 minimize fax"]: "3 minimizar fax"
  }
}

DEFAULTS = {
  operation: OPERATIONS[1]
  axis: "x"
  angle_mode: "none"
  curve_source: "Auto"
  tangent_stops: 0
  margin: 8
  tolerance: 1
  strip: 24
  strip_mode: "Horizontal"
  rescale_rect_mode: "Fit (uniform)"
  recenter: true
  sections: 2
  section_index: 1
  bleed: 1
  no_shrink: true
  style_pad: true
  replace_clip: true
  remove_clip: true
  create_new_lines: true
  comment_source: false
  point_mode: "By distance"
  point_distance: 5
  point_count: 1
  clip_type: "Auto"
  close_paths: true
  merge_identical: true
  max_frames: 400
  fbf_source: "Clip only"
  boolean_mode: "Keep overlap"
  perspective_map: "ABCD (exact copy)"
  perspective_org_mode: "2 quad center"
  info: true
  adj_fscx: true
  adj_fscy: true
  adj_fs: false
  adj_fsp: false
  adj_bord: true
  adj_shad: true
  adj_blur: true
}

MAX_STRIP_OUTPUT_LINES = 1000

NUM_PATTERN = "[%+%-]?%.?%d+%.?%d*[eE]?[%+%-]?%d*"

Core.trim = (value) ->
  text = tostring(value or "")
  if FunctionalString and FunctionalString.trim
    ok, out = pcall FunctionalString.trim, text
    return tostring(out) if ok and out != nil
  text = text\gsub "^%s+", ""
  text = text\gsub "%s+$", ""
  text

Core.copy_line = (line) ->
  out = {}
  out[k] = v for k, v in pairs line
  out

Core.copy_style = (style) ->
  return nil unless type(style) == "table"
  out = {}
  out[k] = v for k, v in pairs style
  out

Core.ass_line = (line) ->
  return line if type(line) == "table" and line.__class
  src = if type(line) == "table" then line else {text: tostring(line or "")}
  copy = Core.copy_line src
  copy.class = copy.class or "dialogue"
  copy.comment = copy.comment or false
  copy.layer = tonumber(copy.layer) or 0
  copy.start_time = tonumber(copy.start_time) or 0
  copy.end_time = tonumber(copy.end_time) or 0
  copy.style = copy.style or "Default"
  copy.actor = copy.actor or ""
  copy.margin_l = tonumber(copy.margin_l) or 0
  copy.margin_r = tonumber(copy.margin_r) or 0
  copy.margin_t = tonumber(copy.margin_t or copy.margin_v) or 0
  copy.effect = copy.effect or ""
  copy.text = tostring(copy.text or "")
  if AMLine
    return AMLine copy, src.parentCollection or copy.parentCollection, {}
  copy

Core.parse_ass_line = (line) ->
  return line if ASS and type(line) == "table" and line.class == ASS.LineContents
  ASS\parse Core.ass_line(line)

Core.clamp = (value, low, high) ->
  math.max low, math.min high, value

Core.enum_option = (value, items, fallback) ->
  value = Core.choice_raw value
  for item in *(items or {})
    return item if value == item
  fallback

Core.L = (key) ->
  lang = UI_LANG[current_language] or UI_LANG.en
  lang[key] or UI_LANG.en[key] or tostring(key or "")

Core.choice_label = (value) ->
  raw = tostring(value or "")
  return raw if raw == ""
  lang = UI_LANG[current_language] or UI_LANG.en
  lang[raw] or raw

Core.choice_raw = (value) ->
  shown = tostring(value or "")
  return shown if current_language == DEFAULT_LANGUAGE
  for raw, label in pairs UI_LANG[current_language] or {}
    return raw if label == shown
  shown

Core.localized_items = (items) ->
  [Core.choice_label item for item in *(items or {})]

Core.valid_language = (value) ->
  if value == "es" then "es" else "en"

Core.normalize_perspective_map = (value) ->
  raw = tostring(Core.choice_raw(value) or "")
  aliased = PERSPECTIVE_MAP_ALIASES[raw] or raw
  for entry in *PERSPECTIVE_DATA.maps
    return entry[1] if aliased == entry[1]
  prefix = aliased\match "^([A-Z][A-Z][A-Z][A-Z])"
  if prefix
    for entry in *PERSPECTIVE_DATA.maps
      return entry[1] if entry[1]\match("^" .. prefix)
  DEFAULTS.perspective_map

Core.normalize_perspective_org = (value) ->
  raw = tostring(Core.choice_raw(value) or "")
  aliased = PERSPECTIVE_ORG_ALIASES[raw] or raw
  for item in *PERSPECTIVE_DATA.org_modes
    return item if aliased == item
  n = tonumber aliased\match "^(%d)"
  return PERSPECTIVE_DATA.org_modes[n] if n and PERSPECTIVE_DATA.org_modes[n]
  DEFAULTS.perspective_org_mode

Core.normalize_operation = (operation) ->
  return "Clip to perspective" if operation == "Clip to Persp"
  Core.enum_option operation, OPERATIONS, DEFAULTS.operation

Core.operation_label = (operation) ->
  labels = OPERATION_LABELS[current_language] or OPERATION_LABELS.en
  labels[operation] or OPERATION_LABELS.en[operation] or tostring(operation or "")

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

Core.format_num = (value, decimals = 3) ->
  n = tonumber value
  return "0" unless n and n == n and n != math.huge and n != -math.huge
  n = 0 if math.abs(n) < 0.0000005
  if math.abs(n - math.floor(n + 0.5)) < 0.0000005
    return tostring math.floor(n + 0.5)
  s = string.format "%." .. tostring(decimals) .. "f", n
  s = s\gsub "0+$", ""
  s = s\gsub "%.$", ""
  if s == "-0" or s == "" then "0" else s

Core.finite_number = (value) ->
  n = tonumber value
  if n and n == n and n != math.huge and n != -math.huge then n else nil

Core.round = (n, decimals = 0) ->
  n = tonumber(n) or 0
  if FunctionalMath and FunctionalMath.round
    ok, out = pcall FunctionalMath.round, n, decimals
    return out if ok and tonumber(out)
  p = 10 ^ (tonumber(decimals) or 0)
  math.floor(n * p + 0.5) / p

Core.warn = (message) ->
  if logger and logger.warn
    logger\warn message
  elseif aegisub and aegisub.debug and aegisub.debug.out
    aegisub.debug.out "[Cliptomaniac] #{message}\n"

MESSAGE_ES = {
  ["No perspective plane could be converted to clip."]: "No se pudo convertir ningun plano de perspectiva a clip."
  ["No clip points changed."]: "No cambiaron puntos de clip."
  ["No vector clip with two usable segments was found."]: "No se encontró un clip vectorial con dos segmentos usables."
  ["No line was transformed."]: "No se transformó ninguna línea."
  ["Select two clipped lines, or one vector clip with two m-l strokes."]: "Selecciona dos líneas con clip, o un clip vectorial con dos trazos m-l."
  ["First clip segment has zero length."]: "El primer segmento del clip mide cero."
  ["No numeric tags changed."]: "No cambió ningún tag numérico."
  ["Shape tools are not available."]: "Las herramientas de formas no están disponibles."
  ["Could not prepare text bounds."]: "No se pudo preparar el área del texto."
  ["Text bounds could not be measured."]: "No se pudo medir el área del texto."
  ["No rectangular clip was found."]: "No se encontró un clip rectangular."
  ["No line received FRZ stops."]: "Ninguna línea recibió marcas de rotación."
  ["No usable clip midpoint found."]: "No se encontró un centro de clip usable."
  ["No line position changed."]: "No cambió ninguna posición."
  ["No usable vector clip found."]: "No se encontró un clip vectorial usable."
  ["No position or clip geometry changed."]: "No cambió ninguna posición ni geometría del clip."
  ["No selected line had both \\pos and a usable clip segment."]: "Ninguna línea seleccionada tenía \\pos y un segmento de clip usable."
  ["No vector clip found for alignment."]: "No se encontró un clip vectorial para alinear."
  ["No selected line with \\pos could be aligned."]: "No se pudo alinear ninguna línea seleccionada con \\pos."
  ["No editable clip found."]: "No se encontró un clip editable."
  ["No source/target clip group found."]: "No se encontró grupo de clip fuente/destino."
  ["No clip was expanded."]: "No se expandió ningún clip."
  ["Text outline tools are not available."]: "Las herramientas de contorno de texto no están disponibles."
  ["No clip could be autofit."]: "No se pudo autoajustar ningún clip."
  ["This action needs the text measuring tools."]: "Esta acción necesita las herramientas de medición de texto."
  ["No text area could be clipped."]: "No se pudo crear clip de ningún área de texto."
  ["No text or drawing outline could be converted to a clip."]: "No se pudo convertir ningún texto o dibujo a clip."
  ["No drawing shape was converted to clip."]: "No se convirtió ningún dibujo a clip."
  ["No clip was converted to shape."]: "No se convirtió ningún clip a dibujo."
  ["No clip could be extracted as a mask line."]: "No se pudo extraer ningún clip como línea de máscara."
  ["Shape combining tools are not available."]: "Las herramientas para combinar formas no están disponibles."
  ["No clip could be combined with the text or drawing shape."]: "No se pudo combinar ningún clip con texto o dibujo."
  ["No dialogue lines selected."]: "No hay líneas de diálogo seleccionadas."
  ["No strip clips were generated."]: "No se generaron franjas de clip."
  ["No animated clip or movable clipped line could be baked."]: "No se pudo hornear ningún clip animado o línea con clip movible."
  ["Perspective tools are not available."]: "Las herramientas de perspectiva no están disponibles."
  ["No 4-point clip could be applied as perspective."]: "No se pudo aplicar ningún clip de 4 puntos como perspectiva."
}

Core.message_text = (message) ->
  text = tostring(message or "")
  return text unless current_language == "es"
  MESSAGE_ES[text] or text

Core.message_title = (title) ->
  raw = tostring(title or "Cliptomaniac")
  if OPERATION_LABELS.en[raw] then Core.operation_label(raw) else raw

Core.show_message = (message, title = "Cliptomaniac") ->
  text = Core.message_text message
  title = Core.message_title title
  aegisub.dialog.display {
    {class: "label", label: title, x: 0, y: 0, width: 34, height: 1}
    {class: "textbox", text: text, x: 0, y: 1, width: 34, height: 10}
  }, {"OK"}

Core.is_dialogue = (line) ->
  line and line.class == "dialogue" and not line.comment

Core.dialogue_indices = (subs, sel) ->
  out, seen = {}, {}
  for i in *(sel or {})
    n = tonumber i
    if n and not seen[n] and Core.is_dialogue subs[n]
      out[#out + 1] = n
      seen[n] = true
  table.sort out
  out

Core.enrich_selected_lines = (subs, sel) ->
  return false unless LineCollection
  ok, collection = pcall -> LineCollection subs, sel, ((line) -> line.class == "dialogue"), false
  return false unless ok and collection and collection.lines
  for line in *collection.lines
    n = tonumber line.number
    if n and subs[n]
      raw = subs[n]
      raw.styleref = line.styleref if line.styleref
      raw.styleRef = line.styleRef if line.styleRef
      raw.parentCollection = line.parentCollection if line.parentCollection
      raw.startFrame = line.startFrame if line.startFrame
      raw.endFrame = line.endFrame if line.endFrame
      raw.duration = line.duration if line.duration
      subs[n] = raw
  true

Core.ensure_tag_block = (text) ->
  text = tostring(text or "")
  return text if text\find "^{"
  "{}" .. text

Core.override_block_spans = (text) ->
  text = tostring(text or "")
  spans, pos = {}, 1
  while true
    s = text\find "{", pos, true
    break unless s
    e = text\find "}", s + 1, true
    break unless e
    spans[#spans + 1] = {
      start: s
      stop: e
      inner: text\sub s + 1, e - 1
    }
    pos = e + 1
  spans

Core.looks_like_override = (inner) ->
  text = tostring(inner or "")
  text\find("\\[%a%d]") != nil

Core.span_is_in_override = (text, absolute_pos) ->
  for block in *Core.override_block_spans text
    if absolute_pos > block.start and absolute_pos < block.stop and Core.looks_like_override block.inner
      return true
  false

Core.map_override_blocks = (text, mapper) ->
  text = tostring(text or "")
  out, pos, changed = {}, 1, 0
  for block in *Core.override_block_spans text
    out[#out + 1] = text\sub pos, block.start - 1
    if Core.looks_like_override block.inner
      next_inner = mapper block.inner, block
      if next_inner != nil and next_inner != block.inner
        out[#out + 1] = "{" .. tostring(next_inner) .. "}"
        changed += 1
      else
        out[#out + 1] = text\sub block.start, block.stop
    else
      out[#out + 1] = text\sub block.start, block.stop
    pos = block.stop + 1
  out[#out + 1] = text\sub pos
  table.concat(out), changed

Core.clean_empty_overrides = (text) ->
  tostring(text or "")\gsub "{%s*}", ""

Core.insert_leading_tags = (text, payload) ->
  text = tostring(text or "")
  return text if not payload or payload == ""
  first = Core.override_block_spans(text)[1]
  if first and first.start == 1 and Core.looks_like_override first.inner
    "{" .. payload .. first.inner .. "}" .. text\sub(first.stop + 1)
  else
    "{" .. payload .. "}" .. text

Core.strip_tags = (text) ->
  (tostring(text or "")\gsub "{[^}]*}", "")

Core.visible_text = Core.strip_tags

Core.override_tags_only = (text) ->
  out = {}
  for block in *Core.override_block_spans text
    if Core.looks_like_override block.inner
      out[#out + 1] = "{" .. block.inner .. "}"
  Core.clean_empty_overrides table.concat(out)

Core.next_char = (text, pos) ->
  if unicode and unicode.chars
    rest = text\sub pos
    for ch in unicode.chars rest
      return ch, #ch
  ch = text\sub pos, pos
  ch, 1

Core.last_visible_char_span = (text) ->
  text = tostring(text or "")
  pos = 1
  last_start, last_stop, last_any_start, last_any_stop = nil, nil, nil, nil
  while pos <= #text
    c = text\sub pos, pos
    if c == "{"
      close = text\find "}", pos + 1, true
      break unless close
      pos = close + 1
    elseif c == "\\" and pos < #text and text\sub(pos + 1, pos + 1)\match "[Nnh]"
      pos += 2
    else
      ch, len = Core.next_char text, pos
      len = math.max 1, tonumber(len) or 1
      last_any_start, last_any_stop = pos, pos + len - 1
      unless ch\match "^%s$"
        last_start, last_stop = pos, pos + len - 1
      pos += len
  if last_start then last_start, last_stop else last_any_start, last_any_stop

Core.insert_tag_before_last_visible = (text, tag) ->
  start_pos = Core.last_visible_char_span text
  return Core.insert_leading_tags text, tag unless start_pos
  text\sub(1, start_pos - 1) .. "{" .. tag .. "}" .. text\sub(start_pos)

Core.balanced_paren_end = (text, open_pos) ->
  depth = 0
  for i = open_pos, #text
    c = text\sub i, i
    if c == "("
      depth += 1
    elseif c == ")"
      depth -= 1
      return i if depth == 0
  nil

Core.ass_override_names = {
  "iclip", "clip", "xbord", "ybord", "xshad", "yshad", "fscx", "fscy"
  "alpha", "blur", "bord", "shad", "move", "fade", "frx", "fry", "frz", "fax", "fay"
  "pos", "org", "fad", "fsp", "fn", "fs", "be", "an", "fr", "ko", "kf", "kt"
  "1a", "2a", "3a", "4a", "1c", "2c", "3c", "4c", "c", "p", "b", "i", "u", "s", "r", "t", "q", "k", "K", "a"
}

Core.tag_name_at = (inner, slash_pos) ->
  rest = tostring(inner or "")\sub (tonumber(slash_pos) or 0) + 1
  for name in *Core.ass_override_names
    return name if rest\sub(1, #name) == name
  rest\match "^[1-4]?%a+"

Core.clip_span_in_inner = (text, inner, base_offset, init = 1) ->
  inner = inner or ""
  i = 1
  while i <= #inner
    if inner\sub(i, i) == "\\"
      name = Core.tag_name_at inner, i
      if name
        value_pos = i + 1 + #name
        if inner\sub(value_pos, value_pos) == "("
          close = Core.balanced_paren_end inner, value_pos
          return nil unless close
          absolute_start = base_offset + i
          if (name == "clip" or name == "iclip") and absolute_start >= init
            absolute_open = base_offset + value_pos
            absolute_stop = base_offset + close
            return {
              start: absolute_start
              stop: absolute_stop
              open_pos: absolute_open
              name: name
              raw: text\sub absolute_start, absolute_stop
              inner: inner\sub value_pos + 1, close - 1
            }
          nested = Core.clip_span_in_inner text, inner\sub(value_pos + 1, close - 1), base_offset + value_pos, init
          return nested if nested
          i = close + 1
          continue
        i = value_pos
        continue
    i += 1
  nil

Core.clip_span_in_block = (text, block, init = 1) ->
  Core.clip_span_in_inner text, block.inner or "", block.start, init

Core.first_clip_span = (text, init = 1) ->
  text = tostring(text or "")
  for block in *Core.override_block_spans text
    continue unless block.stop >= init and Core.looks_like_override block.inner
    span = Core.clip_span_in_block text, block, init
    return span if span
  nil

Core.all_clip_spans = (text) ->
  spans, pos = {}, 1
  while true
    span = Core.first_clip_span text, pos
    break unless span
    spans[#spans + 1] = span
    pos = span.stop + 1
  spans

Core.map_clip_tags = (text, mapper) ->
  text = tostring(text or "")
  out, pos, changed = {}, 1, 0
  while true
    span = Core.first_clip_span text, pos
    break unless span
    out[#out + 1] = text\sub pos, span.start - 1
    replacement = mapper span
    if replacement and replacement != span.raw
      out[#out + 1] = replacement
      changed += 1
    else
      out[#out + 1] = span.raw
    pos = span.stop + 1
  out[#out + 1] = text\sub pos
  table.concat(out), changed

Core.strip_clip_tags = (text) ->
  mapped = Core.map_clip_tags text, -> ""
  mapped

Core.clip_tag_text = (name, inner) ->
  "\\" .. (name or "clip") .. "(" .. tostring(inner or "") .. ")"

Core.clip_kind_from_span = (span) ->
  span and span.name or "clip"

Core.normalize_bounds = (bounds) ->
  left, top, right, bottom = unpack bounds
  left, right = right, left if left > right
  top, bottom = bottom, top if top > bottom
  {left, top, right, bottom}

Core.pad_bounds = (bounds, margin) ->
  left, top, right, bottom = unpack Core.normalize_bounds bounds
  margin = tonumber(margin) or 0
  {left - margin, top - margin, right + margin, bottom + margin}

Core.union_bounds = (a, b) ->
  a, b = Core.normalize_bounds(a), Core.normalize_bounds(b)
  {math.min(a[1], b[1]), math.min(a[2], b[2]), math.max(a[3], b[3]), math.max(a[4], b[4])}

Core.rect_clip_inner = (bounds) ->
  left, top, right, bottom = unpack Core.normalize_bounds bounds
  "#{math.floor(left)},#{math.floor(top)},#{math.ceil(right)},#{math.ceil(bottom)}"

Core.rect_clip_tag = (bounds, name = "clip") ->
  Core.clip_tag_text name, Core.rect_clip_inner bounds

Core.rect_points = (bounds) ->
  left, top, right, bottom = unpack Core.normalize_bounds bounds
  {
    {x: left, y: top}
    {x: right, y: top}
    {x: right, y: bottom}
    {x: left, y: bottom}
  }

Core.vector_clip_inner = (points) ->
  "m #{Core.format_num points[1].x} #{Core.format_num points[1].y} l #{Core.format_num points[2].x} #{Core.format_num points[2].y} #{Core.format_num points[3].x} #{Core.format_num points[3].y} #{Core.format_num points[4].x} #{Core.format_num points[4].y}"

Core.vector_clip_tag = (points, name = "clip") ->
  Core.clip_tag_text name, Core.vector_clip_inner points

Core.scale_clip_path = (path, scale) ->
  factor = 2 ^ ((tonumber(scale) or 1) - 1)
  return path if math.abs(factor - 1) < 0.0000005
  tostring(path or "")\gsub "(" .. NUM_PATTERN .. ")", (n) ->
    v = tonumber n
    if v then Core.format_num(v / factor) else n

Core.clip_scale_factor = (scale) ->
  2 ^ ((tonumber(scale) or 1) - 1)

Core.scale_path_numbers = (path, factor) ->
  tostring(path or "")\gsub "(" .. NUM_PATTERN .. ")", (n) ->
    v = tonumber n
    if v then Core.format_num(v * factor) else n

Core.vector_inner_with_scale = (path, scale) ->
  return path unless scale
  "#{scale},#{Core.scale_path_numbers path, Core.clip_scale_factor scale}"

Core.clip_inner_parts = (inner) ->
  inner = Core.trim inner
  scale, path = inner\match "^%s*(%d+)%s*,%s*([mMnN]%s+.*)$"
  if path
    return "vector", scale, Core.scale_clip_path(path, scale)
  path = inner\match "^%s*([mMnN]%s+.*)$"
  if path
    return "vector", nil, path
  nums = {}
  for n in inner\gmatch NUM_PATTERN
    nums[#nums + 1] = tonumber n
  if #nums >= 4
    return "rect", nil, {nums[1], nums[2], nums[3], nums[4]}
  nil, nil, nil

Core.clip_bounds_from_span = (span) ->
  kind, _scale, payload = Core.clip_inner_parts span.inner
  if kind == "rect"
    return Core.normalize_bounds payload
  if kind == "vector"
    cmds = Core.parse_draw_commands payload
    sampled = nil
    sampled = Core.sample_path cmds, 30 if cmds
    points = if sampled and #sampled > 0 then [item.p for item in *sampled when item and item.p] else Core.anchor_points_from_commands cmds
    if points and #points > 0
      minx, miny, maxx, maxy = math.huge, math.huge, -math.huge, -math.huge
      for p in *points
        minx = math.min minx, p.x
        miny = math.min miny, p.y
        maxx = math.max maxx, p.x
        maxy = math.max maxy, p.y
      return {minx, miny, maxx, maxy}
  nil

Core.first_clip_bounds = (text) ->
  span = Core.first_clip_span text
  return nil unless span
  Core.clip_bounds_from_span span

Core.tokens_for_path = (path) ->
  s = tostring(path or "")\gsub ",", " "
  s = s\gsub "([mMlLbBsSpPcCnN])", " %1 "
  tokens = {}
  for token in s\gmatch "%S+"
    tokens[#tokens + 1] = token
  tokens

Core.parse_draw_commands = (path) ->
  tokens = Core.tokens_for_path path
  cmds, i, cmd = {}, 1, nil
  while i <= #tokens
    token = tokens[i]
    if token\match "^[mMlLbBsSpPcCnN]$"
      cmd = token\lower!
      cmd = "m" if cmd == "n"
      if cmd == "c"
        cmds[#cmds + 1] = {type: "c", pts: {}}
        cmd = nil
      i += 1
      continue
    return nil unless cmd
    if cmd == "m" or cmd == "l" or cmd == "s" or cmd == "p"
      x, y = tonumber(tokens[i]), tonumber(tokens[i + 1])
      return nil unless x and y
      draw_type = if cmd == "m" then "m" else "l"
      cmds[#cmds + 1] = {type: draw_type, pts: {x, y}}
      i += 2
    elseif cmd == "b"
      pts = {}
      for j = 0, 5
        pts[#pts + 1] = tonumber tokens[i + j]
      return nil unless pts[1] and pts[2] and pts[3] and pts[4] and pts[5] and pts[6]
      cmds[#cmds + 1] = {type: "b", pts: pts}
      i += 6
    else
        return nil
  cmds

Core.point_xy = (x, y) ->
  {x: tonumber(x) or 0, y: tonumber(y) or 0}

Core.point_text = (prefix, point) ->
  "#{prefix} #{Core.format_num point.x} #{Core.format_num point.y}"

Core.lerp_point = (a, b, t) ->
  {
    x: a.x + (b.x - a.x) * t
    y: a.y + (b.y - a.y) * t
  }

Core.point_insert_distances = (length, opts = {}) ->
  length = tonumber(length) or 0
  out = {}
  return out unless length > 0
  if opts.point_mode == "By count"
    count = math.max 0, math.floor(tonumber(opts.point_count) or 0)
    for i = 1, count
      out[#out + 1] = length * i / (count + 1)
  else
    spacing = tonumber(opts.point_distance) or 0
    return out unless spacing > 0
    d = spacing
    while d < length - 0.0005
      out[#out + 1] = d
      d += spacing
  out

Core.add_line_insert_points = (parts, p1, p2, opts = {}, include_end = true) ->
  dx, dy = p2.x - p1.x, p2.y - p1.y
  length = math.sqrt dx * dx + dy * dy
  added = 0
  if length > 0
    for d in *Core.point_insert_distances(length, opts)
      t = d / length
      parts[#parts + 1] = Core.point_text "l", {x: p1.x + dx * t, y: p1.y + dy * t}
      added += 1
  parts[#parts + 1] = Core.point_text "l", p2 if include_end
  added

Core.bezier_arclength_samples = (p0, p1, p2, p3, segments = 80) ->
  segments = math.max 1, math.floor(tonumber(segments) or 80)
  samples = {{t: 0, p: p0, acc: 0}}
  prev, total = p0, 0
  for i = 1, segments
    t = i / segments
    pt = Core.bezier_point t, p0, p1, p2, p3
    dist = math.sqrt((pt.x - prev.x) ^ 2 + (pt.y - prev.y) ^ 2)
    total += dist
    samples[#samples + 1] = {t: t, p: pt, acc: total}
    prev = pt
  samples, total

Core.bezier_t_at_distance = (samples, target) ->
  return 0 unless samples and #samples > 0
  target = tonumber(target) or 0
  return 0 if target <= 0
  last = samples[#samples]
  return 1 if target >= (last.acc or 0)
  for i = 2, #samples
    if (samples[i].acc or 0) >= target
      a, b = samples[i - 1], samples[i]
      span = (b.acc or 0) - (a.acc or 0)
      k = if span == 0 then 0 else (target - (a.acc or 0)) / span
      return (a.t or 0) + ((b.t or 0) - (a.t or 0)) * k
  1

Core.bezier_split = (p0, p1, p2, p3, t) ->
  t = Core.clamp tonumber(t) or 0, 0, 1
  p01 = Core.lerp_point p0, p1, t
  p12 = Core.lerp_point p1, p2, t
  p23 = Core.lerp_point p2, p3, t
  p012 = Core.lerp_point p01, p12, t
  p123 = Core.lerp_point p12, p23, t
  p0123 = Core.lerp_point p012, p123, t
  {p0, p01, p012, p0123}, {p0123, p123, p23, p3}

Core.add_bezier_part = (parts, curve) ->
  parts[#parts + 1] = "b #{Core.format_num curve[2].x} #{Core.format_num curve[2].y} #{Core.format_num curve[3].x} #{Core.format_num curve[3].y} #{Core.format_num curve[4].x} #{Core.format_num curve[4].y}"

Core.add_bezier_insert_points = (parts, p0, p1, p2, p3, opts = {}) ->
  samples, total = Core.bezier_arclength_samples p0, p1, p2, p3
  targets = [Core.bezier_t_at_distance(samples, d) for d in *Core.point_insert_distances(total, opts)]
  current = {p0, p1, p2, p3}
  prev_t, added = 0, 0
  for t_abs in *targets
    continue unless t_abs > prev_t + 0.000001 and t_abs < 1 - 0.000001
    local_t = (t_abs - prev_t) / (1 - prev_t)
    left, right = Core.bezier_split current[1], current[2], current[3], current[4], local_t
    Core.add_bezier_part parts, left
    current = right
    prev_t = t_abs
    added += 1
  Core.add_bezier_part parts, current
  added

Core.add_close_insert_points = (parts, start_point, current_point, anchor_count, opts = {}) ->
  return 0 unless anchor_count >= 3 and start_point and current_point
  return 0 if Core.same_point start_point, current_point
  Core.add_line_insert_points parts, current_point, start_point, opts, false

Core.densify_clip_path = (path, opts = {}) ->
  cmds = Core.parse_draw_commands path
  return nil, 0 unless cmds
  parts, start_point, current_point, anchor_count, added = {}, nil, nil, 0, 0
  for cmd in *cmds
    if cmd.type == "m" and #cmd.pts >= 2
      added += Core.add_close_insert_points parts, start_point, current_point, anchor_count, opts
      start_point = Core.point_xy(cmd.pts[1], cmd.pts[2])
      current_point = start_point
      anchor_count = 1
      parts[#parts + 1] = Core.point_text "m", start_point
    elseif cmd.type == "l" and current_point and #cmd.pts >= 2
      next_point = Core.point_xy(cmd.pts[1], cmd.pts[2])
      unless Core.same_point current_point, next_point
        added += Core.add_line_insert_points parts, current_point, next_point, opts, true
        anchor_count += 1
      current_point = next_point
    elseif cmd.type == "b" and current_point and #cmd.pts >= 6
      c1 = Core.point_xy(cmd.pts[1], cmd.pts[2])
      c2 = Core.point_xy(cmd.pts[3], cmd.pts[4])
      next_point = Core.point_xy(cmd.pts[5], cmd.pts[6])
      added += Core.add_bezier_insert_points parts, current_point, c1, c2, next_point, opts
      current_point = next_point
      anchor_count += 1
    elseif cmd.type == "c"
      added += Core.add_close_insert_points parts, start_point, current_point, anchor_count, opts
      current_point = start_point if start_point
  added += Core.add_close_insert_points parts, start_point, current_point, anchor_count, opts
  return nil, 0 if #parts == 0
  Core.trim(table.concat(parts, " ")), added

Core.path_subpaths = (cmds) ->
  subpaths, current = {}, nil
  for cmd in *(cmds or {})
    if cmd.type == "m" and #cmd.pts >= 2
      current = {points: {Core.point_xy(cmd.pts[1], cmd.pts[2])}}
      subpaths[#subpaths + 1] = current
    elseif current and cmd.type == "l" and #cmd.pts >= 2
      current.points[#current.points + 1] = Core.point_xy(cmd.pts[1], cmd.pts[2])
    elseif current and cmd.type == "b" and #cmd.pts >= 6
      current.points[#current.points + 1] = Core.point_xy(cmd.pts[5], cmd.pts[6])
  for sub in *subpaths
    sub.points = Core.clean_anchor_points sub.points
  subpaths

Core.path_from_subpaths = (subpaths) ->
  parts = {}
  for sub in *(subpaths or {})
    pts = sub.points or {}
    continue unless #pts > 0
    parts[#parts + 1] = Core.point_text "m", pts[1]
    for i = 2, #pts
      parts[#parts + 1] = Core.point_text "l", pts[i]
  return nil if #parts == 0
  Core.trim table.concat parts, " "

Core.remove_alternate_clip_points_path = (path) ->
  cmds = Core.parse_draw_commands path
  return nil, false unless cmds
  subpaths = Core.path_subpaths cmds
  changed = false
  for sub in *subpaths
    pts = sub.points or {}
    if #pts > 3
      reduced = {}
      for i, point in ipairs pts
        reduced[#reduced + 1] = point if i % 2 == 1
      if #reduced >= 3 and #reduced < #pts
        sub.points = reduced
        changed = true
  return nil, false unless changed
  Core.path_from_subpaths(subpaths), true

Core.new_shape_split_path = (path) ->
  cmds = Core.parse_draw_commands path
  return nil unless cmds
  subpaths = Core.path_subpaths cmds
  return nil unless #subpaths > 0
  last_sub = subpaths[#subpaths]
  return nil unless last_sub and last_sub.points and #last_sub.points >= 3
  last_point = last_sub.points[#last_sub.points]
  output, removed = {}, false
  for i = 1, #cmds
    cmd = cmds[i]
    if i == #cmds and (cmd.type == "l" or cmd.type == "b")
      removed = true
      continue
    if cmd.type == "m" and #cmd.pts >= 2
      output[#output + 1] = Core.point_text "m", Core.point_xy(cmd.pts[1], cmd.pts[2])
    elseif cmd.type == "l" and #cmd.pts >= 2
      output[#output + 1] = Core.point_text "l", Core.point_xy(cmd.pts[1], cmd.pts[2])
    elseif cmd.type == "b" and #cmd.pts >= 6
      output[#output + 1] = "b #{Core.format_num cmd.pts[1]} #{Core.format_num cmd.pts[2]} #{Core.format_num cmd.pts[3]} #{Core.format_num cmd.pts[4]} #{Core.format_num cmd.pts[5]} #{Core.format_num cmd.pts[6]}"
  return nil unless removed and #output > 0
  output[#output + 1] = Core.point_text "m", last_point
  Core.trim table.concat output, " "

Core.clip_commands_from_span = (span) ->
  kind, _scale, payload = Core.clip_inner_parts span.inner
  if kind == "rect"
    left, top, right, bottom = unpack Core.normalize_bounds payload
    return {
      {type: "m", pts: {left, top}}
      {type: "l", pts: {right, top}}
      {type: "l", pts: {right, bottom}}
      {type: "l", pts: {left, bottom}}
      {type: "l", pts: {left, top}}
    }
  if kind == "vector"
    return Core.parse_draw_commands payload
  nil

Core.same_point = (a, b, epsilon = 0.0005) ->
  a and b and math.abs((a.x or 0) - (b.x or 0)) <= epsilon and math.abs((a.y or 0) - (b.y or 0)) <= epsilon

Core.clean_anchor_points = (points) ->
  out = {}
  for p in *(points or {})
    if p and p.x and p.y and (not out[#out] or not Core.same_point out[#out], p)
      out[#out + 1] = {x: p.x, y: p.y}
  if #out > 1 and Core.same_point out[1], out[#out]
    table.remove out
  out

Core.anchor_points_from_commands = (cmds) ->
  points = {}
  for cmd in *(cmds or {})
    if (cmd.type == "m" or cmd.type == "l") and #cmd.pts >= 2
      points[#points + 1] = {x: cmd.pts[1], y: cmd.pts[2]}
    elseif cmd.type == "b" and #cmd.pts >= 6
      points[#points + 1] = {x: cmd.pts[5], y: cmd.pts[6]}
  Core.clean_anchor_points points

Core.center_from_points = (points) ->
  return nil unless points and #points > 0
  minx, miny, maxx, maxy = math.huge, math.huge, -math.huge, -math.huge
  for p in *points
    minx = math.min minx, p.x
    miny = math.min miny, p.y
    maxx = math.max maxx, p.x
    maxy = math.max maxy, p.y
  {x: (minx + maxx) / 2, y: (miny + maxy) / 2}

Core.quad_points_from_span = (span) ->
  kind, _scale, payload = Core.clip_inner_parts span.inner
  if kind == "rect"
    return Core.rect_points payload
  return nil unless kind == "vector"
  cmds = Core.parse_draw_commands payload
  points = Core.anchor_points_from_commands cmds
  return nil unless #points == 4
  points

Core.first_clip_commands = (text) ->
  span = Core.first_clip_span text
  return nil, nil unless span
  Core.clip_commands_from_span(span), span

Core.atan2 = (dy, dx) ->
  dy, dx = tonumber(dy) or 0, tonumber(dx) or 0
  if math.atan2
    return math.atan2 dy, dx
  if dx > 0 then return math.atan(dy / dx)
  if dx < 0 and dy >= 0 then return math.atan(dy / dx) + math.pi
  if dx < 0 then return math.atan(dy / dx) - math.pi
  if dy > 0 then return math.pi / 2
  if dy < 0 then return -math.pi / 2
  0

Core.segment_length = (segment) ->
  return 0 unless segment
  dx, dy = segment.x2 - segment.x1, segment.y2 - segment.y1
  math.sqrt dx * dx + dy * dy

Core.segment_angle_math = (segment) ->
  return 0 unless segment
  math.deg Core.atan2 segment.y2 - segment.y1, segment.x2 - segment.x1

Core.segment_frz = (segment) ->
  -Core.segment_angle_math segment

Core.lerp_angle = (a, b, t) ->
  a, b = tonumber(a) or 0, tonumber(b) or 0
  delta = (b - a) % (math.pi * 2)
  delta -= math.pi * 2 if delta > math.pi
  a + delta * (tonumber(t) or 0)

Core.first_real_angle = (sampled, fallback = 0) ->
  return fallback unless sampled
  for item in *sampled
    return item.angle if item and (item.dist or 0) > 0 and item.angle != nil
  fallback

Core.bezier_point = (t, p0, p1, p2, p3) ->
  u = 1 - t
  tt, uu = t * t, u * u
  uuu, ttt = uu * u, tt * t
  {
    x: uuu * p0.x + 3 * uu * t * p1.x + 3 * u * tt * p2.x + ttt * p3.x
    y: uuu * p0.y + 3 * uu * t * p1.y + 3 * u * tt * p2.y + ttt * p3.y
  }

Core.bezier_derivative = (t, p0, p1, p2, p3) ->
  u = 1 - t
  uu, tt = u * u, t * t
  {
    x: 3 * uu * (p1.x - p0.x) + 6 * u * t * (p2.x - p1.x) + 3 * tt * (p3.x - p2.x)
    y: 3 * uu * (p1.y - p0.y) + 6 * u * t * (p2.y - p1.y) + 3 * tt * (p3.y - p2.y)
  }

Core.first_path_segments = (cmds, count = 2, bezier_steps = 8) ->
  out, cur = {}, nil
  for cmd in *(cmds or {})
    if cmd.type == "m" and #cmd.pts >= 2
      cur = {x: cmd.pts[1], y: cmd.pts[2]}
    elseif cmd.type == "l" and cur and #cmd.pts >= 2
      nx, ny = cmd.pts[1], cmd.pts[2]
      if nx != cur.x or ny != cur.y
        out[#out + 1] = {x1: cur.x, y1: cur.y, x2: nx, y2: ny}
        return out if #out >= count
      cur = {x: nx, y: ny}
    elseif cmd.type == "b" and cur and #cmd.pts >= 6
      p1 = {x: cmd.pts[1], y: cmd.pts[2]}
      p2 = {x: cmd.pts[3], y: cmd.pts[4]}
      p3 = {x: cmd.pts[5], y: cmd.pts[6]}
      prev = cur
      for step = 1, math.max(1, bezier_steps)
        pt = Core.bezier_point step / bezier_steps, cur, p1, p2, p3
        if pt.x != prev.x or pt.y != prev.y
          out[#out + 1] = {x1: prev.x, y1: prev.y, x2: pt.x, y2: pt.y}
          return out if #out >= count
        prev = pt
      cur = p3
  out

Core.sample_path = (cmds, segments = 30) ->
  pts, cur = {}, {x: 0, y: 0}
  segments = math.max 1, tonumber(segments) or 30
  for cmd in *(cmds or {})
    if cmd.type == "m" and #cmd.pts >= 2
      cur = {x: cmd.pts[1], y: cmd.pts[2]}
      pts[#pts + 1] = {p: cur, dist: 0, angle: 0}
    elseif cmd.type == "l" and #cmd.pts >= 2
      pts[#pts + 1] = {p: cur, dist: 0, angle: 0} if #pts == 0
      nx, ny = cmd.pts[1], cmd.pts[2]
      dx, dy = nx - cur.x, ny - cur.y
      dist = math.sqrt dx * dx + dy * dy
      if dist > 0
        ang = Core.atan2 dy, dx
        for j = 1, segments
          t = j / segments
          pts[#pts + 1] = {p: {x: cur.x + dx * t, y: cur.y + dy * t}, dist: dist / segments, angle: ang}
      cur = {x: nx, y: ny}
    elseif cmd.type == "b" and #cmd.pts >= 6
      pts[#pts + 1] = {p: cur, dist: 0, angle: 0} if #pts == 0
      p1 = {x: cmd.pts[1], y: cmd.pts[2]}
      p2 = {x: cmd.pts[3], y: cmd.pts[4]}
      p3 = {x: cmd.pts[5], y: cmd.pts[6]}
      for j = 1, segments
        t = j / segments
        pt = Core.bezier_point t, cur, p1, p2, p3
        dp = Core.bezier_derivative t, cur, p1, p2, p3
        prev = pts[#pts] and pts[#pts].p or cur
        pts[#pts + 1] = {
          p: pt
          dist: math.sqrt((pt.x - prev.x) ^ 2 + (pt.y - prev.y) ^ 2)
          angle: Core.atan2 dp.y, dp.x
        }
      cur = p3
  total = 0
  for i = 2, #pts
    total += pts[i].dist or 0
    pts[i].accDist = total
  pts[1].accDist = 0 if pts[1]
  pts, total

Core.point_on_path = (sampled, target) ->
  return nil unless sampled and #sampled > 0
  if target <= 0
    first = sampled[1]
    return {p: first.p, angle: Core.first_real_angle sampled, first.angle or 0}
  return sampled[#sampled] if target >= sampled[#sampled].accDist
  for i = 2, #sampled
    if sampled[i].accDist >= target
      p1, p2 = sampled[i - 1], sampled[i]
      d = p2.accDist - p1.accDist
      t = if d == 0 then 0 else (target - p1.accDist) / d
      a1, a2 = p1.angle or 0, p2.angle or 0
      a1 = a2 if (p1.dist or 0) == 0
      return {
        p: {
          x: p1.p.x + (p2.p.x - p1.p.x) * t
          y: p1.p.y + (p2.p.y - p1.p.y) * t
        }
        angle: Core.lerp_angle a1, a2, t
      }
  sampled[#sampled]

Core.first_clip_path_reference = (subs, sel) ->
  for i in *Core.dialogue_indices(subs, sel)
    cmds, span = Core.first_clip_commands subs[i].text
    return cmds, span, i if cmds and span
  nil, nil, nil

Core.path_midpoint = (cmds) ->
  sampled, total = Core.sample_path cmds, 40
  return nil unless sampled and total and total > 0
  item = Core.point_on_path sampled, total / 2
  item and item.p

Core.clip_midpoint_from_span = (span) ->
  return nil unless span
  kind, _scale, payload = Core.clip_inner_parts span.inner
  if kind == "rect"
    b = Core.normalize_bounds payload
    return {x: (b[1] + b[3]) / 2, y: (b[2] + b[4]) / 2}
  return nil unless kind == "vector"
  cmds = Core.clip_commands_from_span span
  anchors = Core.anchor_points_from_commands cmds
  return Core.center_from_points anchors if #anchors >= 4
  Core.path_midpoint cmds

Core.clip_midpoint_for_line = (line, fallback = nil) ->
  span = Core.first_clip_span line.text
  if span
    point = Core.clip_midpoint_from_span span
    return point if point
  fallback

Core.path_segments = (cmds, steps = 30) ->
  sampled, total = Core.sample_path cmds, steps
  out = {}
  return out unless total and total > 0
  for i = 2, #sampled
    a, b = sampled[i - 1], sampled[i]
    if a and b and a.p and b.p and (b.dist or 0) > 0
      out[#out + 1] = {x1: a.p.x, y1: a.p.y, x2: b.p.x, y2: b.p.y}
  out

Core.distance_to_segment = (px, py, x1, y1, x2, y2) ->
  dx, dy = x2 - x1, y2 - y1
  len2 = dx * dx + dy * dy
  if len2 == 0
    ddx, ddy = px - x1, py - y1
    return math.sqrt(ddx * ddx + ddy * ddy), x1, y1
  t = ((px - x1) * dx + (py - y1) * dy) / len2
  t = Core.clamp t, 0, 1
  bx, by = x1 + t * dx, y1 + t * dy
  ddx, ddy = px - bx, py - by
  math.sqrt(ddx * ddx + ddy * ddy), bx, by

Core.clip_scale_reference = (subs, sel) ->
  clipped, single = {}, nil
  for i in *(sel or {})
    line = subs[i]
    if Core.is_dialogue line
      cmds, span = Core.first_clip_commands line.text
      if cmds
        segs = Core.first_path_segments cmds, 2, 8
        if #segs > 0
          clipped[#clipped + 1] = {index: i, seg: segs[1], span: span}
          single = {index: i, seg1: segs[1], seg2: segs[2], span: span} if not single and #segs >= 2
  if #clipped >= 2
    return clipped[1].seg, clipped[2].seg, {mode: "lines", source: clipped[1].index, target: clipped[2].index}
  if single
    return single.seg1, single.seg2, {mode: "single", source: single.index}
  nil, nil, nil, "no_clip"

Core.visible_char_spans = (text) ->
  text = tostring(text or "")
  spans, pos = {}, 1
  while pos <= #text
    c = text\sub pos, pos
    if c == "{"
      close = text\find "}", pos + 1, true
      break unless close
      pos = close + 1
    elseif c == "\\" and pos < #text and text\sub(pos + 1, pos + 1)\match "[Nnh]"
      pos += 2
    else
      ch, len = Core.next_char text, pos
      len = math.max 1, tonumber(len) or 1
      unless ch\match "^%s$"
        spans[#spans + 1] = {start: pos, stop: pos + len - 1}
      pos += len
  spans

Core.selected_stop_indices = (count, limit) ->
  return {} if count <= 0
  limit = math.floor(tonumber(limit) or 0)
  limit = count if limit <= 0 or limit > count
  return {1} if count == 1 or limit == 1
  seen, out = {}, {}
  for i = 1, limit
    idx = 1 + math.floor((i - 1) * (count - 1) / (limit - 1) + 0.5)
    unless seen[idx]
      seen[idx] = true
      out[#out + 1] = idx
  out

Core.insert_tags_at_spans = (text, inserts) ->
  text = tostring(text or "")
  return text unless inserts and #inserts > 0
  table.sort inserts, (a, b) -> a.pos < b.pos
  out, cursor = {}, 1
  for item in *inserts
    pos = Core.clamp tonumber(item.pos) or 1, 1, #text + 1
    if pos >= cursor
      out[#out + 1] = text\sub cursor, pos - 1
      out[#out + 1] = item.tag
      cursor = pos
  out[#out + 1] = text\sub cursor
  table.concat out

Core.numeric_tag_value = (text, tag, fallback = nil) ->
  value = nil
  for block in *Core.override_block_spans text
    continue unless Core.looks_like_override block.inner
    i = 1
    while i <= #block.inner
      if block.inner\sub(i, i) == "\\"
        name = Core.tag_name_at block.inner, i
        if name
          value_pos = i + 1 + #name
          if block.inner\sub(value_pos, value_pos) == "("
            close = Core.balanced_paren_end block.inner, value_pos
            i = (close or value_pos) + 1
            continue
          if name == tag
            raw = block.inner\sub(value_pos)\match "^" .. NUM_PATTERN
            value = tonumber(raw) or value if raw and raw != ""
          i = value_pos
          continue
      i += 1
  value or fallback

Core.ass_tag_names = {
  an: "align"
  fscx: "scale_x"
  fscy: "scale_y"
  fr: "angle"
  frz: "angle"
  frx: "angle_x"
  fry: "angle_y"
  fax: "shear_x"
  fay: "shear_y"
  fs: "fontsize"
  fsp: "spacing"
  b: "bold"
  i: "italic"
  u: "underline"
  s: "strikeout"
  bord: "outline"
  xbord: "outline_x"
  ybord: "outline_y"
  shad: "shadow"
  xshad: "shadow_x"
  yshad: "shadow_y"
  blur: "blur"
  be: "be"
}

Core.tag_number = (value, fallback = nil) ->
  kind = type value
  return value and 1 or 0 if kind == "boolean"
  if kind == "number" or kind == "string"
    n = tonumber value
    return n if n != nil
  return fallback unless kind == "table"
  n = tonumber value.value
  return n if n != nil
  if value.getTagParams
    ok, raw = pcall -> value\getTagParams!
    n = tonumber raw if ok
    return n if n != nil
  if value.get
    ok, raw = pcall -> value\get!
    n = tonumber raw if ok
    return n if n != nil
  fallback

Core.effective_line_state = (line, index = -1) ->
  state = {line: line, tags: {}}
  if ASS and line
    ok_data, data = pcall -> Core.parse_ass_line line
    if ok_data and data
      state.data = data
      if data.getEffectiveTags
        ok_tags, tag_list = pcall -> data\getEffectiveTags index, true, true, true
        if ok_tags and tag_list
          state.tag_list = tag_list
          state.tags = tag_list.tags or {}
          style_ref = data.line and (data.line.styleRef or data.line.styleref) or line.styleRef or line.styleref
          if tag_list.getStyleTable and type(style_ref) == "table"
            ok_style, style = pcall -> tag_list\getStyleTable style_ref, line.style or style_ref.name, true
            state.style = style if ok_style and type(style) == "table"
  state.style or= Core.copy_style(line and (line.styleRef or line.styleref)) or {}
  state

Core.style_value = (line, key, fallback, state = nil) ->
  state or= Core.effective_line_state line
  style = state and state.style or line and (line.styleref or line.styleRef) or {}
  tonumber(style[key]) or fallback

Core.line_tag_value = (line, tag, style_key = nil, fallback = nil, state = nil) ->
  state or= Core.effective_line_state line
  ass_name = Core.ass_tag_names[tag] or tag
  value = Core.tag_number state and state.tags and state.tags[ass_name]
  return value if value != nil
  value = Core.numeric_tag_value line and line.text or "", tag
  return value if value != nil
  return Core.style_value(line, style_key, fallback, state) if style_key
  fallback

Core.remove_tag_names = (text, names) ->
  set = {}
  set[name] = true for name in *names
  mapped = Core.map_override_blocks text, (inner) ->
    out, i = {}, 1
    while i <= #inner
      if inner\sub(i, i) == "\\"
        name = Core.tag_name_at inner, i
        if name
          value_pos = i + 1 + #name
          if inner\sub(value_pos, value_pos) == "("
            close = Core.balanced_paren_end inner, value_pos
            close = value_pos unless close
            unless set[name]
              out[#out + 1] = inner\sub i, close
            i = close + 1
            continue
          raw = inner\sub(value_pos)\match "^" .. NUM_PATTERN
          if set[name] and raw and raw != ""
            i = value_pos + #raw
            continue
      out[#out + 1] = inner\sub i, i
      i += 1
    table.concat out
  Core.clean_empty_overrides mapped

Core.replace_or_insert_numeric_tag = (text, tag, value) ->
  text = tostring(text or "")
  payload = "\\" .. tag .. Core.format_num(value, 4)
  replaced = false
  new_text = Core.map_override_blocks text, (inner) ->
    return inner if replaced
    i = 1
    while i <= #inner
      if inner\sub(i, i) == "\\"
        name = Core.tag_name_at inner, i
        if name
          value_pos = i + 1 + #name
          if inner\sub(value_pos, value_pos) == "("
            close = Core.balanced_paren_end inner, value_pos
            i = (close or value_pos) + 1
            continue
          if name == tag
            raw = inner\sub(value_pos)\match "^" .. NUM_PATTERN
            if raw and raw != ""
              replaced = true
              return inner\sub(1, i - 1) .. payload .. inner\sub(value_pos + #raw)
          i = value_pos
          continue
      i += 1
    inner
  return new_text if replaced
  Core.insert_leading_tags text, payload

Core.scale_existing_numeric_tag = (text, tag, factor, fallback = nil) ->
  found = false
  text = Core.map_override_blocks text, (inner) ->
    out, i = {}, 1
    while i <= #inner
      if inner\sub(i, i) == "\\"
        name = Core.tag_name_at inner, i
        if name
          value_pos = i + 1 + #name
          if inner\sub(value_pos, value_pos) == "("
            close = Core.balanced_paren_end inner, value_pos
            close = value_pos unless close
            out[#out + 1] = inner\sub i, close
            i = close + 1
            continue
          if name == tag
            raw = inner\sub(value_pos)\match "^" .. NUM_PATTERN
            if raw and raw != ""
              found = true
              out[#out + 1] = "\\" .. tag .. Core.format_num((tonumber(raw) or 0) * factor, 4)
              i = value_pos + #raw
              continue
      out[#out + 1] = inner\sub i, i
      i += 1
    table.concat out
  if not found and fallback and math.abs(factor - 1) > 0.0001
    text = Core.insert_leading_tags text, "\\" .. tag .. Core.format_num(fallback * factor, 4)
  text

Core.adjust_text_by_ratio = (line, ratio, opts) ->
  text = line.text or ""
  state = Core.effective_line_state line
  axis = opts.axis
  if axis == "x" or axis == "both"
    base = Core.line_tag_value line, "fscx", "scale_x", 100, state
    text = Core.scale_existing_numeric_tag text, "fscx", ratio, base if opts.adj_fscx
  if axis == "y" or axis == "both"
    base = Core.line_tag_value line, "fscy", "scale_y", 100, state
    text = Core.scale_existing_numeric_tag text, "fscy", ratio, base if opts.adj_fscy
  text = Core.scale_existing_numeric_tag text, "fs", ratio, Core.style_value(line, "fontsize", 20, state) if opts.adj_fs
  text = Core.scale_existing_numeric_tag text, "fsp", ratio, Core.style_value(line, "spacing", 0, state) if opts.adj_fsp
  if opts.adj_bord
    text = Core.scale_existing_numeric_tag text, "bord", ratio, Core.style_value(line, "outline", 0, state)
    text = Core.scale_existing_numeric_tag text, "xbord", ratio
    text = Core.scale_existing_numeric_tag text, "ybord", ratio
  if opts.adj_shad
    text = Core.scale_existing_numeric_tag text, "shad", ratio, Core.style_value(line, "shadow", 0, state)
    text = Core.scale_existing_numeric_tag text, "xshad", ratio
    text = Core.scale_existing_numeric_tag text, "yshad", ratio
  if opts.adj_blur
    text = Core.scale_existing_numeric_tag text, "blur", ratio
    text = Core.scale_existing_numeric_tag text, "be", ratio
  text

Core.rectangle_clip_bounds_from_line = (line) ->
  span = Core.first_clip_span line and line.text
  return nil, "no_clip" unless span
  kind, _scale, payload = Core.clip_inner_parts span.inner
  return Core.normalize_bounds(payload), nil if kind == "rect"
  return nil, "vector_clip" if kind == "vector"
  nil, "bad_clip"

Core.align_for_line = (line) ->
  n = math.floor tonumber(Core.line_tag_value(line, "an", "align", 5)) or 5
  if n >= 1 and n <= 9 then n else 5

Core.zf_align_for_line = (line) ->
  for block in *Core.override_block_spans(line and line.text or "")
    if block.inner\find("\\an[1-9]") or block.inner\find("\\r", 1, true)
      return Core.align_for_line line
  n = math.floor tonumber(line and line.styleref and line.styleref.align) or 0
  return n if n >= 1 and n <= 9
  Core.align_for_line line

Core.leading_override_tags = (text) ->
  payload, cursor = {}, 1
  for block in *Core.override_block_spans text
    break unless block.start == cursor
    payload[#payload + 1] = block.inner if Core.looks_like_override block.inner
    cursor = block.stop + 1
  table.concat payload

Core.prepare_zf_text_line = (dlg, source_line, drop_clip = true) ->
  work = Core.copy_line source_line
  work.styleref = Core.copy_style work.styleref if work.styleref
  work.styleRef = Core.copy_style work.styleRef if work.styleRef
  work.text = Core.strip_clip_tags work.text if drop_clip
  leading = Core.leading_override_tags work.text
  work.text = "{" .. leading .. "}" .. work.text if leading != ""
  call = ZF.line(work)\prepoc dlg
  pers = dlg\getPerspectiveTags work
  source_align = Core.zf_align_for_line work
  align = source_align
  shape = ZF.util\isShape work.text
  multiline = work.text\find("\\N", 1, true) or work.text\find("\\n", 1, true)
  if not shape and not Core.line_needs_projected_quad(work) and pers and pers.pos and not multiline
    width, height = tonumber(work.width), tonumber(work.height)
    if width and height and width > 0 and height > 0
      column = (source_align - 1) % 3
      row = math.floor (source_align - 1) / 3
      x = pers.pos[1] - (column == 1 and width / 2 or column == 2 and width or 0)
      y = pers.pos[2] - (row == 0 and height or row == 1 and height / 2 or 0)
      work.text = Core.remove_tag_names work.text, {"an", "pos", "move"}
      work.text = Core.insert_leading_tags work.text, "\\an7\\pos(#{Core.format_num x, 4},#{Core.format_num y, 4})"
      call = ZF.line(work)\prepoc dlg
      pers = dlg\getPerspectiveTags work
      align = 7
  {:work, :call, :pers, :align, :source_align}

Core.anchor_point_from_align = (align, bounds) ->
  left, top, right, bottom = unpack Core.normalize_bounds bounds
  an = math.floor tonumber(align) or 5
  an = 5 unless an >= 1 and an <= 9
  h = (an - 1) % 3
  v = math.floor (an - 1) / 3
  x = if h == 0 then left elseif h == 1 then (left + right) / 2 else right
  y = if v == 0 then bottom elseif v == 1 then (top + bottom) / 2 else top
  {:x, :y}

Core.rescale_text_dimensions = (line, fx, fy, opts) ->
  text = line.text or ""
  state = Core.effective_line_state line
  fu = math.sqrt math.max(fx * fy, 0)
  fu = (fx + fy) / 2 if fu == 0
  if opts.adj_fscx
    base = Core.line_tag_value line, "fscx", "scale_x", 100, state
    text = Core.scale_existing_numeric_tag text, "fscx", fx, base
  if opts.adj_fscy
    base = Core.line_tag_value line, "fscy", "scale_y", 100, state
    text = Core.scale_existing_numeric_tag text, "fscy", fy, base
  text = Core.scale_existing_numeric_tag text, "fsp", fx, Core.style_value(line, "spacing", 0, state) if opts.adj_fsp
  if opts.adj_bord
    text = Core.scale_existing_numeric_tag text, "bord", fu, Core.style_value(line, "outline", 0, state)
    text = Core.scale_existing_numeric_tag text, "xbord", fx
    text = Core.scale_existing_numeric_tag text, "ybord", fy
  if opts.adj_shad
    text = Core.scale_existing_numeric_tag text, "shad", fu, Core.style_value(line, "shadow", 0, state)
    text = Core.scale_existing_numeric_tag text, "xshad", fx
    text = Core.scale_existing_numeric_tag text, "yshad", fy
  if opts.adj_blur
    text = Core.scale_existing_numeric_tag text, "blur", fu
    text = Core.scale_existing_numeric_tag text, "be", fu
  text

Core.rescale_line_by_rectangle_clip = (dlg, line, opts) ->
  rect, err = Core.rectangle_clip_bounds_from_line line
  return nil, err unless rect
  left, top, right, bottom = unpack rect
  clip_w, clip_h = right - left, bottom - top
  return nil, "bad_clip" unless clip_w > 0 and clip_h > 0
  shape = Core.build_text_bounds dlg, line, opts
  return nil, "no_text" unless shape and shape.w and shape.h and shape.w > 0 and shape.h > 0
  fx, fy = clip_w / shape.w, clip_h / shape.h
  if opts.rescale_rect_mode == "Fit (uniform)"
    f = math.min fx, fy
    fx, fy = f, f
  elseif opts.rescale_rect_mode == "Fill (uniform)"
    f = math.max fx, fy
    fx, fy = f, f
  text = Core.rescale_text_dimensions line, fx, fy, opts
  if opts.recenter and not text\find "\\move%("
    align = shape.align or Core.align_for_line line
    anchor = Core.anchor_point_from_align align, rect
    text = Core.replace_pos_or_insert text, anchor.x, anchor.y
  text = Core.strip_clip_tags text if opts.remove_clip
  text, nil, {fx: fx, fy: fy, rect: rect, text_w: shape.w, text_h: shape.h}

Core.transform_clip_ruler_text = (line, seg1, seg2, opts) ->
  d1, d2 = Core.segment_length(seg1), Core.segment_length(seg2)
  return nil, nil, "zero" if d1 == 0
  ratio = d2 / d1
  axis = opts.axis == "y" and "y" or "x"
  scale_tag = axis == "y" and "fscy" or "fscx"
  style_key = axis == "y" and "scale_y" or "scale_x"
  base = Core.line_tag_value line, scale_tag, style_key, 100
  start_tags = "\\" .. scale_tag .. Core.format_num(base, 4)
  final_tags = "\\" .. scale_tag .. Core.format_num(base * ratio, 4)
  if opts.angle_mode == "first angle" or opts.angle_mode == "transform angle"
    start_tags ..= "\\frz" .. Core.format_num(Core.segment_frz(seg1), 2)
  if opts.angle_mode == "transform angle"
    final_tags ..= "\\frz" .. Core.format_num(Core.segment_frz(seg2), 2)
  dur = math.max 0, (tonumber(line.end_time) or 0) - (tonumber(line.start_time) or 0)
  payload = start_tags .. "\\t(0," .. tostring(dur) .. "," .. final_tags .. ")"
  Core.insert_leading_tags(line.text or "", payload), {d1: d1, d2: d2, ratio: ratio, a1: Core.segment_frz(seg1), a2: Core.segment_frz(seg2)}

Core.frz_lerp_stops_text = (line, seg1, seg2, opts) ->
  a1, a2 = Core.segment_frz(seg1), Core.segment_frz(seg2)
  text = Core.insert_leading_tags line.text or "", "\\frz" .. Core.format_num(a1, 2)
  text = Core.insert_tag_before_last_visible text, "\\frz" .. Core.format_num(a2, 2)
  text = Core.strip_clip_tags text if opts.remove_clip
  text, {a1: a1, a2: a2}

Core.frz_tangent_stops_text = (line, cmds, opts = {}) ->
  return nil unless cmds
  spans = Core.visible_char_spans line.text
  return nil unless #spans > 0
  sampled, total = Core.sample_path cmds, 40
  return nil unless sampled and total and total > 0
  indices = Core.selected_stop_indices #spans, opts.tangent_stops
  inserts = {}
  for idx in *indices
    ratio = if #spans <= 1 then 0 else (idx - 1) / (#spans - 1)
    point = Core.point_on_path sampled, total * ratio
    continue unless point and point.angle != nil
    angle = -math.deg point.angle
    inserts[#inserts + 1] = {pos: spans[idx].start, tag: "{\\frz#{Core.format_num angle, 2}}"}
  return nil if #inserts == 0
  text = Core.insert_tags_at_spans line.text or "", inserts
  text = Core.strip_clip_tags text if opts.remove_clip
  text, {stops: #inserts}

Core.measure_report = (label, seg1, seg2) ->
  d1, d2 = Core.segment_length(seg1), Core.segment_length(seg2)
  ratio = if d1 == 0 then 0 else d2 / d1
  if current_language == "es"
    table.concat {
      label
      "Primero: #{Core.format_num d1, 2} px @ #{Core.format_num Core.segment_frz(seg1), 2} deg"
      "Segundo: #{Core.format_num d2, 2} px @ #{Core.format_num Core.segment_frz(seg2), 2} deg"
      "Cambio: #{Core.format_num (ratio - 1) * 100, 2}%"
    }, "\n"
  else
    table.concat {
      label
      "First: #{Core.format_num d1, 2} px @ #{Core.format_num Core.segment_frz(seg1), 2} deg"
      "Second: #{Core.format_num d2, 2} px @ #{Core.format_num Core.segment_frz(seg2), 2} deg"
      "Change: #{Core.format_num (ratio - 1) * 100, 2}%"
    }, "\n"

Core.op_measure = (subs, sel, opts) ->
  reports = {}
  for n, i in ipairs Core.dialogue_indices(subs, sel)
    cmds = Core.first_clip_commands subs[i].text
    if cmds
      segs = Core.first_path_segments cmds, 2, 8
      if #segs >= 2
        reports[#reports + 1] = Core.measure_report "#{Core.L('line')} #{i}", segs[1], segs[2]
  if #reports == 0
    Core.show_message "No vector clip with two usable segments was found."
    return false
  Core.show_message table.concat(reports, "\n\n"), "Measure clip"
  true

Core.op_measure_transform = (subs, sel, opts) ->
  changed, reports = 0, {}
  for i in *Core.dialogue_indices(subs, sel)
    line = subs[i]
    cmds = Core.first_clip_commands line.text
    continue unless cmds
    segs = Core.first_path_segments cmds, 2, 8
    continue unless #segs >= 2
    next_text, meta = Core.transform_clip_ruler_text line, segs[1], segs[2], opts
    if next_text and next_text != line.text
      line.text = next_text
      subs[i] = line
      changed += 1
      reports[#reports + 1] = Core.measure_report "#{Core.L('line')} #{i}", segs[1], segs[2]
  if changed == 0
    Core.show_message "No line was transformed."
    return false
  aegisub.set_undo_point "Cliptomaniac - Measure transform"
  Core.show_message table.concat(reports, "\n\n"), "Measure & transform clip" if opts.info
  true

Core.op_adjust_by_clip_scale = (subs, sel, opts) ->
  seg1, seg2, meta, err = Core.clip_scale_reference subs, sel
  unless seg1 and seg2
    Core.show_message "Select two clipped lines, or one vector clip with two m-l strokes."
    return false
  d1, d2 = Core.segment_length(seg1), Core.segment_length(seg2)
  if d1 == 0
    Core.show_message "First clip segment has zero length."
    return false
  ratio = d2 / d1
  changed = 0
  for i in *Core.dialogue_indices(subs, sel)
    line = subs[i]
    next_text = Core.adjust_text_by_ratio line, ratio, opts
    if next_text != line.text
      line.text = next_text
      subs[i] = line
      changed += 1
  if changed == 0
    Core.show_message "No numeric tags changed."
    return false
  aegisub.set_undo_point "Cliptomaniac - Adjust by clip scale"
  if opts.info
    message = if current_language == "es" then "Proporción #{Core.format_num ratio * 100, 2}% aplicada a #{changed} línea(s)." else "Ratio #{Core.format_num ratio * 100, 2}% applied to #{changed} line(s)."
    Core.show_message message, "Adjust by clip scale"
  true

Core.op_rescale_by_rectangle_clip = (subs, sel, opts) ->
  unless ZF
    Core.show_message "Shape tools are not available."
    return false
  dlg = nil
  ok_dlg, value = pcall -> ZF.dialog subs, sel, nil, false
  dlg = value if ok_dlg
  unless dlg
    Core.show_message "Could not prepare text bounds."
    return false
  changed, skipped = 0, 0
  reasons, reports = {}, {}
  for i in *Core.dialogue_indices(subs, sel)
    line = subs[i]
    next_text, err, meta = Core.rescale_line_by_rectangle_clip dlg, line, opts
    if next_text and next_text != line.text
      line.text = next_text
      subs[i] = line
      changed += 1
      reports[#reports + 1] = "#{Core.L('line')} #{i}: x #{Core.format_num(meta.fx * 100, 2)}%, y #{Core.format_num(meta.fy * 100, 2)}%"
    else
      skipped += 1
      reasons[err or "unchanged"] = (reasons[err or "unchanged"] or 0) + 1
  if changed == 0
    details = {}
    if current_language == "es"
      details[#details + 1] = "Esta operacion solo acepta \\clip(x1,y1,x2,y2) o \\iclip(x1,y1,x2,y2) rectangular."
      details[#details + 1] = "Los clips vectoriales se rechazan intencionalmente." if reasons.vector_clip
    else
      details[#details + 1] = "This operation only accepts rectangular \\clip(x1,y1,x2,y2) or \\iclip(x1,y1,x2,y2)."
      details[#details + 1] = "Vector clips are intentionally rejected." if reasons.vector_clip
    details[#details + 1] = Core.message_text("No rectangular clip was found.") if reasons.no_clip
    details[#details + 1] = Core.message_text("Text bounds could not be measured.") if reasons.no_text
    Core.show_message table.concat(details, "\n"), "Rescale by rectangle clip"
    return false
  aegisub.set_undo_point "Cliptomaniac - Rescale by rectangle clip"
  if opts.info
    summary = if current_language == "es" then "Cambiadas #{changed} línea(s), omitidas #{skipped}." else "Changed #{changed} line(s), skipped #{skipped}."
    summary ..= "\n\n" .. table.concat(reports, "\n") if #reports > 0
    Core.show_message summary, "Rescale by rectangle clip"
  true

Core.op_frz_lerp_stops = (subs, sel, opts) ->
  ref1, ref2 = Core.clip_scale_reference subs, sel
  ref_cmds = nil
  ref_cmds = Core.first_clip_path_reference subs, sel if opts.curve_source != "Two guide strokes"
  changed = 0
  for i in *Core.dialogue_indices(subs, sel)
    line = subs[i]
    cmds = Core.first_clip_commands line.text
    next_text = nil
    if opts.curve_source != "Two guide strokes"
      next_text = Core.frz_tangent_stops_text line, cmds or ref_cmds, opts
    if not next_text and opts.curve_source != "Path tangents"
      segs = cmds and Core.first_path_segments(cmds, 2, 8) or {}
      seg1 = segs[1] or ref1
      seg2 = segs[2] or ref2
      next_text = Core.frz_lerp_stops_text line, seg1, seg2, opts if seg1 and seg2
    continue unless next_text
    if next_text != line.text
      line.text = next_text
      subs[i] = line
      changed += 1
  if changed == 0
    Core.show_message "No line received FRZ stops."
    return false
  aegisub.set_undo_point "Cliptomaniac - FRZ stops"
  true

Core.position_text_at = (text, x, y) ->
  text = Core.remove_tag_names text, {"move"}
  Core.replace_pos_or_insert text, x, y

Core.op_position_at_clip_midpoint = (subs, sel, opts) ->
  _cmds, guide_span = Core.first_clip_path_reference subs, sel
  fallback = Core.clip_midpoint_from_span guide_span
  unless fallback
    Core.show_message "No usable clip midpoint found."
    return false
  changed = 0
  for i in *Core.dialogue_indices(subs, sel)
    line = subs[i]
    point = Core.clip_midpoint_for_line line, fallback
    continue unless point
    next_text = Core.position_text_at line.text or "", point.x, point.y
    if next_text != line.text
      line.text = next_text
      subs[i] = line
      changed += 1
  if changed == 0
    Core.show_message "No line position changed."
    return false
  aegisub.set_undo_point "Cliptomaniac - Position at clip midpoint"
  true

Core.first_segment_for_line = (line) ->
  cmds = Core.first_clip_commands line.text
  return nil unless cmds
  segs = Core.first_path_segments cmds, 1, 8
  segs[1]

Core.replace_or_insert_parenthesized_tag = (text, name, payload) ->
  replaced = false
  new_text = Core.map_override_blocks text, (inner) ->
    return inner if replaced
    i = 1
    while i <= #inner
      if inner\sub(i, i) == "\\"
        tag_name = Core.tag_name_at inner, i
        if tag_name
          value_pos = i + 1 + #tag_name
          if inner\sub(value_pos, value_pos) == "("
            close = Core.balanced_paren_end inner, value_pos
            if tag_name == name and close
              replaced = true
              return inner\sub(1, i - 1) .. payload .. inner\sub(close + 1)
            i = (close or value_pos) + 1
            continue
      i += 1
    inner
  return new_text if replaced
  Core.insert_leading_tags text, payload

Core.replace_pos_or_insert = (text, x, y) ->
  tag = "\\pos(" .. Core.format_num(x, 2) .. "," .. Core.format_num(y, 2) .. ")"
  Core.replace_or_insert_parenthesized_tag text, "pos", tag

Core.first_pos_xy = (text) ->
  for block in *Core.override_block_spans text
    continue unless Core.looks_like_override block.inner
    x, y = block.inner\match "\\pos%(%s*(" .. NUM_PATTERN .. ")%s*,%s*(" .. NUM_PATTERN .. ")%s*%)"
    return tonumber(x), tonumber(y) if x and y
  nil, nil

Core.replace_first_pos_with_move = (text, move_tag) ->
  replaced = false
  out = Core.map_override_blocks text, (inner) ->
    return inner if replaced
    next_inner, count = inner\gsub "\\pos%b()", move_tag, 1
    if count > 0
      replaced = true
      next_inner
    else
      inner
  out, replaced

Core.shift_pair = (x, y, dx, dy) ->
  Core.format_num((tonumber(x) or 0) + dx, 2), Core.format_num((tonumber(y) or 0) + dy, 2)

Core.shift_path = (path, dx, dy) ->
  tostring(path or "")\gsub "(" .. NUM_PATTERN .. ")%s+(" .. NUM_PATTERN .. ")", (x, y) ->
    nx, ny = Core.shift_pair x, y, dx, dy
    nx .. " " .. ny

Core.shift_geometry_text = (text, dx, dy) ->
  text = tostring(text or "")
  text = Core.map_override_blocks text, (inner) ->
    inner = inner\gsub "\\pos%(%s*(" .. NUM_PATTERN .. ")%s*,%s*(" .. NUM_PATTERN .. ")%s*%)", (x, y) ->
      nx, ny = Core.shift_pair x, y, dx, dy
      "\\pos(#{nx},#{ny})"
    inner = inner\gsub "\\move%(%s*(" .. NUM_PATTERN .. ")%s*,%s*(" .. NUM_PATTERN .. ")%s*,%s*(" .. NUM_PATTERN .. ")%s*,%s*(" .. NUM_PATTERN .. ")(.-)%)", (x1, y1, x2, y2, rest) ->
      nx1, ny1 = Core.shift_pair x1, y1, dx, dy
      nx2, ny2 = Core.shift_pair x2, y2, dx, dy
      "\\move(#{nx1},#{ny1},#{nx2},#{ny2}#{rest})"
    inner\gsub "\\org%(%s*(" .. NUM_PATTERN .. ")%s*,%s*(" .. NUM_PATTERN .. ")%s*%)", (x, y) ->
      nx, ny = Core.shift_pair x, y, dx, dy
      "\\org(#{nx},#{ny})"
  Core.map_clip_tags text, (span) ->
    kind, scale, payload = Core.clip_inner_parts span.inner
    if kind == "rect"
      b = Core.pad_bounds(payload, 0)
      "\\#{span.name}(#{Core.format_num b[1] + dx, 2},#{Core.format_num b[2] + dy, 2},#{Core.format_num b[3] + dx, 2},#{Core.format_num b[4] + dy, 2})"
    elseif kind == "vector"
      "\\#{span.name}(#{Core.vector_inner_with_scale(Core.shift_path(payload, dx, dy), scale)})"
    else
      span.raw

Core.op_clip_to_frz = (subs, sel, opts) ->
  changed = 0
  for i in *Core.dialogue_indices(subs, sel)
    line = subs[i]
    seg = Core.first_segment_for_line line
    continue unless seg
    text = Core.replace_or_insert_numeric_tag line.text, "frz", Core.segment_frz(seg)
    text = Core.strip_clip_tags text if opts.remove_clip
    if text != line.text
      line.text = text
      subs[i] = line
      changed += 1
  if changed == 0
    Core.show_message "No usable vector clip found."
    return false
  aegisub.set_undo_point "Cliptomaniac - Clip to FRZ"
  true

Core.op_clip_to_fax = (subs, sel, opts) ->
  changed = 0
  for i in *Core.dialogue_indices(subs, sel)
    line = subs[i]
    seg = Core.first_segment_for_line line
    continue unless seg
    state = Core.effective_line_state line
    frz = Core.line_tag_value(line, "frz", "angle", 0, state) or 0
    scx = Core.line_tag_value(line, "fscx", "scale_x", 100, state) or 100
    scy = Core.line_tag_value(line, "fscy", "scale_y", 100, state) or 100
    ratio = if scy == 0 then 1 else scx / scy
    line_angle = Core.segment_frz seg
    fax = math.tan(math.rad(line_angle - frz)) / ratio
    unless Core.finite_number(fax) and math.abs(fax) <= 100
      Core.warn "Line #{i}: skipped unstable FAX value from angle #{Core.format_num(line_angle - frz, 2)}."
      continue
    text = Core.replace_or_insert_numeric_tag line.text, "fax", fax
    text = Core.strip_clip_tags text if opts.remove_clip
    if text != line.text
      line.text = text
      subs[i] = line
      changed += 1
  if changed == 0
    Core.show_message "No usable vector clip found."
    return false
  aegisub.set_undo_point "Cliptomaniac - Clip to FAX"
  true

Core.op_clip_to_fay = (subs, sel, opts) ->
  changed = 0
  for i in *Core.dialogue_indices(subs, sel)
    line = subs[i]
    seg = Core.first_segment_for_line line
    continue unless seg
    state = Core.effective_line_state line
    frz = Core.line_tag_value(line, "frz", "angle", 0, state) or 0
    scx = Core.line_tag_value(line, "fscx", "scale_x", 100, state) or 100
    scy = Core.line_tag_value(line, "fscy", "scale_y", 100, state) or 100
    ratio = if scy == 0 then 1 else scx / scy
    line_angle = Core.segment_frz seg
    fay = math.tan(math.rad(line_angle + 90 - frz)) * ratio
    unless Core.finite_number(fay) and math.abs(fay) <= 100
      Core.warn "Line #{i}: skipped unstable FAY value from angle #{Core.format_num(line_angle + 90 - frz, 2)}."
      continue
    text = Core.replace_or_insert_numeric_tag line.text, "fay", fay
    text = Core.strip_clip_tags text if opts.remove_clip
    if text != line.text
      line.text = text
      subs[i] = line
      changed += 1
  if changed == 0
    Core.show_message "No usable vector clip found."
    return false
  aegisub.set_undo_point "Cliptomaniac - Clip to FAY"
  true

Core.op_clip_to_reposition = (subs, sel, opts) ->
  changed = 0
  for i in *Core.dialogue_indices(subs, sel)
    line = subs[i]
    seg = Core.first_segment_for_line line
    continue unless seg
    dx, dy = seg.x2 - seg.x1, seg.y2 - seg.y1
    text = Core.shift_geometry_text line.text, dx, dy
    text = Core.strip_clip_tags text if opts.remove_clip
    if text != line.text
      line.text = text
      subs[i] = line
      changed += 1
  if changed == 0
    Core.show_message "No position or clip geometry changed."
    return false
  aegisub.set_undo_point "Cliptomaniac - Clip to reposition"
  true

Core.op_clip_to_move = (subs, sel, opts) ->
  changed = 0
  for i in *Core.dialogue_indices(subs, sel)
    line = subs[i]
    seg = Core.first_segment_for_line line
    continue unless seg
    x, y = Core.first_pos_xy line.text
    continue unless x and y
    dx, dy = seg.x2 - seg.x1, seg.y2 - seg.y1
    move = "\\move(#{Core.format_num x, 2},#{Core.format_num y, 2},#{Core.format_num x + dx, 2},#{Core.format_num y + dy, 2})"
    text = Core.remove_tag_names line.text, {"move"}
    text = Core.replace_first_pos_with_move text, move
    text = Core.strip_clip_tags text if opts.remove_clip
    if text != line.text
      line.text = text
      subs[i] = line
      changed += 1
  if changed == 0
    Core.show_message "No selected line had both \\pos and a usable clip segment."
    return false
  aegisub.set_undo_point "Cliptomaniac - Clip to move"
  true

Core.op_align_to_clip = (subs, sel, opts) ->
  global_cmds = nil
  for i in *Core.dialogue_indices(subs, sel)
    global_cmds = Core.first_clip_commands subs[i].text
    break if global_cmds
  unless global_cmds
    Core.show_message "No vector clip found for alignment."
    return false
  global_segments = Core.path_segments global_cmds, 40
  changed = 0
  for i in *Core.dialogue_indices(subs, sel)
    line = subs[i]
    px, py = Core.first_pos_xy line.text
    continue unless px and py
    local_cmds = Core.first_clip_commands line.text
    segments = if local_cmds then Core.path_segments(local_cmds, 40) else global_segments
    segments = global_segments if #segments == 0
    best_dist, best_x, best_y = math.huge, px, py
    for seg in *segments
      d, bx, by = Core.distance_to_segment px, py, seg.x1, seg.y1, seg.x2, seg.y2
      if d < best_dist
        best_dist, best_x, best_y = d, bx, by
    if best_dist < math.huge
      line.text = Core.position_text_at line.text, best_x, best_y
      subs[i] = line
      changed += 1
  if changed == 0
    Core.show_message "No selected line with \\pos could be aligned."
    return false
  aegisub.set_undo_point "Cliptomaniac - Align to clip"
  true

Core.clip_vector_parts_for_output = (span) ->
  kind, scale, payload = Core.clip_inner_parts span.inner
  return kind, payload, scale

Core.hotkey_text = (text, op, opts = {}) ->
  Core.map_clip_tags text, (span) ->
    kind, payload, scale = Core.clip_vector_parts_for_output span
    switch op
      when "Toggle clip/iclip"
        Core.clip_tag_text span.name == "clip" and "iclip" or "clip", span.inner
      when "Calibrate clip X"
        return span.raw unless kind == "vector"
        path = tostring(payload or "")\gsub "([mM])%s+(" .. NUM_PATTERN .. ")%s+(" .. NUM_PATTERN .. ")%s+([lL])%s+(" .. NUM_PATTERN .. ")%s+(" .. NUM_PATTERN .. ")", (m, x1, y1, l, x2, y2) ->
          "#{m} #{Core.format_num x1} #{Core.format_num y1} #{l} #{Core.format_num x2} #{Core.format_num y1}"
        Core.clip_tag_text span.name, Core.vector_inner_with_scale(path, scale)
      when "Calibrate clip Y"
        return span.raw unless kind == "vector"
        path = tostring(payload or "")\gsub "([mM])%s+(" .. NUM_PATTERN .. ")%s+(" .. NUM_PATTERN .. ")%s+([lL])%s+(" .. NUM_PATTERN .. ")%s+(" .. NUM_PATTERN .. ")", (m, x1, y1, l, x2, y2) ->
          "#{m} #{Core.format_num x1} #{Core.format_num y1} #{l} #{Core.format_num x1} #{Core.format_num y2}"
        Core.clip_tag_text span.name, Core.vector_inner_with_scale(path, scale)
      when "Rectangle from diagonal"
        return span.raw unless kind == "vector"
        segs = Core.first_path_segments(Core.parse_draw_commands(payload), 1, 1)
        return span.raw unless segs[1]
        s = segs[1]
        path = "m #{Core.format_num s.x1} #{Core.format_num s.y1} l #{Core.format_num s.x2} #{Core.format_num s.y1} #{Core.format_num s.x2} #{Core.format_num s.y2} #{Core.format_num s.x1} #{Core.format_num s.y2}"
        Core.clip_tag_text span.name, Core.vector_inner_with_scale(path, scale)
      when "Circle from 2 points"
        return span.raw unless kind == "vector"
        segs = Core.first_path_segments(Core.parse_draw_commands(payload), 1, 1)
        return span.raw unless segs[1]
        s = segs[1]
        cx, cy = (s.x1 + s.x2) / 2, (s.y1 + s.y2) / 2
        r = Core.segment_length(s) / 2
        return span.raw if r <= 0
        k = 0.5522847498307936
        path = table.concat {
          "m #{Core.format_num cx - r} #{Core.format_num cy}"
          "b #{Core.format_num cx - r} #{Core.format_num cy - k * r} #{Core.format_num cx - k * r} #{Core.format_num cy - r} #{Core.format_num cx} #{Core.format_num cy - r}"
          "b #{Core.format_num cx + k * r} #{Core.format_num cy - r} #{Core.format_num cx + r} #{Core.format_num cy - k * r} #{Core.format_num cx + r} #{Core.format_num cy}"
          "b #{Core.format_num cx + r} #{Core.format_num cy + k * r} #{Core.format_num cx + k * r} #{Core.format_num cy + r} #{Core.format_num cx} #{Core.format_num cy + r}"
          "b #{Core.format_num cx - k * r} #{Core.format_num cy + r} #{Core.format_num cx - r} #{Core.format_num cy + k * r} #{Core.format_num cx - r} #{Core.format_num cy}"
        }, " "
        Core.clip_tag_text span.name, Core.vector_inner_with_scale(path, scale)
      when "New clip shape"
        return span.raw unless kind == "vector"
        path = Core.new_shape_split_path payload
        return span.raw unless path
        Core.clip_tag_text span.name, Core.vector_inner_with_scale(path, scale)
      when "Add clip points"
        path = if kind == "rect" then Core.vector_clip_inner(Core.rect_points(payload)) else payload
        return span.raw unless path
        path, added = Core.densify_clip_path path, opts
        return span.raw unless path and added > 0
        Core.clip_tag_text span.name, Core.vector_inner_with_scale(path, scale)
      when "Remove clip points"
        path = if kind == "rect" then Core.vector_clip_inner(Core.rect_points(payload)) else payload
        return span.raw unless path
        path, changed = Core.remove_alternate_clip_points_path path
        return span.raw unless path and changed
        Core.clip_tag_text span.name, Core.vector_inner_with_scale(path, scale)
      when "Rect clip to vector"
        return span.raw unless kind == "rect"
        b = Core.normalize_bounds payload
        Core.clip_tag_text span.name, Core.vector_clip_inner Core.rect_points b
      when "Vector clip to rect"
        bounds = Core.clip_bounds_from_span span
        return span.raw unless bounds
        Core.rect_clip_tag bounds, span.name
      else
        span.raw

Core.op_hotkey = (subs, sel, op, opts = {}) ->
  changed = 0
  for i in *Core.dialogue_indices(subs, sel)
    line = subs[i]
    next_text, c = Core.hotkey_text line.text, op, opts
    if c > 0 and next_text != line.text
      line.text = next_text
      subs[i] = line
      changed += 1
  if changed == 0
    if op == "Add clip points" or op == "Remove clip points"
      Core.show_message "No clip points changed."
      return false
    Core.show_message "No editable clip found."
    return false
  aegisub.set_undo_point "Cliptomaniac - #{op}"
  true

Core.selection_copy_groups = (subs, sel) ->
  groups, order = {}, {}
  for i in *(sel or {})
    line = subs[i]
    if Core.is_dialogue line
      key = "effect:" .. Core.trim(line.effect or "")
      group = groups[key]
      unless group
        group = {source: i, targets: {}, indices: {i}}
        groups[key] = group
        order[#order + 1] = group
      else
        group.targets[#group.targets + 1] = i
        group.indices[#group.indices + 1] = i
  usable = {}
  for group in *order
    usable[#usable + 1] = group if #group.targets > 0
  if #usable == 0
    indices = Core.dialogue_indices subs, sel
    if #indices >= 2
      targets = {}
      for n = 2, #indices
        targets[#targets + 1] = indices[n]
      usable[1] = {source: indices[1], targets: targets, indices: indices}
  usable

Core.replace_first_clip = (text, replacement) ->
  span = Core.first_clip_span text
  if span
    return text\sub(1, span.start - 1) .. replacement .. text\sub(span.stop + 1)
  Core.insert_leading_tags text, replacement

Core.op_copy_clip = (subs, sel, opts) ->
  changed = 0
  for group in *Core.selection_copy_groups(subs, sel)
    src = subs[group.source]
    span = src and Core.first_clip_span(src.text)
    continue unless span
    for i in *group.targets
      line = subs[i]
      next_text = Core.replace_first_clip line.text or "", span.raw
      if next_text != line.text
        line.text = next_text
        subs[i] = line
        changed += 1
  if changed == 0
    Core.show_message "No source/target clip group found."
    return false
  aegisub.set_undo_point "Cliptomaniac - Copy clip"
  true

Core.shape_info = (drawing) ->
  return nil, "Shape tools are not available." unless ZF and ZF.shape
  ok, shape = pcall -> ZF.shape drawing
  return nil, tostring(shape) unless ok and shape
  return nil, "Empty shape." unless shape.w and shape.h and shape.w > 0 and shape.h > 0
  shape

Core.bounds_from_path = (drawing) ->
  Core.clip_bounds_from_span {inner: drawing, name: "clip"}

Core.shape_bounds = (shape, drawing = nil) ->
  return nil unless shape
  l, t = tonumber(shape.l), tonumber(shape.t)
  r, b = tonumber(shape.r), tonumber(shape.b)
  w, h = tonumber(shape.w), tonumber(shape.h)
  if l and t and r and b
    return Core.normalize_bounds {l, t, r, b}
  if l and t and w and h
    return Core.normalize_bounds {l, t, l + w, t + h}
  if drawing
    return Core.bounds_from_path drawing
  nil

Core.build_shape_text = (shape) ->
  Core.trim shape\build!

Core.move_drawing = (drawing, dx, dy) ->
  shape, err = Core.shape_info drawing
  return nil, err unless shape
  Core.build_shape_text shape\move(dx or 0, dy or 0)

Core.scale_path_from_center = (path, margin) ->
  bounds = Core.clip_bounds_from_span {inner: path, name: "clip"}
  return path unless bounds
  left, top, right, bottom = unpack bounds
  cx, cy = (left + right) / 2, (top + bottom) / 2
  half_w, half_h = math.max((right - left) / 2, 0.001), math.max((bottom - top) / 2, 0.001)
  fx, fy = (half_w + margin) / half_w, (half_h + margin) / half_h
  tostring(path or "")\gsub "(" .. NUM_PATTERN .. ")%s+(" .. NUM_PATTERN .. ")", (x, y) ->
    x, y = tonumber(x), tonumber(y)
    "#{Core.format_num cx + (x - cx) * fx} #{Core.format_num cy + (y - cy) * fy}"

Core.expand_vector_path = (path, margin, tolerance) ->
  if ZF and ZF.clipper
    ok, expanded = pcall ->
      ZF.clipper(path, nil, true)\offset(margin, "Miter", nil, 2, 0.25)\build "line", math.max(1, tonumber(tolerance) or 1)
    return Core.trim expanded if ok and expanded and Core.trim(expanded) != ""
  Core.scale_path_from_center path, margin

Core.simplify_vector_path = (path, tolerance, close_paths = true) ->
  tolerance = math.max 1, tonumber(tolerance) or 1
  return Core.trim path if tolerance <= 1 or not (ZF and ZF.clipper)
  ok, simplified = pcall -> ZF.clipper(path, nil, close_paths)\simplify!\build "line", tolerance
  if ok and simplified and Core.trim(simplified) != "" then Core.trim simplified else Core.trim path

Core.op_expand_clip_margin = (subs, sel, opts) ->
  margin = tonumber(opts.margin) or 0
  changed = 0
  for i in *Core.dialogue_indices(subs, sel)
    line = subs[i]
    next_text, c = Core.map_clip_tags line.text, (span) ->
      kind, scale, payload = Core.clip_inner_parts span.inner
      if kind == "rect"
        Core.rect_clip_tag Core.pad_bounds(payload, margin), span.name
      elseif kind == "vector"
        Core.clip_tag_text span.name, Core.vector_inner_with_scale(Core.expand_vector_path(payload, margin, opts.tolerance), scale)
      else
        span.raw
    if c > 0 and next_text != line.text
      line.text = next_text
      subs[i] = line
      changed += 1
  if changed == 0
    Core.show_message "No clip was expanded."
    return false
  aegisub.set_undo_point "Cliptomaniac - Expand clip margin"
  true

Core.build_text_bounds = (dlg, source_line, opts) ->
  return nil unless ZF
  prepared = Core.prepare_zf_text_line dlg, source_line
  line, call, pers, align = prepared.work, prepared.call, prepared.pers, prepared.align
  return nil unless pers and pers.pos
  px, py = pers.pos[1], pers.pos[2]
  shape = ZF.util\isShape line.text
  unless shape
    shape = call\toShape dlg, align, px, py
    if line.styleref
      line.styleref.scale_x = 100
      line.styleref.scale_y = 100
  return nil unless shape
  expanded = ZF.shape(shape, true)\setPosition(align)\expand(line, pers)\move(px, py)\build!
  simplified = Core.trim ZF.clipper(expanded)\simplify!\build "line", math.max(1, tonumber(opts.tolerance) or 1)
  shape_info = Core.shape_info simplified
  return nil unless shape_info
  bounds = Core.shape_bounds shape_info, simplified
  return nil unless bounds
  {
    l: bounds[1]
    t: bounds[2]
    r: bounds[3]
    b: bounds[4]
    w: bounds[3] - bounds[1]
    h: bounds[4] - bounds[2]
    align: prepared.source_align
    shape: shape_info
    path: simplified
  }

Core.shape_outline_path = (dlg, source_line, opts = {}) ->
  return nil unless ZF
  prepared = Core.prepare_zf_text_line dlg, source_line, opts.drop_clip != false
  work, call, pers, align = prepared.work, prepared.call, prepared.pers, prepared.align
  return nil unless pers and pers.pos
  px, py = pers.pos[1], pers.pos[2]
  shape = ZF.util\isShape work.text
  unless shape
    shape = call\toShape dlg, align, px, py
    if work.styleref
      work.styleref.scale_x = 100
      work.styleref.scale_y = 100
  return nil unless shape
  close_paths = opts.close_paths != false
  path = Core.trim ZF.shape(shape, close_paths)\setPosition(align)\expand(work, pers)\move(px, py)\build!
  margin = tonumber(opts.margin) or 0
  path = Core.expand_vector_path path, margin, opts.tolerance if math.abs(margin) > 0.0005
  Core.simplify_vector_path path, opts.tolerance, close_paths

Core.style_safe_pad = (line) ->
  state = Core.effective_line_state line
  bord = Core.line_tag_value(line, "bord", "outline", 0, state) or 0
  xbord = Core.line_tag_value(line, "xbord", nil, bord, state) or bord
  ybord = Core.line_tag_value(line, "ybord", nil, bord, state) or bord
  shad = Core.line_tag_value(line, "shad", "shadow", 0, state) or 0
  xshad = Core.line_tag_value(line, "xshad", nil, shad, state) or shad
  yshad = Core.line_tag_value(line, "yshad", nil, shad, state) or shad
  blur = Core.line_tag_value(line, "blur", nil, 0, state) or 0
  math.max(bord, xbord, ybord) + math.max(math.abs(shad), math.abs(xshad), math.abs(yshad)) + math.abs(blur) * 2

Core.section_from_mode = (mode, opts, old_bounds, text_bounds) ->
  switch mode
    when "Left/top half" then return 2, 1
    when "Right/bottom half" then return 2, 2
    when "Left/top third" then return 3, 1
    when "Center third" then return 3, 2
    when "Right/bottom third" then return 3, 3
    when "Custom section"
      sections = math.max 1, opts.sections
      return sections, Core.clamp opts.section_index, 1, sections
    when "Auto by position"
      sections = math.max 1, opts.sections
      tb = Core.normalize_bounds text_bounds
      ob = Core.normalize_bounds old_bounds
      if opts.strip_mode == "Vertical"
        span = tb[4] - tb[2]
        return sections, 1 if span <= 0
        center = (ob[2] + ob[4]) / 2
        return sections, Core.clamp(math.floor(Core.clamp((center - tb[2]) / span, 0, 0.999999) * sections) + 1, 1, sections)
      span = tb[3] - tb[1]
      return sections, 1 if span <= 0
      center = (ob[1] + ob[3]) / 2
      return sections, Core.clamp(math.floor(Core.clamp((center - tb[1]) / span, 0, 0.999999) * sections) + 1, 1, sections)
  1, 1

Core.section_bounds = (bounds, sections, index, opts, margin) ->
  bounds = Core.normalize_bounds bounds
  return Core.pad_bounds bounds, margin if sections <= 1
  left, top, right, bottom = unpack bounds
  index = Core.clamp index, 1, sections
  bleed = math.max 0, tonumber(opts.bleed) or 0
  if opts.strip_mode == "Vertical"
    height = bottom - top
    y1 = top + height * (index - 1) / sections
    y2 = top + height * index / sections
    y1 -= if index == 1 then margin else bleed
    y2 += if index == sections then margin else bleed
    return {left - margin, y1, right + margin, y2}
  width = right - left
  x1 = left + width * (index - 1) / sections
  x2 = left + width * index / sections
  x1 -= if index == 1 then margin else bleed
  x2 += if index == sections then margin else bleed
  {x1, top - margin, x2, bottom + margin}

Core.safe_strip_size = (strip) ->
  Core.clamp tonumber(strip) or DEFAULTS.strip, 1, 1000

Core.layout_scale_for_line = (line) ->
  collection = line and line.parentCollection
  meta = collection and collection.meta or {}
  play_y = tonumber(meta.PlayResY or meta.playresy or meta.res_y)
  layout_y = tonumber(meta.LayoutResY or meta.layoutresy)
  unless layout_y
    if aegisub and type(aegisub.video_size) == "function"
      ok, _video_x, video_y = pcall aegisub.video_size
      layout_y = tonumber(video_y) if ok
  return play_y / layout_y if play_y and layout_y and layout_y != 0
  1

Core.matrix_point = (point) ->
  return nil unless point
  x, y = tonumber(point.x), tonumber(point.y)
  if x == nil and type(point) == "table"
    x = tonumber point[1]
  if y == nil and type(point) == "table"
    y = tonumber point[2]
  if (x == nil or y == nil) and type(point) == "table"
    unless x
      ok_x, value_x = pcall -> point\x!
      x = tonumber value_x if ok_x
    unless y
      ok_y, value_y = pcall -> point\y!
      y = tonumber value_y if ok_y
  return nil unless x and y and Core.finite_number(x) and Core.finite_number(y)
  {:x, :y}

Core.project_local_points = (tags, width, height, points, layout_scale) ->
  return nil unless ArchPerspective and ArchPerspective.transformPoints
  source = [{point.x, point.y} for point in *points]
  ok, projected = pcall -> ArchPerspective.transformPoints tags, width, height, source, layout_scale
  return nil unless ok and projected
  out = {}
  for i = 1, #points
    point = Core.matrix_point projected[i]
    return nil unless point
    out[#out + 1] = point
  out

Core.normalize_vector = (x, y) ->
  length = math.sqrt x * x + y * y
  return {x: 0, y: 0} if length < 0.0005
  {x: x / length, y: y / length}

Core.outward_edge_normal = (a, b) ->
  Core.normalize_vector b.y - a.y, -(b.x - a.x)

Core.offset_edge = (a, b, amount) ->
  normal = Core.outward_edge_normal a, b
  {
    {x: a.x + normal.x * amount, y: a.y + normal.y * amount}
    {x: b.x + normal.x * amount, y: b.y + normal.y * amount}
  }

Core.line_intersection = (a1, a2, b1, b2) ->
  dax, day = a2.x - a1.x, a2.y - a1.y
  dbx, dby = b2.x - b1.x, b2.y - b1.y
  denominator = dax * dby - day * dbx
  return nil if math.abs(denominator) < 0.0005
  t = ((b1.x - a1.x) * dby - (b1.y - a1.y) * dbx) / denominator
  {x: a1.x + dax * t, y: a1.y + day * t}

Core.expand_quad_screen = (quad, margin) ->
  return quad unless quad and #quad >= 4
  margin = tonumber(margin) or 0
  return quad if math.abs(margin) < 0.0005
  edges = {}
  for i = 1, 4
    next_i = i == 4 and 1 or i + 1
    edges[i] = Core.offset_edge quad[i], quad[next_i], margin
  expanded = {}
  for i = 1, 4
    prev_i = i == 1 and 4 or i - 1
    point = Core.line_intersection edges[prev_i][1], edges[prev_i][2], edges[i][1], edges[i][2]
    unless point
      prev_normal = Core.outward_edge_normal quad[prev_i], quad[i]
      next_i = i == 4 and 1 or i + 1
      next_normal = Core.outward_edge_normal quad[i], quad[next_i]
      point = {
        x: quad[i].x + prev_normal.x * margin + next_normal.x * margin
        y: quad[i].y + prev_normal.y * margin + next_normal.y * margin
      }
    expanded[i] = point
  expanded

Core.line_needs_projected_quad = (line) ->
  text = if line then tostring(line.text or "") else ""
  return true if text\find "\\p[1-9]"
  state = Core.effective_line_state line
  angle = Core.line_tag_value line, "frz", nil, nil, state
  angle = Core.line_tag_value(line, "fr", "angle", 0, state) if angle == nil
  return true if math.abs(tonumber(angle) or 0) > 0.000001
  for tag in *{"frx", "fry", "fax", "fay"}
    value = Core.line_tag_value line, tag, nil, 0, state
    return true if math.abs(tonumber(value) or 0) > 0.000001
  false

Core.baked_geometry_tags = ->
  {"p", "an", "fscx", "fscy", "pos", "move", "org", "frx", "fry", "frz", "fr", "fax", "fay", "t"}

Core.drawing_local_bounds = (data) ->
  return nil unless data and data.callback and ASS and ASS.Section and ASS.Section.Drawing
  left, top, right, bottom = nil, nil, nil, nil
  ok = pcall ->
    data\callback (section) ->
      is_drawing = section and ((section.instanceOf and section.instanceOf[ASS.Section.Drawing]) or section.class == ASS.Section.Drawing)
      return unless is_drawing and section.getExtremePoints
      ok_ext, ext = pcall -> section\getExtremePoints true
      return unless ok_ext and ext
      if ext.left and ext.top and ext.right and ext.bottom
        l, t = tonumber(ext.left.x), tonumber(ext.top.y)
        r, b = tonumber(ext.right.x), tonumber(ext.bottom.y)
        if l and t and r and b
          left = l if not left or l < left
          top = t if not top or t < top
          right = r if not right or r > right
          bottom = b if not bottom or b > bottom
      elseif ext.x and ext.y and ext.w and ext.h
        l, t, r, b = tonumber(ext.x), tonumber(ext.y), tonumber(ext.x + ext.w), tonumber(ext.y + ext.h)
        if l and t and r and b
          left = l if not left or l < left
          top = t if not top or t < top
          right = r if not right or r > right
          bottom = b if not bottom or b > bottom
  return nil unless ok and left and top and right and bottom
  Core.normalize_bounds {left, top, right, bottom}

Core.projected_text_quad = (line, opts = {}) ->
  return nil unless ArchPerspective and ArchPerspective.transformPoints
  return nil unless Core.line_needs_projected_quad line
  data, tags, width, height = nil, nil, nil, nil
  ok_parse, parsed = pcall -> Core.parse_ass_line line
  data = parsed if ok_parse
  if data and ArchPerspective.prepareForPerspective
    ok_prep, ptags, pwidth, pheight = pcall -> ArchPerspective.prepareForPerspective ASS, data
    pwidth, pheight = tonumber(pwidth), tonumber(pheight)
    if ok_prep and ptags and PerspectiveTools and PerspectiveTools.valid_dim(pwidth) and PerspectiveTools.valid_dim(pheight)
      tags, width, height = ptags, pwidth, pheight
      if PerspectiveTools and PerspectiveTools.needs_extent_override(line, width, height)
        mw, mh = PerspectiveTools.text_extents line, tags
        if PerspectiveTools.valid_dim(mw) and PerspectiveTools.valid_dim(mh)
          width, height = mw, mh
  unless tags and PerspectiveTools and PerspectiveTools.valid_dim(width) and PerspectiveTools.valid_dim(height)
    if PerspectiveTools and PerspectiveTools.prepare
      tags, width, height = PerspectiveTools.prepare line
  return nil unless tags and PerspectiveTools and PerspectiveTools.valid_dim(width) and PerspectiveTools.valid_dim(height)
  bounds = (data and Core.drawing_local_bounds(data)) or {0, 0, width, height}
  quad = Core.project_local_points tags, width, height, Core.rect_points(bounds), Core.layout_scale_for_line(line)
  return nil unless quad and #quad == 4
  margin = tonumber(opts.margin) or 0
  margin += Core.style_safe_pad line if opts.style_pad
  Core.expand_quad_screen quad, margin

Core.text_area_clip_tag = (dlg, line, opts = {}) ->
  if quad = Core.projected_text_quad line, opts
    return Core.vector_clip_tag quad
  return nil unless dlg
  ok, shape = pcall -> Core.build_text_bounds dlg, line, opts
  return nil unless ok and shape
  margin = tonumber(opts.margin) or 0
  margin += Core.style_safe_pad line if opts.style_pad
  Core.rect_clip_tag Core.pad_bounds({shape.l, shape.t, shape.l + shape.w, shape.t + shape.h}, margin)

Core.replace_or_insert_clip = (text, clip_tag, replace_existing = true) ->
  span = Core.first_clip_span text
  if span and replace_existing
    text\sub(1, span.start - 1) .. clip_tag .. text\sub(span.stop + 1)
  else
    Core.insert_leading_tags text, clip_tag

Core.op_autofit_clip = (subs, sel, active, opts) ->
  unless ZF
    Core.show_message "Text outline tools are not available."
    return false
  dlg = ZF.dialog subs, sel, active, false
  changed = 0
  for i in *Core.dialogue_indices(subs, sel)
    line = subs[i]
    span = Core.first_clip_span line.text
    continue unless span
    old_bounds = Core.clip_bounds_from_span span
    continue unless old_bounds
    ok, shape_or_err = pcall -> Core.build_text_bounds dlg, line, opts
    continue unless ok and shape_or_err
    sh = shape_or_err
    text_bounds = {sh.l, sh.t, sh.l + sh.w, sh.t + sh.h}
    margin = tonumber(opts.margin) or 0
    margin += Core.style_safe_pad line if opts.style_pad
    sections, index = Core.section_from_mode opts.autofit_mode or "Whole text", opts, old_bounds, text_bounds
    target = Core.section_bounds text_bounds, sections, index, opts, margin
    target = Core.union_bounds target, old_bounds if opts.no_shrink
    repl = Core.rect_clip_tag target, span.name
    next_text = line.text\sub(1, span.start - 1) .. repl .. line.text\sub(span.stop + 1)
    if next_text != line.text
      line.text = next_text
      subs[i] = line
      changed += 1
  if changed == 0
    Core.show_message "No clip could be autofit."
    return false
  aegisub.set_undo_point "Cliptomaniac - Autofit clip"
  true

Core.op_create_text_clip = (subs, sel, active, opts) ->
  unless ZF or (ASS and ArchPerspective)
    Core.show_message "This action needs the text measuring tools."
    return false
  dlg = nil
  if ZF
    ok, value = pcall -> ZF.dialog subs, sel, active, false
    dlg = value if ok
  changed = 0
  for i in *Core.dialogue_indices(subs, sel)
    line = subs[i]
    clip_tag = Core.text_area_clip_tag dlg, line, opts
    continue unless clip_tag
    next_text = Core.replace_or_insert_clip line.text or "", clip_tag, opts.replace_clip
    if next_text != line.text
      line.text = next_text
      subs[i] = line
      changed += 1
  if changed == 0
    Core.show_message "No text area could be clipped."
    return false
  aegisub.set_undo_point "Cliptomaniac - Create clip around text"
  true

Core.clip_type_for_line = (line, opts = {}) ->
  requested = opts.clip_type or "Auto"
  return requested if requested == "clip" or requested == "iclip"
  span = Core.first_clip_span line.text
  if span and span.name == "iclip" then "iclip" else "clip"

Core.text_to_clip_text = (dlg, line, opts = {}) ->
  path = Core.shape_outline_path dlg, line, opts
  return nil unless path and path != ""
  clip_tag = Core.clip_tag_text Core.clip_type_for_line(line, opts), path
  Core.replace_or_insert_clip line.text or "", clip_tag, opts.replace_clip

Core.op_text_to_clip = (subs, sel, active, opts) ->
  unless ZF
    Core.show_message "Text outline tools are not available."
    return false
  dlg = ZF.dialog subs, sel, active, false
  changed, inserted_offset = 0, 0
  for i in *Core.dialogue_indices(subs, sel)
    idx = i + inserted_offset
    source = subs[idx]
    ok, next_text = pcall -> Core.text_to_clip_text dlg, source, opts
    Core.warn "Line #{idx}: text to clip failed: #{next_text}" unless ok
    continue unless ok and next_text and next_text != source.text
    if opts.comment_source
      output = Core.copy_line source
      output.comment = false
      output.text = next_text
      source.comment = true
      subs[idx] = source
      subs.insert idx + 1, output
      inserted_offset += 1
    else
      source.text = next_text
      subs[idx] = source
    changed += 1
  if changed == 0
    Core.show_message "No text or drawing outline could be converted to a clip."
    return false
  aegisub.set_undo_point "Cliptomaniac - Text to clip"
  true

Core.shape_to_clip_line = (dlg, line) ->
  return nil unless ZF
  work = Core.copy_line line
  call = ZF.line(work)\prepoc dlg
  shape = ZF.util\isShape work.text
  return nil unless shape
  pers = dlg\getPerspectiveTags work
  return nil unless pers and pers.pos
  px, py = pers.pos[1], pers.pos[2]
  align = Core.zf_align_for_line work
  clip = ZF.shape(shape, true)\setPosition(align)\expand(work, pers)\move(px, py)\build!
  clip_tag = "\\clip(#{clip})"
  text = Core.strip_clip_tags work.text
  text = Core.remove_tag_names text, Core.baked_geometry_tags!
  text = Core.override_tags_only text
  Core.replace_or_insert_clip text, clip_tag, true

Core.clip_to_shape_text = (text) ->
  span = Core.first_clip_span text
  return nil unless span
  kind, _scale, payload = Core.clip_inner_parts span.inner
  drawing = if kind == "rect"
    Core.vector_clip_inner Core.rect_points payload
  elseif kind == "vector"
    payload
  else
    nil
  return nil unless drawing
  bounds = Core.clip_bounds_from_span span
  return nil unless bounds
  left, top = bounds[1], bounds[2]
  local_drawing = Core.move_drawing(drawing, -left, -top) or Core.shift_path(drawing, -left, -top)
  text = Core.strip_clip_tags text
  text = Core.remove_tag_names text, Core.baked_geometry_tags!
  text = Core.override_tags_only text
  Core.insert_leading_tags(text, "\\an7\\pos(#{Core.format_num left},#{Core.format_num top})\\fscx100\\fscy100\\p1") .. local_drawing

Core.op_shape_to_clip = (subs, sel, active, opts) ->
  unless ZF
    Core.show_message "Shape tools are not available."
    return false
  dlg = ZF.dialog subs, sel, active, false
  changed = 0
  for i in *Core.dialogue_indices(subs, sel)
    line = subs[i]
    ok, next_text = pcall -> Core.shape_to_clip_line dlg, line
    Core.warn "Line #{i}: shape to clip failed: #{next_text}" unless ok
    if next_text and next_text != line.text
      line.text = next_text
      subs[i] = line
      changed += 1
  if changed == 0
    Core.show_message "No drawing shape was converted to clip."
    return false
  aegisub.set_undo_point "Cliptomaniac - Shape to clip"
  true

Core.op_clip_to_shape = (subs, sel, opts) ->
  changed = 0
  for i in *Core.dialogue_indices(subs, sel)
    line = subs[i]
    next_text = Core.clip_to_shape_text line.text
    if next_text and next_text != line.text
      line.text = next_text
      subs[i] = line
      changed += 1
  if changed == 0
    Core.show_message "No clip was converted to shape."
    return false
  aegisub.set_undo_point "Cliptomaniac - Clip to shape"
  true

Core.op_extract_clip_as_mask = (subs, sel, opts) ->
  changed, inserted_offset = 0, 0
  for i in *Core.dialogue_indices(subs, sel)
    idx = i + inserted_offset
    source = subs[idx]
    next_text = Core.clip_to_shape_text source.text
    continue unless next_text
    output = Core.copy_line source
    output.comment = false
    output.text = next_text
    subs.insert idx + 1, output
    inserted_offset += 1
    changed += 1
  if changed == 0
    Core.show_message "No clip could be extracted as a mask line."
    return false
  aegisub.set_undo_point "Cliptomaniac - Extract clip as mask line"
  true

Core.clip_boolean_text = (dlg, line, opts = {}) ->
  return nil unless ZF and ZF.clipper
  span = Core.first_clip_span line.text
  return nil unless span
  kind, _scale, payload = Core.clip_inner_parts span.inner
  clip_path = if kind == "rect"
    Core.vector_clip_inner Core.rect_points payload
  elseif kind == "vector"
    payload
  else
    nil
  return nil unless clip_path
  shape_path = Core.shape_outline_path dlg, line, {
    margin: 0
    tolerance: opts.tolerance
    close_paths: opts.close_paths
    drop_clip: true
  }
  return nil unless shape_path and shape_path != ""
  inverse = opts.boolean_mode == "Cut text from clip"
  ok, result = pcall -> ZF.clipper(clip_path, shape_path, opts.close_paths != false)\clip(inverse)\build "line", math.max(1, tonumber(opts.tolerance) or 1)
  return nil unless ok and result and Core.trim(result) != ""
  Core.replace_or_insert_clip line.text, Core.clip_tag_text(span.name, Core.trim(result)), true

Core.op_clip_boolean = (subs, sel, active, opts) ->
  unless ZF and ZF.clipper
    Core.show_message "Shape combining tools are not available."
    return false
  dlg = ZF.dialog subs, sel, active, false
  changed = 0
  for i in *Core.dialogue_indices(subs, sel)
    line = subs[i]
    ok, next_text = pcall -> Core.clip_boolean_text dlg, line, opts
    Core.warn "Line #{i}: clip boolean failed: #{next_text}" unless ok
    if ok and next_text and next_text != line.text
      line.text = next_text
      subs[i] = line
      changed += 1
  if changed == 0
    Core.show_message "No clip could be combined with the text or drawing shape."
    return false
  aegisub.set_undo_point "Cliptomaniac - Clip boolean"
  true

Core.clip_point_count = (span) ->
  return 0 unless span
  kind, _scale, payload = Core.clip_inner_parts span.inner
  return 4 if kind == "rect"
  return 0 unless kind == "vector"
  points = Core.anchor_points_from_commands Core.parse_draw_commands payload
  points and #points or 0

Core.clip_diagnostics_line = (line, index) ->
  spans = Core.all_clip_spans line.text
  return "Line #{index}: no clip" if #spans == 0
  parts = {}
  for n, span in ipairs spans
    kind, scale, _payload = Core.clip_inner_parts span.inner
    bounds = Core.clip_bounds_from_span span
    bounds_text = if bounds
      "#{Core.format_num bounds[1], 2},#{Core.format_num bounds[2], 2} - #{Core.format_num bounds[3], 2},#{Core.format_num bounds[4], 2}"
    else
      "unknown bounds"
    kind_text = kind or "unknown"
    scale_text = scale or 1
    parts[#parts + 1] = "#{span.name} ##{n}: #{kind_text}, #{Core.clip_point_count span} points, scale #{scale_text}, #{bounds_text}"
  plane = line.extra and line.extra["_aegi_perspective_ambient_plane"]
  suffix = if plane then " | perspective plane saved" else ""
  "Line #{index}: " .. table.concat(parts, " / ") .. suffix

Core.op_clip_diagnostics = (subs, sel, opts) ->
  reports = {}
  for i in *Core.dialogue_indices(subs, sel)
    reports[#reports + 1] = Core.clip_diagnostics_line subs[i], i
  if #reports == 0
    Core.show_message "No dialogue lines selected."
    return false
  Core.show_message table.concat(reports, "\n"), "Clip diagnostics"
  true

Core.point_distance = (a, b) ->
  dx, dy = b.x - a.x, b.y - a.y
  math.sqrt dx * dx + dy * dy

Core.lerp_point = (a, b, t) ->
  {x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t}

Core.shift_boundary_t = (boundary_at, t, direction, max_step, amount = 1) ->
  return t if amount <= 0 or max_step <= 0
  base = boundary_at t
  return t unless base and base[1] and base[2]
  low, high = 0, max_step
  for _ = 1, 10
    mid = (low + high) / 2
    candidate_t = Core.clamp t + direction * mid, 0, 1
    candidate = boundary_at candidate_t
    if candidate and candidate[1] and candidate[2]
      delta = math.max Core.point_distance(base[1], candidate[1]), Core.point_distance(base[2], candidate[2])
      if delta <= amount then low = mid else high = mid
    else
      high = mid
  Core.clamp t + direction * low, 0, 1

Core.create_rect_strip_clips = (bounds, mode, strip, name = "clip") ->
  strip = Core.safe_strip_size strip
  bounds = Core.normalize_bounds bounds
  left, top, right, bottom = unpack bounds
  span = mode == "Vertical" and bottom - top or right - left
  sections = math.max 1, math.ceil(span / strip)
  clips = {}
  for i = 1, sections
    a = (i - 1) * strip
    b = i == sections and span or i * strip
    if mode == "Vertical"
      y1, y2 = top + a, top + b
      y1 -= 0.5 if i > 1
      y2 += 0.5 if i < sections
      clips[#clips + 1] = Core.rect_clip_tag {left, y1, right, y2}, name
    else
      x1, x2 = left + a, left + b
      x1 -= 0.5 if i > 1
      x2 += 0.5 if i < sections
      clips[#clips + 1] = Core.rect_clip_tag {x1, top, x2, bottom}, name
  clips

Core.create_quad_strip_clips = (points, mode, strip, name = "clip") ->
  strip = Core.safe_strip_size strip
  return nil unless points and #points >= 4
  quad = {points[1], points[2], points[3], points[4]}
  span = if mode == "Vertical"
    (Core.point_distance(quad[1], quad[4]) + Core.point_distance(quad[2], quad[3])) / 2
  else
    (Core.point_distance(quad[1], quad[2]) + Core.point_distance(quad[4], quad[3])) / 2
  return nil if span <= 0
  sections = math.max 1, math.ceil(span / strip)
  boundary_at = (t) ->
    if mode == "Vertical"
      {Core.lerp_point(quad[1], quad[4], t), Core.lerp_point(quad[2], quad[3], t)}
    else
      {Core.lerp_point(quad[1], quad[2], t), Core.lerp_point(quad[4], quad[3], t)}
  clips = {}
  step_t = 1 / sections
  for i = 1, sections
    t1, t2 = (i - 1) / sections, i / sections
    t2 = Core.shift_boundary_t boundary_at, t2, 1, step_t / 2, 1 if i < sections
    if mode == "Vertical"
      top = boundary_at t1
      bottom = boundary_at t2
      clips[#clips + 1] = Core.vector_clip_tag {top[1], top[2], bottom[2], bottom[1]}, name
    else
      left = boundary_at t1
      right = boundary_at t2
      clips[#clips + 1] = Core.vector_clip_tag {left[1], right[1], right[2], left[2]}, name
  clips

Core.quad_uv_point = (quad, u, v) ->
  ok, point = pcall -> quad\uv_to_xy {u, v}
  return nil unless ok and point
  Core.matrix_point point

Core.create_quad_mesh_clips = (points, mode, strip, name = "clip") ->
  strip = Core.safe_strip_size strip
  return nil unless points and #points >= 4
  return nil unless ArchPerspective and ArchPerspective.Quad
  ok, quad = pcall -> ArchPerspective.Quad {
    {points[1].x, points[1].y}
    {points[2].x, points[2].y}
    {points[3].x, points[3].y}
    {points[4].x, points[4].y}
  }
  return {} unless ok and quad
  span = if mode == "Vertical"
    (Core.point_distance(points[1], points[4]) + Core.point_distance(points[2], points[3])) / 2
  else
    (Core.point_distance(points[1], points[2]) + Core.point_distance(points[4], points[3])) / 2
  return {} if span <= 0.0005
  sections = math.max 1, math.ceil(span / strip)
  step_t = 1 / sections
  boundary_at = (t) ->
    if mode == "Vertical"
      {Core.quad_uv_point(quad, 0, t), Core.quad_uv_point(quad, 1, t)}
    else
      {Core.quad_uv_point(quad, t, 0), Core.quad_uv_point(quad, t, 1)}
  clips = {}
  for i = 1, sections
    t1, t2 = (i - 1) / sections, i / sections
    t2 = Core.shift_boundary_t boundary_at, t2, 1, step_t / 2, 1 if i < sections
    if mode == "Vertical"
      top = boundary_at t1
      bottom = boundary_at t2
      if top[1] and top[2] and bottom[1] and bottom[2]
        clips[#clips + 1] = Core.vector_clip_tag {top[1], top[2], bottom[2], bottom[1]}, name
    else
      left = boundary_at t1
      right = boundary_at t2
      if left[1] and left[2] and right[1] and right[2]
        clips[#clips + 1] = Core.vector_clip_tag {left[1], right[1], right[2], left[2]}, name
  if #clips == sections then clips else {}

Core.strip_clips_from_quad = (points, mode, strip, name = "clip") ->
  quad_mode = if mode == "Vertical" then "Vertical" else "Horizontal"
  Core.create_quad_mesh_clips(points, quad_mode, strip, name) or Core.create_quad_strip_clips(points, quad_mode, strip, name)

Core.points_from_clip_span = (span) ->
  kind, _scale, payload = Core.clip_inner_parts span.inner
  if kind == "rect"
    return Core.rect_points payload
  if kind == "vector"
    return Core.anchor_points_from_commands Core.parse_draw_commands payload
  nil

Core.insert_clipped_duplicate = (subs, index, source, clip_tag, offset) ->
  line = Core.copy_line source
  line.comment = false
  line.text = Core.strip_clip_tags line.text
  line.text = Core.insert_leading_tags line.text, clip_tag
  subs.insert index + offset, line

Core.op_create_strip_clips = (subs, sel, active, opts) ->
  dlg = nil
  if ZF
    ok, value = pcall -> ZF.dialog subs, sel, active, false
    dlg = value if ok
  pending, total_output = {}, 0
  for i in *Core.dialogue_indices(subs, sel)
    source = subs[i]
    span = Core.first_clip_span source.text
    clips = nil
    if span
      kind = Core.clip_inner_parts span.inner
      points = Core.points_from_clip_span span
      if kind == "vector" and points and #points >= 4
        clips = Core.strip_clips_from_quad points, opts.strip_mode, opts.strip, span.name
      else
        bounds = Core.clip_bounds_from_span span
        clips = Core.create_rect_strip_clips bounds, opts.strip_mode, opts.strip, span.name if bounds
    else
      if quad = Core.projected_text_quad source, opts
        clips = Core.strip_clips_from_quad quad, opts.strip_mode, opts.strip
      unless clips
        bounds = nil
        if dlg
          ok, shape = pcall -> Core.build_text_bounds dlg, source, opts
          bounds = {shape.l, shape.t, shape.l + shape.w, shape.t + shape.h} if ok and shape
        clips = Core.create_rect_strip_clips bounds, opts.strip_mode, opts.strip if bounds
    continue unless clips and #clips > 0
    pending[#pending + 1] = {index: i, source: source, clips: clips}
    total_output += if opts.create_new_lines then #clips else 1
  if #pending == 0
    Core.show_message "No strip clips were generated."
    return false
  if opts.create_new_lines and total_output > MAX_STRIP_OUTPUT_LINES
    message = if current_language == "es" then "Esto crearía #{total_output} línea(s) de franja. Usa un tamaño de franja mayor o menos líneas seleccionadas." else "This would create #{total_output} strip line(s). Use a larger strip size or fewer selected lines."
    Core.show_message message, "Create strip clips"
    return false
  changed, inserted_offset = 0, 0
  for job in *pending
    idx = job.index + inserted_offset
    source = subs[idx]
    clips = job.clips
    if opts.create_new_lines
      source.comment = true if opts.comment_source
      subs[idx] = source
      for n, clip_tag in ipairs clips
        Core.insert_clipped_duplicate subs, idx, source, clip_tag, n
      inserted_offset += #clips
      changed += #clips
    else
      source.text = Core.strip_clip_tags source.text
      source.text = Core.insert_leading_tags source.text, clips[1]
      subs[idx] = source
      changed += 1
  aegisub.set_undo_point "Cliptomaniac - Create strip clips"
  true

Core.parse_move_tag = (text) ->
  args = tostring(text or "")\match "\\move%(([^%)]*)%)"
  return nil unless args
  nums = [tonumber(n) for n in args\gmatch NUM_PATTERN]
  return nil unless #nums >= 4
  {
    x1: nums[1], y1: nums[2], x2: nums[3], y2: nums[4]
    t1: nums[5], t2: nums[6]
  }

Core.shift_clip_text = (text, dx, dy) ->
  Core.map_clip_tags text, (span) ->
    kind, scale, payload = Core.clip_inner_parts span.inner
    if kind == "rect"
      b = Core.pad_bounds payload, 0
      Core.rect_clip_tag {b[1] + dx, b[2] + dy, b[3] + dx, b[4] + dy}, span.name
    elseif kind == "vector"
      Core.clip_tag_text span.name, Core.vector_inner_with_scale(Core.shift_path(payload, dx, dy), scale)
    else
      span.raw

Core.move_position_at = (move, line, ms) ->
  duration = math.max 1, (tonumber(line.end_time) or 0) - (tonumber(line.start_time) or 0)
  local_ms = (tonumber(ms) or 0) - (tonumber(line.start_time) or 0)
  t1, t2 = tonumber(move.t1) or 0, tonumber(move.t2) or duration
  ratio = if t2 == t1 then 1 else Core.clamp((local_ms - t1) / (t2 - t1), 0, 1)
  {
    x: move.x1 + (move.x2 - move.x1) * ratio
    y: move.y1 + (move.y2 - move.y1) * ratio
  }

Core.frame_range_for_line = (line) ->
  return nil unless aegisub and aegisub.frame_from_ms and aegisub.ms_from_frame
  start_frame = aegisub.frame_from_ms line.start_time
  end_frame = aegisub.frame_from_ms line.end_time
  return nil unless start_frame and end_frame
  end_frame = start_frame + 1 if end_frame <= start_frame
  start_frame, end_frame

Core.manual_move_fbf_lines = (line, opts = {}) ->
  move = Core.parse_move_tag line.text
  return nil unless move and Core.first_clip_span(line.text)
  start_frame, end_frame = Core.frame_range_for_line line
  return nil unless start_frame and end_frame
  out = {}
  for frame = start_frame, end_frame - 1
    start_ms = math.max tonumber(line.start_time) or 0, aegisub.ms_from_frame(frame)
    end_ms = math.min tonumber(line.end_time) or 0, aegisub.ms_from_frame(frame + 1)
    continue if end_ms <= start_ms
    pos = Core.move_position_at move, line, (start_ms + end_ms) / 2
    next_line = Core.copy_line line
    next_line.start_time = start_ms
    next_line.end_time = end_ms
    dx, dy = pos.x - move.x1, pos.y - move.y1
    text = Core.shift_clip_text line.text, dx, dy
    text = Core.remove_tag_names text, {"move", "pos"}
    text = Core.insert_leading_tags text, "\\pos(#{Core.format_num pos.x, 3},#{Core.format_num pos.y, 3})"
    next_line.text = text
    out[#out + 1] = next_line
  out

Core.copy_plain_fbf_line = (item, fallback) ->
  return nil unless type(item) == "table"
  source = if item.text then item elseif item.line and item.line.text then item.line else nil
  return nil unless source
  out = Core.copy_line fallback
  out[k] = v for k, v in pairs source
  out.class = out.class or "dialogue"
  out.comment = false
  out

Core.util_fbf_lines = (line, opts = {}) ->
  return nil unless Util and Util.line2fbf and ASS and ASS.parse
  ok_parse, data = pcall -> Core.parse_ass_line line
  return nil unless ok_parse and data
  ok_fbf, fbf = pcall -> Util.line2fbf data
  return nil unless ok_fbf and type(fbf) == "table"
  out = {}
  for item in *fbf
    plain = Core.copy_plain_fbf_line item, line
    out[#out + 1] = plain if plain and plain.text
  if #out > 0 then out else nil

Core.clip_only_from_baked = (source, baked) ->
  span = Core.first_clip_span baked.text
  return baked unless span
  out = Core.copy_line source
  out.start_time = baked.start_time
  out.end_time = baked.end_time
  base = Core.strip_clip_tags source.text
  base = Core.remove_tag_names base, {"move"}
  out.text = Core.insert_leading_tags base, span.raw
  out

Core.fbf_lines_for_line = (line, opts = {}) ->
  lines = Core.util_fbf_lines(line, opts) or Core.manual_move_fbf_lines(line, opts)
  return nil unless lines and #lines > 0
  if opts.fbf_source == "Clip only"
    lines = [Core.clip_only_from_baked(line, baked) for baked in *lines]
  lines

Core.same_fbf_body = (a, b) ->
  return false unless a and b
  for key in *{"text", "style", "actor", "effect", "layer"}
    return false unless tostring(a[key] or "") == tostring(b[key] or "")
  true

Core.merge_fbf_lines = (lines) ->
  out = {}
  for line in *(lines or {})
    if #out > 0 and Core.same_fbf_body(out[#out], line) and out[#out].end_time == line.start_time
      out[#out].end_time = line.end_time
    else
      out[#out + 1] = line
  out

Core.op_animated_clip_to_fbf = (subs, sel, active, opts) ->
  changed, inserted_offset, total_frames = 0, 0, 0
  pending = {}
  for i in *Core.dialogue_indices(subs, sel)
    line = subs[i]
    lines = Core.fbf_lines_for_line line, opts
    continue unless lines and #lines > 0
    lines = Core.merge_fbf_lines lines if opts.merge_identical
    total_frames += #lines
    pending[#pending + 1] = {index: i, lines: lines}
  if #pending == 0
    Core.show_message "No animated clip or movable clipped line could be baked."
    return false
  if total_frames > opts.max_frames
    message = if current_language == "es" then "Esto crearía #{total_frames} línea(s). Sube Frames max si quieres ejecutarlo." else "This would create #{total_frames} line(s). Raise Max frames if you want to run it."
    Core.show_message message, "Animated clip to FBF"
    return false
  for job in *pending
    idx = job.index + inserted_offset
    source = subs[idx]
    lines = job.lines
    if opts.comment_source
      source.comment = true
      subs[idx] = source
      for n, out_line in ipairs lines
        subs.insert idx + n, out_line
      inserted_offset += #lines
    else
      subs[idx] = lines[1]
      for n = 2, #lines
        subs.insert idx + n - 1, lines[n]
      inserted_offset += #lines - 1
    changed += #lines
  aegisub.set_undo_point "Cliptomaniac - Animated clip to FBF"
  true

Core.quad_from_clip = (text) ->
  span = Core.first_clip_span text
  return nil unless span
  pts = Core.quad_points_from_span span
  return nil unless pts and #pts == 4
  {
    {pts[1].x, pts[1].y}
    {pts[2].x, pts[2].y}
    {pts[3].x, pts[3].y}
    {pts[4].x, pts[4].y}
  }

Core.plane_extra_string = (quad) ->
  return nil unless quad and #quad >= 4
  string.format "%.3f;%.3f|%.3f;%.3f|%.3f;%.3f|%.3f;%.3f",
    quad[1][1], quad[1][2], quad[2][1], quad[2][2], quad[3][1], quad[3][2], quad[4][1], quad[4][2]

Core.plane_points_from_numbers = (nums) ->
  return nil unless nums and #nums >= 8
  points = {}
  for i = 1, 4
    x, y = Core.finite_number(nums[i * 2 - 1]), Core.finite_number(nums[i * 2])
    return nil unless x and y
    points[#points + 1] = {:x, :y}
  points

Core.plane_points_from_string = (value) ->
  nums = {}
  for n in tostring(value or "")\gmatch NUM_PATTERN
    nums[#nums + 1] = tonumber n
    break if #nums >= 8
  Core.plane_points_from_numbers nums

Core.perspective_marker_inner = (text) ->
  tostring(text or "")\match "\\_persp%(([^%)]*)%)"

Core.strip_perspective_marker = (text) ->
  clean = tostring(text or "")\gsub "\\_persp%([^%)]+%)", ""
  Core.clean_empty_overrides clean

Core.plane_points_to_quad = (points) ->
  return nil unless points and #points >= 4
  {{points[1].x, points[1].y}, {points[2].x, points[2].y}, {points[3].x, points[3].y}, {points[4].x, points[4].y}}

Core.perspective_plane_points_for_line = (line, opts = {}) ->
  if line and type(line.extra) == "table"
    points = Core.plane_points_from_string line.extra["_aegi_perspective_ambient_plane"]
    return points, "extra" if points
  marker = Core.perspective_marker_inner(line and line.text)
  if marker
    points = Core.plane_points_from_string marker
    return points, "marker" if points
  quad = Core.projected_text_quad line, {margin: 0, style_pad: false}
  return quad, "projected" if quad and #quad >= 4
  nil, nil

Core.plane_extra_string_from_points = (points) ->
  quad = Core.plane_points_to_quad points
  Core.plane_extra_string quad

PerspectiveTools = PerspectiveTools or {}

PerspectiveTools.finite_value = (n) ->
  type(n) == "number" and n == n and n != math.huge and n != -math.huge and math.abs(n) < 10000000

PerspectiveTools.valid_dim = (n) ->
  PerspectiveTools.finite_value(n) and n > 0.0001

PerspectiveTools.valid_quad = (quad) ->
  return false unless type(quad) == "table" and #quad >= 4
  area = 0
  for i = 1, 4
    p = quad[i]
    return false unless type(p) == "table" and PerspectiveTools.finite_value(p[1]) and PerspectiveTools.finite_value(p[2])
    j = i == 4 and 1 or i + 1
    area += p[1] * quad[j][2] - quad[j][1] * p[2]
  math.abs(area) > 0.01

PerspectiveTools.edge_len = (a, b) ->
  dx, dy = (b[1] or 0) - (a[1] or 0), (b[2] or 0) - (a[2] or 0)
  math.sqrt dx * dx + dy * dy

PerspectiveTools.area = (quad) ->
  area = 0
  for i = 1, 4
    j = i == 4 and 1 or i + 1
    area += quad[i][1] * quad[j][2] - quad[j][1] * quad[i][2]
  area / 2

PerspectiveTools.rotate = (quad, start_index, reversed) ->
  out = {}
  for i = 1, 4
    idx = if reversed then ((start_index - i) % 4) + 1 else ((start_index + i - 2) % 4) + 1
    out[i] = {quad[idx][1], quad[idx][2]}
  out

PerspectiveTools.orient = (quad, width, height) ->
  return quad unless PerspectiveTools.valid_quad quad
  target_aspect = if PerspectiveTools.valid_dim(width) and PerspectiveTools.valid_dim(height) then width / height else 1
  best, best_score = nil, nil
  for reversed in *{false, true}
    for start_index = 1, 4
      candidate = PerspectiveTools.rotate quad, start_index, reversed
      width_len = (PerspectiveTools.edge_len(candidate[1], candidate[2]) + PerspectiveTools.edge_len(candidate[4], candidate[3])) / 2
      height_len = (PerspectiveTools.edge_len(candidate[2], candidate[3]) + PerspectiveTools.edge_len(candidate[1], candidate[4])) / 2
      if width_len > 0 and height_len > 0
        score = math.abs math.log((width_len / height_len) / target_aspect)
        top_y = (candidate[1][2] + candidate[2][2]) / 2
        bottom_y = (candidate[3][2] + candidate[4][2]) / 2
        score += 2 if top_y > bottom_y
        score += 0.5 if candidate[1][1] > candidate[2][1]
        score += 0.25 if PerspectiveTools.area(candidate) < 0
        if not best_score or score < best_score
          best, best_score = candidate, score
  best or quad

PerspectiveTools.map_quad = (quad, name) ->
  name = Core.normalize_perspective_map name
  for entry in *PERSPECTIVE_DATA.maps
    if entry[1] == name
      mapping = entry[2]
      return {quad[mapping[1]], quad[mapping[2]], quad[mapping[3]], quad[mapping[4]]} if type(mapping) == "table"
  quad

PerspectiveTools.map_items = ->
  [entry[1] for entry in *PERSPECTIVE_DATA.maps]

PerspectiveTools.org_mode = (name) ->
  tonumber(tostring(Core.normalize_perspective_org(name))\match "^(%d)") or 2

PerspectiveTools.tag_value = (tag, fallback = 0) ->
  return tonumber(tag) or fallback unless type(tag) == "table"
  return tonumber(tag.value) or fallback if tag.value != nil
  return tonumber(tag.dim_value) or fallback if tag.dim_value != nil
  fallback

PerspectiveTools.dim_tag = (value) ->
  n = tonumber(value) or 0
  {value: n, dim_value: n}

PerspectiveTools.align_value = (value, fallback = 5) ->
  n = math.floor(tonumber(value) or tonumber(fallback) or 5)
  if n >= 1 and n <= 9 then n else 5

PerspectiveTools.ensure_dim_tag = (tags, name, fallback = 0) ->
  tag = tags[name]
  n = PerspectiveTools.tag_value tag, fallback
  if type(tag) == "table"
    tag.value = n
    tag.dim_value = n
  else
    tags[name] = PerspectiveTools.dim_tag(n)
  tags[name]

PerspectiveTools.ensure_align_tag = (tags, fallback = 5) ->
  n = PerspectiveTools.align_value(PerspectiveTools.tag_value(tags.align, fallback), fallback)
  tags.align = PerspectiveTools.dim_tag(n)

PerspectiveTools.default_position = (line, style = nil) ->
  meta = line and line.parentCollection and line.parentCollection.meta or {}
  play_x = tonumber(meta.PlayResX or meta.playresx or meta.res_x) or 1920
  play_y = tonumber(meta.PlayResY or meta.playresy or meta.res_y) or 1080
  state = Core.effective_line_state line
  style = style or PerspectiveTools.style(state.style, line and line.style or "Default")
  align = PerspectiveTools.align_value(Core.line_tag_value(line, "an", "align", style.align or 5, state), style.align or 5)
  ml = tonumber line and line.margin_l
  mr = tonumber line and line.margin_r
  mv = tonumber line and (line.margin_t or line.margin_v)
  ml = tonumber(style.margin_l) or 0 if not ml or ml == 0
  mr = tonumber(style.margin_r) or 0 if not mr or mr == 0
  mv = tonumber(style.margin_t or style.margin_v) or 0 if not mv or mv == 0
  x = if align == 1 or align == 4 or align == 7
    ml
  elseif align == 3 or align == 6 or align == 9
    play_x - mr
  else
    play_x / 2
  y = if align >= 7
    mv
  elseif align >= 4
    play_y / 2
  else
    play_y - mv
  {:x, :y}

PerspectiveTools.ensure_point_tag = (tags, name, fallback) ->
  tag = tags[name]
  x, y = nil, nil
  if type(tag) == "table"
    x = tonumber(tag.x)
    y = tonumber(tag.y)
  x = tonumber(fallback and fallback.x) or 0 unless x
  y = tonumber(fallback and fallback.y) or 0 unless y
  tags[name] = {x: x, y: y}
  tags[name]

PerspectiveTools.sync_dim_tags = (tags) ->
  return tags unless type(tags) == "table"
  for _name, tag in pairs tags
    if type(tag) == "table"
      n = tonumber(tag.value) or tonumber(tag.dim_value)
      if n != nil
        tag.value = n
        tag.dim_value = n
  tags

PerspectiveTools.style = (style, name = "Default") ->
  out = {}
  if type(style) == "table"
    out[k] = v for k, v in pairs style
  out.class = out.class or "style"
  out.name = out.name or name or "Default"
  out.fontname = out.fontname or "Arial"
  out.fontsize = tonumber(out.fontsize) or 20
  out.scale_x = tonumber(out.scale_x) or 100
  out.scale_y = tonumber(out.scale_y) or 100
  out.angle = tonumber(out.angle) or 0
  out.spacing = tonumber(out.spacing) or 0
  out.outline = tonumber(out.outline) or 0
  out.shadow = tonumber(out.shadow) or 0
  out.margin_l = tonumber(out.margin_l) or 0
  out.margin_r = tonumber(out.margin_r) or 0
  out.margin_t = tonumber(out.margin_t or out.margin_v) or 0
  out.align = tonumber(out.align) or 5
  out.bold = out.bold or false
  out.italic = out.italic or false
  out.underline = out.underline or false
  out.strikeout = out.strikeout or false
  out.color1 = out.color1 or "&H00FFFFFF"
  out.color2 = out.color2 or "&H00FFFFFF"
  out.color3 = out.color3 or "&H00000000"
  out.color4 = out.color4 or "&H00000000"
  out

PerspectiveTools.effective_tags = (data) ->
  return nil unless data and data.getEffectiveTags
  ok, eff = pcall -> data\getEffectiveTags(-1, true, true, true)
  return nil unless ok and eff
  eff.tags

PerspectiveTools.shape_extents = (text) ->
  raw = tostring(text or "")
  return nil unless raw\find "\\p[1-9]"
  body = Core.strip_tags raw
  minx, miny, maxx, maxy = math.huge, math.huge, -math.huge, -math.huge
  found = false
  for sx, sy in body\gmatch "(" .. NUM_PATTERN .. ")%s+(" .. NUM_PATTERN .. ")"
    x, y = tonumber(sx), tonumber(sy)
    if x and y
      found = true
      minx = math.min minx, x
      miny = math.min miny, y
      maxx = math.max maxx, x
      maxy = math.max maxy, y
  return nil unless found
  math.max(maxx - minx, 0.01), math.max(maxy - miny, 0.01)

PerspectiveTools.measure_style = (line, style) ->
  state = Core.effective_line_state line
  base_style = if state and state.style and next(state.style) then state.style else style
  out = PerspectiveTools.style base_style, line and line.style or "Default"
  out.fontsize = Core.line_tag_value(line, "fs", "fontsize", out.fontsize, state) or out.fontsize
  out.scale_x = Core.line_tag_value(line, "fscx", "scale_x", out.scale_x, state) or out.scale_x
  out.scale_y = Core.line_tag_value(line, "fscy", "scale_y", out.scale_y, state) or out.scale_y
  out.spacing = Core.line_tag_value(line, "fsp", "spacing", out.spacing, state) or out.spacing
  unless state.tag_list and state.style
    for block in *Core.override_block_spans(line and line.text or "")
      continue unless Core.looks_like_override block.inner
      for name in block.inner\gmatch "\\fn([^\\}]*)"
        out.fontname = name if name and name != ""
  for item in *{{"b", "bold"}, {"i", "italic"}, {"u", "underline"}, {"s", "strikeout"}}
    value = Core.line_tag_value line, item[1], nil, nil, state
    out[item[2]] = value != 0 if value != nil
  out

PerspectiveTools.point_value = (value) ->
  return nil unless type(value) == "table"
  return PerspectiveTools.point_value value.startPos if value.startPos
  x = tonumber(value.x or value[1])
  y = tonumber(value.y or value[2])
  return {x: x, y: y} if x and y
  if value.getTagParams
    ok, px, py = pcall -> value\getTagParams!
    x, y = tonumber(px), tonumber(py) if ok
    return {x: x, y: y} if x and y
  nil

PerspectiveTools.point_from_tag = (text, name) ->
  pattern = "\\" .. name .. "%(%s*(" .. NUM_PATTERN .. ")%s*,%s*(" .. NUM_PATTERN .. ")%s*%)"
  point = nil
  for x, y in tostring(text or "")\gmatch pattern
    point = {x: tonumber(x), y: tonumber(y)} if tonumber(x) and tonumber(y)
  point

PerspectiveTools.move_start = (text) ->
  pattern = "\\move%(%s*(" .. NUM_PATTERN .. ")%s*,%s*(" .. NUM_PATTERN .. ")%s*,%s*(" .. NUM_PATTERN .. ")%s*,%s*(" .. NUM_PATTERN .. ")"
  point = nil
  for x1, y1 in tostring(text or "")\gmatch pattern
    point = {x: tonumber(x1), y: tonumber(y1)} if tonumber(x1) and tonumber(y1)
  point

PerspectiveTools.raw_tags = (line) ->
  state = Core.effective_line_state line
  style = PerspectiveTools.measure_style line, PerspectiveTools.style(state.style, line and line.style or "Default")
  text = tostring(line and line.text or "")
  bord = Core.line_tag_value(line, "bord", "outline", style.outline or 0, state)
  shad = Core.line_tag_value(line, "shad", "shadow", style.shadow or 0, state)
  tags = {
    align: PerspectiveTools.dim_tag Core.line_tag_value(line, "an", "align", style.align or 5, state)
    scale_x: PerspectiveTools.dim_tag Core.line_tag_value(line, "fscx", "scale_x", style.scale_x or 100, state)
    scale_y: PerspectiveTools.dim_tag Core.line_tag_value(line, "fscy", "scale_y", style.scale_y or 100, state)
    angle: PerspectiveTools.dim_tag Core.line_tag_value(line, "frz", "angle", style.angle or 0, state)
    angle_x: PerspectiveTools.dim_tag Core.line_tag_value(line, "frx", nil, 0, state)
    angle_y: PerspectiveTools.dim_tag Core.line_tag_value(line, "fry", nil, 0, state)
    shear_x: PerspectiveTools.dim_tag Core.line_tag_value(line, "fax", nil, 0, state)
    shear_y: PerspectiveTools.dim_tag Core.line_tag_value(line, "fay", nil, 0, state)
    fontsize: PerspectiveTools.dim_tag Core.line_tag_value(line, "fs", "fontsize", style.fontsize or 20, state)
    outline_x: PerspectiveTools.dim_tag Core.line_tag_value(line, "xbord", nil, bord, state)
    outline_y: PerspectiveTools.dim_tag Core.line_tag_value(line, "ybord", nil, bord, state)
    shadow_x: PerspectiveTools.dim_tag Core.line_tag_value(line, "xshad", nil, shad, state)
    shadow_y: PerspectiveTools.dim_tag Core.line_tag_value(line, "yshad", nil, shad, state)
  }
  pos = PerspectiveTools.point_value(state.tags.position) or PerspectiveTools.point_value(state.tags.move) or PerspectiveTools.point_from_tag(text, "pos") or PerspectiveTools.move_start(text) or PerspectiveTools.default_position(line, style)
  org = PerspectiveTools.point_value(state.tags.origin) or PerspectiveTools.point_from_tag(text, "org") or pos
  tags.position = {x: pos.x, y: pos.y}
  tags.origin = {x: org.x, y: org.y}
  tags

PerspectiveTools.has_visible_source = (line) ->
  clean = Core.visible_text(Core.strip_clip_tags(line and line.text or ""))\gsub("\\[Nn]", " ")
  Core.trim(clean) != ""

PerspectiveTools.needs_extent_override = (line, width, height) ->
  return true if tostring(line and line.text or "")\find "\\N", 1, true
  return true if tostring(line and line.text or "")\find "\\n", 1, true
  PerspectiveTools.has_visible_source(line) and ((tonumber(width) or 0) < 1 or (tonumber(height) or 0) < 1)

PerspectiveTools.visible_lines = (text) ->
  clean = Core.visible_text(Core.strip_clip_tags(text or ""))\gsub("\\[Nn]", "\n")\gsub("\\h", " ")
  out = {}
  for line in (clean .. "\n")\gmatch "([^\n]*)\n"
    out[#out + 1] = if line == "" then " " else line
  if #out > 0 then out else {" "}

PerspectiveTools.text_len = (text) ->
  text = tostring(text or "")
  count = 0
  if unicode and unicode.chars
    for _ch in unicode.chars text
      count += 1
  else
    count = #text
  count

PerspectiveTools.rough_text_extents = (line, style, state = nil) ->
  state or= Core.effective_line_state line
  fs = Core.line_tag_value(line, "fs", "fontsize", tonumber(style and style.fontsize) or 20, state) or 20
  sx = Core.line_tag_value(line, "fscx", "scale_x", tonumber(style and style.scale_x) or 100, state) or 100
  sy = Core.line_tag_value(line, "fscy", "scale_y", tonumber(style and style.scale_y) or 100, state) or 100
  spacing = Core.line_tag_value(line, "fsp", "spacing", tonumber(style and style.spacing) or 0, state) or 0
  max_w, total_h = 0, 0
  for piece in *PerspectiveTools.visible_lines(line and line.text or "")
    count = PerspectiveTools.text_len piece
    raw_width = count * fs * 0.4042 + math.max(count - 1, 0) * spacing
    max_w = math.max max_w, raw_width * sx / 100
    total_h += fs * sy / 100
  math.max(max_w, 0.01), math.max(total_h, 0.01)

PerspectiveTools.text_extents = (line, tags = nil) ->
  state = Core.effective_line_state line
  style = PerspectiveTools.measure_style line, PerspectiveTools.style(state.style, line and line.style or "Default")
  w, h = PerspectiveTools.shape_extents line and line.text
  unless PerspectiveTools.valid_dim(w) and PerspectiveTools.valid_dim(h)
    clean = Core.visible_text(Core.strip_clip_tags(line and line.text or ""))\gsub("\\[Nn]", "\n")
    return 100, 100 if Core.trim(clean) == ""
    has_linebreak = tostring(line and line.text or "")\find("\\N", 1, true) or tostring(line and line.text or "")\find("\\n", 1, true)
    if not has_linebreak and state.data and state.data.getTextExtents
      ok, ew, eh = pcall -> state.data\getTextExtents!
      if ok and PerspectiveTools.valid_dim(ew) and PerspectiveTools.valid_dim(eh)
        w, h = ew, eh
    if aegisub and type(aegisub.text_extents) == "function"
      unless PerspectiveTools.valid_dim(w) and PerspectiveTools.valid_dim(h)
        max_w, total_h, measured = 0, 0, false
        for piece in *PerspectiveTools.visible_lines(line and line.text or "")
          sample = if piece == "" then " " else piece
          ok, ew, eh = pcall aegisub.text_extents, style, sample
          if ok and PerspectiveTools.valid_dim(ew) and PerspectiveTools.valid_dim(eh)
            measured = true
            max_w = math.max max_w, ew
            total_h += eh
        if measured
          w, h = max_w, math.max(total_h, 0.01)
  unless PerspectiveTools.valid_dim(w) and PerspectiveTools.valid_dim(h)
    w, h = PerspectiveTools.rough_text_extents line, style, state
  sx = PerspectiveTools.tag_value(tags and tags.scale_x, Core.line_tag_value(line, "fscx", "scale_x", style.scale_x or 100, state))
  sy = PerspectiveTools.tag_value(tags and tags.scale_y, Core.line_tag_value(line, "fscy", "scale_y", style.scale_y or 100, state))
  w /= sx / 100 if PerspectiveTools.valid_dim sx
  h /= sy / 100 if PerspectiveTools.valid_dim sy
  unless PerspectiveTools.valid_dim(w) and PerspectiveTools.valid_dim(h)
    w, h = PerspectiveTools.rough_text_extents line, style, state
  math.max(w, 0.01), math.max(h, 0.01)

PerspectiveTools.normalize_perspective_tags = (tags, line) ->
  return nil unless type(tags) == "table"
  style_ref = if line then (line.styleRef or line.styleref) else nil
  style_name = if line then line.style or "Default" else "Default"
  style = PerspectiveTools.measure_style line, PerspectiveTools.style(style_ref, style_name)
  PerspectiveTools.ensure_align_tag(tags, style.align or 5)
  for item in *{
    {"scale_x", style.scale_x or 100}
    {"scale_y", style.scale_y or 100}
    {"angle", style.angle or 0}
    {"angle_x", 0}
    {"angle_y", 0}
    {"shear_x", 0}
    {"shear_y", 0}
    {"fontsize", style.fontsize or 20}
  }
    PerspectiveTools.ensure_dim_tag(tags, item[1], item[2])
  outline = PerspectiveTools.tag_value(tags.outline, style.outline or 0)
  shadow = PerspectiveTools.tag_value(tags.shadow, style.shadow or 0)
  PerspectiveTools.ensure_dim_tag(tags, "outline_x", outline)
  PerspectiveTools.ensure_dim_tag(tags, "outline_y", outline)
  PerspectiveTools.ensure_dim_tag(tags, "shadow_x", shadow)
  PerspectiveTools.ensure_dim_tag(tags, "shadow_y", shadow)
  pos = PerspectiveTools.ensure_point_tag(tags, "position", PerspectiveTools.default_position(line, style))
  PerspectiveTools.ensure_point_tag(tags, "origin", pos)
  PerspectiveTools.sync_dim_tags(tags)

PerspectiveTools.line = (line) ->
  copy = Core.copy_line line
  copy.text = tostring(copy.text or "")
  style_name = copy.style or "Default"
  style = PerspectiveTools.style(copy.styleRef or copy.styleref, style_name)
  copy.styleRef = style
  copy.styleref = style
  unless copy.parentCollection
    styles = {Default: style}
    styles[style_name] = style
    copy.parentCollection = {
      meta: {PlayResX: 1920, PlayResY: 1080}
      styles: styles
    }
  copy

PerspectiveTools.prepare = (line) ->
  pline = PerspectiveTools.line(line)
  data = nil
  ok_data, parsed = pcall -> Core.parse_ass_line pline
  data = parsed if ok_data
  ok_prep, tags, width, height = false, nil, nil, nil
  if data
    ok_prep, tags, width, height = pcall -> ArchPerspective.prepareForPerspective ASS, data
    if ok_prep and tags and PerspectiveTools.valid_dim(width) and PerspectiveTools.valid_dim(height) and PerspectiveTools.needs_extent_override(pline, width, height)
      mw, mh = PerspectiveTools.text_extents pline, tags
      if PerspectiveTools.valid_dim(mw) and PerspectiveTools.valid_dim(mh)
        width, height = mw, mh
  unless ok_prep and tags and PerspectiveTools.valid_dim(width) and PerspectiveTools.valid_dim(height)
    tags = PerspectiveTools.effective_tags(data) or PerspectiveTools.raw_tags(pline)
    width, height = PerspectiveTools.text_extents pline, tags
  return nil unless tags and PerspectiveTools.valid_dim(width) and PerspectiveTools.valid_dim(height)
  PerspectiveTools.normalize_perspective_tags(tags, pline)
  tags, width, height

PerspectiveTools.fail = (reason) ->
  PerspectiveTools.last_apply_error = reason or "apply failed"
  false

PerspectiveTools.tags_are_finite = (tags) ->
  for name in *{"align", "scale_x", "scale_y", "angle", "angle_x", "angle_y", "shear_x", "shear_y"}
    return false, "non-finite tag #{name}" unless tags[name] and PerspectiveTools.finite_value(PerspectiveTools.tag_value(tags[name], 0))
  return false, "missing position/origin" unless tags.position and tags.origin
  return false, "non-finite position/origin" unless PerspectiveTools.finite_value(tags.position.x) and PerspectiveTools.finite_value(tags.position.y) and PerspectiveTools.finite_value(tags.origin.x) and PerspectiveTools.finite_value(tags.origin.y)
  true

PerspectiveTools.apply_tags_from_quad = (tags, quad, width, height, line, org_mode) ->
  return PerspectiveTools.fail "bad quad" unless PerspectiveTools.valid_quad(quad)
  return PerspectiveTools.fail "bad dimensions #{tostring(width)}x#{tostring(height)}" unless PerspectiveTools.valid_dim(width) and PerspectiveTools.valid_dim(height)
  PerspectiveTools.normalize_perspective_tags(tags, line)
  ok, err = pcall ->
    q = ArchPerspective.Quad {quad[1], quad[2], quad[3], quad[4]}
    ArchPerspective.tagsFromQuad tags, q, width, height, org_mode or 3, Core.layout_scale_for_line(line)
  return PerspectiveTools.fail "tagsFromQuad failed: #{tostring(err)}" unless ok
  PerspectiveTools.sync_dim_tags tags
  finite, reason = PerspectiveTools.tags_are_finite tags
  return PerspectiveTools.fail reason unless finite
  true

PerspectiveTools.rect_at_quad = (arch_quad, tags, sx = 1, sy = 1) ->
  return nil unless arch_quad and tags and ArchPerspective
  an = PerspectiveTools.align_value PerspectiveTools.tag_value(tags.align, 5), 5
  xshift = (ArchPerspective.an_xshift and ArchPerspective.an_xshift[an]) or ({0, 0.5, 1, 0, 0.5, 1, 0, 0.5, 1})[an]
  yshift = (ArchPerspective.an_yshift and ArchPerspective.an_yshift[an]) or ({1, 1, 1, 0.5, 0.5, 0.5, 0, 0, 0})[an]
  return nil unless xshift and yshift
  base = {{0, 0}, {1, 0}, {1, 1}, {0, 1}}
  out = {}
  for i, p in ipairs base
    u = (p[1] - xshift) * sx + 0.5
    v = (p[2] - yshift) * sy + 0.5
    ok, mapped = pcall -> arch_quad\uv_to_xy {u, v}
    return nil unless ok and mapped
    point = Core.matrix_point mapped
    return nil unless point
    out[i] = {point.x, point.y}
  if PerspectiveTools.valid_quad(out) then out else nil

PerspectiveTools.apply_tags_from_plane = (tags, quad, width, height, line, org_mode) ->
  return false unless PerspectiveTools.valid_quad(quad) and PerspectiveTools.valid_dim(width) and PerspectiveTools.valid_dim(height)
  PerspectiveTools.normalize_perspective_tags(tags, line)
  old_x = PerspectiveTools.tag_value tags.scale_x, 100
  old_y = PerspectiveTools.tag_value tags.scale_y, 100
  ok_quad, arch_quad = pcall -> ArchPerspective.Quad {quad[1], quad[2], quad[3], quad[4]}
  return false unless ok_quad and arch_quad
  rect = PerspectiveTools.rect_at_quad arch_quad, tags, 1, 1
  return false unless rect and PerspectiveTools.apply_tags_from_quad(tags, rect, width, height, line, org_mode)
  cur_x = PerspectiveTools.tag_value tags.scale_x, old_x
  cur_y = PerspectiveTools.tag_value tags.scale_y, old_y
  return false unless PerspectiveTools.valid_dim(cur_x) and PerspectiveTools.valid_dim(cur_y)
  rect = PerspectiveTools.rect_at_quad arch_quad, tags, old_x / cur_x, old_y / cur_y
  rect and PerspectiveTools.apply_tags_from_quad(tags, rect, width, height, line, org_mode)

PerspectiveTools.serialize = (line, tags) ->
  text = Core.remove_tag_names line.text, {"frx", "fry", "frz", "fr", "fax", "fay", "fscx", "fscy", "org", "pos", "move", "t"}
  payload = string.format "\\frx%.4f\\fry%.4f\\frz%.4f\\fax%.6f\\fay%.6f\\fscx%.4f\\fscy%.4f\\org(%.3f,%.3f)\\pos(%.3f,%.3f)",
    PerspectiveTools.tag_value(tags.angle_x, 0), PerspectiveTools.tag_value(tags.angle_y, 0), PerspectiveTools.tag_value(tags.angle, 0),
    PerspectiveTools.tag_value(tags.shear_x, 0), PerspectiveTools.tag_value(tags.shear_y, 0),
    PerspectiveTools.tag_value(tags.scale_x, 100), PerspectiveTools.tag_value(tags.scale_y, 100),
    tags.origin.x, tags.origin.y,
    tags.position.x, tags.position.y
  line.text = Core.insert_leading_tags text, payload
  line.text = Core.clean_empty_overrides line.text

PerspectiveTools.apply_quad = (line, quad, opts) ->
  opts = {} unless type(opts) == "table"
  opts.perspective_map = opts.perspective_map or DEFAULTS.perspective_map
  opts.perspective_org_mode = opts.perspective_org_mode or DEFAULTS.perspective_org_mode
  opts.remove_clip = DEFAULTS.remove_clip if opts.remove_clip == nil
  PerspectiveTools.last_apply_error = nil
  tags, width, height = PerspectiveTools.prepare line
  return PerspectiveTools.fail "prepare failed" unless tags
  oriented = PerspectiveTools.orient quad, width, height
  mapped = PerspectiveTools.map_quad oriented, opts.perspective_map
  return false unless PerspectiveTools.apply_tags_from_quad tags, mapped, width, height, line, PerspectiveTools.org_mode(opts.perspective_org_mode)
  PerspectiveTools.serialize line, tags
  line.extra = {} unless type(line.extra) == "table"
  plane = Core.plane_extra_string mapped
  line.extra["_aegi_perspective_ambient_plane"] = plane if plane
  line.text = Core.strip_clip_tags line.text if opts.remove_clip
  true

Core.op_clip_to_perspective = (subs, sel, opts) ->
  unless ASS and ArchPerspective and ArchPerspective.prepareForPerspective and ArchPerspective.tagsFromQuad
    Core.show_message "Perspective tools are not available."
    return false
  changed = 0
  for i in *Core.dialogue_indices(subs, sel)
    line = subs[i]
    quad = Core.quad_from_clip line.text
    continue unless quad
    ok, applied_or_err = pcall -> PerspectiveTools.apply_quad line, quad, opts
    if ok and applied_or_err
      subs[i] = line
      changed += 1
    else
      detail = if applied_or_err == false then (PerspectiveTools.last_apply_error or "apply failed") else tostring applied_or_err
      Core.warn "Line #{i}: clip to perspective failed: #{detail}"
  if changed == 0
    Core.show_message "No 4-point clip could be applied as perspective."
    return false
  aegisub.set_undo_point "Cliptomaniac - Clip to perspective"
  true

Core.perspective_to_clip_text = (line, opts = {}) ->
  points, source = Core.perspective_plane_points_for_line line, opts
  return nil unless points and #points >= 4
  clip_tag = Core.vector_clip_tag points, Core.clip_type_for_line(line, opts)
  text = Core.strip_perspective_marker line.text or ""
  text = Core.replace_or_insert_clip text, clip_tag, true
  Core.clean_empty_overrides(text), points, source

Core.op_perspective_to_clip = (subs, sel, opts) ->
  changed = 0
  for i in *Core.dialogue_indices(subs, sel)
    line = subs[i]
    next_text, points, source = Core.perspective_to_clip_text line, opts
    continue unless next_text
    if next_text != line.text
      line.text = next_text
      plane = Core.plane_extra_string_from_points points
      if plane
        line.extra = {} unless type(line.extra) == "table"
        line.extra["_aegi_perspective_ambient_plane"] = plane
      subs[i] = line
      changed += 1
  if changed == 0
    Core.show_message "No perspective plane could be converted to clip."
    return false
  aegisub.set_undo_point "Cliptomaniac - Perspective to clip"
  true

ACTION_META = {
  {"Measure clip", "direct", "Shows the length and angle of the first two guide strokes inside a clip."}
  {"Measure & transform clip", "options", "Uses two guide strokes as a before and after ruler, then adds a size animation."}
  {"Adjust by clip scale", "options", "Uses two guide strokes as rulers and resizes the selected text values."}
  {"Rescale by rectangle clip", "options", "Resizes text tags to fit a rectangular clip. Vector clips are intentionally rejected."}
  {"FRZ stops for LerpByChar", "options", "Places rotation marks from guide strokes or from the clip path direction."}
  {"Clip to FRZ", "options", "Turns the first guide stroke into the line rotation."}
  {"Clip to FAX", "options", "Turns the first guide stroke into the line slant."}
  {"Clip to FAY", "options", "Turns the first vertical guide stroke into the line Y slant."}
  {"Clip to reposition", "options", "Moves the line by the distance and direction of the first guide stroke."}
  {"Clip to move", "options", "Changes a fixed position into movement using the first guide stroke."}
  {"Position at clip midpoint", "direct", "Moves selected lines to the middle of their clip path, or to the first selected clip."}
  {"Align to clip", "direct", "Moves the line position onto the nearest point of the clip path."}
  {"Autofit clip to text", "options", "Makes the clip fit around the visible text, with padding and section choices."}
  {"Create clip around text", "options", "Creates a new clip around the visible text, including tilted or perspective text."}
  {"Text to clip", "options", "Uses the actual text or drawing outline as the clip shape."}
  {"Expand clip margin", "options", "Grows or shrinks the selected clip by a pixel margin."}
  {"Shape to clip", "direct", "Uses the selected drawing as a clipping area."}
  {"Clip to shape", "direct", "Turns the first clip into an editable drawing."}
  {"Toggle clip/iclip", "direct", "Switches between showing inside the clip and hiding inside the clip."}
  {"Calibrate clip X", "direct", "Makes the first guide stroke perfectly horizontal."}
  {"Calibrate clip Y", "direct", "Makes the first guide stroke perfectly vertical."}
  {"Rectangle from diagonal", "direct", "Makes a rectangle from the first diagonal guide stroke."}
  {"Circle from 2 points", "direct", "Makes a circle using the first guide stroke as its diameter."}
  {"New clip shape", "direct", "Starts a new clip shape from the last point of the current clip path."}
  {"Copy clip/iclip", "direct", "Copies the first clip to matching selected lines, or from the first line to the rest."}
  {"Rect clip to vector", "direct", "Turns a simple rectangle clip into an editable path."}
  {"Vector clip to rect", "direct", "Turns an editable path clip into the smallest rectangle around it."}
  {"Add clip points", "options", "Adds points between existing clip points while preserving the current shape."}
  {"Remove clip points", "direct", "Removes alternating clip points while keeping each shape valid."}
  {"Clip to perspective", "options", "Uses a four-corner clip as the perspective plane for the line."}
  {"Perspective to clip", "direct", "Recreates a four-point clip from the stored perspective plane or current projected geometry."}
  {"Create strip clips", "options", "Splits a clip or text area into thin clipped copies."}
  {"Animated clip to FBF", "options", "Bakes a moving or transformed clipped line into frame-by-frame clipped lines."}
  {"Extract clip as mask line", "direct", "Creates a new drawing line from the first clip."}
  {"Clip boolean with text/shape", "options", "Combines the current clip with the selected text or drawing outline."}
  {"Clip diagnostics", "direct", "Shows clip type, size, points, and perspective-plane status."}
}

ACTION_HELP = {}
ACTION_DIRECT = {}
for item in *ACTION_META
  ACTION_HELP[item[1]] = item[3]
  ACTION_DIRECT[item[1]] = item[2] == "direct"

ACTION_HELP_ES = {
  ["Clip to FAY"]: "Convierte el primer trazo vertical guia en inclinacion Y de la linea."
  ["Add clip points"]: "Anade puntos entre los puntos del clip conservando la forma actual."
  ["Remove clip points"]: "Quita puntos alternos del clip conservando cada forma valida."
  ["Perspective to clip"]: "Recrea un clip de cuatro puntos desde el plano de perspectiva guardado o desde la geometria proyectada actual."
  ["Autofit clip to text"]: "Ajusta el clip alrededor del texto visible, con margen y opciones por secciones."
  ["Create clip around text"]: "Crea un clip nuevo alrededor del texto visible, incluyendo texto inclinado o en perspectiva."
  ["Text to clip"]: "Usa el texto real o el contorno del dibujo como forma del clip."
  ["Expand clip margin"]: "Crece o reduce el clip seleccionado por un margen en píxeles."
  ["Copy clip/iclip"]: "Copia el primer clip a líneas compatibles, o desde la primera línea al resto."
  ["Shape to clip"]: "Usa el dibujo seleccionado como área de clip."
  ["Clip to shape"]: "Convierte el primer clip en un dibujo editable."
  ["Toggle clip/iclip"]: "Alterna entre mostrar dentro del clip y ocultar dentro del clip."
  ["Rect clip to vector"]: "Convierte un clip rectangular simple en una ruta editable."
  ["Vector clip to rect"]: "Convierte una ruta editable en el rectángulo mínimo que la contiene."
  ["Clip boolean with text/shape"]: "Combina el clip actual con el texto o el contorno del dibujo seleccionado."
  ["Extract clip as mask line"]: "Crea una nueva línea de dibujo a partir del primer clip."
  ["Position at clip midpoint"]: "Mueve las líneas seleccionadas al centro de su clip, o al primer clip seleccionado."
  ["Align to clip"]: "Mueve la posición de la línea al punto más cercano de la ruta del clip."
  ["Clip to reposition"]: "Mueve la línea usando la distancia y dirección del primer trazo guía."
  ["Clip to move"]: "Convierte una posición fija en movimiento usando el primer trazo guía."
  ["Clip to FRZ"]: "Convierte el primer trazo guía en rotación de la línea."
  ["Clip to FAX"]: "Convierte el primer trazo guía en inclinación de la línea."
  ["Measure clip"]: "Muestra longitud y ángulo de los dos primeros trazos guía dentro de un clip."
  ["Measure & transform clip"]: "Usa dos trazos guía como regla de antes y después, y añade una animación de tamaño."
  ["Adjust by clip scale"]: "Usa dos trazos guía como regla y escala los valores de texto seleccionados."
  ["Rescale by rectangle clip"]: "Escala tags de texto para ajustarlos a un clip rectangular. Los clips vectoriales se rechazan."
  ["Clip to perspective"]: "Usa un clip de cuatro esquinas como plano de perspectiva para la línea."
  ["Create strip clips"]: "Divide un clip o área de texto en copias con franjas finas."
  ["Animated clip to FBF"]: "Hornea una línea con clip movido o transformado en líneas frame a frame."
  ["Calibrate clip X"]: "Endereza horizontalmente el primer trazo guía."
  ["Calibrate clip Y"]: "Endereza verticalmente el primer trazo guía."
  ["Rectangle from diagonal"]: "Crea un rectángulo desde el primer trazo diagonal."
  ["Circle from 2 points"]: "Crea un círculo usando el primer trazo como diámetro."
  ["New clip shape"]: "Empieza una forma de clip nueva desde el último punto de la ruta actual."
  ["FRZ stops for LerpByChar"]: "Coloca marcas de rotación desde trazos guía o desde la dirección de la ruta del clip."
  ["Clip diagnostics"]: "Muestra tipo, tamaño, puntos y estado de perspectiva del clip."
}

READ_ONLY_ACTIONS = {
  ["Measure clip"]: true
  ["Clip diagnostics"]: true
}

SECTION_AXES = {"Horizontal", "Vertical"}

Core.bool_option = (res, key) ->
  if res[key] == nil
    DEFAULTS[key] and true or false
  else
    res[key] and true or false

Core.normalize_options = (res = {}) ->
  opts = {}
  opts.operation = Core.normalize_operation res.operation
  strip_defaults = opts.operation == "Create strip clips"
  default_margin = if strip_defaults then 0 else DEFAULTS.margin
  default_style_pad = if strip_defaults then false else DEFAULTS.style_pad
  opts.axis = Core.enum_option res.axis, AXES, DEFAULTS.axis
  opts.angle_mode = Core.enum_option res.angle_mode, ANGLE_MODES, DEFAULTS.angle_mode
  opts.curve_source = Core.enum_option res.curve_source, CURVE_SOURCES, DEFAULTS.curve_source
  opts.tangent_stops = Core.clamp math.floor(tonumber(res.tangent_stops) or DEFAULTS.tangent_stops), 0, 256
  opts.autofit_mode = Core.enum_option res.autofit_mode, AUTOFIT_MODES, AUTOFIT_MODES[1]
  opts.rescale_rect_mode = Core.enum_option res.rescale_rect_mode, RESCALE_RECT_MODES, DEFAULTS.rescale_rect_mode
  opts.strip_mode = if Core.choice_raw(res.strip_mode) == "Vertical" then "Vertical" else "Horizontal"
  opts.margin = Core.clamp tonumber(res.margin) or default_margin, -500, 500
  opts.tolerance = Core.clamp tonumber(res.tolerance) or DEFAULTS.tolerance, 1, 80
  opts.strip = Core.clamp tonumber(res.strip) or DEFAULTS.strip, 1, 1000
  opts.sections = Core.clamp math.floor(tonumber(res.sections) or DEFAULTS.sections), 1, 64
  opts.section_index = Core.clamp math.floor(tonumber(res.section_index) or DEFAULTS.section_index), 1, 64
  opts.bleed = Core.clamp tonumber(res.bleed) or DEFAULTS.bleed, 0, 200
  opts.no_shrink = Core.bool_option res, "no_shrink"
  opts.recenter = Core.bool_option res, "recenter"
  opts.style_pad = if res.style_pad == nil then default_style_pad else Core.bool_option res, "style_pad"
  opts.replace_clip = Core.bool_option res, "replace_clip"
  opts.remove_clip = Core.bool_option res, "remove_clip"
  opts.create_new_lines = Core.bool_option res, "create_new_lines"
  opts.comment_source = Core.bool_option res, "comment_source"
  opts.point_mode = Core.enum_option res.point_mode, POINT_INSERT_MODES, DEFAULTS.point_mode
  opts.point_distance = Core.clamp tonumber(res.point_distance) or DEFAULTS.point_distance, 0.1, 10000
  opts.point_count = Core.clamp math.floor(tonumber(res.point_count) or DEFAULTS.point_count), 1, 1000
  opts.clip_type = Core.enum_option res.clip_type, CLIP_TYPES, DEFAULTS.clip_type
  opts.close_paths = Core.bool_option res, "close_paths"
  opts.merge_identical = Core.bool_option res, "merge_identical"
  opts.max_frames = Core.clamp math.floor(tonumber(res.max_frames) or DEFAULTS.max_frames), 1, 5000
  opts.fbf_source = Core.enum_option res.fbf_source, FBF_SOURCES, DEFAULTS.fbf_source
  opts.boolean_mode = Core.enum_option res.boolean_mode, BOOLEAN_MODES, DEFAULTS.boolean_mode
  opts.perspective_map = Core.normalize_perspective_map res.perspective_map
  opts.perspective_org_mode = Core.normalize_perspective_org res.perspective_org_mode
  opts.info = Core.bool_option res, "info"
  for key in *{"adj_fscx", "adj_fscy", "adj_fs", "adj_fsp", "adj_bord", "adj_shad", "adj_blur"}
    opts[key] = Core.bool_option res, key
  opts

Core.action_mode_label = (operation) ->
  if ACTION_DIRECT[operation] then Core.L("runs_now") else Core.L("opens_settings")

Core.action_help = (operation) ->
  if current_language == "es"
    ACTION_HELP_ES[operation] or ACTION_HELP[operation] or ""
  else
    ACTION_HELP[operation] or ""

Core.action_help_line = (operation) ->
  "[#{Core.action_mode_label operation}] #{Core.operation_label operation}: #{Core.action_help(operation)}"

CONTROL_HELP_ES = {
  ["Add clip points"]: {
    "Anadir por: elige distancia fija en pixeles o cantidad fija por tramo original."
    "Distancia: inserta puntos a este intervalo y deja el resto final antes del siguiente punto original."
    "Puntos: inserta esta cantidad de puntos equidistantes entre cada par de puntos originales."
  }
  ["Measure & transform clip"]: {
    "Eje: elige si la guía cambia ancho o alto."
    "Ángulo: decide si la guía también aplica rotación."
    "Mostrar reporte: muestra medidas después de aplicar."
  }
  ["Adjust by clip scale"]: {
    "Eje: elige ancho, alto o ambos."
    "fscx: escala el ancho del texto."
    "fscy: escala el alto del texto."
    "fs: escala el tamaño de fuente."
    "fsp: escala el espaciado."
    "bord: escala el borde."
    "shad: escala la sombra."
    "blur: escala blur y edge blur."
    "Mostrar reporte: muestra el porcentaje aplicado."
  }
  ["Rescale by rectangle clip"]: {
    "Modo: Encajar conserva todo dentro; Rellenar cubre el rectángulo; Estirar usa ancho y alto separados."
    "Centrar: mueve \\pos al ancla del rectángulo según la alineación."
    "Quitar clip guía: borra el clip rectangular después de usarlo."
    "ancho/alto: escala \\fscx y \\fscy."
    "espacio/borde/sombra/blur: escala esas dimensiones."
    "Los clips vectoriales se rechazan; usa primero un clip rectangular."
  }
  ["FRZ stops for LerpByChar"]: {
    "Fuente: elige si la rotación viene de dos trazos guía o de la dirección de la ruta."
    "Marcas: limita cuántas marcas de rotación se colocan. 0 usa la longitud del texto visible."
    "Quitar clip guía: borra el clip después de usarlo como guía."
  }
  ["Clip to FRZ"]: {"Quitar clip guía: borra el clip después de usarlo como guía."}
  ["Clip to FAX"]: {"Quitar clip guía: borra el clip después de usarlo como guía."}
  ["Clip to reposition"]: {"Quitar clip guía: borra el clip después de usarlo como guía."}
  ["Clip to move"]: {"Quitar clip guía: borra el clip después de usarlo como guía."}
  ["Clip to perspective"]: {
    "Esquinas: elige como se leen las cuatro esquinas del clip."
    "Origen: elige el ancla de la línea después de aplicar perspectiva."
    "Quitar clip guía: borra el clip después de usarlo como guía."
  }
  ["Autofit clip to text"]: {
    "Modo: elige que parte del texto debe cubrir el clip."
    "Eje: divide el texto de izquierda a derecha o de arriba a abajo."
    "Margen: suma o resta píxeles alrededor del clip."
    "Tolerancia: valores altos simplifican el resultado; valores bajos conservan más detalle."
    "Partes: cantidad de partes iguales."
    "Índice: parte que se usa en modo personalizado."
    "Solape: solapa partes vecinas para evitar huecos pequeños."
    "No reducir: nunca hace el clip nuevo menor que el anterior."
    "Incluir estilo: incluye borde, sombra y blur en el área."
  }
  ["Create clip around text"]: {
    "Margen: suma o resta píxeles alrededor del texto."
    "Tolerancia: valores altos simplifican clips de texto."
    "Incluir estilo: incluye borde, sombra y blur en el área."
    "Reemplazar clip: sobrescribe el primer clip existente."
  }
  ["Text to clip"]: {
    "Tipo: elige clip normal, inverse clip o conservar el actual."
    "Margen: suma o resta píxeles alrededor del contorno del texto."
    "Tolerancia: valores altos simplifican el contorno."
    "Cerrar rutas: conecta huecos del contorno al construir el clip."
    "Reemplazar clip: sobrescribe el primer clip existente."
    "Comentar original: deja apagada la línea original y crea una copia con clip."
  }
  ["Expand clip margin"]: {
    "Margen: valores positivos crecen el clip; negativos lo reducen."
    "Tolerancia: valores altos simplifican rutas editadas."
  }
  ["Create strip clips"]: {
    "Franjas: elige si las franjas cruzan horizontal o verticalmente. Detecta inclinación y perspectiva."
    "Tamaño: tamaño aproximado de cada franja en píxeles."
    "Crear líneas: crea una línea duplicada por franja."
    "Comentar original: conserva la original apagada al crear duplicados."
  }
  ["Animated clip to FBF"]: {
    "Hornear: elige si conserva toda la línea o solo copia el clip."
    "Frames max: límite de seguridad de líneas de salida."
    "Unir iguales: une frames vecinos cuando el clip final es idéntico."
    "Comentar original: conserva la línea original apagada."
  }
  ["Clip boolean with text/shape"]: {
    "Booleano: conserva solo la intersección o recorta la forma del texto del clip."
    "Tolerancia: valores altos simplifican el resultado."
    "Cerrar rutas: conecta contornos abiertos antes de combinar."
  }
}

Core.operation_control_help = (operation) ->
  return CONTROL_HELP_ES[operation] if current_language == "es" and CONTROL_HELP_ES[operation]
  switch operation
    when "Measure & transform clip"
      {
        "Axis: choose whether the ruler changes width or height."
        "Angle mode: choose if the guide also sets rotation."
        "Show report: show the measured sizes after applying."
      }
    when "Adjust by clip scale"
      {
        "Axis: choose width, height, or both."
        "fscx: resize the text width."
        "fscy: resize the text height."
        "fs: resize the font size."
        "fsp: resize letter spacing."
        "bord: resize the outline."
        "shad: resize the shadow."
        "blur: resize blur and edge blur."
        "Show report: show the percentage that was applied."
      }
    when "Rescale by rectangle clip"
      {
        "Mode: Fit keeps the whole text inside; Fill covers the rectangle; Stretch uses separate width and height factors."
        "Center: move \\pos to the rectangle anchor for the line alignment."
        "Remove guide clip: delete the rectangle clip after it has been used."
        "width/height: scale \\fscx and \\fscy."
        "spacing/outline/shadow/blur: scale those dimensions like Rhea's Rescale to Clip."
        "Vector clips are rejected. Use Rect clip to vector only after this operation, not before it."
      }
    when "FRZ stops for LerpByChar"
      {
        "Curve source: choose whether rotation comes from two guide strokes or the path direction."
        "Tangent stops: limit how many rotation marks are placed. 0 means use the visible text length."
        "Remove guide clip: delete the clip after it has been used as a guide."
      }
    when "Clip to FRZ", "Clip to FAX", "Clip to FAY", "Clip to reposition", "Clip to move"
      {
        "Remove guide clip: delete the clip after it has been used as a guide."
      }
    when "Clip to perspective"
      {
        "Corner order: choose how the four clip corners are read."
        "Origin: choose how the line anchor is chosen after the perspective is applied."
        "Remove guide clip: delete the clip after it has been used as a guide."
      }
    when "Autofit clip to text"
      {
        "Mode: choose which part of the text the new clip should cover."
        "Section axis: split the text from left to right or from top to bottom."
        "Margin: add or remove extra pixels around the fitted clip."
        "Tolerance: higher values make the result simpler; lower values keep more detail."
        "Sections: how many equal parts to split the text into."
        "Index: which part to use when Mode is Custom section."
        "Bleed: overlap between neighboring sections so tiny gaps do not appear."
        "No shrink: never make the new clip smaller than the old one."
        "Style pad: include outline, shadow, and blur in the fitted area."
      }
    when "Create clip around text"
      {
        "Margin: add or remove extra pixels around the text."
        "Tolerance: higher values make regular text clips simpler."
        "Style pad: include outline, shadow, and blur in the clipped area."
        "Replace existing clip: overwrite the first clip already on the line."
      }
    when "Text to clip"
      {
        "Clip type: choose normal clip, inverse clip, or keep the current kind."
        "Margin: add or remove extra pixels around the text outline."
        "Tolerance: higher values make the outline simpler."
        "Close paths: connect outline gaps when building the clip."
        "Replace existing clip: overwrite the first clip already on the line."
        "Comment source: keep the original line off and create a clipped copy."
      }
    when "Expand clip margin"
      {
        "Margin: positive values grow the clip; negative values shrink it."
        "Tolerance: higher values make edited paths simpler."
      }
    when "Add clip points"
      {
        "Add by: choose fixed pixel spacing or a fixed number of inserted points per original segment."
        "Distance: when adding by distance, insert points at this pixel interval and leave any final remainder before the next original point."
        "Points: when adding by count, insert this many evenly spaced points between each pair of original points."
      }
    when "Create strip clips"
      {
        "Strip mode: choose whether strips go across or down. Tilt and perspective are detected from the line."
        "Strip size: approximate pixel size of each strip."
        "Create new lines: make one duplicate line per strip."
        "Comment source: when creating duplicates, keep the original line but turn it off."
      }
    when "Animated clip to FBF"
      {
        "Bake source: choose whether to keep the whole baked line or only copy its clip."
        "Max frames: safety limit for how many output lines can be created."
        "Merge identical: join neighboring frames when their final clip is the same."
        "Comment source: keep the original line but turn it off."
      }
    when "Clip boolean with text/shape"
      {
        "Boolean mode: keep only the overlap, or cut the text shape out of the clip."
        "Tolerance: higher values make the result simpler."
        "Close paths: connect open outlines before combining."
      }
    else
      {}

Core.operation_help_text = (operation) ->
  lines = {
    "[#{Core.action_mode_label operation}] #{Core.operation_label operation}"
    ""
    Core.L("what_it_does")
    Core.action_help(operation)
  }
  controls = Core.operation_control_help operation
  lines[#lines + 1] = ""
  if #controls > 0
    lines[#lines + 1] = Core.L("controls")
    for line in *controls
      lines[#lines + 1] = line
  else
    lines[#lines + 1] = Core.L("controls")
    lines[#lines + 1] = Core.L("no_extra_controls")
  table.concat lines, "\n"

Core.picker_help_text = (operation) ->
  table.concat {
    Core.operation_help_text operation
    ""
    Core.L("picker_refresh")
    Core.L("picker_run")
  }, "\n"

Core.config_section = (operation) ->
  return "main" unless operation
  key = tostring(operation)\lower!
  key = key\gsub "[^%w]+", "_"
  "action_" .. key

Core.config_entries_for_gui = (gui) ->
  entries = {}
  for item in *(gui or {})
    if item.name
      item.config = true
      entries[item.name] = item
  entries

Core.language_entry = ->
  {class: "edit", name: "language", value: current_language, config: true}

Core.add_language_entry = (entries) ->
  entries.language = Core.language_entry!
  entries

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

Core.config_interface = (section, gui) ->
  interface = {}
  interface.main = Core.add_language_entry Core.config_entries_for_gui(Core.action_picker_gui(DEFAULTS.operation))
  for operation in *OPERATIONS
    continue if ACTION_DIRECT[operation]
    op_section = Core.config_section operation
    interface[op_section] = Core.config_entries_for_gui Core.options_gui(operation)
  if section and gui
    entries = Core.config_entries_for_gui gui
    entries = Core.add_language_entry entries if section == "main"
    interface[section] = entries
  interface

Core.read_configured_gui = (section, gui) ->
  Core.load_language!
  return nil unless ConfigHandler
  interface = Core.config_interface section, gui
  ok, options = pcall -> ConfigHandler interface, CONFIG_FILE, true, script_version
  unless ok and options
    Core.warn "ConfigHandler failed for #{section}: #{options}"
    return nil
  ok_read, err_read = pcall -> options\read!
  Core.warn "Could not read config for #{section}: #{err_read}" unless ok_read
  lang = options.configuration and options.configuration.main and options.configuration.main.language
  current_language = Core.valid_language lang
  ok_update, err_update = pcall -> options\updateInterface section
  Core.warn "Could not apply config for #{section}: #{err_update}" unless ok_update
  Core.localize_dropdown_values gui
  options

Core.save_configured_gui = (options, result, section) ->
  return true unless options and result
  ok, err = pcall ->
    options.configuration.main.language = current_language if options.configuration and options.configuration.main
    result.language = current_language if section == "main"
    options\updateConfiguration result, section
    options\write!
  Core.warn "Could not save config for #{section}: #{err}" unless ok
  ok

Core.control_value = (gui, name, fallback = nil) ->
  for item in *(gui or {})
    return item.value if item.name == name and item.value != nil
  fallback

Core.localize_dropdown_values = (gui) ->
  for item in *(gui or {})
    if item.class == "dropdown" and item.value != nil and item.items
      raw = Core.choice_raw item.value
      shown = Core.choice_label raw
      if shown != item.value
        for candidate in *item.items
          if candidate == shown
            item.value = shown
            break
  gui

WINDOW_W = 24
PICKER_HELP_H = 16
OPTION_HELP_H = 16
OPTION_Y_SHIFT = 17

Core.action_picker_gui = (operation) ->
  items, to_raw, to_shown = Core.dropdown_data OPERATIONS, Core.operation_label
  gui = {
    {class: "label", label: Core.L("action"), x: 0, y: 0, width: 3}
    {class: "dropdown", name: "operation", items: items, value: Core.shown_choice(to_shown, operation or DEFAULTS.operation), x: 3, y: 0, width: WINDOW_W - 3}
    {class: "textbox", value: Core.picker_help_text(operation or DEFAULTS.operation), x: 0, y: 1, width: WINDOW_W, height: PICKER_HELP_H}
  }
  gui, to_raw, to_shown

Core.action_picker = ->
  Core.UI.chooseAction {
    current: DEFAULTS.operation
    build: (current) ->
      Core.load_language!
      gui, to_raw, to_shown = Core.action_picker_gui current
      options = Core.read_configured_gui "main", gui
      selected = Core.raw_operation_choice to_raw, Core.control_value(gui, "operation", Core.shown_choice(to_shown, current))
      gui[2].value = Core.shown_choice to_shown, selected
      gui[3].value = Core.picker_help_text selected
      gui, {to_raw: to_raw, options: options}
    buttons: ->
      run, help, language, cancel = Core.L("run"), Core.L("help"), Core.L("language"), Core.L("cancel")
      {run: run, help: help, language: language, cancel: cancel, order: {run, help, language, cancel}}
    read: (result, current, context) ->
      Core.raw_operation_choice context.to_raw, result and result.operation or current
    on_help: (chosen, _result, context) ->
      Core.save_configured_gui context.options, {operation: chosen}, "main"
    on_language: -> Core.toggle_language!
    on_run: (_chosen, result, context) ->
      Core.save_configured_gui context.options, result, "main"
  }

Core.action_help_picker = ->
  current = DEFAULTS.operation
  while true
    Core.load_language!
    gui, to_raw, to_shown = Core.action_picker_gui current
    options = Core.read_configured_gui "main", gui
    current = Core.raw_operation_choice to_raw, Core.control_value(gui, "operation", Core.shown_choice(to_shown, current))
    gui[2].value = Core.shown_choice to_shown, current
    gui[3].value = Core.picker_help_text current
    btn_help, btn_language, btn_close = Core.L("help"), Core.L("language"), Core.L("close")
    button, res = aegisub.dialog.display gui, {btn_help, btn_language, btn_close}, {ok: btn_help, close: btn_close}
    if button == btn_help
      chosen = Core.raw_operation_choice to_raw, res and res.operation or current
      Core.save_configured_gui options, {operation: chosen}, "main"
      current = chosen
    elseif button == btn_language
      current = Core.raw_operation_choice to_raw, res and res.operation or current
      Core.toggle_language!
    else
      return

Core.base_option_gui = (operation, detailed_help = false) ->
  help_value = Core.operation_help_text operation
  {
    {class: "label", label: Core.operation_label(operation), x: 0, y: 0, width: WINDOW_W}
    {class: "textbox", value: help_value, x: 0, y: 1, width: WINDOW_W, height: OPTION_HELP_H}
  }

Core.add_remove_clip = (gui, y) ->
  gui[#gui + 1] = {class: "checkbox", name: "remove_clip", label: Core.L("remove_guide_clip"), value: DEFAULTS.remove_clip, x: 0, y: y, width: 6}

Core.shift_option_controls = (gui, first_index, amount) ->
  for idx = first_index, #gui
    gui[idx].y += amount if gui[idx] and gui[idx].y
  gui

Core.options_gui = (operation, detailed_help = false) ->
  gui = Core.base_option_gui operation, detailed_help
  control_start = #gui + 1
  switch operation
    when "Measure & transform clip"
      gui[#gui + 1] = {class: "label", label: Core.L("axis"), x: 0, y: 4, width: 3}
      gui[#gui + 1] = {class: "dropdown", name: "axis", items: Core.localized_items({"x", "y"}), value: Core.choice_label("x"), x: 3, y: 4, width: 5}
      gui[#gui + 1] = {class: "label", label: Core.L("angle_mode"), x: 0, y: 5, width: 3}
      gui[#gui + 1] = {class: "dropdown", name: "angle_mode", items: Core.localized_items(ANGLE_MODES), value: Core.choice_label(DEFAULTS.angle_mode), x: 3, y: 5, width: 8}
      gui[#gui + 1] = {class: "checkbox", name: "info", label: Core.L("show_report"), value: DEFAULTS.info, x: 0, y: 6, width: 5}
    when "Adjust by clip scale"
      gui[#gui + 1] = {class: "label", label: Core.L("axis"), x: 0, y: 4, width: 3}
      gui[#gui + 1] = {class: "dropdown", name: "axis", items: Core.localized_items(AXES), value: Core.choice_label(DEFAULTS.axis), x: 3, y: 4, width: 5}
      gui[#gui + 1] = {class: "label", label: Core.L("resize"), x: 0, y: 5, width: 3}
      gui[#gui + 1] = {class: "checkbox", name: "adj_fscx", label: Core.L("width"), value: DEFAULTS.adj_fscx, x: 3, y: 5, width: 3}
      gui[#gui + 1] = {class: "checkbox", name: "adj_fscy", label: Core.L("height"), value: DEFAULTS.adj_fscy, x: 6, y: 5, width: 3}
      gui[#gui + 1] = {class: "checkbox", name: "adj_fs", label: Core.L("font"), value: DEFAULTS.adj_fs, x: 9, y: 5, width: 3}
      gui[#gui + 1] = {class: "checkbox", name: "adj_fsp", label: Core.L("spacing"), value: DEFAULTS.adj_fsp, x: 12, y: 5, width: 4}
      gui[#gui + 1] = {class: "checkbox", name: "adj_bord", label: Core.L("outline"), value: DEFAULTS.adj_bord, x: 3, y: 6, width: 4}
      gui[#gui + 1] = {class: "checkbox", name: "adj_shad", label: Core.L("shadow"), value: DEFAULTS.adj_shad, x: 7, y: 6, width: 4}
      gui[#gui + 1] = {class: "checkbox", name: "adj_blur", label: Core.L("blur"), value: DEFAULTS.adj_blur, x: 11, y: 6, width: 3}
      gui[#gui + 1] = {class: "checkbox", name: "info", label: Core.L("show_report"), value: DEFAULTS.info, x: 0, y: 7, width: 5}
    when "Rescale by rectangle clip"
      gui[#gui + 1] = {class: "label", label: Core.L("mode"), x: 0, y: 4, width: 3}
      gui[#gui + 1] = {class: "dropdown", name: "rescale_rect_mode", items: Core.localized_items(RESCALE_RECT_MODES), value: Core.choice_label(DEFAULTS.rescale_rect_mode), x: 3, y: 4, width: 9}
      gui[#gui + 1] = {class: "label", label: Core.L("scale"), x: 0, y: 5, width: 3}
      gui[#gui + 1] = {class: "checkbox", name: "adj_fscx", label: Core.L("width"), value: DEFAULTS.adj_fscx, x: 3, y: 5, width: 3}
      gui[#gui + 1] = {class: "checkbox", name: "adj_fscy", label: Core.L("height"), value: DEFAULTS.adj_fscy, x: 6, y: 5, width: 3}
      gui[#gui + 1] = {class: "checkbox", name: "adj_fsp", label: Core.L("spacing"), value: DEFAULTS.adj_fsp, x: 9, y: 5, width: 4}
      gui[#gui + 1] = {class: "checkbox", name: "adj_bord", label: Core.L("outline"), value: DEFAULTS.adj_bord, x: 3, y: 6, width: 4}
      gui[#gui + 1] = {class: "checkbox", name: "adj_shad", label: Core.L("shadow"), value: DEFAULTS.adj_shad, x: 7, y: 6, width: 4}
      gui[#gui + 1] = {class: "checkbox", name: "adj_blur", label: Core.L("blur"), value: DEFAULTS.adj_blur, x: 11, y: 6, width: 3}
      gui[#gui + 1] = {class: "checkbox", name: "recenter", label: Core.L("center"), value: DEFAULTS.recenter, x: 0, y: 7, width: 4}
      Core.add_remove_clip gui, 8
      gui[#gui + 1] = {class: "checkbox", name: "info", label: Core.L("show_report"), value: DEFAULTS.info, x: 6, y: 8, width: 5}
    when "FRZ stops for LerpByChar"
      gui[#gui + 1] = {class: "label", label: Core.L("curve_source"), x: 0, y: 4, width: 4}
      gui[#gui + 1] = {class: "dropdown", name: "curve_source", items: Core.localized_items(CURVE_SOURCES), value: Core.choice_label(DEFAULTS.curve_source), x: 4, y: 4, width: 7}
      gui[#gui + 1] = {class: "label", label: Core.L("tangent_stops"), x: 0, y: 5, width: 4}
      gui[#gui + 1] = {class: "intedit", name: "tangent_stops", value: DEFAULTS.tangent_stops, min: 0, max: 256, x: 4, y: 5, width: 3}
      Core.add_remove_clip gui, 6
    when "Clip to FRZ", "Clip to FAX", "Clip to FAY", "Clip to reposition", "Clip to move"
      Core.add_remove_clip gui, 4
    when "Clip to perspective"
      gui[#gui + 1] = {class: "label", label: Core.L("corner_order"), x: 0, y: 4, width: 4}
      gui[#gui + 1] = {class: "dropdown", name: "perspective_map", items: Core.localized_items(PerspectiveTools.map_items!), value: Core.choice_label(DEFAULTS.perspective_map), x: 4, y: 4, width: 9}
      gui[#gui + 1] = {class: "label", label: Core.L("origin"), x: 0, y: 5, width: 4}
      gui[#gui + 1] = {class: "dropdown", name: "perspective_org_mode", items: Core.localized_items(PERSPECTIVE_DATA.org_modes), value: Core.choice_label(DEFAULTS.perspective_org_mode), x: 4, y: 5, width: 9}
      Core.add_remove_clip gui, 6
    when "Autofit clip to text"
      gui[#gui + 1] = {class: "label", label: Core.L("mode"), x: 0, y: 4, width: 3}
      gui[#gui + 1] = {class: "dropdown", name: "autofit_mode", items: Core.localized_items(AUTOFIT_MODES), value: Core.choice_label(AUTOFIT_MODES[1]), x: 3, y: 4, width: 10}
      gui[#gui + 1] = {class: "label", label: Core.L("section_axis"), x: 0, y: 5, width: 3}
      gui[#gui + 1] = {class: "dropdown", name: "strip_mode", items: Core.localized_items(SECTION_AXES), value: Core.choice_label("Horizontal"), x: 3, y: 5, width: 6}
      gui[#gui + 1] = {class: "label", label: Core.L("margin"), x: 0, y: 6, width: 3}
      gui[#gui + 1] = {class: "floatedit", name: "margin", value: DEFAULTS.margin, min: -500, max: 500, x: 3, y: 6, width: 3}
      gui[#gui + 1] = {class: "label", label: Core.L("tolerance"), x: 7, y: 6, width: 3}
      gui[#gui + 1] = {class: "floatedit", name: "tolerance", value: DEFAULTS.tolerance, min: 1, max: 80, x: 10, y: 6, width: 3}
      gui[#gui + 1] = {class: "label", label: Core.L("sections"), x: 0, y: 7, width: 3}
      gui[#gui + 1] = {class: "intedit", name: "sections", value: DEFAULTS.sections, min: 1, max: 64, x: 3, y: 7, width: 3}
      gui[#gui + 1] = {class: "label", label: Core.L("index"), x: 7, y: 7, width: 2}
      gui[#gui + 1] = {class: "intedit", name: "section_index", value: DEFAULTS.section_index, min: 1, max: 64, x: 9, y: 7, width: 3}
      gui[#gui + 1] = {class: "label", label: Core.L("bleed"), x: 13, y: 7, width: 2}
      gui[#gui + 1] = {class: "floatedit", name: "bleed", value: DEFAULTS.bleed, min: 0, max: 200, x: 15, y: 7, width: 3}
      gui[#gui + 1] = {class: "checkbox", name: "no_shrink", label: Core.L("no_shrink"), value: DEFAULTS.no_shrink, x: 0, y: 8, width: 4}
      gui[#gui + 1] = {class: "checkbox", name: "style_pad", label: Core.L("style_pad"), value: DEFAULTS.style_pad, x: 4, y: 8, width: 4}
    when "Create clip around text"
      gui[#gui + 1] = {class: "label", label: Core.L("margin"), x: 0, y: 4, width: 3}
      gui[#gui + 1] = {class: "floatedit", name: "margin", value: DEFAULTS.margin, min: -500, max: 500, x: 3, y: 4, width: 3}
      gui[#gui + 1] = {class: "label", label: Core.L("tolerance"), x: 7, y: 4, width: 3}
      gui[#gui + 1] = {class: "floatedit", name: "tolerance", value: DEFAULTS.tolerance, min: 1, max: 80, x: 10, y: 4, width: 3}
      gui[#gui + 1] = {class: "checkbox", name: "style_pad", label: Core.L("style_pad"), value: DEFAULTS.style_pad, x: 0, y: 5, width: 4}
      gui[#gui + 1] = {class: "checkbox", name: "replace_clip", label: Core.L("replace_existing_clip"), value: DEFAULTS.replace_clip, x: 4, y: 5, width: 7}
    when "Text to clip"
      gui[#gui + 1] = {class: "label", label: Core.L("clip_type"), x: 0, y: 4, width: 3}
      gui[#gui + 1] = {class: "dropdown", name: "clip_type", items: Core.localized_items(CLIP_TYPES), value: Core.choice_label(DEFAULTS.clip_type), x: 3, y: 4, width: 5}
      gui[#gui + 1] = {class: "label", label: Core.L("margin"), x: 9, y: 4, width: 3}
      gui[#gui + 1] = {class: "floatedit", name: "margin", value: DEFAULTS.margin, min: -500, max: 500, x: 12, y: 4, width: 3}
      gui[#gui + 1] = {class: "label", label: Core.L("tolerance"), x: 0, y: 5, width: 3}
      gui[#gui + 1] = {class: "floatedit", name: "tolerance", value: DEFAULTS.tolerance, min: 1, max: 80, x: 3, y: 5, width: 3}
      gui[#gui + 1] = {class: "checkbox", name: "close_paths", label: Core.L("close_paths"), value: DEFAULTS.close_paths, x: 0, y: 6, width: 5}
      gui[#gui + 1] = {class: "checkbox", name: "replace_clip", label: Core.L("replace_existing_clip"), value: DEFAULTS.replace_clip, x: 5, y: 6, width: 7}
      gui[#gui + 1] = {class: "checkbox", name: "comment_source", label: Core.L("comment_source"), value: DEFAULTS.comment_source, x: 0, y: 7, width: 6}
    when "Expand clip margin"
      gui[#gui + 1] = {class: "label", label: Core.L("margin"), x: 0, y: 4, width: 3}
      gui[#gui + 1] = {class: "floatedit", name: "margin", value: DEFAULTS.margin, min: -500, max: 500, x: 3, y: 4, width: 3}
      gui[#gui + 1] = {class: "label", label: Core.L("tolerance"), x: 0, y: 5, width: 3}
      gui[#gui + 1] = {class: "floatedit", name: "tolerance", value: DEFAULTS.tolerance, min: 1, max: 80, x: 3, y: 5, width: 3}
    when "Add clip points"
      gui[#gui + 1] = {class: "label", label: Core.L("point_mode"), x: 0, y: 4, width: 4}
      gui[#gui + 1] = {class: "dropdown", name: "point_mode", items: Core.localized_items(POINT_INSERT_MODES), value: Core.choice_label(DEFAULTS.point_mode), x: 4, y: 4, width: 7}
      gui[#gui + 1] = {class: "label", label: Core.L("point_distance"), x: 0, y: 5, width: 4}
      gui[#gui + 1] = {class: "floatedit", name: "point_distance", value: DEFAULTS.point_distance, min: 0.1, max: 10000, x: 4, y: 5, width: 4}
      gui[#gui + 1] = {class: "label", label: Core.L("point_count"), x: 0, y: 6, width: 4}
      gui[#gui + 1] = {class: "intedit", name: "point_count", value: DEFAULTS.point_count, min: 1, max: 1000, x: 4, y: 6, width: 4}
    when "Create strip clips"
      gui[#gui + 1] = {class: "label", label: Core.L("strip_mode"), x: 0, y: 4, width: 4}
      gui[#gui + 1] = {class: "dropdown", name: "strip_mode", items: Core.localized_items(STRIP_MODES), value: Core.choice_label(DEFAULTS.strip_mode), x: 4, y: 4, width: 6}
      gui[#gui + 1] = {class: "label", label: Core.L("strip_size"), x: 0, y: 5, width: 4}
      gui[#gui + 1] = {class: "floatedit", name: "strip", value: DEFAULTS.strip, min: 1, max: 1000, x: 4, y: 5, width: 3}
      gui[#gui + 1] = {class: "checkbox", name: "create_new_lines", label: Core.L("create_new_lines"), value: DEFAULTS.create_new_lines, x: 0, y: 6, width: 6}
      gui[#gui + 1] = {class: "checkbox", name: "comment_source", label: Core.L("comment_source"), value: DEFAULTS.comment_source, x: 6, y: 6, width: 6}
    when "Animated clip to FBF"
      gui[#gui + 1] = {class: "label", label: Core.L("bake_source"), x: 0, y: 4, width: 4}
      gui[#gui + 1] = {class: "dropdown", name: "fbf_source", items: Core.localized_items(FBF_SOURCES), value: Core.choice_label(DEFAULTS.fbf_source), x: 4, y: 4, width: 6}
      gui[#gui + 1] = {class: "label", label: Core.L("max_frames"), x: 0, y: 5, width: 4}
      gui[#gui + 1] = {class: "intedit", name: "max_frames", value: DEFAULTS.max_frames, min: 1, max: 5000, x: 4, y: 5, width: 4}
      gui[#gui + 1] = {class: "checkbox", name: "merge_identical", label: Core.L("merge_identical"), value: DEFAULTS.merge_identical, x: 0, y: 6, width: 6}
      gui[#gui + 1] = {class: "checkbox", name: "comment_source", label: Core.L("comment_source"), value: DEFAULTS.comment_source, x: 6, y: 6, width: 6}
    when "Clip boolean with text/shape"
      gui[#gui + 1] = {class: "label", label: Core.L("boolean_mode"), x: 0, y: 4, width: 4}
      gui[#gui + 1] = {class: "dropdown", name: "boolean_mode", items: Core.localized_items(BOOLEAN_MODES), value: Core.choice_label(DEFAULTS.boolean_mode), x: 4, y: 4, width: 8}
      gui[#gui + 1] = {class: "label", label: Core.L("tolerance"), x: 0, y: 5, width: 3}
      gui[#gui + 1] = {class: "floatedit", name: "tolerance", value: DEFAULTS.tolerance, min: 1, max: 80, x: 3, y: 5, width: 3}
      gui[#gui + 1] = {class: "checkbox", name: "close_paths", label: Core.L("close_paths"), value: DEFAULTS.close_paths, x: 0, y: 6, width: 5}
  Core.shift_option_controls gui, control_start, OPTION_Y_SHIFT

Core.show_action_options = (operation) ->
  return Core.normalize_options {operation: operation} if ACTION_DIRECT[operation]
  section = Core.config_section operation
  while true
    gui = Core.options_gui operation, true
    options = Core.read_configured_gui section, gui
    button, res = aegisub.dialog.display gui, {Core.L("apply"), Core.L("cancel")}, {ok: Core.L("apply"), close: Core.L("cancel")}
    if button == Core.L("apply")
      Core.save_configured_gui options, res, section
      res.operation = operation
      return Core.normalize_options res
    else
      return nil

Core.dispatch = (subs, sel, active, opts) ->
  switch opts.operation
    when "Measure clip" then Core.op_measure subs, sel, opts
    when "Measure & transform clip" then Core.op_measure_transform subs, sel, opts
    when "Adjust by clip scale" then Core.op_adjust_by_clip_scale subs, sel, opts
    when "Rescale by rectangle clip" then Core.op_rescale_by_rectangle_clip subs, sel, opts
    when "FRZ stops for LerpByChar" then Core.op_frz_lerp_stops subs, sel, opts
    when "Clip to FRZ" then Core.op_clip_to_frz subs, sel, opts
    when "Clip to FAX" then Core.op_clip_to_fax subs, sel, opts
    when "Clip to FAY" then Core.op_clip_to_fay subs, sel, opts
    when "Clip to reposition" then Core.op_clip_to_reposition subs, sel, opts
    when "Clip to move" then Core.op_clip_to_move subs, sel, opts
    when "Position at clip midpoint" then Core.op_position_at_clip_midpoint subs, sel, opts
    when "Align to clip" then Core.op_align_to_clip subs, sel, opts
    when "Autofit clip to text" then Core.op_autofit_clip subs, sel, active, opts
    when "Create clip around text" then Core.op_create_text_clip subs, sel, active, opts
    when "Text to clip" then Core.op_text_to_clip subs, sel, active, opts
    when "Expand clip margin" then Core.op_expand_clip_margin subs, sel, opts
    when "Shape to clip" then Core.op_shape_to_clip subs, sel, active, opts
    when "Clip to shape" then Core.op_clip_to_shape subs, sel, opts
    when "Toggle clip/iclip" then Core.op_hotkey subs, sel, "Toggle clip/iclip", opts
    when "Calibrate clip X" then Core.op_hotkey subs, sel, "Calibrate clip X", opts
    when "Calibrate clip Y" then Core.op_hotkey subs, sel, "Calibrate clip Y", opts
    when "Rectangle from diagonal" then Core.op_hotkey subs, sel, "Rectangle from diagonal", opts
    when "Circle from 2 points" then Core.op_hotkey subs, sel, "Circle from 2 points", opts
    when "New clip shape" then Core.op_hotkey subs, sel, "New clip shape", opts
    when "Copy clip/iclip" then Core.op_copy_clip subs, sel, opts
    when "Rect clip to vector" then Core.op_hotkey subs, sel, "Rect clip to vector", opts
    when "Vector clip to rect" then Core.op_hotkey subs, sel, "Vector clip to rect", opts
    when "Add clip points" then Core.op_hotkey subs, sel, "Add clip points", opts
    when "Remove clip points" then Core.op_hotkey subs, sel, "Remove clip points", opts
    when "Clip to perspective" then Core.op_clip_to_perspective subs, sel, opts
    when "Perspective to clip" then Core.op_perspective_to_clip subs, sel, opts
    when "Create strip clips" then Core.op_create_strip_clips subs, sel, active, opts
    when "Animated clip to FBF" then Core.op_animated_clip_to_fbf subs, sel, active, opts
    when "Extract clip as mask line" then Core.op_extract_clip_as_mask subs, sel, opts
    when "Clip boolean with text/shape" then Core.op_clip_boolean subs, sel, active, opts
    when "Clip diagnostics" then Core.op_clip_diagnostics subs, sel, opts
    else false

Core.run_operation = (subs, sel, active, operation) ->
  unless sel and #sel > 0
    Core.show_message Core.L("select_one")
    aegisub.cancel!
  Core.enrich_selected_lines subs, sel unless READ_ONLY_ACTIONS[operation]
  opts = Core.show_action_options operation
  return nil unless opts
  ok = Core.dispatch subs, sel, active, opts
  aegisub.cancel! unless ok
  ok

Core.main = (subs, sel, active) ->
  while true
    operation = Core.action_picker!
    return unless operation
    result = Core.run_operation subs, sel, active, operation
    return result if result != nil

Core.validate = (subs, sel) -> sel and #sel > 0

Core.validate_any = -> true

Core.action_macro = (operation) ->
  (subs, sel, active) ->
    Core.run_operation subs, sel, active, operation

Core.hotkey_menu_path = (operation) ->
  HOTKEY_MENU_ROOT .. "/" .. HOTKEY_MENU_SCRIPT .. "/" .. operation

Core.help_macro = ->
  Core.action_help_picker!

Core.load_language!

register_macro = (name, description, process, validate) ->
  if depctrl and depctrl.registerMacro
    depctrl\registerMacro name, description, process, validate, nil, false
  else
    aegisub.register_macro name, description, process, validate

register_macro "Cliptomaniac", script_description, Core.main, Core.validate
register_macro "Cliptomaniac/Help", "Show the Cliptomaniac action help.", Core.help_macro, Core.validate_any
for operation in *OPERATIONS
  register_macro Core.hotkey_menu_path(operation), Core.action_help(operation), Core.action_macro(operation), Core.validate
