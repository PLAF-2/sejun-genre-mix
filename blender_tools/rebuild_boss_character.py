"""Rebuild reference-based boss surfaces with tailored clothing and baked face albedo.
Run against club_leader_boss_polished.blend. Keeps the established animation rig.
"""
import bpy,bmesh,math,random
from pathlib import Path
from mathutils import Vector,Quaternion
root=Path(__file__).resolve().parents[1]
out=root/'godot-game/assets/3d/club_leader_boss'
rig=bpy.data.objects['ClubLeaderBoss_Base.rig'];source=bpy.data.objects['ClubLeaderBoss_Base']
for p in rig.pose.bones:p.rotation_mode='QUATERNION';p.rotation_quaternion=Quaternion()
bpy.context.view_layer.update()
# Evaluate the fitted human, including facial morphs and helper mask, once in rest pose.
deps=bpy.context.evaluated_depsgraph_get();base=bpy.data.meshes.new_from_object(source.evaluated_get(deps),depsgraph=deps)
groups=[g.name for g in source.vertex_groups]
for o in list(bpy.context.scene.objects):
 if o.type in ['MESH','CURVE'] and o!=source:bpy.data.objects.remove(o,do_unlink=True)
bpy.data.objects.remove(source,do_unlink=True)

def mat(name,color,rough=.6,metal=0):
 m=bpy.data.materials.new(name);m.use_nodes=True;m.diffuse_color=(*color,1)
 p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Roughness'].default_value=rough;p.inputs['Metallic'].default_value=metal
 return m
skin=mat('Boss_Skin_PBR',(.52,.33,.24),.57)
coat=mat('Jacket_Graphite_Twill',(.035,.043,.055),.78)
panel=mat('Jacket_Soft_Leather_Panels',(.018,.023,.032),.55)
inner=mat('Inner_Shirt_Charcoal',(.016,.019,.025),.85)
pants=mat('Tailored_Trousers',(.024,.029,.038),.8)
shoe=mat('Boot_Leather',(.014,.018,.024),.48)
sole=mat('Boot_Rubber',(.007,.009,.013),.88)
metal=mat('Brushed_Gunmetal_Zipper',(.23,.25,.29),.3,.7)
stitch=mat('Stitching_Charcoal',(.095,.105,.12),.83)
hairmats=[mat('Hair_Ink_'+str(i),c,.68+i*.018) for i,c in enumerate([(.003,.004,.006),(.006,.008,.012),(.009,.012,.017),(.004,.006,.009)])]

for hm in hairmats:hm.node_tree.nodes.get('Principled BSDF').inputs['Specular IOR Level'].default_value=.15

def activate(o):
 bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o

def bind(o,bone=None):
 if o.type=='CURVE':activate(o);bpy.ops.object.convert(target='MESH');o=bpy.context.object
 o.parent=rig
 if bone:
  if bone not in rig.data.bones:bone='spine01'
  o.vertex_groups.clear();g=o.vertex_groups.new(name=bone);g.add(list(range(len(o.data.vertices))),1,'REPLACE')
 a=o.modifiers.new('Established boss skeleton','ARMATURE');a.object=rig
 for p in o.data.polygons:p.use_smooth=True
 return o

def shell(name,predicate,material,puff=0):
 mesh=base.copy();o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o)
 for nameg in groups:o.vertex_groups.new(name=nameg)
 bm=bmesh.new();bm.from_mesh(mesh)
 deform=bm.verts.layers.deform.active
 handgroups={i for i,g in enumerate(groups) if any(t in g.lower() for t in ['finger','thumb','wrist','hand'])}
 def handface(f):
  return deform and sum(sum(w for g,w in v[deform].items() if g in handgroups) for v in f.verts)/len(f.verts)>.42
 remove=[]
 for f in bm.faces:
  keep=predicate(f.calc_center_median())
  if name=='Boss_Tailored_Jacket' and handface(f):keep=False
  if name=='Boss_PhotoGuided_Face_And_Hands':
   c=f.calc_center_median();keep=c.z>1.36 or (abs(c.x)>.39 and c.z<1.15)
  if not keep:remove.append(f)
 bmesh.ops.delete(bm,geom=remove,context='FACES')
 if name=='Boss_Tailored_Jacket':
  bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),dist=.00001,plane_co=(0,0,1.39),plane_no=(0,0,1),clear_outer=True,clear_inner=False)
 bmesh.ops.delete(bm,geom=[v for v in bm.verts if not v.link_faces],context='VERTS')
 bm.normal_update()
 for v in bm.verts:
  normal=v.normal.copy();v.co+=normal*puff
  if puff:
   z=v.co.z;x=v.co.x
   fold=.0027*math.sin(z*84+x*23)*math.exp(-((z-1.11)/.15)**2)+.002*math.sin(z*74)*math.exp(-((z-.46)/.09)**2)
   v.co+=normal*fold
 bm.to_mesh(mesh);bm.free();mesh.materials.clear();mesh.materials.append(material)
 for p in mesh.polygons:p.material_index=0
 for attr in list(mesh.color_attributes):mesh.color_attributes.remove(attr)
 return o

