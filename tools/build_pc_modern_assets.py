#!/usr/bin/env python3
"""Build local, source-bound faceted meshes. Standard library only; no game writes.

JSON is the runtime contract. GLB is an editable inspection export in the same
raw axes, deliberately without metre conversion or glTF Y-up rotation.
"""
from __future__ import annotations
import argparse
from collections import Counter
import hashlib
import json
import math
from pathlib import Path
import struct
try:
    from tools.pc_vehicle_catalog import ROOT, source_catalog, mesh_reference
    from tools.inspect_scenarios import decode_resource, parse_world, parse_scenario
    from tools.inspect_shapes import primitive_vertices
    from tools import source_guard
except ModuleNotFoundError as error:
    if error.name != 'tools': raise
    from pc_vehicle_catalog import ROOT, source_catalog, mesh_reference
    from inspect_scenarios import decode_resource, parse_world, parse_scenario
    from inspect_shapes import primitive_vertices
    import source_guard

SCHEMA = 1
TRACKED = {'T-62': 5, 'T-64': 6, 'T-72': 6, 'T-80': 6, 'M1-A1': 7,
           'M60a3': 6, 'M113': 5, 'M2': 6, 'BMP-1': 6, 'BMP-2': 6, 'ACRV-2': 7}
WHEELED = {'BTR-70': 4, 'BRDM-2': 2, 'BRDM-3': 2}
STRUCTURES = {0, 1, 45, 46, 47, 108, 114, *range(145, 159)}
BRIDGE_DECKS = {0, 1, 45, 46, 108, 114}
TWO_TONE_SHAPES = {129, 131, 133, 135, 137, 139, 141, 143, 159}
BUILDING_RUINS = {146, 148, 150, 152, 154, 158}
# Farm 157 combines two buildings and courtyard walls in one source group.
# Recess toward each building's own vertices, never the courtyard centroid.
FARM_PARTS = ((28681,28690,28699,28707,28715,28723), (28811,28819,28827,28841))
MATERIALS = {
    'olive': [107, 118, 75], 'olive_edge': [87, 98, 63],
    'track': [43, 46, 41], 'track_edge': [63, 65, 55],
    'wheel': [83, 92, 62], 'hub': [115, 120, 86],
    'plaster': [162, 153, 126], 'stone_edge': [118, 117, 99],
    'roof': [109, 105, 85], 'glass': [91, 137, 162],
    'wreck': [75, 70, 56], 'wreck_edge': [58, 56, 47],
    'bark': [103, 78, 49], 'foliage': [66, 94, 54],
    'tree_trunk': [103, 78, 49], 'tree_crown': [66, 94, 54],
    'earth': [134, 122, 87], 'grass': [117, 125, 75],
    'road': [112, 109, 94], 'water': [93, 120, 124],
    'hatch': [118, 126, 85], 'vent': [49, 57, 43],
    'cockpit': [105, 151, 178], 'door': [104, 94, 71],
    'tyre': [38, 42, 39], 'canvas': [158, 148, 113], 'canvas_edge': [132, 125, 96],
    'steel': [90, 99, 94], 'cloth': [99, 114, 76],
    'lamp': [183, 181, 151],
    'yard_grass': [76, 132, 55], 'timber': [76, 100, 96],
    'roof_clay': [198, 119, 48], 'roof_slate': [65, 79, 89],
    'roof_ridge': [172, 53, 39], 'signal_red': [189, 48, 35],
    'cloth_light': [150, 165, 102], 'cloth_shadow': [86, 112, 68],
    'webbing': [177, 155, 100], 'leather': [70, 58, 40],
    'skin': [204, 151, 108], 'equipment': [101, 125, 81],
    'equipment_edge': [58, 76, 58], 'optic': [42, 75, 88],
    'ruin_void': [35, 38, 35], 'ruin_mortar': [100, 96, 84],
    'ruin_stone': [169, 160, 139], 'ruin_plaster': [203, 192, 164],
    'ruin_brick': [153, 91, 63], 'ruin_char': [66, 64, 58],
    'insignia_white': [239, 235, 212], 'insignia_red': [190, 43, 32],
    'insignia_gold': [224, 184, 82], 'army_flag': [72, 88, 57],
    'us_flag_red': [182, 40, 48], 'us_flag_white': [246, 243, 231],
    'us_flag_blue': [38, 57, 101],
}
# Small authored paint differences, not faction colours or random camouflage.
VEHICLE_PAINT = {
    'T-62': [115,126,81], 'T-64': [104,121,87], 'T-72': [109,124,78],
    'T-80': [102,121,90], 'M1-A1': [126,133,93], 'M60a3': [120,130,86],
    'M113': [112,127,89], 'M2': [119,131,94], 'BMP-1': [107,127,84],
    'BMP-2': [105,126,85], 'BTR-70': [108,127,91], 'ACRV-2': [108,123,91],
    'BRDM-2': [113,129,85], 'BRDM-3': [109,127,86], 'HIND': [116,128,86],
    'Truck': [111,124,89], 'F-ST': [109,121,88],
}
WALL_PAINT = {47:[209,214,202],145:[182,203,175],147:[231,206,162],
              149:[197,212,218],151:[230,222,197],153:[204,211,193],
              155:[161,192,178],157:[239,227,193]}
ROOF_PAINT = {47:[61,75,88],145:[104,123,135],147:[133,99,71],
              149:[78,104,120],151:[56,66,75],153:[78,94,101],155:[66,106,99]}
DOOR_PAINT = {47:[76,103,100],145:[77,109,115],147:[73,103,106],149:[95,104,98],
              151:[79,105,85],153:[84,106,122],155:[119,108,78],157:[67,95,91]}
# Slot 156 is a complete base compound, despite occupying the class table's
# replacement field. Preserve that source association without painting it wrecked.
WALL_PAINT[156]=[213,209,181]
ROOF_PAINT[156]=[76,98,83]
DOOR_PAINT[156]=[66,90,71]


def is_wreck(index, roles):
    return index!=156 and any(r['variant']=='replacement' for r in roles)


def sub(a, b): return [a[i] - b[i] for i in range(3)]
def dot(a, b): return sum(x*y for x, y in zip(a, b))
def cross(a, b): return [a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0]]
def lerp(a, b, t): return [a[i] * (1-t) + b[i]*t for i in range(3)]
def center(points): return [sum(p[i] for p in points)/len(points) for i in range(3)]
def area2(tri): return math.sqrt(dot(n := cross(sub(tri[1], tri[0]), sub(tri[2], tri[0])), n))
def bounds(points):
    return {'min': [min(p[a] for p in points) for a in range(3)],
            'max': [max(p[a] for p in points) for a in range(3)]} if points else None


def clean_polygon(points):
    out = []
    for point in points:
        if not out or point != out[-1]: out.append(list(point))
    if len(out) > 1 and out[0] == out[-1]: out.pop()
    return out


def triangulate(points):
    """Ear clipping, including concave source faces, with no invented fan area."""
    points = clean_polygon(points)
    if len(points) < 3: return []
    normal = [0., 0., 0.]
    for a, b in zip(points, points[1:]+points[:1]):
        normal = [normal[k]+cross(a, b)[k] for k in range(3)]
    if max(map(abs, normal)) < 1e-9: return []
    drop = max(range(3), key=lambda a: abs(normal[a]))
    axes = [a for a in range(3) if a != drop]
    p2 = [[p[a] for a in axes] for p in points]
    def turn(a, b, c): return (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])
    signed = sum(a[0]*b[1]-b[0]*a[1] for a,b in zip(p2,p2[1:]+p2[:1]))
    sign = 1 if signed > 0 else -1
    remaining = list(range(len(points))); result = []
    while len(remaining) > 3:
        found = False
        for j, b in enumerate(remaining):
            a, c = remaining[j-1], remaining[(j+1)%len(remaining)]
            t = turn(p2[a], p2[b], p2[c])*sign
            if abs(t) < 1e-8:
                remaining.pop(j); found = True; break
            if t < 0: continue
            if any(all(turn(p2[u], p2[v], p2[k])*sign >= -1e-8
                       for u,v in ((a,b),(b,c),(c,a))) for k in remaining if k not in (a,b,c)):
                continue
            result.append([points[a],points[b],points[c]])
            remaining.pop(j); found = True; break
        if not found:
            raise ValueError('source polygon cannot be triangulated without overlap')
    tri = [points[k] for k in remaining]
    if area2(tri) > 1e-8: result.append(tri)
    return result


