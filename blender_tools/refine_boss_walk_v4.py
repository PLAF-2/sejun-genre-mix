"""V4: proportion pass, genuinely loose trousers, and CMU-recorded walk retarget.
Run against club_leader_boss_motion_v3.blend after prepare_cmu_walk.py.
"""
import bpy,bmesh,math,json,random
import numpy as np
from pathlib import Path
from mathutils import Vector,Quaternion,Matrix
root=Path(__file__).resolve().parents[1];out=root/'godot-game/assets/3d/club_leader_boss'
rig=bpy.data.objects['ClubLeaderBoss_Base.rig'];scene=bpy.context.scene
rig.animation_data_clear()
for a in list(bpy.data.actions):bpy.data.actions.remove(a)
for p in rig.pose.bones:p.rotation_mode='QUATERNION';p.rotation_quaternion=Quaternion();p.location=Vector();p.scale=Vector((1,1,1))
bpy.context.view_layer.update()
# Straight, wide-leg tailoring: expand knee/calf/hem rather than tracking muscle contours.
trousers=bpy.data.objects['Boss_Tailored_Pants']
points=[v.co.copy() for v in trousers.data.vertices]
centers={}
for side in [-1,1]:
 for k in range(34):
  z=.08+k*.025
  group=[v for v in points if side*v.x>0 and abs(v.z-z)<.027]
  if not group:continue
  if z>.69:cx=side*.11
  elif z>.45:cx=side*(.14-(z-.45)/.24*.03)
  else:cx=side*(.18-(z-.08)/.37*.04)
  cy=-.025
  rx=max(.035,float(np.percentile([abs(v.x-cx) for v in group],90)))
  ry=max(.045,float(np.percentile([abs(v.y-cy) for v in group],90)))
  centers[side,k]=(cx,cy,rx,ry)
for v in trousers.data.vertices:
 x,y,z=v.co;side=1 if x>=0 else -1
 k=max(0,min(33,round((z-.08)/.025)));p=centers.get((side,k))
 if not p:continue
 cx,cy,rx,ry=p
 # Preserve the shared crotch/waist; broaden the freely hanging leg sections.
 blend=1-min(1,max(0,(z-.69)/.12))
 targetx=.122 if z<.28 else .127 if z<.58 else .142
 targety=.132 if z<.28 else .138 if z<.58 else .155
 nx=cx+(x-cx)*max(1,targetx/rx);ny=cy+(y-cy)*max(1,targety/ry)
 v.co.x=x+(nx-x)*blend;v.co.y=y+(ny-y)*blend
 angle=math.atan2(v.co.y-cy,v.co.x-cx)
 folds=.004*math.cos(angle*5+z*3)+.006*math.sin(z*92+angle)*math.exp(-((z-.145)/.045)**2)
 v.co.x+=math.cos(angle)*folds*blend;v.co.y+=math.sin(angle)*folds*blend
# Taller leg line + slightly smaller head, while moving all skin/rest joints together.
def map_point(v):
 x,y,z=v
 if z<.10:nz=z
 elif z<.90:nz=.10+(z-.10)*1.14
 elif z<1.42:nz=z+.112
 else:nz=1.532+(z-1.42)*.94
 head=max(0,min(1,(z-1.40)/.06))
 width=(1.025 if z>1.0 else .985)*(1-head)+.94*head
 return Vector((x*width,y*(1-.06*head),nz))
for o in bpy.context.scene.objects:
 if o.type=='MESH':
  inv=o.matrix_world.inverted()
  for v in o.data.vertices:v.co=inv@map_point(o.matrix_world@v.co)
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);bpy.context.view_layer.objects.active=rig
bpy.ops.object.mode_set(mode='EDIT')
for b in rig.data.edit_bones:
 head=map_point(b.head);tail=map_point(b.tail);b.head=head;b.tail=tail
bpy.ops.object.mode_set(mode='OBJECT');bpy.context.view_layer.update()
for obj in bpy.context.scene.objects:
 if obj.type=='MESH':obj.hide_viewport=True
