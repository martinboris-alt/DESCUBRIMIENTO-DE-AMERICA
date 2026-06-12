extends Node3D
## La gran piedra del calendario: persigue al jugador por la senda con
## rubber-banding, aplasta cajas y enemigos, y mata si te alcanza.

const RADIUS := 2.3
const TRIGGER_D := 14.0
const STOP_MARGIN := 24.0

var curve: Curve3D
var clen := 0.0

var _d := 0.0
var _active := false
var _stopped := false
var _ball: Node3D
var _rumble: AudioStreamPlayer
var _dust: CPUParticles3D


func _ready() -> void:
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.5, 0.46, 0.4)
	stone.roughness = 0.9
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color(0.3, 0.26, 0.2)
	ring_mat.roughness = 0.95

	_ball = Node3D.new()
	add_child(_ball)
	var sphere := SphereMesh.new()
	sphere.radius = RADIUS
	sphere.height = RADIUS * 2.0
	sphere.radial_segments = 14
	sphere.rings = 8
	var mi := MeshInstance3D.new()
	mi.mesh = sphere
	mi.material_override = stone
	_ball.add_child(mi)
	# anillos tallados (calendario)
	for r in [0.6, 1.4]:
		var torus := TorusMesh.new()
		torus.inner_radius = RADIUS * 0.92 - 0.1
		torus.outer_radius = RADIUS * 0.92 + 0.1
		var tmi := MeshInstance3D.new()
		tmi.mesh = torus
		tmi.material_override = ring_mat
		tmi.rotation.x = PI / 2.0
		tmi.position.x = (r - 1.0) * RADIUS * 0.7
		tmi.rotation.z = PI / 2.0
		_ball.add_child(tmi)

	_dust = CPUParticles3D.new()
	_dust.amount = 24
	_dust.lifetime = 0.9
	_dust.emitting = false
	_dust.spread = 60.0
	_dust.direction = Vector3.UP
	_dust.initial_velocity_min = 1.0
	_dust.initial_velocity_max = 3.0
	_dust.gravity = Vector3(0, -4, 0)
	_dust.scale_amount_min = 0.6
	_dust.scale_amount_max = 1.4
	var dm := SphereMesh.new()
	dm.radius = 0.25
	dm.height = 0.5
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(0.7, 0.62, 0.5, 0.7)
	dm.material = dmat
	_dust.mesh = dm
	add_child(_dust)

	_rumble = AudioStreamPlayer.new()
	var stream: AudioStreamWAV = load("res://assets/audio/rumble.wav")
	if stream:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = stream.data.size() / 2
		_rumble.stream = stream
	_rumble.volume_db = -60.0
	add_child(_rumble)

	visible = false
	Game.state_changed.connect(_on_state)


func _on_state(s: int) -> void:
	# al reaparecer, recoloca la bola detrás del checkpoint
	if s == Game.GState.PLAYING and _active and Game.player:
		var pd: float = curve.get_closest_offset(Game.player.global_position)
		_d = minf(_d, maxf(pd - 18.0, 0.0))
		_stopped = false


func _physics_process(delta: float) -> void:
	if not curve or Game.state != Game.GState.PLAYING or not Game.player:
		return
	var pd: float = curve.get_closest_offset(Game.player.global_position)

	if not _active:
		if pd > TRIGGER_D:
			_active = true
			visible = true
			_d = maxf(pd - 16.0, 0.0)
			_dust.emitting = true
			_rumble.play()
			Game.message.emit("¡¡CORRE!!", 1.8)
			Sfx.play("tnt_boom", -6.0)
		return

	if _stopped:
		return

	# rubber-banding: nunca te deja escapar del todo
	var gap := pd - _d
	var speed := 6.1
	if gap > 22.0:
		speed = 7.2
	elif gap < 9.0:
		speed = 5.6
	_d += speed * delta

	if _d >= clen - STOP_MARGIN:
		_d = clen - STOP_MARGIN
		_stopped = true
		_dust.emitting = false
		_rumble.stop()
		Sfx.play("tnt_boom", -2.0)
		Game.message.emit("La piedra se ha detenido...", 2.0)

	var pos := curve.sample_baked(_d)
	global_position = pos + Vector3.UP * RADIUS * 0.85
	var fwd := (curve.sample_baked(clampf(_d + 1.0, 0, clen)) - pos)
	fwd.y = 0.0
	if fwd.length() > 0.01:
		var side := fwd.normalized().cross(Vector3.UP)
		_ball.rotate(side.normalized(), -speed / RADIUS * delta)

	_rumble.volume_db = clampf(-4.0 - gap * 1.2, -40.0, -4.0)

	# aplasta lo que pilla
	for crate in get_tree().get_nodes_in_group("crate"):
		if not crate.broken and crate.global_position.distance_to(global_position) < RADIUS + 0.8:
			crate.call_deferred("_break")
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not enemy.dead and enemy.global_position.distance_to(global_position) < RADIUS + 0.6:
			enemy.spin_hit(global_position)

	# te alcanza = muerte
	var to_player := Game.player.global_position - global_position
	if to_player.length() < RADIUS + 0.5:
		Game.hearts = 0
		Game.player_died()
