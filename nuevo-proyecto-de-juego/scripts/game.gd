extends Node
## Autoload "Game": estado global de la partida, vidas, monedas y flujo
## intro -> jugando -> muerte/respawn -> victoria o game over.

enum GState { INTRO, PLAYING, DEAD, WIN, GAMEOVER }

signal hud_changed
signal message(text: String, dur: float)
signal state_changed(s: int)
signal damage_flash

const MAX_HEARTS := 3
const START_LIVES := 3
const COINS_PER_LIFE := 50
const TOTAL_IDOLS := 3

var state: int = GState.INTRO
var coins := 0
var idols := 0
var lives := START_LIVES
var hearts := MAX_HEARTS
var checkpoint := Vector3.ZERO
var elapsed := 0.0
var player: CharacterBody3D
var _next_life_at := COINS_PER_LIFE


func level_start() -> void:
	state = GState.INTRO
	coins = 0
	idols = 0
	lives = START_LIVES
	hearts = MAX_HEARTS
	elapsed = 0.0
	_next_life_at = COINS_PER_LIFE
	hud_changed.emit()
	state_changed.emit(state)
	get_tree().create_timer(2.8).timeout.connect(_begin_play)


func _begin_play() -> void:
	if state == GState.INTRO:
		state = GState.PLAYING
		state_changed.emit(state)


func _process(delta: float) -> void:
	if state == GState.PLAYING:
		elapsed += delta


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
	if idols >= TOTAL_IDOLS:
		message.emit("¡Tienes los 3 ídolos! Llega al templo", 3.0)
	else:
		message.emit("Ídolo dorado %d/%d" % [idols, TOTAL_IDOLS], 2.0)
	hud_changed.emit()


func set_checkpoint(pos: Vector3, silent: bool = false) -> void:
	checkpoint = pos
	if not silent:
		Sfx.play("checkpoint")
		message.emit("PUNTO DE CONTROL", 1.6)


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


func win() -> void:
	if state != GState.PLAYING:
		return
	state = GState.WIN
	Sfx.play("win")
	state_changed.emit(state)


func restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		restart()
	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
