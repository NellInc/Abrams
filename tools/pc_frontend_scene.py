"""Read-only START/ANIM draw observations for the opening menu scenery.

The rendered preview is accepted only when every uncovered pixel agrees with a
completed original draw. Menus, cursor, input and scenario state remain DOS-owned.
"""
from collections import deque
import copy
import hashlib
import struct
try:
    from tools.inspect_scenarios import decode_resource
    from tools.inspect_shapes import inspect_shapes, primitive_vertices
    from tools.unpack_pc_executables import unpack
    from tools.pc_live_state import active_program
    from tools.pc_vehicle_math import primitive_camera_vertices
except ModuleNotFoundError as error:
    if error.name != 'tools': raise
    from inspect_scenarios import decode_resource
    from inspect_shapes import inspect_shapes, primitive_vertices
    from unpack_pc_executables import unpack
    from pc_live_state import active_program
    from pc_vehicle_math import primitive_camera_vertices

START_SHA = 'a6fd07ae3df4f61806852d92c0c50354b7f7afccee10da88710ef0bc3361ca6a'
SOURCES = {'ANIM.TBL':'a87cb6ebe75d8958397cf35c08f2842fa13e5d1870aba6335c0608468f897e23',
           'SHAPE.TBL':'81cf10917d8647e8ac187e49887494992828277333f17d6c1926e59581f0a193'}
# START's selector leaves the original animated scene visible under its panel.
PREVIEW = (10, 78, 300, 98)
MENU_PREVIEW = (10, 22, 300, 154)
START_PALETTE = [[0,0,0],[255,255,255],[170,170,170],[85,85,85],[85,85,255],[85,255,255],
                 [255,85,85],[170,85,0],[0,170,0],[85,255,85],[255,255,85],[0,0,0],
                 [255,85,85],[255,85,255],[255,255,85],[255,255,255]]

def exposed_matches(raw,pixels,palette,preview,cursor,covered):
    """Every uncovered preview pixel equals the completed page through the palette."""
    rgb=[bytes((p[2],p[1],p[0])) for p in palette]
    # BGRA bytes 0/1/2 against per-channel translate tables; whole rows at a time.
    tables=[bytes(p[c] for p in palette).ljust(256,b'\0') for c in (2,1,0)]
    x,y,w,h=preview
    cy,ch=(cursor['rect'][1],cursor['rect'][3]) if cursor else (0,0)
    for yy in range(y,y+h):
        a=yy*320+x;idx=bytes(pixels[a:a+w])
        if len(idx)!=w or max(idx)>=len(palette):return False
        if cy<=yy<cy+ch:
            if any(raw[i*4:i*4+3]!=rgb[pixels[i]] for i in range(a,a+w) if i not in covered):return False
            continue
        seg=bytes(raw[a*4:(a+w)*4])
        if any(seg[c::4]!=idx.translate(tables[c]) for c in range(3)):return False
    return True

