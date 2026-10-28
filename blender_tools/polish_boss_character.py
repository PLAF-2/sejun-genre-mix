"""Refine the existing fitted character and keep the established Godot skeleton."""
import bpy, math, bmesh, random
from pathlib import Path
from mathutils import Vector
from mathutils import Quaternion

root=Path(__file__).resolve().parents[1]
rig=bpy.data.objects['ClubLeaderBoss_Base.rig']
body=bpy.data.objects['ClubLeaderBoss_Base']
for pose in rig.pose.bones:
    pose.rotation_mode='QUATERNION';pose.rotation_quaternion=Quaternion()
bpy.context.view_layer.update()
rng=random.Random(53)

def mat(name,color,rough=.65):
    m=bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes=True;m.diffuse_color=(*color,1)
    p=m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value=(*color,1)
    p.inputs['Roughness'].default_value=rough
    p.inputs['Metallic'].default_value=0
    p.inputs['Emission Strength'].default_value=0
    return m

def bind(obj,bone='head'):
    bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj
    if obj.type=='CURVE':bpy.ops.object.convert(target='MESH');obj=bpy.context.object
    obj.parent=rig
    group=obj.vertex_groups.get(bone) or obj.vertex_groups.new(name=bone)
    group.add(list(range(len(obj.data.vertices))),1,'REPLACE')
    modifier=obj.modifiers.new('Skin attachment','ARMATURE');modifier.object=rig
    for face in obj.data.polygons:face.use_smooth=True
    return obj

def curve(name,points,radius,material,bone='head',taper=False):
    data=bpy.data.curves.new(name,'CURVE');data.dimensions='3D';data.bevel_depth=radius;data.bevel_resolution=3;data.resolution_u=10
    spline=data.splines.new('BEZIER');spline.bezier_points.add(len(points)-1)
    for i,(p,co) in enumerate(zip(spline.bezier_points,points)):
        p.co=co;p.handle_left_type='AUTO';p.handle_right_type='AUTO'
        if taper:p.radius=[.85,1,.65,.02][min(i,3)]
    obj=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(obj);obj.data.materials.append(material)
    return bind(obj,bone)

# The prior glowing harness/metal collars read as armor. Keep a civilian black outfit.
for obj in list(bpy.data.objects):
    if any(obj.name.startswith(prefix) for prefix in ['Boss_Chest_Core','Boss_Trim_','Boss_ChestStrap_','Boss_Collar_','Boss_Belt','Boss_Hair_']):
        bpy.data.objects.remove(obj,do_unlink=True)

skin=mat('Boss_Skin_PBR',(.57,.39,.29),.62)
hair=mat('Hair_Black_Natural',(.012,.014,.018),.47)
coat=mat('Boss_Coat_Black',(.027,.031,.036),.84)
cloth=mat('Boss_Inner_Cloth',(.012,.016,.021),.88)
leather=mat('Boss_Boot_Leather',(.015,.019,.022),.65)
seam=mat('Boss_Seam_Charcoal',(.065,.071,.078),.80)
lip=mat('Boss_Lip_Natural',(.39,.21,.17),.64)
# A black inner layer prevents skin peeking through a moving garment seam.
body.data.materials.clear();body.data.materials.append(skin);body.data.materials.append(cloth)
for face in body.data.polygons:
    center=sum((body.data.vertices[i].co for i in face.vertices),Vector())/len(face.vertices)
    hand=any(any(token in body.vertex_groups[g.group].name.lower() for token in ['finger','thumb','wrist','hand']) and g.weight>.35 for i in face.vertices for g in body.data.vertices[i].groups)
    face.material_index=1 if .09<center.z<1.40 and abs(center.x)<.49 and not hand else 0
