"""Original message assignment identity and complete, visible text grouping.

Queued strings remain internal research data. Public messages are assembled only
from individually source/pixel-verified runs in one presented original frame.
"""
from collections import Counter, deque
import struct

CREW_IPS = (0x3D0C,0x3D6A,0x3D8E,0x3DB0,0x3DD2)
RADIO_IPS = (0x3C90,0x3CD4,0x3F73)


class MessageAssignments:
    def __init__(self):
        self.sequence=0
        self.current={}
        self.counts=Counter()
        self.history=deque(maxlen=512)

    def observe(self,ram,regs,ip):
        if len(ram)!=640*1024 or regs['ds']!=regs['cs']+0x19E0:
            raise ValueError('invalid original message snapshot')
        if ip not in CREW_IPS+RADIO_IPS:raise ValueError('unknown original message assignment')
        ds=regs['ds']*16
        if ds+65536>len(ram):raise ValueError('original message data outside RAM')
        def word(at):return struct.unpack_from('<H',ram,ds+at)[0]
        def string(pointer):
            if not pointer:return None
            end=ram.find(b'\0',ds+pointer,min(ds+65536,ds+pointer+256))
            return bytes(ram[ds+pointer:end]) if end>=0 else None
        channel='crew' if ip in CREW_IPS else 'radio'
        primary=word(0x094C if channel=='crew' else 0x094E)
        secondary=word(0x646A) if channel=='crew' else 0
        parts=[(primary,string(primary))]+([(secondary,string(secondary))] if secondary else [])
        self.sequence+=1;self.counts[channel]+=1
        self.current[channel]=None
        if any(not value for pointer,value in parts):
            self.counts['unsupported']+=1
            return
        item={'id':self.sequence,'channel':channel,'ip':ip,'parts':parts,
              'speaker':ram[ds+0x6464] if channel=='crew' else None}
        self.current[channel]=item
        self.history.append({'id':item['id'],'channel':channel,'ip':ip,'speaker':item['speaker'],
                             'parts':[{'pointer':p,'text':t.decode('cp437')} for p,t in parts]})

    def bind(self,run,text):
        kind=run['kind']
        channel='radio' if kind=='radio' else 'crew' if kind in ('crew_primary','crew_secondary') else None
        if channel is None:return
        item=self.current.get(channel)
        part=1 if kind=='crew_secondary' else 0
        if not item or part>=len(item['parts']) or item['speaker']!=run['speaker']:return
        if item['parts'][part]!=(run['source_pointer'],text):return
        # Identity/count convey no queued suffix or queued radio words.
        run['message_ref']={'id':item['id'],'channel':channel,'ip':item['ip'],
                            'part':part,'parts':len(item['parts'])}


def visible_messages(runs):
    groups={}
    for run in runs:
        ref=run.get('message_ref')
        if ref:groups.setdefault(ref['id'],[]).append(run)
    result=[]
    for identity,parts in groups.items():
        parts=sorted(parts,key=lambda r:r['message_ref']['part'])
        first=parts[0];ref=first['message_ref'];count=ref['parts']
        if count not in (1,2) or len(parts)!=count:continue
        if [r['message_ref']['part'] for r in parts]!=list(range(count)):continue
        if any(any(r[k]!=first[k] for k in ('page_offset','font_sha256','speaker','foreground','background','transparent')) or
               any(r['message_ref'][k]!=ref[k] for k in ('id','channel','ip','parts')) for r in parts):continue
        if count==2:
            x,y,w,h=first['rect'];sx,sy,sw,sh=parts[1]['rect']
            if sx!=x+w or sy!=y or sh!=h:continue
        result.append({'id':identity,'channel':ref['channel'],'assignment_ip':ref['ip'],
            'speaker':first['speaker'],'text':''.join(r['text'] for r in parts),
            'parts':[{'rect':r['rect'],'draw_sequence':r['draw_sequence'],
                      'pixel_sha256':r['pixel_sha256'],'source_pointer':r['source_pointer']} for r in parts],
            'basis':'one original assignment, all parts matched in the same presented framebuffer'})
    return result
