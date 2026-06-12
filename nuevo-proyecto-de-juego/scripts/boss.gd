extends CharacterBody3D
## Jefe final: el Guardián del Templo. Embiste al jugador; al chocar
## queda aturdido y es vulnerable a giros y saltos. 3 fases, cada una
## más rápida. Al morir aparece el ídolo-meta.

enum BState { WAIT, FACE, CHARGE, STUN, DEAD }

const MAX_HP := 9
const ARENA_R := 13.0
const TINT := Color(0.45, 0.85, 0.75)

var arena_center := Vector3.ZERO
var goal_script: GDScript

var dead := false
var hp := MAX_HP
var _state: int = BState.WAIT
var _timer := 0.0
var _charge_dir := Vector3.ZERO
var _charge_left := 0.0
var _hit_cd := 0.0
var _visuals: Node3D
var anim := CharAnim.new()


func _phase() -> int:
	return clampi((MAX_HP - hp) / 3, 0, 2)


func _ready() -> void:
	add_to_group("enemy")
	add_to_group("boss")
	_visuals = preload("res://assets/models/conquistador_lowpoly.glb").instantiate()
	_visuals.name = "Visuals"
	_visuals.scale = Vector3.ONE * 2.4
	add_child(_visuals)
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.95
	cap.height = 4.0
	col.shape = cap
	col.position.y = 2.0
	add_child(col)
	await get_tree().process_frame
	await get_tree().process_frame
	anim.setup(_visuals)
	_tint(_visuals)
	Game.set_boss(hp, MAX_HP)


func _tint(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var mat: Material = mi.get_active_material(i)
			if mat is StandardMaterial3D:
				var m: StandardMaterial3D = mat.duplicate()
				m.albedo_color = m.albedo_color * TINT
				m.metallic *= 0.3
				mi.set_surface_override_material(i, m)
	for child in node.get_children():
		_tint(child)


func _physics_process(delta: float) -> void:
	if dead or not Game.player or Game.state != Game.GState.PLAYING:
		return
	_timer -= delta
	_hit_cd = maxf(_hit_cd - delta, 0.0)
	var player := Game.player
	var to_player := player.global_position - global_position
	var dist_flat := Vector2(to_player.x, to_player.z).length()

	if not is_on_floor():
		velocity.y -= 22.0 * delta

	match _state:
		BState.WAIT:
			# despierta cuando el jugador entra en la arena
			if player.global_position.distance_to(arena_center) < ARENA_R + 2.0:
				_state = BState.FACE
				_timer = 1.0
				Sfx.play("tnt_boom", -4.0)
				Music.play_track("boss")
				Game.message.emit("¡EL GUARDIÁN DEL TEMPLO!", 2.2)
		BState.FACE:
			velocity.x = 0
			velocity.z = 0
			_face(to_player, delta)
			if _timer <= 0.0:
				_state = BState.CHARGE
				var flat := Vector3(to_player.x, 0, to_player.z)
				_charge_dir = flat.normalized() if flat.length() > 0.1 else Vector3.FORWARD
				_charge_left = flat.length() + 5.0
				Sfx.play("spin", -2.0, 0.0)
		BState.CHARGE:
			var speed := 8.5 + _phase() * 1.6
			velocity.x = _charge_dir.x * speed
			velocity.z = _charge_dir.z * speed
			_charge_left -= speed * delta
			_face(_charge_dir, delta, 14.0)
			if dist_flat < 1.9 and _hit_cd <= 0.0:
				_hit_cd = 1.0
				player.take_hit(global_position)
			# fin de embestida: agotada o borde de la arena
			var from_center := global_position - arena_center
			from_center.y = 0.0
			if _charge_left <= 0.0 or from_center.length() > ARENA_R:
				_state = BState.STUN
				_timer = 2.4 - 0.5 * _phase()
				velocity.x = 0
				velocity.z = 0
				Sfx.play("land", 2.0)
		BState.STUN:
			# tambaleo; durante el aturdimiento no daña por contacto
			velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 30.0 * delta)
			_visuals.rotation.z = sin(_timer * 9.0) * 0.12
			if _timer <= 0.0:
				_visuals.rotation.z = 0.0
				_state = BState.FACE
				_timer = 0.9 - 0.15 * _phase()

	move_and_slide()
	anim.update(Vector2(velocity.x, velocity.z).length() * 0.6, delta)


func _face(dir: Vector3, delta: float, speed := 8.0) -> void:
	if _visuals and Vector2(dir.x, dir.z).length() > 0.1:
		_visuals.rotation.y = lerp_angle(_visuals.rotation.y, atan2(dir.x, dir.z), speed * delta)


func stomp() -> void:
	_take_damage()


func spin_hit(_from: Vector3) -> void:
	_take_damage()


func _take_damage() -> void:
	if dead:
		return
	if _state != BState.STUN:
		# solo es vulnerable aturdido
		Sfx.play("land", -4.0)
		return
	hp -= 1
	Game.set_boss(hp, MAX_HP)
	Sfx.play("enemy_die", 0.0, 0.12)
	# destello rojo
	var tw := create_tween()
	tw.tween_property(_visuals, "scale", Vector3.ONE * 2.4 * 1.12, 0.08)
	tw.tween_property(_visuals, "scale", Vector3.ONE * 2.4, 0.12)
	if hp <= 0:
		_die()
	else:
		if hp % 3 == 0:
			Game.message.emit("¡El Guardián se enfurece!", 1.8)
		_state = BState.FACE
		_timer = 1.1


func _die() -> void:
	dead = true
	collision_layer = 0
	collision_mask = 0
	Game.set_boss(-1, MAX_HP)
	Game.add_coin(20)
	Sfx.play("tnt_boom")
	Game.message.emit("¡GUARDIÁN DERROTADO!", 2.5)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "scale", Vector3.ONE * 0.05, 1.0)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	if _visuals:
		tw.tween_property(_visuals, "rotation:y", _visuals.rotation.y + TAU * 2.0, 1.0)
	tw.chain().tween_callback(_spawn_goal)


func _spawn_goal() -> void:
	var goal := Area3D.new()
	goal.set_script(goal_script)
	goal.is_goal = true
	goal.position = arena_center + Vector3.UP * 0.2
	get_parent().add_child(goal)
	queue_free()
