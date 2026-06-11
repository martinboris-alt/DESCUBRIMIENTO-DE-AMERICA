# Fase B: reexporta a GLB las escenas refined desde la caché .scn de Godot
extends SceneTree

const JOBS := {
	"jungle_tree_refined": "res://.godot/imported/jungle_tree_refined.glb-31c4bbd8919b28e3a8a28df32eefa272.scn",
	"aztec_ruin_column_refined": "res://.godot/imported/aztec_ruin_column_refined.glb-a7f973b41cc3d27bde653b7516403ec6.scn",
	"aztec_temple_block_refined": "res://.godot/imported/aztec_temple_block_refined.glb-ca01cf9ced3d9f710e686e50e69a6ee0.scn",
}

func _init() -> void:
	var out_dir := "C:/Users/Martin/Documents/GitHub/JUEGO CONQUISTA DE AMERICA/recovered"
	DirAccess.make_dir_recursive_absolute(out_dir)
	for name_ in JOBS:
		var packed: PackedScene = load(JOBS[name_])
		if not packed:
			print("FAIL_LOAD: ", name_)
			continue
		var node := packed.instantiate()
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		var err := doc.append_from_scene(node, state)
		if err == OK:
			err = doc.write_to_filesystem(state, "%s/%s.glb" % [out_dir, name_])
		print("EXPORTED: ", name_, " err=", err)
		node.free()
	quit()