def add_face(output, points, material, primitive, groups, component):
    for tri in triangulate(points):
        normal = cross(sub(tri[1], tri[0]), sub(tri[2], tri[0]))
        # Mild baked hemispheric light: face-up facets stay bright and vertical
        # surfaces darken. Absolute height normal tolerates original two-sided
        # winding; no unverified sun direction or scene illumination is invented.
        shade = .76 + .24 * abs(normal[2]) / math.sqrt(dot(normal, normal))
        output.append({'vertices': [[round(c, 6) for c in v] for v in tri],
                       'color': [round(c * shade) for c in MATERIALS[material]], 'material': material,
                       'source_primitive': primitive, 'source_groups': groups,
                       'component': component})


def inset_outline(points, fraction):
    """Constant-width bevel in a convex face's plane, independent of edge length."""
    ctr=center(points)
    tri=triangulate(points)[0]
    n=cross(sub(tri[1],tri[0]),sub(tri[2],tri[0])); length=math.sqrt(dot(n,n))
    n=[v/length for v in n]; normals=[]
    for a,b in zip(points,points[1:]+points[:1]):
        v=cross(n,sub(b,a)); length=math.sqrt(dot(v,v)); v=[c/length for c in v]
        if dot(v,sub(ctr,a))<0:v=[-c for c in v]
        normals.append(v)
    width=min(dot(v,sub(ctr,a)) for v,a in zip(normals,points))*fraction
    inner=[]
    for i,p in enumerate(points):
        a,b=normals[i-1],normals[i]; denominator=1+dot(a,b)
        if denominator<1e-8:return [lerp(p,ctr,fraction) for p in points]
        inner.append([p[k]+(a[k]+b[k])*width/denominator for k in range(3)])
    if any(dot(n,sub(p,a)) < -1e-7 for p in inner for n,a in zip(normals,points)):
        return [lerp(p,ctr,fraction) for p in points]
    return inner


def inset_patch(output, points, material, edge, primitive, groups, depth=0., inward=None, bevel=.045):
    """Preserve every outer edge; bevel only inward into the owning source part."""
    points = clean_polygon(points)
    source_triangles = triangulate(points)
    if not source_triangles: return
    # Interior triangulation edges are not panel seams. Concave/nonplanar source
    # faces keep their original facets instead of acquiring little inset triangles.
    n = cross(sub(source_triangles[0][1],source_triangles[0][0]),sub(source_triangles[0][2],source_triangles[0][0]))
    nn = math.sqrt(dot(n,n)); n = [v/nn for v in n]
    convex = all(dot(cross(sub(points[(i+1)%len(points)], points[i]),
                           sub(points[(i+2)%len(points)], points[(i+1)%len(points)])), n) >= -1e-7
                 for i in range(len(points)))
    planar = all(abs(dot(sub(p, points[0]),n)) < 1e-6 for p in points)
    if not convex or not planar:
        add_face(output,points,material,primitive,groups,'source_facet')
        return
    for poly in [points]:
        inner = inset_outline(poly,bevel)
        if inward is not None:
            inner = [lerp(p, inward, depth) for p in inner]
        for i in range(len(poly)):
            j = (i+1)%len(poly)
            add_face(output,[poly[i],poly[j],inner[j],inner[i]],edge,primitive,groups,'bevel')
        add_face(output,inner,material,primitive,groups,'panel')


def inside_convex_yz(point, polygon):
    signs = []
    for a,b in zip(polygon, polygon[1:]+polygon[:1]):
        signs.append((b[1]-a[1])*(point[2]-a[2])-(b[2]-a[2])*(point[1]-a[1]))
    return min(signs) >= -1e-7 or max(signs) <= 1e-7


def wheel(output, x, y, z, radius, depth, side, primitive, groups, component, tyre=False):
    """Closed eight-sided wheel relief, entirely inward of original side plane."""
    back = [[x-side*depth,y+math.cos(i*math.tau/8)*radius,z+math.sin(i*math.tau/8)*radius] for i in range(8)]
    front = [[x-side*depth*.10,p[1],p[2]] for p in back]
    add_face(output,back[::-1],'track',primitive,groups,component)
    first=len(output)
    add_face(output,front,'tyre' if tyre else 'wheel',primitive,groups,component)
    for tri in output[first:]:
        tri['motion']={'kind':'wheel','center':[front[0][0],y,z],'radius':radius}
    for i in range(8):
        j=(i+1)%8
        add_face(output,[back[i],back[j],front[j],front[i]],'tyre' if tyre else 'track_edge',primitive,groups,component)
    hub_radius=.49 if tyre else .31
    hub = [[x-side*depth*.06,y+math.cos(i*math.tau/8)*radius*hub_radius,z+math.sin(i*math.tau/8)*radius*hub_radius] for i in range(8)]
    # A solid hub also has a back cap; topology tests apply per component.
    hb = [[front[0][0],p[1],p[2]] for p in hub]
    add_face(output,hb[::-1],'wheel',primitive,groups,component+'_hub')
    first=len(output)
    add_face(output,hub,'hub',primitive,groups,component+'_hub')
    for tri in output[first:]:
        tri['motion']={'kind':'wheel','center':[hub[0][0],y,z],'radius':radius}
    for i in range(8):
        j=(i+1)%8
        add_face(output,[hb[i],hb[j],hub[j],hub[i]],'wheel',primitive,groups,component+'_hub')


def track_patch(output, points, primitive, groups, count, inward, tracked=True):
    """Source hull side becomes one continuous band around polygonal wheel relief."""
    points = clean_polygon(points); ctr=center(points)
    # Original silhouette retained; dark continuous outer ring is useful geometry.
    inner=[lerp(p,ctr,.13) for p in points]
    side=1 if ctr[0] >= 0 else -1
    depth=max(.25,abs(ctr[0])*.06)
    back=[[p[0]-side*depth,p[1],p[2]] for p in inner]
    for i in range(len(points)):
        j=(i+1)%len(points)
        add_face(output,[points[i],points[j],inner[j],inner[i]],'track' if tracked else 'olive',primitive,groups,'track_band' if tracked else 'body_rim')
        add_face(output,[inner[i],inner[j],back[j],back[i]],'track_edge',primitive,groups,'track_recess')
    add_face(output,back,'track' if tracked else 'olive_edge',primitive,groups,'track_back')
    b=bounds(points); low,high=b['min'],b['max']; h=high[2]-low[2]
    radius=min(h*.32,(high[1]-low[1])/(count*2.35))
    z=low[2]+h*.47
    # Fit all road wheels to the usable cross-section rather than silently
    # dropping wheels near source-slope corners. Reduce radius when necessary.
    for _ in range(12):
        candidates=[]
        for sample in range(257):
            y=low[1]+(high[1]-low[1])*sample/256
            ring=[[ctr[0],y+math.cos(j*math.tau/8)*radius,z+math.sin(j*math.tau/8)*radius] for j in range(8)]
            if all(inside_convex_yz(p,inner) for p in ring): candidates.append(y)
        if candidates and (count==1 or candidates[-1]-candidates[0]>=radius*2.05*(count-1)):
            break
        radius*=.85
    if not candidates: raise ValueError('wheel fit failed inside source side')
    start,end=candidates[0],candidates[-1]
    for i in range(count):
        y=start+(end-start)*i/max(1,count-1)
        ring=[[ctr[0],y+math.cos(j*math.tau/8)*radius,z+math.sin(j*math.tau/8)*radius] for j in range(8)]
        if all(inside_convex_yz(p,inner) for p in ring):
            wheel(output,ctr[0],y,z,radius,depth,side,primitive,groups,f'wheel_{primitive}_{i}',tyre=not tracked)