# Build continuous body-conforming shells rather than disconnected remeshed tubes.
jacket=shell('Boss_Tailored_Jacket',lambda c:.83<c.z<1.43 and abs(c.x)<.448,coat,.024)
jacket.data.materials.append(panel)
for f in jacket.data.polygons:
 c=sum((jacket.data.vertices[i].co for i in f.vertices),Vector())/len(f.vertices)
 if abs(c.x)>.21 or (abs(c.x)>.145 and c.z<1.21):f.material_index=1
thick=jacket.modifiers.new('Sewn jacket thickness','SOLIDIFY');thick.thickness=.004
sub=jacket.modifiers.new('Smooth tailored surface','SUBSURF');sub.levels=1;sub.render_levels=1
bind(jacket)
trousers=shell('Boss_Tailored_Pants',lambda c:.085<c.z<.86,pants,.025)
solid=trousers.modifiers.new('Fabric thickness','SOLIDIFY');solid.thickness=.003
sub=trousers.modifiers.new('Cloth smoothing','SUBSURF');sub.levels=1;sub.render_levels=1
bind(trousers)
boots=shell('Boss_Ankle_Boots',lambda c:c.z<.145,shoe,.012)
solid=boots.modifiers.new('Leather thickness','SOLIDIFY');solid.thickness=.004
bind(boots)
body=shell('Boss_PhotoGuided_Face_And_Hands',lambda c:c.z>1.36 or (abs(c.x)>.437 and c.z<1.12),skin)
sub=body.modifiers.new('Facial silhouette refinement','SUBSURF');sub.levels=1;sub.render_levels=1
# Increase face definition slightly while retaining the source person's proportions.
for v in body.data.vertices:
 x,y,z=v.co
 if z>1.43:
  jaw=math.exp(-((z-1.455)/.045)**2)
  v.co.x*=1.0-.025*jaw
# Bake projected photo-guided albedo into the original UV atlas. No flat card geometry.
original_uv=body.data.uv_layers.active.name
projection=body.data.uv_layers.new(name='FaceProjection')
mask=body.data.color_attributes.new(name='FaceBlend',type='FLOAT_COLOR',domain='POINT')
for v in body.data.vertices:
 x,y,z=v.co
 front=max(0,min(1,(-y-.035)/.045))
 edge=max(0,min(1,(.100-abs(x))/.022))
 neck=max(0,min(1,(z-1.425)/.025))
 upper=max(0,min(1,(1.64-z)/.035))
 a=front*edge*neck*upper
 mask.data[v.index].color=(a,a,a,1)
for lp in body.data.loops:
 v=body.data.vertices[lp.vertex_index].co
 projection.data[lp.index].uv=(.5+v.x/.222,(v.z-1.413)/.240)
body.data.uv_layers.active=body.data.uv_layers[original_uv]
m=skin;nodes=m.node_tree.nodes;links=m.node_tree.links
p=nodes.get('Principled BSDF');output=nodes.get('Material Output')
image=bpy.data.images.load(str(out/'face_albedo_reference_v2.png'));image.pack()
uv=nodes.new('ShaderNodeUVMap');uv.uv_map='FaceProjection'
tex=nodes.new('ShaderNodeTexImage');tex.image=image;tex.extension='EXTEND';links.new(uv.outputs['UV'],tex.inputs['Vector'])
attr=nodes.new('ShaderNodeVertexColor');attr.layer_name='FaceBlend'
mix=nodes.new('ShaderNodeMixRGB');mix.blend_type='MIX';mix.inputs[1].default_value=(.52,.33,.24,1)
links.new(attr.outputs['Color'],mix.inputs[0]);links.new(tex.outputs['Color'],mix.inputs[2])
emission=nodes.new('ShaderNodeEmission');links.new(mix.outputs[0],emission.inputs['Color']);links.new(emission.outputs[0],output.inputs['Surface'])
baked=bpy.data.images.new('Boss_Skin_Atlas_2K',width=2048,height=2048,alpha=False)
bake_node=nodes.new('ShaderNodeTexImage');bake_node.image=baked;nodes.active=bake_node
activate(body);scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=1;scene.render.bake.margin=12
bpy.ops.object.bake(type='EMIT')
baked.filepath_raw=str(out/'boss_skin_albedo_v2.png');baked.file_format='PNG';baked.save();baked.pack()
# Remove the authoring nodes so GLB exports a simple standard PBR material.
for n in list(nodes):
 if n not in [p,output,bake_node]:nodes.remove(n)
