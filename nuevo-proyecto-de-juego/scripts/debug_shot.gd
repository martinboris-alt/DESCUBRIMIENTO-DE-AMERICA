extends Node
## Utilidad de desarrollo: captura screenshots y bot de autojuego.
## Uso:  godot --path . -- --shots=120,300 --out=C:/ruta --tp=150
##       godot --path . -- --auto --out=C:/ruta   (bot que recorre el nivel)

var _targets: Array = []
var _out := "."
var _tp := -1.0
var _auto := false
var _frame := 0
var _tp_done := false
var _jump_held := false
var _air_jumped := false
var _close := false


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			for s in arg.get_slice("=", 1).split(","):
				_targets.append(int(s))
		elif arg.begins_with("--out="):
			_out = arg.get_slice("=", 1)
		elif arg.begins_with("--tp="):
			_tp = float(arg.get_slice("=", 1))
		elif arg == "--auto":
			_auto = true
		elif arg == "--close":
			_close = true
	set_process(not _targets.is_empty() or _auto)
	set_physics_process(_auto)


func _process(_delta: float) -> void:
	_frame += 1

	if _close and _frame == 5:
		var rig := get_tree().current_scene.get_node_or_null("CameraRig")
		if rig:
			rig.dist = 3.0
			rig.height = 1.4

	if _tp >= 0.0 and not _tp_done and Game.state == Game.GState.PLAYING:
		_tp_done = true
		var main := get_tree().current_scene
		if main and Game.player and main.has_method("_pos"):
			Game.player.teleport(main._pos(_tp, 0.0, 1.5))
			var rig := main.get_node_or_null("CameraRig")
			if rig:
				rig.setup(Game.player, main.curve)

	if _frame in _targets:
		_capture("%s/shot_f%d.png" % [_out, _frame])
	if not _targets.is_empty() and not _auto and _frame > int(_targets.max()):
		get_tree().quit()

	if _auto:
		if _frame % 600 == 0:
			_capture("%s/auto_f%d.png" % [_out, _frame])
		if _frame % 120 == 0:
			var d := -1.0
			var main := get_tree().current_scene
			if main and Game.player:
				d = main.curve.get_closest_offset(Game.player.global_position)
			print("PROGRESS f=%d d=%.1f vidas=%d corazones=%d monedas=%d idolos=%d estado=%d" %
				[_frame, d, Game.lives, Game.hearts, Game.coins, Game.idols, Game.state])
		if Game.state == Game.GState.WIN:
			print("BOT_WIN f=%d t=%.1fs monedas=%d idolos=%d" %
				[_frame, Game.elapsed, Game.coins, Game.idols])
			_capture("%s/auto_win.png" % _out)
			await get_tree().create_timer(0.5).timeout
			get_tree().quit()
		elif Game.state == Game.GState.GAMEOVER:
			print("BOT_GAMEOVER f=%d monedas=%d" % [_frame, Game.coins])
			_capture("%s/auto_gameover.png" % _out)
			await get_tree().create_timer(0.5).timeout
			get_tree().quit()
		elif _frame > 18000:
			print("BOT_TIMEOUT")
			get_tree().quit()


func _physics_process(_delta: float) -> void:
	if not _auto or Game.state != Game.GState.PLAYING or not Game.player:
		return
	var main := get_tree().current_scene
	if not main or not main.has_method("_in_gap"):
		return
	var player: CharacterBody3D = Game.player
	var d: float = main.curve.get_closest_offset(player.global_position)

	Input.action_press("move_forward")

	# corrección lateral hacia el centro de la senda
	var side: Vector3 = main._fwd(d).cross(Vector3.UP)
	var lateral: float = (player.global_position - main.curve.sample_baked(d)).dot(side)
	if lateral > 0.35:
		Input.action_release("move_right")
		Input.action_press("move_left", clampf(absf(lateral) * 0.5, 0.2, 1.0))
	elif lateral < -0.35:
		Input.action_release("move_left")
		Input.action_press("move_right", clampf(absf(lateral) * 0.5, 0.2, 1.0))
	else:
		Input.action_release("move_left")
		Input.action_release("move_right")

	# saltar justo antes del borde; mantener durante el ascenso para no
	# recortar el salto; doble salto si cae todavía sobre el hueco
	var want_jump := false
	if player.is_on_floor():
		_air_jumped = false
		want_jump = main._in_gap(d + 1.0, 0.0)
	else:
		if player.velocity.y > 2.0:
			want_jump = _jump_held
		elif main._in_gap(d + 0.6, 0.0) and not _air_jumped:
			if _jump_held:
				want_jump = false
			else:
				want_jump = true
				_air_jumped = true

	if want_jump and not _jump_held:
		Input.action_press("jump")
		_jump_held = true
		print("BOT_JUMP d=%.1f aire=%s vel_y=%.2f" %
			[d, str(not player.is_on_floor()), player.velocity.y])
	elif not want_jump and _jump_held:
		Input.action_release("jump")
		_jump_held = false

	# giro de espada: al acercarse un enemigo o periódicamente para cajas
	var enemy_near := false
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not enemy.dead and enemy.global_position.distance_to(player.global_position) < 2.8:
			enemy_near = true
			break
	if enemy_near or _frame % 70 == 0:
		Input.action_press("attack")
	elif _frame % 70 == 2:
		Input.action_release("attack")


func _capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("SHOT_SAVED: ", path)
