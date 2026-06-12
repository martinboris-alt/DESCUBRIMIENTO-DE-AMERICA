extends Node3D
## Construye el nivel actual de la campaña (datos en level_data.gd):
## senda estilo Crash con huecos, jungla, cajas, enemigos, máscaras...
## y según el nivel: bola perseguidora o jefe final.

const TREE_SCENE := preload("res://assets/models/jungle_tree_opt.glb")
const RUIN_SCENE := preload("res://assets/models/ruin_column_opt.glb")
const BLOCK_SCENE := preload("res://assets/models/temple_block_opt.glb")
const WATER_SHADER := preload("res://assets/shaders/water.gdshader")

const CoinScript := preload("res://scripts/coin.gd")
const CrateScript := preload("res://scripts/crate.gd")
const IdolScript := preload("res://scripts/idol.gd")
const CheckpointScript := preload("res://scripts/checkpoint.gd")
const SpikeScript := preload("res://scripts/spike_trap.gd")
const EnemyScript := preload("res://scripts/enemy.gd")
const MaskScript := preload("res://scripts/mask.gd")
const BoulderScript := preload("res://scripts/boulder.gd")
const BossScript := preload("res://scripts/boss.gd")

const HALF_W := 3.5
const WATER_Y := -2.3

var def := {}
var gaps := []
var curve := Curve3D.new()
var clen := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	def = LevelData.get_level(Game.level_index)
	gaps = def.gaps
	_rng.seed = 1519 + Game.level_index
	_build_curve()
	_build_environment()
	_build_ground()
	_build_water()
	_build_beach()
	_build_jungle()
	_build_ruins()
	_build_crates()
	_build_coins()
	_build_enemies()
	_build_checkpoints()
	_build_idols()
	_build_masks()
	_build_spikes()
	_build_finale()

	var player: CharacterBody3D = $Player
	var rig: Node3D = $CameraRig
	Game.level_start()
	Game.player = player
	player.cam_rig = rig
	var spawn := _pos(4.0, 0.0, 1.2)
	Game.set_checkpoint(spawn, true)
	player.teleport(spawn)
	rig.setup(player, curve)

	if def.boulder:
		var boulder := Node3D.new()
		boulder.set_script(BoulderScript)
		boulder.curve = curve
		boulder.clen = clen
		add_child(boulder)


# ── Helpers de senda ──────────────────────────────────────────────────

func _build_curve() -> void:
	var wps: Array = def.waypoints
	for wp in wps:
		curve.add_point(wp)
	for i in wps.size():
		var prev: Vector3 = wps[maxi(i - 1, 0)]
		var next: Vector3 = wps[mini(i + 1, wps.size() - 1)]
		var dir: Vector3 = (next - prev) * 0.22
		curve.set_point_in(i, -dir)
		curve.set_point_out(i, dir)
	clen = curve.get_baked_length()


func _fwd(d: float) -> Vector3:
	var a := curve.sample_baked(clampf(d - 1.0, 0.0, clen))
	var b := curve.sample_baked(clampf(d + 1.0, 0.0, clen))
	var t := b - a
	t.y = 0.0
	return t.normalized() if t.length() > 0.01 else Vector3.FORWARD


func _pos(d: float, lat: float = 0.0, dy: float = 0.0) -> Vector3:
	d = clampf(d, 0.0, clen)
	var p := curve.sample_baked(d)
	var side := _fwd(d).cross(Vector3.UP).normalized()
	return p + side * lat + Vector3.UP * dy


func _in_gap(d: float, margin: float = 0.0) -> bool:
	for g in gaps:
		if d > g[0] - margin and d < g[1] + margin:
			return true
	return false


# ── Entorno ───────────────────────────────────────────────────────────

func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = def.sky_top
	sky_mat.sky_horizon_color = def.sky_horizon
	sky_mat.ground_bottom_color = Color(0.2, 0.3, 0.25)
	sky_mat.ground_horizon_color = def.sky_horizon
	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 1.1
	env.glow_enabled = true
	env.glow_intensity = 0.22
	env.glow_bloom = 0.02
	env.ssao_enabled = true
	env.ssao_intensity = 1.4
	env.fog_enabled = true
	env.fog_light_color = def.sky_horizon
	env.fog_density = 0.0028
	env.fog_sky_affect = 0.25
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.18
	env.adjustment_brightness = 1.0

	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_color = def.sun_color
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 130.0
	add_child(sun)


