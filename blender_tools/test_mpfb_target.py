import bpy
from pathlib import Path

human = bpy.data.objects.get("ClubLeaderBoss_Base")
if human is None:
    raise RuntimeError("ClubLeaderBoss_Base not found")
bpy.ops.object.select_all(action="DESELECT")
human.select_set(True)
bpy.context.view_layer.objects.active = human

base = Path(__file__).resolve().parents[1] / ".blender-user" / "extensions" / "blender_org" / "mpfb" / "data" / "targets"
target = base / "head" / "head-oval.target.gz"
print("LOAD", target)
print(bpy.ops.mpfb.load_target(directory=str(target.parent), files=[{"name": target.name}], weight=0.65))
if human.data.shape_keys:
    print("SHAPE_KEYS", [(k.name, k.value) for k in human.data.shape_keys.key_blocks])
else:
    print("NO_SHAPE_KEYS")
