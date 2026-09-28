#!/usr/bin/env python3
"""Render four new frontend arrangements from reusable single-instrument samples.

Native Genesis percussion is extracted directly, never recorded through an
emulator. Pitched instruments and every note/rhythm are authored here. This is
neither the original score nor a chip-emulation reconstruction. Local-only.
"""
from __future__ import annotations
import argparse
from array import array
import hashlib
import json
import math
from pathlib import Path
import struct
import wave

ROOT = Path(__file__).resolve().parents[1]
RATE = 24000
CONTEXTS = ('intro', 'menu', 'briefing', 'debrief')


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_percussion(source):
    """Bind extracted samples to both their receipt and the supplied ROM."""
    from tools.extract_genesis_samples import ROM_HASH, sample_bytes
    rom = (ROOT/'GENESIS/M-1 Abrams Battle Tank (USA, Europe).md').read_bytes()
    if hashlib.sha256(rom).hexdigest() != ROM_HASH:
        raise ValueError('Unsupported source ROM')
    manifest = json.loads((source/'manifest.json').read_text())
    if manifest['rom_sha256'] != ROM_HASH:
        raise ValueError('Wrong sample source')
    result, receipts = {}, []
    for name in ('music-sample-00', 'music-sample-01'):
        entry = next(x for x in manifest['samples'] if x['name'] == name)
        path = source/'samples'/f'{name}.wav'
        if digest(path) != manifest['files'][f'samples/{name}.wav']['sha256']:
            raise ValueError('Native WAV hash mismatch')
        with wave.open(str(path), 'rb') as wav:
            if wav.getnchannels()!=1 or wav.getsampwidth()!=1:
                raise ValueError('Wrong native PCM format')
            raw, rate = wav.readframes(wav.getnframes()), wav.getframerate()
        if raw != sample_bytes(rom, entry['header_offset']):
            raise ValueError('Native percussion differs from original ROM')
        # Linear resampling of one dry sample, with a short endpoint taper.
        frames = round(len(raw)*RATE/rate)
        values = array('f')
        for i in range(frames):
            position = i*rate/RATE
            lo = min(int(position), len(raw)-1)
            hi = min(lo+1, len(raw)-1)
            value = (raw[lo]+(raw[hi]-raw[lo])*(position-lo)-128)/128
            values.append(value*min(1, i/48, (frames-1-i)/96))
        result[name] = values
        receipts.append({'name':name,'wav_sha256':digest(path),'rom_data_offset':entry['data_offset'],
            'native_frames':len(raw),'native_rate':rate,'processing':'linear 24 kHz resampling, 2 ms attack and 4 ms endpoint taper'})
    return result, receipts


def instrument(kind, note, seconds):
    """Reusable authored dry tonal samples, no proprietary waveforms."""
    frequency = 440*2**((note-69)/12)
    frames = round(seconds*RATE)
    data = array('f')
    for i in range(frames):
        t = i/RATE
        attack = min(1,t/(0.045 if kind=='brass' else 0.012))
        release = min(1,(seconds-t)/0.14)
        phase = 2*math.pi*frequency*t
        if kind=='bass':
            value = (math.sin(phase)+0.22*math.sin(2*phase)+0.08*math.sin(3*phase))*0.38
        elif kind=='brass':
            value = sum(math.sin(n*phase)/n**1.5 for n in range(1,7))*0.26
            value *= 0.8+0.2*math.exp(-t*5)
        else:
            value = (math.sin(phase)+0.25*math.sin(2*phase)+0.07*math.sin(3*phase))*0.24
        data.append(value*attack*release)
    return data