links.new(bake_node.outputs['Color'],p.inputs['Base Color']);links.new(p.outputs['BSDF'],output.inputs['Surface'])
p.inputs['Specular IOR Level'].default_value=.28;p.inputs['Roughness'].default_value=.6
# Projection UV is authoring-only. Keep just the final texture atlas UV layer.
body.data.uv_layers.remove(body.data.uv_layers['FaceProjection'])
for attr in list(body.data.color_attributes):body.data.color_attributes.remove(attr)
bind(body)

def curve(name,points,radius,material,bone,closed=False):
 d=bpy.data.curves.new(name,'CURVE');d.dimensions='3D';d.bevel_depth=radius;d.bevel_resolution=2;d.resolution_u=10
 s=d.splines.new('BEZIER');s.bezier_points.add(len(points)-1);s.use_cyclic_u=closed
 for p,co in zip(s.bezier_points,points):p.co=co;p.handle_left_type='AUTO';p.handle_right_type='AUTO'
 o=bpy.data.objects.new(name,d);bpy.context.collection.objects.link(o);d.materials.append(material);return bind(o,bone)

def meshpart(name,verts,faces,material,bone):
 d=bpy.data.meshes.new(name);d.from_pydata(verts,[],faces);d.update();o=bpy.data.objects.new(name,d);bpy.context.collection.objects.link(o);d.materials.append(material);return bind(o,bone)

# Sculpted hair mass and ribbon-like locks with a shallow ridge, not round ropes.
verts=[];faces=[];rows=14;cols=64
for i in range(rows):
 t=i/(rows-1)
 for j in range(cols):
  az=j/cols*math.tau
  front=max(0,-math.sin(az));boundary=1.525+.055*front+.003*math.sin(az*7)
  theta_end=math.acos(max(-1,min(1,(boundary-1.565)/.115)))
  theta=.035+t*theta_end
  verts.append(((.109+.0015*math.sin(az*11))*math.sin(theta)*math.cos(az),-.008+(.143 if math.sin(az)<0 else .103)*math.sin(theta)*math.sin(az),1.565+.115*math.cos(theta)))
for i in range(rows-1):
 for j in range(cols):faces.append((i*cols+j,i*cols+(j+1)%cols,(i+1)*cols+(j+1)%cols,(i+1)*cols+j))
cap=meshpart('Boss_Sculpted_Hair_Silhouette',verts,faces,hairmats[0],'head')
rng=random.Random(4)
for k in range(23):
 u=k/22;endx=-.103+u*.206;rootx=.014+endx*.24
 points=[Vector((rootx,-.035,1.674-abs(endx)*.13)),Vector((endx*.45,-.121,1.658)),Vector((endx*.83,-.151,1.611)),Vector((endx,-.153+rng.uniform(-.001,.001),1.556+abs(endx)*.13+rng.uniform(-.004,.004)))]
 vs=[];fs=[];width=.0075+rng.random()*.002
 for i in range(17):
  t=i/16
  center=(1-t)**3*points[0]+3*(1-t)**2*t*points[1]+3*(1-t)*t*t*points[2]+t**3*points[3]
  w=width*math.sin(t*math.pi*.9+.17)**.5*(1-t)**.35+.00012
  for q in range(5):
   a=(q-2)/2
   vs.append(tuple(center+Vector((a*w,-.0035*(1-a*a)*math.sin(t*math.pi),0))))
 for i in range(16):
  for j in range(4):fs.append((i*5+j,i*5+j+1,(i+1)*5+j+1,(i+1)*5+j))
 lock=meshpart('Boss_Sculpted_Hair_Lock_%02d'%k,vs,fs,hairmats[k%4],'head')
 sub=lock.modifiers.new('Soft lock edges','SUBSURF');sub.levels=1;sub.render_levels=1
# Eyes use almond silhouettes with a small iris and tiny catchlight.
white=mat('Eye_Warm_Sclera',(.52,.49,.45),.28);iris=mat('Eye_Dark_Brown',(.019,.011,.006),.23);pupil=mat('Eye_Pupil',(.002,.003,.005),.18)
def ellipsoid(name,at,size,material,bone='head'):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=32,ring_count=16,location=at)
 o=bpy.context.object;o.name=name;o.scale=size;activate(o);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(material);return bind(o,bone)