def surface_relief(output, outline, material, edge, primitive, groups, inward, component, border=.14, closed=True, depth_scale=1.):
    """Closed shallow inset badge. Both caps stay behind the original face.

    The .025-recessed base panel sits behind this .006..018 relief. No coplanar
    overlay, outward extrusion or alpha texture is needed. The outline must be
    contained in its source face; face_outline supplies that check.
    """
    if not outline: return
    ctr=center(outline)
    front=[lerp(p,inward,.006*depth_scale) for p in outline]
    back=[lerp(p,inward,.018*depth_scale) for p in outline]
    inner=[lerp(lerp(p,ctr,border),inward,.010*depth_scale) for p in outline]
    for i in range(len(outline)):
        j=(i+1)%len(outline)
        if closed:add_face(output,[back[i],back[j],front[j],front[i]],edge,primitive,groups,component)
        add_face(output,[front[i],front[j],inner[j],inner[i]],edge,primitive,groups,component)
    if closed:add_face(output,back[::-1],edge,primitive,groups,component)
    add_face(output,inner,material,primitive,groups,component)


def face_outline(points, axes, coordinates):
    """Lift a convex 2D detail onto a planar source face, rejecting outside points."""
    triangles=triangulate(points)
    if not triangles:return []
    normal=cross(sub(triangles[0][1],triangles[0][0]),sub(triangles[0][2],triangles[0][0]))
    drop=next(a for a in range(3) if a not in axes)
    if abs(normal[drop])<1e-8:return []
    if any(abs(dot(sub(p,points[0]),normal))>1e-5 for p in points):return []
    result=[]
    for u,v in coordinates:
        signs=[(b[axes[0]]-a[axes[0]])*(v-a[axes[1]])-(b[axes[1]]-a[axes[1]])*(u-a[axes[0]])
               for a,b in zip(points,points[1:]+points[:1])]
        if min(signs)<-1e-7 and max(signs)>1e-7:return []
        p=[0.,0.,0.];p[axes[0]]=u;p[axes[1]]=v
        p[drop]=(dot(normal,points[0])-dot(normal,p))/normal[drop]
        result.append(p)
    return result


def rectangle(x0,y0,x1,y1):return [(x0,y0),(x1,y0),(x1,y1),(x0,y1)]


def vehicle_details(output, points, primitive, groups, inward, turret=False, deck_end=None):
    """Sparse face-bound hatches or rear-deck louvres, never external stowage."""
    b=bounds(points); lo,hi=b['min'],b['max']
    if hi[2]-lo[2]>4 or lo[2]<0 or hi[0]-lo[0]<25 or hi[1]-lo[1]<25:return
    def detail(coords,mat,label):
        surface_relief(output,face_outline(points,(0,1),coords),mat,'olive_edge',primitive,groups,inward,label)
    w=hi[0]-lo[0]; length=hi[1]-lo[1]
    if turret:
        # Low-profile octagonal hatches stay on the original roof. No new cupola.
        radius=min(w*.12,length*.15)
        for i,u in enumerate((.30,.70)):
            x=lo[0]+w*u;y=lo[1]+length*.52
            detail([(x+radius*math.cos(j*math.tau/8),y+radius*math.sin(j*math.tau/8)) for j in range(8)],'hatch',f'hatch_{i}')
    else:
        start=lo[1]+length*.035
        end=min(lo[1]+length*.28,deck_end-length*.018) if deck_end is not None else lo[1]+length*.28
        if end<=start:return
        step=(end-start)/4
        for i in range(4):
            y=start+step*i
            detail(rectangle(lo[0]+w*.24,y,lo[0]+w*.76,y+step*.48),'vent',f'engine_louvre_{i}')


def facade_details(output, points, primitive, groups, inward):
    """Recessed facade openings on source wall planes, with no new volume outside."""
    points = clean_polygon(points)
    if len(points) != 4: return
    constant = [a for a in (0, 1) if len({p[a] for p in points}) == 1]
    if len(constant) != 1: return
    axis = constant[0]; along = 1-axis; b = bounds(points)
    width = b['max'][along]-b['min'][along]; height=b['max'][2]-b['min'][2]
    if width <= 0 or height <= 0 or width/height > 5: return
    # Avoid adding openings across non-rectangular source-wall cutouts.
    if len({p[along] for p in points}) != 2 or len({p[2] for p in points}) != 2:return
    def detail(u0,v0,u1,v1,mat,label):
        coords=rectangle(b['min'][along]+width*u0,b['min'][2]+height*v0,
                         b['min'][along]+width*u1,b['min'][2]+height*v1)
        surface_relief(output,face_outline(points,(along,2),coords),mat,'stone_edge',primitive,groups,inward,label,closed=False)
    # Near-square panes, measured in source units rather than stretched UVs.
    pane=min(height*.25,width*.22); count=4 if width/height>2.4 else 2
    for number in range(count):
        u=(number+.5)/count
        detail(u-pane/width*.5,.49,u+pane/width*.5,.49+pane/height,'glass',f'window_{number}')
    if axis==1 and points[0][axis]<inward[axis]:
        half=min(height*.10/width,.11)
        detail(.5-half,.07,.5+half,.45,'door','door')
        detail(.045,.045,.5-half,.105,'stone_edge','plinth_left')
        detail(.5+half,.045,.955,.105,'stone_edge','plinth_right')
    else:detail(.045,.045,.955,.105,'stone_edge','plinth')
    detail(.045,.88,.955,.925,'stone_edge','eave')


def upper_side_armour(output, points, primitive, groups, inward):
    """Keep the upper APC hull olive while wheels remain visible below it."""
    cut=bounds(points)['min'][2]+(bounds(points)['max'][2]-bounds(points)['min'][2])*.61
    outline=[]
    for a,b in zip(points,points[1:]+points[:1]):
        if a[2]>=cut:outline.append(a)
        if (a[2]>=cut)!=(b[2]>=cut):outline.append(lerp(a,b,(cut-a[2])/(b[2]-a[2])))
    surface_relief(output,outline,'olive','olive_edge',primitive,groups,inward,'upper_side_armour',.055,depth_scale=.25)


def hind_details(output, points, primitive, groups, inward, prefix):
    """Glazing follows the two original HIND forms, including alternate rotor state."""
    def detail(axes,coords,mat,label):
        surface_relief(output,face_outline(points,axes,coords),mat,'olive_edge',primitive,groups,inward,label,.09,closed=False)
    # Source selector bytes identify matching faces in both alternate definitions.
    selector=prefix[0]
    if selector in (40,53):
        # Two windscreens with a deliberately clear centre mullion. Bilinear
        # interpolation stays exactly on these verified planar source quads.
        for n,(u0,u1) in enumerate(((.055,.475),(.525,.945))):
            outline=[lerp(lerp(points[0],points[1],u),lerp(points[3],points[2],u),v)
                     for u,v in rectangle(u0,.09,u1,.91)]
            surface_relief(output,outline,'cockpit','olive_edge',primitive,groups,inward,f'cockpit_front_{selector}_{n}',.07,closed=False)
    if selector in (36,37):
        detail((1,2),[(150,9),(276,9),(226,55),(150,55)],'cockpit','cockpit_side')
        for n,y in enumerate((0,67)):
            detail((1,2),rectangle(y,5,y+49,45),'glass',f'cabin_window_{n}')
    if selector in (50,51):
        detail((1,2),[(105,65),(202,65),(104,98),(80,98)],'cockpit','cockpit_upper_side')
        detail((1,2),rectangle(-24,73,38,94),'vent','engine_side_vent')
    if selector==52:
        for n,(x0,x1) in enumerate(((-54,-20),(20,54))):
            detail((0,1),rectangle(x0,-22,x1,42),'vent',f'engine_intake_{n}')


def truck_details(output, points, primitive, groups, inward, selector):
    """Cab glazing, grille and hub caps within the truck's original polygons."""
    def detail(axes,coords,mat,label):
        surface_relief(output,face_outline(points,axes,coords),mat,'olive_edge',primitive,groups,inward,label,.1,closed=False)
    if selector==79:
        for n,(x0,x1) in enumerate(((-39,-3),(3,39))):
            detail((0,2),rectangle(x0,18,x1,37),'cockpit',f'truck_windscreen_{n}')
    if selector in (70,71):
        detail((1,2),rectangle(49,18,75,36),'cockpit','truck_side_window')
        detail((1,2),rectangle(67,9,75,11),'steel','truck_door_handle')
    if selector==203:
        for n,z in enumerate((-13,-8,-3)):
            detail((0,2),rectangle(-21,z,21,z+2),'vent',f'truck_grille_{n}')
        for n,(x0,x1) in enumerate(((-39,-29),(29,39))):
            detail((0,2),rectangle(x0,-1,x1,5),'lamp',f'truck_lamp_{n}')
    if selector in (221,226):
        ctr=center(points);r=6.0
        detail((1,2),[(ctr[1]+math.cos(i*math.tau/8)*r,ctr[2]+math.sin(i*math.tau/8)*r) for i in range(8)],'steel','truck_hub')


