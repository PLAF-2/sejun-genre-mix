import bpy
import bmesh
import math
from pathlib import Path
from mathutils import Vector

root = Path(__file__).resolve().parents[1]
target_root = root / ".blender-user" / "extensions" / "blender_org" / "mpfb" / "data" / "targets"
out_dir = root / "godot-game" / "assets" / "3d" / "club_leader_boss"
blend_dir = root / "blender_project" / "club_leader_boss"
human = bpy.data.objects["ClubLeaderBoss_Base"]
rig = bpy.data.objects["ClubLeaderBoss_Base.rig"]


def activate(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def load_target(relative_path, weight):
    activate(human)
    path = target_root / relative_path
    bpy.ops.mpfb.load_target(
        directory=str(path.parent),
        files=[{"name": path.name}],
        weight=weight,
    )


def material(name, color, metallic=0.0, roughness=0.45, emission=None):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1.0)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if emission:
        bsdf.inputs["Emission Color"].default_value = (*emission, 1.0)
        bsdf.inputs["Emission Strength"].default_value = 4.0
    return mat


def smooth(obj):
    if obj.type == "MESH":
        for poly in obj.data.polygons:
            poly.use_smooth = True


def uv_part(name, location, scale, mat, parent=None):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=48, ring_count=24, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    smooth(obj)
    bevel = obj.modifiers.new("Soft bevel", "BEVEL")
    bevel.width = 0.004
    bevel.segments = 2
    if parent:
        obj.parent = parent
    return obj


