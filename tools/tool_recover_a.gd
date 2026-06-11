# Fase A: recupera la textura de la columna desde la caché .ctex
extends SceneTree

func _init() -> void:
	var path := "res://.godot/imported/aztec_ruin_column_refined_0.jpg-3c4802193f9e00bde402fcbca2fea17e.ctex"
	var tex: Texture2D = load(path)
	if tex:
		var img := tex.get_image()
		if img.is_compressed():
			img.decompress()
		var err := img.save_jpg("res://assets/models/aztec_ruin_column_refined_0.jpg", 0.92)
		print("RUIN_JPG_SAVED err=", err, " size=", img.get_width(), "x", img.get_height())
	else:
		print("RUIN_CTEX_LOAD_FAILED")
	quit()
