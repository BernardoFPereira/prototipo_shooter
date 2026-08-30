shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

uniform vec2 direction = vec2(0.0, 1.0);
uniform float speed = 0.5;

uniform float band_height : hint_range(0.0, 1.0) = 0.15;
uniform float active_duration : hint_range(0.1, 10.0) = 1.0;
uniform float cycle_duration : hint_range(0.1, 20.0) = 4.0;

uniform vec3 tint : source_color = vec3(0.0, 1.0, 0.0);
uniform float darken_amount : hint_range(0.0, 1.0) = 0.25;
uniform float glow_amount : hint_range(0.0, 3.0) = 0.6;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;

uniform float displacement_strength : hint_range(0.0, 1) = 0.6; // intensidade do deslocamento
uniform float displacement_frequency : hint_range(1.0, 60.0) = 25.0; // "ondulação" ao longo da linha
uniform float displacement_wave_speed : hint_range(0.0, 30.0) = 12.0;

void fragment() {
	vec2 move = direction * TIME * speed;
	vec4 tex = texture(TEXTURE, UV + move);
	float line_mask = tex.r;

	float t = mod(TIME, cycle_duration);
	float sweep_progress = t / active_duration;
	float dist = abs(UV.y - sweep_progress);
	float band_mask = smoothstep(band_height, 0.0, dist);
	float active = step(t, active_duration);
	band_mask *= active;

	float final_mask = line_mask * band_mask * opacity;

	// desloca o UV de leitura do fundo horizontalmente, só onde a faixa está passando
	float wave = sin(UV.y * displacement_frequency + TIME * displacement_wave_speed);
	vec2 displaced_uv = SCREEN_UV + vec2(wave * (displacement_strength/100.0) * band_mask, 0.0);

	vec3 screen_color = texture(screen_texture, displaced_uv).rgb;

	vec3 darkened = mix(screen_color, screen_color * tint, darken_amount * final_mask);
	vec3 result = darkened + tint * glow_amount * final_mask;

	COLOR = vec4(result, 1.0);
}