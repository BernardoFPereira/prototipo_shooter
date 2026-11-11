shader_type canvas_item;

// Vidro do capacete rachando. Fica num ColorRect de tela inteira (HelmetCrack.tscn).
// Tudo é calculado numa grade de pixels igual à arte do HUD (640x360 esticado pra 1080p = pixels de 3x3),
// então as rachaduras ficam pixeladas como o resto do jogo.
// Só aparece dentro da visão do capacete: onde a textura do HelmetFrame é transparente.
//
// Formato da rachadura: teia de aranha (Voronoi em coordenadas log-polares em volta do ponto de impacto):
// rachaduras compridas saindo do impacto + anéis, densas perto do impacto e cada vez maiores longe dele.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform sampler2D visor_mask : filter_nearest; // HUD-HelmetFrame.png (alfa > 0.5 = metal do capacete)

group_uniforms Animacao;
uniform float crack_progress : hint_range(0.0, 1.0) = 0.0; // 0 = vidro inteiro, 1 = rachado até as bordas
uniform float flash : hint_range(0.0, 1.0) = 0.0;          // clarão no ponto do impacto

group_uniforms Formato;
uniform vec2 impact_point = vec2(0.62, 0.4);    // ponto do impacto (0-1 na tela)
uniform vec2 pixel_grid = vec2(640.0, 360.0);  // resolução da arte do HUD (tamanho do "pixel")
uniform float spokes : hint_range(4.0, 40.0, 1.0) = 13.0; // quantas rachaduras saem do impacto
uniform float ring_spacing : hint_range(0.2, 2.0) = 0.65; // <1 = anéis mais espaçados (rachaduras radiais mais longas)
uniform float jitter : hint_range(0.0, 1.0) = 0.85;      // irregularidade das células
uniform float reach : hint_range(0.1, 1.5) = 1.05;       // até onde chega com progress = 1 (1 = largura da tela)
uniform float reach_variation : hint_range(0.0, 1.0) = 0.45; // umas rachaduras chegam mais longe que outras
uniform float core_radius = 7.0;               // raio (em pixels da grade) do miolo todo estilhaçado
uniform float line_width : hint_range(0.2, 2.0) = 0.6;    // espessura das linhas (pixels da grade)
uniform float seed = 0.0;                      // muda o desenho da rachadura

group_uniforms Cores;
uniform vec4 crack_color : source_color = vec4(0.88, 0.97, 1.0, 0.8);
uniform vec4 shadow_color : source_color = vec4(0.0, 0.02, 0.03, 0.45);
uniform vec4 core_color : source_color = vec4(0.92, 1.0, 1.0, 0.8);
uniform vec4 glass_tint : source_color = vec4(0.55, 0.75, 0.8, 0.03); // névoa nos cacos
uniform float shard_shade : hint_range(0.0, 0.5) = 0.04; // cada caco fica um pouco mais claro/escuro
uniform float refraction : hint_range(0.0, 4.0) = 1.0;   // deslocamento da imagem em cada caco (pixels da grade)


vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p + seed * 17.13) * 43758.5453);
}

float hash1(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233)) + seed * 3.71) * 43758.5453);
}

vec2 wrap_cell(vec2 c) {
	return vec2(mod(c.x, spokes), c.y);
}

// Voronoi com distância até a borda (Inigo Quilez). x.x é periódico em "spokes".
// Retorna (distância até a borda, id da célula).
vec3 voronoi(vec2 x) {
	vec2 n = floor(x);
	vec2 f = fract(x);
	vec2 mg = vec2(0.0);
	vec2 mr = vec2(0.0);
	float md = 8.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 o = 0.5 + jitter * (hash2(wrap_cell(n + g)) - 0.5);
			vec2 r = g + o - f;
			float d = dot(r, r);
			if (d < md) {
				md = d;
				mr = r;
				mg = g;
			}
		}
	}
	md = 8.0;
	for (int j = -2; j <= 2; j++) {
		for (int i = -2; i <= 2; i++) {
			vec2 g = mg + vec2(float(i), float(j));
			vec2 o = 0.5 + jitter * (hash2(wrap_cell(n + g)) - 0.5);
			vec2 r = g + o - f;
			if (dot(mr - r, mr - r) > 0.00001) {
				md = min(md, dot(0.5 * (mr + r), normalize(r - mr)));
			}
		}
	}
	return vec3(md, wrap_cell(n + mg));
}

