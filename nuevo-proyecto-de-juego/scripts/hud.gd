extends CanvasLayer
## HUD arcade: monedas, ídolos, máscaras, corazones, vidas, barra del
## jefe, mensajes y pantallas de intro/historia, fin de nivel, game over
## y victoria final. Diseñado a 1280x720.

const W := 1280.0
const H := 720.0
const GOLD := Color(1.0, 0.82, 0.25)
const CREAM := Color(0.96, 0.92, 0.8)
const JADE := Color(0.3, 0.9, 0.55)

var _coin_label: Label
var _lives_label: Label
var _hearts: Array[Polygon2D] = []
var _idol_slots: Array[Polygon2D] = []
var _mask_slots: Array[Polygon2D] = []
var _msg_label: Label
var _objective: Label
var _flash: ColorRect
var _screen: Control
var _screen_title: Label
var _screen_sub: Label
var _screen_hint: Label
var _boss_bar: ColorRect
var _boss_fill: ColorRect
var _boss_label: Label
var _msg_tween: Tween


func _ready() -> void:
	_build()
	Game.hud_changed.connect(_refresh)
	Game.message.connect(_show_message)
	Game.state_changed.connect(_on_state)
	Game.damage_flash.connect(_on_flash)
	Game.boss_changed.connect(_on_boss)
	_refresh()
	_on_state(Game.state)


func _heart_points(s: float) -> PackedVector2Array:
	var pts := [Vector2(8, 4), Vector2(5, 1), Vector2(2, 1), Vector2(0, 3),
		Vector2(0, 6), Vector2(8, 14), Vector2(16, 6), Vector2(16, 3),
		Vector2(14, 1), Vector2(11, 1)]
	var out := PackedVector2Array()
	for p in pts:
		out.append(p * s)
	return out


func _diamond_points(s: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(9, 0) * s, Vector2(18, 11) * s,
		Vector2(9, 22) * s, Vector2(0, 11) * s])


func _mask_points(s: float) -> PackedVector2Array:
	# silueta de máscara (pentágono invertido tipo cara)
	return PackedVector2Array([Vector2(2, 0) * s, Vector2(16, 0) * s,
		Vector2(18, 8) * s, Vector2(9, 20) * s, Vector2(0, 8) * s])


func _circle_points(r: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		out.append(Vector2(cos(a), sin(a)) * r)
	return out


func _mk_label(txt: String, pos: Vector2, size: int, col: Color,
		center := false) -> Label:
	var l := Label.new()
	l.text = txt
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 6)
	if center:
		l.size = Vector2(W, 60)
		l.position = Vector2(0, pos.y)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(l)
	return l


