"""Adapt CC-BY Blender Studio Snow clothing to the existing photo-based boss rig."""
import bpy,bmesh,math
from pathlib import Path
from mathutils import Vector,Quaternion
root=Path(__file__).resolve().parents[1];out=root/'godot-game/assets/3d/club_leader_boss'
rig=bpy.data.objects['ClubLeaderBoss_Base.rig'];scene=bpy.context.scene
rig.animation_data.action=None
for p in rig.pose.bones:p.rotation_mode='QUATERNION';p.rotation_quaternion=Quaternion();p.location=Vector();p.scale=Vector((1,1,1))
bpy.context.view_layer.update()
original=set(bpy.data.objects)
original_actions=set(bpy.data.actions)
source=root/'blender_project/third_party/snow/source/snow_v02.blend'
with bpy.data.libraries.load(str(source),link=False) as (data_from,data_to):data_to.objects=['GEO-snow_shirt','GEO-snow_pants']
loaded={o.name:o for o in data_to.objects if o}
texroot=source.parent/'maps/bake'
def activate(o):
 bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o

def cloth_material(kind):
 m=bpy.data.materials.new('Snow_CC_BY_'+kind);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Roughness'].default_value=.8
 for suffix,target in [('diffuse','Base Color'),('roughness','Roughness'),('normal','Normal')]:
  image=bpy.data.images.load(str(texroot/(kind+'_'+suffix+'.png')),check_existing=False)
  image.name='Snow_'+kind+'_'+suffix+'_Game'
  if max(image.size)>2048:image.scale(2048,2048)
  image.pack()
  n=m.node_tree.nodes.new('ShaderNodeTexImage');n.image=image
  if suffix!='diffuse':image.colorspace_settings.name='Non-Color'
  if suffix=='normal':
   norm=m.node_tree.nodes.new('ShaderNodeNormalMap');norm.inputs['Strength'].default_value=.65;m.node_tree.links.new(n.outputs['Color'],norm.inputs['Color']);m.node_tree.links.new(norm.outputs['Normal'],p.inputs['Normal'])
  else:m.node_tree.links.new(n.outputs['Color'],p.inputs[target])
 return m

def transfer(o,donor):
 # Preserve the garment artist's actual DEF weights, remapped by bone role.
 src=loaded['GEO-snow_shirt'] if 'Tshirt' in o.name else loaded['GEO-snow_pants']
 names=[g.name for g in src.vertex_groups]
 weights=[[(names[g.group],g.weight) for g in v.groups if g.group<len(names)] for v in o.data.vertices]
 bm=bmesh.new();bm.from_mesh(o.data);layer=bm.verts.layers.deform.active
 if layer:
  for v in bm.verts:
   for key in list(v[layer].keys()):del v[layer][key]
 bm.to_mesh(o.data);bm.free();o.vertex_groups.clear()
 mapping={'DEF-Chest':'spine01','DEF-RibCage':'spine02','DEF-Spine':'spine03','DEF-Hip_Center':'root','DEF-Hips':'root'}
 for tag in ['L','R']:
  for snow,boss in [('Shoulder','shoulder01'),('UpperArm1','upperarm01'),('UpperArm2','upperarm02'),('Thigh1','upperleg01'),('Thigh2','upperleg02'),('Knee1','lowerleg01'),('Knee2','lowerleg02'),('Foot','foot')]:mapping['DEF-'+snow+'.'+tag]=boss+'.'+tag
 for i,values in enumerate(weights):
  merged={}
  for name,value in values:
   if name in mapping:merged[mapping[name]]=merged.get(mapping[name],0)+value
  if not merged:merged={'root':1}
  total=sum(merged.values())
  for bone,value in merged.items():
   group=o.vertex_groups.get(bone) or o.vertex_groups.new(name=bone);group.add([i],value/total,'REPLACE')
 o.parent=rig
 sub=o.modifiers.new('Smooth authored garment panels','SUBSURF');sub.levels=1;sub.render_levels=1
 arm=o.modifiers.new('Existing boss animation rig','ARMATURE');arm.object=rig
 for f in o.data.polygons:f.use_smooth=True

# Snow's cloth is independently authored in T-pose; fit its sleeve to the current A-pose.
shirt_source=loaded['GEO-snow_shirt'];mesh=shirt_source.data.copy()
shirt=bpy.data.objects.new('Snow_CC_BY_Adapted_Tshirt',mesh);bpy.context.collection.objects.link(shirt)
shirt.shape_key_clear()
for v in mesh.vertices:
 old=v.co.copy();x,y,z=old;torso=Vector((x*1.15,y*1.10,.95+(z-.8670366)*.964))
 if abs(x)>.165:
  tag='L' if x>0 else 'R';side=1 if x>0 else -1
  a=Vector((side*.187907,.004196,1.360809));b=Vector((side*.442178,.026985,1.337418))
  sa=rig.data.bones['upperarm01.'+tag].head_local;sb=rig.data.bones['lowerarm01.'+tag].head_local
  axis=b-a;t=max(0,min(1,(old-a).dot(axis)/axis.length_squared));center=a+axis*t
  q=axis.normalized().rotation_difference((sb-sa).normalized())
  fit=sa.lerp(sb,t)+q@(old-center)*1.02
  blend=max(0,min(1,(abs(x)-.165)/.065));torso=torso.lerp(fit,blend)
 v.co=torso
