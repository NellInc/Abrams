"""Once-only speech for complete, pixel-verified original crew and radio messages.

The catalogue covers 24 portrait-3 damage reports, all 360 hit bearings and
eight source-qualified warnings/outcome calls from portraits 0, 1 and 2,
and seven original radio captions.
Unknown text remains original-only. Muted first appearances are consumed, and
older page contents cannot replay when stations change. No guest state is read
or changed here; message identity/visibility comes from the original draw trace.
"""
import json
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1]/'godot/data/pc_crew_voice_script.json'
BEARINGS = SCRIPT.with_name('pc_bearing_voice_script.json')
DAMAGE = SCRIPT.with_name('pc_damage_voice_script.json')
WARNINGS = SCRIPT.with_name('pc_warning_voice_script.json')
RADIO = SCRIPT.with_name('pc_radio_voice_script.json')


def catalogue():
    result = {cue['caption']:(name,(0x3D6A if name.startswith('pc_hit_') else 0x3DD2,),3,None)
            for script in (SCRIPT, BEARINGS, DAMAGE)
            for name,cue in json.loads(script.read_text())['cues'].items()}
    for name,cue in json.loads(WARNINGS.read_text())['cues'].items():
        result[cue['caption']] = (name,(cue['assignment_ip'],),cue['speaker'],cue['source_variants'])
    return result


class CrewBarks:
    channel='crew'
    kind='crew_visible'
    default_parts=2
    def __init__(self):
        self.catalogue=catalogue()
        self.last_message=0

    def advance(self,presentation,status):
        if not status.get('active'):return []
        events=[]
        for message in sorted(presentation.get('messages',[]),key=lambda m:m['id']):
            if message['channel']!=self.channel or message['id']<=self.last_message:continue
            self.last_message=message['id']
            selected=self.catalogue.get(message['text'])
            if not selected or message['speaker']!=selected[2] or message['assignment_ip'] not in selected[1]:continue
            variants=selected[3]
            if variants is None:
                if len(message['parts'])!=self.default_parts:continue
            elif [part['source_pointer'] for part in message['parts']] not in variants:continue
            events.append({'kind':self.kind,'sample':None,'voice':selected[0],
                'ip':message['assignment_ip'],'return_ip':0,'value':0,'backend':status['backend'],
                'enabled':bool(status['enabled']),'message_id':message['id'],
                'speaker':message['speaker'],'text':message['text'],'parts':message['parts']})
        return events


class RadioBarks(CrewBarks):
    """Same complete-visible-message gate, with an independent channel identity.

    A queued radio assignment has no public message until actually drawn. R can
    reopen it with a new original assignment; radio arriving while already open
    can also draw directly. Both paths require the actual current pixel proof.
    """
    channel='radio'
    kind='radio_visible'
    default_parts=1

    def __init__(self):
        self.last_message=0
        self.catalogue={cue['caption']:(name,tuple(cue['assignment_ips']),None,cue.get('source_variants'))
            for name,cue in json.loads(RADIO.read_text())['cues'].items()}