// Informação da rachadura num pixel da grade:
// x = distância até a linha (em pixels da grade), y = raio até o impacto, zw = id do caco.
vec4 crack_at(vec2 p) {
	vec2 center = impact_point * pixel_grid;
	vec2 d = p - center;
	float r = max(length(d), 0.5);
	float ang = atan(d.y, d.x) / TAU + 0.5;
	float k = spokes / TAU;
	vec2 w = vec2(ang * spokes, log(r) * k * ring_spacing);
	vec3 v = voronoi(w);
	// converte a distância do espaço log-polar pra pixels (1 unidade ~ r / k pixels)
	float px = v.x * r / k / sqrt(ring_spacing);
	return vec4(px, r, v.yz);
}

// Raio que a rachadura já alcançou nessa direção (varia por "fatia" pra umas irem mais longe).
float reach_at(float ang01, float cell_x) {
	float max_r = reach * pixel_grid.x;
	float var = mix(1.0 - reach_variation, 1.0 + reach_variation * 0.5, hash1(vec2(cell_x, 7.0)));
	float p = crack_progress * crack_progress * (3.0 - 2.0 * crack_progress); // suaviza
	return p * max_r * var;
}

void fragment() {
	vec2 cell_px = floor(UV * pixel_grid) + 0.5; // centro do pixel da grade
	vec2 grid_uv = cell_px / pixel_grid;

	float metal = texture(visor_mask, grid_uv).a;
	if (crack_progress <= 0.0 && flash <= 0.0 || metal > 0.5) {
		COLOR = vec4(0.0);
	} else {
		vec4 here = crack_at(cell_px);
		vec4 diag = crack_at(cell_px + vec2(-1.0, 1.0)); // linha um pixel acima/direita = sombra aqui
		float r = here.y;

		vec2 dd = cell_px - impact_point * pixel_grid;
		float ang01 = atan(dd.y, dd.x) / TAU + 0.5;
		float reach_here = reach_at(ang01, here.z);
		float reach_diag = reach_at(ang01, diag.z);
		// o caco só "quebra" (névoa + refração) quando a rachadura passa do meio dele
		float k = spokes / TAU * ring_spacing;
		float cell_r = exp((here.w + 0.5) / k);
		float shattered = step(cell_r, reach_here);

		float width = line_width * (1.0 + 1.3 * exp(-r / 35.0)); // linhas mais grossas perto do impacto
		bool line = here.x < width && r < reach_here;
		bool shadow = !line && diag.x < width && diag.y < reach_diag;
		// miolo estilhaçado em volta do impacto (cresce rápido no começo)
		float core_r = core_radius * clamp(crack_progress * 6.0, 0.0, 1.0);
		bool core = r < core_r && hash1(cell_px) < mix(0.85, 0.15, r / max(core_r, 0.001));

		// imagem atrás do vidro, deslocada um pouco por caco (refração), sempre em pixels inteiros da grade
		vec2 shard_offset = floor((hash2(here.zw + 3.1) - 0.5) * 2.0 * refraction + 0.5) * shattered;
		vec2 sample_uv = SCREEN_UV + shard_offset / pixel_grid;
		vec3 col = texture(screen_tex, sample_uv).rgb;

		// cacos: névoa + leve variação de brilho por caco
		float shade = (hash1(here.zw + 9.7) - 0.5) * 2.0 * shard_shade * shattered;
		col = mix(col, glass_tint.rgb, glass_tint.a * shattered);
		col *= 1.0 + shade;

		if (shadow) {
			col = mix(col, shadow_color.rgb, shadow_color.a);
		}
		if (line) {
			col = mix(col, crack_color.rgb, crack_color.a);
		}
		if (core) {
			col = mix(col, core_color.rgb, core_color.a);
		}
		// clarão do impacto, em degraus (sem degradê liso)
		float glow = flash * exp(-r / 22.0);
		glow = floor(glow * 4.0) / 4.0;
		col += vec3(glow);

		COLOR = vec4(col, 1.0);
	}
}
