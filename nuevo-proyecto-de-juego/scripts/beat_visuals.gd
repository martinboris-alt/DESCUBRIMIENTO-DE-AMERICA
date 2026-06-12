extends Node
## Hace "respirar" el mundo al ritmo de la música (estilo Geometry Dash):
## pulsa el sol, el glow del entorno y dibuja anillos de beat en los huecos.

var env: Environment
var sun: DirectionalLight3D
var ground_mat: StandardMaterial3D

var _base_glow := 0.22
var _base_sun := 1.2


func setup(p_env: Environment, p_sun: DirectionalLight3D) -> void:
	env = p_env
	sun = p_sun
	if env:
		_base_glow = env.glow_intensity
	if sun:
		_base_sun = sun.light_energy


func _process(_delta: float) -> void:
	var p := Music.pulse()
	if env:
		env.glow_intensity = _base_glow + p * 0.45
		env.adjustment_brightness = 1.0 + p * 0.05
	if sun:
		sun.light_energy = _base_sun + p * 0.5
