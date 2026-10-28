"""Optional, read-only enemy launch context. Never a visibility authority."""
from collections import deque
from functools import lru_cache
import json
import struct
try:
    from tools.pc_vehicle_catalog import source_catalog
    from tools.pc_world import read_objects
except ModuleNotFoundError as error:
    if error.name != 'tools': raise
    from pc_vehicle_catalog import source_catalog
    from pc_world import read_objects


@lru_cache(maxsize=1)
def catalog():
    return source_catalog()[0]


def receipt_capability(core_sha256, directory):
    if not core_sha256: return False
    for path in (directory/'abrams-trace.json', directory/'previous'/core_sha256/'abrams-trace.json'):
        try: info = json.loads(path.read_text())
        except (OSError, ValueError): continue
        if isinstance(info, dict) and info.get('trace_sha256') == core_sha256:
            schema = info.get('guided_launch_event_schema')
            fence = info.get('guided_continuity_event_schema')
            return type(schema) is int and schema == 1 and type(fence) is int and fence == 1
    return False


def word(ds, at):
    if not 0 <= at <= 65534: raise ValueError('guided DS pointer outside segment')
    return struct.unpack_from('<H', ds, at)[0]


def pool(ds, pointer):
    if not 0x709e <= pointer < 0x709e+58*30 or (pointer-0x709e)%58:
        raise ValueError('guided object outside allocator pool')
    if not ds[pointer]&128: raise ValueError('guided object unallocated')
    return pointer


def links(ds, source):
    """Only qualified controller identities. Private, never sent as an actor pool."""
    if len(ds) != 65536 or word(ds,0x79c2) != source['shape_base']:
        raise ValueError('guided shape base differs')
    controls,count = word(ds,0x6f54),word(ds,0xa08)
    scenarios,total = word(ds,0x8dc4),word(ds,0x798a)
    table = word(ds,0x8654)
    if not count or controls+count*17>65536 or not total or scenarios+total*42>65536 or table+62>65536:
        raise ValueError('guided array outside DS')
    objects = {o['pointer']:o for o in read_objects(ds,0)['dynamic']}
    result = {}
    for slot in range(count):
        control = controls+17*slot
        if not ds[control]: continue
        record,actor = word(ds,control+1),word(ds,control+3)
        if not scenarios <= record < scenarios+total*42 or (record-scenarios)%42:
            raise ValueError('guided scenario record outside array')
        kind = word(ds,record)
        if kind not in (13,14,15,16): continue
        row = source['classes'][kind]
        at = word(ds,table+2*kind)
        if at != row['table_offset'] or word(ds,at) != row['name_pointer']:
            raise ValueError('guided class pointer differs')
        expected = [255 if row['shapes'][v] is None else row['shapes'][v] for v in ('primary','alternate','replacement')]
        if list(ds[at+6:at+9]) != expected: raise ValueError('guided class shapes differ')
        end = ds.find(b'\0',row['name_pointer'],row['name_pointer']+32)
        if end < 0 or ds[row['name_pointer']:end] != row['name'].encode('ascii'):
            raise ValueError('guided class name differs')
        pool(ds,actor)
        obj = objects[actor]
        if actor == word(ds,0x799b) or obj['flags']&0x10 or obj['shape_index'] != expected[0]: continue
        result[control] = {'controller_pointer':control,'scenario_record':(record-scenarios)//42,
            'class_index':kind,'actor_pointer':actor,'shape_index':obj['shape_index'],
            'pose':{'position':obj['world_position_raw'],'orientation':obj['orientation_u8']}}
    return result


