extends Node3D

const RUIN_MODEL = preload("res://assets/models/aztec_ruin_column.glb")

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 777

	for _i in 18:
		var angle := rng.randf() * TAU
		var dist  := rng.randf_range(16.0, 44.0)
		var pos   := Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
		if pos.z < -24.0 and abs(pos.x) < 14.0:
			continue

		var instance := RUIN_MODEL.instantiate()
		instance.position = pos
		instance.rotation.y = rng.randf() * TAU
		var s := rng.randf_range(0.6, 1.4)
		instance.scale = Vector3(s, s, s)
		add_child(instance)
