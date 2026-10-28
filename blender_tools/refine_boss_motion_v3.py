"""Versioned motion + wardrobe refinement. Run on rebuilt_v2.blend."""
import bpy,bmesh,math,random
from pathlib import Path
from mathutils import Vector,Quaternion,Matrix
root=Path(__file__).resolve().parents[1];out=root/'godot-game/assets/3d/club_leader_boss'
rig=bpy.data.objects['ClubLeaderBoss_Base.rig'];scene=bpy.context.scene
rig.animation_data_clear()
for p in rig.pose.bones:p.rotation_mode='QUATERNION';p.rotation_quaternion=Quaternion();p.location=Vector();p.scale=Vector((1,1,1))
bpy.context.view_layer.update()

def material(name,color,rough=.7):
 m=bpy.data.materials.new(name);m.use_nodes=True;m.diffuse_color=(*color,1)
 p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Roughness'].default_value=rough
 return m
inner=material('V3_Cotton_Tee',(.012,.016,.022),.92)
edge=material('V3_Fabric_Binding',(.018,.024,.033),.78)
stitch=material('V3_Stitch',(.07,.083,.10),.8)
zipmat=material('V3_Brushed_Zipper',(.12,.14,.17),.42);zipmat.node_tree.nodes.get('Principled BSDF').inputs['Metallic'].default_value=.65

def activate(o):
 bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o

def attach(o,bone):
 if o.type=='CURVE':activate(o);bpy.ops.object.convert(target='MESH');o=bpy.context.object
 o.parent=rig;g=o.vertex_groups.new(name=bone);g.add(list(range(len(o.data.vertices))),1,'REPLACE')
 a=o.modifiers.new('Deform with character','ARMATURE');a.object=rig
 for p in o.data.polygons:p.use_smooth=True
 return o

def curve(name,pts,radius,mat,bone,closed=False):
 d=bpy.data.curves.new(name,'CURVE');d.dimensions='3D';d.bevel_depth=radius;d.bevel_resolution=2;d.resolution_u=10
 s=d.splines.new('BEZIER');s.bezier_points.add(len(pts)-1);s.use_cyclic_u=closed
 for p,co in zip(s.bezier_points,pts):p.co=co;p.handle_left_type='AUTO';p.handle_right_type='AUTO'
 o=bpy.data.objects.new(name,d);bpy.context.collection.objects.link(o);d.materials.append(mat);return attach(o,bone)

def meshpart(name,vs,fs,mat,bone):
 d=bpy.data.meshes.new(name);d.from_pydata(vs,[],fs);d.update();o=bpy.data.objects.new(name,d);bpy.context.collection.objects.link(o);d.materials.append(mat);return attach(o,bone)

# Build an inner cotton layer from the closed V2 garment before opening the jacket.
jacket=bpy.data.objects['Boss_Tailored_Jacket']
shirt=bpy.data.objects.new('V3_Separate_Cotton_Tshirt',jacket.data.copy());bpy.context.collection.objects.link(shirt);shirt.parent=rig
for g in jacket.vertex_groups:shirt.vertex_groups.new(name=g.name)
bm=bmesh.new();bm.from_mesh(shirt.data)
bmesh.ops.delete(bm,geom=[f for f in bm.faces if not (.85<f.calc_center_median().z<1.40 and abs(f.calc_center_median().x)<.19)],context='FACES')
bmesh.ops.delete(bm,geom=[v for v in bm.verts if not v.link_faces],context='VERTS')
for v in bm.verts:v.co.x*=.95;v.co.y*=.94
bm.to_mesh(shirt.data);bm.free();shirt.data.materials.clear();shirt.data.materials.append(inner)
for f in shirt.data.polygons:f.material_index=0;f.use_smooth=True
solid=shirt.modifiers.new('Cotton edge thickness','SOLIDIFY');solid.thickness=.002
arm=shirt.modifiers.new('Same body skeleton','ARMATURE');arm.object=rig
# Open outer jacket, relax the silhouette and sculpt coherent elbow/waist folds.
for mod in jacket.modifiers:
 if mod.type=='SOLIDIFY':mod.thickness=.006
bm=bmesh.new();bm.from_mesh(jacket.data)
bmesh.ops.delete(bm,geom=[f for f in bm.faces if abs(f.calc_center_median().x)<.013 and f.calc_center_median().y<-.065],context='FACES')
bmesh.ops.delete(bm,geom=[v for v in bm.verts if not v.link_faces],context='VERTS')
bm.normal_update()
for v in bm.verts:
 x,y,z=v.co;normal=v.normal.copy()
 waist=math.exp(-((z-.97)/.17)**2);elbow=math.exp(-((abs(x)-.34)/.07)**2-((z-1.15)/.11)**2)
 v.co+=normal*(.010+.008*waist+.003*math.sin(z*72+x*14)*waist+.004*math.sin(z*115)*elbow)
 if abs(x)<.24 and z<.94:v.co.z-=.045*max(0,min(1,(.94-z)/.11))
 if y<-.065 and abs(x)<.04:v.co.x+=math.copysign(.010,x or 1);v.co.y-=.004