# Reuse only the prior retargeting helpers, not its geometry edits/export entry point.
source=(root/'blender_tools/refine_boss_motion_v3.py').read_text(encoding='utf-8-sig')
helpers=source[source.index('rest={b.name'):source.index('rig.animation_data_create();scene.render.fps=24')]
helpers=helpers.replace('side*.245','side*.251').replace('.88+.003',' .992+.003').replace('side*.18,-.38,1.29','side*.185,-.38,1.402').replace('side*.24,.10,1.02','side*.246,.10,1.132')
exec(helpers,globals());legacy_pose=pose
capture=json.loads((root/'work/cmu_walk_cycle.json').read_text());joints={k:np.array(v) for k,v in capture['joints'].items()};samples=len(joints['root'])
legsource=float(np.mean(np.linalg.norm(joints['lfemur']-joints['lhipjoint'],axis=1)+np.linalg.norm(joints['ltibia']-joints['lfemur'],axis=1)))
legdest=sum(lengths[('upperleg01.L','lowerleg01.L','foot.L')]);legscale=legdest/legsource
armsource=float(np.mean(np.linalg.norm(joints['lhumerus']-joints['lclavicle'],axis=1)+np.linalg.norm(joints['lradius']-joints['lhumerus'],axis=1)))
armscale=sum(lengths[('upperarm01.L','lowerarm01.L','wrist.L')])/armsource
rootmean=np.mean(joints['root'],axis=0)
hipmean=np.mean((joints['lhipjoint']+joints['rhipjoint'])*.5,axis=0)
hipdest=(rest['upperleg01.L'].translation+rest['upperleg01.R'].translation)*.5
anklemin={side:float(np.percentile(joints[side+'tibia'][:,2],5)) for side in ['l','r']}
neutral={}
for side in ['l','r']:
 vec=joints[side+'toes']-joints[side+'tibia'];angles=np.arctan2(vec[:,2],-vec[:,1]);neutral[side]=float(np.median(angles[joints[side+'tibia'][:,2]<anklemin[side]+.020]))
def sample(name,t):
 f=min(samples-1,max(0,t*(samples-1)));i=int(f);a=f-i
 return Vector(joints[name][i]*(1-a)+joints[name][min(i+1,samples-1)]*a)
def mocap_pose(t):
 reset();srcroot=sample('root',t);feet={};rolls={}
 for tag,side,code in [('L',1,'l'),('R',-1,'r')]:
  ankle=sample(code+'tibia',t);toe=sample(code+'toes',t);v=toe-ankle
  pitch=math.atan2(v.z,-v.y)-neutral[code];roll=-max(-.30,min(.48,pitch));rolls[tag]=roll
  # Widen only the stance, not the measured forward/back timing of the captured gait.
  x=(ankle.x-hipmean[0])*legscale+hipdest.x+side*.037
  y=(ankle.y-hipmean[1])*legscale+hipdest.y
  z=rest['foot.'+tag].translation.z+(ankle.z-anklemin[code])*legscale
  q=Quaternion((1,0,0),roll)
  lowest=min((q@Vector((0,.065,-.068))).z,(q@Vector((0,-.20,-.060))).z)
  z=max(z,-lowest+.002)
  feet[tag]=Vector((x,y,z))
 # Recorded hip sway/bob, bounded by leg reach so the support foot cannot float.
 srchip=(sample('lhipjoint',t)+sample('rhipjoint',t))*.5
 flooroffset=(rest['foot.L'].translation.z+rest['foot.R'].translation.z)*.5-(anklemin['l']+anklemin['r'])*.5*legscale
 shift=Vector(((srchip.x-hipmean[0])*legscale,(srchip.y-hipmean[1])*legscale,srchip.z*legscale+flooroffset-hipdest.z))
 for tag in ['L','R']:
  hip=rest['upperleg01.'+tag].translation+shift;foot=feet[tag]
  horizontal=(Vector((hip.x,hip.y,0))-Vector((foot.x,foot.y,0))).length
  reach=sum(lengths[('upperleg01.'+tag,'lowerleg01.'+tag,'foot.'+tag)])-.004
  maxz=foot.z+math.sqrt(max(.005,reach*reach-horizontal*horizontal))
  if hip.z>maxz:shift.z-=hip.z-maxz
 pb=rig.pose.bones['root'];m=pb.matrix.copy();m.translation+=shift;pb.matrix=m;update()
 shoulder=sample('lclavicle',t)-sample('rclavicle',t)
 hips=sample('lhipjoint',t)-sample('rhipjoint',t)
 chesttwist=max(-.10,min(.10,math.atan2(shoulder.y,shoulder.x)))
 hipstwist=max(-.08,min(.08,math.atan2(hips.y,hips.x)))
 rig.pose.bones['spine03'].rotation_quaternion=Quaternion((0,0,1),hipstwist*.45)
 rig.pose.bones['spine01'].rotation_quaternion=Quaternion((0,0,1),chesttwist-hipstwist*.45)
 rig.pose.bones['head'].rotation_quaternion=Quaternion((0,0,1),-chesttwist*.45)
 update()
 for tag,side,code in [('L',1,'l'),('R',-1,'r')]:
  ik(['upperleg01.'+tag,'lowerleg01.'+tag,'foot.'+tag],feet[tag],(side*.08,-1,0))
  orient_world('foot.'+tag,Quaternion((1,0,0),rolls[tag])@rest['foot.'+tag].to_quaternion())
  shoulder=rig.pose.bones['upperarm01.'+tag].matrix.translation.copy()
  arm=(sample(code+'radius',t)-sample(code+'clavicle',t))*armscale
  hand=shoulder+arm;hand.x+=side*.015
  elbow=(sample(code+'humerus',t)-sample(code+'clavicle',t)).normalized()
  ik(['upperarm01.'+tag,'lowerarm01.'+tag,'wrist.'+tag],hand,elbow)
  wrist=rig.pose.bones['wrist.'+tag].matrix.translation.copy()
  aim('wrist.'+tag,'finger3-1.'+tag,wrist+Vector((side*.04,-.08,-1)))
  for finger in range(1,6):
   for joint in range(1,4):
    pb=rig.pose.bones.get('finger%d-%d.%s'%(finger,joint,tag))
    if pb:pb.rotation_quaternion=Quaternion((1,0,0),.10 if finger==1 else .18)
 update()
