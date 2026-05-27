extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
const MOUSE_SENSITIVITY = 0.003
const CAMERA_MIN_PITCH = -PI / 3.0
const CAMERA_MAX_PITCH = PI / 3.0

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# Animation state
var _skeleton: Skeleton3D
var _bones: Dictionary = {}
var _anim_time: float = 0.0
var _blend: float = 0.0


func _ready() -> void:
	add_to_group("player")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	await get_tree().process_frame
	await get_tree().process_frame
	_init_skeleton()


func _init_skeleton() -> void:
	_skeleton = _find_skeleton($Visuals)
	if not _skeleton:
		return
	for name in ["thigh.L","thigh.R","shin.L","shin.R",
				 "upper_arm.L","upper_arm.R","forearm.L","forearm.R",
				 "spine","chest"]:
		var idx := _skeleton.find_bone(name)
		if idx >= 0:
			_bones[name] = idx


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found:
			return found
	return null


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera_pivot.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, CAMERA_MIN_PITCH, CAMERA_MAX_PITCH)
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()

	var horiz_speed := Vector2(velocity.x, velocity.z).length()
	_update_animation(horiz_speed, delta)


func _update_animation(speed: float, delta: float) -> void:
	if not _skeleton or _bones.is_empty():
		return

	var is_moving := speed > 0.3
	_blend = move_toward(_blend, 1.0 if is_moving else 0.0, delta * 8.0)

	_anim_time += delta * (speed * 1.8 if is_moving else 0.8)
	var t := _anim_time

	var walk := sin(t) * 0.5 * _blend

	# Legs swing
	_bone_rot("thigh.L",  walk, 0.0, 0.0)
	_bone_rot("thigh.R", -walk, 0.0, 0.0)
	_bone_rot("shin.L",  maxf(-sin(t) * 0.45, 0.0) * _blend, 0.0, 0.0)
	_bone_rot("shin.R",  maxf( sin(t) * 0.45, 0.0) * _blend, 0.0, 0.0)

	# Arms swing opposite
	_bone_rot("upper_arm.L", -walk * 0.55, 0.0, 0.0)
	_bone_rot("upper_arm.R",  walk * 0.55, 0.0, 0.0)
	_bone_rot("forearm.L",   maxf(-sin(t) * 0.25, 0.0) * _blend, 0.0, 0.0)
	_bone_rot("forearm.R",   maxf( sin(t) * 0.25, 0.0) * _blend, 0.0, 0.0)

	# Torso bob + idle breathing
	var breath := sin(t) * 0.012 * (1.0 - _blend)
	var bob    := sin(t * 2.0) * 0.018 * _blend
	_bone_rot("spine", bob + breath, 0.0, 0.0)
	_bone_rot("chest", bob * 0.6 + breath * 0.5, 0.0, 0.0)


func _bone_rot(bone: String, rx: float, ry: float, rz: float) -> void:
	if bone not in _bones:
		return
	_skeleton.set_bone_pose_rotation(_bones[bone], Quaternion.from_euler(Vector3(rx, ry, rz)))