bm.to_mesh(jacket.data);bm.free()
# Remove the old painted-on zipper/seam; both open panels get their own bound edge.
for name in ['Jacket_Front_Zip','Neckline_Finished_Seam','Boss_Folded_Collar_-1','Boss_Folded_Collar_1','Chest_Welt_-1','Chest_Welt_1','Pocket_Zip_-1','Pocket_Zip_1']:
 o=bpy.data.objects.get(name)
 if o:bpy.data.objects.remove(o,do_unlink=True)
for side in [-1,1]:
 pts=[(side*.026,-.125,.805),(side*.026,-.16,1.01),(side*.027,-.177,1.20),(side*.025,-.135,1.375)]
 curve('V3_Jacket_Zip_Edge_'+str(side),pts,.0022,zipmat,'spine02')
 # Turned-out collar is a thick folded cloth surface, distinct from skin and shirt.
 collar=meshpart('V3_Jacket_Lapel_'+str(side),[(side*.022,-.137,1.372),(side*.045,-.107,1.412),(side*.090,-.101,1.389),(side*.085,-.146,1.332)],[(0,1,2,3)],edge,'spine01')
 solid=collar.modifiers.new('Folded collar thickness','SOLIDIFY');solid.thickness=.006
 bevel=collar.modifiers.new('Cloth edge rounding','BEVEL');bevel.width=.003;bevel.segments=3
 curve('V3_Jacket_Pocket_Welt_'+str(side),[(side*.09,-.159,.99),(side*.148,-.138,1.045)],.0035,edge,'spine03')
 curve('V3_Jacket_Chest_Stitch_'+str(side),[(side*.05,-.159,1.275),(side*.13,-.146,1.265)],.0009,stitch,'spine01')
for obj in bpy.context.scene.objects:
 if obj.name.startswith('V3_Jacket_Zip_Edge_'):
  obj.vertex_groups.clear()
  for bone in ['spine01','spine02','spine03']:obj.vertex_groups.new(name=bone)
  for v in obj.data.vertices:
   z=v.co.z
   high=max(0,min(1,(z-1.16)/.13));low=max(0,min(1,(1.12-z)/.17));mid=max(0,1-high-low)
   for name,w in [('spine01',high),('spine02',mid),('spine03',low)]:
    if w>0:obj.vertex_groups[name].add([v.index],w,'REPLACE')
# A separate close-fitting neck rib clearly reveals the shirt behind the collar.
curve('V3_Tee_Neck_Rib',[(.056*math.cos(i*math.tau/32),-.029+.060*math.sin(i*math.tau/32),1.385) for i in range(32)],.003,inner,'spine01',True)
# Soften the face silhouette slightly and define cheek/chin planes without changing identity.
face=bpy.data.objects['Boss_PhotoGuided_Face_And_Hands']
for v in face.data.vertices:
 x,y,z=v.co
 if z>1.43:
  jaw=math.exp(-((z-1.465)/.040)**2)
  v.co.x*=1-.018*jaw
  if y<-.08:v.co.y-=.0013*math.exp(-(x/.035)**2-((z-1.448)/.016)**2)
for o in bpy.data.objects:
 if o.name.startswith('Eye_Anatomical_'):
  for v in o.data.vertices:v.co.z*=1.08
# Relax trouser silhouette; broad folds stop it reading like a painted body.
trousers=bpy.data.objects['Boss_Tailored_Pants']
for v in trousers.data.vertices:
 n=v.normal.copy();z=v.co.z
 v.co+=n*(.008+.003*math.sin(z*70)*math.exp(-((z-.46)/.10)**2))
# Layered, closed hair locks wrap the sides and crown; the old cap is only the inner mass.
cap=bpy.data.objects['Boss_Sculpted_Hair_Silhouette']
for v in cap.data.vertices:
 x,y,z=v.co;az=math.atan2(y+.008,x)
 v.co.x*=1+.012*math.sin(az*7+z*23)
 v.co.z+=.002*math.sin(az*5)*max(0,(z-1.58)/.1)
