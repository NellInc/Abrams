#!/usr/bin/env python3
"""ASR-derived captions and machine critique of the actually encoded promo."""
import argparse
import base64
import difflib
import hashlib
import json
import re
import subprocess
from pathlib import Path

from PIL import Image, ImageDraw, ImageOps, ImageStat

ROOT=Path(__file__).resolve().parents[2]


def ffprobe(path):
    return json.loads(subprocess.check_output(['ffprobe','-v','error','-show_streams','-show_format','-of','json',str(path)]))


def clock(seconds, separator=','):
    value=round(seconds*1000);hours,value=divmod(value,3600000);minutes,value=divmod(value,60000);seconds,milliseconds=divmod(value,1000)
    return f'{hours:02}:{minutes:02}:{seconds:02}{separator}{milliseconds:03}'


def normalized(text):
    return re.findall(r"[a-z0-9]+",text.lower())


def audio_hash(media):
    pcm=subprocess.check_output(['ffmpeg','-v','error','-threads','1','-filter_threads','1','-i',str(media),'-vn','-ar','48000','-ac','2','-f','s16le','-'])
    return hashlib.sha256(pcm).hexdigest()


def transcribe(media,out,model):
    if model == 'openai/whisper-1':
        from generate import budget,request,receipt
        audio=out/'asr-input.wav'
        subprocess.run(['ffmpeg','-v','error','-y','-i',str(media),'-vn','-ar','16000','-ac','1',str(audio)],check=True)
        # Paid call: same approval, budget and duplicate-action ledger as every
        # other OpenRouter request. A review folder inside a production uses
        # the production's authorization; otherwise budget() refuses.
        ledger=next((d for d in (out,out.parent) if (d/'authorization.json').exists()),out)
        budget(ledger,'captions-asr',.1)
        response=request('POST','/audio/transcriptions',json={'model':model,'input_audio':{'data':base64.b64encode(audio.read_bytes()).decode(),'format':'wav'},'language':'en','temperature':0,'response_format':'verbose_json','timestamp_granularities':['word','segment']}).json()
        (out/'asr-response.json').write_text(json.dumps(response,indent=2)+'\n')
        receipt(ledger,'captions-asr',{'model':model,'source_sha256':hashlib.sha256(media.read_bytes()).hexdigest(),'audio_sha256':hashlib.sha256(audio.read_bytes()).hexdigest(),'usage':response.get('usage')},audio)
        words=[{'word':w['word'].strip(),'start':w['start'],'end':w['end']} for w in response['words']]
        heard=response['text'];language='en'
    else:
        from faster_whisper import WhisperModel
        engine=WhisperModel(model,device='cpu',compute_type='int8',download_root=str(out/'asr-models'))
        segments,info=engine.transcribe(str(media),language='en',word_timestamps=True,beam_size=5,vad_filter=True,condition_on_previous_text=False)
        segments=list(segments)
        words=[{'word':w.word.strip(),'start':w.start,'end':w.end,'probability':w.probability} for s in segments for w in s.words]
        heard=' '.join(s.text.strip() for s in segments);language=info.language
    expected=json.loads((ROOT/'tools/promo/brief.json').read_text())['narration']
    diff=list(difflib.ndiff(normalized(expected),normalized(heard)))
    mismatches=[x for x in diff if not x.startswith('  ')]
    data={'source':str(media.resolve()),'source_sha256':hashlib.sha256(media.read_bytes()).hexdigest(),'audio_pcm_sha256':audio_hash(media),'model':model,'language':language,'text':heard,'words':words,'script_word_differences':mismatches}
    (out/'transcription.json').write_text(json.dumps(data,indent=2)+'\n')
    assert words,'ASR returned no word timestamps'
    cues=[];chunk=[]
    for word in words:
        chunk.append(word)
        phrase=' '.join(x['word'] for x in chunk)
        if len(phrase)>60 or word['end']-chunk[0]['start']>3.8 or (len(chunk)>=4 and phrase.endswith(('.',',',';',':','!','?'))):
            cues.append(chunk);chunk=[]
    if chunk:cues.append(chunk)
    srt=[];vtt=['WEBVTT','']
    previous_end=0
    for i,cue in enumerate(cues,1):
        begin,end=cue[0]['start'],cue[-1]['end']
        assert begin>=previous_end-.005 and end>begin and end<=60.1
        phrase=' '.join(w['word'] for w in cue)
        # Preserve ASR evidence, correct only the verified proper-name spelling.
        phrase=re.sub(r'\bAbrams\b','Abrams',phrase,flags=re.I)
        if len(phrase)>48:
            tokens=phrase.split();middle=min(range(1,len(tokens)),key=lambda n:abs(len(' '.join(tokens[:n]))-len(' '.join(tokens[n:]))))
            phrase=' '.join(tokens[:middle])+'\n'+' '.join(tokens[middle:])
        srt += [str(i),clock(begin)+' --> '+clock(end),phrase,'']
        vtt += [clock(begin,'.')+' --> '+clock(end,'.'),phrase,'']
        previous_end=end
    (out/'abrams-promo.srt').write_text('\n'.join(srt)+'\n')
    (out/'abrams-promo.vtt').write_text('\n'.join(vtt)+'\n')
    print(json.dumps({'words':len(words),'cues':len(cues),'word_differences':mismatches,'last_word_seconds':words[-1]['end']}))


