"""Small ASF/AMC FK reader for the explicitly downloaded CMU walking take."""
import numpy as np,json
from pathlib import Path
from scipy.spatial.transform import Rotation
from scipy.signal import savgol_filter,find_peaks
root=Path(__file__).resolve().parents[1];src=root/'blender_project/motion_sources/cmu_07'
lines=(src/'07.asf').read_text().splitlines();bones={};hier={};mode='';b=None
for raw in lines:
 p=raw.split()
 if not p:continue
 if p[0].startswith(':'):mode=p[0];continue
 if mode==':bonedata':
  if p[0]=='begin':b={}
  elif p[0]=='end':bones[b['name']]=b;b=None
  elif b is not None:
   if p[0]=='name':b['name']=p[1]
   elif p[0] in ['direction','axis']:b[p[0]]=list(map(float,p[1:4]))
   elif p[0]=='length':b['length']=float(p[1])
   elif p[0]=='dof':b['dof']=p[1:]
 elif mode==':hierarchy' and p[0] not in ['begin','end']:hier[p[0]]=p[1:]
frames=[];frame=None
for raw in (src/'07_01.amc').read_text().splitlines():
 p=raw.split()
 if not p or p[0].startswith(('#',':')):continue
 if p[0].isdigit():
  if frame:frames.append(frame)
  frame={}
 else:frame[p[0]]=list(map(float,p[1:]))
if frame:frames.append(frame)
C={name:Rotation.from_euler('xyz',b['axis'],degrees=True).as_matrix() for name,b in bones.items()}
scale=.0254/.45
result=[]
for frame in frames:
 rootp=np.array(frame['root'][:3])*scale;rootrot=Rotation.from_euler('xyz',frame['root'][3:6],degrees=True).as_matrix()
 pos={'root':rootp};rot={'root':rootrot}
 def walk(parent):
  for name in hier.get(parent,[]):
   b=bones[name];v=dict(zip(b.get('dof',[]),frame.get(name,[])));angles=[v.get('r'+axis,0) for axis in 'xyz']
   R=C[name]@Rotation.from_euler('xyz',angles,degrees=True).as_matrix()@C[name].T
   rot[name]=rot[parent]@R;pos[name]=pos[parent]+rot[name]@np.array(b['direction'])*b['length']*scale
   walk(name)
 walk('root');result.append(pos)
# Align average travel with the character's front and remove root horizontal travel.
roots=np.array([p['root'] for p in result]);forward=roots[-1]-roots[0];forward[1]=0;forward/=np.linalg.norm(forward)
right=np.cross(np.array([0,1,0]),forward);B=np.array([right,-forward,[0,1,0]])
names=list(result[0]);arrays={name:np.array([B@(p[name]-np.array([p['root'][0],0,p['root'][2]])) for p in result]) for name in names}
for name in names:arrays[name]=savgol_filter(arrays[name],11,2,axis=0)
floor=float(np.percentile(np.concatenate([arrays['ltoes'][:,2],arrays['rtoes'][:,2]]),5))
for name in names:arrays[name][:,2]-=floor
# Pick two consecutive equal-phase left ankle forward maxima well inside the take.
peaks,_=find_peaks(-arrays['ltibia'][:,1],distance=65,prominence=.08)
print('FRAMES',len(frames),'PEAKS',peaks.tolist(),'FLOOR',floor,'ROOT HEIGHT',np.mean(arrays['root'][:,2]),flush=True)
print('JOINTS',names,flush=True)
start,end=(int(peaks[1]),int(peaks[2])) if len(peaks)>2 else ((int(peaks[0]),int(peaks[1])) if len(peaks)>1 else (80,200))
# Correct small endpoint drift without flattening the actual gait rhythm.
data={}
line=np.linspace(roots[start],roots[end],end-start+1);line[:,1]=0
residual=np.array([B@(roots[start+i]-line[i]) for i in range(len(line))]);residual[:,2]=0
residual[:,0]-=residual[0,0];residual[:,1]-=residual[0,1]
for name in names:
 v=arrays[name][start:end+1].copy()+residual;drift=v[-1]-v[0];v-=np.linspace(0,1,len(v))[:,None]*drift
 data[name]=v.tolist()
length=(end-start)/120
speed=float(np.linalg.norm((roots[end]-roots[start])[[0,2]])/length)
(root/'work').mkdir(exist_ok=True)
(root/'work/cmu_walk_cycle.json').write_text(json.dumps({'fps':120,'start':start,'end':end,'duration':length,'speed':speed,'joints':data}),encoding='utf-8')
print('CYCLE',start,end,'DURATION',length,'SPEED',speed,flush=True)
