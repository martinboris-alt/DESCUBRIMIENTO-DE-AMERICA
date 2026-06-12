extends CharacterBody3D
## Conquistador jugable estilo plataformas: salto doble, giro de espada,
## rebote sobre enemigos y cajas, coyote time y buffer de salto.

const SPEED := 6.8
const ACCEL := 42.0
const DEACCEL := 34.0
const JUMP_V := 6.8
const JUMP2_V := 6.6
const GRAV_UP := 16.0
const GRAV_DOWN := 24.0
const COYOTE := 0.12
const JUMP_BUFFER := 0.12
const SPIN_TIME := 0.40
const SPIN_CD := 0.60
const STOMP_BOUNCE := 8.0
const CRATE_BOUNCE := 6.0
const DEATH_Y := -1.6
const MODEL_YAW := 0.0

@onready var visuals: Node3D = $Visuals
@onready var spin_area: Area3D = $SpinArea

var cam_rig: Node3D
var anim := CharAnim.new()

var _coyote := 0.0
var _jump_buf := 0.0
var _can_double := true
var _spin_t := 0.0
var _spin_cd := 0.0
var _spin_yaw := 0.0
var _invuln := 0.0
var _step_t := 0.0
var _was_on_floor := true
var _face_yaw := 0.0
var _dead := false
var _power_t := 0.0
var _orbit: Node3D
var _orbit_masks: Array[Node3D] = []
var _power_light: OmniLight3D


func _ready() -> void:
	add_to_group("player")
	_build_mask_orbit()
	await get_tree().process_frame
	await get_tree().process_frame
	anim.setup(visuals)


func _build_mask_orbit() -> void:
	_orbit = Node3D.new()
	_orbit.position.y = 1.5
	add_child(_orbit)
	for i in 2:
		var m := MaskPickup.build_mask_mesh(0.45)
		m.position = Vector3(0.85 if i == 0 else -0.85, 0.1 * i, 0)
		m.visible = false
		_orbit.add_child(m)
		_orbit_masks.append(m)
	_power_light = OmniLight3D.new()
	_power_light.light_color = Color(1.0, 0.85, 0.3)
	_power_light.light_energy = 0.0
	_power_light.omni_range = 5.0
	_power_light.position.y = 1.2
	add_child(_power_light)


func start_invincibility(dur: float) -> void:
	_power_t = dur


func is_powered() -> bool:
	return _power_t > 0.0


func teleport(pos: Vector3) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	_dead = false
	_power_t = 0.0
	if cam_rig:
		cam_rig.snap()
		var f: Vector3 = cam_rig.forward()
		_face_yaw = atan2(f.x, f.z)
	_invuln = 1.5
	_spin_t = 0.0
	_spin_yaw = 0.0
	visuals.rotation = Vector3(0, _face_yaw + MODEL_YAW, 0)
	visuals.position = Vector3.ZERO
	visuals.visible = true


