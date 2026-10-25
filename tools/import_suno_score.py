#!/usr/bin/env python3
"""Preserve Suno downloads and build an independent, local-only game score."""
from __future__ import annotations
import argparse
from array import array
import base64
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import wave
from tools.source_guard import inside_source

ROOT = Path(__file__).resolve().parents[1]
RATE = 24000

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def bindings():
    """Reuse the visual recognizers' immutable catalog pins, without their art."""
    fingerprints, sources = [], {}
    def catalog(path, script, constant):
        pin = re.search(r'const '+constant+r'\s*:?=\s*"([a-f0-9]{64})"', (ROOT/script).read_text())
        path = ROOT/path
        if not pin or digest(path) != pin[1]:
            raise ValueError(f'Unpinned source recognition catalogue: {path}')
        data = json.loads(path.read_text())
        inputs = data.get('sources', {})
        if 'source_sha256' in data:
            inputs = inputs | {data['source']: data['source_sha256']}
        for name, sha in inputs.items():
            if digest(ROOT/'GAME'/name) != sha:
                raise ValueError(f'Original source differs: {name}')
        sources.update(inputs)
        return data
    d = catalog('local-art/pc-splash-aftermath-v1/catalog.json',
                'godot/scripts/pc_splash_aftermath_art.gd', 'CATALOG_SHA')
    for row in d['entries']:
        fingerprints.append(dict(program=row['program'], height=200, sha256=row['rgb_sha256'],
                                 context='menu' if row['name']=='publisher' else 'death'))
    d = catalog('local-art/pc-newspapers-v1/newspapers.json',
                'godot/scripts/pc_newspaper_art.gd', 'CATALOG_SHA')
    for row in d['entries']:
        fingerprints.append(dict(program='END', height=72, sha256=row['header_sha256'],
                                 context={'victory':'ending_victory','defeat':'ending_defeat','stalemate':'aftermath'}[row['name']]))
    d = catalog('local-art/pc-information-v3/information.json',
                'godot/scripts/pc_information_art.gd', 'CATALOG_SHA')
    for row in d['entries']:
        fingerprints.append(dict(program='START',height=200,sha256=row['rgb_sha256'],context='menu'))
    d = catalog('local-art/pc-motor-pool-v1/motor-pool.json',
                'godot/scripts/pc_frontend_art.gd', 'MOTOR_CATALOG_SHA')
    palette = [[0,0,0],[255,255,255],[170,170,170],[85,85,85],[85,85,255],[85,255,255],
               [170,0,0],[170,85,0],[0,170,0],[85,255,85],[255,255,85],[0,0,0],
               [255,85,85],[0,0,170],[85,255,255],[255,255,255]]
    indices = [i for b in base64.b64decode(d['packed_indices_base64']) for i in (b>>4,b&15)]
    rgb = bytes(c for i in indices[:320*80] for c in palette[i])
    fingerprints.append(dict(program='SIM',height=80,sha256=hashlib.sha256(rgb).hexdigest(),context='arming'))
    return fingerprints, sources

