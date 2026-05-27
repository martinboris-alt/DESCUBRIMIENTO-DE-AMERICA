extends StaticBody3D

func _ready() -> void:
	_build()

func _mat(col: Color, rough: float = 0.95, metal: float = 0.0, emit: Color = Color.BLACK) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	if emit != Color.BLACK:
		m.emission_enabled = true
		m.emission = emit
		m.emission_energy_multiplier = 0.6
	return m

func _add_box(pos: Vector3, size: Vector3, mat: Material, collide: bool = true) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mi)
	if collide:
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		col.shape = box
		col.position = pos
		add_child(col)

func _build() -> void:
	var stone      := _mat(Color(0.68, 0.62, 0.50), 0.90)
	var stone_edge := _mat(Color(0.42, 0.38, 0.28), 0.95)
	var red_paint  := _mat(Color(0.72, 0.08, 0.04), 0.70, 0.0, Color(0.5, 0.02, 0.01))
	var door_mat   := _mat(Color(0.05, 0.04, 0.02), 0.98)

	# Each step: [width, height]
	var steps: Array = [
		[22.0, 2.6],
		[17.6, 2.6],
		[13.2, 2.6],
		[8.8,  2.6],
		[4.4,  2.6],
	]

	var y := 0.0
	for i in steps.size():
		var w: float = steps[i][0]
		var h: float = steps[i][1]
		# Main platform block
		_add_box(Vector3(0, y + h * 0.5, 0), Vector3(w, h, w), stone)
		# Top edge darker band
		_add_box(Vector3(0, y + h - 0.09, 0), Vector3(w + 0.05, 0.20, w + 0.05), stone_edge, false)
		# Red painted band at lower third
		_add_box(Vector3(0, y + h * 0.28, 0), Vector3(w + 0.03, h * 0.10, w + 0.03), red_paint, false)
		y += h

	# Temple structure
	var tw := 4.6
	var th := 4.0
	_add_box(Vector3(0, y + th * 0.5, 0), Vector3(tw, th, tw), stone)
	# Roof slab
	_add_box(Vector3(0, y + th + 0.22, 0), Vector3(tw + 0.7, 0.45, tw + 0.7), stone_edge, false)
	# Doorway (south face)
	_add_box(Vector3(0, y + 1.1, -(tw * 0.5) - 0.01), Vector3(1.3, 2.2, 0.22), door_mat, false)
	# Lintel above door
	_add_box(Vector3(0, y + 2.3, -(tw * 0.5) + 0.02), Vector3(1.7, 0.28, 0.20), stone_edge, false)
	y += th

	# Altar on top
	_add_box(Vector3(0, y + 0.30, 0), Vector3(1.1, 0.60, 1.1), stone_edge, false)
	_add_box(Vector3(0, y + 0.75, 0), Vector3(0.60, 0.45, 0.60), red_paint, false)

	# Staircase up south face
	_build_stairs(steps)

func _build_stairs(steps: Array) -> void:
	var total_h := 0.0
	for s: Array in steps:
		total_h += float(s[1])

	var n_stairs := 28
	var step_h: float   = total_h / n_stairs
	var base_z: float   = float(steps[0][0]) * 0.5
	var stair_w: float  = float(steps[0][0]) * 0.48
	var step_depth: float = base_z * 0.9 / n_stairs

	var stair_mat := _mat(Color(0.55, 0.51, 0.41))

	for i in n_stairs:
		var fi: float = float(i)
		var z: float  = -(base_z - fi * step_depth)
		_add_box(
			Vector3(0, fi * step_h + step_h * 0.5, z),
			Vector3(stair_w, step_h * 0.96, step_depth),
			stair_mat, false
		)
