"""Once-only speech for complete, pixel-verified original crew messages.

The catalogue covers portrait-3 damage reports and all 360 hit bearings.
Unknown text remains original-only. Muted first appearances are consumed, and
older page contents cannot replay when stations change. No guest state is read
or changed here; message identity/visibility comes from the original draw trace.
"""
import json
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1]/'godot/data/pc_crew_voice_script.json'
BEARINGS = SCRIPT.with_name('pc_bearing_voice_script.json')


def catalogue():
    return {cue['caption']:(name,0x3D6A if name.startswith('pc_hit_') else 0x3DD2)
            for script in (SCRIPT, BEARINGS)
            for name,cue in json.loads(script.read_text())['cues'].items()}


class CrewBarks:
    def __init__(self):
        self.catalogue=catalogue()
        self.last_message=0

    def advance(self,presentation,status):
        if not status.get('active'):return []
        events=[]
        for message in sorted(presentation.get('messages',[]),key=lambda m:m['id']):
            if message['channel']!='crew' or message['id']<=self.last_message:continue
            self.last_message=message['id']
            selected=self.catalogue.get(message['text'])
            if (not selected or message['speaker']!=3 or message['assignment_ip']!=selected[1]
                    or len(message['parts'])!=2):continue
            events.append({'kind':'crew_visible','sample':None,'voice':selected[0],
                'ip':message['assignment_ip'],'return_ip':0,'value':0,'backend':status['backend'],
                'enabled':bool(status['enabled']),'message_id':message['id'],
                'speaker':message['speaker'],'text':message['text'],'parts':message['parts']})
        return events