func play_death() -> void:
	_dead = true
	velocity = Vector3.ZERO
	var tw := create_tween()
	tw.tween_property(visuals, "rotation:x", -PI / 2.0, 0.45)\
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func _physics_process(delta: float) -> void:
	if _dead:
		return
	if Game.state != Game.GState.PLAYING:
		anim.update(0.0, delta)
		if not is_on_floor():
			velocity.y -= GRAV_DOWN * delta
			move_and_slide()
		return

	_invuln = maxf(_invuln - delta, 0.0)
	_spin_cd = maxf(_spin_cd - delta, 0.0)
	_coyote = maxf(_coyote - delta, 0.0)
	_jump_buf = maxf(_jump_buf - delta, 0.0)

	# ── Movimiento relativo a la cámara ──────────────────────────────
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var fwd := Vector3.FORWARD
	if cam_rig:
		fwd = cam_rig.forward()
	var right := fwd.cross(Vector3.UP).normalized()
	var dir := (right * input.x - fwd * input.y).normalized() if input.length() > 0.1 else Vector3.ZERO

	if dir != Vector3.ZERO:
		velocity.x = move_toward(velocity.x, dir.x * SPEED, ACCEL * delta)
		velocity.z = move_toward(velocity.z, dir.z * SPEED, ACCEL * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, DEACCEL * delta)
		velocity.z = move_toward(velocity.z, 0.0, DEACCEL * delta)

	# ── Gravedad asimétrica (caída más rápida = mejor feel) ──────────
	if not is_on_floor():
		velocity.y -= (GRAV_UP if velocity.y > 0.0 else GRAV_DOWN) * delta
	else:
		_coyote = COYOTE
		_can_double = true

	# ── Salto con buffer + coyote + salto doble ──────────────────────
	if Input.is_action_just_pressed("jump"):
		_jump_buf = JUMP_BUFFER
	if _jump_buf > 0.0:
		if _coyote > 0.0:
			velocity.y = JUMP_V
			_coyote = 0.0
			_jump_buf = 0.0
			Sfx.play("jump")
		elif _can_double:
			velocity.y = JUMP2_V
			_can_double = false
			_jump_buf = 0.0
			Sfx.play("jump", -2.0)
	# salto corto al soltar
	if Input.is_action_just_released("jump") and velocity.y > 2.5:
		velocity.y = 2.5

	# ── Giro de espada ────────────────────────────────────────────────
	if Input.is_action_just_pressed("attack") and _spin_cd <= 0.0:
		_spin_t = SPIN_TIME
		_spin_cd = SPIN_CD
		_spin_yaw = 0.0
		Sfx.play("spin")
	if _spin_t > 0.0:
		_spin_t -= delta
		_spin_yaw += TAU / SPIN_TIME * delta
		for body in spin_area.get_overlapping_bodies():
			if body.is_in_group("enemy"):
				body.spin_hit(global_position)
			elif body.is_in_group("crate"):
				body.hit_break()

	var was_air := not _was_on_floor
	move_and_slide()

	# ── Rebote sobre enemigos / cajas ─────────────────────────────────
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var other := col.get_collider()
		if other and other.is_in_group("enemy") and col.get_normal().y > 0.4:
			other.stomp()
			velocity.y = STOMP_BOUNCE
			Sfx.play("bounce")
		elif other and other.is_in_group("crate") and col.get_normal().y > 0.6:
			other.hit_break()
			velocity.y = CRATE_BOUNCE

	if was_air and is_on_floor():
		Sfx.play("land", -6.0)

	# ── Orientación del modelo + giro de ataque ──────────────────────
	var hvel := Vector2(velocity.x, velocity.z)
	if hvel.length() > 0.5:
		_face_yaw = lerp_angle(_face_yaw, atan2(velocity.x, velocity.z), 12.0 * delta)
	visuals.rotation.y = _face_yaw + MODEL_YAW + _spin_yaw

	# ── Animación y pasos ─────────────────────────────────────────────
	anim.update(hvel.length(), delta, 1.0 if _spin_t > 0.0 else 0.0)
	# bote vertical del modelo al caminar (sólo en suelo)
	var target_bob := absf(anim.body_bob()) * 1.6 if is_on_floor() else 0.0
	visuals.position.y = lerpf(visuals.position.y, target_bob, 1.0 - exp(-18.0 * delta))
	if is_on_floor() and hvel.length() > 1.0:
		_step_t -= delta * hvel.length()
		if _step_t <= 0.0:
			_step_t = 2.4
			Sfx.play("step", -8.0, 0.18)

	# parpadeo de invulnerabilidad
	visuals.visible = _invuln <= 0.0 or fmod(_invuln, 0.2) < 0.12

	# máscaras orbitando + poder de invencibilidad
	_power_t = maxf(_power_t - delta, 0.0)
	_orbit.rotation.y += delta * (6.0 if _power_t > 0.0 else 1.8)
	for i in _orbit_masks.size():
		_orbit_masks[i].visible = Game.masks > i
	_power_light.light_energy = 2.2 if _power_t > 0.0 else \
		(0.0 if Game.masks == 0 else 0.4)
	if _power_t > 0.0:
		# tocar enemigos los elimina
		for enemy in get_tree().get_nodes_in_group("enemy"):
			if not enemy.dead and not enemy.is_in_group("boss") \
					and enemy.global_position.distance_to(global_position) < 1.4:
				enemy.spin_hit(global_position)

	# ── Caída al agua ─────────────────────────────────────────────────
	if global_position.y < DEATH_Y:
		Game.hearts = 0
		Game.player_died(true)

	_was_on_floor = is_on_floor()


func take_hit(from_pos: Vector3, amount: int = 1) -> void:
	if _invuln > 0.0 or _spin_t > 0.0 or _power_t > 0.0 \
			or Game.state != Game.GState.PLAYING:
		return
	_invuln = 1.3
	var knock := (global_position - from_pos)
	knock.y = 0.0
	knock = knock.normalized() if knock.length() > 0.05 else Vector3.BACK
	velocity = knock * 4.0 + Vector3.UP * 4.0
	if Game.consume_mask():
		Sfx.play("bounce", -4.0)
		return
	Sfx.play("hurt")
	Game.hurt(amount)
