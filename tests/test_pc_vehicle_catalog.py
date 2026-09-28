from pathlib import Path
import tempfile
import unittest
from tools.pc_vehicle_catalog import source_catalog, mesh_reference, obj_reference, export

class VehicleCatalogTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):cls.catalog,cls.shapes=source_catalog()
    def test_source_names_and_shape_roles(self):
        self.assertEqual(self.catalog['shape_base'],115)
        self.assertEqual(len(self.catalog['classes']),31)
        for index,name,shape in [(0,'T-62',115),(2,'T-72',119),(5,'M1-A1',125),(7,'M113',129),(17,'HIND',163),(19,'MIGS',166)]:
            row=self.catalog['classes'][index]
            self.assertEqual((row['name'],row['shapes']['primary']),(name,shape))
        self.assertEqual(self.catalog['classes'][17]['shapes'],{'primary':163,'alternate':164,'replacement':None})
    def test_every_named_mesh_keeps_original_primitive_topology(self):
        for index in range(115,168):
            shape=self.shapes[index];model=mesh_reference(shape);obj=obj_reference(model)
            self.assertEqual(len(model['primitives']),len(shape['primitives']))
            self.assertEqual(model['opaque_commands'],shape['opaque_commands'])
            expected=sum(len(p['encoded_indices']) for p in shape['primitives'])
            self.assertEqual(sum(line.startswith('v ') for line in obj.splitlines()),expected)
            self.assertEqual(sum(line.startswith('l ') for line in obj.splitlines()),sum(len(p['encoded_indices'])==2 for p in shape['primitives']))
    def test_export_is_deterministic_and_retains_unsupported_commands(self):
        with tempfile.TemporaryDirectory() as directory:
            a=export(Path(directory)/'a',self.catalog,self.shapes)
            b=export(Path(directory)/'b',self.catalog,self.shapes)
            self.assertEqual(a,b);self.assertEqual(len(a['models']),53)
            self.assertEqual([r['shape_index'] for r in a['models'] if r['opaque_commands']],[145,153,156,161,162])
            for item in a['models']:
                self.assertEqual((Path(directory)/'a'/item['obj']).read_bytes(),(Path(directory)/'b'/item['obj']).read_bytes())
            with self.assertRaises(FileExistsError):export(Path(directory)/'a',self.catalog,self.shapes)
if __name__=='__main__':unittest.main()
