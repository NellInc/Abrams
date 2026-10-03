#!/usr/bin/env python3
"""Measured v3 speech timing and finite, source-bound audio operations."""
import argparse,base64,difflib,hashlib,json,re,subprocess,wave
from pathlib import Path
from generate import budget,request,receipt
from captions_critic import normalized,clock,audio_hash

def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,d): p.write_text(json.dumps(d,indent=2)+'\n')
def run(cmd): subprocess.run([str(x) for x in cmd],check=True)
def asr(out,path,action,model='openai/whisper-1'):
    budget(out,action,.1)
    result=request('POST','/audio/transcriptions',json={'model':model,'input_audio':{'data':base64.b64encode(path.read_bytes()).decode(),'format':'wav'},'language':'en','temperature':0,'response_format':'verbose_json','timestamp_granularities':['word','segment']}).json()
    write(out/(action+'.json'),result)
    receipt(out,action,{'model':model,'source_sha256':sha(path),'usage':result.get('usage')},path)
    return result

def sources(out):
    from concurrent.futures import ThreadPoolExecutor
    b=json.loads((out/'approved-script.json').read_text())
    # Same file resolution as revise_v3.make(). v5+ briefs mix speech_segments,
    # which no longer map 1:1 to narration_chunks; this check covers the chunks.
    files=b.get('narration_files',[f'narration-v3-part-{i}-dry.wav' for i in range(3)])
    assert len(files)==len(b['narration_chunks']),'narration_files and narration_chunks differ in length'
    def one(i):
        p=out/'motion/media'/files[i]
        r=asr(out,p,f'dry-asr-{i}')
        differences=[x for x in difflib.ndiff(normalized(b['narration_chunks'][i]),normalized(r['text'])) if not x.startswith('  ')]
        write(out/f'dry-word-check-{i}.json',{'file':files[i],'source_sha256':sha(p),'expected':b['narration_chunks'][i],'heard':r['text'],'differences':differences})
        print('SOURCE_ASR',i,r['text'],differences,flush=True)
        assert not differences
        assert all(w['end']>w['start'] for w in r['words'])
    with ThreadPoolExecutor(max_workers=3) as ex:
        for f in [ex.submit(one,i) for i in range(len(files))]:f.result()

def mix(out):
    b=json.loads((out/'production-brief.json').read_text());m=out/'motion/media'
    inputs=['ffmpeg','-v','error','-y']
    if b.get('revision')=='v5':inputs+=['-filter_complex_threads','1']
    sources=b['speech_segments'];filters=[];labels=[]
    for i,s in enumerate(sources):
        inputs+=['-i',m/s['file']];delay=round(s['start']*1000)
        filters.append(f'[{i}:a]highpass=f={70 if s["speaker"]=="narrator" else 120},loudnorm=I={-18 if s["speaker"]=="narrator" else -16.5}:TP=-3:LRA=7,aresample=48000,aformat=channel_layouts=stereo,adelay={delay}|{delay}[a{i}]');labels.append(f'[a{i}]')
    filters.append(''.join(labels)+f'amix=inputs={len(labels)}:duration=longest:normalize=0,apad,atrim=duration=60,asplit[speech][side]')
    inputs+=['-i',m/'music-suno.wav'];i=len(sources)
    filters.append(f'[{i}:a]loudnorm=I=-24:TP=-3:LRA=8,aresample=48000,aformat=channel_layouts=stereo,volume=.75,afade=t=in:d=0.7,afade=t=out:st=58.3:d=1.7[bed]')
    crews=[s for s in sources if s['speaker']!='narrator']
    a=crews[0]['start']-.2;z=crews[-1]['end']+.2
    intervals='+'.join(f"between(t,{s['start']-.1},{s['end']+.1})" for s in crews) if b.get('revision')=='v5' else f'between(t,{a},{z})'
    filters.append(f"[bed][side]sidechaincompress=threshold=.02:ratio=6:attack=8:release=200[ducked0];[ducked0]volume='if({intervals},0.3,1)':eval=frame[ducked]")
    inputs+=['-i',m/'cannon.wav']
    filters.append(f'[{i+1}:a]aresample=48000,aformat=channel_layouts=stereo,volume=.10,adelay=10467|10467[cannon]')
    filters.append('[speech][ducked][cannon]amix=inputs=3:normalize=0,atrim=duration=60,loudnorm=I=-16:TP=-1.5:LRA=8,aresample=48000[out]')
    run(inputs+['-filter_complex',';'.join(filters),'-map','[out]','-ac','2','-c:a','pcm_s24le',*(['-threads','1'] if b.get('revision')=='v5' else []),m/'final-mix.wav'])
    write(out/'audio-edit-receipt.json',{'source_segments':sources,'narration_untouched':True,'tempo':1,'word_splicing':False,'smoke_audio':False,'cannon':{'time':10.467,'source':'recording-showcase/clear-fire.jsonl','packet_index':114,'event_id':144,'sample':'cannon','clip_begin':70,'media_start_seconds':1.4,'evidence':'10.4 + (114-70-1.4*30)/30'},'final_mix_sha256':sha(m/'final-mix.wav'),'filters':filters})
    if b.get('revision')=='v5':
        d=json.loads((out/'audio-edit-receipt.json').read_text());d.update(narration_untouched='All spoken words reused at tempo1, pauses edited only at source sentence boundaries',sentence_splices=sha(out/'source-audio-edit-receipt.json'),cannon={'time':10.467,'source':'Existing original cannon sample, editorial combat accent; not an assertion of a matching recorded gameplay event'});write(out/'audio-edit-receipt.json',d)

