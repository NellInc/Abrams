"""Mechanical asset checks, independent geometry fixtures plus local source audit."""
from collections import Counter
import copy
import json
from pathlib import Path
import struct
import tempfile
import unittest

from tools.build_pc_modern_assets import (
    ROOT, MATERIALS, add_face, area2, bounds, build, export, glb_bytes,
    inset_patch, track_patch, triangulate, validate_model, wheel, octagonal_barrel,
    face_outline, surface_relief, rectangle, inset_outline, BRIDGE_DECKS, cross, sub, dot,
    VEHICLE_PAINT, TWO_TONE_SHAPES, DOOR_PAINT, BUILDING_RUINS, finish_colours,
)


def edge_counts(triangles):
    result = Counter()
    for tri in triangles:
        vertices = [tuple(v) for v in tri['vertices']]
        for a,b in zip(vertices,vertices[1:]+vertices[:1]):result[tuple(sorted((a,b)))]+=1
    return result


class GeometryTests(unittest.TestCase):
    def test_surface_details_are_closed_and_recessed_without_coplanar_overlays(self):
        face=[[0,0,10],[10,0,10],[10,10,10],[0,10,10]]
        outline=face_outline(face,(0,1),rectangle(2,2,8,8))
        triangles=[]
        surface_relief(triangles,outline,'hatch','olive_edge',4,[1],[5,5,0],'fixture')
        self.assertEqual(set(edge_counts(triangles).values()),{2})
        self.assertTrue(all(9.75<v[2]<10 for t in triangles for v in t['vertices']))
        self.assertTrue(all(2<=v[0]<=8 and 2<=v[1]<=8 for t in triangles for v in t['vertices']))
        self.assertEqual(face_outline(face,(0,1),rectangle(-1,2,8,8)),[])
        self.assertEqual(face_outline(face[::-1],(0,1),rectangle(2,2,8,8)),outline)
        face[0][2]=9
        self.assertEqual(face_outline(face,(0,1),rectangle(2,2,8,8)),[])

    def test_bevel_width_is_metric_not_proportional_to_edge_length(self):
        points=[[0,0,0],[100,0,0],[100,10,0],[0,10,0]]
        self.assertEqual(inset_outline(points,.1),[[.5,.5,0],[99.5,.5,0],[99.5,9.5,0],[.5,9.5,0]])
        out=[];inset_patch(out,points,'olive','olive_edge',1,[1],.025,[50,5,-1])
        self.assertTrue(set(map(tuple,points))<=set(tuple(v) for t in out for v in t['vertices']))

    def test_concave_faces_do_not_acquire_internal_panel_seams(self):
        points=[[0,0,0],[3,0,0],[3,1,0],[1,1,0],[1,3,0],[0,3,0]]
        out=[];inset_patch(out,points,'olive','olive_edge',1,[1],.025,[1,1,-1])
        self.assertEqual({t['component'] for t in out},{'source_facet'})
        self.assertAlmostEqual(sum(area2(t['vertices'])/2 for t in out),5)

    def test_concave_triangulation_does_not_fill_notch(self):
        polygon=[[0,0,0],[3,0,0],[3,1,0],[1,1,0],[1,3,0],[0,3,0]]
        triangles=triangulate(polygon)
        self.assertEqual(len(triangles),4)
        self.assertAlmostEqual(sum(area2(t)/2 for t in triangles),5.)
        self.assertAlmostEqual(sum(area2(t)/2 for t in triangulate(polygon[::-1])),5.)

    def test_duplicate_and_collinear_vertices_do_not_generate_degenerates(self):
        polygon=[[0,0,0],[1,0,0],[2,0,0],[2,2,0],[0,2,0],[0,0,0]]
        triangles=triangulate(polygon)
        self.assertTrue(all(area2(t)>0 for t in triangles))
        self.assertAlmostEqual(sum(area2(t)/2 for t in triangles),4.)
        self.assertEqual(triangulate([[0,0,0],[1,1,1],[2,2,2]]),[])

    def test_beveled_cube_is_closed_and_stays_within_original_bounds(self):
        faces=[[[x,y,z] for y,z in [(-1,-1),(1,-1),(1,1),(-1,1)]] for x in (-1,1)]
        faces += [[[x,y,z] for x,z in [(-1,-1),(1,-1),(1,1),(-1,1)]] for y in (-1,1)]
        faces += [[[x,y,z] for x,y in [(-1,-1),(1,-1),(1,1),(-1,1)]] for z in (-1,1)]
        triangles=[]
        for i,face in enumerate(faces):inset_patch(triangles,face,'olive','olive_edge',i,[0],.025,[0,0,0])
        self.assertEqual(set(edge_counts(triangles).values()),{2})
        self.assertEqual(bounds([v for t in triangles for v in t['vertices']]),{'min':[-1,-1,-1],'max':[1,1,1]})
        self.assertGreater(len(triangles),12)

    def test_polygonal_wheel_and_hub_are_separate_closed_solids(self):
        triangles=[];wheel(triangles,10,0,0,3,1,1,123,[5],'wheel_fixture')
        for component in ('wheel_fixture','wheel_fixture_hub'):
            faces=[t for t in triangles if t['component']==component]
            self.assertEqual(set(edge_counts(faces).values()),{2})
            self.assertTrue(all(area2(t['vertices'])>0 for t in faces))
        self.assertTrue(all(9<=v[0]<=10 for t in triangles for v in t['vertices']))
        moving=[t for t in triangles if 'motion' in t]
        self.assertEqual(len(moving),12)
        self.assertTrue(all(t['motion']['radius']==3 for t in moving))
        self.assertTrue(all(t['motion']['center'][1:]==[0,0] for t in moving))

    def test_barrel_is_octagonal_with_only_original_open_breech(self):
        faces=[[[x,y,z] for y,z in [(0,-1),(10,-1),(10,1),(0,1)]] for x in (-1,1)]
        faces += [[[x,y,z] for x,y in [(-1,0),(1,0),(1,10),(-1,10)]] for z in (-1,1)]
        faces += [[[-1,10,-1],[1,10,-1],[1,10,1],[-1,10,1]]]
        ps=[{'id':i,'vertices':p} for i,p in enumerate(faces)]
        triangles=octagonal_barrel(ps,[42])
        edges=edge_counts(triangles)
        self.assertTrue(all(n in (1,2) for n in edges.values()))
        boundary=[e for e,n in edges.items() if n==1]
        self.assertEqual(len(boundary),12) # Eight rim sides, four split diagonals.
        self.assertTrue(all(v[1]==0 for e in boundary for v in e))
        self.assertEqual(bounds([v for t in triangles for v in t['vertices']]),{'min':[-1,0,-1],'max':[1,10,1]})

    def test_track_retains_outline_and_required_wheel_count(self):
        poly=[[10,-30,-5],[10,20,-5],[10,30,0],[10,25,5],[10,-25,5]]
        triangles=[];track_patch(triangles,poly,1,[2],5,[0,0,0])
        components={t['component'] for t in triangles if t['component'].startswith('wheel_') and not t['component'].endswith('_hub')}
        self.assertEqual(len(components),5)
        all_vertices={tuple(v) for t in triangles for v in t['vertices']}
        self.assertTrue(set(map(tuple,poly)).issubset(all_vertices))

    def test_invalid_payload_is_rejected(self):
        triangles=[];add_face(triangles,[[0,0,0],[1,0,0],[0,1,0]],'olive',4,[2],'test')
        model={'triangles':triangles,'source_bounds':{'min':[0,0,0],'max':[1,1,0]},'source_primitives':[{'id':4}]}
        self.assertTrue(validate_model(model))
        for mutation in ('nan','enlarged','color','owner','degenerate'):
            m=copy.deepcopy(model);t=m['triangles'][0]
            if mutation=='nan':t['vertices'][0][0]=float('nan')
            if mutation=='enlarged':t['vertices'][0][0]=-1
            if mutation=='color':t['color'][0]=256
            if mutation=='owner':t['source_primitive']=5
            if mutation=='degenerate':t['vertices'][1]=t['vertices'][0]
            with self.subTest(mutation=mutation),self.assertRaises(ValueError):validate_model(m)

    def test_glb_is_valid_flat_shaded_raw_coordinate_container(self):
        triangles=[];add_face(triangles,[[0,0,0],[1,0,0],[0,1,2]],'olive',4,[2],'test')
        model={'shape_index':4,'triangles':triangles,'bounds':bounds([v for t in triangles for v in t['vertices']]),'axes':'raw source','pivot':[0,0,0]}
        binary=glb_bytes(model);magic,version,size=struct.unpack_from('<4sII',binary)
        self.assertEqual((magic,version,size),(b'glTF',2,len(binary)))
        n,kind=struct.unpack_from('<I4s',binary,12);self.assertEqual(kind,b'JSON')
        doc=json.loads(binary[20:20+n]);self.assertEqual(doc['accessors'][0]['max'],[1,1,2])
        bsize,bkind=struct.unpack_from('<I4s',binary,20+n);self.assertEqual(bkind,b'BIN\0')
        self.assertEqual(len(binary)-(28+n),bsize)
        self.assertEqual(list(struct.unpack_from('<9f',binary,28+n)),[0,0,0,1,0,0,0,1,2])


