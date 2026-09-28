#!/usr/bin/env python3
"""Offline finite source coverage and installed PCM QA, never a listening verdict.

The call denominator exhausts relative-near-call byte candidates in SIM's first
64 KiB code segment to its known sound/message dispatchers. Explicit tables
classify every candidate. This is not a proof against arbitrary indirect calls.
CPU oracle fixtures supply finite original caption domains; rerun their tools
for fresh execution evidence. No source files are changed or sent anywhere.
"""
from __future__ import annotations
import argparse
from array import array
import hashlib
import json
import math
from pathlib import Path
import struct
import sys
import wave

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools.pc_audio_events import SAMPLES
from tools.unpack_pc_executables import unpack
from tools.pc_crew_voice import catalogue

SIM_HASH = '9ee5a5898ddcb8192d30b4083981419515eb3ca220e6cbcd214df628bb164099'
CONTROL_CALLS = {0xBD0:4, 0x1965:0, 0x198E:4, 0x253F:5, 0x2580:12,
                 0x785C:13, 0x7E13:0, 0x8056:0, 0x81BA:4}
MESSAGE_CALLS = {
    0x3CE0:{0xB2E:'destroyed class table'},
    0x3D0E:{0x6B5A:'256 incoming bearing values'},
    0x3D6E:{0x1B99:'convoy warning',0x20D4:'area warning',0x3CA8:'scenario crew',
            0x7055:'fuel warning',0x7695:'area/water/slope warnings',0x7BE7:'smoke warnings'},
    0x3DB2:{0x4C00:'speed',0x69DF:'subsystem destroyed',0x6A05:'subsystem damaged',
            0x6A73:'mobility bad',0x6A9F:'mobility damaged',0x708D:'overheat'},
    0x3CB2:{0x1B8C:'abort radio',0x1BBB:'complete radio'},
    0x3C46:{0xB3A:'scenario routing',0x1BB1:'scenario routing',0x1C1C:'scenario routing',
            0x26B0:'scenario routing',0x4588:'scenario routing'},
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def near_calls(image, target):
    return {i for i in range(65533) if image[i] == 0xE8 and
            (i+3+struct.unpack_from('<h', image, i+1)[0]) & 65535 == target}


def source_inventory(root=ROOT):
    source = root/'GAME/SIM.EXE'
    if sha(source) != SIM_HASH:
        raise ValueError('Unsupported original SIM')
    image, _ = unpack(source.read_bytes())
    actual = {ip+3 for ip in near_calls(image, 0x9107)}
    mapped = {caller for _, caller in SAMPLES}
    if actual != mapped | CONTROL_CALLS.keys() or mapped & CONTROL_CALLS.keys():
        raise ValueError('Unclassified/overlapping original sound callsites')
    for caller, request in CONTROL_CALLS.items():
        call=caller-3
        expected=b'\xb8'+struct.pack('<H',request)+b'\x50' if request else b'\x2b\xc0\x50'
        if image[call-len(expected):call] != expected:
            raise ValueError('Original motor/stop argument changed')
    sounds = [{'return_ip':caller, 'requests':[
        {'id':value, 'sample':sample, 'voice':voice}
        for (value, ip), (sample, voice) in sorted(SAMPLES.items()) if ip == caller],
        'control_request':CONTROL_CALLS.get(caller)} for caller in sorted(actual)]
    message_calls=[]
    for target, expected in MESSAGE_CALLS.items():
        if near_calls(image, target) != expected.keys():
            raise ValueError(f'Unclassified message callsites for {target:04x}')
        message_calls.extend({'target':target,'call_ip':ip,'family':family}
                             for ip,family in expected.items())
    fixtures=root/'godot/tests/fixtures'
    domains={}
    for family in ('damage','warning','remaining','radio'):
        data=json.loads((fixtures/f'pc_{family}_voice_oracle.json').read_text())
        if data['source_sha256'] != SIM_HASH:
            raise ValueError('Wrong source oracle identity')
        domains[family]={row['caption'] for row in data['rows'] if row['caption']}
    bearing=json.loads((fixtures/'pc_bearings.json').read_text())
    domains['bearing']={"We've been hit! Bearing "+r[2] for r in bearing['rows']}
    available=catalogue()
    radio=json.loads((root/'godot/data/pc_radio_voice_script.json').read_text())['cues']
    available.update({c['caption']:(n,) for n,c in radio.items()})
    rows=[]
    for family,captions in domains.items():
        for caption in sorted(captions):
            selected=available.get(caption)
            if not selected or not (root/'godot/assets/audio'/f'voice_{selected[0]}.wav').is_file():
                raise ValueError('Missing original caption performance: '+caption)
            rows.append({'family':family,'caption':caption,'voice':selected[0]})
    return {'source_sha256':SIM_HASH,'sound_calls':sounds,'message_calls':message_calls,
            'caption_counts':{k:len(v) for k,v in domains.items()},'captions':rows,
            'source_caption_total':len(rows),'installed_pc_caption_total':len(available),
            'supplemental_bearing_takes':len(available)-len(rows),
            'missing_source_captions':[],
            'reused_action_voices':['on_the_way','smoke','loaded'],
            'frontend_narration':'Not eligible: complete utterance and interruption identity absent'}


def pcm_metrics(path):
    with wave.open(str(path), 'rb') as wav:
        channels,width,rate,frames,*_=wav.getparams()
        raw=wav.readframes(frames)
    if width != 2 or channels not in (1,2) or not frames or len(raw)!=frames*channels*width:
        raise ValueError('Invalid complete 16-bit PCM: '+str(path))
    values=array('h',raw)
    if sys.byteorder!='little': values.byteswap()
    peak=max(abs(v) for v in values)
    rms=math.sqrt(sum(v*v for v in values)/len(values))/32768
    # -60 dBFS activity threshold records silence without trimming dry masters.
    threshold=33
    first=next((i//channels for i,v in enumerate(values) if abs(v)>=threshold),frames)
    last=next((i//channels for i,v in enumerate(reversed(values)) if abs(v)>=threshold),frames)
    return {'sha256':sha(path),'frames':frames,'channels':channels,'sample_rate':rate,
            'seconds':frames/rate,'peak_dbfs':20*math.log10(max(peak/32768,1e-12)),
            'rms_dbfs':20*math.log10(max(rms,1e-12)),
            'full_scale_samples':sum(v in (-32768,32767) for v in values),
            'leading_silence_seconds':first/rate,'trailing_silence_seconds':last/rate,
            'boundary_delta':max(abs(values[c]-values[-channels+c]) for c in range(channels))/32768}


def audit(root=ROOT):
    inventory=source_inventory(root)
    folder=root/'godot/assets/audio'
    receipts={}
    for path in sorted(folder.glob('*provenance.json')):
        data=json.loads(path.read_text())
        for group,prefix in [('voices','voice_'),('samples',''),('effects','')]:
            entries=data.get(group,{})
            if isinstance(entries,dict):
                for name,entry in entries.items():
                    if isinstance(entry,dict) and 'sha256' in entry:
                        receipts[prefix+name+'.wav']=entry
    assets=[];errors=[];warnings=[]
    paths=list(sorted(folder.glob('*.wav')))
    music=root/'local-audio/frontend-music-v1'
    if (music/'manifest.json').exists():
        tracks=json.loads((music/'manifest.json').read_text())['tracks']
        if set(tracks)!={'intro','menu','briefing','debrief'}: errors.append('Incomplete frontend arrangements')
        for track in tracks.values():
            p=music/track['file'];paths.append(p);receipts[str(p)]=track
    else: errors.append('Local frontend music missing')
    for path in paths:
        metrics=pcm_metrics(path);entry=receipts.get(str(path),receipts.get(path.name))
        label=str(path.relative_to(root))
        if not entry or entry['sha256']!=metrics['sha256']: errors.append('Custody mismatch: '+label)
        if entry and entry.get('source_master'):
            master=Path(entry['source_master'])
            if not master.is_absolute(): master=root/master
            if not master.is_file() or sha(master)!=metrics['sha256']:
                errors.append('Generated dry master mismatch: '+label)
        if metrics['full_scale_samples']: errors.append('Full-scale PCM samples: '+label)
        if metrics['rms_dbfs'] < -60: errors.append('Silent/near-silent PCM: '+label)
        if path.name.startswith('voice_'):
            if metrics['leading_silence_seconds']>0.5: warnings.append('Long speech lead-in: '+label)
            if metrics['trailing_silence_seconds']>1: warnings.append('Long speech tail: '+label)
        assets.append({'path':label,**metrics})
    return {'schema':1,'scope':__doc__,'inventory':inventory,'assets':assets,'errors':errors,
            'warnings':warnings,'measurement':'PCM sample peak/RMS and -60 dBFS boundary silence; not LUFS or true-peak',
            'acceptance_boundary':'No human listening, per-cue live mission occurrence, or mixed-output clipping verdict'}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args();report=audit()
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(report,indent=2)+'\n')
    print(f"PC_AUDIO_AUDIT: {len(report['assets'])} WAVs, {report['inventory']['source_caption_total']} source captions, "
          f"{len(report['errors'])} errors, {len(report['warnings'])} timing advisories")
    for error in report['errors']: print(error)
    return bool(report['errors'])

if __name__=='__main__': raise SystemExit(main())
