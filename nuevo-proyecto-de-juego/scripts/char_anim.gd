class_name CharAnim
extends RefCounted
## Animación procedural de locomoción compartida (jugador y enemigos).
## Ciclo de caminado dinámico: balanceo amplio de piernas y brazos en
## oposición, flexión de rodillas, giro de pies, balanceo de cadera y
## contra-giro de torso, con bobbing vertical. Mezcla suave con idle.

# huesos que intenta controlar (los que falten se ignoran)
const BONES := ["pelvis", "spine", "chest", "neck", "head",
	"thigh.L", "thigh.R", "shin.L", "shin.R", "foot.L", "foot.R",
	"upper_arm.L", "upper_arm.R", "forearm.L", "forearm.R"]

var _skeleton: Skeleton3D
var _bones := {}
var _rests := {}
var _t := 0.0
var _blend := 0.0
var _bob := 0.0


func setup(root: Node) -> bool:
	_skeleton = _find_skeleton(root)
	if not _skeleton:
		return false
	for n in BONES:
		var idx := _skeleton.find_bone(n)
		if idx >= 0:
			_bones[n] = idx
			# la pose se compone con el reposo: set_bone_pose_rotation
			# REEMPLAZA la rotación local, no la suma
			_rests[n] = _skeleton.get_bone_rest(idx).basis.get_rotation_quaternion()
	return not _bones.is_empty()


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found:
			return found
	return null


func update(speed: float, delta: float, arms_out: float = 0.0) -> void:
	if not _skeleton or _bones.is_empty():
		return

	var moving := speed > 0.3
	_blend = move_toward(_blend, 1.0 if moving else 0.0, delta * 9.0)
	# cadencia proporcional a la velocidad (zancada más rápida al correr)
	_t += delta * (clampf(speed, 0.0, 7.0) * 1.7 + 1.5 if moving else 0.9)
	var t := _t
	var b := _blend

	var sw := sin(t)        # fase principal de zancada
	var sw2 := sin(t * 2.0) # doble frecuencia (bob, rebote)

	# ── PIERNAS: balanceo amplio en oposición ────────────────────────
	# muslo adelante => sin>0 ; pierna contraria atrás
	_rot("thigh.L", sw * 0.85 * b, 0.0, 0.0)
	_rot("thigh.R", -sw * 0.85 * b, 0.0, 0.0)
	# rodilla: se dobla al ir la pierna hacia atrás y en la fase de vuelo
	_rot("shin.L", (maxf(-sw, 0.0) * 0.6 + maxf(-sw2, 0.0) * 0.4) * b, 0.0, 0.0)
	_rot("shin.R", (maxf(sw, 0.0) * 0.6 + maxf(sw2, 0.0) * 0.4) * b, 0.0, 0.0)
	# pie: flexiona al despegar/aterrizar
	_rot("foot.L", (-sw * 0.4 + 0.15) * b, 0.0, 0.0)
	_rot("foot.R", (sw * 0.4 + 0.15) * b, 0.0, 0.0)

	# ── BRAZOS: balanceo opuesto a las piernas ───────────────────────
	# brazo izq atrás cuando pierna izq adelante
	_rot("upper_arm.L", -sw * 0.7 * b, 0.0, arms_out * 1.25)
	_rot("upper_arm.R", sw * 0.7 * b, 0.0, -arms_out * 1.25)
	# antebrazo: siempre algo flexionado, más al venir adelante
	_rot("forearm.L", (maxf(-sw, 0.0) * 0.5 + 0.25) * b, 0.0, arms_out * 0.4)
	_rot("forearm.R", (maxf(sw, 0.0) * 0.5 + 0.25) * b, 0.0, -arms_out * 0.4)

	# ── TRONCO: balanceo de cadera + contra-giro + bob ───────────────
	_bob = sw2 * 0.025 * b
	# pelvis: ligera inclinación lateral (sway) y bob vertical via pitch
	_rot("pelvis", _bob, sw * 0.10 * b, sw * 0.06 * b)
	# torso gira al revés que la cadera (oposición natural brazo/pierna)
	_rot("spine", _bob * 0.5, -sw * 0.10 * b, 0.0)
	_rot("chest", -sw2 * 0.03 * b, -sw * 0.06 * b, 0.0)
	# cabeza estabiliza la mirada (contrarresta el bob)
	_rot("head", -_bob * 0.6 + sin(t) * 0.008 * (1.0 - b), 0.0, 0.0)

	# respiración en idle
	if b < 0.99:
		var breath := sin(t * 0.9) * 0.02 * (1.0 - b)
		_rot("chest", -sw2 * 0.03 * b + breath, -sw * 0.06 * b, 0.0)


## Desplazamiento vertical sugerido del cuerpo (lo usa el jugador para
## un pequeño bote del modelo al caminar).
func body_bob() -> float:
	return _bob


func _rot(bone: String, rx: float, ry: float, rz: float) -> void:
	if bone not in _bones:
		return
	var q: Quaternion = _rests[bone] * Quaternion.from_euler(Vector3(rx, ry, rz))
	_skeleton.set_bone_pose_rotation(_bones[bone], q)