def sequential_segment_words(raw,offset,expected):
    """Assign adjacent utterances by checked word order, retaining ASR times."""
    base=raw[offset:];cursor=0
    for token in expected.split():
        count=1
        while len(normalized(' '.join(w['word'] for w in base[cursor:cursor+count])))<len(normalized(token)):
            count+=1
            assert cursor+count<=len(base),(token,'ASR token mapping exhausted')
        if token=='T-72' and normalized(' '.join(w['word'] for w in base[cursor:cursor+3]))==['t','seventy','two']:count=3
        measured=base[cursor:cursor+count];assert measured,(token,'Missing actual ASR word')
        heard=' '.join(w['word'] for w in measured)
        if token=='T-72':heard=re.sub(r'seventy[ -]?two','72',heard,flags=re.I)
        assert normalized(token)==normalized(heard),(token,heard)
        cursor+=count
    return base[:cursor],offset+cursor

def ordered_cue(records,record):
    """Absorb sub-millisecond ASR overlap so SRT, VTT and burned cues stay strictly ordered."""
    if records and 0<records[-1]['end']-record['start']<=.001:record['start']=records[-1]['end']
    return record

def captions(out):
    b=json.loads((out/'production-brief.json').read_text());review=out/'final-review';review.mkdir(exist_ok=True)
    video=out/'abrams-promo-clean.mp4'
    if not video.exists():video=out/'motion/media/final-mix.m4a'
    path=review/'asr-full-final-audio.wav'
    run(['ffmpeg','-v','error','-y',*(['-threads','1','-filter_threads','1'] if b.get('revision')=='v5' else []),'-i',video,'-vn','-ar','16000','-ac','1',path])
    cached=out/'v3-final-asr-locked.json'
    if cached.exists():
        proof=json.loads((out/'v3-final-asr-locked-receipt.json').read_text())
        assert proof['source_sha256']==sha(path),'Cached transcription belongs to different actual audio'
        r=json.loads(cached.read_text())
    else:r=asr(out,path,'v3-final-asr-locked','deepgram/nova-3')
    raw=r['words']
    expected=' '.join(s['expected'] for s in b['speech_segments'])
    diff=[x for x in difflib.ndiff(normalized(expected),normalized(r['text'])) if not x.startswith('  ')]
    # Original T-72 speech may be written as seventy two by ASR. Preserve
    # actual timing and raw evidence; canonical display comes from the asset.
    words=[];display=[];issues=[];speech_word_cursor=0
    for s in b['speech_segments']:
        if b.get('revision')=='v5':
            found,speech_word_cursor=sequential_segment_words(raw,speech_word_cursor,s['expected'])
            assert all(s['start']-.25<=w['start'] and w['end']<=s['end']+.25 for w in found),('ASR word outside its actual source utterance',s['speaker'])
        else:found=[w for w in raw if s['start']-.1<=w['start']<s['end']+.1]
        heard=' '.join(w['word'] for w in found)
        norm=normalized(heard)
        if s['speaker']=='commander': norm=normalized(re.sub(r'seventy[ -]?two','72',heard,flags=re.I))
        differences=[x for x in difflib.ndiff(normalized(s['expected']),norm) if not x.startswith('  ')]
        if differences:issues.append({'speaker':s['speaker'],'heard':heard,'expected':s['expected'],'differences':differences})
        words += [{**w,'speaker':s['speaker']} for w in found]
        cursor=0
        for token in s['expected'].split():
            count=1
            while len(normalized(' '.join(w['word'] for w in found[cursor:cursor+count])))<len(normalized(token)):
                count+=1
                assert cursor+count<=len(found),(token,'ASR token mapping exhausted')
            if token=='T-72' and normalized(' '.join(w['word'] for w in found[cursor:cursor+3]))==['t','seventy','two']:count=3
            measured=found[cursor:cursor+count]
            assert measured,(s['speaker'],token)
            heard_word=' '.join(w['word'] for w in measured)
            if token=='T-72':heard_word=re.sub(r'seventy[ -]?two','72',heard_word,flags=re.I)
            assert normalized(token)==normalized(heard_word),(token,heard_word)
            # Nell explicitly requested the ordinary spoken word Dynamics.
            # Retain the studio's actual brand spelling in display captions.
            display.append({'word':'Dynamix' if token=='Dynamics' else token,'start':measured[0]['start'],'end':measured[-1]['end'],'speaker':s['speaker'],'asr_words':measured})
            cursor+=count
        assert cursor==len(found)
    if b.get('revision')=='v5':assert speech_word_cursor==len(raw),'Unassigned actual ASR words'
    data={'source':str(video),'source_sha256':sha(video),'audio_pcm_sha256':audio_hash(video),'model':'deepgram/nova-3','text':r['text'],'words':words,'script_word_differences':diff,'unresolved_word_differences':issues}
    write(review/'transcription.json',data)
    print('FINAL_ASR',r['text'],'ISSUES',issues,flush=True)
    assert not issues
    assert all(w['end']>w['start'] for w in words)
    assert all(a['end']<=b['start']+.001 for a,b in zip(words,words[1:]))
    phrases=['Four crew.','One tank.','Your command.','Abrams Battle Tank by Dynamics','was a revolution for its time.','Now, it\'s back!','Scan the horizon, work the terrain,','and hold your crew together','when the shells start landing.','Restored artwork.','Reconstructed lettering.','A choice of visual styles,','including the one you first played.','Drop back through the hatch.','New sound effects and expressive crew voices','bring every station to life.']
    if b.get('revision') in ['v4','v5']:phrases.remove('Drop back through the hatch.')
    if b.get('revision')=='v5':phrases.insert(phrases.index('when the shells start landing.')+1,'Engine damaged.')
    phrases += [c['text'] for c in b['crew_showcase']]
    phrases += ['Underneath, the original game still calls every hit,','every loss and every step of the campaign.','On top, a tandem remaster in a new engine,','linked directly to the old one,','gives it a modern spit-shine.','Save states mean one bad engagement','no longer costs you the whole campaign.','Fast-forward keeps you moving.','The remaster is free and open.','Just bring your own copy of the original PC game,','then button up!']
    if b.get('revision') in ['v4','v5']:
        i=phrases.index('Fast-forward keeps you moving.')
        phrases[i:i+1]=['Fast-forward functions keep you engaged','through the quiet parts.']
    cues=[];cursor=0
    for phrase in phrases:
        count=len(phrase.split());c=display[cursor:cursor+count];cursor+=count
        assert normalized(phrase.replace('Dynamics','Dynamix'))==normalized(' '.join(w['word'] for w in c))
        cues.append(c)
    assert cursor==len(display)
    records=[];srt=[];vtt=['WEBVTT','']
    for i,c in enumerate(cues,1):
        text=' '.join(w['word'].strip() for w in c)
        if c[0]['speaker']!='narrator':text='['+b.get('caption_speaker_labels',{}).get(c[0]['speaker'],c[0]['speaker'].capitalize())+'] '+text
        record=ordered_cue(records,{'start':c[0]['start'],'end':c[-1]['end'],'text':text});records.append(record)
        if len(text)>46:
            t=text.split();mid=min(range(1,len(t)),key=lambda j:abs(len(' '.join(t[:j]))-len(' '.join(t[j:]))));text=' '.join(t[:mid])+'\n'+' '.join(t[mid:])
        assert max(map(len,text.splitlines()))<=46
        srt += [str(i),clock(record['start'])+' --> '+clock(record['end']),text,'']
        vtt += [clock(record['start'],'.')+' --> '+clock(record['end'],'.'),text,'']
    assert all(a['end']<=z['start'] and z['end']>z['start'] for a,z in zip(records,records[1:]))
    write(review/'caption-cues.json',records);write(review/'abrams-promo-words.json',{**data,'words':display,'provenance':'Actual final AAC-mix Nova3 word timings, approved case/punctuation. Spoken T seventy two canonicalizes to T-72 over the same measured three-word span. Nell explicitly requested spoken Dynamics; caption retains the studio brand spelling Dynamix over the same measured word span. AAC stream will be copied into final video; decoded-audio hash equality required.'})
    (review/'abrams-promo.srt').write_text('\n'.join(srt)+'\n');(review/'abrams-promo.vtt').write_text('\n'.join(vtt)+'\n')
    print('CAPTIONS_READY',len(words),'words',len(cues),'cues')

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('action',choices=['sources','mix','captions']);p.add_argument('--output',type=Path,required=True);a=p.parse_args();globals()[a.action](a.output.resolve())
