extends StaticBody3D
## Caja rompible estilo Crash. Normal: suelta monedas. TNT: cuenta atrás
## y explota dañando todo alrededor (en cadena).

const SIZE := 0.9
const BOOM_RADIUS := 3.6

static var _wood_mat: StandardMaterial3D
static var _frame_mat: StandardMaterial3D
static var _tnt_mat: StandardMaterial3D

var is_tnt := false
var coin_value := 3
var broken := false
var _counting := false
var _label: Label3D


func _ready() -> void:
	add_to_group("crate")
	if not _wood_mat:
		_wood_mat = StandardMaterial3D.new()
		_wood_mat.albedo_color = Color(0.72, 0.5, 0.24)
		_wood_mat.roughness = 0.9
		_frame_mat = StandardMaterial3D.new()
		_frame_mat.albedo_color = Color(0.42, 0.27, 0.1)
		_frame_mat.roughness = 0.95
		_tnt_mat = StandardMaterial3D.new()
		_tnt_mat.albedo_color = Color(0.78, 0.12, 0.08)
		_tnt_mat.roughness = 0.7

	var box := BoxMesh.new()
	box.size = Vector3.ONE * SIZE
	var mi := MeshInstance3D.new()
	mi.mesh = box
	mi.material_override = _tnt_mat if is_tnt else _wood_mat
	mi.position.y = SIZE / 2.0
	add_child(mi)

	# marco de listones en las aristas
	var h := SIZE / 2.0
	var t := 0.09
	var edges := [
		[Vector3(0, t / 2.0, h), Vector3(SIZE + t, t, t)],
		[Vector3(0, t / 2.0, -h), Vector3(SIZE + t, t, t)],
		[Vector3(0, SIZE - t / 2.0, h), Vector3(SIZE + t, t, t)],
		[Vector3(0, SIZE - t / 2.0, -h), Vector3(SIZE + t, t, t)],
		[Vector3(h, t / 2.0, 0), Vector3(t, t, SIZE + t)],
		[Vector3(-h, t / 2.0, 0), Vector3(t, t, SIZE + t)],
		[Vector3(h, SIZE - t / 2.0, 0), Vector3(t, t, SIZE + t)],
		[Vector3(-h, SIZE - t / 2.0, 0), Vector3(t, t, SIZE + t)],
		[Vector3(h, SIZE / 2.0, h), Vector3(t, SIZE, t)],
		[Vector3(-h, SIZE / 2.0, h), Vector3(t, SIZE, t)],
		[Vector3(h, SIZE / 2.0, -h), Vector3(t, SIZE, t)],
		[Vector3(-h, SIZE / 2.0, -h), Vector3(t, SIZE, t)],
	]
	for e in edges:
		var em := BoxMesh.new()
		em.size = e[1]
		var emi := MeshInstance3D.new()
		emi.mesh = em
		emi.material_override = _frame_mat
		emi.position = e[0]
		add_child(emi)

	if is_tnt:
		_label = Label3D.new()
		_label.text = "TNT"
		_label.font_size = 110
		_label.modulate = Color(1, 1, 0.85)
		_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_label.position = Vector3(0, SIZE / 2.0, 0)
		_label.no_depth_test = true
		add_child(_label)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3.ONE * SIZE
	col.shape = shape
	col.position.y = SIZE / 2.0
	add_child(col)


func hit_break() -> void:
	if broken:
		return
	if is_tnt:
		if not _counting:
			_counting = true
			_countdown()
	else:
		_break()


func _countdown() -> void:
	for n in [3, 2, 1]:
		if not is_inside_tree():
			return
		_label.text = str(n)
		_label.font_size = 160
		Sfx.play("tnt_tick")
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector3.ONE * 1.12, 0.1)
		tw.tween_property(self, "scale", Vector3.ONE, 0.1)
		await get_tree().create_timer(0.5).timeout
	_explode()


func _break() -> void:
	if broken:
		return
	broken = true
	Sfx.play("crate", 0.0, 0.1)
	Game.add_coin(coin_value)
	Sfx.play("coin", -4.0)
	_burst(Color(0.62, 0.42, 0.18), 1.6, 14)
	_remove()


func _explode() -> void:
	if broken:
		return
	broken = true
	Sfx.play("tnt_boom")
	_burst(Color(1.0, 0.55, 0.1), 4.0, 32)
	var my_pos := global_position
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy.global_position.distance_to(my_pos) < BOOM_RADIUS:
			enemy.spin_hit(my_pos)
	for crate in get_tree().get_nodes_in_group("crate"):
		if crate != self and not crate.broken \
				and crate.global_position.distance_to(my_pos) < BOOM_RADIUS:
			if crate.is_tnt:
				crate.call_deferred("_explode")
			else:
				crate.call_deferred("_break")
	var player := Game.player
	if player and player.global_position.distance_to(my_pos) < BOOM_RADIUS - 0.8:
		player.take_hit(my_pos)
	_remove()


func _remove() -> void:
	collision_layer = 0
	for child in get_children():
		if child is MeshInstance3D or child is Label3D:
			child.visible = false
	get_tree().create_timer(1.4).timeout.connect(queue_free)


func _burst(color: Color, spread: float, amount: int) -> void:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.amount = amount
	p.lifetime = 0.7
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = spread * 1.5
	p.initial_velocity_max = spread * 3.0
	p.gravity = Vector3(0, -14, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	var m := BoxMesh.new()
	m.size = Vector3.ONE * 0.16
	p.mesh = m
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	p.mesh.material = mat
	p.position = Vector3(0, SIZE / 2.0, 0)
	add_child(p)
	p.emitting = true
