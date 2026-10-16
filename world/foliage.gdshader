shader_type spatial;
render_mode cull_disabled, specular_disabled;

uniform sampler2D tex : source_color, filter_nearest; // pixelated, 90s style
uniform float sway = 0.3; // metres the tips move in the wind
global uniform vec2 wind; // set by world/wind.gd: the way (and how far) tips lean, metres

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = (1.0 - UV.y) * (1.0 - UV.y); // base stays planted, tips move most
	float gust = sin(TIME * 1.6 + world.x * 0.3 + world.z * 0.22) + 0.5 * sin(TIME * 3.3 + world.x * 0.9 - world.z * 0.7);
	vec2 dir = length(wind) > 0.001 ? normalize(wind) : vec2(1.0, 0.6);
	vec2 bend = wind + dir * gust * sway; // lean with the wind, flutter along it
	VERTEX += inverse(mat3(MODEL_MATRIX)) * vec3(bend.x * h, 0.0, bend.y * h);
}

void fragment() {
	vec4 c = texture(tex, UV);
	if (c.a < 0.5) {
		discard;
	}
	ALBEDO = c.rgb;
}