def cube_part(name, location, scale, mat, rotation=(0.0, 0.0, 0.0), parent=None):
    bpy.ops.mesh.primitive_cube_add(location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    bevel = obj.modifiers.new("Tailored bevel", "BEVEL")
    bevel.width = min(scale) * 0.32
    bevel.segments = 4
    smooth(obj)
    if parent:
        obj.parent = parent
    return obj


def cylinder_part(name, location, radius, depth, mat, scale=(1.0, 1.0, 1.0), parent=None):
    bpy.ops.mesh.primitive_cylinder_add(vertices=48, radius=radius, depth=depth, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    bevel = obj.modifiers.new("Rounded edges", "BEVEL")
    bevel.width = 0.012
    bevel.segments = 3
    smooth(obj)
    if parent:
        obj.parent = parent
    return obj


def body_shell(name, keep_face, mat, thickness=0.008):
    depsgraph = bpy.context.evaluated_depsgraph_get()
    evaluated = human.evaluated_get(depsgraph)
    mesh = bpy.data.meshes.new_from_object(evaluated, depsgraph=depsgraph)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    for group in human.vertex_groups:
        obj.vertex_groups.new(name=group.name)
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bm.faces.ensure_lookup_table()
    remove_faces = [face for face in bm.faces if not keep_face(face.calc_center_median())]
    bmesh.ops.delete(bm, geom=remove_faces, context="FACES")
    loose = [vert for vert in bm.verts if not vert.link_faces]
    if loose:
        bmesh.ops.delete(bm, geom=loose, context="VERTS")
    bm.to_mesh(mesh)
    bm.free()
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    for poly in obj.data.polygons:
        poly.material_index = 0
    solidify = obj.modifiers.new("Fabric thickness", "SOLIDIFY")
    solidify.thickness = thickness
    solidify.offset = 1.0
    smooth_mod = obj.modifiers.new("Tailored smoothing", "SMOOTH")
    smooth_mod.factor = 0.28
    smooth_mod.iterations = 2
    armature = obj.modifiers.new("Boss rig", "ARMATURE")
    armature.object = rig
    smooth(obj)
    return obj


def hair_curve(name, points, radius, mat):
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = radius
    curve.bevel_resolution = 3
    curve.resolution_u = 8
    spline = curve.splines.new("BEZIER")
    spline.bezier_points.add(len(points) - 1)
    for bp, co in zip(spline.bezier_points, points):
        bp.co = co
        bp.handle_left_type = "AUTO"
        bp.handle_right_type = "AUTO"
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    return obj


def skin_to_bone(obj, bone_name):
    """Keep accessory vertices in rest space and deform with the same exported rig."""
    activate(obj)
    if obj.type == "CURVE":
        bpy.ops.object.convert(target="MESH")
    obj.parent = rig
    group = obj.vertex_groups.get(bone_name) or obj.vertex_groups.new(name=bone_name)
    group.add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")
    modifier = obj.modifiers.new("Accessory skin", "ARMATURE")
    modifier.object = rig


# Photo-guided phenotype and facial proportions.
keys = human.data.shape_keys.key_blocks if human.data.shape_keys else []
for key in keys:
    if key.name.startswith("$md-"):
        key.value = 0.0
for key_name, value in {
    "$md-$as-$ma-$yn": 0.82,
    "$md-$ca-$ma-$yn": 0.14,
    "$md-universal-$ma-$yn-$av$mu-$av$wg": 0.78,
}.items():
    if human.data.shape_keys and key_name in human.data.shape_keys.key_blocks:
        human.data.shape_keys.key_blocks[key_name].value = value

for path, weight in [
    ("head/head-oval.target.gz", 0.58),
    ("head/head-scale-vert-incr.target.gz", 0.13),
    ("head/head-scale-horiz-decr.target.gz", 0.11),
    ("chin/chin-width-decr.target.gz", 0.18),
    ("chin/chin-height-incr.target.gz", 0.07),
    ("chin/chin-prominent-decr.target.gz", 0.05),
    ("nose/nose-scale-horiz-decr.target.gz", 0.10),
    ("nose/nose-scale-depth-incr.target.gz", 0.10),
    ("nose/nose-point-width-decr.target.gz", 0.06),
    ("nose/nose-point-down.target.gz", 0.04),
    ("forehead/forehead-scale-vert-incr.target.gz", 0.06),
    ("eyebrows/eyebrows-angle-down.target.gz", 0.05),
    ("mouth/mouth-scale-horiz-incr.target.gz", 0.04),
    ("mouth/mouth-upperlip-volume-decr.target.gz", 0.06),
    ("mouth/mouth-lowerlip-volume-decr.target.gz", 0.04),
    ("cheek/l-cheek-volume-decr.target.gz", 0.05),
    ("cheek/r-cheek-volume-decr.target.gz", 0.05),
    ("eyes/l-eye-scale-decr.target.gz", 0.05),
    ("eyes/r-eye-scale-decr.target.gz", 0.05),
    ("eyes/l-eye-epicanthus-in.target.gz", 0.12),
    ("eyes/r-eye-epicanthus-in.target.gz", 0.12),
]:
    load_target(path, weight)

# A plain Principled material survives GLB export; MPFB's procedural node group does not.
skin_mat = material("Boss_Skin_PBR", (0.55, 0.33, 0.23), roughness=0.56)
human.data.materials.clear()
human.data.materials.append(skin_mat)
for polygon in human.data.polygons:
    polygon.material_index = 0
smooth(human)

hair_mat = material("Hair_Black_Natural", (0.008, 0.010, 0.014), roughness=0.27)
coat_mat = material("Boss_Coat_Black", (0.017, 0.021, 0.030), metallic=0.03, roughness=0.68)
cloth_mat = material("Boss_Inner_Cloth", (0.025, 0.030, 0.042), roughness=0.62)
metal_mat = material("Boss_Armor_DarkSteel", (0.055, 0.062, 0.085), metallic=0.88, roughness=0.22)
trim_mat = material("Boss_Arcane_Trim", (0.20, 0.055, 0.38), metallic=0.48, roughness=0.24, emission=(0.38, 0.06, 0.72))
boot_mat = material("Boss_Boot_Leather", (0.008, 0.009, 0.012), metallic=0.05, roughness=0.31)

game_parts = [human, rig]

# Natural side-parted black hair: a sculpted cap plus curved locks.
hair_cap = uv_part("Boss_Hair_Cap", (0.0, -0.018, 1.548), (0.112, 0.108, 0.125), hair_mat)
bm = bmesh.new()
bm.from_mesh(hair_cap.data)
bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < (-0.012 if v.co.y < -0.025 else -0.048)], context="VERTS")
bm.to_mesh(hair_cap.data)
bm.free()
game_parts.append(hair_cap)

