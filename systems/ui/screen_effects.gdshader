shader_type canvas_item;

// Full-screen feedback: darkening red vignette + desaturation at low health,
// desaturation as magicka is spent, blur + dark breathing edges when out of stamina,
// a fade to black for death,
// and a short red flash when hit. Driven by ScreenEffects.gd.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;

uniform float health_loss : hint_range(0.0, 1.0) = 0.0; // 0 = full health, 1 = dead
uniform float flash : hint_range(0.0, 1.0) = 0.0;       // hit flash, decays over time
uniform float pulse : hint_range(0.0, 1.0) = 0.0;       // heartbeat at low health
uniform vec4 tint_color : source_color = vec4(0.30, 0.02, 0.02, 1.0);
uniform float max_desaturation : hint_range(0.0, 1.0) = 0.6;
uniform float magicka_loss : hint_range(0.0, 1.0) = 0.0; // 0 = full magicka, 1 = empty
uniform float max_magicka_desaturation : hint_range(0.0, 1.0) = 0.7;
uniform float stamina_loss : hint_range(0.0, 1.0) = 0.0; // 0 = full stamina, 1 = empty
uniform float breath : hint_range(0.0, 1.0) = 0.0;       // slow breathing pulse when winded
uniform float max_stamina_blur : hint_range(0.0, 4.0) = 1.8; // mip level at empty stamina
uniform float fade : hint_range(0.0, 1.0) = 0.0;         // fade to black (death/respawn)

void fragment() {
	// Low stamina: the view softens (blur via mipmaps) as you run out of breath.
	float winded = smoothstep(0.5, 1.0, stamina_loss);
	vec3 scr = textureLod(screen_tex, SCREEN_UV, winded * max_stamina_blur * (0.7 + 0.3 * breath)).rgb;

	// Distance from screen centre, corrected for aspect ratio.
	vec2 p = SCREEN_UV - 0.5;
	p.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float d = length(p);

	float loss = clamp(health_loss + pulse * 0.12, 0.0, 1.0);
	float inner = mix(0.75, 0.22, loss);          // vignette closes in as health drops
	float vig = smoothstep(inner, inner + 0.45, d);

	// Colour drains out below ~60% health.
	float grey = dot(scr, vec3(0.299, 0.587, 0.114));
	// Colour also drains as magicka is spent (starts straight away, strongest when empty).
	float desat_health = smoothstep(0.4, 1.0, health_loss) * max_desaturation;
	float desat_magicka = smoothstep(0.0, 1.0, magicka_loss) * max_magicka_desaturation;
	float desat = clamp(max(desat_health, desat_magicka) + 0.5 * min(desat_health, desat_magicka), 0.0, 1.0);
	vec3 col = mix(scr, vec3(grey), desat);

	float strength = vig * loss * 0.9 + flash * (0.2 + vig * 0.5);
	col = mix(col, tint_color.rgb, clamp(strength, 0.0, 1.0));

	// Winded: dark (not red) edges that swell with each breath.
	float inner_s = mix(0.8, 0.35, winded);
	float vig_s = smoothstep(inner_s, inner_s + 0.5, d);
	col *= 1.0 - vig_s * winded * (0.45 + 0.25 * breath);

	col = mix(col, vec3(0.0), fade);
	COLOR = vec4(col, 1.0);
}
