#!/usr/bin/env python3
"""Author the title Abrams and its two crew in Blender, preserving Godot batch selectors.
Run Blender --background --factory-startup --python tools/build_cover_blender.py.
The .blend retains an unmodified Basis and a named authored refinement shape key.
Runtime exports only vertex/normal replacements, preserving UVs, colour and materials.
"""
import bpy
import argparse
import hashlib
import json
import math
import sys
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
from tools.source_guard import inside_source
SOURCE_ART = ROOT / 'local-art/cover-blender-v1'
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output',type=Path,help='Write a review candidate here, leaving installed assets untouched')
parser.add_argument('--source',type=Path,default=SOURCE_ART/'source.json',help='Captured procedural batches for this candidate')
options=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
ART = options.output.resolve() if options.output else SOURCE_ART
OUT = ART/'cover_blender_v1.json' if options.output else ROOT/'godot/assets/cover_blender_v1.json'
if inside_source(ART) or inside_source(OUT):raise ValueError('Refusing original inputs or pinned evidence')
ART.mkdir(parents=True,exist_ok=True)

def gauss(p, centre, scale):
    return math.exp(-sum(((p[i]-centre[i])/scale[i])**2 for i in range(3))*2)

def garment_fit(p,batch):
    """Tailor the over-full upper sleeves without moving elbow/wrist anchors."""
    if batch['frame']!='crew':return Vector((0,0,0))
    # The source shader colours identify the outer shirt, its opaque lining and
    # their stitched trim. Apply the same fit to all three, retaining contact.
    colours=((201,201,186),(119,123,110),(166,168,154),
             (176,154,118),(113,101,79),(136,120,93))
    if not any(max(abs(batch['colour'][i]-c[i]/255) for i in range(3))<.00001 for c in colours):return Vector((0,0,0))
    arms=[((.87,1.45,.6),(.96,1.17,.58)),((.58,1.4,.26),(.52,1.24,.02))] if p[0]>0 else [((-.49,1.265,.04),(-.36,1.04,.15)),((-.88,1.235,.10),(-1.02,1.035,.19))]
    result=Vector((0,0,0))
    point=Vector(p)
    for shoulder,elbow in arms:
        shoulder,elbow=Vector(shoulder),Vector(elbow)
        axis=elbow-shoulder;t=(point-shoulder).dot(axis)/axis.length_squared
        if not -.3<t<1.3:continue
        centre=shoulder+axis*max(0.,min(1.,t));radial=point-centre;distance=radial.length
        if not .028<distance<.105:continue
        band=max(0.,min(1.,(distance-.028)/.025));band=band*band*(3-2*band)
        outer=max(0.,min(1.,(.105-distance)/.02));band*=outer*outer*(3-2*outer)
        ends=max(0.,min(1.,(t+.3)/.15))*max(0.,min(1.,(1.3-t)/.2))
        # The joined shoulder now has its own anatomical shape. Tailoring is
        # strongest over the upper arm and fades before the clavicle insertion.
        # Working if the rounded deltoid stays full while sleeve folds taper.
        shoulder_fade=max(0.,min(1.,(t-.04)/.24))
        falloff=math.exp(-((t-.43)/.48)**4)*ends*ends*(3-2*ends)*shoulder_fade
        fit=-radial.normalized()*.0065*band*falloff
        if fit.length>result.length:result=fit
    return result