part = Vector((0.018, -0.080, 1.665))
for i in range(17):
    side = -1.0 if i < 10 else 1.0
    t = (i if i < 10 else i - 10) / (9.0 if i < 10 else 6.0)
    end_x = (-0.092 + t * 0.105) if side < 0 else (0.025 + t * 0.075)
    end_z = 1.572 - abs(end_x) * 0.10
    points = [
        part + Vector((side * 0.003 * i, 0.0, -0.002 * i)),
        Vector((end_x * 0.55, -0.119, 1.629)),
        Vector((end_x, -0.122, end_z)),
    ]
    lock = hair_curve(f"Boss_Hair_Lock_{i:02d}", points, 0.0045 + (i % 3) * 0.0008, hair_mat)
    game_parts.append(lock)

# Eyes are separate meshes; the MPFB base alone has no eyeballs or irises.
eye_white = material("Boss_Eye_White", (0.72, 0.69, 0.64), roughness=0.24)
iris_mat = material("Boss_Iris_DarkBrown", (0.025, 0.014, 0.009), roughness=0.27)
for side, tag in [(-1.0, "R"), (1.0, "L")]:
    eye_center = rig.data.bones[f"eye.{tag}"].head_local.copy()
    # The face morph moved the sockets forward and down from the original rig markers.
    eye_center.y = -0.134
    eye_center.z = 1.540
    game_parts.append(uv_part(f"Boss_Eyeball_{tag}", eye_center, (0.0125, 0.0108, 0.0115), eye_white))
    game_parts.append(uv_part(f"Boss_Iris_{tag}", eye_center + Vector((0, -0.0102, 0)), (0.0052, 0.0016, 0.0052), iris_mat))
    game_parts.append(hair_curve(f"Boss_Eyebrow_{tag}", [
        (side * 0.014, -0.146, 1.557),
        (side * 0.028, -0.145, 1.560),
        (side * 0.044, -0.135, 1.555),
    ], 0.0018, hair_mat))

# Body-conforming garments copied from the human surface. These deform with the rig
# and retain natural shoulders, elbows, knees and silhouette instead of primitive blocks.
jacket = body_shell(
    "Boss_Fitted_LongCoat",
    lambda c: (0.72 < c.z < 1.40 and abs(c.x) < 0.31) or (1.02 < c.z < 1.36 and 0.20 < abs(c.x) < 0.46),
    coat_mat,
    0.011,
)
pants = body_shell(
    "Boss_Fitted_Trousers",
    lambda c: 0.16 < c.z < 0.91 and abs(c.x) < 0.245,
    cloth_mat,
    0.009,
)
boots = body_shell(
    "Boss_Fitted_Boots",
    lambda c: c.z < 0.36 and abs(c.x) < 0.22,
    boot_mat,
    0.013,
)
game_parts += [jacket, pants, boots]
game_parts += [
    cube_part("Boss_Belt", (0, -0.132, 0.91), (0.175, 0.010, 0.010), metal_mat),
    uv_part("Boss_Chest_Core", (0, -0.153, 1.215), (0.020, 0.009, 0.026), trim_mat),
]

