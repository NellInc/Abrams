"""Blender authoring pass using recovered Genesis polygons and palette only.

Editable source and restrained bevel studies. No invented joints, silhouette
replacement, gameplay binding, modern tank proportions or final-art claim.
"""
import argparse
import hashlib
import json
from pathlib import Path
import sys

import bpy
import bmesh
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools.extract_genesis_models import ROM_HASH, canonical_cycle


def build(source: Path, output: Path):
    catalog_path = source / 'catalog.json'
    catalog = json.loads(catalog_path.read_text())
    if catalog['rom_sha256'] != ROM_HASH or catalog['palette_bank'] != 3:
        raise ValueError('Requires fingerprinted Genesis source and ordinary palette')
    for name, expected in catalog['files'].items():
        if hashlib.sha256((source / name).read_bytes()).hexdigest() != expected:
            raise ValueError('Changed source reference: ' + name)
    output.mkdir(parents=True, exist_ok=False)
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = 32
    scene.render.resolution_x = 1920
    scene.render.resolution_y = 1080
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = 'PNG'
    scene.view_settings.view_transform = 'Standard'
    scene.world.color = (.15, .15, .15)

    def linear(value):
        value /= 255
        return value / 12.92 if value <= .04045 else ((value + .055) / 1.055) ** 2.4

    materials = {}
    for restored in (False, True):
        for source_material in catalog['materials']:
            index = source_material['material']
            mat = bpy.data.materials.new(('study' if restored else 'source') + f'_{index:02x}')
            mat.use_nodes = True
            shader = mat.node_tree.nodes['Principled BSDF']
            color = tuple(linear(c) for c in source_material['mean_rgb']) + (1,)
            shader.inputs['Base Color'].default_value = color if restored else (0, 0, 0, 1)
            shader.inputs['Roughness'].default_value = .78
            shader.inputs['Metallic'].default_value = .08 if restored else 0
            if not restored:
                shader.inputs['Emission Color'].default_value = color
                shader.inputs['Emission Strength'].default_value = 1
            mat['source_material'] = index
            mat['source_pattern'] = source_material['pattern']
            mat['source_mean_rgb'] = source_material['mean_rgb']
            materials[restored, index] = mat

    def geometry(model, restored):
        pose = model['poses'][0]
        if pose['unmeshed_commands']:
            raise ValueError('Selected vehicle contains unmeshed source commands')
        vectors = {int(i): v for i, v in pose['vertices'].items()}
        # Source VM sort blocks remain separate mesh components. These names
        # deliberately do not infer hull/turret joints or animation semantics.
        starts = sorted({g['target'] for c in model['commands'] for g in c.get('groups', [])})
        def group(at):
            return max([s for s in starts if s <= at], default=model['offset'])
        collection = bpy.data.collections.new(f"genesis_{model['index']}_" + ('study' if restored else 'source'))
        scene.collection.children.link(collection)
        reports = []
        for start in sorted({group(p['offset']) for p in pose['polygons']}):
            selected = [p for p in pose['polygons'] if group(p['offset']) == start]
            verts, faces, colors, seen, retained, opposite_duplicates = [], [], [], set(), [], []
            for p in selected:
                points = [vectors[i] for i in p['indices']]
                if points[-1] == points[0]:
                    points = points[:-1]
                key = (canonical_cycle(points), p['material'])
                if key in seen:
                    opposite_duplicates.append(p['offset'])
                    continue
                seen.add(key)
                retained.append(p['offset'])
                faces.append(tuple(range(len(verts), len(verts) + len(points))))
                verts += [(v[0] / 64, v[2] / 64, v[1] / 64) for v in points]
                colors.append(p['material'])
            mesh = bpy.data.meshes.new(f'vm_block_{start:06x}')
            mesh.from_pydata(verts, [], faces)
            palette = sorted(set(colors))
            for color in palette:
                mesh.materials.append(materials[restored, color])
            for face, color in zip(mesh.polygons, colors):
                face.material_index = palette.index(color)
            bm = bmesh.new()
            bm.from_mesh(mesh)
            bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=1e-7)
            bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
            original_faces = len(bm.faces)
            if restored:
                bmesh.ops.bevel(bm, geom=list(bm.edges), offset=.45 / 64, segments=4,
                                affect='EDGES', clamp_overlap=True)
                bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
            bm.to_mesh(mesh)
            bm.free()
            mesh.update()
            node = bpy.data.objects.new(mesh.name, mesh)
            collection.objects.link(node)
            node['genesis_model'] = model['index']
            node['source_vm_block'] = start
            node['source_commands'] = retained
            node['authored_bevel_raw_units'] = .45 if restored else 0
            reports.append({'block': start, 'source_commands': retained,
                            'coincident_alternatives': opposite_duplicates,
                            'source_faces': original_faces, 'authored_faces': len(mesh.polygons)})
        for line in pose['lines']:
            curve = bpy.data.curves.new(f"source_line_{line['offset']:06x}", 'CURVE')
            curve.dimensions = '3D'
            curve.bevel_depth = (.3 if restored else .2) / 64
            curve.bevel_resolution = 3 if restored else 0
            spline = curve.splines.new('POLY')
            spline.points.add(1)
            for point, index in zip(spline.points, line['indices']):
                v = vectors[index]
                point.co = (v[0] / 64, v[2] / 64, v[1] / 64, 1)
            curve.materials.append(materials[restored, line['material']])
            node = bpy.data.objects.new(curve.name, curve)
            collection.objects.link(node)
            node['genesis_model'] = model['index']
            node['source_command'] = line['offset']
        return collection, reports

    bpy.ops.object.camera_add(location=(8, 12, 8))
    camera = bpy.context.object
    camera.rotation_euler = (Vector((0, .3, .2)) - camera.location).to_track_quat('-Z', 'Y').to_euler()
    camera.data.type = 'ORTHO'
    camera.data.ortho_scale = 12
    scene.camera = camera
    for location, power, size in [((1, 4, 8), 1300, 7), ((-6, -4, 4), 900, 5)]:
        bpy.ops.object.light_add(type='AREA', location=location)
        light = bpy.context.object
        light.data.energy, light.data.size = power, size
        light.rotation_euler = (-light.location).to_track_quat('-Z', 'Y').to_euler()
    bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, -.6))
    floor = bpy.context.object
    floor_mat = bpy.data.materials.new('preview_floor')
    floor_mat.diffuse_color = (.08, .09, .10, 1)
    floor.data.materials.append(floor_mat)

    receipts = []
    for index in (115, 125, 129):
        model_path = source / f'shape-{index:03d}.json'
        model = json.loads(model_path.read_text())
        original, _ = geometry(model, False)
        restored, components = geometry(model, True)
        bpy.ops.object.select_all(action='DESELECT')
        for node in restored.objects:
            node.select_set(True)
        bpy.context.view_layer.objects.active = restored.objects[0]
        glb = output / f'genesis-{index}-study.glb'
        bpy.ops.export_scene.gltf(filepath=str(glb), use_selection=True, export_extras=True, export_yup=True)
        used = {i for p in model['poses'][0]['polygons'] + model['poses'][0]['lines'] for i in p['indices']}
        vectors = {int(i): v for i, v in model['poses'][0]['vertices'].items()}
        minimum = [min(vectors[i][axis] for i in used) for axis in range(3)]
        maximum = [max(vectors[i][axis] for i in used) for axis in range(3)]
        floor.location.z = minimum[1] / 64 - .025
        right = camera.rotation_euler.to_quaternion() @ Vector((2.8, 0, 0))
        for node in original.objects:
            node.location -= right
        for node in restored.objects:
            node.location += right
        scene.render.filepath = str(output / f'genesis-{index}-comparison.png')
        bpy.ops.render.render(write_still=True)
        receipts.append({'index': index, 'source_model_sha256': hashlib.sha256(model_path.read_bytes()).hexdigest(),
                         'components': components, 'glb': glb.name, 'glb_sha256': hashlib.sha256(glb.read_bytes()).hexdigest(),
                         'minimum_genesis': minimum, 'maximum_genesis': maximum,
                         'preview': f'genesis-{index}-comparison.png'})
        for collection in (original, restored):
            collection.hide_render = True
            collection.hide_viewport = True
    bpy.ops.wm.save_as_mainfile(filepath=str(output / 'genesis-source-fitted-studies.blend'))
    manifest = {'schema': 1, 'rom_sha256': ROM_HASH, 'source': str(source),
                'source_catalog_sha256': hashlib.sha256(catalog_path.read_bytes()).hexdigest(),
                'blender': bpy.app.version_string, 'models': receipts,
                'transformation': {'raw_units_per_blender_unit': 64, 'bevel_raw_units': .45,
                                   'bevel_segments': 4, 'line_radius_raw_units': .3,
                                   'source_axes': 'Genesis XYZ to Blender XZY; glTF X,Y,-Z'},
                'scope': 'Genesis-first editable bevel/material studies. Source silhouettes and VM blocks retained, source dither averaged. No detailed surface restoration, inferred joints, damage behavior, live binding or final-art acceptance.'}
    (output / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print('GENESIS_VEHICLE_STUDIES', json.dumps({'models': len(receipts), 'output': str(output)}))


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--source', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    a = p.parse_args(sys.argv[sys.argv.index('--') + 1:])
    if any(a.output.resolve().is_relative_to((ROOT / n).resolve()) for n in ('GAME', 'GENESIS', 'reference')):
        p.error('author studies outside original/reference directories')
    build(a.source, a.output)