eye_mat=mat('Eye_PhotoGuided_Albedo',(1,1,1),.44)
eye_tex=eye_mat.node_tree.nodes.new('ShaderNodeTexImage');eye_tex.image=image
eye_mat.node_tree.links.new(eye_tex.outputs['Color'],eye_mat.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])
for side,tag in [(-1,'R'),(1,'L')]:
 x=side*.0288;z=1.540
 eye=ellipsoid('Eye_Anatomical_'+tag,(x,-.1285,z),(.0114,.005,.0040),eye_mat)
 for layer in list(eye.data.uv_layers):eye.data.uv_layers.remove(layer)
 uv=eye.data.uv_layers.new(name='EyeProjection')
 for lp in eye.data.loops:
  v=eye.matrix_world@eye.data.vertices[lp.vertex_index].co
  uv.data[lp.index].uv=(.5+v.x/.222,(v.z-1.413)/.240)
# Plain high-collar graphite jacket with visible construction and understated metalwork.
curve('Neckline_Finished_Seam',[(.071*math.cos(i*math.tau/32),-.028+.070*math.sin(i*math.tau/32),1.390) for i in range(32)],.0022,panel,'spine01',True)
for side in [-1,1]:
 collar=meshpart('Boss_Folded_Collar_'+str(side),[(side*.014,-.114,1.390),(side*.050,-.091,1.414),(side*.075,-.090,1.390),(side*.045,-.130,1.365)],[(0,1,2,3)],panel,'neck')
 solid=collar.modifiers.new('Folded cloth thickness','SOLIDIFY');solid.thickness=.003
 bevel=collar.modifiers.new('Collar edge','BEVEL');bevel.width=.003;bevel.segments=3
 curve('Chest_Welt_'+str(side),[(side*.07,-.142,1.27),(side*.125,-.133,1.26)],.0023,panel,'spine02')
 curve('Pocket_Zip_'+str(side),[(side*.08,-.137,1.01),(side*.13,-.12,1.075)],.0014,metal,'spine03')
curve('Jacket_Front_Zip',[(0,-.113,.85),(0,-.142,1.02),(0,-.161,1.2),(0,-.121,1.395)],.0019,metal,'spine02')
# Make independent fingers readable without adding blocky armor.
for side,tag in [(1,'L'),(-1,'R')]:
 ankle=rig.data.bones['foot.'+tag].head_local.copy()
 ellipsoid('Boot_Sole_'+tag,(ankle.x,-.075,.025),(.068,.148,.024),sole,'foot.'+tag)
 for j in range(3):
  curve('Boot_Lace_'+tag+str(j),[(ankle.x-.032,-.068-j*.017,.096-j*.012),(ankle.x+.032,-.068-j*.017,.096-j*.012)],.0016,stitch,'foot.'+tag)
# UV-map accessories for future texturing and preserve smooth normals.
for o in bpy.context.scene.objects:
 if o.type=='MESH' and not o.data.uv_layers:
  activate(o);bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(island_margin=.02);bpy.ops.object.mode_set(mode='OBJECT')
# One broad key and rim, clean studio previews, no harsh underlighting.
for o in list(bpy.context.scene.objects):
 if o.type=='LIGHT':bpy.data.objects.remove(o,do_unlink=True)
for name,at,power,size in [('Key',(-2,-3,3),160,2.4),('Fill',(2,-2,2),80,2),('Rim',(1,1,2.6),180,1.8)]:
 bpy.ops.object.light_add(type='AREA',location=at);o=bpy.context.object;o.name=name;o.data.energy=power;o.data.shape='DISK';o.data.size=size;o.rotation_euler=(Vector((0,0,1.1))-o.location).to_track_quat('-Z','Y').to_euler()
scene.world.color=(.08,.08,.08)
scene.view_settings.view_transform='AgX'
blend=root/'blender_project/club_leader_boss/club_leader_boss_rebuilt_v2.blend';bpy.ops.wm.save_as_mainfile(filepath=str(blend))
bpy.ops.object.select_all(action='DESELECT')
for o in bpy.context.scene.objects:
 if o.type in ['MESH','ARMATURE']:o.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(out/'club_leader_boss_rebuilt_v2.glb'),export_format='GLB',use_selection=True,export_apply=True,export_animations=False)
scene.cycles.samples=32;scene.render.resolution_x=800;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
cam=bpy.data.objects['Preview_Camera'];scene.camera=cam
for name,at,target in [('rebuilt_face_v2',(.13,-.82,1.59),(0,-.04,1.55)),('rebuilt_full_v2',(1.25,-3.0,1.50),(0,0,.9))]:
 cam.location=at;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(out/(name+'.png'));bpy.ops.render.render(write_still=True)
print('REBUILT BOSS V2 EXPORTED',flush=True)
