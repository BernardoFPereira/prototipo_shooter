class_name ShieldBreakGlyphs
extends GPUParticles3D


const FALLBACK_COLOR: Color = Color(0.545, 0.0, 1.0)
const FALLBACK_ENERGY: float = 4.0


func play_from_shield(shield_mesh: MeshInstance3D) -> void:
	if shield_mesh == null:
		play(FALLBACK_COLOR, FALLBACK_ENERGY, 1.2)
		return
	global_position = shield_mesh.global_position
	play(_read_shield_color(shield_mesh), _read_shield_energy(shield_mesh), _read_shield_radius(shield_mesh))


func play(color: Color, energy: float, radius: float) -> void:
	var glyph_mat: StandardMaterial3D = (draw_pass_1 as PrimitiveMesh).material.duplicate() as StandardMaterial3D
	glyph_mat.emission = color
	glyph_mat.emission_energy_multiplier = energy
	material_override = glyph_mat

	var process: ParticleProcessMaterial = process_material.duplicate() as ParticleProcessMaterial
	process.emission_sphere_radius = radius
	process_material = process

	restart()

	var max_lifetime: float = lifetime * (1.0 + process.lifetime_randomness)
	await get_tree().create_timer(max_lifetime + 0.5).timeout
	queue_free()


func _shield_material(shield_mesh: MeshInstance3D) -> Material:
	if shield_mesh.material_override:
		return shield_mesh.material_override
	return shield_mesh.get_active_material(0)


func _read_shield_color(shield_mesh: MeshInstance3D) -> Color:
	var mat: Material = _shield_material(shield_mesh)
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
	var mat: Material = _shield_material(shield_mesh)
	if mat is ShaderMaterial:
		var e = mat.get_shader_parameter("_emission")
		if e is float or e is int:
			return maxf(float(e), 1.0)
	return FALLBACK_ENERGY


func _read_shield_radius(shield_mesh: MeshInstance3D) -> float:
	var s: Vector3 = shield_mesh.global_transform.basis.get_scale()
	var scale_factor: float = maxf(s.x, maxf(s.y, s.z))
	if shield_mesh.mesh is SphereMesh:
		return (shield_mesh.mesh as SphereMesh).radius * scale_factor
	return shield_mesh.get_aabb().size.x * 0.5 * scale_factor
