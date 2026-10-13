shader_type spatial;
render_mode cull_disabled, specular_disabled;

uniform sampler2D tex : source_color, filter_nearest; // pixelated, 90s style
uniform float sway = 0.3; // metres the tips move in the wind

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = (1.0 - UV.y) * (1.0 - UV.y); // base stays planted, tips move most
	float gust = sin(TIME * 1.6 + world.x * 0.3 + world.z * 0.22) + 0.5 * sin(TIME * 3.3 + world.x * 0.9 - world.z * 0.7);
	VERTEX += inverse(mat3(MODEL_MATRIX)) * vec3(gust * sway * h, 0.0, gust * sway * 0.6 * h); // same wind direction for every blade
}

void fragment() {
	vec4 c = texture(tex, UV);
	if (c.a < 0.5) {
		discard;
	}
	ALBEDO = c.rgb;
}
