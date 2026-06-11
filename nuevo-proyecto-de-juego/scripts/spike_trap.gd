extends Node3D
## Trampa de pinchos de obsidiana con ciclo: oculta -> aviso -> arriba.

const PERIOD := 2.6
const T_WARN := 1.1
const T_UP := 1.5

var phase_offset := 0.0

var _spikes: Node3D
var _t := 0.0
var _up := false


func _ready() -> void:
	_t = phase_offset

	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.5, 0.47, 0.42)
	stone.roughness = 0.95
	var base := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.7, 0.22, 1.7)
	base.mesh = bm
	base.material_override = stone
	base.position.y = 0.11
	add_child(base)

	var obsidian := StandardMaterial3D.new()
	obsidian.albedo_color = Color(0.12, 0.1, 0.14)
	obsidian.roughness = 0.25
	obsidian.metallic = 0.4

	_spikes = Node3D.new()
	add_child(_spikes)
	for pos in [Vector3(0, 0, 0), Vector3(0.5, 0, 0.5), Vector3(-0.5, 0, 0.5),
			Vector3(0.5, 0, -0.5), Vector3(-0.5, 0, -0.5)]:
		var spike := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.14
		cone.height = 0.85
		spike.mesh = cone
		spike.material_override = obsidian
		spike.position = pos + Vector3(0, 0.62, 0)
		_spikes.add_child(spike)
	_spikes.position.y = -0.95


func _physics_process(delta: float) -> void:
	_t = fmod(_t + delta, PERIOD)
	var target_y := -0.95
	if _t >= T_UP:
		target_y = 0.0
		if not _up:
			_up = true
	elif _t >= T_WARN:
		target_y = -0.78
		_up = false
	else:
		_up = false
	_spikes.position.y = move_toward(_spikes.position.y, target_y, 8.0 * delta)

	if _up and Game.state == Game.GState.PLAYING and Game.player:
		var p := Game.player.global_position
		var d := p - global_position
		if Vector2(d.x, d.z).length() < 1.0 and d.y > -0.5 and d.y < 1.3:
			Game.player.take_hit(global_position + Vector3.DOWN * 0.5)