# ── Suelo: cinta con huecos ───────────────────────────────────────────

func _build_ground() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var grass := Color(0.3, 0.55, 0.18)
	var dirt := Color(0.56, 0.42, 0.24)
	var rock := Color(0.32, 0.26, 0.19)

	var lats := [-HALF_W, -HALF_W * 0.45, HALF_W * 0.45, HALF_W]
	var cols := [grass, dirt, dirt, grass]

	var step := 1.5
	var rows := int(clen / step) + 1

	var row_pts: Array = []
	var row_solid: Array = []
	for r in rows + 1:
		var d := minf(r * step, clen)
		var p := curve.sample_baked(d)
		var side := _fwd(d).cross(Vector3.UP).normalized()
		var pts: Array[Vector3] = []
		for lt in lats:
			pts.append(p + side * lt)
		row_pts.append(pts)
		row_solid.append(not _in_gap(d + step * 0.5) or r == rows)

	var jitter := func(c: Color, k: float) -> Color:
		return Color(c.r * (1.0 + k), c.g * (1.0 + k * 0.6), c.b * (1.0 + k), 1.0)

	for r in rows:
		var solid: bool = row_solid[r] and not _in_gap(r * step + 0.1) and not _in_gap((r + 1) * step - 0.1)
		var a: Array = row_pts[r]
		var b: Array = row_pts[r + 1]
		var floor_a: Vector3 = a[0]
		var skirt_a := Vector3(0, WATER_Y - 1.2 - floor_a.y, 0)
		var floor_b: Vector3 = b[0]
		var skirt_b := Vector3(0, WATER_Y - 1.2 - floor_b.y, 0)
		if solid:
			for i in 3:
				var k := _rng.randf_range(-0.08, 0.08)
				_quad(st, a[i], a[i + 1], b[i + 1], b[i],
					jitter.call(cols[i], k), jitter.call(cols[i + 1], k))
			_quad(st, a[0] + skirt_a, a[0], b[0], b[0] + skirt_b, rock, rock)
			_quad(st, a[3], a[3] + skirt_a, b[3] + skirt_b, b[3], rock, rock)
		else:
			if r > 0 and row_solid[r - 1] and not _in_gap((r - 0.5) * step):
				for i in 3:
					_quad(st, a[i + 1], a[i], a[i] + skirt_a,
						a[i + 1] + skirt_a, rock, rock)
			if r < rows - 1 and not _in_gap((r + 1.5) * step):
				for i in 3:
					_quad(st, b[i], b[i + 1], b[i + 1] + skirt_b,
						b[i] + skirt_b, rock, rock)

	st.generate_normals()
	var mesh := st.commit()

	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	add_child(mi)

	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape: ConcavePolygonShape3D = mesh.create_trimesh_shape()
	shape.backface_collision = true
	col.shape = shape
	body.add_child(col)
	add_child(body)


func _quad(st: SurfaceTool, p1: Vector3, p2: Vector3, p3: Vector3, p4: Vector3,
		c12: Color, c34: Color) -> void:
	# winding horario (front-face en Godot) visto desde arriba/fuera
	st.set_color(c12); st.add_vertex(p1)
	st.set_color(c34); st.add_vertex(p3)
	st.set_color(c34); st.add_vertex(p2)
	st.set_color(c12); st.add_vertex(p1)
	st.set_color(c12); st.add_vertex(p4)
	st.set_color(c34); st.add_vertex(p3)