def pose(kind,t):
 if kind=='Walk':mocap_pose(t)
 else:legacy_pose(kind,t)
rig.animation_data_create();scene.render.fps=30
for kind,length in [('Idle',2.0),('Walk',capture['duration']),('StrafeLeft',.9),('StrafeRight',.9),('Cast',.85),('Dash',1.0)]:
 action=bpy.data.actions.new('Boss_'+kind);rig.animation_data.action=action;action.use_fake_user=True
 frames=round(length*30);scene.frame_start=0;scene.frame_end=frames
 for f in range(frames+1):
  scene.frame_set(f);pose(kind,f/frames)
  for pb in rig.pose.bones:
   pb.keyframe_insert(data_path='rotation_quaternion',frame=f,group=pb.name)
   if pb.name=='root':pb.keyframe_insert(data_path='location',frame=f,group=pb.name)
 print('V4 BAKED',kind,frames,flush=True)
rig.animation_data.action=None;reset();scene.frame_start=0;scene.frame_end=60
for obj in bpy.context.scene.objects:
 if obj.type=='MESH':obj.hide_viewport=False
# Put measured root-space walk velocity alongside the asset for runtime speed matching.
metadata={'source':'CMU 07_01','cycle_frames':[capture['start'],capture['end']],'duration':capture['duration'],'source_speed_mps':capture['speed'],'retarget_leg_scale':legscale,'godot_walk_speed':capture['speed']*legscale*3.05,'head_scale':.94,'leg_length_scale':1.14}
(out/'MOTION_V4_METADATA.json').write_text(json.dumps(metadata,indent=2),encoding='utf-8')
blend=root/'blender_project/club_leader_boss/club_leader_boss_motion_v4.blend';bpy.ops.wm.save_as_mainfile(filepath=str(blend))
bpy.ops.object.select_all(action='DESELECT')
for o in bpy.context.scene.objects:
 if o.type in ['MESH','ARMATURE']:o.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(out/'club_leader_boss_motion_v4.glb'),export_format='GLB',use_selection=True,export_apply=True,export_animations=True,export_animation_mode='ACTIONS')
scene.render.engine='CYCLES';scene.cycles.samples=24;scene.render.resolution_x=800;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
cam=bpy.data.objects['Preview_Camera'];scene.camera=cam
for name,t in [('motion_v4_full',0),('motion_v4_walk',.3)]:
 pose('Idle' if t==0 else 'Walk',t);cam.location=(1.2,-3.15,1.55);cam.rotation_euler=(Vector((0,0,.97))-cam.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(out/(name+'.png'));bpy.ops.render.render(write_still=True)
print('MOTION V4 EXPORTED',metadata,flush=True)
