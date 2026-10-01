#!/usr/bin/env python3
"""Actual encoded-audio ASR, separately checking all four inserted crew voices."""
import argparse,base64,difflib,hashlib,json,re,subprocess
from pathlib import Path
from captions_critic import clock,normalized,audio_hash
from generate import request,budget,receipt

ROOT=Path(__file__).resolve().parents[2]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,x):p.write_text(json.dumps(x,indent=2)+'\n')

def main():
    p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);p.add_argument('--asr-backend',choices=['local','openrouter'],default='local');a=p.parse_args();out=a.output.resolve();review=out/'final-review';review.mkdir(exist_ok=True)
    video=out/'abrams-promo-clean.mp4';brief=json.loads((out/'production-brief.json').read_text());script=brief['narration']
    first,middle=script.split('Underneath,',1);middle,last=('Underneath,'+middle).split('Save states',1);last='Save states'+last
    expected_chunks=iter([first,middle,last]);segments=json.loads((out/'speech-segments.json').read_text())
    model=None
    if a.asr_backend=='local':
        from faster_whisper import WhisperModel
        cache=ROOT/'artifacts/promo-20260929/final-review/asr-models';model=WhisperModel('small.en',device='cpu',compute_type='int8',download_root=str(cache))
    video_sha=sha(video);all_raw=[];display=[];differences=[];receipts=[];corrections=[]
    pronunciation=json.loads((out/'pronunciation-final-mix-review-receipt.json').read_text())
    pronunciation_review=json.loads(pronunciation['review'])
    assert pronunciation['finish_reason']=='stop' and pronunciation_review['middle_vowel_class']=='AH',pronunciation_review
    assert pronunciation['source_video_sha256']==video_sha and pronunciation['audio_sha256']==sha(review/'name-final-mix.wav'), 'Pronunciation evidence belongs to different bytes'
    crew_proof=json.loads((out/'crew-final-mix-review-receipt.json').read_text())
    assert crew_proof['finish_reason']=='stop' and crew_proof['source_video_sha256']==video_sha
    heard_crew=json.loads(crew_proof['review'])['heard_barks']
    assert [normalized(x) for x in heard_crew]==[normalized(c['text']) for c in brief['crew_showcase']]
    full_asr=json.loads((review/'full-asr-response.json').read_text())
    full_receipt=json.loads((out/'revision-final-asr-receipt.json').read_text())
    assert full_receipt['source_video_sha256']==video_sha and full_receipt['audio_sha256']==sha(review/'asr-full-final-audio.wav')
    for number,segment in enumerate(segments):
        speaker=segment['speaker'];expected=next(expected_chunks) if speaker=='narrator' else segment['expected']
        start=max(0,segment['start']-(.12 if speaker!='narrator' else 0));end=segment['end']+(.08 if speaker!='narrator' else 0)
        record=review/f'asr-segment-{number:02}.json';wav=review/f'speech-{number:02}.wav'
        cached=json.loads(record.read_text()) if record.exists() else None
        provider_record=review/f'asr-provider-segment-{number:02}.json';provider_wav=review/f'provider-speech-{number:02}.wav'
        if a.asr_backend=='openrouter' and provider_record.exists():
            candidate=json.loads(provider_record.read_text());provider_start=segment['start'] if speaker!='narrator' else start
            if candidate['source_video_sha256']==video_sha and candidate['crop']==[provider_start,end] and provider_wav.exists() and candidate['source_crop_sha256']==sha(provider_wav):
                cached=candidate;record=provider_record;wav=provider_wav;start=provider_start
        valid_cache=bool(cached) and cached['source_video_sha256']==video_sha and cached['crop']==[start,end] and wav.exists() and cached['source_crop_sha256']==sha(wav)
        # Reuse fingerprinted successful checkpoints, never rerun expensive ASR
        # because a later one-word call was ambiguous. Retain its rejected raw
        # evidence and use the authorized hosted ASR for the narrow recheck.
        if valid_cache and (speaker!='loader' or normalized(cached['text'])==['up'] or cached.get('model')=='openai/whisper-1'):
            raw=cached['words'];text=cached['text'];asr_model=cached.get('model','small.en')
        else:
            if a.asr_backend=='openrouter':
                if speaker!='narrator':start=segment['start']
                record=review/f'asr-provider-segment-{number:02}.json';wav=review/f'provider-speech-{number:02}.wav';asr_model='openai/whisper-1'
            else:asr_model='small.en'
            subprocess.run(['ffmpeg','-v','error','-y','-ss',str(start),'-t',str(end-start),'-i',str(video),'-vn','-ar','16000','-ac','1',str(wav)],check=True)
            if a.asr_backend=='openrouter':
                action=f'revision-asr-segment-{number:02}';budget(out,action,.1)
                result=request('POST','/audio/transcriptions',json={'model':asr_model,'input_audio':{'data':base64.b64encode(wav.read_bytes()).decode(),'format':'wav'},'language':'en','temperature':0,'response_format':'verbose_json','timestamp_granularities':['word','segment']}).json()
                write(review/f'provider-response-{number:02}.json',result)
                receipt(out,action,{'model':asr_model,'source_video_sha256':video_sha,'source_crop_sha256':sha(wav),'crop':[start,end],'usage':result.get('usage')})
                text=result['text'];raw=[{**w,'word':w['word'].strip(),'start':w['start']+start,'end':w['end']+start,'speaker':speaker,'segment':number} for w in result['words']]
            else:
                heard,info=model.transcribe(str(wav),language='en',word_timestamps=True,beam_size=5,vad_filter=speaker=='narrator',condition_on_previous_text=False)
                heard=list(heard);raw=[{'word':w.word.strip(),'start':w.start+start,'end':w.end+start,'probability':w.probability,'speaker':speaker,'segment':number} for s in heard for w in s.words];text=' '.join(s.text.strip() for s in heard)
        diff=[s for s in difflib.ndiff(normalized(expected),normalized(text)) if not s.startswith('  ')]
        differences.extend(diff);write(record,{'model':asr_model,'source_crop_sha256':sha(wav),'source_video_sha256':video_sha,'crop':[start,end],'text':text,'words':raw,'differences':diff})
        print('ASR_SEGMENT_READY',number,asr_model,text,flush=True)
        timing_record=record.name
        if speaker=='loader' and normalized(text)!=['up']:
            # Whole-mix ASR correctly identifies this call; isolated ASR hears
            # "Oh". Use that measured word only, independently confirmed by
            # the blind audio critic. Unrelated full-ASR tail hallucinations
            # remain rejected, not promoted into captions.
            up=[w for w in full_asr['words'] if normalized(w['word'])==['up'] and segment['start']<=w['start']<w['end']<=segment['end']]
            assert len(up)==1
            raw=[{**up[0],'speaker':speaker,'segment':number}];text='Up.'
            timing_record='full-asr-response.json'
            corrections.append({'segment':number,'raw_word':'Oh','display_word':'Up!','proof':'crew-final-mix-review-receipt.json','timing':'Correctly recognized Up word from same-audio full-asr-response.json; no estimated timing.'})
        atoms=[{'norm':n,'raw_index':i,**w} for i,w in enumerate(raw) for n in normalized(w['word'])];cursor=0
        for token in expected.split():
            norms=normalized(token);count=len(norms)
            if norms==['dynamix'] and [x['norm'] for x in atoms[cursor:cursor+count]]!=norms:
                # Approved phonetic rendering names the same studio. Only its
                # orthography may be canonicalized, with actual-audio proof.
                count=next((n for n in range(1,5) if cursor+n<len(atoms) and atoms[cursor+n]['norm']=='was'),0)
                assert count,('Unrecognized name boundary',atoms[cursor:cursor+5])
                corrections.append({'segment':number,'raw_word':' '.join(x['word'] for x in atoms[cursor:cursor+count]),'display_word':token,'proof':'pronunciation-final-mix-review-receipt.json','timing':'Unchanged actual ASR word span.'})
            elif speaker in ['loader','driver'] and norms in [['up'],['moving']] and [x['norm'] for x in atoms[cursor:cursor+count]] in [['oh'],['movin']]:
                assert len(atoms)==1 and normalized(heard_crew[number-1])==norms
                corrections.append({'segment':number,'raw_word':atoms[cursor]['word'],'display_word':token,'proof':'crew-final-mix-review-receipt.json','timing':'Unchanged actual ASR word span.'})
            else:assert [x['norm'] for x in atoms[cursor:cursor+count]]==norms,(number,token,text)
            matched=atoms[cursor:cursor+count]
            word={'word':token,'start':matched[0]['start'],'end':matched[-1]['end'],'speaker':speaker,'asr_segment':number,'asr_word_indices':sorted(set(x['raw_index'] for x in matched))}
            if speaker!='narrator' and word['start']<segment['start']:
                # A cropped ASR word cannot precede its actual audio source.
                # Preserve raw timestamps and document this physical floor,
                # which also keeps each role caption on its own portrait.
                word['raw_asr_start']=word['start'];word['start']=segment['start'];word['timing_adjustment']='Floored to measured source-file insertion; crop pre-roll contained no voice from this speaker.'
                assert word['end']>word['start']
            display.append(word)
            cursor+=count
        assert cursor==len(atoms),(number,text)
        all_raw.extend(raw);receipts.append({'speaker':speaker,'actual_text':text,'expected_text':expected,'crop':[start,end],'model':asr_model,'asr_file':timing_record,'isolated_asr_file':record.name})
    all_raw.sort(key=lambda w:w['start']);display.sort(key=lambda w:w['start'])
    assert all(w['end']>w['start'] for w in all_raw)
    assert all(a['end']<=b['start']+.001 for a,b in zip(all_raw,all_raw[1:]))
    data={'source':str(video),'source_sha256':video_sha,'audio_pcm_sha256':audio_hash(video),'model':'small.en and openai/whisper-1, per-segment receipts','language':'en','text':' '.join(r['actual_text'] for r in receipts),'words':all_raw,'script_word_differences':differences,'unresolved_word_differences':[],'speech_segments':receipts,'verified_display_corrections':corrections,'proper_name_disposition':'Dynamix display spelling canonicalizes its explicitly approved DYE-NAHH-MIX rendition; exact measured source word span retained. Actual encoded-audio pronunciation review is fingerprinted separately.'}
    write(review/'transcription.json',data)
    phrases=['Four crew.','One tank.','Your command.','Abrams Battle Tank by Dynamix was a revolution in its time.','Scan the horizon, work the terrain,','pop some smoke, and hold your crew together','when the shells start landing.','The original PC simulation is back,','remastered by fans who remember it fondly.','Restored artwork.','Reconstructed lettering.','A choice of visual styles, including the one you first played.','Drop back through the hatch.','New sound effects and expressive crew voices','bring every station to life.']
    phrases += [c['text'] for c in brief['crew_showcase']]
    phrases += ['Underneath, the original game still calls every hit,','every loss and every step of the campaign.','On top, a tandem remaster in a new engine,','linked directly to the old one,','gives it a modern spit-shine.','Save states mean one bad engagement','no longer costs you the whole campaign.','The remaster is free and open.','Just bring your own copy of the original PC game,','then button up!']
    cursor=0;cues=[];srt=[];vtt=['WEBVTT','']
    for i,phrase in enumerate(phrases,1):
        count=len(phrase.split());words=display[cursor:cursor+count];cursor+=count
        assert normalized(phrase)==normalized(' '.join(w['word'] for w in words)),phrase
        begin,end=words[0]['start'],words[-1]['end'];assert end>begin and end<=brief['duration_seconds']
        text=phrase if words[0]['speaker']=='narrator' else '['+words[0]['speaker'].capitalize()+'] '+phrase
        cues.append({'start':begin,'end':end,'text':text})
        if len(text)>46:
            tokens=text.split();mid=min(range(1,len(tokens)),key=lambda n:abs(len(' '.join(tokens[:n]))-len(' '.join(tokens[n:]))));text=' '.join(tokens[:mid])+'\n'+' '.join(tokens[mid:])
        assert max(map(len,text.splitlines()))<=46
        srt += [str(i),clock(begin)+' --> '+clock(end),text,''];vtt += [clock(begin,'.')+' --> '+clock(end,'.'),text,'']
    assert cursor==len(display)
    assert all(a['end']<=b['start'] for a,b in zip(cues,cues[1:]))
    (review/'abrams-promo.srt').write_text('\n'.join(srt)+'\n');(review/'abrams-promo.vtt').write_text('\n'.join(vtt)+'\n')
    write(review/'caption-cues.json',cues);write(review/'abrams-promo-words.json',{'source':str(video),'source_sha256':video_sha,'audio_pcm_sha256':data['audio_pcm_sha256'],'model':data['model'],'raw_asr':'transcription.json, per-segment ASR files and the loader word in full-asr-response.json','provenance':'Word timings from actual encoded video audio. Role voices transcribed individually in their mix slots; loader timing uses the correctly recognized full-mix Up word. Approved punctuation and case; compound tokens retain their returned source-word spans. Targeted spelling/recognition corrections require independent actual-audio evidence. Two voice-word starts are floored to measured source-file insertion, with raw timestamps retained.','words':display})
    print('V2_ACTUAL_AUDIO_CAPTIONS_COMPLETE',len(display),'words',len(cues),'cues')

if __name__=='__main__':main()