func _build_water() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(1000, 1000)
	plane.subdivide_width = 50
	plane.subdivide_depth = 50
	var mat := ShaderMaterial.new()
	mat.shader = WATER_SHADER
	mat.set_shader_parameter("wave_speed", 0.8)
	mat.set_shader_parameter("wave_height", 0.12)
	mat.set_shader_parameter("color_shallow", Color(0.12, 0.62, 0.66, 0.85))
	mat.set_shader_parameter("color_deep", Color(0.02, 0.28, 0.45, 0.96))
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.material_override = mat
	mi.position = Vector3(0, WATER_Y, -170)
	add_child(mi)


func _build_beach() -> void:
	var sand := StandardMaterial3D.new()
	sand.albedo_color = Color(0.88, 0.8, 0.58)
	sand.roughness = 1.0

	var body := StaticBody3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 10.0
	cyl.bottom_radius = 11.5
	cyl.height = 3.2
	var mi := MeshInstance3D.new()
	mi.mesh = cyl
	mi.material_override = sand
	body.add_child(mi)
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 10.0
	shape.height = 3.2
	col.shape = shape
	body.add_child(col)
	var base := _pos(2.0)
	body.position = base + Vector3.DOWN * 1.55
	add_child(body)

	if Game.level_index == 0:
		var boat := Node3D.new()
		var hull_mat := StandardMaterial3D.new()
		hull_mat.albedo_color = Color(0.35, 0.22, 0.1)
		hull_mat.roughness = 0.9
		var sail_mat := StandardMaterial3D.new()
		sail_mat.albedo_color = Color(0.93, 0.9, 0.8)
		for part in [
			[Vector3(2.4, 1.2, 6.5), Vector3(0, 0.6, 0), hull_mat],
			[Vector3(2.8, 0.5, 7.2), Vector3(0, 1.3, 0), hull_mat],
			[Vector3(0.22, 5.0, 0.22), Vector3(0, 3.6, 0.4), hull_mat],
			[Vector3(0.1, 2.8, 2.4), Vector3(0, 4.2, 0.4), sail_mat],
		]:
			var bm := BoxMesh.new()
			bm.size = part[0]
			var bmi := MeshInstance3D.new()
			bmi.mesh = bm
			bmi.material_override = part[2]
			bmi.position = part[1]
			boat.add_child(bmi)
		boat.position = base + _fwd(2.0).cross(Vector3.UP) * 14.0
		boat.position.y = WATER_Y + 0.4
		boat.rotation.y = 0.5
		add_child(boat)


# ── Jungla con MultiMesh ──────────────────────────────────────────────

func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found := _find_mesh_instance(child)
		if found:
			return found
	return null


func _extract_mesh(scene: PackedScene) -> Mesh:
	var inst := scene.instantiate()
	var mi := _find_mesh_instance(inst)
	var mesh: Mesh = null
	if mi:
		mesh = mi.mesh.duplicate()
		for i in mesh.get_surface_count():
			var mat := mi.get_active_material(i)
			if mat:
				mesh.surface_set_material(i, mat)
	inst.free()
	return mesh


func _multimesh(mesh: Mesh, transforms: Array) -> void:
	if not mesh or transforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)


