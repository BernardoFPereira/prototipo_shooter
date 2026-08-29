shader_type canvas_item;

uniform sampler2D glow_source : source_color, filter_linear, repeat_disable;
uniform vec3 glow_tint : source_color = vec3(1, 1, 1);
uniform vec3 detect_color : source_color = vec3(1.0, 1.0, 1.0);
uniform float threshold : hint_range(0.0, 1.0) = 0;
uniform float intensity : hint_range(0.0, 10.0) = 0;
uniform float blur_size : hint_range(0.0, 20.0) = 0;
uniform float line_opacity : hint_range(0.0, 1.0) = 0;

void fragment() {
	vec4 original = texture(TEXTURE, UV);

	vec3 glow_sum = vec3(0.0);
	float mask_sum = 0.0;
	float weight_sum = 0.0;

	for (float x = -2.0; x <= 2.0; x += 1.0) {
		for (float y = -2.0; y <= 2.0; y += 1.0) {
			vec2 offset = vec2(x, y) * blur_size * TEXTURE_PIXEL_SIZE;
			vec4 s = texture(glow_source, UV + offset);

			float dist = length(vec2(x, y));
			float weight = exp(-dist * dist * 0.3);

			float diff = distance(s.rgb, detect_color);
			float mask = step(diff, threshold) * s.a;

			glow_sum += glow_tint * mask * weight;
			mask_sum += mask * weight;
			weight_sum += weight;
		}
	}

	vec3 glow = (glow_sum / weight_sum) * intensity;
	float glow_alpha = clamp((mask_sum / weight_sum) * intensity * 0.5, 0.0, 1.0);

	vec3 line_rgb = original.rgb * line_opacity;
	float line_a = original.a * line_opacity;

	COLOR.rgb = line_rgb + glow;
	COLOR.a = clamp(line_a + glow_alpha, 0.0, 1.0);
}