class FrontendScene:
    def __init__(self, directory):
        exe=(directory/'START.EXE').read_bytes()
        if hashlib.sha256(exe).hexdigest()!=START_SHA: raise ValueError('unsupported START scene executable')
        decoded,meta=unpack(exe)
        self.anchors=[]
        for at,n in [(0x42e4,9),(0x10850+0x27c9,32),(0x10850+0x3b2,10),(0x7600+0x31f4,8)]:
            if any(at<=r['load_offset']<at+n for r in meta['relocations']): raise ValueError('relocated scene anchor')
            self.anchors.append((at,decoded[at:at+n]))
        for name,pin in SOURCES.items():
            if hashlib.sha256((directory/name).read_bytes()).hexdigest()!=pin:raise ValueError('unsupported START scene source: '+name)
        self.shape_bytes=decode_resource((directory/'ANIM.TBL').read_bytes())
        self.shapes=inspect_shapes(self.shape_bytes)['shapes']
        # Reuse existing Modern scenery only for exactly identical source faces,
        # colours and roots. Cutscene-only objects keep their own source geometry.
        sim=inspect_shapes(decode_resource((directory/'SHAPE.TBL').read_bytes()))['shapes']
        def signature(s,p):return (str(primitive_vertices(s,p)),tuple(p['prefix_bytes'][1:]))
        self.aliases={}
        for s in self.shapes:
            signatures=[signature(s,p) for p in s['primitives']]
            if not signatures or s['opaque_commands']:continue
            for t in sim:
                target=[signature(t,p) for p in t['primitives']]
                if sorted(signatures)!=sorted(target) or len(set(signatures))!=len(signatures):continue
                faces={p['offset']:t['primitives'][target.index(signature(s,p))]['offset'] for p in s['primitives']}
                def members(shape,root):
                    groups={g['offset']:g for g in shape['groups']}
                    return sorted(p for g in root['group_pointers'] for p in groups[g]['primitive_pointers'])
                roots={}
                for root in s['roots']:
                    matched=[r['offset'] for r in t['roots'] if members(t,r)==sorted(faces[p] for p in members(s,root))]
                    if len(matched)==1:roots[root['offset']]=matched[0]
                if len(roots)==len(s['roots']):self.aliases[s['index']]={'shape':t['index'],'faces':faces,'roots':roots};break
        self.active=None;self.current=None;self.primitive=None;self.background=None
        self.completed=deque(maxlen=4);self.sequence=0;self.vertices_checked=0

    def clear(self):
        self.active=None;self.current=None;self.primitive=None;self.background=None
        self.completed.clear()

    def observe(self,event,regs,raw,offset):
        w=lambda at:struct.unpack_from('<H',raw,at)[0]
        words=lambda at,n:list(struct.unpack_from('<'+'h'*n,raw,at))
        if event==54:
            upper,lower=struct.unpack('<HH',raw)
            self.background={'kind':'horizon','line':[[regs['si'],regs['di']],[regs['bx'],regs['cx']]],'colors':[upper&255,lower&255]}
            return
        if event==55:self.background={'kind':'solid','color':regs['dx']&255};return
        if event==49:
            self.active=None;self.current=None;self.primitive=None
            program=active_program(raw)
            if not program or program['name']!='START':self.clear();return
            load=program['load_segment'];ds=regs['ds']*16
            if regs['ds']!=load+0x1505 or any(raw[load*16+at:load*16+at+len(code)]!=code for at,code in self.anchors):self.clear();return
            shape_base=struct.unpack_from('<H',raw,ds+0x9a0c)[0]*16
            if raw[shape_base:shape_base+len(self.shape_bytes)]!=self.shape_bytes:self.clear();return
            data=raw[ds:ds+65536]
            left,right,top,bottom=struct.unpack_from('<4h',data,0x264b)
            near,cutoff,shift=struct.unpack_from('<3h',data,0x4912)
            if not (0<=left<right<320 and 0<=top<bottom<200 and 0<near<4096 and shift in (6,7,8,9)):self.clear();return
            self.sequence+=1
            self.active={'sequence':self.sequence,'frontend_scene':'START/ANIM',
                'page_offset':(struct.unpack_from('<H',data,0x2660)[0]-0xa000)*16,
                'camera':{'clip':[left,top,right,bottom],'center':list(struct.unpack_from('<2h',data,0x517b)),
                    'near_raw':near,'distance_cutoff_raw':cutoff,'focal_pixels':1<<shift,
                    'matrix_q14_columns':list(struct.unpack_from('<9h',data,0x47cd)),
                    'world_position_raw':list(struct.unpack_from('<3h',data,0x97ee)),
                    'matrix_mode':data[0x4911]},
                'objects':[],'materials':[list(p) for p in zip(struct.unpack_from('<32H',data,0x345e),struct.unpack_from('<32H',data,0x36de))],
                'background':copy.deepcopy(self.background),'unsupported':[]}
            return
        if not self.active:return
        if event==50:
            pointer=w(0x491c);index=raw[pointer+1]
            if index>=len(self.shapes):self.active=None;return
            shape=self.shapes[index]
            if regs['di'] not in [r['offset'] for r in shape['roots']]:self.active=None;return
            self.current={'pointer':pointer,'shape_index':index,'root':regs['di'],
                'dynamic_instance':not bool(raw[0x532f]),'static_path':raw[0x532f],
                'matrix_mode':raw[0x532e],'matrix':words(w(0x532a),9),'view_origin':words(0x4a76,3),
                'world_delta':words(0x4a7c,3),'packed_shift':raw[0x4a75],
                'polygons':[],'primitive_ids':[],'round_forms':[],'draw_order':[]}
            self.active['objects'].append(self.current);self.primitive=None
        elif event==51:
            self.primitive=regs['si']
        elif event==52:
            if not self.current or self.primitive is None:self.active=None;return
            shape=self.shapes[self.current['shape_index']]
            primitive=next((p for p in shape['primitives'] if p['offset']==self.primitive),None)
            if primitive is None:self.active=None;return
            vertices=primitive_camera_vertices(shape,primitive,self.current)
            for encoded,expected in zip(primitive['encoded_indices'],vertices):
                actual=[words(at+(encoded&127)*2,1)[0] for at in (0x4b69,0x4c69,0x4d69)]
                if actual!=expected:raise ValueError('START source vertex mismatch')
                self.vertices_checked+=1
            count=w(0x50b9)
            if count>16:raise ValueError('START polygon exceeds source bounds')
            self.current['draw_order'].append({'kind':'polygon','index':len(self.current['polygons'])})
            self.current['primitive_ids'].append(self.primitive)
            self.current['polygons'].append({'primitive':self.primitive,'camera_vertices':vertices,
                'colors':[raw[0x2656],raw[0x2655]],'fill_mode':raw[0x2654],
                'pixels':list(map(list,zip(words(0x5079,count),words(0x5099,count))))})
        elif event==53:
            if len(raw)!=64000 or offset!=self.active['page_offset']:self.active=None;return
            self.completed.append((self.active,raw));self.active=None;self.current=None

    def paired(self,raw,palette,runs,cursor):
        # Recognition uses complete, pixel-verified source labels. It cannot
        # activate on an intro, briefing, map, partially painted panel or dialog.
        labels={r['text']:r for r in runs}
        if palette!=START_PALETTE:return None
        contexts = [
            ('scenario', PREVIEW, [('MISSION:',[18,16,64,8]),('TIME:',[42,27,40,8]),('SKILL:',[34,40,48,8])]),
            ('menu', MENU_PREVIEW, [('SCENARIO',[20,12,64,8]),('CAMPAIGN',[104,12,64,8]),
                                   ('M1-INFO',[188,12,56,8]),('EXIT',[264,12,32,8])]),
        ]
        matched = [(name,rect) for name,rect,required in contexts
                   if all(text in labels and labels[text]['rect']==box for text,box in required)]
        if len(matched)!=1:return None
        view,preview = matched[0]
        covered=set()
        if cursor:
            import base64
            x,y,w,h=cursor['rect']
            covered={((y+i//w)*320+x+i%w) for i,c in enumerate(base64.b64decode(cursor['indices'])) if c}
        for drawing,pixels in reversed(self.completed):
            if not drawing['objects'] or drawing['background'] is None:continue
            if not exposed_matches(raw,pixels,palette,preview,cursor,covered):continue
            # Copy only the containers rewritten below; source geometry stays shared and read-only.
            result=drawing|{'objects':[o|{'primitive_ids':list(o['primitive_ids']),'polygons':[dict(p) for p in o['polygons']]} for o in drawing['objects']]}
            result['frontend_view']=view
            result['preview_rect']=list(preview)
            for obj in result['objects']:
                alias=self.aliases.get(obj['shape_index'])
                if alias:
                    obj['source_anim_shape']=obj['shape_index'];obj['shape_index']=alias['shape'];obj['root']=alias['roots'][obj['root']]
                    obj['primitive_ids']=[alias['faces'][p] for p in obj['primitive_ids']]
                    for p in obj['polygons']:p['primitive']=alias['faces'][p['primitive']]
                else:
                    # No accidental collision with a gameplay shape identifier.
                    obj['source_anim_shape']=obj['shape_index'];obj['shape_index']+=256
            return result
        return None
