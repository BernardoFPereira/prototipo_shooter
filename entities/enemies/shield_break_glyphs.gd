class_name ShieldBreakGlyphs
extends GPUParticles3D

## Explosão de glifos quando o escudo de um inimigo quebra: o escudo "se decompila" em
## caracteres (os mesmos glifos do fundo do menu, matrix_dust_atlas.png).
##
## A cor e o brilho são copiados do material do escudo na hora da quebra — se mudarem a cor do
## escudo (parâmetro `color` do hologram.gdshader), os glifos seguem automaticamente.
##
## Uso (é o que o EnemyBase.break_shield() faz):
##     var fx = cena.instantiate()
##     get_tree().root.add_child(fx)
##     fx.play_from_shield(mesh_do_escudo)

## Cor usada se não der pra ler a cor do material do escudo.
const FALLBACK_COLOR := Color(0.545, 0.0, 1.0)
## Brilho usado se o material do escudo não tiver o parâmetro `_emission`.
const FALLBACK_ENERGY := 4.0


## Lê cor, brilho e tamanho do escudo, posiciona a explosão no centro dele e dispara.
func play_from_shield(shield_mesh: MeshInstance3D) -> void:
	if shield_mesh == null:
		play(FALLBACK_COLOR, FALLBACK_ENERGY, 1.2)
		return
	global_position = shield_mesh.global_position
	play(_read_shield_color(shield_mesh), _read_shield_energy(shield_mesh), _read_shield_radius(shield_mesh))


func play(color: Color, energy: float, radius: float) -> void:
	# Duplica os materiais pra cada explosão ter a própria cor sem mexer no recurso da cena
	# (senão dois inimigos com escudos de cores diferentes brigariam pelo mesmo material).
	var glyph_mat := (draw_pass_1 as PrimitiveMesh).material.duplicate() as StandardMaterial3D
	# Albedo preto + emission = cor do escudo * _emission: é a mesma conta que o hologram.gdshader
	# faz (ALBEDO = color * _emission, unshaded), então o tom bate com o do escudo.
	glyph_mat.emission = color
	glyph_mat.emission_energy_multiplier = energy
	material_override = glyph_mat

	var process := process_material.duplicate() as ParticleProcessMaterial
	process.emission_sphere_radius = radius
	process_material = process

	restart()

	# one_shot: depois que o último glifo morre, o nó não serve pra mais nada.
	var max_lifetime := lifetime * (1.0 + process.lifetime_randomness)
	await get_tree().create_timer(max_lifetime + 0.5).timeout
	queue_free()


#region LEITURA DO MATERIAL DO ESCUDO
func _shield_material(shield_mesh: MeshInstance3D) -> Material:
	if shield_mesh.material_override:
		return shield_mesh.material_override
	return shield_mesh.get_active_material(0)


func _read_shield_color(shield_mesh: MeshInstance3D) -> Color:
	var mat := _shield_material(shield_mesh)
	if mat is ShaderMaterial:
		var c = mat.get_shader_parameter("color")
		if c is Color:
			return Color(c.r, c.g, c.b)
		if c is Vector3:
			return Color(c.x, c.y, c.z)
	elif mat is BaseMaterial3D:
		return mat.albedo_color
	return FALLBACK_COLOR


func _read_shield_energy(shield_mesh: MeshInstance3D) -> float:
	var mat := _shield_material(shield_mesh)
	if mat is ShaderMaterial:
		var e = mat.get_shader_parameter("_emission")
		if e is float or e is int:
			return maxf(float(e), 1.0)
	return FALLBACK_ENERGY


func _read_shield_radius(shield_mesh: MeshInstance3D) -> float:
	var s := shield_mesh.global_transform.basis.get_scale()
	var scale_factor := maxf(s.x, maxf(s.y, s.z))
	if shield_mesh.mesh is SphereMesh:
		return (shield_mesh.mesh as SphereMesh).radius * scale_factor
	return shield_mesh.get_aabb().size.x * 0.5 * scale_factor
#endregion