func _build() -> void:
	# moneda
	var coin := Polygon2D.new()
	coin.polygon = _circle_points(13)
	coin.color = GOLD
	coin.position = Vector2(36, 34)
	add_child(coin)
	var coin_inner := Polygon2D.new()
	coin_inner.polygon = _circle_points(8)
	coin_inner.color = Color(0.82, 0.6, 0.1)
	coin.add_child(coin_inner)
	_coin_label = _mk_label("x 0", Vector2(58, 16), 28, CREAM)

	# ídolos
	for i in 3:
		var d := Polygon2D.new()
		d.polygon = _diamond_points(1.0)
		d.color = Color(0.35, 0.35, 0.35, 0.8)
		d.position = Vector2(26 + i * 30, 58)
		add_child(d)
		_idol_slots.append(d)

	# máscaras de Quetzal
	for i in 2:
		var m := Polygon2D.new()
		m.polygon = _mask_points(1.2)
		m.color = Color(0.3, 0.3, 0.3, 0.7)
		m.position = Vector2(130 + i * 32, 56)
		add_child(m)
		_mask_slots.append(m)

	# corazones + vidas
	for i in 3:
		var hp := Polygon2D.new()
		hp.polygon = _heart_points(2.0)
		hp.color = Color(0.9, 0.15, 0.2)
		hp.position = Vector2(W - 140 + i * 40, 18)
		add_child(hp)
		_hearts.append(hp)
	_lives_label = _mk_label("VIDAS x 3", Vector2(W - 142, 54), 20, CREAM)

	_objective = _mk_label("", Vector2(0, 14), 18, Color(1, 1, 1, 0.85), true)
	_msg_label = _mk_label("", Vector2(0, 270), 34, GOLD, true)
	_msg_label.modulate.a = 0.0

	# barra del jefe
	_boss_label = _mk_label("", Vector2(0, 624), 20, Color(0.95, 0.5, 0.4), true)
	_boss_label.visible = false
	_boss_bar = ColorRect.new()
	_boss_bar.color = Color(0.1, 0.05, 0.05, 0.8)
	_boss_bar.position = Vector2(W / 2.0 - 250, 654)
	_boss_bar.size = Vector2(500, 18)
	_boss_bar.visible = false
	add_child(_boss_bar)
	_boss_fill = ColorRect.new()
	_boss_fill.color = Color(0.85, 0.2, 0.15)
	_boss_fill.position = Vector2(2, 2)
	_boss_fill.size = Vector2(496, 14)
	_boss_bar.add_child(_boss_fill)

	_flash = ColorRect.new()
	_flash.color = Color(0.8, 0.05, 0.05, 0.0)
	_flash.size = Vector2(W, H)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)

	# pantalla superpuesta
	_screen = Control.new()
	_screen.size = Vector2(W, H)
	_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_screen)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.04, 0.06, 0.55)
	dim.size = Vector2(W, H)
	_screen.add_child(dim)
	_screen_title = Label.new()
	_screen_title.size = Vector2(W, 90)
	_screen_title.position = Vector2(0, 230)
	_screen_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_screen_title.add_theme_font_size_override("font_size", 54)
	_screen_title.add_theme_color_override("font_color", GOLD)
	_screen_title.add_theme_color_override("font_outline_color", Color.BLACK)
	_screen_title.add_theme_constant_override("outline_size", 10)
	_screen.add_child(_screen_title)
	_screen_sub = Label.new()
	_screen_sub.size = Vector2(W, 90)
	_screen_sub.position = Vector2(0, 320)
	_screen_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_screen_sub.add_theme_font_size_override("font_size", 24)
	_screen_sub.add_theme_color_override("font_color", CREAM)
	_screen_sub.add_theme_color_override("font_outline_color", Color.BLACK)
	_screen_sub.add_theme_constant_override("outline_size", 6)
	_screen.add_child(_screen_sub)
	_screen_hint = Label.new()
	_screen_hint.size = Vector2(W, 40)
	_screen_hint.position = Vector2(0, 430)
	_screen_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_screen_hint.add_theme_font_size_override("font_size", 19)
	_screen_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	_screen_hint.add_theme_color_override("font_outline_color", Color.BLACK)
	_screen_hint.add_theme_constant_override("outline_size", 5)
	_screen.add_child(_screen_hint)


func _refresh() -> void:
	_coin_label.text = "x %d" % Game.coins
	_lives_label.text = "VIDAS x %d" % maxi(Game.lives, 0)
	for i in _hearts.size():
		_hearts[i].color = Color(0.9, 0.15, 0.2) if i < Game.hearts \
			else Color(0.25, 0.25, 0.28, 0.7)
	for i in _idol_slots.size():
		_idol_slots[i].color = GOLD if i < Game.idols \
			else Color(0.35, 0.35, 0.35, 0.8)
	for i in _mask_slots.size():
		if Game.is_invincible():
			_mask_slots[i].color = Color(1.0, 0.85, 0.2)
		else:
			_mask_slots[i].color = JADE if i < Game.masks \
				else Color(0.3, 0.3, 0.3, 0.7)