func _build_jungle() -> void:
	var tree_mesh := _extract_mesh(TREE_SCENE)
	if not tree_mesh:
		return
	var aabb := tree_mesh.get_aabb()
	var base_scale := 9.0 / maxf(aabb.size.y, 0.01)

	var transforms: Array = []
	var d := 4.0
	while d < clen - 8.0:
		for side_sign: float in [-1.0, 1.0]:
			if _rng.randf() < 0.82:
				var lat := side_sign * (HALF_W + 1.2 + _rng.randf() * 2.6)
				var p := _pos(d + _rng.randf_range(-1.0, 1.0), lat, 0.0)
				p.y -= _rng.randf_range(1.2, 3.0)
				var s := base_scale * _rng.randf_range(0.7, 1.3)
				var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * s)
				transforms.append(Transform3D(basis, p))
		d += 2.4
	d = 0.0
	while d < clen:
		for side_sign: float in [-1.0, 1.0]:
			var lat := side_sign * (14.0 + _rng.randf() * 14.0)
			var p := _pos(d, lat, 0.0)
			p.y = WATER_Y - 0.5
			var s := base_scale * _rng.randf_range(1.5, 2.3)
			var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * s)
			transforms.append(Transform3D(basis, p))
		d += 7.0
	_multimesh(tree_mesh, transforms)

	var bush := SphereMesh.new()
	bush.radius = 0.6
	bush.height = 0.8
	var bush_mat := StandardMaterial3D.new()
	bush_mat.albedo_color = Color(0.22, 0.46, 0.14)
	bush_mat.roughness = 1.0
	bush.material = bush_mat
	var bush_tf: Array = []
	d = 3.0
	while d < clen - 6.0:
		if not _in_gap(d, 1.0) and _rng.randf() < 0.75:
			var lat := (HALF_W - 0.4) * (1.0 if int(d / 3.0) % 2 == 0 else -1.0)
			var p := _pos(d, lat + _rng.randf_range(-0.5, 0.5), 0.1)
			var s := _rng.randf_range(0.7, 1.7)
			bush_tf.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * s), p))
		d += 3.0
	_multimesh(bush, bush_tf)

	var rock := SphereMesh.new()
	rock.radius = 0.5
	rock.height = 0.7
	var rock_mat := StandardMaterial3D.new()
	rock_mat.albedo_color = Color(0.52, 0.5, 0.46)
	rock_mat.roughness = 0.95
	rock.material = rock_mat
	var rock_tf: Array = []
	d = 9.0
	while d < clen - 6.0:
		if not _in_gap(d, 1.0) and _rng.randf() < 0.6:
			var lat := _rng.randf_range(-HALF_W + 0.6, HALF_W - 0.6)
			var p := _pos(d, lat, 0.05)
			var s := _rng.randf_range(0.5, 1.1)
			rock_tf.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * s), p))
		d += 11.0
	_multimesh(rock, rock_tf)


func _build_ruins() -> void:
	var col_mesh := _extract_mesh(RUIN_SCENE)
	var block_mesh := _extract_mesh(BLOCK_SCENE)
	if col_mesh:
		var aabb := col_mesh.get_aabb()
		var tf: Array = []
		var d := 40.0
		while d < clen - 30.0:
			var lat := 5.5 * (1.0 if int(d / 35.0) % 2 == 0 else -1.0)
			var s: float = _rng.randf_range(2.4, 3.4) / maxf(aabb.size.y, 0.01)
			tf.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * s),
				_pos(d, lat, -0.15)))
			d += 35.0
		_multimesh(col_mesh, tf)
	if block_mesh:
		var aabb := block_mesh.get_aabb()
		var tf: Array = []
		var d := 60.0
		while d < clen - 30.0:
			var lat := 4.5 * (-1.0 if int(d / 70.0) % 2 == 0 else 1.0)
			var s: float = 1.6 / maxf(aabb.size.y, 0.01)
			tf.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * s),
				_pos(d, lat, -0.45)))
			d += 70.0
		_multimesh(block_mesh, tf)


# ── Entidades ─────────────────────────────────────────────────────────

func _build_crates() -> void:
	for c in def.crates:
		var crate := StaticBody3D.new()
		crate.set_script(CrateScript)
		crate.is_tnt = c[2]
		crate.position = _pos(c[0], c[1], c[3])
		crate.rotation.y = _rng.randf_range(-0.2, 0.2)
		add_child(crate)


func _build_coins() -> void:
	# tramos de monedas genéricos cada ~22 m
	var d := 12.0
	var lane := 0
	while d < clen - 24.0:
		var lat: float = [0.0, 1.4, -1.4][lane % 3]
		lane += 1
		for i in 6:
			var cd := d + i * 1.7
			if not _in_gap(cd, 0.6):
				_spawn_coin(_pos(cd, lat, 0.95))
		d += 22.0
	# arcos sobre los huecos
	for g in gaps:
		var d0: float = g[0] - 1.5
		var d1: float = g[1] + 1.5
		var y0 := curve.sample_baked(clampf(d0, 0, clen)).y
		var y1 := curve.sample_baked(clampf(d1, 0, clen)).y
		for i in 5:
			var t := i / 4.0
			var p := _pos(lerpf(d0, d1, t), 0.0, 0.0)
			p.y = lerpf(y0, y1, t) + 1.0 + sin(t * PI) * 1.7
			_spawn_coin(p)


