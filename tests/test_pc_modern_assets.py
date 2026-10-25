"""Mechanical asset checks, independent geometry fixtures plus local source audit."""
from collections import Counter
import copy
import hashlib
import json
from pathlib import Path
import struct
import tempfile
import unittest
from unittest import mock

from tools.build_pc_modern_assets import (
    ROOT, MATERIALS, add_face, area2, bounds, build, export, glb_bytes,
    inset_patch, track_patch, triangulate, validate_model, wheel, octagonal_barrel,
    face_outline, surface_relief, rectangle, inset_outline, BRIDGE_DECKS, cross, sub, dot,
    VEHICLE_PAINT, TWO_TONE_SHAPES, DOOR_PAINT, BUILDING_RUINS, finish_colours, inside_source,
    REGISTRY, REGISTRY_FIELDS, load_catalog, merge_catalog, registry_bytes, source_registry, split_catalog,
)
from tools.package.git_boundary import decoded_payload


@unittest.skipUnless((ROOT/'local-art/pc-modern/catalog.json').exists(),'local authored catalogue unavailable')
class TacticalVehicleAuthoringTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        from tools.build_pc_tactical_vehicles import build_geometry
        base=load_catalog()
        cls.models={i:build_geometry(base['models'][i]) for i in (115,125)}

    def test_runtime_pair_is_attributed_bounded_and_cost_limited(self):
        for index,model in self.models.items():
            with self.subTest(shape=index):
                self.assertTrue(validate_model(model))
                self.assertLessEqual(len(model['triangles']),8192)
                components={t['component'] for t in model['triangles']}
                count=5 if index==115 else 7
                for wheel in range(count):self.assertIn(f'roadwheel_{wheel}_dish',components)
                self.assertIn('barrel_bore',components)
                self.assertIn('bore_evacuator',components)
                self.assertIn('sloped_glacis',components)
                self.assertIn('lower_hull_boat',components)
                self.assertIn('track_idler',components)
                self.assertIn('commander_cupola',components)
                self.assertIn('roof_gun_receiver',components)
                self.assertIn('roof_gun_barrel',components)
                self.assertFalse(any('_bolt_' in name for name in components),'fasteners belong in baked master detail')

    def test_reference_proportions_replace_old_box_profiles(self):
        for index,model in self.models.items():
            tris=model['triangles']
            hull=[v for t in tris if t['component'] in ('lower_hull_boat','fender_plate','sloped_glacis') for v in t['vertices']]
            lo,hi=bounds(hull).values()
            ratio=(hi[1]-lo[1])/(hi[0]-lo[0])
            self.assertAlmostEqual(ratio,2.17 if index==125 else 2.0,delta=.07)
            hull_height=(hi[2]-lo[2])/(hi[0]-lo[0])
            self.assertGreater(hull_height,.25)
            self.assertLess(hull_height,.45)
            roof=[v for t in tris if t['component']==('angular_turret_cheeks' if index==125 else 'cast_turret_dome') for v in t['vertices']]
            self.assertTrue(roof)
            self.assertGreater(len({round(v[2],2) for v in roof}),3,'turret has an authored compound profile')

    def test_blender_uv_catalogue_carries_no_source_registry_decode(self):
        path=ROOT/'local-art/pc-tactical-vehicles-v1/catalog.json'
        if not path.exists():self.skipTest('Blender bake not available')
        data=json.loads(path.read_text())
        self.assertEqual({m['shape_index'] for m in data['models']},{115,125})
        for model in data['models']:
            self.assertFalse(set(REGISTRY_FIELDS)&model.keys())
            self.assertTrue(all('vertices' not in line and 'prefix_bytes' not in line for line in model['source_lines']))
            for triangle in model['triangles']:
                self.assertEqual(len(triangle['uvs']),3)
                self.assertTrue(all(len(uv)==2 and all(0<=value<=1 for value in uv) for uv in triangle['uvs']))