def clip_plane(points, axis, value, positive):
    """Clip in the original face plane. Used to partition, never overlay, paint."""
    result=[]
    for a,b in zip(points,points[1:]+points[:1]):
        da=(a[axis]-value)*(1 if positive else -1)
        db=(b[axis]-value)*(1 if positive else -1)
        if da>=0:result.append(a)
        if (da>=0)!=(db>=0):result.append(lerp(a,b,da/(da-db)))
    return clean_polygon(result)


def painted_sheet(output, points, primitive, groups, base, regions):
    """Non-overlapping x/z colour patches on the source's two-sided crew sheets.

    Each rectangle partitions existing triangles, so sleeves, straps and equipment
    panels add neither silhouette coverage nor coplanar layers that could flicker.
    """
    pieces=[(tri,base,'crew_fabric') for tri in triangulate(points)]
    for (x0,z0,x1,z1),material,component in regions:
        updated=[]
        for poly,old_material,old_component in pieces:
            inner=poly
            for axis,value,positive in ((0,x0,True),(0,x1,False),(2,z0,True),(2,z1,False)):
                outside=clip_plane(inner,axis,value,not positive)
                if triangulate(outside):updated.append((outside,old_material,old_component))
                inner=clip_plane(inner,axis,value,positive)
                if not triangulate(inner):break
            else:
                updated.append((inner,material,component))
        pieces=updated
    for poly,material,component in pieces:
        add_face(output,poly,material,primitive,groups,component)


def crew_details(output, points, primitive, groups, part):
    """Tailored low-poly colour facets, keeping both original weapon-team poses.

    Parts are the original primitive order shared by 161/162, not inferred bones.
    The circular head remains the separate, original raster command.
    """
    box=bounds(points);lo,hi=box['min'],box['max']
    x0,x1=lo[0],hi[0];z0,z1=lo[2],hi[2]
    regions=[];base='cloth'
    def patch(rect,material,label):regions.append((rect,material,label))
    if part==0:
        patch((-40,-27,50,-14),'cloth_light','crew_shoulders')
        patch((-40,-60,-7,-27),'cloth_shadow','crew_jacket_fold')
        for a,b in ((-10,-6),(8,12)):
            patch((a,-51,b,-24),'webbing','crew_shoulder_strap')
        patch((-4,-38,5,-29),'cloth_shadow','crew_chest_pocket')
        patch((-4,-31,5,-28),'cloth_light','crew_pocket_flap')
        patch((-40,-56,50,-51),'leather','crew_belt')
        patch((-1,-55,4,-52),'webbing','crew_buckle')
        patch((-5,-20,5,-14),'skin','crew_neck')
    elif part in (1,2,3,4):
        patch((x0,z0,(x0+x1)*.5,z1),'cloth_shadow','crew_trouser_fold')
        patch((x0,-100,x1,-80),'leather','crew_boot')
        patch((x0,-83,x1,-80),'webbing','crew_boot_cuff')
    elif part in (5,6,8,9):
        patch((x0,z0,x1,z0+(z1-z0)*.28),'cloth_shadow','crew_sleeve_fold')
        if part==8:
            patch((x0,-22,x1,-19),'webbing','crew_cuff')
            patch((x0,-19,x1,z1),'skin','crew_hand')
        elif part in (5,6):
            patch((3,-40,11,-31),'skin','crew_hand')
    elif part in (10,11):
        base='equipment_edge'
        patch((x0+1.3,z0+1.3,x1-1.3,z1-1.3),'equipment','launcher_panel')
        if part==10:
            for z in (-13,-5,2):
                patch((x0+2,z,x1-2,z+1.5),'webbing','launcher_band')
            patch((x0+4,-11,x0+10,-3),'optic','launcher_sight')
        else:
            patch((x0+2,18,x1-2,22),'optic','launcher_optic')
            patch((x0+1,6,x1-1,8),'steel','launcher_collar')
    painted_sheet(output,points,primitive,groups,base,regions)


def star_outline(cx, cy, radius):
    return [(cx+math.sin(i*math.pi/5)*radius*(1 if i%2==0 else .382),
             cy+math.cos(i*math.pi/5)*radius*(1 if i%2==0 else .382)) for i in range(10)]


def paint_polygon(output, points, primitive, groups, base, outline, ink, label):
    """Partition a flat flag into disjoint colour facets, with no overlay."""
    pieces=[(tri,base,'flag_field') for tri in triangulate(points)]
    for patch in triangulate(outline):
        n=cross(sub(patch[1],patch[0]),sub(patch[2],patch[0]))
        def clip(poly,a,b,inside):
            normal=cross(n,sub(b,a));result=[]
            for p,q in zip(poly,poly[1:]+poly[:1]):
                dp=dot(sub(p,a),normal)*(1 if inside else -1)
                dq=dot(sub(q,a),normal)*(1 if inside else -1)
                if dp>=-1e-8:result.append(p)
                if (dp>=0)!=(dq>=0):result.append(lerp(p,q,dp/(dp-dq)))
            return clean_polygon(result)
        updated=[]
        for poly,mat,component in pieces:
            inner=poly
            for a,b in zip(patch,patch[1:]+patch[:1]):
                outside=clip(inner,a,b,False)
                if sum(area2(t) for t in triangulate(outside))>1e-6:updated.append((outside,mat,component))
                inner=clip(inner,a,b,True)
                if sum(area2(t) for t in triangulate(inner))<=1e-6:break
            else:updated.append((inner,ink,label))
        pieces=updated
    for poly,mat,component in pieces:
        for triangle in triangulate(poly):
            rounded=[[round(v,6) for v in p] for p in triangle]
            if area2(rounded)>1e-8:add_face(output,rounded,mat,primitive,groups,component)


def base_insignia(output, points, primitive, groups, inward, index):
    """Small source-bounded Army stars on existing gables or cube walls."""
    if index not in (153,155,156):return
    box=bounds(points);lo,hi=box['min'],box['max']
    n=cross(sub(points[1],points[0]),sub(points[2],points[0]))
    if index in (153,156):
        if abs(n[2])>max(abs(n[0]),abs(n[1])) and hi[2]>=399:
            # Roof recognition marks remain legible at normal gameplay scale.
            cx=(lo[0]+hi[0])*.5;cz=(lo[1]+hi[1])*.5;radius=185;axes=(0,1)
        else:
            if hi[1]-lo[1]>1e-6 or hi[2]<399:return
            cx=-500 if index==153 else 0;cz=315;radius=65;axes=(0,2)
    else:
        if hi[2]-lo[2]<1:return
        axes=(0,2) if hi[1]-lo[1]<1e-6 else (1,2)
        cx=0;cz=90;radius=25
    outline=face_outline(points,axes,star_outline(cx,cz,radius))
    white=index!=153
    surface_relief(output,outline,'insignia_white' if white else 'insignia_red',
                   'army_flag' if white else 'insignia_gold',primitive,groups,inward,
                   'us_army_star' if white else 'soviet_star',.13,closed=False,depth_scale=.5)