func _spawn_coin(p: Vector3) -> void:
	var coin := Area3D.new()
	coin.set_script(CoinScript)
	coin.position = p
	add_child(coin)


func _build_enemies() -> void:
	for e in def.enemies:
		var enemy := CharacterBody3D.new()
		enemy.set_script(EnemyScript)
		var visuals: Node3D = preload("res://assets/models/conquistador_lowpoly.glb").instantiate()
		visuals.name = "Visuals"
		enemy.add_child(visuals)
		var col := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = 0.38
		cap.height = 1.6
		col.shape = cap
		col.position.y = 0.8
		enemy.add_child(col)
		enemy.position = _pos(e[0], e[1], 0.6)
		var dir := _fwd(e[0]).cross(Vector3.UP) if e[2] else _fwd(e[0])
		enemy.patrol_vec = dir * 2.5
		enemy.speed_mult = def.enemy_speed
		add_child(enemy)


func _build_checkpoints() -> void:
	for c in def.checkpoints:
		var cp := Area3D.new()
		cp.set_script(CheckpointScript)
		cp.position = _pos(c[0], c[1], 0.0)
		cp.rotation.y = atan2(_fwd(c[0]).x, _fwd(c[0]).z)
		add_child(cp)


func _build_idols() -> void:
	for idata in def.idols:
		var base := _pos(idata[0], idata[1], 0.0)
		if idata[2] > 0.0:
			var path_y := curve.sample_baked(clampf(idata[0], 0, clen)).y
			base.y = path_y + idata[2]
			_stone_platform(base, Vector3(2.8, 0.5, 2.8))
			base += Vector3.UP * 0.25
		var idol := Area3D.new()
		idol.set_script(IdolScript)
		idol.position = base
		add_child(idol)


func _build_masks() -> void:
	for m in def.masks:
		var mask := Area3D.new()
		mask.set_script(MaskScript)
		mask.position = _pos(m[0], m[1], 1.2)
		add_child(mask)


func _stone_platform(pos: Vector3, size: Vector3) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.57, 0.5)
	mat.roughness = 0.95
	var body := StaticBody3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	body.add_child(mi)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	body.position = pos
	add_child(body)


func _build_spikes() -> void:
	for s in def.spikes:
		var trap := Node3D.new()
		trap.set_script(SpikeScript)
		trap.phase_offset = s[2]
		trap.position = _pos(s[0], s[1], 0.05)
		add_child(trap)


# ── Final del nivel: templo+meta, santuario, o arena del jefe ─────────

