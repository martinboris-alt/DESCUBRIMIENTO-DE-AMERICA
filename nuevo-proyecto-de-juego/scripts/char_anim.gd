class_name CharAnim
extends RefCounted
## Animación procedural compartida (andar/idle/brazos) sobre el esqueleto
## del conquistador de Meshy. La usan jugador y enemigos.

var _skeleton: Skeleton3D
var _bones := {}
var _rests := {}
var _t := 0.0
var _blend := 0.0


func setup(root: Node) -> bool:
	_skeleton = _find_skeleton(root)
	if not _skeleton:
		return false
	for n in ["thigh.L", "thigh.R", "shin.L", "shin.R",
			"upper_arm.L", "upper_arm.R", "forearm.L", "forearm.R",
			"spine", "chest"]:
		var idx := _skeleton.find_bone(n)
		if idx >= 0:
			_bones[n] = idx
			# la pose debe componerse con el reposo: set_bone_pose_rotation
			# REEMPLAZA la rotación local, no la suma
			_rests[n] = _skeleton.get_bone_rest(idx).basis.get_rotation_quaternion()
	return not _bones.is_empty()


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found:
			return found
	return null


func update(speed: float, delta: float, arms_out: float = 0.0) -> void:
	if not _skeleton or _bones.is_empty():
		return

	var moving := speed > 0.3
	_blend = move_toward(_blend, 1.0 if moving else 0.0, delta * 8.0)
	_t += delta * (speed * 1.9 if moving else 0.8)
	var t := _t

	var walk := sin(t) * 0.55 * _blend

	_rot("thigh.L", walk, 0.0)
	_rot("thigh.R", -walk, 0.0)
	_rot("shin.L", maxf(-sin(t) * 0.45, 0.0) * _blend, 0.0)
	_rot("shin.R", maxf(sin(t) * 0.45, 0.0) * _blend, 0.0)

	_rot("upper_arm.L", -walk * 0.5, arms_out * 1.25)
	_rot("upper_arm.R", walk * 0.5, -arms_out * 1.25)
	_rot("forearm.L", maxf(-sin(t) * 0.22, 0.0) * _blend, arms_out * 0.4)
	_rot("forearm.R", maxf(sin(t) * 0.22, 0.0) * _blend, -arms_out * 0.4)

	var breath := sin(t) * 0.010 * (1.0 - _blend)
	var bob := sin(t * 2.0) * 0.018 * _blend
	_rot("spine", bob + breath, 0.0)
	_rot("chest", bob * 0.5 + breath * 0.4, 0.0)


func _rot(bone: String, rx: float, rz: float) -> void:
	if bone not in _bones:
		return
	var q: Quaternion = _rests[bone] * Quaternion.from_euler(Vector3(rx, 0.0, rz))
	_skeleton.set_bone_pose_rotation(_bones[bone], q)