def american_flag(output, points, primitive, groups):
    """Thirteen stripes and fifty stars, partitioning the existing flag plane.

    Star cells use disjoint radial sectors rather than coplanar overlays or
    repeated polygon subtraction. The original flag size and pole are retained.
    """
    box=bounds(points);x0,_,z0=box['min'];x1,_,z1=box['max']
    width=x1-x0;height=z1-z0;union_x=x0+width*.4;union_z=z1-height*7/13
    def face(coords,material,label):
        add_face(output,face_outline(points,(0,2),coords),material,primitive,groups,label)
    def rect(a,b,c,d,material,label):face(rectangle(a,b,c,d),material,label)
    for row in range(13):
        rect(union_x if row<7 else x0,z1-height*(row+1)/13,x1,z1-height*row/13,
             'us_flag_red' if row%2==0 else 'us_flag_white',f'us_flag_stripe_{row:02d}')
    dx=(union_x-x0)/6;dz=(z1-union_z)/10
    rect(x0,z1-dz*.5,union_x,z1,'us_flag_blue','us_flag_canton')
    rect(x0,union_z,union_x,union_z+dz*.5,'us_flag_blue','us_flag_canton')
    star=0
    for row in range(9):
        cy=z1-(row+1)*dz;count=6 if row%2==0 else 5
        if count==5:
            rect(x0,cy-dz*.5,x0+dx*.5,cy+dz*.5,'us_flag_blue','us_flag_canton')
            rect(union_x-dx*.5,cy-dz*.5,union_x,cy+dz*.5,'us_flag_blue','us_flag_canton')
        for column in range(count):
            cx=x0+(column+(.5 if count==6 else 1))*dx
            outline=star_outline(cx,cy,dz*.43)
            corners=sorted(((math.atan2(x-cx,z-cy)%math.tau,(x,z))
                            for x,z in rectangle(cx-dx*.5,cy-dz*.5,cx+dx*.5,cy+dz*.5)))
            outer=[]
            for i in range(10):
                a=i*math.pi/5;s,c=math.sin(a),math.cos(a)
                distance=min(dx*.5/max(abs(s),1e-12),dz*.5/max(abs(c),1e-12))
                outer.append((cx+s*distance,cy+c*distance))
            for i in range(10):
                j=(i+1)%10
                between=[corner for angle,corner in corners if i*math.pi/5+1e-9<angle<(i+1)*math.pi/5-1e-9]
                face([outline[i],outer[i],*between,outer[j],outline[j]],'us_flag_blue','us_flag_canton')
            face(outline,'us_flag_white',f'us_flag_star_{star:02d}')
            star+=1


def ruined_face(output, points, primitive, groups, inward, index):
    """Broken slabs and masonry inside the original damaged face envelope.

    Dark recessed backing preserves original occlusion. Uneven pieces retreat
    into the existing volume, exposing charcoal gaps and fractured edge faces.
    No rubble extends into adjacent roads or changes a simulation footprint.
    """
    palette=('ruin_stone','ruin_plaster','ruin_brick','ruin_char')
    for ti,tri in enumerate(triangulate(points)):
        add_face(output,[lerp(v,inward,.12) for v in tri],'ruin_void',primitive,groups,'ruin_interior')
        # Unequal edge splits prevent the intact regular panel appearance.
        ab=lerp(tri[0],tri[1],.39);bc=lerp(tri[1],tri[2],.58);ca=lerp(tri[2],tri[0],.47)
        mid=center(tri)
        cells=([tri[0],ab,mid,ca],[ab,tri[1],bc,mid],[mid,bc,tri[2],ca])
        for j,cell in enumerate(cells):
            seed=(primitive+ti*7+j*11)%17
            if seed%7==0:continue # collapsed/open section
            ctr=center(cell)
            inset=[lerp(v,ctr,.12 if j%2 else .20) for v in cell]
            # Uneven quadrilateral slabs read as masonry, rather than glass
            # shards, while retaining a small bounded mesh cost per wreck.
            rim=[lerp(inset[0],inset[-1],.19),inset[1],lerp(inset[2],inset[1],.13),inset[3]]
            # Large inward steps give broken thickness, rather than drawn cracks.
            top=[lerp(v,inward,.012+.011*((seed+k*3)%5)) for k,v in enumerate(rim)]
            floor=[lerp(v,inward,.12) for v in rim]
            mat=palette[(seed+j)%4]
            add_face(output,top,mat,primitive,groups,'ruin_broken_slab')
            for k in range(len(rim)):
                l=(k+1)%len(rim)
                add_face(output,[top[k],top[l],floor[l],floor[k]],'ruin_mortar',primitive,groups,'ruin_fracture')



def chamfered_part(primitives, groups, fraction=.22):
    """Truncate shared source corners, producing coherent broad turret facets.

    One shared centroid per original vertex keeps adjacent face corner caps joined.
    Each cap segment remains attributed to its original face; no part is moved,
    rotated or independently animated. This deliberately shrinks sharp corners.
    """
    neighbours={}
    for p in primitives:
        poly=clean_polygon(p['vertices'])
        for i,v in enumerate(poly):
            key=tuple(v)
            neighbours.setdefault(key,set()).update((tuple(poly[i-1]),tuple(poly[(i+1)%len(poly)])))
    caps={v:center([lerp(v,n,fraction) for n in ns]) for v,ns in neighbours.items()}
    output=[];inward=center([v for p in primitives for v in p['vertices']])
    for p in primitives:
        poly=clean_polygon(p['vertices']);face=[]
        if len(poly)<3:continue
        for i,v in enumerate(poly):
            a=lerp(v,poly[i-1],fraction);b=lerp(v,poly[(i+1)%len(poly)],fraction)
            face.extend((a,b))
            add_face(output,[a,b,caps[tuple(v)]],'olive_edge',p['id'],groups,'turret_corner_facet')
        if max(v[2] for v in face)-min(v[2] for v in face)<4:
            inset_patch(output,face,'olive','olive_edge',p['id'],groups,.025,inward)
            vehicle_details(output,face,p['id'],groups,inward,turret=True)
        else:add_face(output,face,'olive',p['id'],groups,'turret_plane')
    return output


def octagonal_barrel(primitives, groups, fraction=.292893):
    """Cut only cross-section corners; retain length, slanted breech and ownership.

    Each original side owns half of the adjacent diagonal facet. Muzzle cap is
    clipped to the shared rim (three points per cross-section vertex). The original open breech stays open.
    """
    neighbours={}
    for p in primitives:
        poly=p['vertices']
        for a,b in zip(poly,poly[1:]+poly[:1]):
            if a[0]!=b[0] or a[2]!=b[2]:
                neighbours.setdefault(tuple(a),set()).add(tuple(b))
                neighbours.setdefault(tuple(b),set()).add(tuple(a))
    if any(len(ns)!=2 for ns in neighbours.values()):
        raise ValueError('barrel cross-section must have two incident edges')
    mids={v:center([lerp(v,n,fraction) for n in ns]) for v,ns in neighbours.items()}
    origin=center([v for p in primitives for v in p['vertices']]);output=[]
    def face(points,material,p,component):
        n=cross(sub(points[1],points[0]),sub(points[2],points[0]))
        if dot(n,sub(center(points),origin))<0:points=points[::-1]
        add_face(output,points,material,p['id'],groups,component)
    for p in primitives:
        poly=p['vertices']
        if len({v[1] for v in poly})==1:
            # Split the diagonal rim at each shared side-facet midpoint so
            # muzzle topology has no T-junctions. Convex center fan is exact.
            rim=[]
            for i,v in enumerate(poly):
                rim.extend((lerp(v,poly[i-1],fraction),mids[tuple(v)],lerp(v,poly[(i+1)%len(poly)],fraction)))
            ctr=center(rim)
            bore=[lerp(v,ctr,.43) for v in rim]
            # A short dark bore is recessed into the existing barrel. The
            # outside rim, length and only open boundary (breech) stay fixed.
            depth=min(max(v[0] for v in rim)-min(v[0] for v in rim),
                      max(v[2] for v in rim)-min(v[2] for v in rim))*.45
            bore=[[v[0],v[1]-depth,v[2]] for v in bore]
            for i,a in enumerate(rim):
                j=(i+1)%len(rim)
                face([a,rim[j],bore[j],bore[i]],'olive_edge',p,'barrel_muzzle')
            # Retain the split diagonals so the ring and bore cap share edges.
            ctr=center(bore)
            for a,b in zip(bore,bore[1:]+bore[:1]):
                face([a,b,ctr],'vent',p,'barrel_bore')
            continue
        inset=[]
        for i,v in enumerate(poly):
            ns=[poly[j%len(poly)] for j in (i-1,i+1) if poly[j%len(poly)][0]!=v[0] or poly[j%len(poly)][2]!=v[2]]
            if len(ns)!=1:raise ValueError('barrel side must have one cross edge')
            inset.append(lerp(v,ns[0],fraction))
        face(inset,'olive',p,'barrel_plane')
        for i,a in enumerate(poly):
            j=(i+1)%len(poly);b=poly[j]
            if a[0]==b[0] and a[2]==b[2]:
                face([inset[i],inset[j],mids[tuple(b)],mids[tuple(a)]],'olive_edge',p,'barrel_corner_facet')
    return output