class GuidedLaunches:
    def __init__(self, source=None, shapes=None):
        self.source, self.shapes = source, shapes
        self.enabled = False
        self.frame = self.epoch = None
        self.token = 0
        self.frozen = deque(maxlen=8)
        self.pending = None
        self.queue = deque()
        self.actor_revisions = {}
        self.controller_revisions = {}
        self.generation = 0
        self.load_segment = None
        self.in_frame = []

    def reset(self):
        self.pending = None
        self.frozen.clear()
        self.queue.clear()
        self.frame = self.epoch = None
        self.actor_revisions.clear()
        self.controller_revisions.clear()
        self.generation = 0
        self.in_frame.clear()
        self.load_segment = None

    def before_frame(self, frame, epoch):
        self.pending = None
        self.in_frame.clear()
        self.frame,self.epoch = frame,epoch

    def freeze(self, ram, load, sequence):
        if not self.enabled: return
        try:
            self.load_segment = load
            ds = ram[(load+0x19e0)*16:(load+0x19e0)*16+65536]
            rows = links(ds,self.source or catalog())
            self.frozen.append((sequence,{control:(identity,self.revision(identity)) for control,identity in rows.items()}))
        except (ValueError,IndexError,struct.error):
            self.frozen.append((sequence,{}))

    def candidate(self, registers, raw, offset, presented):
        if not self.enabled or self.frame is None or self.epoch is None: return None
        try:
            if len(raw)!=65544 or offset!=0x033f or len(registers)!=12: return None
            if any(type(r) is not int or not 0<=r<=65535 for r in registers): return None
            schema,backend,gate,reserved = struct.unpack_from('<4H',raw)
            if (schema,reserved)!=(1,0) or backend not in (0,1) or gate!=1: return None
            ds = raw[8:]
            load = registers[8]
            if registers[9]!=load+0x19e0 or (load+0x19e0)*16+65536>640*1024: return None
            if registers[7]<4 or registers[7]+2>65536 or registers[11]*16+registers[7]+2>640*1024: return None
            if backend!=ds[0x35ac]: return None
            control,actor = word(ds,0x777e),word(ds,0x7776)
            identity = links(ds,self.source or catalog()).get(control)
            if not identity or registers[1]!=control or identity['actor_pointer']!=actor: return None
            projectile = pool(ds,word(ds,control+15))
            target,player = pool(ds,word(ds,0x5fc6)),pool(ds,word(ds,0x799b))
            if projectile in (actor,target,player): return None
            if word(ds,projectile+2)!=100 or word(ds,projectile+36)!=250 or ds[projectile+1]!=word(ds,0x79c2)+71 or word(ds,control+12)!=10: return None
            drawing = (presented or {}).get('draw_pass') or {}
            frozen = next((rows for seq,rows in self.frozen if seq==drawing.get('sequence')), {})
            prior = frozen.get(control)
            if prior is None: return None
            displayed,revision = prior
            if revision != self.revision(identity): return None
            if {k:v for k,v in displayed.items() if k!='pose'} != {k:v for k,v in identity.items() if k!='pose'}: return None
            matches = [(index+1,obj) for index,obj in enumerate(drawing.get('objects',[]))
                if obj.get('dynamic_instance') is True and obj.get('kind')!='sprite'
                and obj.get('pointer')==actor and obj.get('shape_index')==identity['shape_index']]
            if len(matches)!=1: return None
            owner,obj = matches[0]
            if self.shapes is not None:
                roots = self.shapes[identity['shape_index']]['roots']
                if obj.get('root') not in [root['offset'] for root in roots]: return None
            ui = (presented or {}).get('ui_overlay') or {}
            stamp = {'pass_sequence':drawing.get('sequence'),'start_ram_sha256':drawing.get('start_ram_sha256'),
                     'video_sha256':(presented or {}).get('video_sha256'),'ui_sha256':ui.get('mask_sha256'),'owner':owner}
            if any(not isinstance(stamp[k],str) or len(stamp[k])!=64 or any(c not in '0123456789abcdef' for c in stamp[k])
                   for k in ('start_ram_sha256','video_sha256','ui_sha256')): return None
            self.token += 1
            return dict(identity,schema=1,frame=self.frame,epoch=self.epoch,token=self.token,
                projectile_pointer=projectile,target_pointer=target,player_target=target==player,
                backend=backend,gate=gate,source=stamp,display_pose=displayed['pose'])
        except (ValueError,IndexError,KeyError,struct.error,TypeError): return None

    def revision(self, identity):
        return (self.generation,self.actor_revisions.get(identity['actor_pointer'],0),
                self.controller_revisions.get(identity['controller_pointer'],0))

    def barrier(self, registers, raw, offset):
        """Native source barriers invalidate even candidates already paired this step."""
        if not self.enabled: return
        if len(raw)!=8 or len(registers)!=12 or any(type(r) is not int or not 0<=r<=65535 for r in registers):
            self.invalidate_all(); return
        schema,kind,pointer,reserved=struct.unpack('<4H',raw)
        load=self.load_segment
        allocations=(0x02b4,0x02bc)
        actors=(0x0a95,0x0aaf,0x0afd,0x0b17,0x3a73)
        controls=(0x429a,0x4435,0x443f,0x4449)
        globals_=(0x516a,0x885a,0x87d3,0x9268)
        if load is None or offset not in allocations+actors+controls+globals_:
            self.invalidate_all(); return
        cs=load+0x0b4d if offset in allocations else load
        if registers[8]!=cs or (offset!=0x9268 and registers[9]!=load+0x19e0):
            self.invalidate_all(); return
        if offset==0x9268 and (registers[10]!=load+0x19e0 or registers[11]!=load+0x19e0):
            self.invalidate_all(); return
        if (kind==1 and offset not in allocations+actors) or (kind==2 and offset not in controls) or (kind==3 and offset not in globals_):
            self.invalidate_all(); return
        if schema!=1 or reserved or kind not in (1,2,3): self.invalidate_all(); return
        if kind==1 and not (0x709e<=pointer<0x709e+30*58 and (pointer-0x709e)%58==0):
            self.invalidate_all(); return
        if kind==2 and not 0<=pointer<=65519: self.invalidate_all(); return
        if kind==3:
            self.invalidate_all(); return
        revisions=self.actor_revisions if kind==1 else self.controller_revisions
        if len(revisions)>=3855 and pointer not in revisions: self.invalidate_all(); return
        revisions[pointer]=revisions.get(pointer,0)+1
        key='actor_pointer' if kind==1 else 'controller_pointer'
        for candidate in self.in_frame:
            if candidate.get(key)==pointer: candidate.clear()
        self.queue=deque(candidate for candidate in self.queue if candidate)
        self.pending=None

    def invalidate_all(self):
        self.generation+=1
        self.actor_revisions.clear()
        self.controller_revisions.clear()
        self.pending=None
        for candidate in self.in_frame: candidate.clear()
        self.queue.clear()

    def observe(self, event, registers, raw, offset, presented):
        prior,self.pending = self.pending,None
        if event==60:
            self.barrier(registers,raw,offset)
            return None
        if event==59:
            candidate = self.candidate(registers,raw,offset,presented)
            if candidate:
                if len(self.in_frame)>=64: return None
                self.in_frame.append(candidate)
                if candidate['player_target']: self.pending = (candidate,tuple(registers))
                elif len(self.queue)<64: self.queue.append(candidate)
            return None
        if event!=25 or prior is None or len(raw)!=12: return None
        candidate,regs = prior
        if struct.unpack_from('<3H',raw)!=(0x9107,0x034f,15): return None
        if len(registers)!=12 or any(registers[i]!=regs[i] for i in (1,6,8,9,11)) or registers[7]!=(regs[7]-4)&65535: return None
        backend,gate = struct.unpack_from('<2H',raw,6)
        if backend!=candidate['backend'] or gate!=candidate['gate']: return None
        return candidate

    def drain(self):
        result = list(self.queue)
        self.queue.clear()
        return result