for name in ['Boss_Fitted_LongCoat','Boss_Fitted_Trousers','Boss_Fitted_Boots']:
    obj=bpy.data.objects.get(name)
    if not obj:continue
    obj.data.materials.clear();obj.data.materials.append(coat if 'Coat' in name else cloth if 'Trousers' in name else leather)
    for face in obj.data.polygons:face.material_index=0
    for mod in obj.modifiers:
        if mod.type=='SOLIDIFY':mod.thickness=.006
    # Give cloth clearance and restrained elbow/knee folds instead of a skin-tight shell.
    for v in obj.data.vertices:
        x,y,z=v.co
        if 'Coat' in name:
            v.co.x*=1.07
            v.co.y*=1.12
            fold=.0025*math.sin(z*118+x*24)*math.exp(-((z-1.10)/.16)**2)
            v.co.y+=fold
        elif 'Trousers' in name:
            v.co.x*=1.065;v.co.y*=1.09
            v.co.y+=.0025*math.sin(z*95)*math.exp(-((z-.48)/.18)**2)
    # Add one subdivision level after thickness/smoothing, before skin deformation.
    sub=obj.modifiers.new('Fabric surface refinement','SUBSURF');sub.levels=1;sub.render_levels=1
    bpy.context.view_layer.objects.active=obj
    bpy.ops.object.modifier_move_up(modifier=sub.name)

# Replace the old cropped body shells with complete sewn garment meshes.
for name in ['Boss_Fitted_LongCoat','Boss_Fitted_Trousers','Boss_Fitted_Boots']:
    if name in bpy.data.objects:bpy.data.objects.remove(bpy.data.objects[name],do_unlink=True)

def garment(name,rings,material,weights):
    verts=[];faces=[];segments=32
    for center,axis,rx,ry in rings:
        axis=Vector(axis).normalized();a=Vector((0,1,0));a=(a-axis*a.dot(axis)).normalized();b=axis.cross(a).normalized()
        for j in range(segments):
            angle=2*math.pi*j/segments
            v=Vector(center)+a*(math.cos(angle)*ry)+b*(math.sin(angle)*rx)
            verts.append(v)
    for i in range(len(rings)-1):
        for j in range(segments):faces.append((i*segments+j,i*segments+(j+1)%segments,(i+1)*segments+(j+1)%segments,(i+1)*segments+j))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
    obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj);obj.data.materials.append(material);obj.parent=rig
    for i in range(len(rings)):
        for bone,value in weights(i,len(rings)).items():
            g=obj.vertex_groups.get(bone) or obj.vertex_groups.new(name=bone);g.add(list(range(i*segments,(i+1)*segments)),value,'REPLACE')
    solid=obj.modifiers.new('Fabric edge','SOLIDIFY');solid.thickness=.012
    sub=obj.modifiers.new('Sewn smoothing','SUBSURF');sub.levels=2;sub.render_levels=2
    arm=obj.modifiers.new('Garment skin','ARMATURE');arm.object=rig
    for p in mesh.polygons:p.use_smooth=True
    return obj

garment('Boss_Casual_Jacket',[(Vector((0,-.004,z)),Vector((0,0,1)),rx,ry) for z,rx,ry in [(.82,.193,.17),(.835,.198,.171),(.9,.2,.172),(1.02,.208,.18),(1.15,.23,.18),(1.28,.248,.157),(1.36,.224,.13),(1.40,.11,.09),(1.425,.088,.078)]],coat,lambda i,n:{'spine02' if i<4 else 'spine03':1})
for tag,side in [('L',1),('R',-1)]:
    shoulder=rig.data.bones['upperarm01.'+tag].head_local.copy()
    elbow=rig.data.bones['lowerarm01.'+tag].head_local.copy()
    wrist=rig.data.bones.get('wrist.'+tag)
    wrist=wrist.head_local.copy() if wrist else Vector((side*.48,-.10,.98))
    rings=[]
    for i in range(11):
        t=i/10
        point=shoulder.lerp(elbow,t*2) if t<=.5 else elbow.lerp(wrist,(t-.5)*2)
        axis=(elbow-shoulder) if t<.5 else wrist-elbow
        radius=.095*(1-t)+.060*t+.002*math.sin(t*20)
        rings.append((point,axis,radius,radius*.9))
    garment('Boss_Jacket_Sleeve_'+tag,rings,coat,lambda i,n,tag=tag:{'upperarm01.'+tag:1} if i<4 else {'upperarm01.'+tag:.5,'lowerarm01.'+tag:.5} if i<6 else {'lowerarm01.'+tag:1})
    hip=rig.data.bones['upperleg01.'+tag].head_local.copy();knee=rig.data.bones['lowerleg01.'+tag].head_local.copy();ankle=rig.data.bones['foot.'+tag].head_local.copy()
    rings=[]
    for i in range(15):
        t=i/14
        point=hip.lerp(knee,t*2) if t<=.5 else knee.lerp(ankle,(t-.5)*2)
        radius=.112*(1-t)+.069*t+.002*math.sin(t*45)
        rings.append((point,Vector((0,0,1)),radius,radius*1.25))
    garment('Boss_Casual_Trouser_'+tag,rings,cloth,lambda i,n,tag=tag:{'upperleg01.'+tag:1} if i<6 else {'upperleg01.'+tag:.5,'lowerleg01.'+tag:.5} if i<9 else {'lowerleg01.'+tag:1})
    bpy.ops.mesh.primitive_cube_add(size=1,location=(ankle.x,-.09,.05))
    shoe=bpy.context.object;shoe.name='Boss_Casual_Shoe_'+tag;shoe.scale=(.145,.30,.095)
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    bevel=shoe.modifiers.new('Rounded leather upper','BEVEL');bevel.width=.029;bevel.segments=5
    shoe.data.materials.append(leather);bind(shoe,'foot.'+tag)