@unittest.skipUnless((ROOT/'GAME/SHAPE.TBL').exists(),'original local corpus unavailable')
class LocalSourceIntegrationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):cls.result=build()

    def test_all_source_classes_variants_and_static_scenarios_are_registered(self):
        r=self.result;self.assertEqual(len(r['models']),188);self.assertEqual(len(r['classes']),31)
        self.assertEqual(len(r['inventory']['required_shapes']),151)
        self.assertEqual(len(r['inventory']['source_only_shapes']),37)
        self.assertEqual(sum(sum(c.values()) for c in r['inventory']['world_shape_counts'].values()),6163)
        self.assertEqual(set(r['inventory']['world_shape_counts']),set(map(str,range(8))))
        for row in r['classes']:
            for variant,index in row['shapes'].items():
                if index is not None:
                    self.assertIn({'class_index':row['class_index'],'name':row['name'],'variant':variant},r['models'][index]['class_roles'])

    def test_every_mesh_is_finite_bounded_and_primitive_attributed(self):
        for m in self.result['models']:
            with self.subTest(index=m['shape_index']):self.assertTrue(validate_model(m))
            for t in m['triangles']:
                actual={g['offset'] for g in m['groups'] if t['source_primitive'] in g['primitive_pointers']}
                self.assertEqual(set(t['source_groups']),actual)
                self.assertIn(t['material'],MATERIALS)

    def test_visual_commands_retain_exact_original_centers_and_radii(self):
        for i,expected in ((145,([200,24,100],30,0)),(153,([500,-440,350],100,0)),(156,([1000,-100,350],100,0)),(161,([0,0,0],15,2)),(162,([0,0,0],15,2))):
            cmd=self.result['models'][i]['visual_commands'][0]
            self.assertEqual((cmd['center_raw'],cmd['radius_raw'],cmd['color_index']),expected)
        for i in (115,125):
            self.assertTrue(any(t['component']=='turret_corner_facet' for t in self.result['models'][i]['triangles']))

    def test_building_facades_have_source_bounded_openings(self):
        for i in (147,149,151):
            m=self.result['models'][i]
            self.assertTrue(any(t['component'].startswith('window_') for t in m['triangles']))
            self.assertTrue(validate_model(m))

    def test_refinement_has_bounded_cost_and_source_owned_details(self):
        self.assertEqual(self.result['authoring_revision'],9)
        # Includes the literal 50-star flag, bounded to one source face.
        self.assertLess(sum(len(m['triangles']) for m in self.result['models']),24000)
        for i in (115,117,119,121,125,127):
            m=self.result['models'][i]
            components={t['component'] for t in m['triangles']}
            self.assertTrue({'hatch_0','hatch_1','barrel_bore','engine_louvre_0'}<=components)
            self.assertLess(len(m['triangles']),1500)
            turret=m['groups'][1]['primitive_pointers']
            back=min(v[1] for p in m['source_primitives'] if p['id'] in turret for v in p['vertices'])
            self.assertTrue(all(v[1]<back for t in m['triangles'] if t['component'].startswith('engine_louvre') for v in t['vertices']))
        for i in (129,131,133,135,137,139):
            m=self.result['models'][i]
            armour=[t for t in m['triangles'] if t['component']=='upper_side_armour']
            self.assertTrue(armour)
            # Skin must sit outside wheel fronts to avoid a coplanar sawtooth.
            wheel_x=max(abs(v[0]) for t in m['triangles'] if t['component'].startswith('wheel_') for v in t['vertices'])
            visible_skin=[t for t in armour if t['material']=='olive']
            self.assertTrue(visible_skin)
            self.assertTrue(all(abs(v[0])>wheel_x for t in visible_skin for v in t['vertices']))

    def test_flat_decks_keep_exact_source_planes(self):
        for i in sorted(BRIDGE_DECKS):
            m=self.result['models'][i];source={p['id']:p for p in m['source_primitives']}
            for t in m['triangles']:
                points=source[t['source_primitive']]['vertices']
                original=triangulate(points)[0];n=cross(sub(original[1],original[0]),sub(original[2],original[0]))
                self.assertEqual(t['component'],'source_plane')
                self.assertTrue(all(abs(dot(sub(v,original[0]),n))<1e-6 for v in t['vertices']))
                self.assertTrue(all(v in points for v in t['vertices']))

    def test_crew_detail_partitions_original_sheets_without_overlap_or_coverage_loss(self):
        for i in (161,162):
            model=self.result['models'][i]
            parts={t['component'] for t in model['triangles']}
            self.assertTrue({'crew_belt','crew_buckle','crew_hand','crew_boot',
                             'crew_shoulder_strap','launcher_panel','launcher_optic'}<=parts)
            for p in model['source_primitives']:
                originals=triangulate(p['vertices'])
                if not originals:continue
                refined=[t for t in model['triangles'] if t['source_primitive']==p['id']]
                self.assertAlmostEqual(sum(area2(t)/2 for t in originals),
                                       sum(area2(t['vertices'])/2 for t in refined),places=3)
                a,b,c=originals[0];n=cross(sub(b,a),sub(c,a))
                for t in refined:
                    self.assertTrue(all(abs(dot(sub(v,a),n))<1e-6 for v in t['vertices']))
                    # Every patch vertex must lie within a source triangle.
                    for v in t['vertices']:
                        self.assertTrue(any(abs(sum(area2([v,q[k],q[(k+1)%3]]) for k in range(3))-area2(q))<.002 for q in originals))
            self.assertLess(len(model['triangles']),600)

    def test_building_colours_retain_landmark_identity_without_runtime_tint(self):
        farm=self.result['models'][157]
        for pid,material in ((28707,'roof_clay'),(28715,'roof_clay'),(28751,'yard_grass'),
                             (28819,'roof_slate'),(28699,'timber')):
            faces=[t for t in farm['triangles'] if t['source_primitive']==pid]
            self.assertTrue(any(t['material']==material for t in faces))
        clay=[t['color'] for t in farm['triangles'] if t['material']=='roof_clay']
        self.assertTrue(all(r>g*1.4 and g>b*1.7 for r,g,b in clay))
        grass=[t['color'] for t in farm['triangles'] if t['material']=='yard_grass']
        self.assertTrue(all(g>r*1.5 and g>b*1.7 for r,g,b in grass))
        ridge=[t['color'] for t in self.result['models'][151]['triangles'] if t['material']=='roof_ridge']
        self.assertTrue(ridge and all(r>g*2 for r,g,b in ridge))
        for i in (145,153):
            model=self.result['models'][i]
            flags={p['id'] for p in model['source_primitives'] if p['prefix_bytes'][1:3]==[6,6]}
            self.assertTrue(any(t['material']=='signal_red' for t in model['triangles']))
            self.assertFalse(any(t['component'].startswith('window_') for t in model['triangles'] if t['source_primitive'] in flags))

    def test_all_authored_source_red_accents_survive_material_refinement(self):
        seen=set()
        for model in self.result['models']:
            if not 115<=model['shape_index']<=164:continue
            red={p['id'] for p in model['source_primitives'] if p['prefix_bytes']==[255,6,6]}
            for t in model['triangles']:
                if t['source_primitive'] not in red:continue
                if model['shape_index']==156 or t['material'].startswith('insignia_'):continue
                seen.add(model['shape_index'])
                self.assertEqual(t['material'],'signal_red')
                r,g,b=t['color']
                self.assertGreaterEqual(r,170)
                self.assertGreater(r,g*3)
                self.assertGreater(r,b*4)
        self.assertEqual(seen,{115,117,119,121,129,131,133,135,139,141,143,145,153,163,164})

    def test_ruins_have_broken_slabs_fractures_and_dark_interiors(self):
        for i in BUILDING_RUINS:
            model=self.result['models'][i]
            parts={t['component'] for t in model['triangles']}
            self.assertTrue({'ruin_interior','ruin_broken_slab','ruin_fracture'}<=parts)
            self.assertTrue(validate_model(model))
            colours={t['material'] for t in model['triangles']}
            self.assertTrue({'ruin_void','ruin_brick','ruin_plaster'}<=colours)
        self.assertFalse(any(t['material'].startswith(('ruin_','wreck')) for t in self.result['models'][156]['triangles']))

    def test_base_stars_and_flag_facets_are_distinct_and_source_bounded(self):
        for i,label in ((153,'soviet_star'),(155,'us_army_star'),(156,'us_army_star')):
            m=self.result['models'][i]
            self.assertTrue(any(t['component']==label for t in m['triangles']))
            self.assertTrue(validate_model(m))
        for i,pid,label in ((153,27177,'soviet_flag_star'),(156,28325,'us_flag_star_00')):
            m=self.result['models'][i]
            tris=[t for t in m['triangles'] if t['source_primitive']==pid]
            self.assertTrue(any(t['component']==label for t in tris))
            self.assertAlmostEqual(sum(area2(t['vertices']) for t in tris),60000,places=3)
            self.assertTrue(all(v[1]==940 if i==153 else v[1]==1280 for t in tris for v in t['vertices']))

    def test_american_flag_has_thirteen_stripes_and_fifty_separate_stars(self):
        m=self.result['models'][156]
        flag=[t for t in m['triangles'] if t['source_primitive']==28325]
        components={t['component'] for t in flag}
        self.assertEqual({c for c in components if c.startswith('us_flag_star_')},
                         {f'us_flag_star_{i:02d}' for i in range(50)})
        self.assertEqual({c for c in components if c.startswith('us_flag_stripe_')},
                         {f'us_flag_stripe_{i:02d}' for i in range(13)})
        self.assertLess(len(flag),1700)
        self.assertEqual({t['material'] for t in flag},{'us_flag_red','us_flag_white','us_flag_blue'})
        for row in range(13):
            stripe=[t for t in flag if t['component']==f'us_flag_stripe_{row:02d}']
            self.assertEqual({t['material'] for t in stripe},{'us_flag_red' if row%2==0 else 'us_flag_white'})
        for t in flag:
            if t['component'].startswith('us_flag_star_'):
                self.assertTrue(all(0<=v[0]<=80 and 650-150*7/13<=v[2]<=650 for v in t['vertices']))

    def test_material_finish_preserves_every_noncolour_triangle_field(self):
        for m in self.result['models']:
            if m['shape_index'] not in range(115,165):continue
            triangles=copy.deepcopy(m['triangles'])
            before=[{k:v for k,v in t.items() if k not in ('color','material')} for t in triangles]
            finish_colours(m['shape_index'],m['name'],m['class_roles'],triangles,m['source_primitives'])
            self.assertEqual(before,[{k:v for k,v in t.items() if k not in ('color','material')} for t in triangles])

    def test_vehicle_hubs_hatches_and_upper_facets_have_restrained_highlights(self):
        m=self.result['models'][115];paint=VEHICLE_PAINT['T-62']
        for material,factor in (('hub',.94),('hatch',1.08)):
            faces=[t for t in m['triangles'] if t['material']==material]
            self.assertTrue(faces)
            self.assertTrue(all(sum(t['color'])>sum(paint)*factor for t in faces))
        rims=[t for t in m['triangles'] if t['material']=='olive_edge' and t['component'].startswith('hatch_')]
        self.assertTrue(any(sum(t['color'])>sum(paint)*1.15 for t in rims))
        upper=[t for t in m['triangles'] if t['material']=='olive' and min(v[2] for v in t['vertices'])>=0]
        self.assertTrue(any(sum(t['color'])>sum(paint)*1.06 for t in upper))
        self.assertTrue(all(max(t['color'])<180 for t in m['triangles'] if t['source_primitive']!=13453))

    def test_glazing_is_blue_grey_with_fixed_facet_highlights(self):
        seen=set()
        for m in self.result['models']:
            panes=[t for t in m['triangles'] if t['material'] in ('glass','cockpit')]
            if not panes:continue
            seen.add(m['shape_index'])
            for t in panes:
                r,g,b=t['color']
                self.assertGreater(b,g);self.assertGreater(g,r)
                self.assertGreaterEqual(b,130);self.assertLess(b,205)
            self.assertGreater(len({tuple(t['color']) for t in panes}),1)
        self.assertTrue({145,147,149,151,153,155,157,159,163,164}<=seen)

    def test_bridge_highlights_retain_original_endpoints_and_warm_decks(self):
        lines=0
        for i in BRIDGE_DECKS:
            m=self.result['models'][i];source={p['id']:p for p in m['source_primitives']}
            for line in m['source_lines']:
                self.assertEqual(line['vertices'],source[line['source_primitive']]['vertices'])
                self.assertEqual(line['prefix_bytes'],source[line['source_primitive']]['prefix_bytes'])
                if len(line['vertices'])!=2:continue
                r,g,b=line['color'];self.assertTrue(90<r<g<b<180);lines+=1
            self.assertTrue(all(r>g>b for r,g,b in (t['color'] for t in m['triangles'])))
        self.assertGreater(lines,50)
        self.assertFalse(any('color' in line for m in self.result['models'] if m['shape_index'] not in BRIDGE_DECKS for line in m['source_lines']))

    def test_two_tone_is_explicit_and_canvas_is_separate_from_metal(self):
        self.assertEqual({m['shape_index'] for m in self.result['models'] if m.get('paint_style')=='two_tone_olive'},TWO_TONE_SHAPES)
        truck=self.result['models'][159]
        canopy={p['id'] for p in truck['source_primitives'] if 85<=p['prefix_bytes'][0]<=91}
        faces=[t for t in truck['triangles'] if t['source_primitive'] in canopy]
        self.assertEqual({t['material'] for t in faces},{'canvas','canvas_edge'})
        self.assertTrue(all(r>g>b for r,g,b in (t['color'] for t in faces)))

    def test_wrecks_separate_scorching_steel_and_surviving_paint(self):
        for m in self.result['models']:
            if not any(r['variant']=='replacement' for r in m['class_roles']):continue
            panels=[t['color'] for t in m['triangles'] if t['material']=='wreck']
            if not panels:continue
            self.assertGreaterEqual(len(set(map(tuple,panels))),3)
            self.assertTrue(all(max(rgb)<180 for rgb in panels))
            if m['shape_index']<145 or m['shape_index']==160:
                self.assertTrue(any(b>r and g>r for r,g,b in panels))
                self.assertTrue(any(g>r>b for r,g,b in panels))

    def test_building_accents_and_crew_equipment_are_distinct(self):
        for index in DOOR_PAINT:
            m=self.result['models'][index]
            doors=[t['color'] for t in m['triangles'] if t['material']=='door']
            self.assertTrue(doors)
            self.assertTrue(all(max(rgb)<145 for rgb in doors))
            frames=[t['color'] for t in m['triangles'] if t['material']=='stone_edge' and t['component'].startswith('window_')]
            if index!=47:self.assertTrue(frames and max(map(sum,frames))>500)
        for i in (161,162):
            m=self.result['models'][i]
            panels=[t['color'] for t in m['triangles'] if t['material']=='equipment']
            straps=[t['color'] for t in m['triangles'] if t['component']=='crew_shoulder_strap']
            self.assertTrue(panels and straps)
            self.assertTrue(all(sum(c)<270 for c in panels))
            self.assertTrue(all(sum(c)>430 for c in straps))
    def test_hangar_door_sits_in_front_of_recessed_end_wall(self):
        m=self.result['models'][47]
        door=[v[1] for t in m['triangles'] if t['source_primitive']==4893 and t['component']=='panel' for v in t['vertices']]
        wall=[v[1] for t in m['triangles'] if t['source_primitive']==4884 and t['component']=='panel' for v in t['vertices']]
        self.assertTrue(door and wall)
        self.assertLess(max(door),min(wall))
        self.assertGreater(min(door),-1280)

    def test_truck_details_have_real_depth_and_distinct_materials(self):
        m=self.result['models'][159];ts=m['triangles']
        components={t['component'] for t in ts}
        self.assertTrue({'truck_windscreen_0','truck_windscreen_1','truck_side_window','truck_hub','truck_lamp_0','truck_grille_0'}<=components)
        glass=[t for t in ts if t['component'].startswith('truck_windscreen')]
        panels=[t for t in ts if t['source_primitive']==29755 and t['component']=='panel']
        self.assertTrue(all(v[1]<80 for t in glass for v in t['vertices']))
        self.assertGreater(min(v[1] for t in glass for v in t['vertices']),max(v[1] for t in panels for v in t['vertices']))
        self.assertTrue({'canvas','tyre','lamp','cockpit'}<={t['material'] for t in ts})

    def test_wheeled_vehicles_retain_their_own_running_gear(self):
        for i in (141,143):
            m=self.result['models'][i]
            hubs=[t for t in m['triangles'] if t['component']=='source_wheel_hub']
            self.assertEqual(len({t['source_primitive'] for t in hubs}),4)
            self.assertFalse(any(t['component'].startswith('wheel_') for t in m['triangles']))
            originals={p['id'] for p in m['source_primitives'] if p['prefix_bytes'][0] in (71,72)}
            self.assertTrue(all(t['material'] in ('tyre','hub') for t in m['triangles'] if t['source_primitive'] in originals))
            wheel_panels=[t for t in m['triangles'] if t['source_primitive'] in originals and t['component']=='panel']
            self.assertTrue(wheel_panels)
            self.assertTrue(all(abs(v[0])<45*(1-.025) for t in wheel_panels for v in t['vertices']))
        self.assertTrue(any(t['material']=='tyre' for t in self.result['models'][137]['triangles']))
        self.assertFalse(any(t['material']=='tyre' for t in self.result['models'][115]['triangles']))

    def test_full_authored_roster_and_hind_intakes(self):
        authored=[m for m in self.result['models'] if m['status'] in ('authored_mesh','conservative_refinement','partial_opaque') and m['triangles']]
        self.assertEqual(len(authored),57)
        self.assertEqual({m['shape_index'] for m in authored},BRIDGE_DECKS|{47}|set(range(115,165)))
        for i in (163,164):
            self.assertTrue({'engine_side_vent','engine_intake_0','engine_intake_1'}<={t['component'] for t in self.result['models'][i]['triangles']})

    def test_both_hind_states_have_matching_glazing_and_original_rotor_lines(self):
        signatures=[]
        for i in (163,164):
            m=self.result['models'][i]
            glass=[t for t in m['triangles'] if t['component'].startswith('cockpit_')]
            self.assertEqual(len(glass),80) # Four windscreens, two lower and two upper side panes.
            signatures.append([(t['vertices'],t['color'],t['component']) for t in glass])
            source={p['id']:p for p in m['source_primitives']}
            self.assertEqual(len(m['source_lines']),1)
            for line in m['source_lines']:self.assertEqual(line['vertices'],source[line['source_primitive']]['vertices'])
        self.assertEqual(signatures[0],signatures[1])
        self.assertNotEqual(self.result['models'][163]['source_lines'][0]['vertices'],self.result['models'][164]['source_lines'][0]['vertices'])

    def test_farm_annex_recesses_toward_its_own_interior(self):
        m=self.result['models'][157]
        for pid,axis,direction,plane in ((28811,0,1,120),(28841,0,-1,220),(28827,1,1,-250)):
            panels=[t for t in m['triangles'] if t['source_primitive']==pid and t['component']=='panel']
            self.assertTrue(panels)
            self.assertTrue(all((v[axis]-plane)*direction>0 for t in panels for v in t['vertices']))

    def test_opaque_lines_and_ambiguous_families_are_never_marked_finished(self):
        for m in self.result['models']:
            if m['opaque_commands']:self.assertIn(m['status'],('source_command','partial_opaque'))
        for i in (165,166):self.assertEqual(self.result['models'][i]['status'],'unresolved_placeholder')
        self.assertEqual(self.result['models'][167]['triangles'],[])
        self.assertEqual(self.result['models'][167]['status'],'source_control_invisible')
        for i in (123,124):self.assertEqual(self.result['models'][i]['status'],'conservative_refinement')

    def test_tree_preserves_crossed_source_planes_and_uv_envelope(self):
        m=self.result['models'][103]
        self.assertEqual(sum(m['scenario_placements'].values()),147)
        self.assertEqual(m['source_bounds'],{'min':[-160,-160,0],'max':[160,160,480]})
        self.assertEqual(m['status'],'tree_sprite_template')
        for t in m['triangles']:
            self.assertTrue(all(v[0]==0 for v in t['vertices']) or all(v[1]==0 for v in t['vertices']))
            self.assertTrue(all(0<=u<=1 and 0<=v<=1 for u,v in t['uv']))

    def test_tanks_have_substantial_geometry_and_closed_road_wheels(self):
        for i,wheels in ((115,10),(125,14),(129,10),(137,8)):
            m=self.result['models'][i]
            self.assertGreater(len(m['triangles']),300)
            if i in (115,125,129):
                group=m['groups'][0]['offset']
                hull=[t for t in m['triangles'] if group in t['source_groups']]
                self.assertEqual(set(edge_counts(hull).values()),{2})
            components={t['component'] for t in m['triangles'] if t['component'].startswith('wheel_') and not t['component'].endswith('_hub')}
            self.assertEqual(len(components),wheels)
            for c in components:
                self.assertEqual(set(edge_counts([t for t in m['triangles'] if t['component']==c]).values()),{2})

    def test_export_is_reproducible_and_source_hashes_are_complete(self):
        self.assertEqual(len(self.result['sources']),19)
        with tempfile.TemporaryDirectory() as tmp:
            a=export(Path(tmp)/'a',copy.deepcopy(self.result));b=export(Path(tmp)/'b',copy.deepcopy(self.result))
            self.assertEqual(a,b)
            self.assertEqual((Path(tmp)/'a/catalog.json').read_bytes(),(Path(tmp)/'b/catalog.json').read_bytes())
            for m in self.result['models']:
                if m['triangles']:
                    p=f"models/{m['shape_index']:03d}.glb"
                    self.assertEqual((Path(tmp)/'a'/p).read_bytes(),(Path(tmp)/'b'/p).read_bytes())

if __name__=='__main__':unittest.main()
