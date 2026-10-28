"""V5 normal clothing: rebuild garment envelopes without anatomical bulges.
The body/face and captured animations stay unchanged; clothes remain separate skinned meshes.
"""
import bpy,bmesh,math
from pathlib import Path
from mathutils import Vector,Quaternion
root=Path(__file__).resolve().parents[1];out=root/'godot-game/assets/3d/club_leader_boss'
rig=bpy.data.objects['ClubLeaderBoss_Base.rig'];scene=bpy.context.scene
rig.animation_data.action=None
for pb in rig.pose.bones:pb.rotation_mode='QUATERNION';pb.rotation_quaternion=Quaternion();pb.location=Vector();pb.scale=Vector((1,1,1))
bpy.context.view_layer.update()
def mix(a,b,t):return a*(1-t)+b*t
def profile(z):
 keys=[(.90,-.137),(1.10,-.165),(1.35,-.173),(1.52,-.120)]
 if z<=keys[0][0]:return keys[0][1]
 for (a,x),(b,y) in zip(keys,keys[1:]):
  if z<=b:return mix(x,y,(z-a)/(b-a))
 return keys[-1][1]
# Straight-leg slacks: project onto a new relaxed pattern instead of retaining muscle bulges.
pants=bpy.data.objects['Boss_Tailored_Pants']
for v in pants.data.vertices:
 x,y,z=v.co;side='L' if x>=0 else 'R'
 hip=rig.data.bones['upperleg01.'+side].head_local;knee=rig.data.bones['lowerleg01.'+side].head_local;ankle=rig.data.bones['foot.'+side].head_local
 a,b=(ankle,knee) if z<knee.z else (knee,hip)
 t=max(0,min(1,(z-a.z)/(b.z-a.z)));center=a.lerp(b,t)
 dx=x-center.x;dy=y-center.y;angle=math.atan2(dy/.145,dx/.13)
 high=max(0,min(1,(z-knee.z)/(hip.z-knee.z)))
 rx=.102+.011*high;ry=.117+.010*high
 # Restrained vertical drape, no rings of knee/calf stuffing.
 crease=.0014*math.cos(angle*4)+.0012*math.sin(z*26+angle*2)
 nx=center.x+(rx+crease)*math.cos(angle);ny=center.y+(ry+crease)*math.sin(angle)
 blend=max(0,min(1,(hip.z-.025-z)/.085))
 v.co.x=mix(x,nx,blend);v.co.y=mix(y,ny,blend)
# Light, plain jacket: flatten front panels and relax sleeve tubes around the actual arm axis.
jacket=bpy.data.objects['Boss_Tailored_Jacket']
for v in jacket.data.vertices:
 p=v.co.copy();x,y,z=p
 if abs(x)<.205 and y<-.075:
  target=profile(z)+.4*x*x+.0015*math.sin(z*35+x*4)
  v.co.y=mix(y,target,.86)
 elif abs(x)>.215:
  tag='L' if x>0 else 'R'
  shoulder=rig.data.bones['upperarm01.'+tag].head_local;elbow=rig.data.bones['lowerarm01.'+tag].head_local;wrist=rig.data.bones['wrist.'+tag].head_local
  candidates=[]
  for idx,(a,b) in enumerate([(shoulder,elbow),(elbow,wrist)]):
   axis=b-a;t=max(0,min(1,(p-a).dot(axis)/axis.length_squared));center=a+axis*t;candidates.append(((p-center).length,idx,t,center))
  _,idx,t,center=min(candidates,key=lambda c:c[0]);radial=p-center
  radius=(.078-.010*t) if idx==0 else (.066-.012*t)
  radius+=.0013*math.sin(t*23)*math.exp(-((t-(.9 if idx==0 else .12))/.2)**2)
  if radial.length>.001:
   blend=max(0,min(1,(abs(x)-.215)/.055));v.co=p.lerp(center+radial.normalized()*radius,blend*.8)
bm=bmesh.new();bm.from_mesh(jacket.data)
bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),dist=.00001,plane_co=(0,0,.925),plane_no=(0,0,1),clear_inner=True,clear_outer=False)
bmesh.ops.delete(bm,geom=[v for v in bm.verts if not v.link_faces],context='VERTS')
bm.to_mesh(jacket.data);bm.free()
for o in bpy.data.objects:
 if o.type=='MESH' and o.name.startswith('V3_Jacket_Zip_Edge_'):
  for v in o.data.vertices:v.co.z=max(v.co.z,.925);v.co.y=profile(v.co.z)+.4*v.co.x*v.co.x-.003
# Matte woven shades instead of bright, smooth padded-looking panels.
for o,color,rough in [(jacket,(.014,.019,.026),.86),(pants,(.018,.023,.031),.88)]:
 for material in o.data.materials:
  if material and material.use_nodes:
   p=material.node_tree.nodes.get('Principled BSDF')
   p.inputs['Base Color'].default_value=(*color,1);p.inputs['Roughness'].default_value=rough;p.inputs['Specular IOR Level'].default_value=.23
   material.diffuse_color=(*color,1)
# Use the captured idle for source preview, but export all existing animation actions.
blend=root/'blender_project/club_leader_boss/club_leader_boss_clothes_v5.blend';bpy.ops.wm.save_as_mainfile(filepath=str(blend))
bpy.ops.object.select_all(action='DESELECT')
for o in bpy.context.scene.objects:
 if o.type in ['MESH','ARMATURE']:o.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(out/'club_leader_boss_clothes_v5.glb'),export_format='GLB',use_selection=True,export_apply=True,export_animations=True,export_animation_mode='ACTIONS')
action=bpy.data.actions.get('Boss_Idle');rig.animation_data.action=action;scene.frame_set(0)
scene.render.engine='CYCLES';scene.cycles.samples=24;scene.render.resolution_x=800;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
cam=bpy.data.objects['Preview_Camera'];scene.camera=cam;cam.location=(1.2,-3.15,1.55);cam.rotation_euler=(Vector((0,0,.97))-cam.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(out/'clothes_v5_full.png');bpy.ops.render.render(write_still=True)
print('CLOTHING V5 EXPORTED',flush=True)