def visual_commands(shape):
    """Decoded round-form authoring records, never guessed polygon replacements."""
    records=[]
    for command in shape['opaque_commands']:
        data=bytes.fromhex(command['hex'])
        if len(data)!=4:continue
        records.append({'kind':'source_projected_round_form','command_offset':command['offset'],
                        'command_bytes':list(data),'sort_vector_encoded':data[0],
                        'radius_raw':data[1],'color_index':data[2],'center_vertex_encoded':data[3],
                        'center_raw':primitive_vertices(shape,{'encoded_indices':[data[3]]})[0],
                        'raster_entry':'0f8d:123e','projection_entry':'0b4d:31a6',
                        'runtime_binding':'Observe original raster radius,x,y at SS:SP+4,+6,+8; radius clamp102 and source clip remain authoritative.',
                        'status':'source_visual_command_requires_paired_raster'})
    return records


def collect_inventory(source, catalog, shapes):
    counts={}; class_counts={}; sources=dict(catalog['sources'])
    for number in range(8):
        world_name=f'SNARIO{number}.WLD'; scenario_name=f'SNARIO{number}.SSS'
        raw=(source/world_name).read_bytes(); sources[world_name]=hashlib.sha256(raw).hexdigest()
        world=parse_world(decode_resource(raw))
        counts[str(number)]=dict(sorted(Counter(e['shape_index'] for r in world['records'] for e in r['entries'] if not e['unused']).items()))
        raw=(source/scenario_name).read_bytes(); sources[scenario_name]=hashlib.sha256(raw).hexdigest()
        scenario=parse_scenario(decode_resource(raw))
        class_counts[str(number)]=dict(sorted(Counter(r['word_0'] for r in scenario['records']).items()))
    required={i for count in counts.values() for i in count}
    required.update(i for row in catalog['classes'] for i in row['shapes'].values() if i is not None)
    return {'sources':sources,'world_shape_counts':counts,'scenario_class_counts':class_counts,
            'required_shapes':sorted(required),'source_only_shapes':sorted(set(range(len(shapes)))-required)}


def material_for(index, roles, primitive):
    if index==103: return 'bark' if primitive['prefix_bytes'][1]==7 else 'foliage'
    if is_wreck(index,roles):return 'wreck'
    points=primitive['vertices'];selector=primitive['prefix_bytes'][0]
    if index in BRIDGE_DECKS:return 'stone_edge'
    if index in STRUCTURES:
        if index==47 and selector==25:return 'door'
        if index==47 and selector==27:return 'lamp'
        if index in (145,153,156) and primitive['prefix_bytes'][1:3]==[6,6]:return 'army_flag' if index==156 else 'signal_red'
        if index==151 and selector==18:return 'roof_ridge'
        if index==157:
            if selector==35:return 'yard_grass'
            if selector in (30,31):return 'roof_clay'
            if selector==41:return 'roof_slate'
            if selector in (29,42):return 'timber'
        if len(points)>=3:
            n=cross(sub(points[1],points[0]),sub(points[2],points[0]))
            if abs(n[2])>max(abs(n[0]),abs(n[1])) and min(p[2] for p in points)>0:return 'roof'
        return 'plaster'
    if index in (141,143) and selector in (71,72):return 'tyre'
    if index==159:
        if selector in (221,226,94,95,96,99):return 'tyre'
        if 85<=selector<=91:return 'canvas'
    if index in (161,162):
        if primitive['prefix_bytes'][1]==6 or primitive['prefix_bytes'][2]==6:return 'steel'
        return 'tyre' if points and max(p[2] for p in points)<=-60 else 'cloth'
    if index in (163,164) and primitive['prefix_bytes'][1]==6:return 'tyre'
    if index>=115:return 'glass' if index in (163,164) and primitive['prefix_bytes'][1]==4 else 'olive'
    m=primitive['prefix_bytes'][1]
    return 'water' if m==4 else 'road' if m==3 else 'grass' if m in (5,9,19) else 'earth'


def finish_colours(index, name, roles, output, primitives):
    """Authored flat materials and model-local fill; no textures or runtime lights."""
    replacement=is_wreck(index,roles)
    paint=VEHICLE_PAINT.get(name,MATERIALS['olive'])
    wall=WALL_PAINT.get(index,MATERIALS['plaster'])
    primitive_order={p['id']:i for i,p in enumerate(primitives)}
    source_material={p['id']:material_for(index,roles,p) for p in primitives}
    red_accents={p['id'] for p in primitives if p['prefix_bytes']==[255,6,6]}
    glass_bounds={}
    for tri in output:
        if tri['material'] in ('glass','cockpit'):
            key=(tri['source_primitive'],tri['component'])
            glass_bounds.setdefault(key,[]).extend(v[2] for v in tri['vertices'])
    for tri in output:
        material=tri['material'];rgb=MATERIALS[material]
        vs=tri['vertices'];normal=cross(sub(vs[1],vs[0]),sub(vs[2],vs[0]));length=math.sqrt(dot(normal,normal))
        nx,ny,nz=[abs(v)/length for v in normal]
        # Side/end planes now separate under an intentionally baked fill.
        # This is fixed object-local art, not a world-space shadow or sun.
        shade=min(1.0,.73+.27*nz+.08*nx)
        if index in WALL_PAINT and not replacement:shade=min(1.0,.83+.17*nz+.07*nx)
        if index in (161,162):shade=1.0
        if material.startswith('us_flag_'):
            shade=1.0
        elif material.startswith(('ruin_','insignia_')) or material=='army_flag':
            shade=max(.85,shade) if material.startswith('insignia_') else shade
        elif tri['source_primitive'] in red_accents:
            # Preserve the exact red source faces, including their existing
            # borders, weapon accents, and the flag still present on base wrecks.
            # This is a material correction only; never reroute mesh construction.
            tri['material']='signal_red'
            rgb=MATERIALS['signal_red'];shade=max(.92,shade)
        elif replacement:
            # Broad surviving paint, scorched metal and dull exposed edges.
            # Each original face owns a finish; no decals or extra rubble.
            tones=([145,137,118],[73,78,74],[175,163,139],[111,108,96]) if index in STRUCTURES else (
                [54,59,57],[c*.62+9 for c in paint],[98,110,108],[43,46,45])
            rgb=tones[primitive_order[tri['source_primitive']]%len(tones)]
            if material=='wreck_edge':rgb=[c*(1.06 if nz>.2 else .9) for c in rgb]
        elif index in BRIDGE_DECKS:rgb=[148,142,125]
        elif index==159 and source_material[tri['source_primitive']]=='canvas' and material in ('olive_edge','canvas_edge'):
            tri['material']='canvas_edge';rgb=MATERIALS['canvas_edge']
        elif material in ('olive','olive_edge','wheel','hub','hatch'):
            factor={'olive':1.,'olive_edge':.87,'wheel':.82,'hub':1.20,'hatch':1.12}[material]
            upper=sum(v[2] for v in vs)/3>=0
            if material=='olive' and upper:factor+=.075*nz
            if material=='hatch' and index in (115,117,119,121,125,127):factor+=.03
            if material=='olive_edge' and upper and nz>.35:
                factor=1.23 if tri['component'].startswith('hatch_') else 1.05
            rgb=[c*factor for c in paint]
        elif tri['component']=='truck_hub' and material=='steel':rgb=[145,153,139]
        elif material=='vent' and index in (115,117,119,121,125,127,159):rgb=[43,52,42]
        elif material=='door' and index in DOOR_PAINT:rgb=DOOR_PAINT[index]
        elif material=='plaster':rgb=wall
        elif material=='stone_edge':
            owning=source_material[tri['source_primitive']]
            base=MATERIALS[owning] if owning in ('roof_clay','roof_slate','roof_ridge','timber','yard_grass','signal_red') else ROOF_PAINT.get(index,wall) if owning=='roof' else wall
            rgb=[c*.75 for c in base]
            if tri['component'].startswith('window_'):rgb=[218,216,196]
            elif tri['component']=='eave':rgb=[c*.88 for c in wall]
            elif owning=='roof':rgb=[c*.88 for c in base]
        elif material=='roof':rgb=ROOF_PAINT.get(index,[c*.84 for c in wall])
        elif index in (161,162) and material in ('equipment','equipment_edge','webbing','skin','optic','steel'):
            rgb={'equipment':[70,92,78],'equipment_edge':[48,65,57],
                 'webbing':[187,164,112],'skin':[216,169,123],'optic':[65,102,116],
                 'steel':[119,132,125]}[material]
            if tri['component']=='launcher_band':rgb=[145,137,101]
        elif index==162 and material.startswith('cloth'):
            rgb=[rgb[0]*.90,rgb[1]*1.02,rgb[2]*1.08]
        elif material in ('glass','cockpit'):
            # Two broad, quiet glass facets; never a photographic reflection.
            z=sum(v[2] for v in vs)/3
            heights=glass_bounds[(tri['source_primitive'],tri['component'])]
            tone=.93+.22*(z-min(heights))/max(1,max(heights)-min(heights))
            rgb=[c*tone for c in rgb]
        tri['color']=[round(max(0,min(255,c*shade))) for c in rgb]