def render(source, output, loop):
    raw = subprocess.check_output(['ffmpeg','-v','error','-i',str(source),'-vn','-af',
        'loudnorm=I=-18:TP=-2:LRA=11','-ar',str(RATE),'-ac','2','-f','s16le','-'])
    pcm = array('h'); pcm.frombytes(raw)
    if sys.byteorder != 'little': pcm.byteswap()
    frames = len(pcm)//2
    # Remove digital near-silence only, preserving the musical attack and decay.
    active = [i for i in range(frames) if max(abs(pcm[2*i]),abs(pcm[2*i+1]))>33]
    if not active or frames < RATE*10: raise ValueError(f'Empty or short master: {source}')
    first, last = max(0,active[0]-RATE//50), min(frames,active[-1]+RATE//5)
    pcm = pcm[first*2:last*2]; frames = len(pcm)//2
    begin = 0
    if loop:
        # Cold playback retains the original opening. The last two seconds
        # crossfade into seconds 8..10, then the engine loops to second 10.
        # This proves sample continuity; rhythmic fit still needs listening.
        cross = RATE*2; begin = RATE*10
        for i in range(cross):
            weight = (i+1)/cross
            for channel in range(2):
                at = (frames-cross+i)*2+channel
                pcm[at] = round(pcm[at]*(1-weight)+pcm[(begin-cross+i)*2+channel]*weight)
    else:
        for i in range(min(RATE//100,frames//2)):
            for channel in range(2):
                pcm[i*2+channel] = round(pcm[i*2+channel]*i/(RATE//100))
                at = (frames-1-i)*2+channel
                pcm[at] = round(pcm[at]*i/(RATE//100))
    peak = max(abs(x) for x in pcm)/32768
    rms = (sum(float(x)**2 for x in pcm)/len(pcm))**0.5/32768
    boundary = max(abs(pcm[-2+c]-pcm[begin*2+c]) for c in range(2)) if loop else 0
    if peak>=0.999 or rms<0.001: raise ValueError(f'Unusable derivative: {source}')
    # An exact boundary value avoids a codec-independent impulse at wrap.
    if loop:
        for c in range(2): pcm[-2+c] = pcm[begin*2+c]
    if sys.byteorder != 'little': pcm.byteswap()
    with wave.open(str(output),'wb') as wav:
        wav.setparams((2,2,RATE,0,'NONE','not compressed'));wav.writeframes(pcm.tobytes())
    return dict(file=output.name,sha256=digest(output),frames=frames,seconds=frames/RATE,
                sample_rate=RATE,channels=2,loop=loop,loop_begin=begin,peak=peak,rms=rms,
                pre_correction_boundary_delta=boundary,boundary_delta=0)

def build(exports, output):
    if inside_source(output,ROOT): raise ValueError('Output cannot be an original-source directory')
    if output.exists(): raise FileExistsError(f'Refusing to replace an existing score: {output}')
    rows = {x['id']:x for x in json.loads(exports.read_text()) if x['path'].endswith('.wav')}
    score = json.loads((ROOT/'godot/data/pc_suno_score.json').read_text())
    if set(rows)!={x['id'] for x in score['tracks']}: raise ValueError('Twelve WAV exports are required')
    fingerprints, sources = bindings()
    output.mkdir(parents=True); (output/'masters').mkdir()
    tracks = {}
    for cue in score['tracks']:
        row = rows[cue['id']]; original = Path(row['path'])
        if inside_source(original,ROOT): raise ValueError('A game input is not a Suno master')
        master = output/'masters'/(cue['id']+'.wav')
        shutil.copyfile(original, master)
        tracks[cue['id']] = render(master,output/(cue['id']+'.wav'),cue['loop']) | {
            'title':cue['title'],'master_file':'masters/'+master.name,'master_sha256':digest(master),
            'song_url':row['song_url'],'variants':['https://suno.com/song/'+v for v in row['variants']],
            'processing':'FFmpeg loudnorm -18 LUFS/-2 dBTP/11 LU, stereo 24 kHz PCM; near-silence trim; 2 s loop crossfade or 10 ms endpoint fades'}
        print(cue['id'],round(tracks[cue['id']]['seconds'],2),flush=True)
    manifest = dict(schema=1,kind='independent Suno score',provider='Suno',tracks=tracks,
        fingerprints=fingerprints,classification_sources=sources,
        authoring_sha256=digest(ROOT/'godot/data/pc_suno_score.json'),
        builder_sha256=digest(Path(__file__)),listening_acceptance='pending')
    (output/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    return manifest

def musical_analysis(pcm, bpm):
    """Fit the generated pulse, then expose tonal and onset features for edits.

    Tempo and downbeat are estimates, never a claim of perceptual acceptance.
    Only the offline polishing command needs NumPy/SciPy; playback does not.
    """
    import numpy as np
    from scipy.signal import stft, correlate
    from scipy.optimize import minimize_scalar
    mono = pcm.mean(axis=1)[::3]
    frequencies, times, spectrum = stft(mono, fs=8000, nperseg=1024, noverlap=984)
    magnitude = np.abs(spectrum)
    flux = np.maximum(np.diff(np.log1p(100*magnitude), axis=1), 0).mean(axis=0)
    flux = np.maximum(0, flux-np.convolve(flux, np.ones(201)/201, 'same'))
    ac = correlate(flux, flux, mode='full', method='fft')[len(flux)-1:]
    low, high = 60/(bpm*1.08), 60/(bpm*.92)
    # Multiple beat separations improve sub-frame tempo resolution.
    def periodicity(period):
        return -sum(np.interp(period*n/.005, np.arange(len(ac)), ac)/n for n in range(1,9))
    periods = np.linspace(low, high, 401)
    best = min(periods, key=periodicity)
    fit = minimize_scalar(periodicity, bounds=(max(low,best-.002),min(high,best+.002)), method='bounded')
    beat = float(fit.x)
    phases = np.arange(0,beat,.005)
    def pulse(phase):
        return np.interp(np.arange(phase,times[-1],beat), times[1:],flux).mean()
    phase = float(max(phases,key=pulse))
    # Pick the strongest recurring quarter-note position as a bar origin.
    phase += max(range(4),key=lambda n: np.interp(np.arange(phase+n*beat,times[-1],4*beat),times[1:],flux).mean())*beat
    mask = (frequencies>=65)&(frequencies<=4000)
    notes = np.rint(69+12*np.log2(frequencies[mask]/440)).astype(int)%12
    chroma = np.stack([np.square(magnitude[mask][notes==n]).sum(axis=0) for n in range(12)])
    chroma /= np.maximum(1e-10,np.linalg.norm(chroma,axis=0))
    energy = np.sqrt(np.square(magnitude).sum(axis=0))
    return dict(beat=beat,phase=phase,times=times,chroma=chroma,energy=energy,flux=flux)

def phrase_loop(pcm, analysis, *, low=0.0, high=None, cold_open=True, quiet=False):
    """Choose matching 8/16/24/32-bar phrases, crossfade on their fitted pulse."""
    import numpy as np
    a=analysis; beat=a['beat']; bar=4*beat
    high=min(len(pcm)/RATE-.25, high if high is not None else len(pcm)/RATE)
    low=max(low,a['phase']+bar)
    candidates=[]
    def feature(at):
        # Match the complete preceding bar, rather than a single endpoint.
        grid=np.linspace(at-bar,at,33)
        tonal=np.stack([np.interp(grid,a['times'],row) for row in a['chroma']])
        tonal/=max(1e-10,np.linalg.norm(tonal))
        energy=np.interp(grid,a['times'],a['energy'])
        onset=np.interp(grid,a['times'][1:],a['flux'])
        return tonal,energy,onset
    for bars in [8,16,24,32]:
        for s in np.arange(a['phase'],high,beat):
            e=s+bars*bar
            if s<low or e>high or e-s<18:continue
            cs,rs,os=feature(s); ce,re,oe=feature(e)
            tonal=float(np.sum(cs*ce))
            level=float(abs(20*np.log10(max(1e-9,re.mean())/max(1e-9,rs.mean()))))
            rhythm=float(np.dot(os,oe)/max(1e-10,np.linalg.norm(os)*np.linalg.norm(oe)))
            # Musical similarity dominates; favour a developed 16+ bar loop.
            score=3*(1-tonal)+.04*level+.25*(1-rhythm)+(.16 if bars==8 else 0)
            if quiet:score+=float(np.interp(np.arange(s,e,.1),a['times'],a['energy']).mean())*12
            candidates.append((score,s,e,bars,tonal,level,rhythm))
    if not candidates:raise ValueError('No complete eight-bar phrase in requested source section')
    score,s,e,bars,tonal,level,rhythm=min(candidates)
    start,end=round(s*RATE),round(e*RATE)
    cross=round(beat*RATE) # exactly one fitted beat, avoiding doubled bar attacks
    origin=0 if cold_open else start
    result=pcm[origin:end].copy()
    weight=np.linspace(0,1,cross)[:,None]
    weight=weight*weight*(3-2*weight)
    result[-cross:]=result[-cross:]*(1-weight)+pcm[start-cross:start]*weight
    begin=start-origin
    # Smooth a tiny endpoint correction across 2.7 ms, never a last-sample snap.
    correction=result[begin]-result[-1]
    result[-64:]+=np.linspace(0,1,64)[:,None]**2*correction
    if begin>=240:result[:240]*=np.linspace(0,1,240)[:,None]
    return result,dict(loop=True,loop_begin=begin,source_begin_seconds=origin/RATE,
        source_loop_seconds=s,source_end_seconds=e,estimated_bpm=60/beat,
        estimated_bar_origin_seconds=a['phase'],loop_bars=bars,crossfade_beats=1,
        tonal_similarity=tonal,join_level_difference_db=level,onset_similarity=rhythm,
        edit_method='pulse-fitted whole-phrase selection; one-beat smooth overlap; 64-frame endpoint bridge')

def polish(directory, output):
    """Arrange the preserved Suno masters; never overwrite originals or buy exports."""
    import numpy as np
    from scipy.signal import butter,sosfiltfilt
    if inside_source(output,ROOT):raise ValueError('Output cannot be an original-source directory')
    if output.exists():raise FileExistsError(f'Refusing to replace existing edits: {output}')
    old=json.loads((directory/'manifest.json').read_text())
    score=json.loads((ROOT/'godot/data/pc_suno_score.json').read_text())
    output.mkdir(parents=True)
    decoded={}; analyses={}; tracks=dict(old['tracks'])
    def source(key):
        if key not in decoded:
            row=old['tracks'][key];path=directory/row['master_file']
            if digest(path)!=row['master_sha256']:raise ValueError('Preserved master changed: '+key)
            raw=subprocess.check_output(['ffmpeg','-v','error','-i',str(path),'-af',
                'loudnorm=I=-18:TP=-2:LRA=11','-ar',str(RATE),'-ac','2','-f','f32le','-'])
            decoded[key]=np.frombuffer(raw,dtype='<f4').reshape(-1,2).copy()
            cue=next(x for x in score['tracks'] if x['id']==key)
            analyses[key]=musical_analysis(decoded[key],cue['bpm'])
        return decoded[key],analyses[key]
    def save(key,pcm,edit,master):
        peak=float(np.max(np.abs(pcm)))
        if peak>.89:pcm=pcm*(.89/peak)
        data=np.rint(np.clip(pcm,-.999,.999)*32767).astype('<i2')
        path=output/(key+'.wav')
        with wave.open(str(path),'wb') as wav:
            wav.setparams((2,2,RATE,0,'NONE','not compressed'));wav.writeframes(data.tobytes())
        begin=edit.get('loop_begin',0)
        delta=int(np.max(np.abs(data[-1].astype(int)-data[begin].astype(int)))) if edit['loop'] else 0
        row=old['tracks'][master]
        tracks[key]=dict(file=path.name,sha256=digest(path),frames=len(data),seconds=len(data)/RATE,
            sample_rate=RATE,channels=2,peak=float(np.max(np.abs(data)))/32768,
            rms=float(np.sqrt(np.mean(pcm**2))),boundary_delta=delta,
            master_file=row['master_file'],master_sha256=row['master_sha256'],song_url=row['song_url'],
            source_master=master,title=next(x['title'] for x in score['tracks']+score['edits'] if x['id']==key),**edit)
        if edit['loop'] and delta>1:raise ValueError('Loop wrap is discontinuous: '+key)
        print(key,round(len(data)/RATE,2),{k:round(v,3) if isinstance(v,float) else v for k,v in edit.items()},flush=True)
    for cue in score['tracks']:
        if not cue['loop']:continue
        pcm,a=source(cue['id']);edited,meta=phrase_loop(pcm,a)
        save(cue['id'],edited,meta,cue['id'])
    for cue in score['edits']:
        key=cue['id'];master=cue['source_master'];pcm,a=source(master)
        if cue['kind']=='stinger':
            # Start on a measured attack in the opening statement; retain decay.
            eligible=np.where((a['times'][1:]>.15)&(a['times'][1:]<8))[0]
            attack=int(eligible[np.argmax(a['flux'][eligible])])
            begin=max(0,round((a['times'][attack+1]-.025)*RATE))
            duration=min(5.8,max(2.4,4*a['beat']+.7))
            edited=pcm[begin:begin+round(duration*RATE)].copy()
            edited[:240]*=np.linspace(0,1,240)[:,None]
            fade=round(.9*RATE);edited[-fade:]*=np.linspace(1,0,fade)[:,None]**1.5
            meta=dict(loop=False,loop_begin=0,source_begin_seconds=begin/RATE,
                source_end_seconds=(begin+len(edited))/RATE,edit_method='opening attack; one-bar statement and shaped decay')
        else:
            if cue['kind']=='aftermath':
                pcm=sosfiltfilt(butter(2,[90,2600],fs=RATE,btype='bandpass',output='sos'),pcm,axis=0)*.58
                edited,meta=phrase_loop(pcm,a,low=8,high=len(pcm)/RATE-8,cold_open=False,quiet=True)
            else:
                # Independent passages, unchanged pitch/tempo, contrasting voicing.
                lo,hi=cue['source_window_seconds']
                edited,meta=phrase_loop(pcm,a,low=lo,high=hi,cold_open=False)
                if key=='battle_flank':
                    edited=sosfiltfilt(butter(2,4200,fs=RATE,btype='lowpass',output='sos'),edited,axis=0)
                    # Restore the tiny seam correction after zero-phase filtering.
                    edited[-64:]+=np.linspace(0,1,64)[:,None]**2*(edited[0]-edited[-1])
            meta['arrangement']=cue['arrangement']
        save(key,edited,meta,master)
    fingerprints,sources=bindings()
    manifest=old|dict(tracks=tracks,revision=2,fingerprints=fingerprints,classification_sources=sources,
        authoring_sha256=digest(ROOT/'godot/data/pc_suno_score.json'),
        builder_sha256=digest(Path(__file__)),listening_acceptance='pending',
        polish='Six pulse/phrase-matched loops, two arranged battle passages, four stingers and a subdued aftermath bed. Original masters unchanged.')
    (output/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    return manifest

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--exports',type=Path)
    parser.add_argument('--polish',type=Path,help='Existing preserved-master pack to arrange')
    parser.add_argument('--output',type=Path,default=ROOT/'local-audio/suno-score-v1')
    args=parser.parse_args()
    if bool(args.exports)==bool(args.polish):parser.error('Choose exactly one of --exports or --polish')
    if args.polish:polish(args.polish,args.output)
    else:build(args.exports,args.output)
