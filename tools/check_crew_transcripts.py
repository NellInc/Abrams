#!/usr/bin/env python3
"""Transcribe generated crew samples with expected words withheld from the model.

Only fingerprinted generated samples are sent. No original game recording, cue
name or expected transcript is included. Digits must be transcribed as spoken
words: numeric normalization never silently certifies digit-by-digit delivery.
"""
import argparse
import base64
import hashlib
import json
from pathlib import Path
import re
import urllib.error
import urllib.request
try:
    from tools.generate_crew_voice import keychain_secret,validate_wav,BASE
except ModuleNotFoundError:
    from generate_crew_voice import keychain_secret,validate_wav,BASE


def normalized(text):
    return re.sub(r'[^a-z0-9]','',re.sub(r'<[^>]+>','',text).lower())


def wording_matches(transcript, expected):
    # Nell explicitly accepts aviation "niner" for a bearing/heading digit.
    # Keep the exception scoped to numeric calls; whole-number phrases still fail.
    if re.search(r'\b(?:bearing|heading)\b',expected,re.I):
        transcript=re.sub(r'\bniner\b','nine',transcript,flags=re.I)
    return normalized(transcript)==normalized(expected)


def prepare(directory,cues=None,*,number_delivery=False):
    manifest=json.loads((directory/'manifest.json').read_text())
    jobs={k:v for k,v in manifest['voices'].items() if not cues or k in cues}
    if not jobs or (cues and set(cues)-jobs.keys()):raise ValueError('unknown/empty QA selection')
    content=[{'type':'text','text':'Transcribe each labelled audio clip verbatim. Return a JSON object mapping its neutral clip ID to the exact spoken transcript. Write spoken numbers as words, preserving whether they are individual digits or a whole number. Do not convert digit sequences to numerals. Do not add or infer words. Mark any non-speech vocalization in square brackets.'}]
    inputs=[]
    for i,(name,voice) in enumerate(jobs.items()):
        if not re.fullmatch('[a-z_]+',name):raise ValueError('unsafe generated cue name')
        raw=(directory/f'voice_{name}.wav').read_bytes();metrics=validate_wav(raw)
        if metrics['sha256']!=voice['sha256']:raise ValueError('generated audio differs from receipt')
        label=f'clip_{i:02d}'
        content.extend([{'type':'text','text':label},{'type':'audio','mime_type':'audio/wav','data':base64.b64encode(raw).decode()}])
        inputs.append({'id':label,'cue':name,'sha256':metrics['sha256'],'expected':voice['performed_text']})
    schema={'type':'object','properties':{item['id']:{'type':'string'} for item in inputs},
            'required':[item['id'] for item in inputs],'additionalProperties':False}
    if number_delivery:
        content[0]['text']='Listen to each labelled clip and analyze how any bearing or heading number is actually spoken. Distinguish separate digits from compound whole-number words. For each clip return number_delivery (individual_digits, whole_number, no_number, or uncertain) and spoken_number_words (an array of the literal English number words you hear, in order, without any numeric characters). Do not infer a number from context. Do not include the preceding sentence in spoken_number_words.'
        schema['properties']={item['id']:{'type':'object','properties':{
            'number_delivery':{'type':'string','enum':['individual_digits','whole_number','no_number','uncertain']},
            'spoken_number_words':{'type':'array','items':{'type':'string'}}},
            'required':['number_delivery','spoken_number_words'],'additionalProperties':False} for item in inputs}
    request={'model':'gemini-3.8-flash','input':content,'response_format':schema}
    if len(json.dumps(request).encode())>=20_000_000:raise ValueError('audio QA request exceeds inline limit')
    return request,inputs


def evaluate(response,inputs,*,number_delivery=False):
    if response.get('status') not in (None,'completed'):raise ValueError('incomplete transcription')
    parts=[p['text'] for step in response.get('steps',[]) if step.get('type')=='model_output'
           for p in step.get('content',[]) if p.get('type')=='text']
    output=''.join(parts) if parts else response.get('output_text','')
    transcripts=json.loads(output)
    if not isinstance(transcripts,dict) or set(transcripts)!={item['id'] for item in inputs}:
        raise ValueError('transcription IDs/types differ from neutral request')
    if number_delivery:
        result={}
        for item in inputs:
            value=transcripts[item['id']]
            if (not isinstance(value,dict) or set(value)!={'number_delivery','spoken_number_words'} or
                    value['number_delivery'] not in ('individual_digits','whole_number','no_number','uncertain') or
                    not isinstance(value['spoken_number_words'],list) or
                    any(not isinstance(w,str) for w in value['spoken_number_words'])):
                raise ValueError('invalid number-delivery response')
            match=re.search(r'\b(?:bearing|heading) ([a-z ]+)[.!]?$',item['expected'].lower())
            if not match:raise ValueError('expected script has no bearing/heading number words')
            words=match[1].split()
            if len(words)!=3 or any(w not in 'zero one two three four five six seven eight nine'.split() for w in words):
                raise ValueError('expected bearing is not three number words')
            result[item['cue']]=value|{'audio_sha256':item['sha256'],'expected_number_words':words,
                'match':value['number_delivery']=='individual_digits' and [('nine' if w=='niner' else w) for w in value['spoken_number_words']]==words}
        return result
    if any(not isinstance(t,str) for t in transcripts.values()):raise ValueError('invalid transcription types')
    return {item['cue']:{'transcript':transcripts[item['id']],'expected':item['expected'],
            'normalized_match':wording_matches(transcripts[item['id']],item['expected']),
            'audio_sha256':item['sha256']} for item in inputs}


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--directory',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
    p.add_argument('--number-delivery',action='store_true',help='Separate blind phonetic classification for selected bearing clips')
    p.add_argument('--cue',action='append');p.add_argument('--dry-run',action='store_true')
    p.add_argument('--keychain-service',default='aiguardians-google-ai')
    p.add_argument('--keychain-account',default='gemini-api-key');a=p.parse_args()
    request,inputs=prepare(a.directory,a.cue,number_delivery=a.number_delivery);a.output.mkdir(parents=True,exist_ok=False)
    safe={'model':request['model'],'prompt':request['input'][0]['text'],'inputs':inputs,
          'method':('Blind spoken-number classification' if a.number_delivery else 'Automated transcription')+', cue identities and expected words withheld from model'}
    (a.output/'receipt.json').write_text(json.dumps(safe,indent=2)+'\n')
    if a.dry_run:print('QA dry run prepared; no credentials read or audio sent');return
    secret=keychain_secret(a.keychain_service,a.keychain_account)
    req=urllib.request.Request(BASE+'/interactions',data=json.dumps(request).encode(),
        headers={'Content-Type':'application/json','x-goog-api-key':secret})
    try:
        with urllib.request.urlopen(req,timeout=180) as response:data=json.load(response)
    except urllib.error.HTTPError as error:raise RuntimeError(f'Gemini QA returned HTTP {error.code}; no automatic retry') from None
    (a.output/'response.json').write_text(json.dumps(data,indent=2)+'\n')
    results=evaluate(data,inputs,number_delivery=a.number_delivery)
    result=results if a.number_delivery else {'method':safe['method'],'model':request['model'],'results':results}
    filename='number-delivery-check.json' if a.number_delivery else 'transcription-check.json'
    (a.output/filename).write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))
    if not all(item['match' if a.number_delivery else 'normalized_match'] for item in results.values()):raise SystemExit(1)


if __name__=='__main__':main()
