shader_type spatial;
// Sea with cartoon foam: a wobbly rim at the shore plus a drifting web of foam cells
// that fades out as the water gets deeper.
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform vec4 deep_color : source_color = vec4(0.1, 0.3, 0.45, 0.85);
uniform vec4 shallow_color : source_color = vec4(0.25, 0.5, 0.6, 0.6);
uniform vec4 foam_color : source_color = vec4(0.95, 0.92, 0.85, 1.0);
uniform float foam_opacity : hint_range(0.0, 1.0) = 1.0; // at the coastline; fades to 0 at foam_depth
uniform float shallow_depth = 4.0; // metres of water before it's fully deep_color
uniform float foam_depth = 3.0; // foam fades out by this depth
uniform float rim_width = 0.3; // solid foam right at the shore
uniform float cell_size = 2.5; // metres across one foam cell
uniform float web_width = 0.1; // thickness of the cell edges
uniform float drift_speed = 0.6;
uniform float pixel_size = 0.12; // metres per foam "texel", chunky 90s look
uniform float anim_fps = 8.0; // foam moves in steps, like low-framerate texture animation
uniform int color_bands = 3; // shallow-to-deep colour in hard steps
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;

group_uniforms ripples;
uniform float ripple_scale = 0.6; // ripples per metre
uniform float ripple_strength = 1.2; // how bumpy the light catching is
uniform float ripple_speed = 0.5;
uniform float ripple_fade_distance = 250.0; // ripples flatten out by this distance (stops far shimmer)
uniform float shininess : hint_range(0.0, 1.0) = 0.9; // specular glint strength
uniform vec4 reflect_color : source_color = vec4(0.45, 0.5, 0.6, 1.0); // sky tint at glancing angles
uniform float reflect_amount : hint_range(0.0, 1.0) = 0.3;
group_uniforms;

// Integer hash of a lattice cell. The usual fract(sin(dot)) hash breaks down kilometres from the origin:
// neighbouring cells hash the same corner differently and the pattern tears along cell edges.
uint hash_u(vec2 p, uint salt) {
	uint h = (uint(int(p.x)) * 1597334677u) ^ (uint(int(p.y)) * 3812015801u) ^ salt;
	h = (h ^ (h >> 16u)) * 2246822519u;
	h = (h ^ (h >> 13u)) * 3266489917u;
	return h ^ (h >> 16u);
}

float hash1(vec2 p) {
	return float(hash_u(p, 0u)) / 4294967295.0;
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash1(i), hash1(i + vec2(1.0, 0.0)), u.x),
		mix(hash1(i + vec2(0.0, 1.0)), hash1(i + vec2(1.0, 1.0)), u.x), u.y);
}

// Slope of crossing wave trains, warped by noise so they don't look like a grid (Morrowind-style rolling ripples).
// Derivative is analytic: finite differences far from the origin lose float precision and show as scan lines.
vec2 ripple_slope(vec2 p, float time) {
	vec2 q = p * ripple_scale;
	float t = time * ripple_speed;
	q += 0.8 * vec2(vnoise(q * 0.5 + t * 0.2), vnoise(q * 0.5 - t * 0.2 + 7.0));
	vec2 d1 = vec2(1.0, 0.3) * 3.0;
	vec2 d2 = vec2(-0.6, 0.8) * 2.6;
	vec2 d3 = vec2(0.2, -1.0) * 5.1;
	return ripple_scale * (d1 * cos(dot(q, d1) + t * 2.0)
		+ d2 * cos(dot(q, d2) + t * 1.7)
		+ 0.5 * d3 * cos(dot(q, d3) + t * 2.9));
}

vec2 hash2(vec2 p) {
	return vec2(float(hash_u(p, 0u)), float(hash_u(p, 2654435769u))) / 4294967295.0;
}

// Distance to the nearest cell edge (second-closest minus closest point), points wobble over time.
float cell_edge(vec2 p, float time) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = 0.5 + 0.4 * sin(time * drift_speed +6.2831 * hash2(i + g));
			float d = length(g + o - f);
			if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) { d2 = d; }
		}
	}
	return d2 - d1;
}

void fragment() {
	// Height of water above the ground behind this pixel.
	vec4 v = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, texture(depth_tex, SCREEN_UV).r, 1.0);
	vec3 ground = (INV_VIEW_MATRIX * vec4(v.xyz / v.w, 1.0)).xyz;
	vec3 surface = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float depth = max(surface.y - ground.y, 0.0);

	// Snap the foam to a coarse world grid and a low framerate.
	vec2 px = (floor(surface.xz / pixel_size) + 0.5) * pixel_size;
	float time = floor(TIME * anim_fps) / anim_fps;
	float wob = sin(px.x * 0.35 + time * 0.7) * sin(px.y * 0.29 - time * 0.5) * 0.25;
	float rim = step(depth + wob * 0.3, rim_width);
	float web = step(cell_edge(px / cell_size + 0.15 * sin(px.yx / cell_size * 2.3 + time * 0.4), time), web_width);
	float fade = 1.0 - clamp((depth + wob) / foam_depth, 0.0, 1.0); // full at the coastline, gone at foam_depth
	float foam = max(rim, web) * fade * foam_opacity;

	float bands = float(color_bands);
	vec4 water = mix(shallow_color, deep_color, floor(smoothstep(0.0, shallow_depth, depth) * bands + 0.5) / bands);
	// Ripples: bump the normal so the sun/moon glints off them, tint toward the sky at glancing angles.
	vec2 slope = ripple_slope(surface.xz, time);
	NORMAL_MAP = normalize(vec3(-slope, 4.0)) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = ripple_strength * (1.0 - smoothstep(ripple_fade_distance * 0.3, ripple_fade_distance, length(VERTEX))) * (1.0 - foam);
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	water.rgb = mix(water.rgb, reflect_color.rgb, fresnel * reflect_amount);

	ALBEDO = mix(water.rgb, foam_color.rgb, foam);
	ALPHA = mix(water.a, foam_color.a, foam);
	ROUGHNESS = mix(0.05, 1.0, foam);
	SPECULAR = mix(shininess, 0.2, foam);
}