def score(context):
    """16-bar D-minor thematic variations; beats and pitches remain inspectable."""
    bpm = {'intro':104,'menu':96,'briefing':80,'debrief':88}[context]
    roots = [38,38,34,36,38,41,36,33,38,38,34,36,43,41,33,38]
    motif = [62,69,65,64,62,65,67,69,70,69,65,64,67,65,61,62]
    events=[]
    def note(beat,kind,pitch,length,gain,pan):
        events.append({'beat':beat,'sample':kind,'note':pitch,'beats':length,'gain':gain,'pan':pan})
    for bar, root in enumerate(roots):
        beat = bar*4
        note(beat,'bass',root,3.5,0.50,0)
        chord=[root+24,root+31,root+27 if root in (38,43,33) else root+28]
        for j,pitch in enumerate(chord): note(beat,'pad',pitch,3.8,0.24,-0.4+j*0.4)
        if context!='briefing' or bar%4 in (2,3):
            note(beat,'brass',motif[bar],1.65,0.5 if context=='intro' else 0.34,0.12)
            note(beat+2,'brass',motif[(bar+1)%16],1.5,0.40 if context=='intro' else 0.26,-0.12)
        if context!='briefing':
            for pulse in (0,2): note(beat+pulse,'music-sample-00',0,0,0.16 if context=='debrief' else 0.25,0)
            if bar%4==0: note(beat,'music-sample-01',0,0,0.09,-0.25)
        elif bar%4==0: note(beat,'music-sample-00',0,0,0.10,0)
    return bpm, events


def write_wave(path, left, right):
    peak=max(max(abs(x) for x in left),max(abs(x) for x in right),1e-9)
    scale=min(1.0,0.72/peak)
    samples=array('h')
    for a,b in zip(left,right): samples.extend((round(a*scale*32767),round(b*scale*32767)))
    if struct.pack('=H',1)!=struct.pack('<H',1): samples.byteswap()
    with wave.open(str(path),'wb') as wav:
        wav.setparams((2,2,RATE,0,'NONE','not compressed'))
        wav.writeframes(samples.tobytes())
    return {'sha256':digest(path),'frames':len(left),'sample_rate':RATE,'channels':2,
        'seconds':len(left)/RATE,'peak':peak*scale,'gain_applied':scale,
        'rms':math.sqrt(sum(float(x)**2 for x in samples)/len(samples))/32767,
        'boundary_delta':max(abs(left[0]-left[-1]),abs(right[0]-right[-1]))*scale}


def build(source, output):
    percussion, receipts=read_percussion(source)
    output.mkdir(parents=True,exist_ok=False)
    tracks={}
    for context in CONTEXTS:
        bpm, events=score(context)
        seconds_per_beat=60/bpm
        frames=round(64*seconds_per_beat*RATE)
        left,right=array('f',[0])*frames,array('f',[0])*frames
        cache={}
        for event in events:
            name=event['sample']
            key=(name,event['note'],event['beats'])
            if key not in cache:
                cache[key]=percussion[name] if name in percussion else instrument(name,event['note'],event['beats']*seconds_per_beat)
            sample=cache[key]
            start=round(event['beat']*seconds_per_beat*RATE)
            angle=(event['pan']+1)*math.pi/4
            gl,gr=math.cos(angle)*event['gain'],math.sin(angle)*event['gain']
            for i,value in enumerate(sample):
                # Wrap tails around the loop instead of abruptly truncating them.
                at=(start+i)%frames
                left[at]+=value*gl;right[at]+=value*gr
        path=output/f'{context}.wav'
        tracks[context]={'file':path.name,'bpm':bpm,'bars':16,'beats_per_bar':4,
                         **write_wave(path,left,right),'events':events}
    manifest={'schema':1,'kind':'authored sample-based frontend score',
        'claim':'New arrangements, not the original Genesis score or exact chip synthesis',
        'source_policy':'Local-only source-derived percussion; no mixed gameplay recording, no upload or redistribution authority',
        'builder_sha256':digest(Path(__file__)),'native_sources':receipts,'tracks':tracks}
    (output/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    return manifest


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source',type=Path,default=ROOT/'local-audio/genesis-native-v1')
    parser.add_argument('--output',type=Path,default=ROOT/'local-audio/frontend-music-v1')
    args=parser.parse_args()
    result=build(args.source,args.output)
    print(json.dumps({name:{k:v for k,v in track.items() if k!='events'} for name,track in result['tracks'].items()},indent=2))

if __name__=='__main__':
    # Allow both python -m tools.build_frontend_music and direct invocation.
    import sys
    sys.path.insert(0,str(ROOT))
    main()
