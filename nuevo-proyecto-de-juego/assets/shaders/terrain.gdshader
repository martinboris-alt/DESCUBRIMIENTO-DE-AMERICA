shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 color_grass : source_color = vec4(0.22, 0.45, 0.14, 1.0);
uniform vec4 color_dry   : source_color = vec4(0.48, 0.42, 0.22, 1.0);
uniform vec4 color_dirt  : source_color = vec4(0.38, 0.28, 0.14, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 5; i++) {
		v += amp * noise(p);
		p *= 2.1;
		amp *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV * 18.0;
	float n  = fbm(uv * 0.4);
	float n2 = fbm(uv * 1.2 + vec2(5.3, 2.1));
	float n3 = fbm(uv * 3.0 + vec2(1.7, 8.4));

	// Base grass with variation
	vec3 col = mix(color_grass.rgb, color_dry.rgb, clamp(n * 1.2 - 0.3, 0.0, 1.0));
	// Dirt patches
	col = mix(col, color_dirt.rgb, clamp(n2 * n3 * 2.0 - 0.8, 0.0, 0.6));
	// Fine detail noise
	col += (n3 - 0.5) * 0.06;

	ALBEDO    = clamp(col, vec3(0.0), vec3(1.0));
	ROUGHNESS = 0.92;
	METALLIC  = 0.0;
	// Subtle normal bump from noise gradient
	float eps = 0.02;
	float nx  = fbm(uv * 0.4 + vec2(eps, 0.0)) - n;
	float nz  = fbm(uv * 0.4 + vec2(0.0, eps)) - n;
	NORMAL_MAP = normalize(vec3(-nx * 4.0, 1.0, -nz * 4.0)) * 0.5 + 0.5;
}
