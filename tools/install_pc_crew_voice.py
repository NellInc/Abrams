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
    from tools.pc_crew_voice import SCRIPT,DAMAGE,WARNINGS
except ModuleNotFoundError:
    from check_crew_transcripts import normalized,wording_matches
    from generate_crew_voice import validate_wav,pronounce_headings,PREFERRED
    from pc_crew_voice import SCRIPT,DAMAGE,WARNINGS

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


def prepare(source,script_path=SCRIPT):
    script=json.loads(script_path.read_text());manifest=json.loads((source/'manifest.json').read_text())
    if manifest['script_sha256']!=hashlib.sha256(script_path.read_bytes()).hexdigest():raise ValueError('generation script changed')
    if manifest['voices'].keys()!=script['cues'].keys():raise ValueError('catalogue coverage differs')
    qa=source/'qa-first/transcription-check.json';numbers=source/'qa-bearing-delivery/number-delivery-check.json'
    qa_report=json.loads(qa.read_text())
    transcripts=qa_report['results'];delivery=json.loads(numbers.read_text()) if numbers.exists() else {}
    if transcripts.keys()!=manifest['voices'].keys():raise ValueError('QA coverage differs')
    voices={};payloads={};dest=ROOT/'godot/assets/audio'
    for name,voice in manifest['voices'].items():
        if not re.fullmatch('pc_[a-z_]+',name):raise ValueError('unsafe PC cue')
        raw=(source/f'voice_{name}.wav').read_bytes();metrics=validate_wav(raw)
        if any(voice[k]!=v for k,v in metrics.items()):raise ValueError('generated WAV differs from receipt')
        if voice['text']!=script['cues'][name]['caption']:raise ValueError('caption differs')
        expected=script['cues'][name]['text' if voice['generator']==PREFERRED else 'caption']
        if voice['performed_text']!=pronounce_headings(expected):raise ValueError('performed text differs from script')
        check_take(voice,transcripts[name],delivery.get(name))
        path=dest/f'voice_{name}.wav'
        if path.exists() and path.read_bytes()!=raw:raise ValueError('refusing to replace different installed voice')
        payloads[path]=raw
        voices[name]=voice|{'source_master':str((source/f'voice_{name}.wav').relative_to(ROOT) if source.is_absolute() else source/f'voice_{name}.wav'),
            'processing':'Unmodified generated dry master','transcript_qa':transcripts[name],
            'number_delivery_qa':delivery.get(name)}
    receipt={'scope':script['scope'],'status':'Automated wording checked; digit delivery checked where required; human listening review pending',
             'script_sha256':manifest['script_sha256'],'voices':voices,
             'qa_inputs':[{'path':str(f),'sha256':hashlib.sha256(f.read_bytes()).hexdigest()} for f in (qa,numbers) if f.exists()]}
    if 'revalidation' in qa_report:receipt['qa_revalidation']=qa_report['revalidation']
    return payloads,receipt


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--source',type=Path,required=True);p.add_argument('--dry-run',action='store_true')
    p.add_argument('--bank',choices=('crew','damage','warning'),default='crew');a=p.parse_args()
    payloads,receipt=prepare(a.source,{'crew':SCRIPT,'damage':DAMAGE,'warning':WARNINGS}[a.bank])
    if not a.dry_run:
        for path,raw in payloads.items():path.write_bytes(raw)
        (ROOT/'godot/assets/audio'/f'pc_{a.bank}_provenance.json').write_text(json.dumps(receipt,indent=2)+'\n')
    print(f'{len(payloads)} PC {a.bank} takes verified'+(' (dry run)' if a.dry_run else ' and installed'))


if __name__=='__main__':main()
