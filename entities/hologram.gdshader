shader_type spatial;
render_mode unshaded, shadows_disabled;
#include "funcs.gdshaderinc"
uniform vec3 color: source_color;
uniform float lines1:hint_range(0.0, 300.0, 1.0) = 2;
uniform float lines2:hint_range(0.0, 200.0, 0.1) = 2;
uniform float _emission:hint_range(0.0,10.0);
uniform float _fresnel:hint_range(0.0, 10.0) = 1.0;

// Quebra do escudo, animado pelo EnemyBase.break_shield(): 0 = escudo normal, 1 = sumiu.
// Com 0 o shader se comporta exatamente como antes.
//   0.00 - 0.35: flash quase branco + glitch forte e constante
//   0.00 - 1.00: as scanlines vão sumindo uma a uma, em ordem aleatória
uniform float break_progress:hint_range(0.0, 1.0) = 0.0;

varying float rand_dist;

void vertex(){
	float breaking = step(0.0001, break_progress);
	float amp = 0.04 + break_progress * 0.3;
	float distortion = sin(TIME * 10.0 + VERTEX.y * 20.0) * amp;
	float rand_time = random(TIME);
	// Normalmente o glitch aparece em ~1% dos frames; quebrando, fica ligado o tempo todo.
	rand_dist = max(step(rand_time, 0.01), breaking);

	VERTEX.x += distortion*rand_dist;
	// Leve "inchaço" enquanto colapsa.
	VERTEX *= 1.0 + break_progress * 0.15;
}

void fragment(){
	float n = random2_1(SCREEN_UV);
	float f = fresnel(_fresnel, NORMAL, VIEW);

	vec2 igrid = floor(SCREEN_UV * lines1);
	float l1 = mod(igrid.y, 2.0);
	l1 = mix(0.4,1.0,l1);

	// Cada scanline some quando break_progress passa do "sorteio" dela.
	if (random(igrid.y) < break_progress) {
		discard;
	}

	vec2 uv2 = SCREEN_UV;
	uv2.y -= TIME * 0.06;
	vec2 igrid2 = floor(uv2*lines2);
	float l2 = random(igrid2.y);
	l2 = step(0.2,l2);
	l2 = mix(0.2,1.0,l2);

	float m = f*n*l1*l2;
	float flash = step(0.0001, break_progress) * (1.0 - smoothstep(0.0, 0.35, break_progress));
	// O flash só reforça o contorno (fresnel), não pinta a esfera inteira de branco.
	ALPHA = clamp(m + flash * f * 0.5, 0.0, 1.0);

	vec3 base_col = color * mix(_emission, _emission+5.0, rand_dist);
	ALBEDO = mix(base_col, vec3(2.0) + color * _emission, flash * 0.6);
}
