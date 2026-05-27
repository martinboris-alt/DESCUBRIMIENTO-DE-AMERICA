extends Node3D

var _skeleton: Skeleton3D
var _bones: Dictionary = {}
var _time: float = 0.0
var _blend: float = 0.0  # 0=idle, 1=walk

func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_find_skeleton(self)
	if _skeleton:
		_cache_bones()
	else:
		push_warning("character_anim: Skeleton3D not found")


func _find_skeleton(node: Node) -> void:
	if node is Skeleton3D:
		_skeleton = node
		return
	for child in node.get_children():
		_find_skeleton(child)


func _cache_bones() -> void:
	var names := [
		"DEF-thigh.L", "DEF-thigh.R",
		"DEF-shin.L",  "DEF-shin.R",
		"DEF-upper_arm.L", "DEF-upper_arm.R",
		"DEF-forearm.L",   "DEF-forearm.R",
		"DEF-spine",  "DEF-spine.001", "DEF-spine.003",
	]
	for n in names:
		var idx := _skeleton.find_bone(n)
		if idx >= 0:
			_bones[n] = idx


func animate(speed: float, delta: float) -> void:
	if not _skeleton or _bones.is_empty():
		return

	var is_moving := speed > 0.3
	_blend = move_toward(_blend, 1.0 if is_moving else 0.0, delta * 8.0)

	if is_moving:
		_time += delta * speed * 1.8
	else:
		# Idle: slow breathing cycle
		_time += delta * 0.8

	var t := _time

	# ── WALK ────────────────────────────────────────────────────────────────
	var walk_swing := sin(t) * 0.5 * _blend

	# Thighs
	_rot("DEF-thigh.L",  walk_swing,   0.0, 0.0)
	_rot("DEF-thigh.R", -walk_swing,   0.0, 0.0)

	# Shins (only bend when leg is swinging back)
	_rot("DEF-shin.L", maxf(-sin(t) * 0.45, 0.0) * _blend, 0.0, 0.0)
	_rot("DEF-shin.R", maxf( sin(t) * 0.45, 0.0) * _blend, 0.0, 0.0)

	# Arms opposite to legs
	_rot("DEF-upper_arm.L", -walk_swing * 0.55, 0.0, 0.0)
	_rot("DEF-upper_arm.R",  walk_swing * 0.55, 0.0, 0.0)

	# Forearms follow upper arm
	_rot("DEF-forearm.L", maxf(-sin(t) * 0.25, 0.0) * _blend, 0.0, 0.0)
	_rot("DEF-forearm.R", maxf( sin(t) * 0.25, 0.0) * _blend, 0.0, 0.0)

	# ── IDLE breathing ─────────────────────────────────────────────────────
	var breath := sin(t) * 0.012 * (1.0 - _blend)
	var walk_bob := sin(t * 2.0) * 0.018 * _blend
	_rot("DEF-spine",     walk_bob + breath, 0.0, 0.0)
	_rot("DEF-spine.001", walk_bob * 0.6 + breath * 0.7, 0.0, 0.0)
	_rot("DEF-spine.003", breath * 0.5, 0.0, 0.0)


func _rot(bone_name: String, rx: float, ry: float, rz: float) -> void:
	if bone_name not in _bones:
		return
	_skeleton.set_bone_pose_rotation(_bones[bone_name], Quaternion.from_euler(Vector3(rx, ry, rz)))