# Fuse intersecting shoulder pieces into one continuous cloth surface, then transfer
# the existing human's skin weights back onto it. This removes tube-like seams.
jacket_parts=[o for o in bpy.data.objects if o.name=='Boss_Casual_Jacket' or o.name.startswith('Boss_Jacket_Sleeve_')]
converted=[]
for obj in jacket_parts:
    bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj
    for modifier in list(obj.modifiers):
        if modifier.type=='ARMATURE':obj.modifiers.remove(modifier)
    bpy.ops.object.convert(target='MESH');converted.append(bpy.context.object)
bpy.ops.object.select_all(action='DESELECT')
for obj in converted:obj.select_set(True)
bpy.context.view_layer.objects.active=converted[0];bpy.ops.object.join();jacket=bpy.context.object
jacket.name='Boss_Tailored_Casual_Jacket'
print('POLISH_STAGE remesh jacket',flush=True)
remesh=jacket.modifiers.new('Continuous cloth shoulders','REMESH');remesh.mode='VOXEL';remesh.voxel_size=.009;remesh.use_smooth_shade=True
bpy.ops.object.modifier_apply(modifier=remesh.name)
sm=jacket.modifiers.new('Relax fabric','SMOOTH');sm.factor=.7;sm.iterations=5;bpy.ops.object.modifier_apply(modifier=sm.name)
jacket.vertex_groups.clear()
for group in body.vertex_groups:jacket.vertex_groups.new(name=group.name)
transfer=jacket.modifiers.new('Fitted deformation weights','DATA_TRANSFER');transfer.object=body
transfer.use_vert_data=True;transfer.data_types_verts={'VGROUP_WEIGHTS'};transfer.vert_mapping='POLYINTERP_NEAREST'
print('POLISH_STAGE transfer garment weights',flush=True)
bpy.ops.object.modifier_apply(modifier=transfer.name)
arm=jacket.modifiers.new('Natural garment deformation','ARMATURE');arm.object=rig
normals=[v.normal.copy() for v in jacket.data.vertices]
for v,normal in zip(jacket.data.vertices,normals):
    fold=.0018*math.sin(v.co.z*94+v.co.x*11)*math.exp(-((v.co.z-1.06)/.18)**2)
    v.co+=normal*fold
print('POLISH_STAGE garment complete',len(jacket.data.vertices),flush=True)
for p in jacket.data.polygons:p.use_smooth=True

