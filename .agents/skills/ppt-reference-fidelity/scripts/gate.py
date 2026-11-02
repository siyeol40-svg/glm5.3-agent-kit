"""Sequential, hash-bound local gates. Cooperation guardrail, not trusted attestation."""
import argparse
from datetime import datetime, timezone
from pathlib import Path
from common import read, write, sha, digest, emit, cli_error
from inspect_pptx import inspect
from compare_manifests import compare
from validate_pptx import validate
from render_regions import CHECKS

STAGES = ['preflight','route','authority','reference','mapping','edit','structural',
          'integrity','render','visual']
FILES = {'preflight': ['preflight.json'], 'route': ['route.json'],
         'authority': ['authority_contract.json'], 'reference': ['reference_manifest.json'],
         'mapping': ['content_mapping.json'], 'edit': ['edit_evidence.json'],
         'structural': ['result_manifest.json','structural_diff.json'],
         'integrity': ['package_integrity.json'], 'render': ['render_evidence.json','region_plan.json'],
         'visual': ['visual_qa.json']}


def ensure(test, message):
    if not test:
        raise ValueError(message)


def validate_mapping(mapping, ref, result=None):
    ensure(mapping.get('schema') == 'kit.mapping.v1' and mapping.get('locked') is True, 'mapping is not locked')
    ensure(mapping.get('reference_sha256') == ref['artifact_sha256'], 'mapping reference mismatch')
    slots = mapping.get('slots', [])
    ensure(bool(slots), 'empty slots')
    targets = set()
    for s in slots:
        target = (s['slide'], s['target'])
        ensure(target not in targets, 'duplicate slot target'); targets.add(target)
        shapes = {x['key']: x for x in ref['slides'][s['slide']-1]['shapes']}
        ensure(s['target'] in shapes, 'unknown mapping target')
        ensure(s['role'] in ('text','photo','diagram'), 'unknown slot role')
        ensure(s.get('role') == s.get('content_kind'), 'slot semantic role changed')
        ensure(s.get('source_quote') and s['source_quote'] in Path(s['source_file']).read_text(encoding='utf-8'),
               'missing source quote in actual material')
        ensure(sha(s['source_file']) == s['source_sha256'], 'stale content source')
        if result:
            dest = {x['key']: x for x in result['slides'][s['slide']-1]['shapes']}[s['target']]
            if shapes[s['target']]['text']:
                ensure(dest['text'] == s['expected_text'], 'mapped text not replaced: '+s['target'])
            if shapes[s['target']]['images']:
                ensure([i['sha256'] for i in dest['images']] == s['expected_image_sha256'], 'mapped image mismatch')
    # Every text/image-bearing leaf needs a provenance decision, even unchanged copy.
    required = {(i+1, x['key']) for i, slide in enumerate(ref['slides']) for x in slide['shapes']
                if x['text'] or x['images']}
    ensure(required <= targets, 'unmapped reference text/image slots remain')


