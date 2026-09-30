"""Dependency-free contracts for offline player references and their entry points."""
import hashlib
from html.parser import HTMLParser
import json
from pathlib import Path
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
REF = ROOT / 'docs/player-reference'
DATA = json.loads((REF / 'manual-content.json').read_text())
ALLOW = json.loads((ROOT / 'tools/package/allowlist.json').read_text())


class Links(HTMLParser):
    def __init__(self, text):
        super().__init__()
        self.links = []
        self.feed(text)
    def handle_starttag(self, tag, attrs):
        self.links.extend(value for key, value in attrs if key in ('href', 'src') and value)


class PlayerReference(unittest.TestCase):
    def test_manual_inventory_and_source_fingerprint(self):
        self.assertEqual(len(DATA['missions']), 8)
        self.assertEqual(len(DATA['vehicles']), 16)
        self.assertEqual(len(DATA['keyboard_controls']), 35)
        self.assertEqual(len(DATA['anti_tank_guided_weapons']), 5)
        self.assertEqual(len(DATA['ammunition_and_armament']), 6)
        self.assertEqual(len(DATA['stations']), 5)
        self.assertEqual(DATA['source']['sha256'], '4545710cf18793fe03f4147808a58db4cae72b62e96bb28cd791db661934b618')
        for section in ['missions', 'vehicles', 'keyboard_controls', 'stations', 'anti_tank_guided_weapons', 'ammunition_and_armament', 'other_units_and_objectives']:
            for row in DATA[section]:
                self.assertTrue(row['page_refs'], row['name'])
                for page in row['page_refs']:
                    self.assertEqual(page['pdf_page_1_based'], page['printed_page'] + 4)
        self.assertNotIn(DATA['source']['path'], ALLOW['source'] + ALLOW['private'])

    def test_friendly_units_and_uncertain_fst_values_preserved(self):
        self.assertEqual({v['name'] for v in DATA['vehicles'] if v['allegiance']=='FRIENDLY'}, {'M113', 'M1A1 Abrams', 'M2 Bradley', 'M60A3'})
        fst = next(v for v in DATA['vehicles'] if v['name']=='FST-1')
        self.assertIsNone(fst['specs']['combat_weight_tons'])
        self.assertIsNone(fst['specs']['maximum_speed_kmh'])
        self.assertIn('rumors', fst['description'].lower())
        m60 = next(v for v in DATA['vehicles'] if v['name']=='M60A3')
        self.assertEqual(m60['specs']['range_m'], 750)

    def test_original_creators_are_prominent_and_source_bound(self):
        credits=json.loads((REF/'credits.json').read_text())
        self.assertEqual(credits['studio'],'Dynamix')
        self.assertEqual(credits['publisher'],'Electronic Arts')
        self.assertEqual(credits['source']['sha256'],'97b431e019a277f63239da90ddebd27c02a2417a2d7dfa750e94fc6faf7a07ae')
        names={n for r in credits['rows'] for n in r['names']}
        self.assertEqual(names,{'Damon Slye','David McClurg','Richard Rayl','Greg Volkmer','Kobi Miller','Cyrus Kanga','Jerry Luttrell','Rich Hilleman'})
        readme=(ROOT/'README.md').read_text()
        self.assertLess(readme.index('## Original creators'),readme.index('## Artwork'))
        for n in names:self.assertIn(n,readme)
        for file in ['keyboard-controls.html','field-guide.html']:
            if not (REF/file).exists():continue
            text=(REF/file).read_text()
            self.assertIn('Original creators',text)
            for n in names:self.assertIn(n,text)

    def test_visual_inventory_and_provenance(self):
        visuals=json.loads((REF/'visuals.json').read_text())
        self.assertEqual({r['name'] for r in visuals['maps']},{r['name'] for r in DATA['missions']})
        self.assertEqual(len(visuals['wireframes']),16)
        self.assertEqual(len({r['file'] for r in visuals['wireframes'] if r['file']}),14)
        self.assertIsNone(next(r['file'] for r in visuals['wireframes'] if r['name']=='FST-1'))
        self.assertEqual(next(r['file'] for r in visuals['wireframes'] if r['name']=='BRDM-3'),'wireframe-brdm-2.png')
        for group in visuals.values():
            for r in group:
                if not r['file']:continue
                self.assertEqual(Path(r['file']).name,r['file'])
                self.assertIn('docs/player-reference/'+r['file'],ALLOW['private'])
                if r.get('native_file'):
                    self.assertEqual(Path(r['native_file']).name,r['native_file'])
                    self.assertIn('docs/player-reference/'+r['native_file'],ALLOW['private'])
        for file,rows,hash_key in [('maps-provenance.json','maps','svg_sha256'),('wireframes-provenance.json','drawings','output_sha256')]:
            prov=json.loads((REF/file).read_text())
            for r in prov[rows]:
                path=REF/r['file']
                if path.exists():self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(),r[hash_key])
                if r.get('native_file'):
                    native=REF/r['native_file']
                    if native.exists():
                        raw=native.read_bytes()
                        self.assertEqual(raw[:8],b'\x89PNG\r\n\x1a\n')
                        self.assertEqual(int.from_bytes(raw[16:20],'big'),2400)
                        self.assertEqual(hashlib.sha256(raw).hexdigest(),r['native_png_sha256'])
        mapping=json.loads((REF/'maps-provenance.json').read_text())['mapping']
        self.assertEqual(len(mapping['instruction_slices']),9)
        self.assertEqual(mapping['original_titles'][0],'NUREMBURG HIGHWAY')

    def test_contextual_controls_are_distinct(self):
        zoom = [r for r in DATA['keyboard_controls'] if r['name']=='Z']
        self.assertEqual({tuple(r['stations']) for r in zoom}, {('gunner',), ('commander',)})
        self.assertEqual(len([r for r in DATA['keyboard_controls'] if r['name']=='Enter']), 3)
        self.assertEqual({r['name'] for r in DATA['keyboard_controls'] if r['name'].startswith('F')}, {'F1','F2','F3','F4','F5','F7','F8','F9','F10'})
        text = (ROOT/'tools/build_player_reference.py').read_text()
        for chord in ['Cmd+S','Cmd+L','Cmd+Shift+L','Cmd+G','Ctrl+Alt+S','Ctrl+Alt+L','Ctrl+Alt+Shift+L','Ctrl+Alt+G']:
            self.assertIn(chord, text)

    def test_reviewed_static_assets_and_source_closure(self):
        for name in ['keyboard-controls.html','field-guide.html','keyboard-controls.pdf','field-guide.pdf']:
            path = 'docs/player-reference/' + name
            self.assertIn(path, ALLOW['private'])
            self.assertNotIn(path, ALLOW['source'])
        for name in ['godot/scripts/pc_interface_theme.gd','godot/scripts/pc_reference_library.gd','tools/build_reference_maps.py','tools/build_player_reference.py','tests/test_player_reference.py','godot/tests/test_pc_interface_reference.gd']:
            self.assertIn(name, ALLOW['source'])
        source_ci = (ROOT/'tools/package/source_ci.py').read_text()
        self.assertIn('tests.test_player_reference', source_ci)

    def test_local_reference_guards_and_no_new_game_accelerators(self):
        swift=(ROOT/'tools/standalone/Launcher.swift').read_text()
        self.assertIn('guard ["keyboard-controls.html", "field-guide.html"].contains(name)', swift)
        self.assertIn('fileExists(atPath: url.path)', swift)
        self.assertIn('openReference("keyboard-controls.html")', swift)
        theme=(ROOT/'godot/scripts/pc_interface_theme.gd').read_text()
        self.assertIn('if name not in ["keyboard-controls.html","field-guide.html"]', theme)
        self.assertIn('FileAccess.file_exists(path)', (ROOT/'godot/scripts/pc_reference_library.gd').read_text())
        self.assertIn('show_reference(host: Window', theme)
        self.assertNotIn('OS.shell_open', theme)
        play=(ROOT/'godot/scripts/pc_play_menu.gd').read_text()
        help_section=play.split('help_popup=PopupMenu.new()', 1)[1].split('refresh_controls()',1)[0]
        self.assertIn('_watch(help_popup)', help_section)
        self.assertNotIn('Shortcut.new', help_section)
        self.assertNotIn('set_item_accelerator', help_section)

    def test_glass_has_accessibility_fallback_and_no_frame_shader(self):
        swift=(ROOT/'tools/standalone/Launcher.swift').read_text()
        self.assertIn('NSVisualEffectView', swift)
        self.assertIn('accessibilityDisplayShouldReduceTransparency', swift)
        self.assertIn('accessibilityDisplayOptionsDidChangeNotification', swift)
        theme=(ROOT/'godot/scripts/pc_interface_theme.gd').read_text()
        for forbidden in ['_process(', 'ShaderMaterial', 'hint_screen_texture', 'create_tween(']:
            self.assertNotIn(forbidden, theme)

    @unittest.skipUnless((REF/'field-guide.html').exists(), 'Generated private assets are outside the source-only kit')
    def test_html_asset_links_and_catalogue_coverage(self):
        for name in ['field-guide.html','keyboard-controls.html']:
            text=(REF/name).read_text()
            for target in Links(text).links:
                if target.startswith('#'):continue
                self.assertFalse('://' in target or target.startswith('/'), target)
                self.assertTrue((REF/target).is_file(), target)
                self.assertIn('docs/player-reference/'+target, ALLOW['private'])
            self.assertIn('default-src \'none\'', text)
            self.assertIn('prefers-reduced-transparency', text)
        catalogue=(REF/'field-guide.html').read_text()
        for section in ['missions','vehicles','anti_tank_guided_weapons','ammunition_and_armament','other_units_and_objectives']:
            for row in DATA[section]:self.assertIn(row['name'], catalogue)
        controls=(REF/'keyboard-controls.html').read_text()
        self.assertIn('Menus and briefings', controls)
        self.assertIn('Radio and thermal', controls)

    @unittest.skipUnless((REF/'vehicle-m113.svg').exists(), 'Private model studies are outside the source-only kit')
    def test_sixteen_model_studies_are_named_valid_and_local(self):
        figures=json.loads((REF/'illustrations.json').read_text())['vehicles']
        self.assertEqual({r['name'] for r in figures}, {r['name'] for r in DATA['vehicles']})
        self.assertEqual(len(figures),16)
        for row in figures:
            svg=ET.fromstring((REF/row['svg']).read_text())
            self.assertIn(row['name'], svg.find('{http://www.w3.org/2000/svg}title').text)
            self.assertGreater(row['triangles'],0)
            self.assertEqual(len(row['model_sha256']),64)
            self.assertNotIn('script', (REF/row['svg']).read_text())


if __name__ == '__main__':unittest.main()