def displacement(p, n, batch):
    """Structural garment fit plus shallow surface craft, preserving pose anchors."""
    x,y,z = p
    kind,role = batch['kind'],batch['frame']
    amount = 0.0
    if role == 'crew':
        commander = x > 0
        if kind == 'cloth':
            # Sleeves compress into the elbow/cuff; broad folds flow across the chest.
            elbows = [(0.96,1.17,0.58),(0.52,1.24,0.02)] if commander else [(-0.36,1.04,0.15),(-1.02,1.035,0.19)]
            for c in elbows:
                weight = gauss(p,c,(0.17,0.12,0.17))
                amount += 0.0055*weight*math.sin((y-c[1])*93+(z-c[2])*19)
            amount += 0.0018*math.sin(y*62+z*15)*math.sin(x*31)*gauss(p,(0.74,1.24,0.4) if commander else (-0.68,1.13,0.23),(0.35,0.30,0.32))
            # The glove's back follows the knuckle arc, while the underside stays
            # on its weapon grip or hatch contact. Keep finger-tip anchors fixed.
            hands = [(0.98,1.34,0.3),(0.74,1.36,0.02)] if commander else [(-0.58,0.858,-0.12),(-0.96,0.858,-0.13)]
            for hand in hands:
                weight = gauss(p,hand,(0.065,0.045,0.065))
                contact = max(0.0,min(1.0,(y-hand[1]+0.006)/0.026))
                amount += 0.0022*weight*contact*(0.5+0.5*math.cos((x-hand[0])*140))
            # Subtle tension lines around the fitted helmet cover.
            if not commander and y > 1.36:
                amount += 0.0017*math.sin(x*81+z*37)*gauss(p,(-0.68,1.44,-0.06),(0.17,0.14,0.17))
        elif kind == 'skin':
            # Soften planar cheek transitions without changing the gaze or head basis.
            head = Vector((0.77,1.61,0.39) if commander else (-0.68,1.36,-0.06))
            forward = Vector((0.72,-0.05,-0.69) if commander else (0.25,-0.45,-0.86)).normalized()
            up = Vector((0.025,0.99,-0.06) if commander else (0.02,0.80,-0.60))
            right = up.cross(forward).normalized(); up = forward.cross(right).normalized()
            local = Vector(p)-head
            lx,ly,lz = local.dot(right),local.dot(up),local.dot(forward)
            cheek = math.exp(-((abs(lx)-0.049)/0.024)**2-((ly+0.028)/0.042)**2-((lz-0.058)/0.04)**2)
            amount += 0.0026*cheek
            amount -= 0.0012*math.exp(-(lx/0.055)**2-((ly+0.09)/0.018)**2-((lz-0.05)/0.05)**2)
        elif kind == 'standard':
            # Helmet shell tooling and glove knuckle compression, kept below silhouette scale.
            centre = (0.77,1.69,0.39) if commander else (-0.68,1.43,-0.06)
            amount += 0.0006*math.sin(x*47+z*33)*gauss(p,centre,(0.18,0.13,0.18))
    elif kind == 'paint':
        # Rolled plate surface, broad shallow hand-worked irregularity, no pose drift.
        amount = 0.0008*math.sin(x*11.3+z*7.7)*math.sin(y*16.1+z*3.2)
    delta=Vector(n)*amount+garment_fit(p,batch)
    # Retain the installed loader's exact one-centimetre displacement contract.
    if delta.length>.0095:delta=delta.normalized()*.0095
    return Vector(p)+delta


