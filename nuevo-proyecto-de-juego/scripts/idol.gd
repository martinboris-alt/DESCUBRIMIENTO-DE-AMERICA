extends Area3D
## Ídolo dorado coleccionable (3 por nivel). Si is_goal, es el ídolo del
## templo y al tocarlo se gana la partida.

var is_goal := false

var _taken := false
var _base_y := 0.0
var _t := 0.0


func _ready() -> void:
	_base_y = position.y
	_t = randf() * TAU

	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(1.0, 0.8, 0.15)
	gold.metallic = 1.0
	gold.roughness = 0.22
	gold.emission_enabled = true
	gold.emission = Color(0.7, 0.5, 0.05)
	gold.emission_energy_multiplier = 0.5

	var s := 2.2 if is_goal else 1.0
	# tótem: base + cuerpo + cabeza + tocado
	for part in [
		[BoxMesh.new(), Vector3(0.42, 0.14, 0.42), Vector3(0, 0.07, 0)],
		[CylinderMesh.new(), Vector3(0.3, 0.42, 0.3), Vector3(0, 0.35, 0)],
		[BoxMesh.new(), Vector3(0.34, 0.3, 0.3), Vector3(0, 0.72, 0)],
		[CylinderMesh.new(), Vector3(0.4, 0.12, 0.4), Vector3(0, 0.93, 0)],
	]:
		var mesh: Mesh = part[0]
		if mesh is BoxMesh:
			mesh.size = part[1]
		else:
			mesh.top_radius = part[1].x * 0.5
			mesh.bottom_radius = part[1].x * 0.62
			mesh.height = part[1].y
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = gold
		mi.position = part[2] * s
		mi.scale = Vector3.ONE * s
		add_child(mi)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.85, 0.3)
	light.light_energy = 1.4 if is_goal else 0.8
	light.omni_range = 6.0 * s
	light.position.y = 0.8 * s
	add_child(light)

	if is_goal:
		# columna de luz como hito visible desde lejos
		var beam := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.5
		cyl.bottom_radius = 0.5
		cyl.height = 40.0
		beam.mesh = cyl
		var bm := StandardMaterial3D.new()
		bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		bm.albedo_color = Color(1.0, 0.9, 0.4, 0.16)
		bm.emission_enabled = true
		bm.emission = Color(1.0, 0.85, 0.3)
		bm.emission_energy_multiplier = 0.8
		bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		beam.material_override = bm
		beam.position.y = 20.0
		add_child(beam)

	var col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.3 * s
	col.shape = sphere
	col.position.y = 0.5 * s
	add_child(col)

	monitorable = false
	body_entered.connect(_on_body)


func _process(delta: float) -> void:
	_t += delta
	rotation.y += 1.2 * delta
	position.y = _base_y + sin(_t * 2.0) * 0.12


func _on_body(body: Node3D) -> void:
	if _taken or not body.is_in_group("player"):
		return
	_taken = true
	if is_goal:
		Game.win()
		return
	Game.add_idol()
	Sfx.play("idol")
	set_deferred("monitoring", false)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "position:y", position.y + 2.0, 0.5)
	tw.tween_property(self, "scale", Vector3.ONE * 0.05, 0.5)
	tw.chain().tween_callback(queue_free)
