extends Node3D

func _ready() -> void:
	_build()

func _mat(col: Color, rough: float = 0.85, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	return m

func _mi(mesh: Mesh, pos: Vector3, mat: Material, rot_y: float = 0.0) -> void:
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.position = pos
	if rot_y != 0.0:
		n.rotation.y = rot_y
	n.material_override = mat
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(n)

func _build() -> void:
	var steel   := _mat(Color(0.72, 0.74, 0.78), 0.25, 0.85)
	var brown   := _mat(Color(0.20, 0.11, 0.04))
	var skin    := _mat(Color(0.88, 0.70, 0.53))
	var crimson := _mat(Color(0.76, 0.06, 0.06))
	var gold    := _mat(Color(0.85, 0.67, 0.12), 0.15, 1.0)
	var leather := _mat(Color(0.38, 0.23, 0.09))

	# Legs / chausses
	var legs := CapsuleMesh.new()
	legs.radius = 0.18
	legs.height = 0.95
	_mi(legs, Vector3(0, 0.48, 0), brown)

	# Boots
	for s: int in [-1, 1]:
		var boot := CylinderMesh.new()
		boot.top_radius = 0.1
		boot.bottom_radius = 0.13
		boot.height = 0.28
		_mi(boot, Vector3(s * 0.1, 0.14, 0), leather)

	# Belt
	var belt := CylinderMesh.new()
	belt.top_radius = 0.28
	belt.bottom_radius = 0.28
	belt.height = 0.09
	_mi(belt, Vector3(0, 0.79, 0), leather)

	# Torso / breastplate
	var torso := CylinderMesh.new()
	torso.top_radius = 0.20
	torso.bottom_radius = 0.27
	torso.height = 0.62
	_mi(torso, Vector3(0, 1.08, 0), steel)

	# Gorget (neck guard)
	var gorget := CylinderMesh.new()
	gorget.top_radius = 0.13
	gorget.bottom_radius = 0.18
	gorget.height = 0.16
	_mi(gorget, Vector3(0, 1.46, 0), steel)

	# Pauldrons (shoulder plates)
	for s: int in [-1, 1]:
		var pauldron := SphereMesh.new()
		pauldron.radius = 0.11
		_mi(pauldron, Vector3(s * 0.30, 1.38, 0), steel)
		var vambrace := CylinderMesh.new()
		vambrace.top_radius = 0.075
		vambrace.bottom_radius = 0.085
		vambrace.height = 0.32
		_mi(vambrace, Vector3(s * 0.35, 1.12, 0), steel)

	# Cape (red)
	var cape := BoxMesh.new()
	cape.size = Vector3(0.50, 0.80, 0.06)
	_mi(cape, Vector3(0, 1.02, -0.27), crimson)

	# Head
	var head := SphereMesh.new()
	head.radius = 0.20
	_mi(head, Vector3(0, 1.71, 0), skin)

	# Morion helmet – bowl
	var helm_bowl := CylinderMesh.new()
	helm_bowl.top_radius = 0.17
	helm_bowl.bottom_radius = 0.24
	helm_bowl.height = 0.20
	_mi(helm_bowl, Vector3(0, 1.91, 0), steel)

	# Morion – crest (vertical fin front-back)
	var crest := BoxMesh.new()
	crest.size = Vector3(0.038, 0.24, 0.38)
	_mi(crest, Vector3(0, 2.06, 0), steel)

	# Morion – side brims
	for z_side: int in [-1, 1]:
		var brim := BoxMesh.new()
		brim.size = Vector3(0.46, 0.04, 0.13)
		_mi(brim, Vector3(0, 1.83, z_side * 0.28), steel)

	# Sword – blade
	var blade := BoxMesh.new()
	blade.size = Vector3(0.042, 0.72, 0.038)
	_mi(blade, Vector3(0.46, 0.78, 0.04), steel)

	# Sword – crossguard
	var guard := BoxMesh.new()
	guard.size = Vector3(0.22, 0.042, 0.05)
	_mi(guard, Vector3(0.46, 1.16, 0.04), gold)

	# Sword – handle
	var handle := CylinderMesh.new()
	handle.top_radius = 0.028
	handle.bottom_radius = 0.033
	handle.height = 0.18
	_mi(handle, Vector3(0.46, 1.30, 0.04), leather)

	# Sword – pommel
	var pommel := SphereMesh.new()
	pommel.radius = 0.052
	_mi(pommel, Vector3(0.46, 1.41, 0.04), gold)
