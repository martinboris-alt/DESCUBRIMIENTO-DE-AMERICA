class_name MaskPickup
extends Area3D
## Máscara de Quetzal (estilo Aku Aku): absorbe un golpe. Con la tercera
## obtienes invencibilidad temporal.

var _taken := false
var _base_y := 0.0
var _t := 0.0


static func build_mask_mesh(s: float = 1.0) -> Node3D:
	var root := Node3D.new()
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(0.95, 0.78, 0.2)
	gold.metallic = 0.8
	gold.roughness = 0.3
	gold.emission_enabled = true
	gold.emission = Color(0.55, 0.4, 0.05)
	gold.emission_energy_multiplier = 0.6
	var jade := StandardMaterial3D.new()
	jade.albedo_color = Color(0.1, 0.65, 0.4)
	jade.roughness = 0.4
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.1, 0.07, 0.05)

	# cara, ojos, boca y plumas
	var parts := [
		[Vector3(0.5, 0.62, 0.12), Vector3(0, 0, 0), gold],
		[Vector3(0.11, 0.1, 0.05), Vector3(-0.12, 0.12, 0.07), dark],
		[Vector3(0.11, 0.1, 0.05), Vector3(0.12, 0.12, 0.07), dark],
		[Vector3(0.26, 0.07, 0.05), Vector3(0, -0.18, 0.07), dark],
		[Vector3(0.1, 0.34, 0.06), Vector3(-0.3, 0.42, 0), jade],
		[Vector3(0.1, 0.42, 0.06), Vector3(0, 0.5, 0), jade],
		[Vector3(0.1, 0.34, 0.06), Vector3(0.3, 0.42, 0), jade],
	]
	for p in parts:
		var mesh := BoxMesh.new()
		mesh.size = p[0] * s
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = p[2]
		mi.position = p[1] * s
		root.add_child(mi)
	return root


func _ready() -> void:
	_base_y = position.y
	_t = randf() * TAU
	add_child(build_mask_mesh(1.0))

	var light := OmniLight3D.new()
	light.light_color = Color(0.4, 1.0, 0.6)
	light.light_energy = 0.8
	light.omni_range = 4.0
	add_child(light)

	var col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.1
	col.shape = sphere
	add_child(col)

	monitorable = false
	body_entered.connect(_on_body)


func _process(delta: float) -> void:
	_t += delta
	rotation.y += 2.0 * delta
	position.y = _base_y + sin(_t * 2.2) * 0.15


func _on_body(body: Node3D) -> void:
	if _taken or not body.is_in_group("player"):
		return
	_taken = true
	Game.add_mask()
	set_deferred("monitoring", false)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "position:y", position.y + 1.5, 0.35)
	tw.tween_property(self, "scale", Vector3.ONE * 0.05, 0.35)
	tw.chain().tween_callback(queue_free)
