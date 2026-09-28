from pathlib import Path
import unittest
from tools.audit_pc_portrait_coverage import ROOT, source_audit, driver_visibility


class PortraitCoverageTests(unittest.TestCase):
    @unittest.skipUnless((ROOT/'artifacts/pc-information-baseline-02/crew.bin').exists(),
                         'requires private original source captures and donors')
    def test_finite_four_role_denominator_and_distinct_resource_samples(self):
        result=source_audit()
        self.assertEqual(result['portrait_count'],4)
        self.assertEqual(result['crew_portrait_count'],4)
        self.assertEqual([r['role'] for r in result['roles']],['commander','gunner','driver','loader'])
        self.assertEqual([r['crew_index'] for r in result['roles']],[3,0,1,2])
        self.assertEqual([r['resource_pixel_differences'] for r in result['roles']],[7,19,4,4])
        self.assertEqual(result['crew_nonportrait_bitmaps'][0]['kind'],'tank-and-seat diagram')
        self.assertEqual(sum(r['faces_loaded_proof']['pixels_checked'] for r in result['roles']),10696)

    @unittest.skipUnless((ROOT/'artifacts/pc-portrait-lifecycle-trace-01/text-03570.png').exists(),
                         'requires captured original driver lifecycle')
    def test_independent_first_complete_frame_and_erasure(self):
        result=driver_visibility()
        self.assertEqual(result['frames'],146)
        self.assertEqual(result['first_complete'],3583)
        self.assertEqual(result['first_erased'],3690)
        self.assertEqual(sum(r['portrait']==2 for r in result['rows']),107)


if __name__=='__main__':unittest.main()
