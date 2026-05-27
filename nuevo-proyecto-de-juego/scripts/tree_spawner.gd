extends Node3D

@export var tree_scene: PackedScene
@export var count: int = 80
@export var terrain_half_size: float = 46.0
@export var clear_radius: float = 8.0


func _ready() -> void:
	if not tree_scene:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var spawned := 0
	var attempts := 0
	while spawned < count and attempts < count * 15:
		attempts += 1
		var x := rng.randf_range(-terrain_half_size, terrain_half_size)
		var z := rng.randf_range(-terrain_half_size, terrain_half_size)
		if Vector2(x, z).length() < clear_radius:
			continue
		var tree := tree_scene.instantiate()
		tree.position = Vector3(x, 0.1, z)
		tree.rotation.y = rng.randf() * TAU
		var s := rng.randf_range(0.8, 1.6)
		tree.scale = Vector3(s, s, s)
		add_child(tree)
		spawned += 1
