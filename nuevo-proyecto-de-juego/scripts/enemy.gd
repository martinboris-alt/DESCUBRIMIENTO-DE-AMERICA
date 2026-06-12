extends CharacterBody3D
## Guerrero azteca: patrulla su zona, persigue al jugador si se acerca y
## le daña por contacto. Muere de un giro de espada o un salto encima.

const WALK := 2.1
const CHASE := 3.8
const AGGRO := 8.5
const CONTACT_R := 1.25
const GRAV := 22.0
const TINT := Color(1.0, 0.72, 0.48)

var home := Vector3.ZERO
var patrol_vec := Vector3.RIGHT * 2.5
var speed_mult := 1.0

var anim := CharAnim.new()
var dead := false
var _t := 0.0
var _hit_cd := 0.0
var _visuals: Node3D


func _ready() -> void:
	add_to_group("enemy")
	home = global_position
	_t = randf() * TAU
	_visuals = get_node_or_null("Visuals")
	await get_tree().process_frame
	await get_tree().process_frame
	if _visuals:
		anim.setup(_visuals)
		_tint_meshes(_visuals)
		_add_headdress()


func _tint_meshes(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var mat: Material = mi.get_active_material(i)
			if mat is StandardMaterial3D:
				var m: StandardMaterial3D = mat.duplicate()
				m.albedo_color = m.albedo_color * TINT
				m.metallic *= 0.5
				mi.set_surface_override_material(i, m)
	for child in node.get_children():
		_tint_meshes(child)


func _add_headdress() -> void:
	var skel := _find_skeleton(_visuals)
	if not skel or skel.find_bone("head") < 0:
		return
	var attach := BoneAttachment3D.new()
	attach.bone_name = "head"
	skel.add_child(attach)
	var colors := [Color(0.85, 0.12, 0.1), Color(0.1, 0.65, 0.3), Color(0.95, 0.75, 0.1)]
	for i in 3:
		var feather := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.05, 0.45, 0.12)
		feather.mesh = box
		var m := StandardMaterial3D.new()
		m.albedo_color = colors[i]
		feather.material_override = m
		feather.position = Vector3((i - 1) * 0.09, 0.32, -0.05)
		feather.rotation.x = -0.25 - 0.12 * absf(i - 1.0)
		attach.add_child(feather)


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found:
			return found
	return null


func _physics_process(delta: float) -> void:
	if dead:
		return
	_hit_cd = maxf(_hit_cd - delta, 0.0)
	_t += delta

	if not is_on_floor():
		velocity.y -= GRAV * delta

	var target_vel := Vector3.ZERO
	var player := Game.player
	if player and Game.state == Game.GState.PLAYING:
		var to_player := player.global_position - global_position
		var dist := to_player.length()
		if dist < AGGRO and absf(to_player.y) < 2.5:
			var flat := Vector3(to_player.x, 0, to_player.z).normalized()
			target_vel = flat * CHASE * speed_mult
			if dist < CONTACT_R and _hit_cd <= 0.0:
				_hit_cd = 1.1
				player.take_hit(global_position)
		else:
			var goal := home + patrol_vec * sin(_t * 0.6)
			var to_goal := goal - global_position
			to_goal.y = 0.0
			if to_goal.length() > 0.3:
				target_vel = to_goal.normalized() * WALK * speed_mult

	velocity.x = move_toward(velocity.x, target_vel.x, 18.0 * delta)
	velocity.z = move_toward(velocity.z, target_vel.z, 18.0 * delta)
	move_and_slide()

	var hvel := Vector2(velocity.x, velocity.z)
	if _visuals and hvel.length() > 0.4:
		_visuals.rotation.y = lerp_angle(_visuals.rotation.y, atan2(velocity.x, velocity.z), 8.0 * delta)
	anim.update(hvel.length(), delta)


func stomp() -> void:
	_die(Vector3.DOWN * 0.5)


func spin_hit(from_pos: Vector3) -> void:
	var fling := (global_position - from_pos)
	fling.y = 0.0
	fling = fling.normalized() if fling.length() > 0.05 else Vector3.BACK
	_die(fling * 5.0 + Vector3.UP * 4.0)


func _die(fling: Vector3) -> void:
	if dead:
		return
	dead = true
	collision_layer = 0
	collision_mask = 0
	Sfx.play("enemy_die")
	Game.add_coin(2)
	Sfx.play("coin", -6.0)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "global_position", global_position + fling, 0.55)
	tw.tween_property(self, "scale", Vector3.ONE * 0.05, 0.55)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	if _visuals:
		tw.tween_property(_visuals, "rotation:z", PI, 0.55)
	tw.chain().tween_callback(queue_free)
