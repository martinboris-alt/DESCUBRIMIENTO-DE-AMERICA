extends CanvasLayer
## Controles táctiles para Android/iOS: joystick virtual en la mitad
## izquierda y botones de SALTO y GIRO a la derecha. Solo se muestra en
## dispositivos con pantalla táctil.

const STICK_RADIUS := 95.0
const DEAD_ZONE := 0.18

var _stick_id := -1
var _stick_origin := Vector2.ZERO
var _stick_vec := Vector2.ZERO
var _btn_touches := {}  # action -> índice de toque

var _canvas: Control
var _buttons := {}  # action -> {pos, r, label}


func _ready() -> void:
	if not DisplayServer.is_touchscreen_available():
		visible = false
		set_process_input(false)
		return
	layer = 50
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_on_draw)
	add_child(_canvas)

	var vp := _canvas.get_viewport_rect().size
	_buttons["jump"] = {"pos": Vector2(vp.x - 120, vp.y - 150), "r": 68.0, "label": "SALTO"}
	_buttons["attack"] = {"pos": Vector2(vp.x - 290, vp.y - 105), "r": 58.0, "label": "GIRO"}


func _process(_delta: float) -> void:
	if _canvas:
		_canvas.queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_down(event.index, event.position)
		else:
			_touch_up(event.index)
	elif event is InputEventScreenDrag and event.index == _stick_id:
		_update_stick(event.position)


func _touch_down(idx: int, pos: Vector2) -> void:
	for action in _buttons:
		var b: Dictionary = _buttons[action]
		if pos.distance_to(b.pos) <= b.r * 1.35 and action not in _btn_touches:
			_btn_touches[action] = idx
			Input.action_press(action)
			return
	var vp := _canvas.get_viewport_rect().size
	if pos.x < vp.x * 0.48 and _stick_id == -1:
		_stick_id = idx
		_stick_origin = pos
		_stick_vec = Vector2.ZERO


func _touch_up(idx: int) -> void:
	if idx == _stick_id:
		_stick_id = -1
		_stick_vec = Vector2.ZERO
		for a in ["move_left", "move_right", "move_forward", "move_back"]:
			Input.action_release(a)
	for action in _btn_touches.keys():
		if _btn_touches[action] == idx:
			_btn_touches.erase(action)
			Input.action_release(action)


func _update_stick(pos: Vector2) -> void:
	var v := (pos - _stick_origin) / STICK_RADIUS
	if v.length() > 1.0:
		v = v.normalized()
	if v.length() < DEAD_ZONE:
		v = Vector2.ZERO
	_stick_vec = v
	Input.action_press("move_right", maxf(v.x, 0.0))
	Input.action_press("move_left", maxf(-v.x, 0.0))
	Input.action_press("move_back", maxf(v.y, 0.0))
	Input.action_press("move_forward", maxf(-v.y, 0.0))


func _on_draw() -> void:
	var col_base := Color(1, 1, 1, 0.14)
	var col_ring := Color(1, 1, 1, 0.35)
	var vp := _canvas.get_viewport_rect().size
	var origin := _stick_origin if _stick_id != -1 else Vector2(170, vp.y - 170)
	_canvas.draw_circle(origin, STICK_RADIUS, col_base)
	_canvas.draw_arc(origin, STICK_RADIUS, 0, TAU, 40, col_ring, 3.0)
	_canvas.draw_circle(origin + _stick_vec * STICK_RADIUS * 0.6, 38.0, Color(1, 1, 1, 0.4))

	var font := ThemeDB.fallback_font
	for action in _buttons:
		var b: Dictionary = _buttons[action]
		var pressed: bool = action in _btn_touches
		_canvas.draw_circle(b.pos, b.r, Color(1, 0.8, 0.2, 0.32) if pressed else col_base)
		_canvas.draw_arc(b.pos, b.r, 0, TAU, 32, col_ring, 3.0)
		var sz: Vector2 = font.get_string_size(b.label, HORIZONTAL_ALIGNMENT_CENTER, -1, 20)
		_canvas.draw_string(font, b.pos - Vector2(sz.x / 2.0, -7),
			b.label, HORIZONTAL_ALIGNMENT_CENTER, -1, 20, Color(1, 1, 1, 0.75))