def verify_stage(stage, work, source, candidate):
    get = lambda n: read(work/n)
    h = sha(candidate) if candidate.exists() else None
    if stage == 'preflight':
        d = get('preflight.json')
        ensure(d.get('schema') == 'kit.preflight.v1' and d.get('status') == 'PASS', 'preflight not PASS')
        ensure(d.get('ppt_master') and d.get('master_files'), 'missing engine inventory')
        for name, info in d['master_files'].items():
            file = Path(d['ppt_master'])/'scripts'/name
            ensure(info.get('exists') and file.is_file() and sha(file) == info.get('sha256'), 'engine inventory changed')
        for name in ('zipfile','xml.etree.ElementTree'):
            ensure(d.get('imports', {}).get(name, {}).get('status') == 'PASS', 'required stdlib unavailable')
    elif stage == 'route':
        d = get('route.json'); ensure(d.get('route') == 'Edit Native PPTX' and d.get('reason'), 'native route required')
    elif stage == 'authority':
        d = get('authority_contract.json')
        ensure(d.get('design_sha256') == sha(source) and d.get('facts'), 'authority contract incomplete')
        for f in d['facts']:
            ensure(sha(f['path']) == f['sha256'], 'stale authority source')
    elif stage == 'reference':
        ensure(get('reference_manifest.json') == inspect(source), 'reference manifest not reproducible')
    elif stage == 'mapping':
        m = get('content_mapping.json')
        validate_mapping(m, get('reference_manifest.json'))
        facts = {(str(Path(f['path']).resolve()),f['sha256']) for f in get('authority_contract.json')['facts']}
        ensure(all((str(Path(s['source_file']).resolve()),s['source_sha256']) in facts for s in m['slots']),
               'mapping source not authorized by authority contract')
        regions = m.get('regions', [])
        ensure(regions and len({r['id'] for r in regions}) == len(regions), 'missing/duplicate locked QA regions')
        for i, slide in enumerate(get('reference_manifest.json')['slides'], 1):
            page_regions = [r for r in regions if r['slide'] == i]
            full = [r for r in page_regions if r.get('full_slide') is True]
            ensure(len(full) == 1, 'one full-slide region required per slide')
            details = [r for r in page_regions if not r.get('full_slide')]
            required = {x['key'] for x in slide['shapes'] if x['text'] or x['images']}
            covered = {key for r in details for key in r.get('targets', [])}
            ensure(required <= covered, 'detail QA must cover every content slot')
    elif stage == 'edit':
        d = get('edit_evidence.json')
        ensure(h and d.get('artifact_sha256') == h, 'stale edit evidence')
        ensure(d.get('engine') == 'ppt-master' and d.get('mode') == 'roundtrip', 'wrong edit engine/mode')
        for key in ('guard_log','quality_log','export_log','delivery_log','readback'):
            ensure(key in d and Path(d[key]['path']).is_file() and sha(d[key]['path']) == d[key]['sha256'] and d[key].get('exit_code') == 0,
                   'missing/stale engine evidence: '+key)
        ensure(d.get('quality_gate') == 'PASS' and d.get('delivery_gate') == 'PASS', 'engine gates not PASS')
        delivery = read(d['delivery_log']['path'])
        ensure(delivery.get('schema') == 'ppt-master.pptx-delivery-check.v1' and
               delivery.get('status') in ('passed','passed-with-advisories') and delivery.get('errors') == [],
               'upstream delivery report failed or unsupported')
        ensure(not delivery.get('advisories') or d.get('advisory_review'), 'delivery advisories not reviewed')
        export_text = Path(d['export_log']['path']).read_text(encoding='utf-8')
        ensure('Round-trip export summary:' in export_text, 'missing roundtrip export receipt')
        validate_mapping(get('content_mapping.json'), get('reference_manifest.json'), inspect(candidate))
    elif stage == 'structural':
        result = inspect(candidate)
        ensure(get('result_manifest.json') == result, 'stale result manifest')
        actual = compare(get('reference_manifest.json'), result, get('content_mapping.json'))
        ensure(actual['status'] == 'PASS' and get('structural_diff.json') == actual, 'structural validation failed')
    elif stage == 'integrity':
        actual = validate(candidate)
        ensure(actual['status'] == 'PASS' and get('package_integrity.json') == actual, 'integrity validation failed')
    elif stage == 'render':
        d, plan = get('render_evidence.json'), get('region_plan.json')
        ensure(d.get('artifact_sha256') == h and plan.get('artifact_sha256') == h, 'stale render')
        ensure(d.get('renderer') and d.get('command') and d.get('exit_code') == 0, 'missing render execution record')
        ensure(sha(d['log']['path']) == d['log']['sha256'], 'render log changed')
        ensure(len(plan.get('slides', [])) == len(inspect(candidate)['slides']), 'render slide coverage mismatch')
        ensure([s['slide'] for s in plan['slides']] == list(range(1, len(plan['slides'])+1)), 'render roster invalid')
        actual_regions = []
        for slide in plan['slides']:
            ensure(sha(slide['image']) == slide['image_sha256'], 'render image changed')
            actual_regions.extend({'slide':slide['slide'], **r} for r in slide['regions'])
        ensure(actual_regions == get('content_mapping.json')['regions'], 'QA region plan changed after lock')
    elif stage == 'visual':
        from PIL import Image, ImageChops
        d, plan = get('visual_qa.json'), get('region_plan.json')
        ensure(d.get('status') == 'PASS' and d.get('artifact_sha256') == h, 'visual QA not PASS/current')
        ensure(d.get('region_plan_sha256') == digest(plan), 'visual QA region plan mismatch')
        expected = {r['id']: (s,r) for s in plan['slides'] for r in s['regions']}
        rows = d.get('regions', [])
        ensure(len(expected) == len(rows) and {r['id'] for r in rows} == set(expected), 'missing/duplicate QA regions')
        for row in rows:
            s, r = expected[row['id']]
            ensure(row['status'] == 'PASS' and row.get('reviewer') and row.get('notes'), 'unreviewed region')
            ensure(set(row.get('checks', {})) == set(CHECKS) and all(v == 'PASS' for v in row['checks'].values()),
                   'incomplete visual checks')
            ensure(row['box'] == r['box'] and row['slide'] == s['slide'], 'QA region identity changed')
            ensure(sha(row['image']) == row['image_sha256'] and sha(s['image']) == row['source_sha256'], 'stale QA image')
            with Image.open(s['image']) as image, Image.open(row['image']) as crop:
                x0,y0,x1,y1 = r['box']
                ensure(0 <= x0 < x1 <= image.width and 0 <= y0 < y1 <= image.height, 'QA bounds invalid')
                if r.get('full_slide'):
                    ensure(r['box'] == [0,0,image.width,image.height], 'full slide region is not full image')
                ensure(image.crop(tuple(r['box'])).size == crop.size and
                       ImageChops.difference(image.crop(tuple(r['box'])).convert('RGB'), crop.convert('RGB')).getbbox() is None,
                       'QA crop is not derived from render')