@unittest.skipUnless((ROOT/'local-art/pc-modern/catalog.json').exists(),'local authored catalogue unavailable')
class TacticalRosterAuthoringTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        from tools.build_pc_tactical_roster import authored,ROSTER_SHAPES
        cls.base=load_catalog();cls.models={i:authored(cls.base['models'][i]) for i in ROSTER_SHAPES}

    def _wreck_wheel_parts(self,model,master=False):
        tyre=[t for t in model['triangles'] if t['component'] in ('damaged_roadwheel','collapsed_tyre')]
        count=8*(32 if master else 20)-4
        self.assertEqual(len(tyre)%count,0)
        for start in range(0,len(tyre),count):
            points=[v for t in tyre[start:start+count] for v in t['vertices']];lo,hi=bounds(points).values()
            y,z=(lo[1]+hi[1])/2,(lo[2]+hi[2])/2;r=(hi[1]-lo[1])/2;squash=(hi[2]-lo[2])/(2*r);side=1 if lo[0]>0 else -1
            parts={name:[t for t in model['triangles'] if t['component']==name and t['vertices'][0][0]*side>0 and abs(sum(v[1] for v in t['vertices'])/3-y)<r*.7]
                   for name in ('exposed_wheel_dish','axle_hub')}
            yield side,y,z,r,squash,points,parts

    def test_wreck_wheel_fittings_follow_the_existing_flattened_profiles(self):
        from math import hypot
        from tools.build_pc_tactical_roster import authored
        from tools.pc_tactical_wrecks import FAMILY_KEYS
        for shape in FAMILY_KEYS:
            for master in (False,True):
                model=authored(self.base['models'][shape],True) if master else self.models[shape]
                for side,y,z,r,squash,tyre,parts in self._wreck_wheel_parts(model,master):
                    for name,ts in parts.items():
                        self.assertTrue(ts,(shape,name));points=[v for t in ts for v in t['vertices']];lo,hi=bounds(points).values()
                        self.assertAlmostEqual((hi[2]-lo[2])/(hi[1]-lo[1]),squash,delta=.000003,msg=(shape,name))
                        self.assertLess(max(hypot((v[1]-y)/r,(v[2]-z)/(r*squash)) for v in points),.70,(shape,name))
                        self.assertEqual(set(edge_counts(ts).values()),{2},(shape,name,'closed wheel fitting'))

    def test_wreck_rims_have_a_seated_lip_and_a_recessed_closed_well(self):
        from math import hypot
        from tools.pc_tactical_wrecks import FAMILY_KEYS
        for shape in FAMILY_KEYS:
            for side,y,z,r,squash,tyre,parts in self._wreck_wheel_parts(self.models[shape]):
                points=[v for t in parts['exposed_wheel_dish'] for v in t['vertices']]
                stations=sorted({round(side*v[0],6) for v in points});self.assertEqual(len(stations),3,(shape,'dished profile'))
                radii={x:{round(hypot((v[1]-y)/r,(v[2]-z)/(r*squash)),5) for v in points if abs(side*v[0]-x)<.000001} for x in stations}
                self.assertEqual(radii[stations[-1]],{.54});self.assertEqual(radii[stations[1]],{.28})
                self.assertAlmostEqual(stations[-1]-stations[1],.15,delta=.000003)
                skin=max(side*v[0] for v in tyre)
                self.assertLess(stations[0],skin);self.assertGreater(stations[1],skin+.049)

    def test_loose_wreck_hub_caps_clear_both_wheel_faces(self):
        from math import sqrt
        from tools.pc_tactical_wrecks import FAMILY_KEYS
        axis=[v/sqrt(29) for v in (3,2,4)]
        for shape in FAMILY_KEYS:
            ends={name:[sum(v[k]*axis[k] for k in range(3)) for t in self.models[shape]['triangles'] if t['component']==name for v in t['vertices']]
                  for name in ('detached_roadwheel','detached_hub')}
            self.assertLess(min(ends['detached_hub']),min(ends['detached_roadwheel'])-.149)
            self.assertGreater(max(ends['detached_hub']),max(ends['detached_roadwheel'])+.149)

    def test_wheeled_side_panels_face_outward_and_follow_finished_skin(self):
        from tools.pc_tactical_wheeled_vehicles import _side_skin_x
        for shape,part,skin,offset in ((137,'btr_triangular_door','btr_boat_armour',.082),
                (141,'brdm_side_periscope','brdm_raised_crew_enclosure',.08),
                (143,'brdm_side_periscope','brdm_raised_crew_enclosure',.08),
                (159,'truck_bonnet_side_louvre','truck_sloping_bonnet',.10)):
            model=self.models[shape];seen=set();width_scale=.75 if shape==159 else 1.
            for t in model['triangles']:
                if t['component']!=part:continue
                a,b,c=t['vertices'];side=1 if a[0]>0 else -1;seen.add(side)
                self.assertGreater(cross(sub(b,a),sub(c,a))[0]*side,0,(shape,part))
                for v in t['vertices']:
                    visible_skin={skin,'truck_enclosed_engine_bay'} if shape==159 else {skin}
                    skin_x=_side_skin_x(model['triangles'],visible_skin,v[1],v[2],side)
                    # Preserve the original relative clearance after fitting
                    # the complete truck, including its louvres, in width.
                    self.assertAlmostEqual((v[0]-skin_x)*side/width_scale,offset,delta=.000003)
                    if shape==159:self.assertGreater((v[0]-_side_skin_x(model['triangles'],visible_skin,v[1],v[2],side))*side/width_scale,.02)
                if shape==159:
                    v=[sum(p[k] for p in t['vertices'])/3 for k in range(3)]
                    self.assertGreater((v[0]-_side_skin_x(model['triangles'],visible_skin,v[1],v[2],side))*side/width_scale,.02)
            self.assertEqual(seen,{-1,1})

    def test_wheeled_headlights_clear_the_bow_and_share_master_seats(self):
        from tools.build_pc_tactical_roster import authored
        from tools.pc_tactical_vehicle_refinement import _skin_z,_component_bounds
        for shape,skin in ((137,'btr_compound_bow'),(141,'brdm_compound_boat_hull'),(143,'brdm_compound_boat_hull')):
            model=self.models[shape];master=authored(self.base['models'][shape],True)
            for part in ('headlight_housing','headlight_lens','headlight_mount_foot','lamp_guard'):
                self.assertEqual(_component_bounds(model,{part}),_component_bounds(master,{part}))
            for t in model['triangles']:
                if t['component']=='headlight_lens':
                    for v in t['vertices']:self.assertGreater(v[2]-_skin_z(model,{skin},v[0],v[1]),.1)
            for side in (-1,1):
                lo,hi=bounds([v for t in model['triangles'] if t['component']=='headlight_mount_foot' and t['vertices'][0][0]*side>0 for v in t['vertices']]).values()
                surface=_skin_z(model,{skin},(lo[0]+hi[0])/2,(lo[1]+hi[1])/2)
                self.assertLess(lo[2],surface);self.assertGreater(hi[2],surface)

    def test_hind_camouflage_partitions_the_wing_and_faces_outward(self):
        from tools.build_pc_tactical_vehicles import source_groups,solid
        from tools.build_pc_modern_assets import area2
        from tools.pc_tactical_vehicle_refinement import _skin_z
        for shape in (163,164):
            model=self.models[shape];groups=source_groups(self.base['models'][shape])
            for t in model['triangles']:
                a,b,c=t['vertices'];n=cross(sub(b,a),sub(c,a))
                if t['component']=='fin_piebald_patch':self.assertGreater(n[0]*a[0],0)
                if t['component']=='stub_wing_piebald':self.assertGreater(n[2],0)
            for gi,side in ((3,-1),(4,1)):
                root,tip=side*65,side*199;reference=[]
                solid(reference,groups[gi],[[[root,-40,31],[tip,-36,27],[tip,48,27],[root,60,35]],
                      [[root,-40,37],[tip,-36,30],[tip,48,30],[root,60,40]]],'hind_olive','stub_wing')
                top=lambda ts:[t for t in ts if t['component'] in ('stub_wing','stub_wing_piebald') and t['vertices'][0][0]*side>0 and cross(sub(t['vertices'][1],t['vertices'][0]),sub(t['vertices'][2],t['vertices'][0]))[2]>0]
                self.assertAlmostEqual(sum(area2(t['vertices']) for t in top(model['triangles'])),sum(area2(t['vertices']) for t in top(reference)),delta=.001)
                paint=[t for t in top(model['triangles']) if t['component']=='stub_wing_piebald'];self.assertTrue(paint)
                for t in paint:
                    for v in t['vertices']:self.assertAlmostEqual(v[2],_skin_z({'triangles':reference},{'stub_wing'},v[0],v[1]),delta=.000002)

    def test_tracked_end_wheels_clear_roadwheels_and_t62_spacing_is_correct(self):
        import math
        for shape in (115,117,119,121,123,125,127,129,131,133,135,139):
            for side in (-1,1):
                parts={}
                for t in self.models[shape]['triangles']:
                    name=t['component']
                    if (name.startswith('roadwheel_') and name.endswith('_tyre') or name in ('drive_sprocket','track_idler')) and all(side*v[0]>0 for v in t['vertices']):
                        parts.setdefault(name,[]).extend(t['vertices'])
                circles={}
                for name,points in parts.items():
                    lo,hi=bounds(points).values();y,z=(lo[1]+hi[1])/2,(lo[2]+hi[2])/2
                    circles[name]=(y,z,max(math.hypot(v[1]-y,v[2]-z) for v in points))
                for name in ('drive_sprocket','track_idler'):
                    y,z,r=circles[name]
                    for other,(Y,Z,R) in circles.items():
                        if other.startswith('roadwheel_'):
                            self.assertGreater(math.hypot(y-Y,z-Z)-r-R,.25,(shape,side,name,other))
                if shape==115:
                    ys=sorted(y for n,(y,_,_) in circles.items() if n.startswith('roadwheel_'))
                    gaps=[b-a for a,b in zip(ys,ys[1:])]
                    self.assertEqual(len(ys),5);self.assertGreater(min(gaps[:2]),max(gaps[2:]))

    def test_idlers_are_smooth_closed_dishes_and_drive_teeth_match_bake_master(self):
        import math
        from collections import Counter
        from tools.build_pc_tactical_roster import authored
        for shape in (115,117,119,121,123,125,127,129,131,133,135,139):
            model=self.models[shape];master=authored(self.base['models'][shape],True)
            for name in ('drive_sprocket','track_idler'):
                ts=[t for t in model['triangles'] if t['component']==name]
                edges=Counter(tuple(sorted((tuple(a),tuple(b)))) for t in ts for a,b in zip(t['vertices'],t['vertices'][1:]+t['vertices'][:1]))
                self.assertTrue(edges);self.assertEqual(set(edges.values()),{2},(shape,name,'closed end-wheel body'))
                points=[v for t in ts for v in t['vertices'] if v[0]>0];lo,hi=bounds(points).values()
                y,z=(lo[1]+hi[1])/2,(lo[2]+hi[2])/2
                radii=[math.hypot(v[1]-y,v[2]-z) for v in points if abs(v[0]-hi[0])<1e-6]
                if name=='track_idler':self.assertAlmostEqual(max(radii),min(radii),places=5)
                else:
                    self.assertGreater(max(radii)-min(radii),max(radii)*.1)
                    self.assertEqual(ts,[t for t in master['triangles'] if t['component']==name],'exact game/master tooth stations')
            self.assertFalse(any(t['component']=='track_idler_tooth' for t in model['triangles']))

    def test_end_wheel_seat_respects_chamfered_track_shoulders(self):
        import math
        from tools.build_pc_tactical_vehicles import end_wheel_height
        # T-62's actual authored track loop. A box-only fit would put the
        # wheel through the diagonal upper shoulders at the ends of the belt.
        loop=[[-76,-30.8],[102,-30.8],[111,-22.8],[112,-2.5],
              [106,1.5],[-81,1.5],[-88,-3.5],[-88,-21.8]]
        radius=(1.5+30.8)*.30
        for y in (-88+radius+.6,112-radius-.6):
            z=end_wheel_height(loop,y,radius);margins=[]
            for a,b in zip(loop,loop[1:]+loop[:1]):
                dy,dz=b[0]-a[0],b[1]-a[1]
                margins.append((dy*(z-a[1])-dz*(y-a[0]))/math.hypot(dy,dz)-radius)
            self.assertGreaterEqual(min(margins),.149999)
            self.assertAlmostEqual(min(margins),.15,msg='wheel contacts the inner belt instead of floating in a generic box')

    def test_optical_apertures_clear_finished_casting_and_share_master_seats(self):
        from tools.build_pc_tactical_roster import authored
        from tools.pc_tactical_vehicle_refinement import _skin_y,_skin_z,_component_bounds
        cast={115:'cast_turret_dome',117:'t64_compound_cast_turret',119:'t72_compound_cast_turret',
              121:'t80_compound_cast_turret',127:'m60_long_nose_cast_turret'}
        for shape,name in cast.items():
            model=self.models[shape];master=authored(self.base['models'][shape],True);skin={name}
            parts={'infrared_searchlight_glass'} if shape==115 else {'thermal_sight_aperture','laser_rangefinder_aperture'} if shape==127 else {'infrared_lens','gunner_sight_aperture'}
            for part in parts:
                self.assertEqual(_component_bounds(model,{part}),_component_bounds(master,{part}))
                for t in model['triangles']:
                    if t['component']!=part:continue
                    for v in t['vertices']:
                        if 'infrared' in part:
                            surface=_skin_y(model,skin,v[0],v[2])
                            if surface is not None:self.assertGreater(v[1]-surface,.09,(shape,part,v))
                        else:self.assertGreater(v[2]-_skin_z(model,skin,v[0],v[1]),.09,(shape,part,v))
            if shape in (117,119,121):
                for part in ('refine_snorkel_stowage_stay','refine_snorkel_retaining_band','refine_searchlight_mount_stem'):
                    self.assertEqual(_component_bounds(model,{part}),_component_bounds(master,{part}))

    def test_roof_weapon_pedestals_contact_skin_without_moving_weapons(self):
        from tools.build_pc_tactical_vehicles import build_geometry
        from tools.pc_tactical_vehicle_refinement import _skin_z,_component_bounds
        for shape,part,skin in ((129,'commander_gun_mount',{'armoured_upper_hull_sloped_glacis'}),
                               (131,'machinegun_pedestal',{'bradley_angular_turret'}),
                               (139,'machinegun_pedestal',{'acrv_observation_cupola','observation_hatch'})):
            model=self.models[shape];old=build_geometry(self.base['models'][shape]);lo,hi=_component_bounds(model,{part}).values()
            x,y=(lo[0]+hi[0])/2,(lo[1]+hi[1])/2
            self.assertAlmostEqual(lo[2],_skin_z(model,skin,x,y)-.2)
            self.assertEqual(hi[2],_component_bounds(old,{part})['max'][2])
            weapons=lambda m:[t for t in m['triangles'] if 'machinegun' in t['component'] and t['component']!=part]
            self.assertEqual(weapons(model),weapons(old),'the existing gun and aim are immutable')
        m60=self.models[127];lo,hi=_component_bounds(m60,{'refine_cupola_mount_foot'}).values()
        self.assertAlmostEqual(lo[2],24.8);self.assertAlmostEqual(hi[2],29.2)

    def test_complete_roster_preserves_filled_group_custody_and_bounds(self):
        self.assertEqual(len(self.models),34)
        for index,model in self.models.items():
            with self.subTest(shape=index):
                self.assertTrue(validate_model(model));self.assertLessEqual(len(model['triangles']),8192)
                source={p['id']:p for p in model['source_primitives']}
                for t in model['triangles']:
                    self.assertGreaterEqual(len(source[t['source_primitive']]['vertices']),3)
                    self.assertEqual(t['source_groups'],[g['offset'] for g in model['groups'] if t['source_primitive'] in g['primitive_pointers']])
                self.assertEqual(model['source_primitives'],self.base['models'][index]['source_primitives'])
                self.assertEqual(model['source_lines'],self.base['models'][index]['source_lines'])
        self.assertTrue(set((161,162,165,166)).isdisjoint(self.models))

    def test_distinct_running_gear_and_original_rotor_states(self):
        for index,count in {117:6,119:6,121:6,127:6,129:5,131:6,133:6,135:6,139:7}.items():
            components={t['component'] for t in self.models[index]['triangles']}
            self.assertEqual({f'roadwheel_{i}_dish' for i in range(count)}, {c for c in components if c.startswith('roadwheel_') and c.endswith('_dish')})
        for index in (163,164):
            model=self.models[index];rotor=model['groups'][6]['offset']
            self.assertFalse(any(rotor in t['source_groups'] for t in model['triangles']))
            self.assertEqual(model['source_lines'],self.base['models'][index]['source_lines'])

    def test_carrier_and_m60_height_ratios_and_round_running_gear(self):
        # Gross height/width references: Bradley BAE 3.0/3.2, M113 Army
        # 2.5/2.6. The original source ceiling/ground remain fixed; running
        # gear is rebuilt, never made oval by a blanket vertical stretch.
        for index,target in ((129,.93),(131,.93),(127,.89),(137,.80),(141,1.04),(143,1.04)):
            lo,hi=self.models[index]['bounds'].values()
            with self.subTest(shape=index):
                self.assertAlmostEqual((hi[2]-lo[2])/(hi[0]-lo[0]),target,delta=.025)
        for index in (117,119,121,127,129,131,133,135,137,139,141,143,159):
            components={t['component'] for t in self.models[index]['triangles'] if t['component'].endswith('_tyre')}
            self.assertTrue(components)
            for component in components:
                points=[v for t in self.models[index]['triangles'] if t['component']==component for v in t['vertices']]
                lo,hi=bounds(points).values()
                with self.subTest(shape=index,wheel=component):
                    self.assertAlmostEqual(hi[1]-lo[1],hi[2]-lo[2],places=4)
        bradley=self.models[131]
        parts={t['component'] for t in bradley['triangles']}
        self.assertTrue({'tow_launcher_rim','tow_launcher_tube','bradley_troop_periscope','bradley_firing_port'}<=parts)
        for index,ceiling in ((133,51),(135,33)):
            self.assertLessEqual(self.models[index]['bounds']['max'][2],ceiling,'ATGM belongs close to the turret roof')
        for index in (141,143):
            # Body/running-gear proportions exclude projecting tow fittings.
            lo,hi=bounds([v for t in self.models[index]['triangles'] if not t['component'].startswith('refine_') for v in t['vertices']]).values()
            self.assertAlmostEqual((hi[1]-lo[1])/(hi[0]-lo[0]),2.44,delta=.03)
            model=self.models[index];parts={t['component'] for t in model['triangles']}
            self.assertFalse(any('_belly_' in c or 'brdm_rack_' in c or 'brdm_source_roof_rail'==c or 'brdm_missile_' in c for c in parts))
            self.assertIn('brdm_stowed_auxiliary_wheel_panel',parts)
            for part in ('brdm_launcher_canister','brdm_launcher_front_rim','brdm_launcher_end_cap'):
                ts=[t for t in model['triangles'] if t['component']==part]
                self.assertTrue(ts,(index,part))
                self.assertEqual({g for t in ts for g in t['source_groups']},{model['groups'][1]['offset']})
                for station in (-16,-8,0,8,16):
                    points=[v for t in ts if abs(sum(v[0] for v in t['vertices'])/3-station)<3.5 for v in t['vertices']]
                    self.assertTrue(points,(index,part,station))
            self.assertEqual(len([c for c in parts if c.endswith('_tyre')]),4,'four visible road wheels in the reference road-going pose')

    def test_molot_has_single_heavy_gun_broad_low_turret_and_seven_wheels(self):
        model=self.models[123];parts={t['component'] for t in model['triangles']}
        self.assertTrue({'molot_low_armoured_turret','molot_main_gun','molot_segmented_side_skirt','molot_sight_glass'}<=parts)
        self.assertFalse(parts&{'fst_left_pod','fst_right_pod','fst_paired_gun_tube','fst_barrel_bridge'})
        self.assertEqual({c for c in parts if c.startswith('roadwheel_') and c.endswith('_dish')},{f'roadwheel_{i}_dish' for i in range(7)})
        for part,group in (('molot_low_armoured_turret',4),('molot_main_gun',3),('molot_sight_glass',1),('molot_auxiliary_barrel',2)):
            ts=[t for t in model['triangles'] if t['component']==part]
            self.assertEqual({g for t in ts for g in t['source_groups']},{model['groups'][group]['offset']})
        lo,hi=bounds([v for t in model['triangles'] if t['component']=='molot_low_armoured_turret' for v in t['vertices']]).values()
        self.assertGreater(hi[0]-lo[0],34);self.assertLess(hi[2]-lo[2],11)
        lo,hi=bounds([v for t in model['triangles'] if t['component']=='molot_main_gun' for v in t['vertices']]).values()
        self.assertGreater(hi[0]-lo[0],3);self.assertEqual((lo[0]+hi[0])/2,0)

    def test_molot_reference_periscope_smoke_clusters_and_dished_wheels(self):
        from math import hypot
        model=self.models[123]
        part=lambda name:[v for t in model['triangles'] if t['component']==name for v in t['vertices']]
        sight=bounds(part('molot_sight_head'));glass=bounds(part('molot_sight_glass'))
        self.assertGreater(sight['max'][2]-sight['min'][2],6,'tall bevelled panoramic head')
        self.assertGreater(glass['max'][2]-glass['min'][2],4,'large upright periscope pane')
        self.assertGreater(glass['max'][1]-glass['min'][1],.9,'front pane follows the sloping hood')
        self.assertTrue(part('molot_periscope_brow') and part('molot_periscope_window_rim'))
        self.assertEqual(len([t for t in model['triangles'] if t['component']=='molot_smoke_launch_tube']),12*28)
        for name in ('molot_smoke_launch_tube','molot_smoke_tube_recess','molot_smoke_cluster_bracket','molot_turret_service_latch'):
            self.assertEqual({g for t in model['triangles'] if t['component']==name for g in t['source_groups']},{model['groups'][4]['offset']})
        for side in (-1,1):
            for i in range(7):
                tyre=[v for v in part(f'roadwheel_{i}_tyre') if v[0]*side>0]
                dish=[v for v in part(f'roadwheel_{i}_dish') if v[0]*side>0]
                b=bounds(tyre);diameter=b['max'][1]-b['min'][1]
                self.assertGreater(diameter,11,'fuller wheel nearly fills each original station')
                self.assertLess(diameter,12.75,'no wheel-to-wheel collision')
                self.assertGreaterEqual(b['min'][2],model['source_bounds']['min'][2])
                self.assertLess(min(v[0]*side for v in dish),max(v[0]*side for v in tyre)-.7,'steel dish recess remains visible')
                hub=part(f'roadwheel_{i}_hub')
                self.assertEqual(len({round(v[0]*side,5) for v in hub if v[0]*side>0}),3,'hub casting has a seated root, shoulder and axle cap')
                caps=[t for t in model['triangles'] if t['component']==f'roadwheel_{i}_dish' and t['vertices'][0][0]*side>0 and max(v[0] for v in t['vertices'])-min(v[0] for v in t['vertices'])<1e-6]
                self.assertEqual(len(caps),18)
                for t in caps:
                    a,b,c=t['vertices']
                    self.assertGreater(cross(sub(b,a),sub(c,a))[0]*side,0,'recessed rim must face outward on the culled runtime mesh')

    def test_bradley_compact_turret_has_connected_mantlet_and_raised_tow_box(self):
        model=self.models[131]
        def part(name):return bounds([v for t in model['triangles'] if t['component']==name for v in t['vertices']])
        turret=part('bradley_angular_turret');hull=part('armoured_upper_hull_sloped_glacis')
        self.assertLess(turret['max'][1]-turret['min'][1],(hull['max'][1]-hull['min'][1])*.55)
        self.assertLess(turret['max'][0]-turret['min'][0],(hull['max'][0]-hull['min'][0])*.73)
        self.assertGreater(part('tow_launcher_housing')['max'][2],turret['max'][2])
        mantlet=part('bradley_gun_mantlet');gun=part('25mm_autocannon')
        self.assertGreaterEqual(mantlet['max'][1],gun['min'][1])
        self.assertLessEqual(mantlet['min'][2],gun['min'][2]);self.assertGreaterEqual(mantlet['max'][2],gun['max'][2])

    def test_bradley_roof_vision_and_six_ports_keep_original_owners(self):
        model=self.models[131]
        for role,count in (('commander',8),('gunner',2)):
            glass=[t for t in model['triangles'] if t['component']==f'bradley_{role}_vision_glass']
            self.assertEqual(len(glass),count*2)
            self.assertEqual({g for t in glass for g in t['source_groups']},{model['groups'][1]['offset']})
        for name,count in (('bradley_troop_periscope',4),('bradley_rear_periscope',2)):
            parts=[t for t in model['triangles'] if t['component']==name]
            self.assertEqual(len(parts),count*12)
            self.assertEqual({g for t in parts for g in t['source_groups']},{model['groups'][0]['offset']})
        self.assertTrue(any(t['component']=='bradley_rear_firing_port' for t in model['triangles']))

    def test_molot_deck_does_not_share_the_overlapping_fender_top_plane(self):
        from tools.build_pc_tactical_roster import authored
        for master in (False,True):
            model=authored(self.base['models'][123],master)
            deck=[v[2] for t in model['triangles'] if t['component']=='fst_low_wedge_hull' for v in t['vertices']]
            fender=[v[2] for t in model['triangles'] if t['component']=='track_fender' for v in t['vertices']]
            self.assertGreaterEqual(max(fender)-max(deck),.3,'separate the overlapping planes to avoid the observed black bake seam')

    def test_refined_launch_canisters_and_turret_bases_are_formed_and_seated(self):
        for shape in (141,143):
            model=self.models[shape]
            ts=[t for t in model['triangles'] if t['component']=='brdm_launcher_canister']
            lo,hi=bounds([v for t in ts for v in t['vertices']]).values()
            self.assertGreater(hi[1]-lo[1],64)
            self.assertLess(hi[2],model['source_bounds']['max'][2])
            caps=[t for t in model['triangles'] if t['component']=='brdm_launcher_end_cap']
            self.assertTrue(caps)
            from tools.pc_tactical_finish import camouflage_role
            self.assertTrue(all(camouflage_role(shape,t['material'],t['component'])=='paint' for t in caps))
        for shape,part,deck in ((123,'molot_seated_turret_race',-4.45),(131,'bradley_turret_race',9.7)):
            model=self.models[shape]
            lo,hi=bounds([v for t in model['triangles'] if t['component']==part for v in t['vertices']]).values()
            self.assertLessEqual(lo[2],deck+.06)
            self.assertGreater(hi[2],deck+.5)

    def test_tracked_roadwheel_shoulders_are_formed_closed_and_cost_neutral(self):
        from math import hypot
        from tools.build_pc_tactical_roster import authored
        folder=ROOT/'local-art/pc-tactical-roster-v1'
        for shape in (115,117,119,121,123,125,127,129,131,133,135,139):
            current=self.models[shape]
            incumbent=json.loads((folder/str(shape)/'model.json').read_text())['model']
            self.assertEqual(len(current['triangles']),len(incumbent['triangles']),(shape,'unchanged runtime facet budget'))
            for master in (False,True):
                model=authored(self.base['models'][shape],True) if master else current
                names={t['component'] for t in model['triangles'] if t['component'].startswith('roadwheel_') and t['component'].endswith('_tyre')}
                for name in names:
                    triangles=[t for t in model['triangles'] if t['component']==name]
                    rim=[t for t in model['triangles'] if t['component']==name[:-5]+'_dish']
                    self.assertEqual(set(edge_counts(triangles+rim).values()),{2},(shape,name,'closed joined tyre/rim'))
                    if not master:
                        hubs=[t for t in model['triangles'] if t['component']==name[:-5]+'_hub']
                        self.assertEqual(len(triangles+rim+hubs),424 if shape==123 else 392,(shape,name,'bounded formed-wheel budget'))
                    for side in (-1,1):
                        points=[v for t in triangles for v in t['vertices'] if side*v[0]>0]
                        lo,hi=bounds(points).values();y=(lo[1]+hi[1])/2;z=(lo[2]+hi[2])/2
                        stations=sorted({round(side*v[0],6) for v in points})
                        self.assertEqual(len(stations),3,(shape,name,'real shoulder sections'))
                        outline={tuple(v) for v in points if abs(side*v[0]-stations[1])<.000001}
                        self.assertEqual(len(outline),32 if master else 20,(shape,name,'round outline retained'))
                        radii=[max(hypot(v[1]-y,v[2]-z) for v in points if abs(side*v[0]-x)<.000001) for x in stations]
                        self.assertAlmostEqual(radii[0]/radii[1],.94,delta=.000002)
                        self.assertAlmostEqual(radii[2]/radii[1],.86 if shape in (115,123,125) else .83 if shape in (129,131,133,135,139) else .85,delta=.000002)
                        rim_points=[v for t in rim for v in t['vertices'] if side*v[0]>0]
                        mounting={tuple(v) for v in rim_points if abs(side*v[0]-stations[-1])<.000001}
                        self.assertEqual(mounting,{tuple(v) for v in points if abs(side*v[0]-stations[-1])<.000001})

    def test_baked_roster_preserves_pair_source_and_proven_aliases(self):
        from tools.build_pc_tactical_roster import ALIASES,alias_model
        folder=ROOT/'local-art/pc-tactical-roster-v1'
        if not (folder/'manifest.json').exists():self.skipTest('complete roster bake unavailable')
        data=json.loads((folder/'catalog.json').read_text());manifest=json.loads((folder/'manifest.json').read_text())
        self.assertEqual(set(map(int,json.loads((folder/'authoring.json').read_text())['aliases'])),set(ALIASES))
        from tools.build_pc_tactical_roster import SCENE_SHAPES
        self.assertEqual({m['shape_index'] for m in data['models']},set(SCENE_SHAPES) if manifest['schema']==3 else set(self.models))
        self.assertLessEqual((folder/'catalog.json').stat().st_size,96*1024*1024)
        for name,digest in manifest['files'].items():self.assertEqual(hashlib.sha256((folder/name).read_bytes()).hexdigest(),digest)
        baked={m['shape_index']:m for m in data['models']}
        pair=json.loads((ROOT/'local-art/pc-tactical-vehicles-v1/catalog.json').read_text())
        for m in pair['models']:
            self.assertEqual(m['source_bounds'],baked[m['shape_index']]['source_bounds'])
            self.assertLessEqual(len(baked[m['shape_index']]['triangles']),8192)
        if manifest['schema']==3:
            self.assertNotEqual((folder/'pair-albedo.png').read_bytes(),(ROOT/'local-art/pc-tactical-vehicles-v1/albedo.png').read_bytes())
        else:
            self.assertEqual((folder/'pair-albedo.png').read_bytes(),(ROOT/'local-art/pc-tactical-vehicles-v1/albedo.png').read_bytes())
        for target,donor in ALIASES.items():
            reproduced,proof=alias_model(self.base['models'][donor],self.base['models'][target],baked[donor])
            self.assertEqual(reproduced['triangles'],baked[target]['triangles'])
            altered=copy.deepcopy(baked[donor]);altered['triangles'][0]['vertices'][0][0]+=.01
            with self.assertRaises(ValueError):alias_model(self.base['models'][donor],self.base['models'][target],altered)
        for m in data['models']:
            self.assertFalse(set(REGISTRY_FIELDS)&m.keys())
            self.assertIn(m['texture_bank'],('pair','intact','wreck','scene','bridge'))

    def test_baked_roster_exports_keep_normal_tangents_and_contact_occlusion(self):
        folder=ROOT/'local-art/pc-tactical-roster-v1'
        if not (folder/'manifest.json').exists():self.skipTest('complete roster bake unavailable')
        models=json.loads((folder/'catalog.json').read_text())['models']
        from tools.refine_pc_tactical_exports import verify_glb
        for model in models:
            with self.subTest(shape=model['shape_index']):
                proof=verify_glb(folder/str(model['shape_index'])/(model['name'].lower()+'.glb'))
                self.assertEqual(proof['meshes'],2 if model['shape_index'] in (161,162) else 1)

    def test_truck_lamps_seat_in_full_width_radiator_apron(self):
        model=self.models[159]
        def part(name):return bounds([v for t in model['triangles'] if t['component']==name for v in t['vertices']])
        apron=part('truck_radiator_apron');lamps=part('truck_seated_headlight_bezel')
        engine=part('truck_enclosed_engine_bay')
        self.assertGreater(engine['max'][2]-engine['min'][2],25)
        self.assertGreater(engine['max'][1]-engine['min'][1],28)
        self.assertGreater(apron['max'][0]-apron['min'][0],60)
        for axis in (0,2):
            self.assertLessEqual(apron['min'][axis],lamps['min'][axis])
            self.assertGreaterEqual(apron['max'][axis],lamps['max'][axis])
        self.assertLess(lamps['min'][1],apron['max'][1],'lamp housing intersects its supporting metal')
        screen=part('truck_split_windscreen')
        self.assertLess(screen['max'][1]-screen['min'][1],2,'slightly raked windscreen avoids the old wedge profile')
        recess=part('truck_grille_recess');bars=part('truck_grille_bar')
        self.assertLess(recess['max'][0]-recess['min'][0],(apron['max'][0]-apron['min'][0])*.53,'narrower grille fits between the inset lamps')
        for side in (-1,1):
            points=[v[0]*side for t in model['triangles'] if t['component']=='truck_seated_headlight_bezel' for v in t['vertices'] if v[0]*side>0]
            centre=(min(points)+max(points))*.5
            self.assertAlmostEqual(centre/abs(apron['max'][0]),30.5/44,delta=.01,msg='lamp assemblies move inward while the full-width apron stays')
        self.assertGreater(bars['max'][1]-recess['max'][1],1.5,'grille has actual physical depth')
        self.assertIn('truck_grille_return',{t['component'] for t in model['triangles']})
        # Looking through a gap between slats must hit the dark radiator, not
        # an opaque engine-bay cap or the former full-width apron box.
        hits=[];px,pz=1.5,-2.
        for t in model['triangles']:
            a,b,c=t['vertices']
            den=(b[2]-c[2])*(a[0]-c[0])+(c[0]-b[0])*(a[2]-c[2])
            if abs(den)<1e-9:continue
            u=((b[2]-c[2])*(px-c[0])+(c[0]-b[0])*(pz-c[2]))/den
            v=((c[2]-a[2])*(px-c[0])+(a[0]-c[0])*(pz-c[2]))/den
            if min(u,v,1-u-v)>=0:hits.append((u*a[1]+v*b[1]+(1-u-v)*c[1],t['component']))
        self.assertEqual(max(hits)[1],'truck_grille_recess')
        self.assertAlmostEqual(max(hits)[0],106.7)
        for t in model['triangles']:
            if t['component']=='truck_split_windscreen':
                a,b,c=t['vertices']
                self.assertGreater(cross(sub(b,a),sub(c,a))[1],0,'bake rays face out of the cab')
        from tools.pc_tactical_wheeled_vehicles import geometry
        for master in (False,True):
            triangles=geometry(self.base['models'][159],master)
            lugs=[t for t in triangles if t['component']=='truck_1_axle_2_lug']
            self.assertEqual(len(lugs),120,'six identical 20-triangle nuts in game and bake master')

    def test_polished_running_gear_has_matching_bake_paths_and_outward_glass(self):
        from tools.build_pc_tactical_roster import authored
        for shape in (115,117,119,121,123,125,127,129,131,133,135,139):
            game=[t for t in self.models[shape]['triangles'] if t['component']=='track_shoe']
            master=[t for t in authored(self.base['models'][shape],True)['triangles'] if t['component']=='track_shoe']
            self.assertEqual(game,master,'different shoe stations bake ghost joints onto the track')
        for shape in (137,141,143):
            name='btr_crew_windscreen' if shape==137 else 'brdm_broad_crew_windscreen'
            screen=[t for t in self.models[shape]['triangles'] if t['component']==name]
            self.assertTrue(screen)
            for t in screen:
                a,b,c=t['vertices'];self.assertGreater(cross(sub(b,a),sub(c,a))[1],0)

    def test_truck_canvas_hangs_between_retained_support_bows(self):
        from tools.build_pc_tactical_roster import authored
        game=authored(self.base['models'][159]);master=authored(self.base['models'][159],True)
        canvas=lambda m:[t for t in m['triangles'] if t['component']=='truck_canvas_cover']
        self.assertEqual(canvas(game),canvas(master),'bake and game cloth use the same folds')
        vertices={tuple(v) for t in canvas(game) for v in t['vertices']}
        station=lambda y:round(-78+(y+78)*102/119,6)
        for y in (-76,-48,-20,8,39):
            self.assertIn((0.,station(y),46.5),vertices,'bow crown remains supported')
            self.assertIn((32.25,station(y),16.),vertices,'lower tied hem stays anchored')
        for y in (-62,-34,-6,23.5):
            self.assertIn((0.,station(y),45.5),vertices,'cloth drops between bow crowns')
            self.assertTrue(any(v[1]==station(y) and 31.5<v[0]<32.25 and 28<v[2]<30 for v in vertices),'side skirt has shaped fullness')
        for y in (24,):
            caps=[t for t in canvas(game) if all(v[1]==y for v in t['vertices'])]
            self.assertEqual(len(caps),13,'collinear skirt stations must not remove the end cap')
            for t in caps:
                a,b,c=t['vertices'];normal=cross(sub(b,a),sub(c,a))
                self.assertGreater(normal[1]*(y+27),0,'closed canopy ends face outward')
        self.assertLessEqual(len(game['triangles']),8192)

    def test_truck_proportions_keep_cover_close_to_cab_and_wheels_round(self):
        model=self.models[159]
        lo,hi=model['bounds']['min'],model['bounds']['max']
        self.assertGreater((hi[1]-lo[1])/(hi[0]-lo[0]),2.65)
        self.assertLess((hi[1]-lo[1])/(hi[0]-lo[0]),3.0)
        top=lambda name:max(v[2] for t in model['triangles'] if t['component']==name for v in t['vertices'])
        cover=top('truck_canvas_cover');cab=top('truck_cab_shell')
        self.assertGreater(cover,cab)
        self.assertLess(cover-cab,(hi[2]-lo[2])*.12,'cover must not tower over the cab')
        tyres={t['component'] for t in model['triangles'] if t['component'].endswith('_tyre')}
        self.assertEqual(len(tyres),10,'two singles and four rear dual-wheel pairs')
        for name in tyres:
            wheel=bounds([v for t in model['triangles'] if t['component']==name for v in t['vertices']])
            self.assertAlmostEqual(wheel['max'][1]-wheel['min'][1],wheel['max'][2]-wheel['min'][2],delta=.1)
            self.assertAlmostEqual(wheel['min'][2],lo[2],delta=.01)

    def test_convoy_truck_has_dished_wheels_and_reference_cab_relationships(self):
        model=self.models[159]
        def part(name):return [v for t in model['triangles'] if t['component']==name for v in t['vertices']]
        for side in (-1,1):
            for axle in range(3):
                prefix=f'truck_{side}_axle_{axle}'
                lip=max(v[0]*side for v in part(prefix+'_rim'))
                dish=max(v[0]*side for v in part(prefix+'_vented_dish'))
                hub=max(v[0]*side for v in part(prefix+'_hub'))
                self.assertGreater(lip-dish,.3 if axle==2 else 2.,'steel dish must remain recessed')
                self.assertTrue(hub>lip if axle==2 else hub<lip,'front spindle and rear well are distinct')
                self.assertTrue(part(prefix+'_vent_return'),'punched openings have real depth')
                self.assertEqual({t['material'] for t in model['triangles'] if t['component']==prefix+'_vent_return'},{'wheel'},'recess returns retain painted steel instead of bright chipped-looking metal')
                outer=bounds(part(prefix+'_tyre'))
                if axle<2:
                    inner=bounds(part(prefix+'_inner_tyre'))
                    self.assertEqual(inner['min'][1:],outer['min'][1:])
                    self.assertEqual(inner['max'][1:],outer['max'][1:])
                    gap=min(v[0]*side for v in part(prefix+'_tyre'))-max(v[0]*side for v in part(prefix+'_inner_tyre'))
                    self.assertGreater(gap,.5,'dual tyres have a visible separation')
        cab=bounds(part('truck_cab_shell'));hood=bounds(part('truck_sloping_bonnet'))
        cargo=bounds(part('truck_canvas_cover'));wheel=bounds(part('truck_1_axle_2_tyre'))
        self.assertLess(cargo['max'][1],cab['min'][1])
        self.assertLess(cab['min'][1]-cargo['max'][1],6)
        self.assertAlmostEqual(cab['max'][1],hood['min'][1])
        self.assertGreater(hood['max'][1]-hood['min'][1],40,'bonnet no longer compressed')
        self.assertGreater((wheel['min'][1]+wheel['max'][1])/2,hood['min'][1],'front axle sits beneath bonnet')
        self.assertTrue(part('truck_screen_gasket') and part('truck_sideglass_gasket'))
        self.assertTrue(part('truck_cab_mirror_arm') and part('truck_cab_mirror'))
        self.assertGreater((hood['max'][0]-hood['min'][0])/(cab['max'][0]-cab['min'][0]),.90,'broad bonnet fills the cab width')
        step=bounds(part('truck_cab_step'))
        self.assertGreater(step['max'][0]-cab['max'][0],3)
        self.assertLess(step['max'][2],cab['min'][2]-7,'boarding platform is a visible lower step')
        self.assertTrue(part('truck_cab_step_bracket') and part('truck_cab_step_tread'))
        self.assertTrue(part('truck_canvas_entry_ajar_flap') and part('truck_canvas_entry_fold'))
        # A rear-facing sightline through the entry must reach cargo space,
        # rather than the old solid canvas end cap.
        hits=[]
        for t in model['triangles']:
            a,b,c=t['vertices'];px,pz=0.,27.
            den=(b[2]-c[2])*(a[0]-c[0])+(c[0]-b[0])*(a[2]-c[2])
            if abs(den)<1e-9:continue
            u=((b[2]-c[2])*(px-c[0])+(c[0]-b[0])*(pz-c[2]))/den
            v=((c[2]-a[2])*(px-c[0])+(a[0]-c[0])*(pz-c[2]))/den
            if min(u,v,1-u-v)>=0:hits.append(u*a[1]+v*b[1]+(1-u-v)*c[1])
        self.assertTrue(hits)
        self.assertGreater(min(hits),-77,'narrow centre gap reveals cargo behind the flap')

    def test_truck_crowned_hood_loaded_bed_ajar_flap_and_signal_lenses(self):
        model=self.models[159]
        part=lambda name:[v for t in model['triangles'] if t['component']==name for v in t['vertices']]
        bonnet=part('truck_sloping_bonnet')
        front=[v for v in bonnet if v[1]==108]
        crown=max(v[2] for v in front if abs(v[0])<.01)
        self.assertGreater(crown,max(v[2] for v in front if abs(v[0])>25)+.6,'rounded top shoulders and crown')
        cargo=[t for t in model['triangles'] if t['component']=='truck_bed_cargo_crate']
        self.assertEqual(len(cargo),3*12)
        b=bounds(part('truck_bed_cargo_crate'))
        self.assertGreater(b['max'][2]-b['min'][2],23,'substantial load boxes')
        self.assertEqual(b['min'][2],5,'crates rest on the bed floor')
        flap=part('truck_canvas_entry_ajar_flap');left=max(v[0] for v in flap if v[0]<0);right=min(v[0] for v in flap if v[0]>0)
        self.assertGreater(right-left,2);self.assertLess(right-left,4,'only a narrow slit remains')
        self.assertGreater(max(v[1] for v in flap)-min(v[1] for v in flap),1,'flap leaves are visibly ajar')
        self.assertGreater(len({round(v[2],4) for v in flap if 24<v[2]<31}),0,'intermediate cloth row softens the hanging flap')
        for name,material,group in (('truck_recessed_headlight_lens','truck_headlamp_glass',0),('truck_front_indicator','truck_indicator_glass',0),('truck_tail_lamp','truck_stop_glass',3),('truck_rear_indicator','truck_indicator_glass',3)):
            ts=[t for t in model['triangles'] if t['component']==name]
            self.assertTrue(ts,name);self.assertEqual({t['material'] for t in ts},{material})
            self.assertEqual({g for t in ts for g in t['source_groups']},{model['groups'][group]['offset']})
        lens=bounds(part('truck_recessed_headlight_lens'))
        self.assertGreater(lens['max'][1]-lens['min'][1],.3,'formed glass has convex depth')
        self.assertTrue(part('truck_tail_lamp_housing') and part('truck_front_signal_housing'))

    def test_baked_truck_flap_has_no_black_projection_holes(self):
        from PIL import Image
        folder=ROOT/'local-art/pc-tactical-roster-v1/159'
        if not (folder/'model.json').exists():self.skipTest('truck bake unavailable')
        data=json.loads((folder/'model.json').read_text())['model']
        image=Image.open(folder/'albedo.png').convert('RGB');sampled=0
        for triangle in data['triangles']:
            if triangle['component']!='truck_canvas_entry_ajar_flap':continue
            a,b,c=triangle['vertices'];normal=cross(sub(b,a),sub(c,a))
            if normal[1]>=-1 or abs(normal[1])<abs(normal[0])+abs(normal[2]):continue
            for weights in ((1/3,1/3,1/3),(.6,.2,.2),(.2,.6,.2),(.2,.2,.6)):
                u,v=[sum(w*uv[k] for w,uv in zip(weights,triangle['uvs'])) for k in range(2)]
                x=min(image.width-1,max(0,int(u*image.width)));y=min(image.height-1,max(0,int(v*image.height)))
                self.assertGreater(min(image.getpixel((x,y))),45,'opaque canvas must not carry a black missing-ray patch')
                sampled+=1
        self.assertEqual(sampled,16*4,'sample every curved strip on both rear-facing flap leaves')

    def test_wreck_families_keep_distinct_profiles_and_matching_bake_track_stations(self):
        from tools.build_pc_tactical_roster import ALIASES,authored
        for shape in (120,122,128,134,136):self.assertNotIn(shape,ALIASES)
        silhouettes=[]
        for shape in (118,120,122,128,132,134,136):
            silhouettes.append({tuple(v) for t in self.models[shape]['triangles'] for v in t['vertices']})
        self.assertEqual(len({frozenset(s) for s in silhouettes}),len(silhouettes))
        parts={t['component'] for t in self.models[126]['triangles']}
        self.assertIn('abrams_collapsed_angular_turret',parts)
        self.assertNotIn('displaced_torn_turret',parts)
        parts={t['component'] for t in self.models[124]['triangles']}
        self.assertIn('molot_collapsed_turret_cheek',parts)
        for shape in (116,120,126,130,134):
            def track(model):
                return [t['vertices'] for t in model['triangles'] if t['component'] in ('broken_lower_track_shoe','buckled_upper_track_shoe')]
            self.assertEqual(track(self.models[shape]),track(authored(self.base['models'][shape],True)))

    def test_carrier_access_fittings_retain_the_original_hull_owner(self):
        for shape in (129,131,133,135,139):
            m=self.models[shape]
            for part in ('refine_driver_vision_coaming','refine_driver_vision_glass',
                         'refine_rear_hinge_knuckle','refine_rear_service_latch'):
                triangles=[t for t in m['triangles'] if t['component']==part]
                self.assertTrue(triangles,(shape,part))
                self.assertTrue(all(t['source_groups']==[m['groups'][0]['offset']] for t in triangles))

    def test_bmp_launchers_have_distinct_structural_parts_on_original_owner(self):
        required={133:{'sagger_launch_rail_web','sagger_launch_rail_flange','sagger_rail_mount',
                       'sagger_rail_pivot','sagger_missile_body','sagger_swept_fin','sagger_nose_probe'},
                  135:{'atgm_pedestal_foot','atgm_launcher_support','atgm_cradle_pivot',
                       'atgm_launch_cradle','atgm_launch_canister','atgm_canister_clamp','atgm_canister_end_seal'}}
        from tools.build_pc_tactical_roster import authored
        for shape,parts in required.items():
            model=self.models[shape];owner=model['groups'][3]['offset']
            self.assertTrue(parts<={t['component'] for t in model['triangles']})
            for master in (False,True):
                triangles=authored(self.base['models'][shape],master)['triangles']
                launch=[t for t in triangles if t['component'] in parts]
                self.assertTrue(all(t['source_groups']==[owner] for t in launch))
                self.assertTrue(validate_model(authored(self.base['models'][shape],master)))
            if shape==133:
                fins=[t for t in model['triangles'] if t['component']=='sagger_swept_fin']
                self.assertEqual(len(fins),48,'four closed swept fins, each twelve triangles')

    def test_service_hardware_fits_existing_hull_owned_cases_and_grilles(self):
        for shape in (115,117,119,121,125,127,129,131,139):
            model=self.models[shape];owner=model['groups'][0]['offset']
            bed=[t for t in model['triangles'] if t['component']=='refine_recessed_engine_grille_bed']
            slats=[t for t in model['triangles'] if t['component']=='engine_deck_grille' or t['component'].startswith('engine_grille_')]
            self.assertEqual(len(bed),12)
            self.assertTrue(all(t['source_groups']==[owner] for t in bed))
            self.assertTrue(all(t['material']=='olive_edge' for t in slats))
            self.assertLess(max(v[2] for t in bed for v in t['vertices']),min(v[2] for t in slats for v in t['vertices']))
            if shape in (115,117,119,121,127):
                for part in ('refine_service_case_lid','refine_service_case_hinge','refine_service_case_latch'):
                    ts=[t for t in model['triangles'] if t['component']==part];self.assertTrue(ts)
                    self.assertTrue(all(t['source_groups']==[owner] for t in ts))

    def test_wipers_follow_glass_and_hind_side_panels_face_outward(self):
        for shape,screen in ((137,'btr_crew_windscreen'),(141,'brdm_broad_crew_windscreen'),(143,'brdm_broad_crew_windscreen')):
            model=self.models[shape];a,b,c=next(t['vertices'] for t in model['triangles'] if t['component']==screen)
            normal=cross(sub(b,a),sub(c,a));length=sum(x*x for x in normal)**.5
            points=[v for t in model['triangles'] if 'windscreen_wiper' in t['component'] for v in t['vertices']]
            self.assertTrue(points)
            for v in points:
                distance=sum(normal[k]*(v[k]-a[k]) for k in range(3))/length
                self.assertGreaterEqual(distance,-.001)
                self.assertLessEqual(distance,.55,'wiper arm/blade must stay on the glazing plane')
        for shape in (163,164):
            model=self.models[shape]
            for t in model['triangles']:
                if t['component'] in ('cabin_window','cabin_window_frame','main_gear_door'):
                    a,b,c=t['vertices'];normal=cross(sub(b,a),sub(c,a))
                    self.assertGreater(normal[0]*sum(v[0] for v in (a,b,c)),0,'both sides face away from fuselage')
            # Door vertices sit on the actual polygonal fuselage with a shallow
            # .43-unit surface offset, rather than a floating fixed-X box.
            skin=[t for t in model['triangles'] if t['component']=='sculpted_fuselage']
            points={tuple(v) for t in model['triangles'] if t['component']=='main_gear_door' for v in t['vertices']}
            for x,y,z in points:
                hits=[]
                for t in skin:
                    a,b,c=t['vertices'];den=(b[2]-c[2])*(a[1]-c[1])+(c[1]-b[1])*(a[2]-c[2])
                    if abs(den)<1e-9:continue
                    u=((b[2]-c[2])*(y-c[1])+(c[1]-b[1])*(z-c[2]))/den
                    v=((c[2]-a[2])*(y-c[1])+(a[1]-c[1])*(z-c[2]))/den
                    if min(u,v,1-u-v)>=-1e-7:hits.append(u*a[0]+v*b[0]+(1-u-v)*c[0])
                self.assertTrue(hits)
                # Interpolated skin rings differ slightly from the diagonal
                # triangulation of their quads. Keep that sub-.04 allowance.
                self.assertAlmostEqual(abs(x)-max(hits),.43,delta=.04)


