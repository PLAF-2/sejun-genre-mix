extends RefCounted

# Raycasts own damage. These short-lived meshes only show the already-clipped path.
static func glow(tint: Color, strength: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = tint
	material.emission_enabled = true
	material.emission = tint
	material.emission_energy_multiplier = strength
	return material

static func shot(world: Node3D, start: Vector3, end: Vector3, impact: bool = true, tint: Color = Color("#ffe3a3")) -> void:
	var distance := start.distance_to(end)
	if distance < 0.03: return
	var bolt := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.016
	mesh.bottom_radius = 0.025
	mesh.height = minf(0.48, distance)
	mesh.radial_segments = 8
	bolt.mesh = mesh
	bolt.material_override = glow(tint, 4.0)
	world.add_child(bolt)
	bolt.global_position = start
	bolt.quaternion = Quaternion(Vector3.UP, (end - start).normalized())
	bolt.name = "VisibleBullet"
	var line := MeshInstance3D.new()
	var trail := ImmediateMesh.new()
	trail.surface_begin(Mesh.PRIMITIVE_LINES, glow(tint.darkened(0.25), 2.0))
	trail.surface_add_vertex(start)
	trail.surface_add_vertex(end)
	trail.surface_end()
	line.mesh = trail
	world.add_child(line)
	var fade := line.create_tween()
	fade.tween_interval(0.045)
	fade.tween_callback(line.queue_free)
	var flight := bolt.create_tween()
	flight.tween_property(bolt, "global_position", end, clampf(distance / 130.0, 0.04, 0.13))
	flight.tween_callback(func() -> void:
		if impact and is_instance_valid(world):
			for i in 7:
				var spark := MeshInstance3D.new()
				var sphere := SphereMesh.new()
				sphere.radius = 0.025
				sphere.height = 0.05
				spark.mesh = sphere
				spark.material_override = glow(tint, 3.0)
				world.add_child(spark)
				spark.global_position = end
				var tween := spark.create_tween().set_parallel(true)
				tween.tween_property(spark, "position", spark.position + Vector3(randf_range(-0.3, 0.3), randf_range(0.02, 0.35), randf_range(-0.3, 0.3)), 0.16)
				tween.tween_property(spark, "scale", Vector3.ZERO, 0.16)
				tween.chain().tween_callback(spark.queue_free)
		bolt.queue_free()
	)

static func casing(world: Node3D, at: Vector3, right: Vector3) -> void:
	var shell := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.025
	mesh.bottom_radius = 0.025
	mesh.height = 0.10
	shell.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#ac864b")
	material.metallic = 0.8
	material.roughness = 0.25
	shell.material_override = material
	world.add_child(shell)
	shell.global_position = at
	var tween := shell.create_tween()
	tween.tween_property(shell, "position", at + right * 0.6 + Vector3.UP * 0.16, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(shell, "rotation", Vector3(3, 4, 2), 0.35)
	tween.tween_property(shell, "position", at + right * 0.95 - Vector3.UP, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(shell.queue_free)
