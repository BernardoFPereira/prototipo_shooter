shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_always;

// AQUI ESTÁ O SEGREDO: Declaramos a textura e dizemos que ela é a "Albedo"
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;

uniform vec4 albedo : source_color = vec4(1.0);
uniform float glow_strength : hint_range(0.0, 10.0) = 4.0;

void fragment() {
    // Usamos o nome que declaramos acima: albedo_texture
    vec4 tex_color = texture(albedo_texture, UV);

    ALBEDO = albedo.rgb;
    ALPHA = tex_color.a * albedo.a;

    EMISSION = ALBEDO * glow_strength;
}