"""Retarget downloaded Mixamo Walking to the existing boss, retaining Snow CC-BY garments."""
import bpy,math,json
import numpy as np
from pathlib import Path
from mathutils import Vector,Quaternion,Matrix
root=Path(__file__).resolve().parents[1];out=root/'godot-game/assets/3d/club_leader_boss';scene=bpy.context.scene;rig=bpy.data.objects['ClubLeaderBoss_Base.rig']
rig.animation_data.action=None
for obj in bpy.context.scene.objects:
 if obj.type=='MESH':obj.hide_viewport=True
v4=(root/'blender_tools/refine_boss_walk_v4.py').read_text(encoding='utf-8-sig')
code=v4[v4.index("source=(root/'blender_tools/refine_boss_motion_v3.py')"):v4.index('rig.animation_data_create();scene.render.fps=30')]
code=code.replace('work/cmu_walk_cycle.json','work/mixamo_walk_cycle.json')
exec(code,globals())
old=bpy.data.actions.get('Boss_Walk')
if old:bpy.data.actions.remove(old)
action=bpy.data.actions.new('Boss_Walk');action.use_fake_user=True;rig.animation_data.action=action;scene.render.fps=30
frames=round(capture['duration']*30);scene.frame_start=0;scene.frame_end=frames
for f in range(frames+1):
 scene.frame_set(f);mocap_pose(f/frames)
 for pb in rig.pose.bones:
  pb.keyframe_insert(data_path='rotation_quaternion',frame=f,group=pb.name)
  if pb.name=='root':pb.keyframe_insert(data_path='location',frame=f,group=pb.name)
rig.animation_data.action=None;reset()
for obj in bpy.context.scene.objects:
 if obj.type=='MESH':obj.hide_viewport=False
metadata={'source':'Adobe Mixamo Walking (Swagger)','fps':30,'frames':frames,'duration':capture['duration'],'source_speed':capture['speed'],'leg_scale':legscale,'godot_walk_speed':capture['speed']*legscale*3.05}
(out/'MIXAMO_V7_METADATA.json').write_text(json.dumps(metadata,indent=2),encoding='utf-8')
bpy.ops.wm.save_as_mainfile(filepath=str(root/'blender_project/club_leader_boss/club_leader_boss_mixamo_v7.blend'))
bpy.ops.object.select_all(action='DESELECT')
for obj in bpy.context.scene.objects:
 if obj.type in ['MESH','ARMATURE']:obj.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(out/'club_leader_boss_mixamo_v7.glb'),export_format='GLB',use_selection=True,export_apply=True,export_animations=True,export_animation_mode='ACTIONS')
rig.animation_data.action=action;scene.frame_set(round(frames*.30))
scene.render.engine='CYCLES';scene.cycles.samples=20;scene.render.resolution_x=800;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
cam=bpy.data.objects['Preview_Camera'];scene.camera=cam;cam.location=(1.2,-3.15,1.55);cam.rotation_euler=(Vector((0,0,.97))-cam.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(out/'mixamo_v7_walk.png');bpy.ops.render.render(write_still=True)
print('MIXAMO V7 EXPORTED',metadata,flush=True)
