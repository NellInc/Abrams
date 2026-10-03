#!/usr/bin/env python3
"""Offline installation of full-sentence PC bearing TTS after blinded wording QA.

Retains the five previously accepted takes. Each new master must match its own
batch script, receipt, caption and independent transcript. No game files or
mixed recordings are read. Nothing is installed until the whole set validates.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
try:
    from tools.generate_crew_voice import validate_wav, pronounce_headings
    from tools.install_pc_crew_voice import check_take
    from tools.pc_crew_voice import BEARINGS
except ModuleNotFoundError as error:
    if error.name != 'tools': raise
    from generate_crew_voice import validate_wav, pronounce_headings
    from install_pc_crew_voice import check_take
    from pc_crew_voice import BEARINGS

ROOT=Path(__file__).resolve().parents[1]


def prepare(source):
    script=json.loads(BEARINGS.read_text());voices={};payloads={}
    repair_folder=source/'repairs'
    repairs={};repair_qa={}
    if repair_folder.exists():
        repair_manifest=json.loads((repair_folder/'manifest.json').read_text())
        repair_script=source/'repair-script.json'
        if repair_manifest['script_sha256']!=hashlib.sha256(repair_script.read_bytes()).hexdigest():
            raise ValueError('repair script changed')
        repairs=repair_manifest['voices']
        repair_qa=json.loads((repair_folder/'qa-first/transcription-check.json').read_text())['results']
        if repairs.keys()!=repair_qa.keys() or not repairs.keys()<=script['cues'].keys():
            raise ValueError('repair QA coverage differs')
    for batch in range(4):
        folder=source/f'batch-{batch}'
        generation=json.loads((folder/'manifest.json').read_text())
        script_path=source/f'script-{batch}.json'
        batch_script=json.loads(script_path.read_text())
        if generation['script_sha256']!=hashlib.sha256(script_path.read_bytes()).hexdigest():
            raise ValueError('generation batch script changed')
        if generation['voices'].keys()!=batch_script['cues'].keys():
            raise ValueError('incomplete generation batch')
        qa=json.loads((folder/'qa-first/transcription-check.json').read_text())['results']
        number_file=folder/'qa-bearing-delivery/number-delivery-check.json'
        numbers=json.loads(number_file.read_text()) if number_file.exists() else {}
        if qa.keys()!=generation['voices'].keys():raise ValueError('incomplete wording QA')
        for name,voice in generation['voices'].items():
            if not re.fullmatch(r'pc_hit_[a-z_]+',name) or name in voices:
                raise ValueError('duplicate/unsafe bearing cue')
            if batch_script['cues'][name]!=script['cues'].get(name):
                raise ValueError('batch and runtime script differ')
            if (voice['text']!=script['cues'][name]['caption'] or
                    voice['performed_text']!=pronounce_headings(script['cues'][name]['text'])):
                raise ValueError('generated words differ from runtime caption')
            master_folder=folder
            original_hash=voice['sha256']
            transcript=qa[name]
            if name in repairs:
                voice=repairs[name]
                master_folder=repair_folder
                transcript=repair_qa[name]
                if (voice['text']!=script['cues'][name]['caption'] or
                        voice['performed_text']!=pronounce_headings(script['cues'][name]['text'])):
                    raise ValueError('repair words differ from runtime caption')
            raw=(master_folder/f'voice_{name}.wav').read_bytes()
            if any(voice[k]!=v for k,v in validate_wav(raw).items()):
                raise ValueError('WAV differs from generation receipt')
            check_take(voice,transcript,numbers.get(name))
            path=ROOT/'godot/assets/audio'/f'voice_{name}.wav'
            if path.exists() and path.read_bytes()!=raw:
                raise ValueError('refusing to replace different installed voice')
            voices[name]=voice|{'source_master':str((master_folder/f'voice_{name}.wav').resolve().relative_to(ROOT)),
                'processing':'Unmodified generated dry master','transcript_qa':transcript,
                'previous_take_sha256':original_hash if name in repairs else None,
                'number_delivery_qa':numbers.get(name)}
            payloads[path]=raw
    if voices.keys()!=script['cues'].keys():raise ValueError('bearing bank coverage differs')
    return payloads,{'provider':'Google Gemini','script_sha256':hashlib.sha256(BEARINGS.read_bytes()).hexdigest(),
        'scope':'355 added full-sentence bearings; existing five retained; automated wording QA, human mix acceptance open',
        'voices':voices}


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--source',type=Path,required=True)
    p.add_argument('--dry-run',action='store_true');args=p.parse_args()
    payloads,receipt=prepare(args.source)
    if not args.dry_run:
        for path,raw in payloads.items():
            if not path.exists():path.write_bytes(raw)
        (ROOT/'godot/assets/audio/pc_bearing_provenance.json').write_text(json.dumps(receipt,indent=2)+'\n')
    print(f'PC_BEARINGS: {len(payloads)} fully verified takes; '+('dry run' if args.dry_run else 'installed unchanged'))


if __name__=='__main__':main()