def build_model(shape, roles, placements, required):
    ref=mesh_reference(shape); index=shape['index']; output=[]; lines=[]
    vertices=[v for p in ref['primitives'] for v in p['vertices']]
    sb=bounds(vertices)
    group_by_primitive={p['id']:[g['offset'] for g in ref['groups'] if p['id'] in g['primitive_pointers']] for p in ref['primitives']}
    group_centers={g['offset']:center([v for p in ref['primitives'] if p['id'] in g['primitive_pointers'] for v in p['vertices']]) for g in ref['groups'] if g['primitive_pointers']}
    part_centers={}
    if index==157:
        for ids in FARM_PARTS:
            ctr=center([v for p in ref['primitives'] if p['id'] in ids for v in p['vertices']])
            part_centers.update({pid:ctr for pid in ids})
    if index==159:
        # Windscreen is its own flat render group. Its recess must point into
        # the cab volume, not toward a coplanar group centre (z-fighting).
        ids=(29685,29693,29741,29755)
        ctr=center([v for p in ref['primitives'] if p['id'] in ids for v in p['vertices']])
        part_centers.update({pid:ctr for pid in ids})
    if index==47:
        # The original door overlaps the hangar end wall. Give its inset a
        # genuine inward direction, then keep it ahead of the recessed wall.
        part_centers[4893]=center([v for p in ref['primitives'] if p['id'] in
                                  (4843,4851,4859,4867,4875,4884) for v in p['vertices']])
    if index in (141,143):
        for p in ref['primitives']:
            if p['prefix_bytes'][0] in (71,72):
                ctr=center(p['vertices']);ctr[0]=0
                part_centers[p['id']]=ctr
    name=roles[0]['name'] if roles else f'static_{index:03d}'
    turret_ids=set();barrel_ids=set()
    if index in (115,117,119,121,125,127):
        group=ref['groups'][1]
        turret_ids=set(group['primitive_pointers'])
        output.extend(chamfered_part([p for p in ref['primitives'] if p['id'] in turret_ids],[group['offset']]))
    if index in (115,117,119,121,125,127):
        group=ref['groups'][2 if index in (125,127) else -1]
        barrel_ids=set(group['primitive_pointers'])
        output.extend(octagonal_barrel([p for p in ref['primitives'] if p['id'] in barrel_ids],[group['offset']]))
    deck_end=min((v[1] for p in ref['primitives'] if p['id'] in turret_ids for v in p['vertices']),default=None)
    replacement=is_wreck(index,roles)
    known = 115<=index<=164 or index in STRUCTURES
    for part,p in enumerate(ref['primitives']):
        if p['id'] in turret_ids | barrel_ids:continue
        pts=clean_polygon(p['vertices']); groups=group_by_primitive[p['id']]
        tris=triangulate(pts)
        if not tris:
            lines.append({'source_primitive':p['id'],'source_groups':groups,'vertices':pts,'prefix_bytes':p['prefix_bytes']})
            if index in BRIDGE_DECKS and len(pts)==2:
                lines[-1]['color']=[133,157,171] if p['prefix_bytes'][1]==0 else [101,127,140]
            continue
        mat=material_for(index,roles,p)
        inward=part_centers.get(p['id'],group_centers.get(groups[0]) if groups else center(vertices))
        track=(index not in (141,143) and name in (TRACKED | WHEELED) and not replacement and len(pts)>=5 and
               len({v[0] for v in pts})==1 and abs(pts[0][0])>0 and min(v[2] for v in pts)<0 and
               groups and groups[0]==ref['groups'][0]['offset'])
        if index==156 and p['prefix_bytes']==[255,6,6]:
            american_flag(output,pts,p['id'],groups)
        elif index==153 and p['prefix_bytes']==[255,6,6]:
            box=bounds(pts);lo,hi=box['min'],box['max']
            outline=face_outline(pts,(0,2),star_outline((lo[0]+hi[0])*.5,(lo[2]+hi[2])*.5,(hi[2]-lo[2])*.36))
            paint_polygon(output,pts,p['id'],groups,'signal_red',outline,'insignia_gold','soviet_flag_star')
        elif index in BUILDING_RUINS:
            ruined_face(output,pts,p['id'],groups,inward,index)
        elif index in (161,162):
            crew_details(output,pts,p['id'],groups,part)
        elif index in BRIDGE_DECKS:
            # Deck sheets have no interior volume to recess toward.
            add_face(output,pts,mat,p['id'],groups,'source_plane')
        elif track:
            track_patch(output,pts,p['id'],groups,(TRACKED | WHEELED)[name],inward,name in TRACKED)
            if index in (129,131,133,135,137,139):
                upper_side_armour(output,pts,p['id'],groups,inward)
        elif known:
            edge='wreck_edge' if replacement else 'tyre' if mat=='tyre' else 'stone_edge' if index in STRUCTURES else 'olive_edge'
            # Pull toward the source part centroid; this is a convex combination
            # of source vertices, bounded by original part coordinates.
            # Keep unresolved F-ST source anatomy; no identity-specific additions.
            if index in (163,164) and p['prefix_bytes'][1]==4:mat='olive'
            # BRDM wheel polygons overlap the hull side in the original.
            # Distinct inward planes avoid coplanar depth fighting in previews.
            depth=.035 if index in (141,143) and mat=='tyre' else .025
            if index==47 and mat=='door':depth=.01
            inset_patch(output,pts,mat,edge,p['id'],groups,depth,inward,.12 if index in (123,124) else .045)
            if index in (145,147,149,151,153,155,156,157) and mat in ('plaster','timber'):
                facade_details(output,pts,p['id'],groups,inward)
            base_insignia(output,pts,p['id'],groups,inward,index)
            if name in (TRACKED | WHEELED) and not replacement and groups and groups[0]==ref['groups'][0]['offset']:
                vehicle_details(output,pts,p['id'],groups,inward,deck_end=deck_end)
            if index in (163,164):hind_details(output,pts,p['id'],groups,inward,p['prefix_bytes'])
            if index in (141,143) and mat=='tyre' and len(pts)==6:
                ctr=center(pts);r=7.0
                outline=face_outline(pts,(1,2),[(ctr[1]+math.cos(i*math.tau/8)*r,ctr[2]+math.sin(i*math.tau/8)*r) for i in range(8)])
                surface_relief(output,outline,'hub','tyre',p['id'],groups,inward,'source_wheel_hub',closed=False)
            if index==159:truck_details(output,pts,p['id'],groups,inward,p['prefix_bytes'][0])
        else:
            add_face(output,pts,mat,p['id'],groups,'source_surface')
    if known:finish_colours(index,name,roles,output,ref['primitives'])
    status='authored_mesh' if known else 'source_surface'
    caveats=[]
    if index in (123,124):
        status='conservative_refinement';caveats.append('F-ST identity unresolved; source form retained, no real-world vehicle inferred.')
    if index in (165,166):
        status='unresolved_placeholder';caveats.append('Class label identifies aircraft; source program is a cube with selector word16. Original isolated allocation selects this cube and ordinary mesh renderer; shipped-mission visibility and universal mutation absence remain unverified. See aircraft-research/REPORT.md.')
    if index==167:
        status='source_control_invisible';caveats.append('Bridge marker primitive prefix[130,255,2] is unconditionally skipped by original0b4d:0553..0574 before projection. No visible model or fabricated span.')
    if index==103:
        status='tree_sprite_template';caveats.append('Crossed crown triangles and trunk quads. Illustrated sprite art is external; never enlarge or billboard these planes.')
    if ref['opaque_commands']:
        status='partial_opaque' if output else 'source_command'
        caveats.append('Opaque commands retained; polygon mesh does not replace or complete the whole source program.')
    if lines:caveats.append('Source lines/degenerate primitives remain source-rendered; no arbitrary thickness introduced.')
    model={'shape_index':index,'name':name,'class_roles':roles,'required':required,'scenario_placements':placements,
           'status':status,'pivot':[0,0,0],'axes':'raw primitive_vertices x/y/z; z is original height; no physical unit conversion',
           'source_bounds':sb,'bounds':bounds([v for t in output for v in t['vertices']]),
           'dimensions_raw':[sb['max'][a]-sb['min'][a] for a in range(3)] if sb else None,
           'triangles':output,'source_lines':lines,'source_primitives':ref['primitives'],
           'selectors':ref['selectors'],'roots':ref['roots'],'groups':ref['groups'],
           'opaque_commands':ref['opaque_commands'],'visual_commands':visual_commands(shape),'caveats':caveats,
           'binding':'Select only triangles attributed to an actually drawn source primitive in its selected source group/root. Never draw the union of all roots.'}
    if index in TWO_TONE_SHAPES:model['paint_style']='two_tone_olive'
    if index==103:
        for t in output:
            t['material']='tree_trunk' if t['source_primitive'] in (10541,10571) else 'tree_crown'
            # Crown apex/base and trunk each span their own local shape patch.
            source=next(p['vertices'] for p in ref['primitives'] if p['id']==t['source_primitive'])
            axis=0 if len({p[0] for p in source})>1 else 1
            b=bounds(source); width=b['max'][axis]-b['min'][axis]; height=b['max'][2]-b['min'][2]
            t['uv']=[[(v[axis]-b['min'][axis])/width,1-(v[2]-b['min'][2])/height] for v in t['vertices']]
    return model