hair=[bpy.data.materials.get('Hair_Ink_'+str(i)) for i in range(4)]
rng=random.Random(203)
for k in range(42):
 az=k/42*math.tau
 if math.sin(az)<-.6:continue # Existing fringe remains, add crown/sides/back volume.
 theta0=.18+rng.random()*.22;theta1=1.9+rng.random()*.25
 vs=[];fs=[]
 for i in range(13):
  t=i/12;theta=theta0+(theta1-theta0)*t
  a=az+.15*math.sin(t*math.pi)+rng.uniform(-.008,.008)
  ry=.143 if math.sin(a)<0 else .103
  center=Vector((.110*math.sin(theta)*math.cos(a),-.008+ry*math.sin(theta)*math.sin(a),1.566+.117*math.cos(theta)))
  outward=Vector((math.cos(a),math.sin(a),.32*math.cos(theta))).normalized()
  tangent=Vector((-math.sin(a),math.cos(a),0))
  width=(.007+rng.random()*.002)*(math.sin(math.pi*t)**.45)+.00015
  depth=.0045*(math.sin(math.pi*t)**.65)+.0002
  center+=outward*(.003+math.sin(math.pi*t)*.005)
  for j in range(8):
   ang=j/8*math.tau;vs.append(tuple(center+tangent*math.cos(ang)*width+outward*math.sin(ang)*depth))
 for i in range(12):
  for j in range(8):fs.append((i*8+j,i*8+(j+1)%8,(i+1)*8+(j+1)%8,(i+1)*8+j))
 lock=meshpart('V3_Hair_Volume_%02d'%k,vs,fs,hair[k%4],'head')
# UVs for new surfaces, ready for standard GLB materials.
for o in bpy.context.scene.objects:
 if o.type=='MESH' and not o.data.uv_layers:
  activate(o);bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(island_margin=.02);bpy.ops.object.mode_set(mode='OBJECT')

# Bake artist-authored planted-foot motion via two-segment IK to the original deform rig.
# Solving the real joint-to-joint direction avoids relying on MPFB helper-bone axes.
rest={b.name:b.matrix_local.copy() for b in rig.data.bones}
lengths={}
for tag in ['L','R']:
 for chain in [('upperarm01.','lowerarm01.','wrist.'),('upperleg01.','lowerleg01.','foot.')]:
  names=[x+tag for x in chain];ps=[rest[x].translation for x in names];lengths[tuple(names)]=((ps[1]-ps[0]).length,(ps[2]-ps[1]).length)

def update():bpy.context.view_layer.update()
def reset():
 for p in rig.pose.bones:p.rotation_quaternion=Quaternion();p.location=Vector();p.scale=Vector((1,1,1))
 update()
def orient_world(name,quat):
 p=rig.pose.bones[name];m=quat.to_matrix().to_4x4();m.translation=p.matrix.translation.copy();p.matrix=m;update()
def aim(name,child,target):
 p=rig.pose.bones[name];a=p.matrix.translation.copy();cur=rig.pose.bones[child].matrix.translation-a
 desired=Vector(target)-a
 if cur.length<1e-6 or desired.length<1e-6:return
 q=cur.normalized().rotation_difference(desired.normalized());orient_world(name,q@p.matrix.to_quaternion())
def ik(names,target,hint):
 a,b,c=names;p=rig.pose.bones[a].matrix.translation.copy();target=Vector(target)
 l1,l2=lengths[tuple(names)];d=target-p;length=max(.005,min(d.length,l1+l2-.002));u=d.normalized()
 pole=Vector(hint);v=pole-u*pole.dot(u)
 if v.length<.001:v=Vector((1,0,0)).cross(u)
 v.normalize();along=(l1*l1-l2*l2+length*length)/(2*length);height=math.sqrt(max(0,l1*l1-along*along))
 elbow=p+u*along+v*height
 aim(a,b,elbow);aim(b,c,p+u*length)

def smooth(a,b,t):
 t=max(0,min(1,(t-a)/(b-a)));return t*t*(3-2*t)
