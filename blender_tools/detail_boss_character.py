"""Refine existing reference-based rig; save a separate source, preserve original."""
import bpy, math, random
import numpy as np
from mathutils import Vector,Quaternion
from pathlib import Path
root=Path(__file__).resolve().parents[1]
rig=bpy.data.objects['ClubLeaderBoss_Base.rig']; body=bpy.data.objects['ClubLeaderBoss_Base']
for p in rig.pose.bones:p.rotation_mode='QUATERNION';p.rotation_quaternion=Quaternion()
bpy.context.view_layer.update()
rng=random.Random(81)

def material(name,color,rough):
 m=bpy.data.materials.get(name) or bpy.data.materials.new(name);m.use_nodes=True
 p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Roughness'].default_value=rough
 m.diffuse_color=(*color,1)
 return m

def texture(m,label,data,target):
 h,w,c=data.shape
 im=bpy.data.images.new(label,width=w,height=h);im.pixels.foreach_set(data.astype(np.float32).ravel());im.pack()
 n=m.node_tree.nodes.new('ShaderNodeTexImage');n.image=im
 if target=='Normal':
  im.colorspace_settings.name='Non-Color';norm=m.node_tree.nodes.new('ShaderNodeNormalMap');norm.inputs['Strength'].default_value=.08
  m.node_tree.links.new(n.outputs['Color'],norm.inputs['Color']);m.node_tree.links.new(norm.outputs['Normal'],m.node_tree.nodes.get('Principled BSDF').inputs['Normal'])
 else:
  if target=='Roughness':im.colorspace_settings.name='Non-Color'
  m.node_tree.links.new(n.outputs['Color'],m.node_tree.nodes.get('Principled BSDF').inputs[target])

def micro(m,label,cloth=False):
 n=512;random=np.random.default_rng(124 if cloth else 18)
 yy,xx=np.mgrid[:n,:n];grain=random.normal(0,1,(n,n))
 h=grain*.12
 if cloth:h+=.2*np.sin(xx*math.pi/2)*np.sin(yy*math.pi/2)
 dx=np.roll(h,1,1)-np.roll(h,-1,1);dy=np.roll(h,1,0)-np.roll(h,-1,0)
 norm=np.ones((n,n,4),dtype=np.float32);norm[:,:,0]=.5+dx*.13;norm[:,:,1]=.5+dy*.13;norm[:,:,2]=1
 texture(m,label+'_normal',norm,'Normal')
 rough=np.ones((n,n,4),dtype=np.float32);rough[:,:,:3]=np.clip((.84 if cloth else .49)+grain[:,:,None]*.009,0,1)
 texture(m,label+'_roughness',rough,'Roughness')

skin=bpy.data.materials['Boss_Skin_PBR'];p=skin.node_tree.nodes.get('Principled BSDF')
# Replace flat brown with spatially varied complexion. Vertex colors survive GLB.
for link in list(skin.node_tree.links):
 if link.to_node==p and link.to_socket.name=='Base Color':skin.node_tree.links.remove(link)
attr=body.data.color_attributes.get('Complexion') or body.data.color_attributes.new(name='Complexion',type='FLOAT_COLOR',domain='POINT')
for v in body.data.vertices:
 x,y,z=v.co;front=math.exp(-((y+.10)/.075)**2)
 cheek=math.exp(-((abs(x)-.061)/.031)**2-((z-1.51)/.032)**2)*front
 lip=math.exp(-(x/.034)**4-((z-1.465)/.009)**2)*front
 undereye=math.exp(-((abs(x)-.044)/.026)**2-((z-1.548)/.013)**2)*front
 variation=.008*math.sin(x*350+z*210)*math.sin(z*176-y*231)
 base=np.array([.38,.235,.165])+variation
 base+=cheek*np.array([.025,-.008,-.009])+lip*np.array([-.035,-.07,-.045])+undereye*np.array([-.025,-.025,-.018])
 attr.data[v.index].color=(*np.clip(base,0,1),1)
color=skin.node_tree.nodes.new('ShaderNodeVertexColor');color.layer_name='Complexion'
skin.node_tree.links.new(color.outputs['Color'],p.inputs['Base Color'])
p.inputs['Subsurface Weight'].default_value=.08;p.inputs['Subsurface Radius'].default_value=(1,.45,.25)
p.inputs['Specular IOR Level'].default_value=.3
micro(skin,'Skin_pores')
# Match the small eyelid meshes to the new skin rather than using a uniform dark seam.
for o in bpy.data.objects:
 if o.type=='MESH' and (o.name.startswith('Boss_Eyelid') or o.name.startswith('Boss_Eyeball') or o.name.startswith('Boss_Iris')):
  print('EYE',o.name,tuple(o.location),flush=True)
  if o.name.startswith('Boss_Eyelid'):
   m=material('Eyelid_Complexion',(.38,.235,.165),.52);o.data.materials.clear();o.data.materials.append(m)
  elif o.name.startswith('Boss_Eyeball'):
   m=material('Sclera_Soft_Ivory',(.35,.33,.30),.25);o.data.materials.clear();o.data.materials.append(m)
  else:
   m=material('Iris_Deep_Brown',(.025,.012,.007),.22);o.data.materials.clear();o.data.materials.append(m)