def loudness_checks(returncode,stderr):
    """Fail closed: an unmeasured or unparsed loudness pass is a failed check."""
    matches=re.findall(r'\{\s*"input_i".*?\}',stderr,re.S)
    try:metrics=json.loads(matches[-1]) if matches else {}
    except ValueError:metrics={}
    def value(key):
        try:return float(metrics[key])
        except (KeyError,TypeError,ValueError):return None
    peak,integrated=value('input_tp'),value('input_i')
    return {'loudness_measured':returncode==0 and peak is not None and integrated is not None,
            'true_peak_below_minus_1_db':peak is not None and peak<=-1.0,
            'integrated_loudness_in_delivery_range':integrated is not None and -19<=integrated<=-14},metrics


def critique(media,out):
    actual=out.parent/'production-brief.json'
    brief=json.loads((actual if actual.exists() else ROOT/'tools/promo/brief.json').read_text());probe=ffprobe(media)
    serial=['-threads','1'] if brief.get('revision')=='v5' else []
    videos=[s for s in probe['streams'] if s['codec_type']=='video'];audios=[s for s in probe['streams'] if s['codec_type']=='audio']
    duration=float(probe['format']['duration'])
    checks={'duration_matches_brief':abs(duration-brief['duration_seconds'])<.1,'aspect_ratio_16_9':bool(videos) and videos[0]['width']*9==videos[0]['height']*16,'full_hd':bool(videos) and (videos[0]['width'],videos[0]['height'])==(1920,1080),'audio_present':bool(audios),'h264_video':bool(videos) and videos[0]['codec_name']=='h264','aac_audio':bool(audios) and audios[0]['codec_name']=='aac'}
    result=subprocess.run(['ffmpeg','-v','error',*serial,'-i',str(media),'-f','null','-'],capture_output=True,text=True)
    checks['complete_decode']=result.returncode==0 and not result.stderr.strip()
    (out/'decode-errors.txt').write_text(result.stderr)
    loudness=subprocess.run(['ffmpeg','-hide_banner',*serial,'-i',str(media),'-af','loudnorm=I=-16:TP=-1.5:LRA=11:print_format=json','-f','null','-'],capture_output=True,text=True)
    (out/'loudness.txt').write_text(loudness.stderr)
    loudness_result,metrics=loudness_checks(loudness.returncode,loudness.stderr);checks.update(loudness_result)
    frames=out/'review-frames';frames.mkdir(exist_ok=True)
    transitions=[s['start'] for s in brief['shots'][1:]]+brief.get('internal_transitions',[])
    times=[s['start']+s['duration']/2 for s in brief['shots']]+[s['start']+.5 for s in brief['shots']]+[max(0,t+delta) for t in transitions for delta in (-1/30,0,1/30)]+[23.4,29.1,32.2,34.5,40.5,46.9,51.8,52.2,57,58.5]
    times+=brief.get('review_frame_times',[])
    indices=sorted(set(min(round(duration*30)-1,max(0,round(t*30))) for t in times))
    times=[n/30 for n in indices]
    # Select exact frame numbers in one decode. A timestamp seek rounded just
    # above a cut can skip the very frame where a missing source is visible.
    # FFmpeg's expression parser rejects a long left-associated sum. A
    # balanced tree selects the same indices with shallow parse depth.
    def selection_tree(items):
        if len(items)==1:return f'eq(n,{items[0]})'
        middle=len(items)//2
        return '('+selection_tree(items[:middle])+'+'+selection_tree(items[middle:])+')'
    select=selection_tree(indices)
    subprocess.run(['ffmpeg','-v','error','-y',*serial,'-i',str(media),'-vf',f"select='{select}'",
                    '-fps_mode','vfr','-frames:v',str(len(indices)),*serial,str(frames/'selected-%03d.png')],check=True)
    sheet=Image.new('RGB',(1280,260*((len(times)+3)//4)), '#141915');draw=ImageDraw.Draw(sheet)
    gameplay_samples=[]
    for n,t in enumerate(times):
        destination=frames/f'{t:06.3f}.png'
        (frames/f'selected-{n+1:03d}.png').replace(destination)
        im=Image.open(destination).convert('RGB');thumbnail=ImageOps.contain(im,(320,230));x=n%4*320;y=n//4*260;sheet.paste(thumbnail,(x,y));draw.text((x+8,y+232),f'{t:.1f}s',fill='white')
        shot=next(s for s in brief['shots'] if round(s['start']*30)<=indices[n]<round((s['start']+s['duration'])*30))
        if shot['kind']=='game_capture':
            # Previously broken cuts had uniform background in this region.
            # Branding and subtitles sit outside it.
            stats=ImageStat.Stat(im.crop((430,100,1490,920)).convert('L'))
            gameplay_samples.append({'frame':indices[n],'time':t,'shot':shot['id'],'luma_stddev':stats.stddev[0]})
    sheet.save(out/'final-contact-sheet.png')
    (out/'review-frame-indices.json').write_text(json.dumps({'video_sha256':hashlib.sha256(media.read_bytes()).hexdigest(),
        'sampling':'Exact decoded frame indices, 30 fps; before, on and after every section and internal checkpoint cut.',
        'frames':[{'index':i,'seconds':i/30,'file':f'{i/30:06.3f}.png'} for i in indices]},indent=2)+'\n')
    checks['no_blank_sampled_gameplay_frames']=bool(gameplay_samples) and all(s['luma_stddev']>2 for s in gameplay_samples)
    (out/'gameplay-cut-check.json').write_text(json.dumps({'video_sha256':hashlib.sha256(media.read_bytes()).hexdigest(),
        'criterion':'Central gameplay luma standard deviation exceeds 2 in all sampled gameplay frames, including exact cuts.',
        'samples':gameplay_samples},indent=2)+'\n')
    transcript=json.loads((out/'transcription.json').read_text()) if (out/'transcription.json').exists() else None
    checks['asr_from_this_video']=bool(transcript) and (transcript['source_sha256']==hashlib.sha256(media.read_bytes()).hexdigest() or transcript.get('audio_pcm_sha256')==audio_hash(media))
    if transcript:
        checks['spoken_script_match']=not transcript.get('unresolved_word_differences',transcript['script_word_differences'])
        checks['positive_word_durations']=all(w['end']>w['start'] for w in transcript['words'])
        checks['ordered_words']=all(a['end']<=b['start']+.001 for a,b in zip(transcript['words'],transcript['words'][1:]))
    report={'self_review':'The promo was produced by the reviewing assistant in this session.','video':str(media.resolve()),'video_sha256':hashlib.sha256(media.read_bytes()).hexdigest(),'checks':checks,'loudness':metrics,'probe':probe,'visual_review':'Pending review of extracted screenshots.','subjective_listening':'Unverified unless a playback/analysis tool has actually been used.','rights':'Local review output. Original game and derived cover rights remain with their respective holders. No publication authorized.'}
    (out/'critic-report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({'checks':checks,'loudness':metrics,'frames':len(times),'contact_sheet':str(out/'final-contact-sheet.png')}))
    if not all(checks.values()):raise SystemExit(1)


def polish(out):
    """Use approved typography while retaining measured, unchanged ASR timing."""
    data=json.loads((out/'transcription.json').read_text())
    assert not data['script_word_differences'],'Resolve actual speech differences before caption polishing'
    approved=json.loads((ROOT/'tools/promo/brief.json').read_text())['narration']
    raw=data['words'];words=[];index=0
    for token in approved.split():
        count=len(normalized(token));measured=raw[index:index+count]
        assert normalized(token)==normalized(' '.join(w['word'] for w in measured)),token
        words.append({'word':token,'start':measured[0]['start'],'end':measured[-1]['end'],
                      'asr_word_indices':list(range(index,index+count)),'speaker':'narrator'})
        index+=count
    assert index==len(raw)
    crew=json.loads((out/'crew-asr.json').read_text())
    assert normalized(' '.join(w['word'] for w in crew['words']))==['up']
    words.append({**crew['words'][0],'word':'Up!','speaker':'crew','asr_source':'crew-asr.json'})
    words.sort(key=lambda w:w['start'])
    assert all(w['end']>w['start'] for w in words)
    assert all(a['end']<=b['start']+.001 for a,b in zip(words,words[1:]))
    # Finite editorial phrase breaks avoid flashing a final word by itself.
    # These define grouping only; each boundary still comes from actual ASR.
    phrases=[
        'Four crew.', 'One tank.', 'Your command.',
        'Abrams Battle Tank by Dynamix was a revolution in its time.',
        'Scan the horizon, work the terrain,',
        'pop some smoke, and hold your crew together',
        'when the shells start landing.',
        'The original PC simulation is back,',
        'remastered by fans who remember it fondly.',
        'Restored artwork.', 'Reconstructed lettering.',
        'A choice of visual styles, including the one you first played.',
        'Drop back through the hatch.',
        'New sound effects and expressive crew voices',
        'bring every station to life.', 'Up!',
        'Underneath, the original game still calls every hit,',
        'every loss and every step of the campaign.',
        'On top, a tandem remaster in a new engine,',
        'linked directly to the old one,', 'gives it a modern spit-shine.',
        'Save states mean one bad engagement',
        'no longer costs you the whole campaign.',
        'The remaster is free and open.',
        'Just bring your own copy of the original PC game,', 'then button up!',
    ]
    cues=[];cursor=0
    for phrase in phrases:
        size=len(phrase.split());cue=words[cursor:cursor+size]
        assert normalized(phrase)==normalized(' '.join(w['word'] for w in cue)),phrase
        assert len({w['speaker'] for w in cue})==1
        cues.append(cue);cursor+=size
    assert cursor==len(words)
    srt=[];vtt=['WEBVTT',''];previous=0
    for i,cue in enumerate(cues,1):
        begin,end=cue[0]['start'],cue[-1]['end'];assert begin>=previous and end>begin and end<=60
        phrase=' '.join(w['word'] for w in cue)
        if cue[0]['speaker']=='crew':phrase='[Crew] '+phrase
        if len(phrase)>46:
            tokens=phrase.split();middle=min(range(1,len(tokens)),key=lambda n:abs(len(' '.join(tokens[:n]))-len(' '.join(tokens[n:]))))
            phrase=' '.join(tokens[:middle])+'\n'+' '.join(tokens[middle:])
        assert len(phrase.splitlines())<=2 and max(map(len,phrase.splitlines()))<=46
        srt += [str(i),clock(begin)+' --> '+clock(end),phrase,'']
        vtt += [clock(begin,'.')+' --> '+clock(end,'.'),phrase,''];previous=end
    (out/'abrams-promo.srt').write_text('\n'.join(srt)+'\n')
    (out/'abrams-promo.vtt').write_text('\n'.join(vtt)+'\n')
    (out/'caption-cues.json').write_text(json.dumps([
        {'start':c[0]['start'],'end':c[-1]['end'],
         'text':('[Crew] ' if c[0]['speaker']=='crew' else '')+' '.join(w['word'] for w in c)}
        for c in cues],indent=2)+'\n')
    (out/'abrams-promo-words.json').write_text(json.dumps({'source':data['source'],
        'source_sha256':data['source_sha256'],'audio_pcm_sha256':data['audio_pcm_sha256'],
        'provenance':'Actual encoded audio, small.en word timestamps. Approved capitalization and punctuation; compound spit-shine spans two returned ASR tokens. Crew call uses independent final-audio crop ASR.',
        'raw_asr':'transcription.json','crew_asr':'crew-asr.json','words':words},indent=2)+'\n')
    print(json.dumps({'polished_words':len(words),'cues':len(cues),'positive_ordered_cues':True,'maximum_lines':2}))


def main():
    p=argparse.ArgumentParser();p.add_argument('action',choices=['captions','polish','critic']);p.add_argument('--video',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--asr-model',default='small.en');a=p.parse_args();a.output.mkdir(parents=True,exist_ok=True)
    if a.action=='captions':transcribe(a.video,a.output,a.asr_model)
    elif a.action=='polish':polish(a.output)
    else:critique(a.video,a.output)


if __name__=='__main__':main()