def pose(kind,t):
 reset();cycle=t*math.tau
 walking=kind in ['Walk','StrafeLeft','StrafeRight']
 body=rig.pose.bones['root'];m=body.matrix.copy();m.translation+=Vector((.008*math.sin(cycle) if walking else .002*math.sin(cycle),0,-.016+(.006*math.cos(cycle*2) if walking else .002*math.sin(cycle))))
 body.matrix=m;update()
 cast=(smooth(.10,.43,t)*(1-smooth(.60,1,t))) if kind=='Cast' else 0
 dash=math.sin(t*math.pi) if kind=='Dash' else 0
 # Chest and head lead the motion, with a smaller delayed head response.
 rig.pose.bones['spine01'].rotation_quaternion=Quaternion((1,0,0),.025*math.sin(cycle)-cast*.13-dash*.24)
 rig.pose.bones['spine02'].rotation_quaternion=Quaternion((0,1,0),.020*math.sin(cycle) if walking else .006*math.sin(cycle))
 rig.pose.bones['head'].rotation_quaternion=Quaternion((0,1,0),.018*math.sin(cycle-.35))
 update()
 for tag,side,offset in [('L',1,0),('R',-1,.5)]:
  p=(t+offset)%1
  fy=0;fx=side*.16 if kind in ['StrafeLeft','StrafeRight'] else side*.11;fz=.069
  if walking:
   if p<.60:travel=-.19+.38*(p/.60);lift=0
   else:
    swing=(p-.60)/.40;travel=.19-.38*smooth(0,1,swing);lift=math.sin(swing*math.pi)*.085
   if kind=='Walk':fy=travel
   else:fx+=travel*(1 if kind=='StrafeLeft' else -1)*.8
   fz+=lift
  else:fx=side*.12;fy=-.015
  if kind=='Cast':fy=side*.02;fz=.069
  if kind=='Dash':fy=side*.08;fx=side*.12
  ik(['upperleg01.'+tag,'lowerleg01.'+tag,'foot.'+tag],(fx,fy,fz),(side*.12,-1,0))
  orient_world('foot.'+tag,rest['foot.'+tag].to_quaternion())
  # Hands hang at the sides in idle, counter-swing during locomotion, gather then release.
  hand=Vector((side*.245,-.035+(.09*math.sin(cycle+offset*math.tau) if walking else .006*math.sin(cycle)),.88+.003*math.sin(cycle)))
  if cast>0:hand=hand.lerp(Vector((side*.18,-.38,1.29)),cast)
  if dash>0:hand=hand.lerp(Vector((side*.24,.10,1.02)),dash)
  ik(['upperarm01.'+tag,'lowerarm01.'+tag,'wrist.'+tag],hand,(side*.2,.55,-.15))
  wrist=rig.pose.bones['wrist.'+tag].matrix.translation.copy()
  fingers=Vector((side*.04,-.08,-1)).lerp(Vector((side*.12,-1,.1)),cast)
  aim('wrist.'+tag,'finger3-1.'+tag,wrist+fingers)
  # Slightly curled relaxed fingers; avoid the old rigid spread hands.
  for finger in range(1,6):
   for joint in range(1,4):
    pb=rig.pose.bones.get('finger%d-%d.%s'%(finger,joint,tag))
    if pb:pb.rotation_quaternion=Quaternion((1,0,0),(.10 if finger==1 else .22)+cast*.1)
 update()

rig.animation_data_create();scene.render.fps=24
for kind,length in [('Idle',2.0),('Walk',.9),('StrafeLeft',.9),('StrafeRight',.9),('Cast',.85),('Dash',1.0)]:
 action=bpy.data.actions.new('Boss_'+kind);rig.animation_data.action=action;action.use_fake_user=True
 frames=round(length*24);scene.frame_start=0;scene.frame_end=frames
 for f in range(frames+1):
  scene.frame_set(f);pose(kind,f/frames)
  for pb in rig.pose.bones:
   pb.keyframe_insert(data_path='rotation_quaternion',frame=f,group=pb.name)
   if pb.name=='root':pb.keyframe_insert(data_path='location',frame=f,group=pb.name)
 print('BAKED',kind,frames,flush=True)
rig.animation_data.action=None;reset();scene.frame_start=0;scene.frame_end=48
blend=root/'blender_project/club_leader_boss/club_leader_boss_motion_v3.blend';bpy.ops.wm.save_as_mainfile(filepath=str(blend))
bpy.ops.object.select_all(action='DESELECT')
for o in bpy.context.scene.objects:
 if o.type in ['MESH','ARMATURE']:o.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(out/'club_leader_boss_motion_v3.glb'),export_format='GLB',use_selection=True,export_apply=True,export_animations=True,export_animation_mode='ACTIONS')
scene.render.engine='CYCLES';scene.cycles.samples=24;scene.render.resolution_x=800;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
cam=bpy.data.objects['Preview_Camera'];scene.camera=cam
for name,at,target,kind,t in [('motion_v3_full',(1.2,-3,1.5),(0,0,.9),'Idle',0),('motion_v3_face',(.13,-.82,1.59),(0,-.04,1.55),'Idle',0),('motion_v3_walk',(1.2,-3,1.5),(0,0,.9),'Walk',.22),('motion_v3_cast',(1.2,-3,1.5),(0,0,.9),'Cast',.45)]:
 pose(kind,t);cam.location=at;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(out/(name+'.png'));bpy.ops.render.render(write_still=True)
print('MOTION V3 EXPORTED',flush=True)
