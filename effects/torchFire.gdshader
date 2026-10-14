shader_type spatial;
// Torch flame puff: the old fire texture for detail, faded to a soft round edge, coloured by the particle's colour ramp.
render_mode blend_add, unshaded, cull_disabled, depth_draw_never;

uniform sampler2D fire_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float brightness = 1.8;

void vertex() {
	// Face the camera, spin by the particle's angle, keep the particle's scale (same as StandardMaterial particle billboards).
	mat4 mat_world = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]), normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
	mat_world = mat_world * mat4(vec4(cos(INSTANCE_CUSTOM.x), -sin(INSTANCE_CUSTOM.x), 0.0, 0.0), vec4(sin(INSTANCE_CUSTOM.x), cos(INSTANCE_CUSTOM.x), 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat_world;
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	float edge = 1.0 - smoothstep(0.35, 1.0, length(UV - 0.5) * 2.0); // round off the square sprite
	vec3 detail = texture(fire_tex, UV).rgb;
	ALBEDO = COLOR.rgb * detail * edge * COLOR.a * brightness;
}
