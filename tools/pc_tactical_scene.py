"""Tactical scene geometry and high-master mechanical surface detail.

Bridges retain their attributed topology. Buildings use source-bound construction
recipes; crews partition their original painter sheets into tailored materials.
High-master vehicle welds/fasteners bake onto the unchanged game mesh.
"""
import copy
import math
from collections import Counter

from tools.build_pc_modern_assets import bounds, validate_model


def geometry(base, master=False):
    if base['shape_index']==147:
        from tools.pc_tactical_cabin import geometry as cottage
        return cottage(base,master)
    if base["shape_index"] in (161,162):
        from tools.pc_tactical_crews import geometry as crew
        return crew(base,master)
    from tools.pc_tactical_architecture import SHAPES,geometry as architecture
    if base["shape_index"] in SHAPES:return architecture(base,master)
    from tools.pc_tactical_bridges import SHAPES as bridges,geometry as bridge
    if base['shape_index'] in bridges:return bridge(base,master)
    model=copy.deepcopy(base)
    # Flags and painted insignia stay in the source painter renderer. Their
    # subpixel tessellation must not be blurred into a large building UV tile.
    model['source_passthrough']={153:[27177],156:[28325]}.get(base['shape_index'],[])
    model['bounds']=bounds([v for t in model['triangles'] for v in t['vertices']])
    validate_model(model)
    return model


def mechanical_details(model):
    """Bake restrained weld seams and corner fasteners on large planar parts.

    Triangulation diagonals cancel. Curved castings, wreck fragments, flags,
    skin and original flat crew sheets never acquire invented panel grids.
    """
    from tools.build_pc_tactical_vehicles import tube
    shape=model['shape_index']
    if shape%2==0 and 115<=shape<=160 or shape in (161,162):return
    accepted=('glacis','fender','skirt_panel','stowage','toolbox','engine_deck',
              'rear_access','side_panel','load_bed','cab_roof','door','hatch')
    parts={}
    for t in model['triangles']:
        if not any(name in t['component'] for name in accepted):continue
        if t['material'] not in ('olive','olive_edge','hatch','equipment','steel'):continue
        key=(t['source_primitive'],t['component'])
        parts.setdefault(key,[]).append(t)
    sources={int(p['id']):dict(p,groups=[g['offset'] for g in model['groups'] if p['id'] in g['primitive_pointers']]) for p in model['source_primitives']}
    lo,hi=model['source_bounds']['min'],model['source_bounds']['max']
    additions=[]
    for (primitive,component),triangles in parts.items():
        edges=Counter()
        for t in triangles:
            points=[tuple(round(c,5) for c in v) for v in t['vertices']]
            for a,b in zip(points,points[1:]+points[:1]):edges[tuple(sorted((a,b)))]+=1
        used=0
        for (a,b),count in edges.items():
            length=math.dist(a,b)
            if count!=1 or length<8 or used>=8:continue
            # Remain strictly inside the immutable source envelope.
            radius=min(.16,length*.003)
            if any(min(a[k],b[k])-radius<lo[k] or max(a[k],b[k])+radius>hi[k] for k in range(3)):continue
            p=[a[k]+(b[k]-a[k])*.035 for k in range(3)]
            q=[a[k]+(b[k]-a[k])*.965 for k in range(3)]
            tube(additions,[sources[primitive]],p,q,radius,'olive_edge',component+'_weld_bead',6)
            used+=1
    model['triangles'].extend(additions)
    model['bounds']=bounds([v for t in model['triangles'] for v in t['vertices']])
    validate_model(model)