def check(work, source, candidate, state):
    ensure(state['source_sha256'] == sha(source), 'source changed; start a new run')
    for event in state['events']:
        for name, expected in event['files'].items():
            ensure(sha(work/name) == expected, 'evidence changed; invalidate from '+event['stage'])
        if event.get('candidate_sha256'):
            ensure(sha(candidate) == event['candidate_sha256'], 'candidate changed; invalidate from edit')
        verify_stage(event['stage'], work, source, candidate)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('action', choices=['init','advance','invalidate','finalize'])
    p.add_argument('--work', required=True); p.add_argument('--source', required=True)
    p.add_argument('--candidate', required=True); p.add_argument('--stage', choices=STAGES)
    p.add_argument('--reason'); a = p.parse_args()
    work = Path(a.work).resolve(); source = Path(a.source).resolve(); candidate = Path(a.candidate).resolve()
    work.mkdir(parents=True, exist_ok=True); sp = work/'gate_state.json'
    try:
        ensure(source != candidate, 'candidate must not overwrite source')
        if a.action == 'init':
            ensure(not sp.exists(), 'run already initialized')
            state = {'schema':'kit.run.v1', 'source_sha256':sha(source), 'events':[], 'invalidations':[]}
        else:
            state = read(sp)
            if a.action == 'invalidate':
                ensure(a.stage and a.reason, 'stage and reason required')
                state['events'] = [e for e in state['events'] if STAGES.index(e['stage']) < STAGES.index(a.stage)]
                state['invalidations'].append({'stage':a.stage,'reason':a.reason})
                (work/'final_receipt.json').unlink(missing_ok=True)
            else:
                check(work, source, candidate, state)
                if a.action == 'advance':
                    ensure(len(state['events']) < len(STAGES), 'all gates already recorded')
                    stage = STAGES[len(state['events'])]
                    ensure(a.stage == stage, 'next required stage: '+stage)
                    verify_stage(stage, work, source, candidate)
                    state['events'].append({'stage':stage, 'status':'PASS',
                        'time':datetime.now(timezone.utc).isoformat(),
                        'files':{n:sha(work/n) for n in FILES[stage]},
                        'candidate_sha256':sha(candidate) if STAGES.index(stage) >= 5 else None})
                elif a.action == 'finalize':
                    ensure(len(state['events']) == len(STAGES), 'incomplete gates')
                    receipt = {'schema':'kit.receipt.v1','status':'PASS','artifact_sha256':sha(candidate),
                               'source_sha256':sha(source),'gates':state['events'],
                               'limitation':'Local evidence consistency, not independent or tamper-proof attestation.'}
                    return emit(work/'final_receipt.json', receipt)
        write(sp, state)
        print('PASS: '+a.action + (' '+a.stage if a.stage else '')); return 0
    except Exception as e:
        if a.action == 'finalize':
            return cli_error(work/'final_receipt.json', e)
        print('FAIL: '+str(e)); return 1

if __name__ == '__main__':
    raise SystemExit(main())
