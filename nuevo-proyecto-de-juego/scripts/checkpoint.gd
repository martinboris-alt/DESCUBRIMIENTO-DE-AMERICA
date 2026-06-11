extends Area3D
## Estela de piedra: punto de control. Se ilumina al activarse.

var _active := false
var _glyph_mat: StandardMaterial3D


func _ready() -> void:
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.55, 0.52, 0.46)
	stone.roughness = 0.95

	var pillar := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.7, 2.2, 0.4)
	pillar.mesh = box
	pillar.material_override = stone
	pillar.position.y = 1.1
	add_child(pillar)

	var cap := MeshInstance3D.new()
	var cap_mesh := BoxMesh.new()
	cap_mesh.size = Vector3(0.9, 0.25, 0.6)
	cap.mesh = cap_mesh
	cap.material_override = stone
	cap.position.y = 2.32
	add_child(cap)

	_glyph_mat = StandardMaterial3D.new()
	_glyph_mat.albedo_color = Color(0.4, 0.38, 0.34)
	_glyph_mat.emission_enabled = true
	_glyph_mat.emission = Color(0.1, 0.1, 0.1)
	_glyph_mat.emission_energy_multiplier = 0.4
	var glyph := MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(0.45, 0.45, 0.06)
	glyph.mesh = gm
	glyph.material_override = _glyph_mat
	glyph.position = Vector3(0, 1.5, 0.2)
	glyph.rotation.z = PI / 4.0
	add_child(glyph)

	var col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 2.6
	col.shape = sphere
	col.position.y = 1.0
	add_child(col)

	monitorable = false
	body_entered.connect(_on_body)


func _on_body(body: Node3D) -> void:
	if _active or not body.is_in_group("player"):
		return
	_active = true
	Game.set_checkpoint(global_position + Vector3.UP * 0.2)
	_glyph_mat.emission = Color(0.2, 1.0, 0.4)
	_glyph_mat.emission_energy_multiplier = 2.2
	_glyph_mat.albedo_color = Color(0.3, 0.9, 0.45)