func _process(_delta: float) -> void:
	if Game.state == Game.GState.PLAYING:
		var m := int(Game.elapsed) / 60
		var s := int(Game.elapsed) % 60
		var lv := Game.level_index + 1
		var total := LevelData.count()
		if Game.is_invincible():
			_objective.text = "¡INVENCIBLE!  ·  Nivel %d/%d  ·  %02d:%02d" % [lv, total, m, s]
		else:
			_objective.text = "Nivel %d/%d  ·  Ídolos %d/%d  ·  %02d:%02d" \
				% [lv, total, Game.idols, Game.TOTAL_IDOLS, m, s]
	else:
		_objective.text = ""
	if Game.is_invincible():
		_refresh()


func _show_message(text: String, dur: float) -> void:
	_msg_label.text = text
	if _msg_tween:
		_msg_tween.kill()
	_msg_label.modulate.a = 1.0
	_msg_label.scale = Vector2.ONE * 1.15
	_msg_tween = create_tween()
	_msg_tween.tween_property(_msg_label, "scale", Vector2.ONE, 0.15)
	_msg_tween.tween_interval(dur)
	_msg_tween.tween_property(_msg_label, "modulate:a", 0.0, 0.4)


func _on_flash() -> void:
	_flash.color.a = 0.4
	var tw := create_tween()
	tw.tween_property(_flash, "color:a", 0.0, 0.45)


func _on_boss(hp: int, max_hp: int) -> void:
	var show := hp >= 0
	_boss_bar.visible = show
	_boss_label.visible = show
	if show:
		_boss_label.text = "GUARDIÁN DEL TEMPLO"
		var tw := create_tween()
		tw.tween_property(_boss_fill, "size:x", 496.0 * hp / float(max_hp), 0.3)


func _on_state(s: int) -> void:
	var def := Game.level_def()
	match s:
		Game.GState.INTRO:
			_screen.visible = true
			_screen.modulate.a = 1.0
			_screen_title.text = "NIVEL %d — %s" % [Game.level_index + 1, def.name]
			_screen_sub.text = def.story
			if Game.level_index == 0:
				_screen_hint.text = "WASD moverse · ESPACIO saltar (doble) · CLIC/J girar espada · R reiniciar"
			else:
				_screen_hint.text = "Recoge la 3ª máscara de Quetzal para ser invencible"
		Game.GState.PLAYING:
			if _screen.visible:
				var tw := create_tween()
				tw.tween_property(_screen, "modulate:a", 0.0, 0.5)
				tw.tween_callback(func():
					_screen.visible = false
					_screen.modulate.a = 1.0)
		Game.GState.DEAD:
			_show_message("¡Has caído! Vuelves al último punto de control...", 1.4)
		Game.GState.LEVEL_DONE:
			var m := int(Game.elapsed) / 60
			var sec := int(Game.elapsed) % 60
			_screen.visible = true
			_screen_title.text = "¡NIVEL %d SUPERADO!" % [Game.level_index + 1]
			_screen_sub.text = "Tiempo %02d:%02d · Monedas %d · Ídolos %d/%d" \
				% [m, sec, Game.coins, Game.idols, Game.TOTAL_IDOLS]
			_screen_hint.text = "Pulsa ESPACIO para continuar al siguiente nivel"
		Game.GState.GAMEOVER:
			_screen.visible = true
			_screen_title.text = "FIN DE LA EXPEDICIÓN"
			_screen_sub.text = "Caíste en el nivel %d. Monedas totales: %d" \
				% [Game.level_index + 1, Game.coins]
			_screen_hint.text = "Pulsa R para reintentar"
		Game.GState.WIN:
			var m := int(Game.total_time) / 60
			var sec := int(Game.total_time) % 60
			_screen.visible = true
			_screen_title.text = "¡NUEVA ESPAÑA CONQUISTADA!"
			_screen_sub.text = "Campaña completada en %02d:%02d\nMonedas %d · Ídolos %d/%d" \
				% [m, sec, Game.coins, Game.idols_total, LevelData.count() * Game.TOTAL_IDOLS]
			_screen_hint.text = "Pulsa R para jugar de nuevo" \
				+ ("   ·   ¡EXPEDICIÓN PERFECTA!" if Game.idols_total == LevelData.count() * Game.TOTAL_IDOLS else "")
