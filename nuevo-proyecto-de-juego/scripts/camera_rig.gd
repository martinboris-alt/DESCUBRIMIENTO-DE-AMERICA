extends Node3D
## Cámara de persecución estilo Crash: sigue al jugador orientada según
## la tangente de la senda, con suavizado exponencial.

var dist := 8.2
var height := 4.4

const LOOK_AHEAD := 3.6
const LOOK_UP := 1.5

var player: Node3D
var curve: Curve3D

var _fwd := Vector3.FORWARD


func setup(p_player: Node3D, p_curve: Curve3D) -> void:
	player = p_player
	curve = p_curve
	snap()


func snap() -> void:
	if not player or not curve:
		return
	_update_fwd(1.0)
	global_position = _desired_pos()
	_look()


func forward() -> Vector3:
	return _fwd


func _desired_pos() -> Vector3:
	return player.global_position - _fwd * dist + Vector3.UP * height


func _update_fwd(weight: float) -> void:
	var d := curve.get_closest_offset(player.global_position)
	var len := curve.get_baked_length()
	var a := curve.sample_baked(clampf(d - 1.5, 0.0, len))
	var b := curve.sample_baked(clampf(d + 1.5, 0.0, len))
	var tangent := b - a
	tangent.y = 0.0
	if tangent.length() > 0.01:
		_fwd = _fwd.lerp(tangent.normalized(), weight).normalized()


func _look() -> void:
	look_at(player.global_position + Vector3.UP * LOOK_UP + _fwd * LOOK_AHEAD, Vector3.UP)


func _physics_process(delta: float) -> void:
	if not player or not curve:
		return
	_update_fwd(1.0 - exp(-3.0 * delta))
	var k := 1.0 - exp(-5.0 * delta)
	global_position = global_position.lerp(_desired_pos(), k)
	_look()
