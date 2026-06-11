# Imprime offsets de waypoints y curvatura local de la senda
extends SceneTree

const WAYPOINTS: Array[Vector3] = [
	Vector3(0, 0.5, 10), Vector3(0, 0.5, 0), Vector3(0, 0.5, -25),
	Vector3(8, 1.0, -50), Vector3(10, 1.5, -75), Vector3(0, 2.2, -100),
	Vector3(-10, 2.8, -125), Vector3(-12, 3.2, -150), Vector3(-4, 5.0, -175),
	Vector3(6, 7.0, -200), Vector3(10, 7.5, -225), Vector3(4, 5.5, -250),
	Vector3(-6, 3.5, -275), Vector3(-8, 2.5, -300), Vector3(0, 2.0, -325),
	Vector3(0, 2.0, -342),
]


func _init() -> void:
	var curve := Curve3D.new()
	for wp in WAYPOINTS:
		curve.add_point(wp)
	for i in WAYPOINTS.size():
		var prev := WAYPOINTS[maxi(i - 1, 0)]
		var next := WAYPOINTS[mini(i + 1, WAYPOINTS.size() - 1)]
		var dir := (next - prev) * 0.22
		curve.set_point_in(i, -dir)
		curve.set_point_out(i, dir)
	var clen := curve.get_baked_length()
	print("CLEN=%.1f" % clen)
	for i in WAYPOINTS.size():
		print("WP%d d=%.1f  %s" % [i, curve.get_closest_offset(WAYPOINTS[i]), str(WAYPOINTS[i])])
	# curvatura: cambio de rumbo en grados por metro, cada 5 m
	var d := 5.0
	while d < clen - 5.0:
		var t0 := (curve.sample_baked(d) - curve.sample_baked(d - 4.0))
		var t1 := (curve.sample_baked(d + 4.0) - curve.sample_baked(d))
		t0.y = 0; t1.y = 0
		var ang := rad_to_deg(t0.normalized().angle_to(t1.normalized()))
		var slope := (curve.sample_baked(d + 4.0).y - curve.sample_baked(d - 4.0).y) / 8.0
		print("d=%.0f curv=%4.1f° pend=%+.2f" % [d, ang, slope])
		d += 5.0
	quit()
