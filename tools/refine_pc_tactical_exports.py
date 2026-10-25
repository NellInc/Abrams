#!/usr/bin/env python3
"""Preserve baked geometry while restoring its tangent frame and contact AO.

Run with Blender --background --factory-startup --python THIS -- --output PATH.
Outputs are candidates only. Existing bake receipts and runtime atlas bytes stay
unchanged; export-polish.json records this separate, non-baking operation.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import struct
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools.build_pc_tactical_roster import ALIASES, expand_glb_alias
from tools.build_pc_tactical_vehicles import attach_occlusion
from tools.source_guard import inside_source


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def mesh_signature(objects):
    # Vertex/loop/UV order and material assignments must remain exact. This is
    # a material/export repair, never a topology or source-ownership rewrite.
    data = []
    for obj in sorted(objects, key=lambda o: o.name):
        mesh = obj.data
        data.append([obj.name, [list(v.co) for v in mesh.vertices],
                     [list(p.vertices) for p in mesh.polygons],
                     [p.material_index for p in mesh.polygons],
                     [list(v.uv) for v in mesh.uv_layers.active.data]])
    return hashlib.sha256(json.dumps(data, separators=(',', ':')).encode()).hexdigest()


def verify_glb(path):
    raw = path.read_bytes()
    assert struct.unpack_from('<4sII', raw) == (b'glTF', 2, len(raw))
    length, kind = struct.unpack_from('<II', raw, 12)
    assert kind == 0x4E4F534A
    data = json.loads(raw[20:20+length])
    for mesh in data['meshes']:
        for primitive in mesh['primitives']:
            assert {'NORMAL', 'TANGENT', 'TEXCOORD_0'} <= primitive['attributes'].keys()
            material = data['materials'][primitive['material']]
            assert 'normalTexture' in material and 'occlusionTexture' in material
    return {'meshes': len(data['meshes']), 'materials': len(data['materials'])}


def main():
    args = sys.argv[sys.argv.index('--')+1:]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, type=Path)
    options = parser.parse_args(args)
    output = options.output.resolve()
    if inside_source(output,ROOT):parser.error('output must be outside original sources')
    if not output.is_relative_to((ROOT / 'artifacts').resolve()):
        parser.error('output must be inside artifacts')
    source = ROOT / 'local-art/pc-tactical-roster-v1'
    if output.exists():parser.error('Use a fresh candidate directory')
    output.mkdir(parents=True)
    models = json.loads((source / 'catalog.json').read_text())['models']
    by_id = {m['shape_index']: m for m in models}
    receipt = {'schema': 1, 'operation': 'restore baked tangent frame and contact occlusion',
               'builder_sha256': sha(__file__), 'runtime_manifest_sha256': sha(source/'manifest.json'),
               'preserved_runtime_files': json.loads((source/'manifest.json').read_text())['files'],
               'states': {}}
    import bpy
    for index, model in sorted(by_id.items()):
        if index in ALIASES:
            continue
        folder = source / str(index)
        target = output / str(index)
        target.mkdir()
        blend = folder / 'vehicle.blend'
        glb_name = model['name'].lower()+'.glb'
        bpy.ops.wm.open_mainfile(filepath=str(blend))
        bpy.context.preferences.filepaths.save_version = 0
        objects = [o for o in bpy.data.objects if o.type == 'MESH' and o.name.endswith('_GAME')]
        assert len(objects) == (2 if index in (161, 162) else 1), (index, [o.name for o in objects])
        before = mesh_signature(objects)
        for obj in objects:
            assert len(obj.data.materials) == 1
            ao = bpy.data.images.get(obj.name+'_ao')
            assert ao is not None and ao.packed_file is not None, (index, obj.name)
            attach_occlusion(bpy, obj.data.materials[0], ao)
        for obj in bpy.context.selected_objects:
            obj.select_set(False)
        for obj in objects:
            obj.hide_set(False)
            obj.select_set(True)
        bpy.context.view_layer.objects.active = objects[0]
        assert mesh_signature(objects) == before
        bpy.ops.export_scene.gltf(filepath=str(target/glb_name), export_format='GLB',
                                  use_selection=True, export_extras=True, export_tangents=True)
        proof = verify_glb(target/glb_name)
        bpy.ops.file.pack_all()
        bpy.ops.wm.save_as_mainfile(filepath=str(target/'vehicle.blend'), check_existing=False)
        proof.update({'before_glb': sha(folder/glb_name), 'before_blend': sha(blend),
                      'glb_sha256': sha(target/glb_name), 'blend_sha256': sha(target/'vehicle.blend'),
                      'geometry_uv_sha256': before, 'bake_receipt_sha256': sha(folder/'model.json')})
        receipt['states'][str(index)] = proof
        print('TACTICAL_EXPORT_POLISHED', index, flush=True)
    for index, donor in ALIASES.items():
        target = output / str(index)
        target.mkdir()
        name = by_id[index]['name'].lower()+'.glb'
        expand_glb_alias(output/str(donor)/(by_id[donor]['name'].lower()+'.glb'), target/name, donor, index)
        proof = verify_glb(target/name)
        proof.update({'alias_of': donor, 'before_glb': sha(source/str(index)/name), 'glb_sha256': sha(target/name)})
        receipt['states'][str(index)] = proof
    assert len(receipt['states']) == 57
    assert all(sha(source/name) == digest for name, digest in receipt['preserved_runtime_files'].items())
    (output/'export-polish.json').write_text(json.dumps(receipt, indent=2)+'\n')
    print('TACTICAL_EXPORT_POLISH_COMPLETE 57 states, 55 editable Blender masters', flush=True)


if __name__ == '__main__':
    main()