# Thin tapered locks replace the thick tubular front fringe. Keep shaped scalp volume.
for o in list(bpy.data.objects):
 if o.name.startswith('Boss_Hair_Tapered_'):bpy.data.objects.remove(o,do_unlink=True)
hair=material('Hair_Black_Natural',(.009,.011,.014),.58);micro(hair,'Hair_surface')

def strand(name,points,radius,mat,bone='head'):
 d=bpy.data.curves.new(name,'CURVE');d.dimensions='3D';d.bevel_depth=radius;d.bevel_resolution=2;d.resolution_u=8
 s=d.splines.new('BEZIER');s.bezier_points.add(len(points)-1)
 for i,(p,co) in enumerate(zip(s.bezier_points,points)):
  p.co=co;p.handle_left_type='AUTO';p.handle_right_type='AUTO';p.radius=[.5,1,.65,.015][min(i,3)]
 o=bpy.data.objects.new(name,d);bpy.context.collection.objects.link(o);d.materials.append(mat)
 bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o;bpy.ops.object.convert(target='MESH');o=bpy.context.object
 o.parent=rig;g=o.vertex_groups.new(name=bone);g.add(list(range(len(o.data.vertices))),1,'REPLACE');a=o.modifiers.new('Rig','ARMATURE');a.object=rig
 for f in o.data.polygons:f.use_smooth=True
 return o
for i in range(92):
 u=i/91;x=-.101+.202*u;side=-1 if u<.61 else 1
 rootx=.016+side*.015;tipz=1.554+.007*math.sin(u*11)+abs(x)*.06+rng.uniform(-.005,.005)
 points=[(rootx,-.044,1.671-abs(x)*.12),(x*.4,-.103,1.654),(x*.84,-.119,1.609),(x,-.124+rng.uniform(-.002,.002),tipz)]
 o=strand('Hair_Fine_Lock_%03d'%i,points,.0023+rng.random()*.0009,hair)
 # Flatten depth to read as layered ribbons instead of dreadlocks.
for i in range(150):
 u=rng.random();x=-.103+.206*u
 strand('Hair_Flyaway_%03d'%i,[(.016,-.043,1.674-abs(x)*.1),(x*.4,-.105,1.657),(x*.82,-.122,1.612),(x,-.126,1.555+rng.uniform(-.008,.008))],.00028,hair)
# Distinguish woven fabric, leather and metal, add collar/pocket tailoring.
coat=bpy.data.materials['Boss_Coat_Black'];micro(coat,'Jacket_weave',True)
inner=bpy.data.materials['Boss_Inner_Cloth'];micro(inner,'Trouser_weave',True)
leather=bpy.data.materials['Boss_Boot_Leather'];micro(leather,'Leather_grain')
seam=material('Fine_Stitch',(.055,.061,.069),.8)
for side in [-1,1]:
 # A flat folded collar, rather than cylindrical piping.
 verts=[(side*.018,-.156,1.395),(side*.065,-.134,1.425),(side*.11,-.125,1.397),(side*.092,-.161,1.347)]
 mesh=bpy.data.meshes.new('Folded collar');mesh.from_pydata(verts,[],[(0,1,2,3)]);mesh.update()
 o=bpy.data.objects.new('Tailored_Collar_'+str(side),mesh);bpy.context.collection.objects.link(o);o.parent=rig;mesh.materials.append(coat)
 g=o.vertex_groups.new(name='spine03');g.add(list(range(4)),1,'REPLACE')
 solid=o.modifiers.new('Cloth thickness','SOLIDIFY');solid.thickness=.003
 bevel=o.modifiers.new('Soft collar edge','BEVEL');bevel.width=.004;bevel.segments=3
 a=o.modifiers.new('Rig','ARMATURE');a.object=rig
 strand('Pocket_Welt_'+str(side),[(side*.11,-.173,1.105),(side*.145,-.167,1.10),(side*.165,-.155,1.095)],.003,coat,'spine02')
 for i in range(14):
  z=.9+i*.031
  strand('Zipper_Tooth_%s_%02d'%(side,i),[(side*.0015,-.192,z),(side*.004,-.191,z+.001)],.0007,seam,'spine02')
# Export normal maps require UVs on each garment, not Generated coordinates.
for o in bpy.context.scene.objects:
 if o.type=='MESH' and not o.data.uv_layers:
  bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
  bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(island_margin=.02);bpy.ops.object.mode_set(mode='OBJECT')
blend=root/'blender_project/club_leader_boss/club_leader_boss_detailed.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(blend))
bpy.ops.object.select_all(action='DESELECT')
for o in bpy.context.scene.objects:
 if o.type in ['MESH','ARMATURE']:o.select_set(True)
bpy.context.view_layer.objects.active=rig
out=root/'godot-game/assets/3d/club_leader_boss'
bpy.ops.export_scene.gltf(filepath=str(out/'club_leader_boss.glb'),export_format='GLB',use_selection=True,export_apply=True,export_animations=True)
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24
scene.render.resolution_x=640;scene.render.resolution_y=800;scene.render.resolution_percentage=100
cam=bpy.data.objects['Preview_Camera'];scene.camera=cam
cam.location=(.15,-.85,1.6);target=Vector((0,-.04,1.56));cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler()
scene.render.filepath=str(out/'detailed_face.png');bpy.ops.render.render(write_still=True)
print('DETAILED MODEL EXPORTED',flush=True)
