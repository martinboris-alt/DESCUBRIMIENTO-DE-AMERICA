extends CanvasLayer

var _compass_label: Label
var _player: CharacterBody3D

func _ready() -> void:
	_build_ui()
	_player = get_tree().get_first_node_in_group("player")

func _process(_delta: float) -> void:
	if _player and _compass_label:
		_compass_label.text = _get_compass(_player.rotation.y)

func _get_compass(rad: float) -> String:
	var deg := fmod(rad_to_deg(-rad) + 360.0, 360.0)
	var dirs := ["N", "NE", "E", "SE", "S", "SO", "O", "NO"]
	var idx := int(round(deg / 45.0)) % 8
	return "%s  %.0f°" % [dirs[idx], deg]

func _label(txt: String, pos: Vector2, size: int, col: Color, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = txt
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if bold:
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		l.add_theme_constant_override("outline_size", 3)
	add_child(l)
	return l

func _panel(pos: Vector2, size: Vector2, col: Color) -> ColorRect:
	var r := ColorRect.new()
	r.position = pos
	r.size = size
	r.color = col
	add_child(r)
	return r

func _build_ui() -> void:
	var gold  := Color(1.00, 0.84, 0.35)
	var cream := Color(0.95, 0.88, 0.72)
	var white := Color(1.00, 1.00, 1.00, 0.85)
	var dark  := Color(0.0, 0.0, 0.0, 0.55)

	# --- Top-left title panel ---
	_panel(Vector2(14, 14), Vector2(280, 58), dark)
	_label("CONQUISTA DE AMÉRICA", Vector2(22, 18), 17, gold, true)
	_label("Hernán Cortés · Año 1519 · Nueva España", Vector2(22, 42), 11, cream)

	# --- Top-right compass panel ---
	_panel(Vector2(get_viewport().get_visible_rect().size.x - 154, 14), Vector2(140, 42), dark)
	_compass_label = _label("N  0°", Vector2(get_viewport().get_visible_rect().size.x - 146, 22), 15, white, true)

	# --- Centre crosshair ---
	var vp := get_viewport().get_visible_rect().size
	_label("·", vp / 2.0 - Vector2(4, 10), 22, Color(1, 1, 1, 0.7))

	# --- Bottom hint bar ---
	_panel(Vector2(0, get_viewport().get_visible_rect().size.y - 34), Vector2(get_viewport().get_visible_rect().size.x, 34), Color(0, 0, 0, 0.45))
	_label("WASD · Mover    Ratón · Cámara    Espacio · Saltar    Esc · Cursor", Vector2(20, get_viewport().get_visible_rect().size.y - 26), 11, Color(0.8, 0.8, 0.8, 0.75))
