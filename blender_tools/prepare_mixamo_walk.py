import bpy,json,math
from mathutils import Vector
from pathlib import Path
import numpy as np
root=Path(__file__).resolve().parents[1]
bpy.ops.import_scene.fbx(filepath=str(root/'blender_project/motion_sources/mixamo/Walking.fbx'))
rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE');scene=bpy.context.scene
start,end=map(int,rig.animation_data.action.frame_range);fps=scene.render.fps
aliases={'root':'Hips','lhipjoint':'LeftUpLeg','rhipjoint':'RightUpLeg','lfemur':'LeftLeg','rfemur':'RightLeg','ltibia':'LeftFoot','rtibia':'RightFoot','ltoes':'LeftToeBase','rtoes':'RightToeBase','lclavicle':'LeftArm','rclavicle':'RightArm','lhumerus':'LeftForeArm','rhumerus':'RightForeArm','lradius':'LeftHand','rradius':'RightHand'}
def bone(name):return next(b for b in rig.pose.bones if b.name.split(':')[-1]==name)
poses=[]
for frame in range(start,end+1):
 scene.frame_set(frame);bpy.context.view_layer.update();poses.append({k:np.array(rig.matrix_world@bone(name).matrix.translation) for k,name in aliases.items()})
roots=np.array([p['root'] for p in poses]);forward=roots[-1]-roots[0];forward[2]=0
speed=np.linalg.norm(forward)/((end-start)/fps);forward/=np.linalg.norm(forward);right=np.cross(np.array([0,0,1]),forward);B=np.array([right,-forward,[0,0,1]])
line=np.linspace(roots[0],roots[-1],len(poses));line[:,2]=0
arrays={k:np.array([B@(p[k]-line[i]) for i,p in enumerate(poses)]) for k in aliases}
floor=float(np.percentile(np.concatenate([arrays['ltoes'][:,2],arrays['rtoes'][:,2]]),5))
for k,v in arrays.items():v[:,2]-=floor;v-=np.linspace(0,1,len(v))[:,None]*(v[-1]-v[0])
(root/'work/mixamo_walk_cycle.json').write_text(json.dumps({'fps':fps,'start':start,'end':end,'duration':(end-start)/fps,'speed':float(speed),'joints':{k:v.tolist() for k,v in arrays.items()}}),encoding='utf-8')
print('MIXAMO WALK CAPTURE',start,end,fps,speed,flush=True)