func _build_finale() -> void:
	var end_pos := curve.sample_baked(clen)
	var u := _fwd(clen)
	var center := end_pos + u * 14.0
	center.y = end_pos.y

	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.72, 0.66, 0.54)
	stone.roughness = 0.9
	var stone_dark := StandardMaterial3D.new()
	stone_dark.albedo_color = Color(0.5, 0.45, 0.34)
	stone_dark.roughness = 0.95

	# plaza (más grande si hay jefe)
	var plaza_r := 17.0 if not def.boss else 19.0
	var plaza := StaticBody3D.new()
	var pl_mesh := CylinderMesh.new()
	pl_mesh.top_radius = plaza_r
	pl_mesh.bottom_radius = plaza_r + 2.0
	pl_mesh.height = 3.0
	var pl_mi := MeshInstance3D.new()
	pl_mi.mesh = pl_mesh
	pl_mi.material_override = stone_dark
	plaza.add_child(pl_mi)
	var pl_col := CollisionShape3D.new()
	var pl_shape := CylinderShape3D.new()
	pl_shape.radius = plaza_r
	pl_shape.height = 3.0
	pl_col.shape = pl_shape
	plaza.add_child(pl_col)
	plaza.position = center + Vector3.DOWN * 1.5
	add_child(plaza)

	# columnas flanqueando la llegada
	var col_mesh := _extract_mesh(RUIN_SCENE)
	if col_mesh:
		var aabb := col_mesh.get_aabb()
		var s := 3.4 / maxf(aabb.size.y, 0.01)
		var tf: Array = []
		var side := u.cross(Vector3.UP)
		for side_sign: float in [-1.0, 1.0]:
			tf.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * s),
				end_pos + u * 4.0 + side * side_sign * 5.0))
		if def.boss:
			# anillo de columnas alrededor de la arena
			for k in 6:
				var ang := TAU * k / 6.0 + 0.4
				tf.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * s),
					center + Vector3(cos(ang), 0, sin(ang)) * (plaza_r - 2.0)))
		_multimesh(col_mesh, tf)

	if def.boulder:
		# santuario sencillo con el ídolo-meta
		_stone_platform(center + Vector3.UP * 0.4, Vector3(5.0, 0.8, 5.0))
		var goal := Area3D.new()
		goal.set_script(IdolScript)
		goal.is_goal = true
		goal.position = center + Vector3.UP * 0.9
		add_child(goal)
		return

	# pirámide (al fondo de la plaza; decorativa, la meta va delante)
	var temple_c := center + u * 7.0 if not def.boss else center + u * (plaza_r + 8.0)
	var temple := StaticBody3D.new()
	temple.position = temple_c
	add_child(temple)
	var red_paint := StandardMaterial3D.new()
	red_paint.albedo_color = Color(0.72, 0.1, 0.06)
	red_paint.roughness = 0.7
	red_paint.emission_enabled = true
	red_paint.emission = Color(0.4, 0.03, 0.01)
	red_paint.emission_energy_multiplier = 0.5
	var widths := [20.0, 16.6, 13.2, 9.8, 6.4]
	var step_h := 1.2
	var y := 0.0
	for i in widths.size():
		var w: float = widths[i]
		var box := BoxMesh.new()
		box.size = Vector3(w, step_h, w)
		var mi := MeshInstance3D.new()
		mi.mesh = box
		mi.material_override = stone
		mi.position = Vector3(0, y + step_h * 0.5, 0)
		temple.add_child(mi)
		var band := BoxMesh.new()
		band.size = Vector3(w + 0.06, step_h * 0.16, w + 0.06)
		var band_mi := MeshInstance3D.new()
		band_mi.mesh = band
		band_mi.material_override = red_paint if i % 2 == 0 else stone_dark
		band_mi.position = Vector3(0, y + step_h * 0.82, 0)
		temple.add_child(band_mi)
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = box.size
		col.shape = shape
		col.position = mi.position
		temple.add_child(col)
		y += step_h

	var total_h := step_h * widths.size()

	if def.boss:
		var boss := CharacterBody3D.new()
		boss.set_script(BossScript)
		boss.arena_center = center
		boss.goal_script = IdolScript
		boss.position = center + u * 6.0 + Vector3.UP * 0.5
		add_child(boss)
		for side_sign: float in [-1.0, 1.0]:
			var torch := OmniLight3D.new()
			torch.light_color = Color(1.0, 0.5, 0.15)
			torch.light_energy = 2.4
			torch.omni_range = 12.0
			torch.position = center + u.cross(Vector3.UP) * side_sign * (plaza_r - 3.0) \
				+ Vector3.UP * 3.0
			add_child(torch)
		return

	# meta sobre un pedestal en la plaza, frente a la pirámide
	var goal_pos := center - u * 6.0
	goal_pos.y = center.y
	_stone_platform(goal_pos + Vector3.DOWN * 0.25, Vector3(4.0, 0.5, 4.0))
	var goal := Area3D.new()
	goal.set_script(IdolScript)
	goal.is_goal = true
	goal.position = goal_pos + Vector3.UP * 0.3
	add_child(goal)

	for side_sign: float in [-1.0, 1.0]:
		var torch := OmniLight3D.new()
		torch.light_color = Color(1.0, 0.6, 0.2)
		torch.light_energy = 2.0
		torch.omni_range = 8.0
		torch.position = goal_pos + u.cross(Vector3.UP) * side_sign * 3.0 + Vector3.UP * 1.5
		add_child(torch)