mesh.materials.clear();mesh.materials.append(cloth_material('shirt'))
for f in mesh.polygons:f.material_index=0
transfer(shirt,bpy.data.objects['Boss_Tailored_Jacket'])
# Fit artist-authored trouser panels along the new hip/knee/ankle lines.
sourcepants=loaded['GEO-snow_pants'];mesh=sourcepants.data.copy()
pants=bpy.data.objects.new('Snow_CC_BY_Adapted_Trousers',mesh);bpy.context.collection.objects.link(pants)
pants.shape_key_clear()
def mapz(z):
 anchors=[(.03677,.025),(.08058,.069),(.48961,.526),(.84253,.977),(.97156,1.100)]
 for (a,x),(b,y) in zip(anchors,anchors[1:]):
  if z<=b:return x+(y-x)*(z-a)/(b-a)
 return anchors[-1][1]
for v in mesh.vertices:
 x,y,z=v.co;tag='L' if x>=0 else 'R';side=1 if x>=0 else -1;nz=mapz(z)
 hip=rig.data.bones['upperleg01.'+tag].head_local;knee=rig.data.bones['lowerleg01.'+tag].head_local;ankle=rig.data.bones['foot.'+tag].head_local
 if nz<knee.z:a,b=ankle,knee
 else:a,b=knee,hip
 t=max(0,min(1,(nz-a.z)/(b.z-a.z)));dest=a.lerp(b,t)
 offset=dest-Vector((side*.082,-.006,nz))
 blend=max(0,min(1,(.91-z)/.15))
 v.co=Vector((x*1.09+offset.x*blend,y*1.06+offset.y*blend,nz))
mesh.materials.clear();mesh.materials.append(cloth_material('pants'))
for f in mesh.polygons:f.material_index=0
transfer(pants,bpy.data.objects['Boss_Tailored_Pants'])
# Exposed arms: evaluate the existing anatomical body, preserving its original weights.
with bpy.data.libraries.load(str(root/'blender_project/club_leader_boss/club_leader_boss_polished.blend'),link=False) as (data_from,data_to):data_to.objects=['ClubLeaderBoss_Base']
body_source=data_to.objects[0];bpy.context.collection.objects.link(body_source)
# Remove rig modifier (rest pose), keep the built-in helper mask.
for mod in list(body_source.modifiers):
 if mod.type=='ARMATURE':body_source.modifiers.remove(mod)
deps=bpy.context.evaluated_depsgraph_get();armmesh=bpy.data.meshes.new_from_object(body_source.evaluated_get(deps),depsgraph=deps)
arms=bpy.data.objects.new('Photo_Boss_Exposed_Arms',armmesh);bpy.context.collection.objects.link(arms)
for g in body_source.vertex_groups:arms.vertex_groups.new(name=g.name)
bm=bmesh.new();bm.from_mesh(armmesh)
bmesh.ops.delete(bm,geom=[f for f in bm.faces if not ((.20<abs(f.calc_center_median().x)<.418 and 1.00<f.calc_center_median().z<1.41) or (abs(f.calc_center_median().x)<.22 and 1.29<f.calc_center_median().z<1.41))],context='FACES')
bmesh.ops.delete(bm,geom=[v for v in bm.verts if not v.link_faces],context='VERTS');bm.normal_update()
for v in bm.verts:
 x,y,z=v.co
 nz=z+.112 if z<1.42 else 1.532+(z-1.42)*.94
 v.co=Vector((x*1.025,y,nz))-v.normal*.0006
bm.to_mesh(armmesh);bm.free();armmesh.materials.clear()
skin=bpy.data.materials.new('Photo_Boss_Arm_Skin');skin.use_nodes=True;p=skin.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(.52,.33,.24,1);p.inputs['Roughness'].default_value=.65
armmesh.materials.append(skin)
for f in armmesh.polygons:f.material_index=0;f.use_smooth=True
arms.parent=rig;arm=arms.modifiers.new('Existing boss arm bones','ARMATURE');arm.object=rig
# Retain original face/hands/hair/shoes, replace only old clothing layers.
for o in list(bpy.data.objects):
 if o in original and (o.name in ['Boss_Tailored_Jacket','Boss_Tailored_Pants','V3_Separate_Cotton_Tshirt'] or o.name.startswith(('V3_Jacket_','V3_Tee_'))):bpy.data.objects.remove(o,do_unlink=True)
keep=set(original)|{shirt,pants,arms}
for o in list(bpy.data.objects):
 if o not in keep:bpy.data.objects.remove(o,do_unlink=True)
for action in list(bpy.data.actions):
 if action not in original_actions:bpy.data.actions.remove(action)
bpy.data.orphans_purge(do_recursive=True)
# Only the existing rig's animations are exported; no Snow rig drivers are executed.
blend=root/'blender_project/club_leader_boss/club_leader_boss_snow_v6.blend';bpy.ops.wm.save_as_mainfile(filepath=str(blend))
bpy.ops.object.select_all(action='DESELECT')
for o in bpy.context.scene.objects:
 if o.type in ['MESH','ARMATURE']:o.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(out/'club_leader_boss_snow_v6.glb'),export_format='GLB',use_selection=True,export_apply=True,export_animations=True,export_animation_mode='ACTIONS')
rig.animation_data.action=bpy.data.actions.get('Boss_Idle');scene.frame_set(0)
scene.render.engine='CYCLES';scene.cycles.samples=24;scene.render.resolution_x=800;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
cam=bpy.data.objects['Preview_Camera'];scene.camera=cam;cam.location=(1.2,-3.15,1.55);cam.rotation_euler=(Vector((0,0,.97))-cam.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(out/'snow_v6_full.png');bpy.ops.render.render(write_still=True)
print('SNOW CLOTHING V6 EXPORTED',flush=True)