# Subtle lapels and arcane seams remain readable at FPS distance without hiding the face.
for side in (-1.0, 1.0):
    game_parts.append(cube_part(
        f"Boss_Collar_{'L' if side < 0 else 'R'}",
        (side * 0.041, -0.145, 1.286),
        (0.020, 0.007, 0.060),
        metal_mat,
        rotation=(0.0, side * 0.04, side * 0.31),
    ))
    game_parts.append(cube_part(
        f"Boss_Trim_{'L' if side < 0 else 'R'}",
        (side * 0.145, -0.140, 0.91),
        (0.004, 0.005, 0.220),
        trim_mat,
        rotation=(0.0, 0.0, side * 0.035),
    ))
    game_parts.append(cube_part(
        f"Boss_ChestStrap_{'L' if side < 0 else 'R'}",
        (side * 0.055, -0.146, 1.145),
        (0.009, 0.006, 0.145),
        metal_mat,
        rotation=(0.0, 0.0, side * 0.35),
    ))

# Hair/eyes must follow the head, and rigid trim follows the chest or pelvis.
for obj in game_parts[2:]:
    if obj in [jacket, pants, boots]:
        obj.parent = rig
        continue
    if any(word in obj.name for word in ("Hair", "Eyeball", "Iris", "Eyebrow")):
        skin_to_bone(obj, "head")
    else:
        skin_to_bone(obj, "spine05" if "Belt" in obj.name else "spine02")

# Neutral ready pose, less like a mannequin while retaining a clean game-rig rest shape.
for bone_name, rotation in {
    "upperarm01.L": (0.0, 0.0, math.radians(-18)),
    "upperarm01.R": (0.0, 0.0, math.radians(18)),
    "lowerarm01.L": (0.0, math.radians(-8), math.radians(-12)),
    "lowerarm01.R": (0.0, math.radians(8), math.radians(12)),
    "head": (math.radians(2), 0.0, 0.0),
}.items():
    if bone_name in rig.pose.bones:
        bone = rig.pose.bones[bone_name]
        bone.rotation_mode = "XYZ"
        bone.rotation_euler = rotation

# Save fitted source.
fitted_blend = blend_dir / "club_leader_boss_fitted.blend"
bpy.ops.wm.save_as_mainfile(filepath=str(fitted_blend))

# Export only game objects to Godot's recommended binary glTF format.
bpy.ops.object.select_all(action="DESELECT")
for obj in game_parts:
    obj.select_set(True)
bpy.context.view_layer.objects.active = rig
glb_path = out_dir / "club_leader_boss.glb"
bpy.ops.export_scene.gltf(
    filepath=str(glb_path),
    export_format="GLB",
    use_selection=True,
    export_animations=True,
    export_apply=True,
)

# Render a quick proof image from the same asset.
camera = bpy.data.objects.get("Preview_Camera")
if camera:
    camera.location = (0.0, -3.7, 1.05)
    direction = Vector((0.0, -0.02, 0.95)) - camera.location
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = camera
bpy.context.scene.render.film_transparent = False
bpy.context.scene.world.color = (0.012, 0.015, 0.026)
bpy.context.scene.render.engine = "BLENDER_WORKBENCH"
bpy.context.scene.display.shading.light = "STUDIO"
bpy.context.scene.display.shading.color_type = "MATERIAL"
bpy.context.scene.display.shading.show_shadows = True
bpy.context.scene.display.shading.show_cavity = True
bpy.context.scene.render.resolution_x = 720
bpy.context.scene.render.resolution_y = 900
bpy.context.scene.render.resolution_percentage = 100
bpy.context.scene.render.filepath = str(out_dir / "club_leader_boss_preview.png")
bpy.ops.render.render(write_still=True)

# A closer proof image makes facial fitting reviewable without enlarging a thumbnail.
camera.location = (0.36, -1.10, 1.60)
camera.rotation_euler = (Vector((0, -0.05, 1.54)) - camera.location).to_track_quat("-Z", "Y").to_euler()
bpy.context.scene.render.filepath = str(out_dir / "club_leader_boss_face_preview.png")
bpy.ops.render.render(write_still=True)

print("FITTED", fitted_blend)
print("EXPORTED", glb_path)
print("PREVIEW", bpy.context.scene.render.filepath)
