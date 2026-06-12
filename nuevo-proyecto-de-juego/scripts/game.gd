extends Node
## Autoload "Game": estado global de la campaña (3 niveles), vidas,
## monedas, máscaras y flujo intro -> jugando -> nivel superado / jefe
## -> victoria final o game over.

enum GState { INTRO, PLAYING, DEAD, LEVEL_DONE, WIN, GAMEOVER }

signal hud_changed
signal message(text: String, dur: float)
signal state_changed(s: int)
signal damage_flash
signal boss_changed(hp: int, max_hp: int)

const MAX_HEARTS := 3
const START_LIVES := 3
const COINS_PER_LIFE := 50
const TOTAL_IDOLS := 3
const INVINCIBLE_TIME := 12.0

var state: int = GState.INTRO
var level_index := 0
var coins := 0
var idols := 0
var idols_total := 0
var lives := START_LIVES
var hearts := MAX_HEARTS
var masks := 0
var checkpoint := Vector3.ZERO
var elapsed := 0.0
var total_time := 0.0
var player: CharacterBody3D
var boss_hp := -1
var boss_max := 0
var _next_life_at := COINS_PER_LIFE
var _fresh := true


func level_start() -> void:
	state = GState.INTRO
	if _fresh:
		coins = 0
		idols_total = 0
		lives = START_LIVES
		total_time = 0.0
		level_index = clampi(level_index, 0, LevelData.count() - 1)
		_next_life_at = COINS_PER_LIFE
		_fresh = false
	idols = 0
	hearts = MAX_HEARTS
	masks = 0
	elapsed = 0.0
	boss_hp = -1
	boss_max = 0
	hud_changed.emit()
	state_changed.emit(state)
	get_tree().create_timer(3.2).timeout.connect(_begin_play)


func level_def() -> Dictionary:
	return LevelData.get_level(level_index)


func _begin_play() -> void:
	if state == GState.INTRO:
		state = GState.PLAYING
		state_changed.emit(state)


func _process(delta: float) -> void:
	if state == GState.PLAYING:
		elapsed += delta
		total_time += delta


func add_coin(n: int = 1) -> void:
	coins += n
	if coins >= _next_life_at:
		_next_life_at += COINS_PER_LIFE
		lives += 1
		Sfx.play("checkpoint", 0.0, 0.0)
		message.emit("¡VIDA EXTRA!", 1.6)
	hud_changed.emit()


func add_idol() -> void:
	idols += 1
	idols_total += 1
	if idols >= TOTAL_IDOLS:
		message.emit("¡Tienes los 3 ídolos del nivel!", 2.5)
	else:
		message.emit("Ídolo dorado %d/%d" % [idols, TOTAL_IDOLS], 2.0)
	hud_changed.emit()


func add_mask() -> void:
	masks += 1
	if masks >= 3:
		masks = 2
		if player:
			player.start_invincibility(INVINCIBLE_TIME)
		message.emit("¡PODER DE QUETZAL! ¡Eres invencible!", 2.5)
		Sfx.play("idol")
	else:
		message.emit("Máscara de Quetzal %d" % masks, 1.6)
		Sfx.play("checkpoint", -2.0)
	hud_changed.emit()


func consume_mask() -> bool:
	if masks > 0:
		masks -= 1
		hud_changed.emit()
		return true
	return false


func is_invincible() -> bool:
	return player != null and player.is_powered()


func set_checkpoint(pos: Vector3, silent: bool = false) -> void:
	checkpoint = pos
	if not silent:
		Sfx.play("checkpoint")
		message.emit("PUNTO DE CONTROL", 1.6)


func set_boss(hp: int, max_hp: int) -> void:
	boss_hp = hp
	boss_max = max_hp
	boss_changed.emit(hp, max_hp)


func hurt(n: int = 1) -> void:
	if state != GState.PLAYING:
		return
	hearts -= n
	damage_flash.emit()
	hud_changed.emit()
	if hearts <= 0:
		player_died()


func player_died(_fell: bool = false) -> void:
	if state != GState.PLAYING:
		return
	lives -= 1
	masks = 0
	hud_changed.emit()
	if player:
		player.play_death()
	if lives < 0:
		state = GState.GAMEOVER
		Sfx.play("lose")
		state_changed.emit(state)
	else:
		state = GState.DEAD
		Sfx.play("lose", -6.0)
		state_changed.emit(state)
		get_tree().create_timer(1.5).timeout.connect(_respawn)


func _respawn() -> void:
	if state != GState.DEAD:
		return
	hearts = MAX_HEARTS
	if player:
		player.teleport(checkpoint + Vector3.UP * 1.0)
	state = GState.PLAYING
	hud_changed.emit()
	state_changed.emit(state)


func goal_reached() -> void:
	if state != GState.PLAYING:
		return
	if level_index >= LevelData.count() - 1:
		state = GState.WIN
		Sfx.play("win")
	else:
		state = GState.LEVEL_DONE
		Sfx.play("win")
	state_changed.emit(state)


func advance_level() -> void:
	if state != GState.LEVEL_DONE:
		return
	level_index += 1
	state = GState.INTRO
	get_tree().reload_current_scene()


func restart(full: bool = false) -> void:
	if full:
		_fresh = true
		level_index = 0
	else:
		lives = maxi(lives, START_LIVES)
	get_tree().paused = false
	get_tree().reload_current_scene()


func _unhandled_input(event: InputEvent) -> void:
	match state:
		GState.LEVEL_DONE:
			if event.is_action_pressed("jump") or event.is_action_pressed("ui_accept") \
					or event.is_action_pressed("attack"):
				advance_level()
		GState.WIN:
			if event.is_action_pressed("restart") or event.is_action_pressed("jump"):
				restart(true)
		GState.GAMEOVER:
			if event.is_action_pressed("restart") or event.is_action_pressed("jump"):
				restart()
		_:
			if event.is_action_pressed("restart"):
				restart()
	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