@unittest.skipUnless((ROOT/'local-art/pc-modern/catalog.json').exists(),'local authored catalogue unavailable')
class TacticalSceneAuthoringTests(unittest.TestCase):
    def test_base_has_human_scale_door_and_two_window_storeys(self):
        from tools.build_pc_tactical_roster import authored
        model=authored(load_catalog()['models'][155])
        door=bounds([v for t in model['triangles'] if t['component']=='architecture_recessed_leaf' for v in t['vertices']])
        height=door['max'][2]-door['min'][2];width=door['max'][0]-door['min'][0]
        self.assertGreater(height/width,1.9)
        self.assertLess(height/width,2.5,'door must not stretch over the full source cube')
        self.assertLess(height,(model['bounds']['max'][2]-model['bounds']['min'][2])*.45)
        glazing=[t for t in model['triangles'] if t['component']=='architecture_glazing']
        self.assertEqual(len(glazing),32,'two windows on each of two storeys, four walls')
        self.assertEqual({round(min(v[2] for v in t['vertices']),2) for t in glazing},{-92.16,25.6})
        for t in glazing:
            b=bounds(t['vertices']);width=max(b['max'][k]-b['min'][k] for k in (0,1))
            self.assertGreater((b['max'][2]-b['min'][2])/width,.9)
            self.assertLess((b['max'][2]-b['min'][2])/width,1.4)
        self.assertEqual(sum(t['component']=='architecture_flat_roof' for t in model['triangles']),2)
        self.assertEqual(sum(t['component']=='architecture_roof_coping_return' for t in model['triangles']),8)

    def test_red_roof_cap_faces_up_without_changing_its_source_paint(self):
        from tools.build_pc_tactical_roster import authored
        original=load_catalog()['models'][151]
        old=[t for t in original['triangles'] if t['source_primitive']==26634]
        self.assertEqual(len(old),10)
        for master in (False,True):
            model=authored(original,master)
            cap=[t for t in model['triangles'] if t['source_primitive']==26634]
            self.assertEqual(len(cap),len(old))
            for before,after in zip(old,cap):
                self.assertEqual({k:v for k,v in before.items() if k!='vertices'},
                                 {k:v for k,v in after.items() if k!='vertices'})
                self.assertEqual(sorted(map(tuple,before['vertices'])),sorted(map(tuple,after['vertices'])))
                a,b,c=after['vertices']
                self.assertGreater(cross(sub(b,a),sub(c,a))[2],0,'roof cap exterior faces upward')

    def test_intact_roof_course_lips_run_along_the_eaves(self):
        from tools.build_pc_tactical_roster import authored
        base=load_catalog()['models']
        for shape in (145,151,153,156,157):
            model=authored(base[shape]);lips=[t for t in model['triangles'] if t['component']=='architecture_tile_lip']
            self.assertTrue(lips)
            for t in lips:
                zs=[v[2] for v in t['vertices']]
                self.assertAlmostEqual(max(zs)-min(zs),.55,delta=.000003,msg=(shape,t['source_primitive']))

    def test_building_drainage_is_exposed_and_brackets_reach_the_facade(self):
        from tools.build_pc_tactical_roster import authored
        base=load_catalog()['models']
        for shape in (145,151,153,155,156,157):
            for master in (False,True):
                model=authored(base[shape],master);checked=0
                for source in base[shape]['source_primitives']:
                    ts=[t for t in model['triangles'] if t['source_primitive']==source['id']]
                    walls=[t for t in ts if t['component']=='architecture_wall']
                    pipes=[t for t in ts if t['component'] in ('architecture_gutter','architecture_downpipe')]
                    if not pipes:continue
                    self.assertTrue(walls)
                    q=source['vertices'];axis=next(k for k in (0,1) if max(v[k] for v in q)-min(v[k] for v in q)<.001)
                    a,b,c=walls[0]['vertices'];inward=-1 if cross(sub(b,a),sub(c,a))[axis]>0 else 1;plane=a[axis]
                    self.assertTrue(all(abs(v[axis]-plane)<.000003 for t in walls for v in t['vertices']))
                    for t in pipes:
                        self.assertGreater(min((plane-v[axis])*inward for v in t['vertices']),.01,(shape,master,source['id'],t['component']))
                        self.assertGreaterEqual(min((v[axis]-q[0][axis])*inward for v in t['vertices']),0)
                    straps=[v for t in ts if t['component']=='architecture_pipe_strap' for v in t['vertices']]
                    self.assertTrue(straps)
                    self.assertLess(min((plane-v[axis])*inward for v in straps),0)
                    self.assertGreater(max((plane-v[axis])*inward for v in straps),.1)
                    checked+=1
                self.assertGreaterEqual(checked,4)

    def test_intact_slate_courses_have_restrained_piecewise_colour_variation(self):
        from tools.build_pc_tactical_roster import authored
        from tools.pc_tactical_architecture import FINISHES
        base=load_catalog()['models']
        for shape in (145,151,153,155,156,157):
            model=authored(base[shape]);slates=[t for t in model['triangles'] if t['component']==('architecture_flat_roof' if shape==155 else 'architecture_slate_course')]
            self.assertTrue(slates)
            colours={t['material'] for t in slates};self.assertEqual(len(colours),1 if shape==155 else 5)
            for mat in colours:
                self.assertTrue(mat=='architecture_slate' if shape==155 else mat.startswith('architecture_slate_'))
                role,rgb,profile=FINISHES[mat];self.assertEqual(role,'roof_slate');self.assertEqual(profile[2],0)
                self.assertTrue(all(abs(a-b)<=5 for a,b in zip(rgb,(65,79,89))))

    def test_cottage_window_reveals_face_into_each_opening(self):
        from tools.build_pc_tactical_roster import authored
        base=load_catalog()['models']
        for shape in (147,149):
            model=authored(base[shape]);count=0
            for pid in {t['source_primitive'] for t in model['triangles']}:
                ts=[t for t in model['triangles'] if t['component']=='cabin_window_reveal' and t['source_primitive']==pid]
                self.assertEqual(len(ts)%8,0)
                for start in range(0,len(ts),8):
                    block=ts[start:start+8];lo,hi=bounds([v for t in block for v in t['vertices']]).values();centre=[(a+b)/2 for a,b in zip(lo,hi)]
                    for t in block:
                        a,b,c=t['vertices'];n=cross(sub(b,a),sub(c,a));p=[sum(v[k] for v in (a,b,c))/3 for k in range(3)]
                        self.assertLess(sum(n[k]*(p[k]-centre[k]) for k in range(3)),0,'reveal faces into its opening');count+=1
            self.assertEqual(count,64)

    def test_architecture_exterior_normals_and_reveals_face_the_visible_surface(self):
        from tools.build_pc_tactical_roster import authored
        base=load_catalog()['models']
        facade={'architecture_wall','architecture_gable','architecture_glazing','architecture_upper_glazing','architecture_recessed_leaf','architecture_interior'}
        roof={'architecture_slate_course','architecture_clay_tile','architecture_roof_deck','architecture_fractured_roof_tile','architecture_flat_roof','architecture_roof_coping'}
        for shape in (145,146,151,153,154,155,156,157,158):
            model=authored(base[shape]);sources={p['id']:p['vertices'] for p in base[shape]['source_primitives']}
            for t in model['triangles']:
                if t['component'] not in facade|roof:continue
                a,b,c=t['vertices'];n=cross(sub(b,a),sub(c,a))
                if t['component'] in roof:self.assertGreater(n[2],0,(shape,t['component']))
                else:
                    q=sources[t['source_primitive']];axis=next(k for k in (0,1) if max(v[k] for v in q)-min(v[k] for v in q)<.001)
                    inward=-1 if q[0][axis]>0 else 1
                    if shape==157 and axis==0 and q[0][axis]==120:inward=1
                    self.assertLess(n[axis]*inward,0,(shape,t['component']))
            for pid in sources:
                ts=[t for t in model['triangles'] if t['component']=='architecture_reveal' and t['source_primitive']==pid]
                self.assertEqual(len(ts)%8,0)
                for start in range(0,len(ts),8):
                    block=ts[start:start+8];lo,hi=bounds([v for t in block for v in t['vertices']]).values();centre=[(a+b)/2 for a,b in zip(lo,hi)]
                    for t in block:
                        a,b,c=t['vertices'];n=cross(sub(b,a),sub(c,a));p=[sum(v[k] for v in (a,b,c))/3 for k in range(3)]
                        self.assertLess(sum(n[k]*(p[k]-centre[k]) for k in range(3)),0,'reveal faces into its opening')

    def test_architecture_bake_master_uses_the_game_tile_and_foundation_stations(self):
        from tools.build_pc_tactical_roster import authored
        base=load_catalog()['models'];parts={'architecture_slate_course','architecture_clay_tile','architecture_tile_lip','architecture_fractured_roof_tile','architecture_foundation','architecture_flat_roof','architecture_roof_coping','architecture_roof_coping_return'}
        for shape in (153,155,156,157,158):
            game=authored(base[shape]);master=authored(base[shape],True)
            self.assertEqual([t for t in game['triangles'] if t['component'] in parts],[t for t in master['triangles'] if t['component'] in parts])
            tail_count=lambda m:sum(t['component']=='architecture_rafter_tail' for t in m['triangles'])
            self.assertEqual(tail_count(game)//(12 if shape==158 else 20),tail_count(master)//28)

    def test_roof_bakes_keep_ceramic_and_slate_dielectric(self):
        from PIL import Image
        for shape in (145,146,154,155,158):
            folder=ROOT/'local-art/pc-tactical-roster-v1'/str(shape)
            if not (folder/'model.json').is_file():self.skipTest('ruined farm bake unavailable')
            model=json.loads((folder/'model.json').read_text())['model']
            metal=Image.open(folder/'metallic.png').convert('L')
            rough=Image.open(folder/'roughness.png').convert('L')
            count=0
            for triangle in model['triangles']:
                if triangle['component'] not in ('architecture_clay_tile','architecture_slate_course','architecture_fractured_roof_tile','architecture_flat_roof'):continue
                for weights in ((1/3,1/3,1/3),(.6,.2,.2),(.2,.6,.2),(.2,.2,.6)):
                    u,v=[sum(weights[j]*triangle['uvs'][j][k] for j in range(3)) for k in range(2)]
                    pixel=(min(metal.width-1,int(u*metal.width)),min(metal.height-1,int(v*metal.height)))
                    self.assertLessEqual(metal.getpixel(pixel),3,'roof tile must not pick up zinc reflectivity')
                    self.assertGreater(rough.getpixel(pixel),150,'roof tile must not become mirror-smooth')
                    count+=1
            if shape==155:self.assertEqual(count,8,'both flat roof triangles sampled four ways')
            else:self.assertGreater(count,1900)

    def test_ruin_roof_tile_lips_face_down_the_pitch(self):
        from tools.build_pc_tactical_roster import authored
        base=load_catalog()['models']
        for shape in (146,154,158):
            sources={p['id']:p['vertices'] for p in base[shape]['source_primitives']}
            lips=[t for t in authored(base[shape])['triangles'] if t['component']=='architecture_tile_lip']
            self.assertTrue(lips)
            for t in lips:
                q=sources[t['source_primitive']]
                roof=cross(sub(q[1],q[0]),sub(q[2],q[0]))
                if roof[2]<0:roof=[-v for v in roof]
                a,b,c=t['vertices'];normal=cross(sub(b,a),sub(c,a))
                self.assertGreater(normal[0]*roof[0]+normal[1]*roof[1],0,'surviving roof courses lap down the pitch')

    def test_scene_geometry_keeps_original_commands_and_partial_status(self):
        from tools.build_pc_tactical_roster import SCENE,BRIDGES,SCENE_SHAPES,authored
        base=load_catalog()
        self.assertEqual(len(SCENE_SHAPES),57)
        for shape in SCENE+BRIDGES:
            with self.subTest(shape=shape):
                original=base['models'][shape];model=authored(original)
                self.assertNotEqual(model['triangles'],original['triangles'])
                self.assertLessEqual(len(model['triangles']),8192)
                for field in REGISTRY_FIELDS:self.assertEqual(model[field],original[field])
                for t in model['triangles']:
                    self.assertEqual(t['source_groups'],[g['offset'] for g in original['groups'] if t['source_primitive'] in g['primitive_pointers']])
                self.assertEqual(model.get('status'),original.get('status'))
                self.assertEqual(model['source_passthrough'],{153:[27177],156:[28325]}.get(shape,[]))

    def test_cabin_has_real_roof_openings_and_original_pose_custody(self):
        from tools.build_pc_tactical_roster import authored
        base=load_catalog()['models'][147];model=authored(base)
        self.assertLessEqual(len(model['triangles']),8192)
        parts={t['component'] for t in model['triangles']}
        self.assertTrue({'cabin_clay_tile','cabin_ridge_cap','cabin_window_reveal',
                         'cabin_recessed_glazing','cabin_door_handle','cabin_downpipe'}<=parts)
        roof=[v for t in model['triangles'] if t['component']=='cabin_clay_tile' for v in t['vertices']]
        self.assertGreater(max(v[2] for v in roof)-min(v[2] for v in roof),35)
        ids={p['id'] for p in base['source_primitives']}
        for t in model['triangles']:
            self.assertIn(t['source_primitive'],ids)
            self.assertEqual(t['source_groups'],[base['groups'][0]['offset']])
            for v in t['vertices']:
                for k in range(3):self.assertTrue(base['source_bounds']['min'][k]<=v[k]<=base['source_bounds']['max'][k])
        glass=[v for t in model['triangles'] if t['component']=='cabin_recessed_glazing' and t['source_primitive']==25884 for v in t['vertices']]
        walls=[v for t in model['triangles'] if t['component']=='cabin_wall' and t['source_primitive']==25884 for v in t['vertices']]
        self.assertGreater(min(v[0] for v in walls)-max(v[0] for v in glass),3)

    def test_architecture_ruins_retain_flags_and_show_construction(self):
        from tools.build_pc_tactical_roster import authored
        base=load_catalog()
        for shape in (145,146,148,149,150,151,152,153,154,155,156,157,158):
            original=base['models'][shape];model=authored(original)
            parts={t['component'] for t in model['triangles']}
            self.assertTrue('architecture_flat_roof' in parts if shape==155 else any('tile' in x or 'slate' in x for x in parts),shape)
            if shape in (148,150,152):
                self.assertIn('architecture_fallen_slab_edge',parts)
                self.assertIn('architecture_torn_window_frame',parts)
            elif shape!=149:self.assertIn('architecture_reveal',parts)
            variants=(model,authored(original,True)) if shape in (153,155,156) else (model,)
            for component in ('soviet_star','us_army_star'):
                old=[t for t in original['triangles'] if t['component']==component]
                for variant in variants:
                    current=[t for t in variant['triangles'] if t['component']==component]
                    self.assertEqual(len(current),len(old))
                    for before,after in zip(old,current):
                        self.assertEqual({k:v for k,v in before.items() if k!='vertices'},
                                         {k:v for k,v in after.items() if k!='vertices'})
                        self.assertEqual(sorted(map(tuple,before['vertices'])),sorted(map(tuple,after['vertices'])))
                        source=next(p for p in original['source_primitives'] if p['id']==after['source_primitive'])['vertices']
                        axis=next((k for k in (0,1) if max(v[k] for v in source)-min(v[k] for v in source)<.001),2)
                        outward=1 if axis==2 or source[0][axis]>0 else -1
                        a,b,c=after['vertices']
                        self.assertGreater(cross(sub(b,a),sub(c,a))[axis]*outward,0,'painted star faces outward')
            for pid in model['source_passthrough']:
                self.assertEqual([t for t in model['triangles'] if t['source_primitive']==pid],
                                 [t for t in original['triangles'] if t['source_primitive']==pid])

    def test_crew_has_two_arms_two_legs_and_a_seated_knee(self):
        from tools.build_pc_tactical_roster import authored
        base=load_catalog()['models']
        for shape in (161,162):
            for master in (False,True):
                source=base[shape];model=authored(source,master)
                self.assertEqual(model['presentation_pose']['kind'],'ground-atgm-v1')
                self.assertEqual(model['source_primitives'],source['source_primitives'])
                self.assertTrue(validate_model(model))
                self.assertTrue(all(t['source_primitive']==source['source_primitives'][0]['id'] for t in model['triangles']),
                                'whole-object presentation has one immutable provenance anchor')
                # One raised knee and one grounded knee, in distinct lateral lanes.
                trousers=[v for t in model['triangles'] if t['component']=='crew_trousers_sculpt' for v in t['vertices']]
                self.assertTrue(any(v[0]>-5 and v[1]<8 and -76<v[2]<-70 for v in trousers))
                self.assertTrue(any(-16<v[0]<-9 and v[1]>10 and v[2]<-87 for v in trousers))
                for ylo,yhi in ((-1,8),(9,20)):
                    foot=[v for t in model['triangles'] if t['component'].startswith('crew_boot') for v in t['vertices'] if ylo<v[1]<yhi]
                    self.assertTrue(foot);self.assertLess(min(v[2] for v in foot),-89.3)

    def test_crew_boots_have_foot_length_toe_heel_and_instep(self):
        from tools.build_pc_tactical_roster import authored
        for shape in (161,162):
            model=authored(load_catalog()['models'][shape])
            self.assertLessEqual(len(model['triangles'])+len(model['command_head']['triangles']),8192)
            for near in (False,True):
                points=[v for t in model['triangles'] if t['component'].startswith('crew_boot') for v in t['vertices'] if (v[1]<9)==near]
                lo,hi=bounds(points).values()
                self.assertGreater(hi[0]-lo[0],9,'formed foot length follows its new X-facing pose')
                self.assertLess(hi[0]-lo[0],15)
                self.assertGreater(hi[1]-lo[1],3.5)
                self.assertLess(hi[1]-lo[1],7.5)
                self.assertGreater(hi[2]-lo[2],5,'ankle rises above the low toe box')

    def test_kneeling_boots_have_low_toes_and_articulated_rear_ankle(self):
        from tools.build_pc_tactical_roster import authored
        for shape in (161,162):
            model=authored(load_catalog()['models'][shape])
            for near in (False,True):
                vs=[v for t in model['triangles'] if t['component'].startswith('crew_boot') for v in t['vertices'] if (v[1]<9)==near]
                # Both feet have opposing directions in the kneeling pose.
                toe=[v for v in vs if v[0]>0] if near else [v for v in vs if v[0]<-27]
                heel=[v for v in vs if v[0]<-7] if near else [v for v in vs if -25<v[0]<-23]
                self.assertTrue(toe and heel)
                self.assertLess(max(v[2] for v in toe),-86)
                if near:self.assertLess(min(v[2] for v in heel),-89.3)
                else:self.assertGreater(min(v[2] for v in heel),-88.9,'folded rear heel lifts above its grounded toe')
                self.assertGreater(max(v[2] for v in vs),-84)

    def test_atlas_sliver_repair_recovers_collapsed_sculpt_islands(self):
        from types import SimpleNamespace as NS
        from copy import deepcopy
        from tools.build_pc_tactical_roster import guard_atlas_uvs
        class Loop:
            def __init__(self,p):self.value=p
            @property
            def uv(self):return NS(x=self.value[0],y=self.value[1])
            @uv.setter
            def uv(self,p):self.value=p
        for last in ((.4,.4),(.40002,.4)):
            loops=[Loop(p) for p in ((.4,.4),(.4,.4),last)]
            obj=NS(data=NS(uv_layers=NS(active=NS(data=loops)),polygons=[NS(loop_indices=(0,1,2))]))
            model={'triangles':[{'source_primitive':30888}],'command_head':{}}
            before=deepcopy(model);repairs=guard_atlas_uvs(obj,model,161)
            self.assertEqual(model,before,'UV repair cannot alter source geometry')
            self.assertEqual(len(repairs),1)
            self.assertEqual(len({tuple(v) for v in repairs[0]['new_uvs']}),3)
            self.assertLess(repairs[0]['source_texel_displacement'],.1,'repair remains inside sub-texel padding')

    def test_ground_crew_anatomy_is_connected_and_proportioned(self):
        from tools.build_pc_tactical_roster import authored
        base=load_catalog()['models']
        for shape in (161,162):
            model=authored(base[shape]);ts=model['triangles']
            parents={}
            def root(v):
                parents.setdefault(v,v)
                while v!=parents[v]:parents[v]=parents[parents[v]];v=parents[v]
                return v
            anatomy={'crew_jacket_sculpt','crew_trousers_sculpt','crew_sleeve_sculpt','crew_belt','crew_boot_sculpt','crew_boot_sole'}
            for t in ts:
                if t['component'] not in anatomy:continue
                vs=[tuple(round(c,5) for c in v) for v in t['vertices']]
                for v in vs[1:]:parents[root(v)]=root(vs[0])
            self.assertEqual(len({root(v) for v in parents}),1,'both hips, knees, ankles and arms remain joined to the torso')

            torso=[v for t in ts if t['component']=='crew_jacket_sculpt' for v in t['vertices']]
            self.assertLess(max(v[2] for v in torso),-52,'tunic follows the low firing pose')
            self.assertGreater(max(v[2] for v in torso)-min(v[2] for v in torso),17)
            self.assertGreater(max(v[1] for v in torso)-min(v[1] for v in torso),14,'shoulders retain clothed volume')

    def test_crew_fuller_limbs_and_fleshy_grips(self):
        from tools.build_pc_tactical_roster import authored
        for shape in (161,162):
            ts=authored(load_catalog()['models'][shape])['triangles']
            trousers=[v for t in ts if t['component']=='crew_trousers_sculpt' for v in t['vertices']]
            for near in (False,True):
                thigh=[v for v in trousers if (v[1]<9)==near and -22<v[0]<-14]
                self.assertTrue(thigh)
                self.assertGreater(max(v[2] for v in thigh)-min(v[2] for v in thigh),6,'kneeling trousers retain full volume')
            palms=[v for t in ts if t['component']=='crew_hand_palm' for v in t['vertices']]
            self.assertTrue(palms)
            for side in ('left','right'):
                for finger in ('index','middle','ring','little'):
                    vs=[v for t in ts if t['component']=='crew_hand_'+side+'_'+finger for v in t['vertices']]
                    self.assertGreater(max(v[0] for v in vs)-min(v[0] for v in vs),.85)

    def test_crew_fingertip_pads_follow_the_held_control_face(self):
        from tools.build_pc_tactical_roster import authored
        for shape in (161,162):
            ts=authored(load_catalog()['models'][shape])['triangles']
            for side in ('left','right'):
                tips={}
                for name in ('index','middle','ring','little'):
                    vs=[v for t in ts if t['component']=='crew_hand_'+side+'_'+name for v in t['vertices']]
                    tips[name]=min(v[2] for v in vs)
                self.assertLess(tips['middle'],tips['index']-.15)
                self.assertGreater(tips['little'],tips['index']+.20)
            grip=[v for t in ts if t['component']=='crew_hand_left_index' for v in t['vertices']]
            control=[v for t in ts if t['component']==('launcher_manual_knob' if shape==161 else 'launcher_aiming_handwheel') for v in t['vertices']]
            self.assertLess(min(sum((a[k]-b[k])**2 for k in range(3))**.5 for a in grip for b in control),3,
                            'posed fingers meet their actual firing control')

    def test_crew_grips_have_four_formed_fingers_and_opposed_thumbs(self):
        from collections import Counter,defaultdict
        from tools.build_pc_tactical_roster import authored
        from tools.pc_tactical_crews import formed_hands
        base=load_catalog()['models']
        for master in (False,True):
            edges=Counter();directions=defaultdict(int)
            for tri in formed_hands(base[161],master):
                points=[tuple(v) for v in tri['vertices']]
                for a,b in zip(points,points[1:]+points[:1]):
                    key=tuple(sorted((a,b)));edges[key]+=1;directions[key]+=1 if a<=b else -1
            self.assertEqual(set(edges.values()),{2},'every explicit finger and palm is closed')
            self.assertTrue(all(v==0 for v in directions.values()),'shared edges retain consistent winding')
        for shape in (161,162):
            model=authored(base[shape]);triangles=model['triangles']
            for side in ('left','right'):
                for name in ('index','middle','ring','little'):
                    points=[v for t in triangles if t['component']=='crew_hand_'+side+'_'+name for v in t['vertices']]
                    self.assertTrue(points,'each curled finger survives game retopology')
                    self.assertGreater(max(v[2] for v in points)-min(v[2] for v in points),2.5)
            thumbs=[v for t in triangles if t['component']=='crew_hand_thumb' for v in t['vertices']]
            self.assertTrue(thumbs)
            from tools.pc_tactical_ground_crews import head_point
            head=[head_point(v) for t in model['command_head']['triangles'] for v in t['vertices']]
            self.assertLess(max(v[2] for v in head)-min(v[2] for v in head),19)
            self.assertGreater(min(v[2] for v in head),-56,'attached head sits on the kneeling neck')
            self.assertLessEqual(len(triangles)+len(model['command_head']['triangles']),8192)

    def test_ground_crew_pockets_fit_the_kneeling_tunic(self):
        from tools.build_pc_tactical_roster import authored
        for shape in (161,162):
            model=authored(load_catalog()['models'][shape]);parts={t['component'] for t in model['triangles']}
            self.assertTrue({'crew_chest_pocket','crew_pocket_flap','crew_belt'}<=parts)
            shell=[t for t in model['triangles'] if t['component']=='crew_jacket_sculpt']
            for tri in model['triangles']:
                if tri['component'] not in ('crew_chest_pocket','crew_pocket_flap'):continue
                for x,y,z in tri['vertices']:
                    hits=[]
                    for t in shell:
                        a,b,c=t['vertices'];den=(b[2]-c[2])*(a[1]-c[1])+(c[1]-b[1])*(a[2]-c[2])
                        if abs(den)<1e-9:continue
                        u=((b[2]-c[2])*(y-c[1])+(c[1]-b[1])*(z-c[2]))/den
                        v=((c[2]-a[2])*(y-c[1])+(a[1]-c[1])*(z-c[2]))/den
                        if min(u,v,1-u-v)>=-1e-6:
                            hit=u*a[0]+v*b[0]+(1-u-v)*c[0]
                            if hit<-11:hits.append(hit)
                    self.assertTrue(hits)
                    self.assertTrue(.03<=x-max(hits)<=.41,'pocket relief is fitted to the actual +X-facing tunic')

    def test_ground_crew_pockets_avoid_arm_intersections(self):
        from tools.build_pc_tactical_roster import authored
        for shape in (161,162):
            triangles=authored(load_catalog()['models'][shape])['triangles']
            jacket=[t for t in triangles if t['component']=='crew_jacket_sculpt']
            for tri in triangles:
                if tri['component'] not in ('crew_chest_pocket','crew_pocket_flap'):continue
                points=tri['vertices']+[[sum(v[k] for v in tri['vertices'])/3 for k in range(3)]]
                for x,y,z in points:
                    hits=[]
                    for t in jacket:
                        a,b,c=t['vertices'];den=(b[2]-c[2])*(a[1]-c[1])+(c[1]-b[1])*(a[2]-c[2])
                        if abs(den)<1e-9:continue
                        u=((b[2]-c[2])*(y-c[1])+(c[1]-b[1])*(z-c[2]))/den
                        v=((c[2]-a[2])*(y-c[1])+(a[1]-c[1])*(z-c[2]))/den
                        if min(u,v,1-u-v)>=-1e-6:
                            hit=u*a[0]+v*b[0]+(1-u-v)*c[0]
                            if hit<-11 and not any(abs(hit-h)<1e-4 for h in hits):hits.append(hit)
                    self.assertEqual(len(hits),2,'pockets lie on the chest, without an intervening upper-arm surface')
                    self.assertTrue(.015<=x-max(hits)<=.43,'pocket face interiors also clear the curved tunic')

    def test_ground_polish_has_straight_boot_rims_and_closed_fitted_cuffs(self):
        from tools.build_pc_tactical_roster import authored
        from tools.pc_tactical_ground_crews import cuffs,material_sections,WRISTS
        polygon=[[-2,0,-84],[2,0,-82],[0,2,-82]]
        pieces=material_sections(polygon)
        sleeve=[[-6,14,-72],[-5,15,-70],[-7,16,-70]]
        self.assertEqual(material_sections(sleeve),[sleeve],'belt planes do not subdivide the remote forearm')
        self.assertAlmostEqual(sum(area2(t) for part in pieces for t in triangulate(part)),area2(polygon),places=5)
        self.assertTrue(all(not(min(v[2] for v in part)<-83<max(v[2] for v in part)) for part in pieces))
        for shape in (161,162):
            base=load_catalog()['models'][shape];model=authored(base)
            boot=[t for t in model['triangles'] if t['component']=='crew_boot_sculpt']
            sole=[t for t in model['triangles'] if t['component']=='crew_boot_sole']
            self.assertTrue(boot and sole)
            self.assertLessEqual(max(v[2] for t in boot for v in t['vertices']),-83+.000001)
            self.assertLessEqual(max(v[2] for t in sole for v in t['vertices']),-88.7+.000001)
            rear=[v for t in boot for v in t['vertices'] if v[1]>9 and v[2]>-87+.000001]
            self.assertTrue(rear);self.assertLessEqual(max(v[0] for v in rear),-19+.000001,'folded shaft has a straight cuff along the calf axis')
            heel=[v for t in boot+sole for v in t['vertices'] if v[1]>9 and -25<v[0]<-23]
            self.assertTrue(heel);self.assertGreater(min(v[2] for v in heel),-88.9,'articulated rear heel is leather and raised above the toe')
            self.assertGreater(len({tuple(v) for t in boot for v in t['vertices'] if abs(v[2]+83)<.000001}),12)
            for master in (False,True):
                edges=Counter()
                for tri in cuffs(base,master):
                    points=[tuple(v) for v in tri['vertices']]
                    for a,b in zip(points,points[1:]+points[:1]):edges[tuple(sorted((a,b)))]+=1
                self.assertEqual(set(edges.values()),{2},'both sewn cuffs are closed solids')
            cv=[v for t in model['triangles'] if t['component']=='crew_cuff' for v in t['vertices']]
            for wrist in WRISTS[shape]:
                near=[v for v in cv if sum((v[k]-wrist[k])**2 for k in range(3))<2.3**2]
                self.assertGreater(len(near),20,'cuff surrounds the actual sleeve/hand joint')

    def test_ground_refinement_has_closed_cushioned_hands_and_grounded_knee(self):
        from tools.pc_tactical_ground_crews import grips,HAND_CENTRES
        from tools.build_pc_tactical_roster import authored
        for shape in (161,162):
            base=load_catalog()['models'][shape]
            for master in (False,True):
                ts=grips(base,master);edges=Counter();directed=Counter()
                for t in ts:
                    points=[tuple(v) for v in t['vertices']]
                    for a,b in zip(points,points[1:]+points[:1]):
                        edges[tuple(sorted((a,b)))]+=1;directed[(a,b)]+=1
                self.assertEqual(set(edges.values()),{2},'rounded pads leave every palm and digit closed')
                self.assertTrue(all(count==directed[(b,a)] for (a,b),count in directed.items()),'rounded fingertip fans preserve winding')
                for centre in HAND_CENTRES[shape]:
                    palms=[]
                    for t in ts:
                        if t['component']!='crew_hand_palm':continue
                        mid=[sum(v[k] for v in t['vertices'])/3 for k in range(3)]
                        nearest=min(HAND_CENTRES[shape],key=lambda c:sum((mid[k]-c[k])**2 for k in range(3)))
                        if nearest==centre:palms.extend(t['vertices'])
                    self.assertGreater(max(v[1] for v in palms)-min(v[1] for v in palms),2.3,'metacarpal pads retain flesh across their depth')
            knee=[v for t in authored(base)['triangles'] if t['component']=='crew_trousers_sculpt'
                  for v in t['vertices'] if -15<v[0]<-8 and v[1]>10]
            self.assertLess(min(v[2] for v in knee),-89.5,'weight-bearing knee reaches the same ground as the toe and front sole')

    def test_ground_polish_seats_all_grips_and_shapes_launcher_edges(self):
        from tools.build_pc_tactical_roster import authored
        for shape in (161,162):
            ts=authored(load_catalog()['models'][shape])['triangles']
            for side in ('left','right'):
                hand=[v for t in ts if t['component']=='crew_hand_'+side+'_index' for v in t['vertices']]
                control=('launcher_manual_knob' if side=='left' else 'launcher_control_knob') if shape==161 else 'launcher_aiming_handwheel'
                controls=[v for t in ts if t['component']==control for v in t['vertices']]
                self.assertLess(min(sum((a[k]-b[k])**2 for k in range(3))**.5 for a in hand for b in controls),.7,
                                'fingers meet the operating control within less than a finger radius')
            case=[v for t in ts if t['component']==('launcher_case' if shape==161 else 'launcher_spigot_guidance_housing') for v in t['vertices']]
            lo,hi=bounds(case).values()
            self.assertGreater(len({round(v[2],5) for v in case}),2,'actual case has bevel bands, not just a sharp box')
            self.assertFalse(any(all(abs(v[k]-lo[k])<1e-5 or abs(v[k]-hi[k])<1e-5 for k in range(3)) for v in case),'sharp triple-corner vertices are cut back')
            label='launcher_sagger_cruciform_fin' if shape==161 else 'launcher_canister_band'
            profile=[v for t in ts if t['component']==label for v in t['vertices']]
            self.assertEqual(len({round(v[0],4) for v in profile}),8,'fins or container bands have a shaped multi-station profile')

    def test_crew_neck_reaches_the_actual_jacket_neck_depth(self):
        from tools.build_pc_tactical_roster import authored
        base=load_catalog()['models']
        for shape in (161,162):
            model=authored(base[shape])
            neck=[v for t in model['command_head']['triangles'] if t['component'].startswith('crew_head_neck') for v in t['vertices']]
            self.assertTrue(neck,'a sloping neck must connect the forward head to the jacket')
            self.assertAlmostEqual(min(v[2] for v in neck),-14.9,places=5,msg='neck reaches the rounded raster foot without exceeding the head ellipse')
            end={tuple(v) for v in neck if abs(v[2]+14)<1e-6}
            self.assertTrue(end)
            self.assertAlmostEqual((min(v[1] for v in end)+max(v[1] for v in end))/2,10.8,places=5,
                                   msg='the physical neck centre stays fixed with denser front-face sampling')
            self.assertGreater(max(v[1] for v in end),13)
            self.assertLess(min(v[1] for v in end),8.6)

    def test_crew_hands_and_helmet_have_fitted_anatomical_profiles(self):
        from tools.build_pc_tactical_roster import authored
        from tools.pc_tactical_crew_heads import FINISHES
        base=load_catalog()['models']
        for shape in (161,162):
            model=authored(base[shape]);parts={t['component'] for t in model['triangles']}
            self.assertTrue({'crew_hand_thumb','crew_hand_knuckle','launcher_case_seam'}<=parts)
            rim=[v for t in model['command_head']['triangles'] if t['component']=='crew_head_helmet_rim' for v in t['vertices']]
            self.assertLessEqual(max(abs(v[0]) for v in rim),15.3,'helmet should fit the skull rather than flare like a brimmed hat')
            self.assertEqual(FINISHES['crew_head_helmet'][0],'equipment','painted helmet must not use woven cloth finish')

    def test_ground_crews_keep_source_bounds_and_distinct_real_launchers(self):
        from tools.build_pc_tactical_roster import authored
        from tools.pc_tactical_ground_crews import head_point,POSE
        for shape in (161,162):
            original=load_catalog()['models'][shape];model=authored(original)
            self.assertEqual(model['presentation_pose'],POSE)
            self.assertTrue(validate_model(model),'the approved whole-object bound replaces obsolete standing face clips')
            self.assertFalse(any('head' in t['component'] for t in model['triangles']))
            parts={t['component'] for t in model['triangles']}
            self.assertTrue({'launcher_carry_handle','launcher_case_catch','launcher_case','launcher_ocular_eyecup'}<=parts)
            expected=({'launcher_sagger_periscope_mast','launcher_sagger_missile','launcher_sagger_cruciform_fin','launcher_sagger_case_lid'} if shape==161 else
                      {'launcher_spigot_canister','launcher_spigot_guidance_housing','launcher_tripod_leg','launcher_tripod_foot'})
            self.assertTrue(expected<=parts)
            boots=[v for t in model['triangles'] if t['component'].startswith('crew_boot') for v in t['vertices']]
            if shape==161:
                controller=[v for t in model['triangles'] if t['component']=='launcher_case' for v in t['vertices']]
                missile_case=[v for t in model['triangles'] if t['component']=='launcher_sagger_case_base' for v in t['vertices']]
                self.assertEqual(min(v[2] for v in controller),-90,'controller is genuinely ground-supported')
                self.assertGreater(min(v[0] for v in controller),max(v[0] for v in boots),'controller stays ahead of the boot toes')
                self.assertLess(max(v[1] for v in controller),min(v[1] for v in missile_case),'controller and missile case are separate physical supports')
            if shape==162:
                leg=[v for t in model['triangles'] if t['component']=='launcher_tripod_leg' for v in t['vertices'] if v[2]<-83]
                self.assertTrue(all(v[0]>4 or v[1]>8 for v in leg),'tripod legs clear the forward boot')
                housing=[v for t in model['triangles'] if t['component']=='launcher_spigot_guidance_housing' for v in t['vertices']]
                ocular=[v for t in model['triangles'] if t['component']=='launcher_ocular_rim' for v in t['vertices']]
                self.assertLess(min(v[2] for v in ocular),max(v[2] for v in housing),'sight tube is attached to the housing')
                feet=[v for t in model['triangles'] if t['component']=='launcher_tripod_foot' for v in t['vertices']]
                self.assertEqual(len({tuple(round(sum(v[k] for v in t['vertices'])/3,3) for k in range(3)) for t in model['triangles'] if t['component']=='launcher_tripod_foot'}),36)
                self.assertEqual(min(v[2] for v in feet),-90)
            eyes=[head_point(v) for t in model['command_head']['triangles'] if t['component']=='crew_head_eye' for v in t['vertices']]
            ocular=[v for t in model['triangles'] if t['component']=='launcher_ocular_glass' for v in t['vertices']]
            self.assertLess(min(sum((a[k]-b[k])**2 for k in range(3))**.5 for a in eyes for b in ocular),.8,'ocular meets a real eye, not the nose')

    def test_crew_heads_are_separate_command_bound_volumes(self):
        from tools.build_pc_tactical_roster import authored,public
        base=load_catalog()
        for shape in (161,162):
            source=base['models'][shape];model=authored(source);head=public(model)['command_head']
            command=source['visual_commands'][0]
            self.assertEqual(head['command_offset'],command['command_offset'])
            self.assertEqual(head['command'],command['command_bytes'])
            self.assertLessEqual(len(head['triangles'])+len(model['triangles']),8192)
            self.assertGreater(len(head['triangles']),500)
            parts={t['component'] for t in head['triangles']}
            self.assertTrue({'crew_head_helmet_dome','crew_head_skin_surface','crew_head_nose_bridge',
                             'crew_head_eye','crew_head_ear','crew_head_chinstrap'}<=parts)
            points=[v for t in head['triangles'] for v in t['vertices']]
            self.assertGreater(max(v[1] for v in points)-min(v[1] for v in points),1.0)
            self.assertTrue(all(v[0]*v[0]+v[2]*v[2]<=1.000001 and abs(v[1])<=1 for v in points))
            self.assertFalse(any('head' in t['component'] for t in model['triangles']))

    def test_crew_chinstraps_face_outward_on_both_cheeks(self):
        from tools.pc_tactical_crew_heads import geometry
        for shape in (161,162):
            model,_=geometry(load_catalog()['models'][shape])
            sides=set()
            for t in model['triangles']:
                if t['component']!='crew_head_chinstrap':continue
                a,b,c=t['vertices'];normal=cross(sub(b,a),sub(c,a))
                sides.add(-1 if sum(v[0] for v in t['vertices'])<0 else 1)
                self.assertLess(normal[1],0,'both cheek straps face away from the negative-Y facial surface')
            self.assertEqual(sides,{-1,1})

    def test_crew_head_bakes_cover_subpixel_charts(self):
        from PIL import Image
        for shape in (161,162):
            folder=ROOT/'local-art/pc-tactical-roster-v1'/str(shape)
            if not (folder/'model.json').exists():self.skipTest('Blender bake unavailable')
            triangles=json.loads((folder/'model.json').read_text())['model']['command_head']['triangles']
            for channel in ('albedo','roughness'):
                image=Image.open(folder/'head'/(channel+'.png')).convert('RGB')
                misses=[]
                for i,t in enumerate(triangles):
                    for weights in ((1/3,1/3,1/3),(.6,.2,.2),(.2,.6,.2),(.2,.2,.6)):
                        u,v=[sum(w*p[k] for w,p in zip(weights,t['uvs'])) for k in (0,1)]
                        pixel=(min(image.width-1,int(u*image.width)),min(image.height-1,int(v*image.height)))
                        if max(image.getpixel(pixel))<6:misses.append(i);break
                self.assertFalse(misses,f'{shape}/{channel}: unseeded head charts {misses[:12]}')

    def test_crew_collar_is_closed_cloth_around_the_neck(self):
        from collections import Counter
        from tools.pc_tactical_crew_heads import geometry,FINISHES
        for master in (False,True):
            model,_=geometry(load_catalog()['models'][161],master)
            collar=[t for t in model['triangles'] if t['component'].startswith('crew_head_collar')]
            self.assertTrue(collar)
            edges=Counter(tuple(sorted((tuple(a),tuple(b)))) for t in collar for a,b in zip(t['vertices'],t['vertices'][1:]+t['vertices'][:1]))
            self.assertEqual(set(edges.values()),{2},'folded collar must have no open edge')
            self.assertEqual({t['material'] for t in collar},{'crew_head_collar'})
            self.assertEqual(FINISHES['crew_head_collar'][0],'cloth')
            self.assertAlmostEqual(max(v[2] for t in collar for v in t['vertices']),-12.5)

    def test_crew_jaw_angles_rise_above_the_chin(self):
        from tools.pc_tactical_crew_heads import geometry
        for master in (False,True):
            model,_=geometry(load_catalog()['models'][161],master)
            skin=[v for t in model['triangles'] if t['component']=='crew_head_skin_surface' for v in t['vertices']]
            chin=min(v[2] for v in skin if abs(v[0])<.3 and v[1]<4)
            angles=[v for v in skin if abs(v[0])>4 and v[1]>6 and v[2]<-3]
            self.assertTrue(angles)
            self.assertGreater(min(v[2] for v in angles),chin+1.3,
                               'jaw rises toward the ears instead of ending in a horizontal neck shelf')

    def test_crew_face_and_nose_are_one_closed_anatomical_surface(self):
        from collections import Counter,defaultdict
        from tools.pc_tactical_crew_heads import geometry
        source=load_catalog()['models'][161]
        for master in (False,True):
            model,_=geometry(source,master)
            triangles=[t for t in model['triangles'] if t['component'].startswith(('crew_head_skin_surface','crew_head_nose_bridge','crew_head_neck'))]
            edges=Counter();adjacency=defaultdict(set)
            for t in triangles:
                points=[tuple(round(c,6) for c in v) for v in t['vertices']]
                for a,b in zip(points,points[1:]+points[:1]):
                    edges[tuple(sorted((a,b)))]+=1
                    adjacency[a].add(b);adjacency[b].add(a)
            self.assertTrue(edges)
            self.assertEqual(set(edges.values()),{2},'skin, neck and nasal bridge share edges without open seams')
            pending=[next(iter(adjacency))];seen=set()
            while pending:
                point=pending.pop()
                if point in seen:continue
                seen.add(point);pending.extend(adjacency[point]-seen)
            self.assertEqual(seen,set(adjacency),'nose and neck belong to the facial surface, not disconnected volumes')

    def test_farm_cow_is_anatomical_source_owned_decoration(self):
        from tools.build_pc_tactical_roster import authored
        base=load_catalog();model=authored(base['models'][157])
        animal=[t for t in model['triangles'] if 'cow_' in t['component']]
        self.assertGreater(len(animal),500)
        self.assertTrue(all(t['source_primitive']==28751 for t in animal))
        parts={t['component'] for t in animal}
        self.assertTrue(any('barrel' in x for x in parts))
        self.assertTrue(any('muzzle' in x for x in parts))
        self.assertTrue(any('hoof' in x for x in parts))
        self.assertTrue(any('tail' in x for x in parts))
        self.assertTrue({'architecture_cow_head_profile','architecture_cow_broad_muzzle',
                         'architecture_cow_jointed_leg'}<=parts)
        self.assertFalse(any('cow_' in t['component'] for t in authored(base['models'][158])['triangles']))

    def test_destroyed_farmyard_contains_grounded_source_owned_debris(self):
        from tools.build_pc_tactical_roster import authored
        model=authored(load_catalog()['models'][158])
        debris=[t for t in model['triangles'] if t['component'] in (
            'architecture_yard_broken_masonry','architecture_yard_fallen_roof_tile',
            'architecture_yard_fallen_rafter')]
        self.assertGreater(len(debris),300)
        self.assertEqual({t['source_primitive'] for t in debris},{29245})
        extent=bounds([v for t in debris for v in t['vertices']])
        self.assertGreater(extent['max'][0]-extent['min'][0],500)
        self.assertGreater(extent['max'][1]-extent['min'][1],300)
        self.assertGreaterEqual(extent['min'][2],0)
        self.assertLess(extent['max'][2],18)
        self.assertLessEqual(len(model['triangles']),8192)
        pieces=[t for t in model['triangles'] if t['component']=='architecture_yard_broken_masonry']
        self.assertGreater(len({round(v[2],3) for t in pieces for v in t['vertices']}),30,
                           'rubble has varied profiles rather than repeated identical piles')
        parts={t['component'] for t in model['triangles']}
        self.assertTrue({'architecture_fractured_roof_tile','architecture_roof_fracture_core'}<=parts)
        floor=[t for t in model['triangles'] if t['source_primitive']==29245 and t['component']=='architecture_floor']
        self.assertEqual({t['material'] for t in floor},{'architecture_yard_dust'})

    def test_polished_ruins_keep_debris_on_original_floor_and_matching_roof_breaks(self):
        from tools.build_pc_tactical_roster import authored
        base=load_catalog()['models']
        for shape in (148,150,152):
            m=authored(base[shape]);floor=base[shape]['source_primitives'][0]['id']
            rubble=[t for t in m['triangles'] if t['component']=='architecture_grounded_ruin_masonry']
            self.assertGreater(len(rubble),10);self.assertEqual({t['source_primitive'] for t in rubble},{floor})
            self.assertGreater(sum(t['component']=='architecture_fallen_render_slab' for t in m['triangles']),80)
            for part in ('architecture_fallen_floor_rafter','architecture_scattered_floor_roof_tile'):
                pieces=[t for t in m['triangles'] if t['component']==part]
                self.assertTrue(pieces);self.assertEqual({t['source_primitive'] for t in pieces},{floor})
            for t in m['triangles']:
                if t['component']=='architecture_collapsed_floor':
                    a,b,c=t['vertices'];self.assertGreater(cross(sub(b,a),sub(c,a))[2],0)
        for shape in (146,154,158):
            def fractures(master):
                return [t for t in authored(base[shape],master)['triangles'] if 'fractured_roof_tile' in t['component'] or 'roof_fracture_core' in t['component']]
            self.assertTrue(fractures(False));self.assertEqual(fractures(False),fractures(True))

    def test_crew_bakes_have_no_black_interior_projection_misses(self):
        from math import hypot
        from PIL import Image
        folder=ROOT/'local-art/pc-tactical-roster-v1'
        if not (folder/'161/model.json').exists():self.skipTest('crew masters unavailable')
        for shape in (161,162):
            triangles=json.loads((folder/str(shape)/'model.json').read_text())['model']['triangles']
            for channel in ('albedo','normal'):
                image=Image.open(folder/str(shape)/(channel+'.png')).convert('RGB')
                checked=0;misses=[]
                for index,triangle in enumerate(triangles):
                    points=[(u*image.width,v*image.height) for u,v in triangle['uvs']]
                    x,y=[sum(p[k] for p in points)/3 for k in (0,1)]
                    distances=[abs((b[0]-a[0])*(y-a[1])-(b[1]-a[1])*(x-a[0]))/max(1e-12,hypot(b[0]-a[0],b[1]-a[1]))
                               for a,b in zip(points,points[1:]+points[:1])]
                    # Subpixel slivers have no unambiguous interior texel.
                    if min(distances)<1:continue
                    checked+=1
                    if max(image.getpixel((min(image.width-1,int(x)),min(image.height-1,int(y)))))<6:misses.append(index)
                self.assertGreater(checked,len(triangles)*.85)
                self.assertFalse(misses,f'{shape}/{channel}: black interior bake misses {misses[:8]}')

    def test_baked_building_stars_have_no_systematic_black_occlusion(self):
        from statistics import median
        from PIL import Image
        folder=ROOT/'local-art/pc-tactical-roster-v1'
        if not all((folder/str(shape)/'ao.png').exists() for shape in (153,155,156)):
            self.skipTest('building Blender bakes unavailable')
        for shape in (153,155,156):
            model=json.loads((folder/str(shape)/'model.json').read_text())['model']
            image=Image.open(folder/str(shape)/'ao.png').convert('L');samples={}
            for triangle in model['triangles']:
                if triangle['component'] not in ('soviet_star','us_army_star') or triangle['material'] not in ('insignia_white','insignia_red'):continue
                u,v=[sum(p[k] for p in triangle['uvs'])/3 for k in (0,1)]
                samples.setdefault(triangle['source_primitive'],[]).append(image.getpixel((min(image.width-1,int(u*image.width)),min(image.height-1,int(v*image.height)))))
            self.assertEqual(len(samples),4)
            for owner,values in samples.items():
                self.assertGreater(median(values),64,(shape,owner,'paint interiors retain real occlusion without becoming black'))

    def test_bridge_deck_winding_matches_original_top_and_underside_normals(self):
        from tools.pc_tactical_bridges import geometry
        base=load_catalog()['models']
        for shape in (0,1,45,46,108,114):
            for master in (False,True):
                model=geometry(base[shape],master)
                self.assertTrue(model['triangles'])
                for t in model['triangles']:
                    a,b,c=t['vertices']
                    sign=-1 if t['source_primitive'] in (11187,13065,13075) else 1
                    self.assertGreater(cross(sub(b,a),sub(c,a))[2]*sign,0,(shape,master,t['source_primitive']))

    def test_baked_bridge_decks_have_no_false_coplanar_occlusion(self):
        from statistics import median
        from PIL import Image
        folder=ROOT/'local-art/pc-tactical-roster-v1'
        if not all((folder/str(shape)/'ao.png').exists() for shape in (0,1,45,46,108,114)):
            self.skipTest('bridge Blender bakes unavailable')
        for shape in (0,1,45,46,108,114):
            model=json.loads((folder/str(shape)/'model.json').read_text())['model']
            ao=Image.open(folder/str(shape)/'ao.png').convert('L')
            normal=Image.open(folder/str(shape)/'normal.png').convert('RGB')
            samples={}
            for t in model['triangles']:
                if t['component']!='bridge_cast_deck_panel':continue
                u,v=[sum(p[k] for p in t['uvs'])/3 for k in (0,1)]
                pixel=(min(ao.width-1,int(u*ao.width)),min(ao.height-1,int(v*ao.height)))
                samples.setdefault(t['source_primitive'],[]).append((ao.getpixel(pixel),normal.getpixel(pixel)[2]))
            self.assertTrue(samples)
            for owner,values in samples.items():
                self.assertGreater(median(v[0] for v in values),200,(shape,owner,'open deck AO'))
                self.assertGreater(median(v[1] for v in values),240,(shape,owner,'outward tangent normals'))

    def test_bridge_refinement_retains_surface_area_and_original_lines(self):
        from tools.pc_tactical_bridges import geometry,SHAPES
        from tools.build_pc_modern_assets import area2
        base=load_catalog()
        for shape in SHAPES:
            original=base['models'][shape];model=geometry(original)
            self.assertEqual(original['source_lines'],model['source_lines'])
            old=sum(area2(t['vertices']) for t in original['triangles'])
            new=sum(area2(t['vertices']) for t in model['triangles'])
            self.assertAlmostEqual(old,new,delta=old*1e-6)

    def test_hangar_flag_is_white_matte_cloth_on_its_original_plane(self):
        from tools.pc_tactical_bridges import geometry,FINISHES
        base=load_catalog()['models'][47]
        source=next(p for p in base['source_primitives'] if p['id']==4915)
        self.assertEqual(source['prefix_bytes'],[27,1,1])
        original=source['vertices']
        expected=sum(area2([original[0],original[i],original[i+1]]) for i in range(1,len(original)-1))
        for master in (False,True):
            flag=[t for t in geometry(base,master)['triangles'] if t['source_primitive']==4915]
            self.assertEqual(len(flag),10,'one cloth field and four hems, with no cladding grid')
            self.assertEqual({t['material'] for t in flag},{'bridge_flag_cloth','bridge_flag_hem'})
            self.assertEqual({v[1] for t in flag for v in t['vertices']},{1280})
            self.assertEqual(bounds([v for t in flag for v in t['vertices']]),bounds(original))
            self.assertAlmostEqual(sum(area2(t['vertices']) for t in flag),expected,delta=1e-6)
            self.assertTrue(all(t['source_groups']==[4901] for t in flag))
        for name in ('bridge_flag_cloth','bridge_flag_hem'):
            _,rgb,profile=FINISHES[name]
            self.assertGreaterEqual(min(rgb),225)
            self.assertLessEqual(max(rgb)-min(rgb),10)
            self.assertEqual(profile[0],'fabric')
            self.assertGreaterEqual(profile[1],.88)
            self.assertEqual(profile[2],0.)

    def test_bridge_bakes_keep_shared_source_plane_uvs_continuous(self):
        from tools.pc_tactical_bridges import SHAPES
        folder=ROOT/'local-art/pc-tactical-roster-v1'
        if not all((folder/str(shape)/'model.json').exists() for shape in SHAPES):
            self.skipTest('bridge Blender bakes unavailable')
        for shape in SHAPES:
            model=json.loads((folder/str(shape)/'model.json').read_text())['model']
            points={}
            for triangle in model['triangles']:
                for point,uv in zip(triangle['vertices'],triangle['uvs']):
                    key=(triangle['source_primitive'],tuple(point))
                    if key in points:
                        # Allow only the existing tiny float32 sliver repair,
                        # below one quarter of a pixel in the 512px bank tile.
                        self.assertLessEqual(max(abs(a-b) for a,b in zip(points[key],uv)),.25/512,(shape,key))
                    else:points[key]=uv

    def test_mechanical_bake_details_add_no_runtime_geometry_or_crew_thickness(self):
        from tools.build_pc_tactical_roster import authored
        from tools.pc_tactical_scene import mechanical_details
        base=load_catalog()
        model=authored(base['models'][115]);before=copy.deepcopy(model['triangles'])
        high=authored(base['models'][115],True)
        self.assertEqual(model['triangles'],before)
        self.assertTrue(any(t['component'].endswith('_weld_bead') for t in high['triangles']))
        for shape in (161,162):
            model=authored(base['models'][shape]);before=copy.deepcopy(model['triangles'])
            mechanical_details(model)
            self.assertEqual(model['triangles'],before)

    def test_material_profiles_keep_dielectrics_separate_from_exposed_metal(self):
        from tools.pc_tactical_finish import _profile,_linear
        for name in ('tyre','canvas','plaster','skin','cloth','us_flag_white'):
            self.assertEqual(_profile(name)[2],0.)
        self.assertGreater(_profile('steel')[2],.8)
        self.assertEqual(_profile('us_flag_white')[0],'signal')
        self.assertEqual(_linear([255,0,0]),(1.,0.,0.,1.))


class TacticalCamouflageTests(unittest.TestCase):
    def test_camouflage_covers_vehicle_families_and_matching_wrecks(self):
        from tools.pc_tactical_finish import CAMOUFLAGE_SHAPES,camouflage_family
        self.assertEqual(set(CAMOUFLAGE_SHAPES),set(range(115,145))|{159,160,163,164})
        for shape in range(115,145,2):
            self.assertEqual(camouflage_family(shape),camouflage_family(shape+1))
        self.assertEqual(camouflage_family(125),'nato')
        self.assertEqual(camouflage_family(131),'nato')
        self.assertEqual(camouflage_family(123),'eastern')
        self.assertEqual(camouflage_family(163),camouflage_family(164))

    def test_camouflage_excludes_rubber_glass_bare_metal_and_nonvehicles(self):
        from tools.pc_tactical_finish import camouflage_role
        for shape in (115,125,131,141,159,163):
            for name in ('tyre','track','track_edge','steel','optic','glass','lamp','red','skin','canvas','hind_blue'):
                self.assertEqual(camouflage_role(shape,name),'',(shape,name))
        for shape in (0,108,147,151,153,156,161,162):
            self.assertEqual(camouflage_role(shape,'olive'),'')
        self.assertEqual(camouflage_role(141,'signal_red'),'paint')

    def test_wreck_paint_is_limited_to_surviving_plates(self):
        from tools.pc_tactical_finish import camouflage_role
        self.assertEqual(camouflage_role(126,'burnt','buckled_front_deck'),'wreck')
        self.assertEqual(camouflage_role(142,'burnt','brdm_crushed_launch_canister'),'wreck')
        for role,part in (('burnt','damaged_roadwheel'),('scorch','collapsed_tyre'),('rust','engine_manifold'),('exposed','torn_sidewall_torn_edge')):
            self.assertEqual(camouflage_role(126,role,part),'')


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

    def test_export_refuses_original_trees_in_any_case(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);(root/'GAME').mkdir();(root/'local-art').mkdir()
            with mock.patch('tools.build_pc_modern_assets.ROOT',root):
                for name in ('GAME/x','game/x','Game/new/x','GENESIS/x','genesis','reference/x','REFERENCE'):
                    with self.subTest(name=name):self.assertTrue(inside_source(root/name))
                self.assertFalse(inside_source(root/'local-art/pc-modern'));self.assertFalse(inside_source(root/'gamey'))
                # The guard rejects before any directory or file is created.
                with mock.patch.object(Path,'mkdir',side_effect=AssertionError('wrote')),self.assertRaises(ValueError):
                    export(root/'game'/'pc-modern',{'models':[]})
        if (ROOT/'GAME').exists():self.assertTrue(inside_source(ROOT/'game'/'pc-modern'))

    def test_split_catalogue_round_trips_without_source_structure(self):
        primitive={'id':4,'prefix_bytes':[255,0,2],'vertices':[[0,0,0],[0,0,0],[1,0,0],[0,0,0]]}
        model={'shape_index':0,'triangles':[],'selectors':[],'roots':[],'groups':[],'source_primitives':[primitive],
               'opaque_commands':[],'visual_commands':[],'source_lines':[{'source_primitive':4,'source_groups':[2],
               'vertices':[[0,0,0],[1,0,0]],'prefix_bytes':[255,0,2],'color':[1,2,3]}]}
        result={'schema':1,'sources':{'SHAPE.TBL':'x'},'classes':[{'name':'A','raw_hex':'00'}],'models':[model]}
        public,registry=split_catalog(copy.deepcopy(result))
        self.assertIsNone(decoded_payload(json.dumps(public).encode()))
        self.assertEqual(public['models'][0]['source_lines'],[{'source_primitive':4,'source_groups':[2],'color':[1,2,3]}])
        self.assertEqual(public['classes'],[{'name':'A'}])
        expected=copy.deepcopy(result);del expected['classes'][0]['raw_hex']
        self.assertEqual(merge_catalog(public,registry),expected)
        for field in REGISTRY_FIELDS:
            bad=copy.deepcopy(public);bad['models'][0][field]=[]
            with self.subTest(field=field),self.assertRaises(ValueError):merge_catalog(bad,registry)
        with self.assertRaises(ValueError):merge_catalog(public,dict(registry,source_sha256='y'))

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

    def test_published_catalogue_omits_the_player_derived_source_registry(self):
        with tempfile.TemporaryDirectory() as tmp:
            out=Path(tmp)/'a';expected=copy.deepcopy(self.result);export(out,expected)
            raw=(out/'catalog.json').read_bytes();public=json.loads(raw)
            self.assertIsNone(decoded_payload(raw))
            self.assertFalse(any('raw_hex' in row for row in public['classes']))
            for model in public['models']:
                self.assertFalse(set(REGISTRY_FIELDS)&set(model))
                for line in model['source_lines']:self.assertFalse({'vertices','prefix_bytes'}&set(line))
            # The registry is a pure decode of the player's SHAPE.TBL, pinned by the catalogue.
            registry=(out/REGISTRY).read_bytes()
            self.assertEqual(registry,registry_bytes(source_registry((ROOT/'GAME/SHAPE.TBL').read_bytes())))
            self.assertEqual(public['source_registry']['sha256'],hashlib.sha256(registry).hexdigest())
            merged=load_catalog(out);del merged['source_registry']
            for row in expected['classes']:del row['raw_hex']
            self.assertEqual(merged,json.loads(json.dumps(expected)))
            (out/REGISTRY).write_bytes(registry.replace(b'"schema":1',b'"schema":2',1))
            with self.assertRaises(ValueError):load_catalog(out)
        with self.assertRaises(ValueError):source_registry(b'\x02'+bytes(8))

if __name__=='__main__':unittest.main()
