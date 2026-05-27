shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform float wave_speed : hint_range(0.0, 3.0) = 0.8;
uniform float wave_height : hint_range(0.0, 0.5) = 0.15;
uniform vec4 color_shallow : source_color = vec4(0.1, 0.55, 0.75, 0.85);
uniform vec4 color_deep : source_color = vec4(0.02, 0.18, 0.42, 0.95);

void vertex() {
	float w = sin(VERTEX.x * 0.30 + TIME * wave_speed)
			+ sin(VERTEX.z * 0.25 + TIME * wave_speed * 0.9) * 0.6
			+ sin((VERTEX.x - VERTEX.z) * 0.18 + TIME * wave_speed * 1.3) * 0.4;
	VERTEX.y += w * wave_height;

	float dx = cos(VERTEX.x * 0.30 + TIME * wave_speed) * 0.30 * wave_height
			 + cos((VERTEX.x - VERTEX.z) * 0.18 + TIME * wave_speed * 1.3) * 0.18 * wave_height * 0.4;
	float dz = cos(VERTEX.z * 0.25 + TIME * wave_speed * 0.9) * 0.25 * wave_height * 0.6
			 - cos((VERTEX.x - VERTEX.z) * 0.18 + TIME * wave_speed * 1.3) * 0.18 * wave_height * 0.4;
	NORMAL = normalize(vec3(-dx, 1.0, -dz));
}

void fragment() {
	ALBEDO = mix(color_shallow.rgb, color_deep.rgb, 0.4);
	ALPHA = mix(color_shallow.a, color_deep.a, 0.5);
	ROUGHNESS = 0.04;
	SPECULAR = 0.9;
	METALLIC = 0.0;
}