def validate_model(model):
    """Fail closed on malformed or enlarged authored geometry."""
    source_ids={p['id'] for p in model['source_primitives']}
    b=model['source_bounds']
    for tri in model['triangles']:
        if len(tri['vertices'])!=3 or area2(tri['vertices'])<=1e-8:raise ValueError('degenerate triangle')
        if tri['source_primitive'] not in source_ids:raise ValueError('unattributed triangle')
        if len(tri['color'])!=3 or any(not isinstance(x,int) or not 0<=x<=255 for x in tri['color']):raise ValueError('invalid RGB')
        for v in tri['vertices']:
            if len(v)!=3 or not all(math.isfinite(x) for x in v):raise ValueError('nonfinite vertex')
            if any(not b['min'][a]-1e-5<=v[a]<=b['max'][a]+1e-5 for a in range(3)):raise ValueError('mesh exceeds source bounds')
    return True


def glb_bytes(model):
    """Unindexed flat-shaded glTF 2.0, vertex colors, raw coordinate metadata."""
    if not model['triangles']:return None
    pos=[]; normals=[]; colors=[]
    for tri in model['triangles']:
        n=cross(sub(tri['vertices'][1],tri['vertices'][0]),sub(tri['vertices'][2],tri['vertices'][0]));length=math.sqrt(dot(n,n))
        for v in tri['vertices']:
            pos.extend(v);normals.extend(c/length for c in n);colors.extend(c/255 for c in tri['color'])
    buffers=[struct.pack('<'+'f'*len(a),*a) for a in (pos,normals,colors)]
    binary=b''.join(buffers); count=len(pos)//3
    doc={'asset':{'version':'2.0','generator':'Abrams source-bound low-poly authoring'},'scene':0,
         'scenes':[{'nodes':[0]}],'nodes':[{'mesh':0,'name':f"shape_{model['shape_index']:03d}",'extras':{'source_axes':model['axes'],'pivot':model['pivot']}}],
         'meshes':[{'primitives':[{'attributes':{'POSITION':0,'NORMAL':1,'COLOR_0':2},'material':0,'mode':4}]}],
         'materials':[{'doubleSided':True,'pbrMetallicRoughness':{'baseColorFactor':[1,1,1,1],'metallicFactor':0,'roughnessFactor':1}}],
         'buffers':[{'byteLength':len(binary)}],
         'bufferViews':[{'buffer':0,'byteOffset':sum(map(len,buffers[:i])),'byteLength':len(b),'target':34962} for i,b in enumerate(buffers)],
         'accessors':[{'bufferView':i,'componentType':5126,'count':count,'type':'VEC3',**({'min':model['bounds']['min'],'max':model['bounds']['max']} if i==0 else {})} for i in range(3)]}
    raw=json.dumps(doc,separators=(',',':')).encode();raw+=b' '*((-len(raw))%4);binary+=b'\0'*((-len(binary))%4)
    return struct.pack('<4sII',b'glTF',2,12+8+len(raw)+8+len(binary))+struct.pack('<I4s',len(raw),b'JSON')+raw+struct.pack('<I4s',len(binary),b'BIN\0')+binary


def build(source=ROOT/'GAME'):
    catalog,shapes=source_catalog(source);inventory=collect_inventory(source,catalog,shapes);models=[]
    for shape in shapes:
        i=shape['index'];roles=[{'class_index':r['class_index'],'name':r['name'],'variant':variant} for r in catalog['classes'] for variant,idx in r['shapes'].items() if idx==i]
        placements={n:count[i] for n,count in inventory['world_shape_counts'].items() if i in count}
        model=build_model(shape,roles,placements,i in inventory['required_shapes']);validate_model(model);models.append(model)
    return {'schema':SCHEMA,'authoring_revision':9,'sources':inventory['sources'],'classes':catalog['classes'],
            'inventory':inventory,'materials':MATERIALS,'models':models,
            'coordinate_contract':'Raw source-local primitive_vertices coordinates, unchanged pivot. GLB also retains raw z-up coordinates; units are not metres.',
            'visibility_contract':'Per-triangle source_primitive ownership is mandatory. Lines, opaque commands and sprite-only programs remain original-authoritative. Offline whole-model GLB is an authoring preview, never a visibility list.'}


SOURCE_DIRS=('GAME','GENESIS','reference')


def inside_source(path):
    """Case- and alias-correct: on APFS 'game/x' is GAME/x, yet is_relative_to differs."""
    return source_guard.inside_source(path,ROOT,SOURCE_DIRS)


def export(output, result):
    output=output.resolve()
    if inside_source(output):raise ValueError('output cannot overwrite source')
    output.mkdir(parents=True,exist_ok=True)
    (output/'models').mkdir(exist_ok=True)
    for model in result['models']:
        glb=glb_bytes(model)
        if glb:
            filename=f"models/{model['shape_index']:03d}.glb";(output/filename).write_bytes(glb);model['glb']=filename
            model['glb_sha256']=hashlib.sha256(glb).hexdigest()
    (output/'catalog.json').write_text(json.dumps(result,separators=(',',':'))+'\n')
    summary={'schema':SCHEMA,'sources':result['sources'],'models':len(result['models']),
             'required_shapes':len(result['inventory']['required_shapes']),
             'triangles':sum(len(m['triangles']) for m in result['models']),
             'statuses':dict(Counter(m['status'] for m in result['models'])),
             'catalog_sha256':hashlib.sha256((output/'catalog.json').read_bytes()).hexdigest()}
    (output/'manifest.json').write_text(json.dumps(summary,indent=2)+'\n')
    return summary


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source',type=Path,default=ROOT/'GAME');parser.add_argument('--output',type=Path,default=ROOT/'local-art/pc-modern')
    args=parser.parse_args();print(json.dumps(export(args.output,build(args.source)),indent=2))
