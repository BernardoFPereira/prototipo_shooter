shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float brightness = 1.0;

void fragment() {
	vec3 color = texture(screen_texture, SCREEN_UV).rgb;
	color = max(color, vec3(0.0));
	color = pow(color, vec3(1.0 / brightness));
	COLOR = vec4(color, 1.0);
}
