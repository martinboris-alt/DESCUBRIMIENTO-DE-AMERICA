extends Area3D
## Doblón de oro giratorio. Se recoge al tocarlo.

static var _mesh: CylinderMesh
static var _mat: StandardMaterial3D

var _taken := false


func _ready() -> void:
	if not _mesh:
		_mesh = CylinderMesh.new()
		_mesh.top_radius = 0.26
		_mesh.bottom_radius = 0.26
		_mesh.height = 0.06
		_mat = StandardMaterial3D.new()
		_mat.albedo_color = Color(1.0, 0.78, 0.1)
		_mat.metallic = 1.0
		_mat.roughness = 0.18
		_mat.emission_enabled = true
		_mat.emission = Color(0.6, 0.42, 0.02)
		_mat.emission_energy_multiplier = 0.45

	var mi := MeshInstance3D.new()
	mi.mesh = _mesh
	mi.material_override = _mat
	mi.rotation.x = PI / 2.0
	add_child(mi)

	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.55
	shape.shape = sphere
	add_child(shape)

	monitorable = false
	body_entered.connect(_on_body)


func _process(delta: float) -> void:
	rotation.y += 3.2 * delta
	if not _taken:
		var s := 1.0 + Music.pulse() * 0.28
		scale = scale.lerp(Vector3.ONE * s, 1.0 - exp(-18.0 * delta))


func _on_body(body: Node3D) -> void:
	if _taken or not body.is_in_group("player"):
		return
	_taken = true
	Game.add_coin(1)
	Sfx.play("coin", -2.0, 0.1)
	set_deferred("monitoring", false)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "position:y", position.y + 1.2, 0.25)
	tw.tween_property(self, "scale", Vector3.ONE * 0.05, 0.25)
	tw.chain().tween_callback(queue_free)