def soften_joints(positions, points, normals, faces, batch):
    """Local Blender-mesh relaxation at soft neck and elbow transitions.

    Working if joint creases soften while hands, cuffs, faces and armour retain
    their existing positions, with every vertex inside the loader's 1cm limit.
    """
    if batch['frame']!='crew' or batch['kind'] not in ('skin','cloth'):
        return points,normals,0
    shirt_colours=((201,201,186),(119,123,110),(166,168,154),
                   (176,154,118),(113,101,79),(136,120,93))
    if batch['kind']=='cloth' and not any(max(abs(batch['colour'][i]-c[i]/255) for i in range(3))<.00001 for c in shirt_colours):
        return points,normals,0
    def weight(p):
        if batch['kind']=='skin':
            centre=(.744,1.466,.425) if p[0]>0 else (-.685,1.237,.065)
            ceiling=1.525 if p[0]>0 else 1.296
            return gauss(p,centre,(.09,.105,.09))*max(0.,min(1.,(ceiling-p[1])/.025))
        elbows=((.96,1.17,.58),(.52,1.24,.02)) if p[0]>0 else ((-.36,1.04,.15),(-1.02,1.035,.19))
        shoulders=((.87,1.45,.60),(.58,1.40,.26)) if p[0]>0 else ((-.49,1.265,.04),(-.88,1.235,.10))
        # Ease the angular deltoid/sleeve join within the same centimetre
        # envelope. Working if shoulders round off while wrists/grips retain
        # their source positions and every animated batch selector stays exact.
        return max(max(gauss(p,c,(.115,.10,.115)) for c in elbows),
                   max(.72*gauss(p,c,(.13,.115,.13)) for c in shoulders))
    # Weld only exact copies inside this source material batch. Other volumes,
    # original hard edges and semantic/material boundaries remain independent.
    lookup={};groups=[];indices=[]
    for i,p in enumerate(positions):
        key=tuple(round(v,7) for v in p)
        if key not in lookup:lookup[key]=len(groups);groups.append([])
        group=lookup[key];groups[group].append(i);indices.append(group)
    adjacent=[set() for _ in groups]
    for face in faces:
        for a,b in zip(face,face[1:]+face[:1]):
            a,b=indices[a],indices[b]
            if a!=b:adjacent[a].add(b);adjacent[b].add(a)
    weights=[weight(positions[g[0]]) for g in groups]
    if batch['kind']=='skin':
        # The source necks are independent connected surfaces. Use topology to
        # exclude the overlapping chin and all facial landmarks from relaxation.
        visited=set()
        for start in range(len(groups)):
            if start in visited:continue
            pending=[start];component=[]
            while pending:
                at=pending.pop()
                if at in visited:continue
                visited.add(at);component.append(at);pending.extend(adjacent[at]-visited)
            top=max(positions[groups[j][0]][1] for j in component)
            commander=positions[groups[start][0]][0]>0
            if top>(1.56 if commander else 1.33):
                for j in component:weights[j]=0.
    centres=[points[g[0]].copy() for g in groups]
    for _ in range(4):
        updated=[]
        for i,p in enumerate(centres):
            neighbours=adjacent[i]
            average=sum((centres[j] for j in neighbours),Vector())/len(neighbours) if neighbours else p
            updated.append(p.lerp(average,.58*weights[i]))
        centres=updated
    moved=0
    for i,p in enumerate(points):
        w=weights[indices[i]]
        if w<.0001:continue
        original=Vector(positions[i]);delta=centres[indices[i]]-original
        if delta.length>.0095:delta=delta.normalized()*.0095
        if (original+delta-p).length>1e-7:moved+=1
        points[i]=original+delta
    sums=[Vector() for _ in groups]
    for face in faces:
        a,b,c=face
        normal=(points[b]-points[a]).cross(points[c]-points[a])
        if normal.dot(normals[a])<0:normal=-normal
        for i in face:sums[indices[i]]+=normal
    for i,n in enumerate(normals):
        w=weights[indices[i]]
        if w>.0001 and sums[indices[i]].length>1e-9:
            averaged=sums[indices[i]].normalized()
            if averaged.dot(n)>.7:normals[i]=n.lerp(averaged,w).normalized()
    return points,normals,moved

bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
source_path = options.source.resolve()
source = json.loads(source_path.read_text())
result = {'schema':1,'source_sha256':hashlib.sha256(source_path.read_bytes()).hexdigest(),'batches':{}}
report=[]
for index,batch in enumerate(source['batches']):
    v=batch['vertices']; normals=batch['normals']; count=len(v)//3
    # Preserve split source vertices and exact topology, including authored hard edges.
    positions=[v[i:i+3] for i in range(0,len(v),3)]
    faces=[batch['indices'][i:i+3] for i in range(0,len(batch['indices']),3)] if batch['indices'] else [list(range(i,i+3)) for i in range(0,count,3)]
    mesh=bpy.data.meshes.new(f"{batch['frame']}_{index:03d}")
    mesh.from_pydata(positions,[],faces); mesh.update()
    ob=bpy.data.objects.new(mesh.name,mesh); bpy.context.collection.objects.link(ob)
    ob['source_batch_sha256']=batch['id']; ob['runtime_frame']=batch['frame']; ob['material_semantic']=batch['kind']
    # Godot y-up is shown in Blender z-up by an object-only rotation. Coordinates export unchanged.
    ob.rotation_euler=(math.pi/2,0,0)
    mat=bpy.data.materials.new(mesh.name+'_preview'); mat.diffuse_color=(*batch['colour'],1); ob.data.materials.append(mat)
    ob.shape_key_add(name='Basis'); sculpt=ob.shape_key_add(name='Fitted sleeves, relaxed joints and rolled armour')
    moved=0; peak=0.0; fitted=0; exported=[]; exported_normals=[]
    for i,vertex in enumerate(sculpt.data):
        point=displacement(positions[i],normals[i*3:i*3+3],batch)
        delta=(point-Vector(positions[i])).length
        if garment_fit(positions[i],batch).length>.0000001:fitted+=1
        if delta>0.0000001: moved+=1
        peak=max(peak,delta); vertex.co=point
        exported.extend(round(float(c),7) for c in point)
        normal=Vector(normals[i*3:i*3+3]).normalized()
        tangent=normal.cross(Vector((0,1,0)) if abs(normal.y)<0.9 else Vector((1,0,0))).normalized()
        bitangent=normal.cross(tangent).normalized()
        epsilon=0.00015
        a=displacement(Vector(positions[i])+tangent*epsilon,normal,batch)-point
        b=displacement(Vector(positions[i])+bitangent*epsilon,normal,batch)-point
        refined=a.cross(b).normalized()
        if refined.dot(normal)<0: refined=-refined
        exported_normals.extend(round(float(c),7) for c in refined)
    points,refined_normals,relaxed=soften_joints(positions,
        [Vector(exported[i:i+3]) for i in range(0,len(exported),3)],
        [Vector(exported_normals[i:i+3]) for i in range(0,len(exported_normals),3)],faces,batch)
    if relaxed:
        exported=[];exported_normals=[];peak=0.;moved=0
        for i,(point,normal) in enumerate(zip(points,refined_normals)):
            sculpt.data[i].co=point
            delta=(point-Vector(positions[i])).length;peak=max(peak,delta)
            if delta>1e-7:moved+=1
            exported.extend(round(float(c),7) for c in point)
            exported_normals.extend(round(float(c),7) for c in normal)
    sculpt.value=1.0
    # Differentiate the sculpt along each original split normal's tangent frame.
    # This follows tailored folds while preserving authored hard-edge splits.
    if moved:
        result['batches'][batch['id']]={'frame':batch['frame'],'count':count,'vertices':exported,'normals':exported_normals}
    report.append({'object':ob.name,'semantic':batch['kind'],'vertices':count,'moved':moved,'structurally_fitted_vertices':fitted,'relaxed_joint_vertices':relaxed,'max_displacement_m':peak})
# Pivots remain explicit collections/metadata; assemble a second preview using runtime offsets.
for ob in bpy.context.scene.objects:
    if ob.get('runtime_frame') in ('turret','crew'): ob.location=(0,0.1,1.4)
    elif ob.get('runtime_frame')=='barrel': ob.location=(0,1.77,2.14)
bpy.context.scene['authoring']='Blender mesh shape-key sculpt: fitted sleeves, relaxed neck/elbow transitions, connected trim/lining, both crew and tank plate finish; unchanged pose anchors and runtime materials'
bpy.ops.wm.save_as_mainfile(filepath=str(ART/'cover-authored.blend'),compress=True)
OUT.parent.mkdir(parents=True,exist_ok=True)
OUT.write_text(json.dumps(result,separators=(',',':'))+'\n')
(ART/'authoring-report.json').write_text(json.dumps({'source_sha256':result['source_sha256'],'runtime_sha256':hashlib.sha256(OUT.read_bytes()).hexdigest(),'batches':report},indent=2)+'\n')
print('COVER_BLENDER',len(result['batches']),'refined batches;',OUT.stat().st_size,'bytes')
