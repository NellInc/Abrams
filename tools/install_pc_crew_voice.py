#!/usr/bin/env python3
"""Install the bounded PC crew set after fingerprinted, blinded wording QA.

This is an offline verification/install step. Automated QA is separate from
human listening approval. Numeric transcripts require a second, independent
spoken-number classification; numeric normalization alone is insufficient.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
try:
    from tools.check_crew_transcripts import normalized,wording_matches
    from tools.generate_crew_voice import validate_wav,pronounce_headings,PREFERRED
    from tools.pc_crew_voice import SCRIPT,DAMAGE,WARNINGS,RADIO
except ModuleNotFoundError:
    from check_crew_transcripts import normalized,wording_matches
    from generate_crew_voice import validate_wav,pronounce_headings,PREFERRED
    from pc_crew_voice import SCRIPT,DAMAGE,WARNINGS,RADIO

DIGITS='zero one two three four five six seven eight nine'.split()
ROOT=Path(__file__).resolve().parents[1]


def check_take(voice,transcription,delivery=None):
    if transcription['audio_sha256']!=voice['sha256'] or transcription['expected']!=voice['performed_text']:
        raise ValueError('transcription custody mismatch')
    if wording_matches(transcription['transcript'],voice['performed_text']):return
    # Only space-separated single digits, never a whole-number transcript, can
    # use the separate phonetic classification to resolve recognizer formatting.
    match=re.fullmatch(r"(We've been hit[!,]? Bearing)\s+([0-9])\s+([0-9])\s+([0-9])[.!]?",transcription['transcript'],re.I)
    if not match or not delivery:raise ValueError('wording or number delivery unverified')
    words=[DIGITS[int(d)] for d in match.groups()[1:]]
    expanded=match[1]+' '+' '.join(words)
    if (normalized(expanded)!=normalized(voice['performed_text']) or
            delivery['audio_sha256']!=voice['sha256'] or
            delivery['number_delivery']!='individual_digits' or
            [('nine' if w=='niner' else w) for w in delivery['spoken_number_words']]!=words):
        raise ValueError('wording or number delivery mismatch')


def _generation(source,script_path):
    manifest_path=source/'manifest.json'
    manifest=json.loads(manifest_path.read_text())
    if manifest['script_sha256']!=hashlib.sha256(script_path.read_bytes()).hexdigest():raise ValueError('generation script changed')
    qa=source/'qa-first/transcription-check.json';numbers=source/'qa-bearing-delivery/number-delivery-check.json'
    report=json.loads(qa.read_text());delivery=json.loads(numbers.read_text()) if numbers.exists() else {}
    if report['results'].keys()!=manifest['voices'].keys():raise ValueError('QA coverage differs')
    return {'source':source,'script':json.loads(script_path.read_text()),'manifest':manifest,
            'qa':report,'delivery':delivery,'inputs':[f for f in (manifest_path,script_path,qa,numbers) if f.exists()]}


def prepare(source,script_path=SCRIPT,*,source_script=None,repair=None):
    script=json.loads(script_path.read_text())
    base=_generation(source,source_script or script_path)
    if base['manifest']['voices'].keys()!=script['cues'].keys():raise ValueError('catalogue coverage differs')
    batches=[base];selected={name:base for name in base['manifest']['voices']}
    if repair is not None:
        replacement=_generation(repair,script_path)
        names=replacement['manifest']['voices'].keys()
        if not names or not names<=selected.keys():raise ValueError('unknown/empty repair selection')
        selected.update({name:replacement for name in names});batches.append(replacement)
    voices={};payloads={};dest=ROOT/'godot/assets/audio'
    for name,batch in selected.items():
        if not re.fullmatch('pc_[a-z_]+',name):raise ValueError('unsafe PC cue')
        cue=script['cues'][name]
        if batch['script']['cues'].get(name)!=cue:raise ValueError('selected generation cue differs from current script')
        if batch['script']['roles'].get(cue['role'])!=script['roles'].get(cue['role']):raise ValueError('selected generation casting differs from current script')
        voice=batch['manifest']['voices'][name];folder=batch['source']
        raw=(folder/f'voice_{name}.wav').read_bytes();metrics=validate_wav(raw)
        if any(voice[k]!=v for k,v in metrics.items()):raise ValueError('generated WAV differs from receipt')
        if voice['text']!=cue['caption']:raise ValueError('caption differs')
        expected=cue['text' if voice['generator']==PREFERRED else 'caption']
        if voice['performed_text']!=pronounce_headings(expected):raise ValueError('performed text differs from script')
        transcript=batch['qa']['results'][name];delivery=batch['delivery'].get(name)
        check_take(voice,transcript,delivery)
        path=dest/f'voice_{name}.wav'
        if path.exists() and path.read_bytes()!=raw:raise ValueError('refusing to replace different installed voice')
        payloads[path]=raw
        voices[name]=voice|{'source_master':str((folder/f'voice_{name}.wav').relative_to(ROOT) if folder.is_absolute() else folder/f'voice_{name}.wav'),
            'generation_script_sha256':batch['manifest']['script_sha256'],
            'processing':'Unmodified generated dry master','transcript_qa':transcript,
            'number_delivery_qa':delivery}
    receipt={'scope':script['scope'],'status':'Automated wording checked; digit delivery checked where required; human listening review pending',
             'script_sha256':hashlib.sha256(script_path.read_bytes()).hexdigest(),'voices':voices,
             'qa_inputs':[{'path':str(f),'sha256':hashlib.sha256(f.read_bytes()).hexdigest()} for batch in batches for f in batch['inputs']]}
    if 'revalidation' in base['qa']:receipt['qa_revalidation']=base['qa']['revalidation']
    return payloads,receipt


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--source',type=Path,required=True);p.add_argument('--dry-run',action='store_true')
    p.add_argument('--source-script',type=Path,help='Fingerprint-pinned original script when retaining unchanged takes')
    p.add_argument('--repair-source',type=Path,help='Independently generated and blind-checked replacement subset from the current script')
    p.add_argument('--bank',choices=('crew','damage','warning','radio'),default='crew');a=p.parse_args()
    payloads,receipt=prepare(a.source,{'crew':SCRIPT,'damage':DAMAGE,'warning':WARNINGS,'radio':RADIO}[a.bank],source_script=a.source_script,repair=a.repair_source)
    if not a.dry_run:
        for path,raw in payloads.items():path.write_bytes(raw)
        (ROOT/'godot/assets/audio'/f'pc_{a.bank}_provenance.json').write_text(json.dumps(receipt,indent=2)+'\n')
    print(f'{len(payloads)} PC {a.bank} takes verified'+(' (dry run)' if a.dry_run else ' and installed'))


if __name__=='__main__':main()