# Eyes are inset almond shapes, rather than protruding spheres.
for tag in ['L','R']:
    eye=bpy.data.objects.get('Boss_Eyeball_'+tag);iris=bpy.data.objects.get('Boss_Iris_'+tag)
    if not eye:continue
    eye.scale.z*=.54;eye.scale.y*=.65;eye.location.y+=.003
    iris.scale.z*=.70;iris.scale.x*=.85;iris.location.y+=.005
    center=eye.location.copy()
    for upper in [True,False]:
        points=[]
        for i in range(7):
            u=-1+2*i/6
            points.append((center.x+u*.0123,center.y-.0075+abs(u)*.003,center.z+(1-u*u)*(.0059 if upper else -.0041)))
        curve('Boss_Eyelid_'+tag+str(upper),points,.0007,skin)

# Fill the hair volume with a shaped cap and tapered, asymmetric locks.
bpy.ops.mesh.primitive_uv_sphere_add(segments=64,ring_count=32,location=(0,-.007,1.573))
cap=bpy.context.object;cap.name='Boss_Hair_Sculpted_Cap';cap.scale=(.113,.108,.105)
bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
bm=bmesh.new();bm.from_mesh(cap.data)
for v in list(bm.verts):
    world=cap.matrix_world@v.co
    cutoff=1.588 if world.y<-.060 else 1.505
    if world.z<cutoff:bm.verts.remove(v)
bm.to_mesh(cap.data);bm.free();cap.data.materials.append(hair);bind(cap)
for i in range(16):
    u=i/15;side=-1 if u<.58 else 1
    end_x=-.101+u*.200
    root_x=.018+side*.012
    end_z=1.562+.010*math.sin(u*6.4)-abs(end_x)*.07
    curve('Boss_Hair_Tapered_%02d'%i,[
        (root_x,-.040,1.675-abs(end_x)*.12),
        (end_x*.38,-.103,1.660),
        (end_x*.84,-.116,1.615),
        (end_x,-.122+rng.uniform(-.002,.002),end_z)
    ],.010+rng.random()*.003,hair,taper=True)

# A sewn front opening, soft stand collar, pocket flaps and fine stitch lines.
curve('Boss_Jacket_Zipper',[(0,-.181,.83),(0,-.188,1.0),(0,-.187,1.22),(0,-.145,1.37)],.0015,seam,'spine02')
for side in [-1,1]:
    curve('Boss_Pocket_Stitch'+str(side),[(side*.105,-.166,1.12),(side*.15,-.157,1.115)],.0011,seam,'spine02')
    curve('Boss_Hem_Stitch'+str(side),[(side*.012,-.168,.82),(side*.10,-.166,.82),(side*.16,-.143,.83)],.0011,seam,'spine02')

# Bake subtle material microvariation into small textures so it survives GLB export.
import numpy as np
for material in [coat,cloth,skin]:
    base=material.diffuse_color[:3];size=256
    values=np.random.default_rng(84).normal(1,.035 if material!=skin else .017,(size,size,1))
    rgba=np.ones((size,size,4),dtype=np.float32);rgba[:,:,:3]=np.clip(np.array(base)[None,None,:]*values,0,1)
    image=bpy.data.images.new(material.name+'_Detail',width=size,height=size)
    image.pixels.foreach_set(rgba.ravel());image.pack()
    tex=material.node_tree.nodes.new('ShaderNodeTexImage');tex.image=image
    material.node_tree.links.new(tex.outputs['Color'],material.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])

out=root/'godot-game/assets/3d/club_leader_boss'
blend=root/'blender_project/club_leader_boss/club_leader_boss_polished.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(blend))
bpy.ops.object.select_all(action='DESELECT')
for obj in bpy.context.scene.objects:
    if obj.type in ['MESH','ARMATURE']:obj.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(out/'club_leader_boss.glb'),export_format='GLB',use_selection=True,export_apply=True,export_animations=True)

scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24
scene.render.resolution_x=640;scene.render.resolution_y=800;scene.render.resolution_percentage=100
scene.world.color=(.08,.08,.08)
cam=bpy.data.objects['Preview_Camera'];scene.camera=cam
for label,location,target in [('polished_full',(0,-3.1,1.1),(0,0,.9)),('polished_face',(.20,-.85,1.60),(0,-.04,1.56))]:
    cam.location=location;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(out/(label+'.png'));bpy.ops.render.render(write_still=True)
print('POLISHED BOSS EXPORTED',blend)
