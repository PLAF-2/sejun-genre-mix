import bpy
from pathlib import Path

project_root = Path(__file__).resolve().parents[1]
output_dir = project_root / "blender_project" / "club_leader_boss"
output_dir.mkdir(parents=True, exist_ok=True)

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)

result = bpy.ops.mpfb.create_human()
print("CREATE_HUMAN", result)

mesh_objects = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
if not mesh_objects:
    raise RuntimeError("MPFB did not create a human mesh")

human = max(mesh_objects, key=lambda obj: len(obj.data.vertices))
human.name = "ClubLeaderBoss_Base"
human.data.name = "ClubLeaderBoss_Mesh"
bpy.context.view_layer.objects.active = human
human.select_set(True)

# 사진 속 인물과 비슷한 성인 남성의 자연스러운 기본 비율에서 시작한다.
human["character_role"] = "club_leader_final_boss"
human["reference_note"] = "Black side-parted hair, lean young adult male, realistic RPG boss"

try:
    bpy.ops.mpfb.add_standard_rig()
    print("STANDARD_RIG_ADDED")
except Exception as exc:
    print("STANDARD_RIG_WARNING", exc)

# 작업 확인용 조명과 카메라. Godot로 내보낼 때에는 모델/골격만 선택한다.
bpy.ops.object.light_add(type="AREA", location=(4.0, -4.0, 6.5))
key = bpy.context.object
key.name = "Preview_Key_Light"
key.data.energy = 1100
key.data.shape = "DISK"
key.data.size = 4.0

bpy.ops.object.light_add(type="AREA", location=(-3.0, -1.0, 4.0))
fill = bpy.context.object
fill.name = "Preview_Fill_Light"
fill.data.energy = 650
fill.data.size = 3.0

bpy.ops.object.camera_add(location=(0.0, -8.0, 1.55), rotation=(1.5708, 0.0, 0.0))
camera = bpy.context.object
camera.name = "Preview_Camera"
bpy.context.scene.camera = camera

scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 720
scene.render.resolution_y = 900
scene.render.resolution_percentage = 100

blend_path = output_dir / "club_leader_boss_working.blend"
bpy.ops.wm.save_as_mainfile(filepath=str(blend_path))
print("SAVED", blend_path)
print("OBJECTS", [(obj.name, obj.type) for obj in bpy.context.scene.objects])
