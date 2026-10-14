shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

// Smoke wisps drawn like the sea foam: the same drifting cell-edge web, stretched tall and
// warped into wavy ribbons that rise, so they flow like water lines instead of soft puffs.
// Drawn on one camera-facing (Y-locked) quad; the base sits at the mesh origin.

uniform vec4 smoke_color : source_color = vec4(0.62, 0.6, 0.57, 0.6);
uniform vec4 glow_color : source_color = vec4(0.95, 0.5, 0.18, 1.0); // fire light on the base of the plume
uniform float rise_speed = 0.5;
uniform float cell_size = 0.55; // width of one wisp cell, in quad units across
uniform float stretch = 3.0; // cells this many times taller than wide: long rising ribbons
uniform float web_width = 0.07; // thickness of the wisp lines
uniform float wave = 0.6; // how much the ribbons snake side to side
uniform float drift_speed = 0.8; // how fast the web reshapes
uniform float haze = 0.12; // faint soft smoke between the lines
uniform float spread = 1.0; // how much the plume widens with height
uniform float sway = 0.2; // drift of the whole column
uniform float tip_wander = 0.12; // how far the flame tip the smoke comes off darts side to side
uniform float tip_flicker = 1.8; // how fast the flame tip moves
uniform float rise_time = 2.5; // seconds for smoke to climb from the tip to the top, so the plume traces where the tip was
uniform float pixel_res = 96.0; // 90s-style downsample; 0 = smooth
uniform float anim_fps = 12.0; // steps the motion like low-framerate texture animation; 0 = smooth

uint hash_u(vec2 p, uint salt) {
	uint h = (uint(int(p.x)) * 1597334677u) ^ (uint(int(p.y)) * 3812015801u) ^ salt;
	h = (h ^ (h >> 16u)) * 2246822519u;
	h = (h ^ (h >> 13u)) * 3266489917u;
	return h ^ (h >> 16u);
}

float hash1(vec2 p) {
	return float(hash_u(p, 0u)) / 4294967295.0;
}

vec2 hash2(vec2 p) {
	return vec2(float(hash_u(p, 0u)), float(hash_u(p, 2654435769u))) / 4294967295.0;
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash1(i), hash1(i + vec2(1.0, 0.0)), u.x),
		mix(hash1(i + vec2(0.0, 1.0)), hash1(i + vec2(1.0, 1.0)), u.x), u.y);
}

// Distance to the nearest cell edge (second-closest minus closest point); points wobble over time. Same as the water foam.
float cell_edge(vec2 p, float time) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = 0.5 + 0.4 * sin(time * drift_speed + 6.2831 * hash2(i + g));
			float d = length(g + o - f);
			if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) { d2 = d; }
		}
	}
	return d2 - d1;
}

// One layer of wisps: web lines in a space that scrolls up and snakes sideways.
float wisps(vec2 uv, float h, float time, float scale, float seed) {
	vec2 p = vec2((uv.x - 0.5) / (cell_size * scale), h / (cell_size * scale * stretch) - time * rise_speed / scale);
	p.x += sin(p.y * 2.1 + time * 0.9 + seed) * wave + (vnoise(p * vec2(0.8, 0.5) + time * 0.25 + seed) - 0.5) * wave * 2.0;
	float e = cell_edge(p + seed * 17.0, time);
	return 1.0 - smoothstep(web_width * 0.4, web_width, e);
}

void vertex() {
	// billboard around Y, keeping the node's scale
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)) * length(MODEL_MATRIX[0].xyz), 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))) * length(MODEL_MATRIX[2].xyz), 0.0),
		MODEL_MATRIX[3]);
}

void fragment() {
	vec2 uv = UV;
	if (pixel_res > 0.0) {
		uv = (floor(uv * pixel_res) + 0.5) / pixel_res;
	}
	float time = anim_fps > 0.0 ? floor(TIME * anim_fps) / anim_fps : TIME;
	float h = 1.0 - uv.y; // 0 at the fire, 1 at the top

	// plume shape: narrow at the fire, widening and wandering as it rises
	// each height shows smoke that left the flame tip h * rise_time seconds ago, so the tip's flicker ripples up the plume
	float emitted = TIME - h * rise_time;
	float tip = (vnoise(vec2(emitted * tip_flicker, 1.0)) - 0.5 + 0.5 * (vnoise(vec2(emitted * tip_flicker * 2.3, 5.0)) - 0.5)) * tip_wander;
	float center = 0.5 + tip + sin(h * 2.5 + time * 0.5) * sway * h + (vnoise(vec2(h * 2.0 - time * 0.3, 3.0)) - 0.5) * 0.3 * h;
	float half_width = mix(0.06, 0.36, pow(h, 0.7)) * spread; // stays inside the quad so the plume never clips
	float mask = 1.0 - smoothstep(half_width * 0.25, half_width, abs(uv.x - center));
	mask *= smoothstep(0.0, 0.12, h) * (1.0 - smoothstep(0.45, 1.0, h));

	vec2 local = vec2(uv.x - center + 0.5, uv.y);
	float lines = max(wisps(local, h, time, 1.0, 0.0), 0.6 * wisps(local, h, time, 0.55, 3.7)); // big ribbons + finer threads
	float soft = vnoise(vec2(local.x * 6.0, h * 4.0 - time * rise_speed * 2.0)) * haze;
	float a = clamp(lines + soft, 0.0, 1.0) * mask;

	ALBEDO = mix(glow_color.rgb, smoke_color.rgb, smoothstep(0.05, 0.3, h));
	ALPHA = a * smoke_color.a;
}
