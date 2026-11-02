"""Prepare bounded images; record actual text reports. Does not invoke vision tools."""
import argparse
from pathlib import Path
import re
from common import read, write, sha, digest, cli_error
from render_regions import required_checks

TOOLS = ('look_at', 'call_omo_agent:multimodal-looker')


def require(condition, message):
    if not condition:
        raise ValueError(message)


def plate(reference_image, result_image, box, side):
    """A/B contact image, one same-coordinate region. No stretching or upscaling."""
    from PIL import Image, ImageOps, ImageDraw
    require(256 <= side <= 1536, 'max side must be between 256 and 1536; no safe context limit is assumed')
    with Image.open(reference_image) as a, Image.open(result_image) as b:
        require(a.size == b.size, 'reference/result renders require identical canvas dimensions')
        require(len(box) == 4 and all(isinstance(v, int) for v in box), 'integer crop box required')
        x0,y0,x1,y1 = box
        require(0 <= x0 < x1 <= a.width and 0 <= y0 < y1 <= a.height, 'crop box outside render')
        crops = [a.crop(tuple(box)).convert('RGB'), b.crop(tuple(box)).convert('RGB')]
    # Both width and height are bounded. Header labels explain reference/candidate.
    panel_w, panel_h = (side-12)//2, side-24
    thumb = [ImageOps.contain(im, (panel_w, panel_h), Image.Resampling.LANCZOS)
             if im.width > panel_w or im.height > panel_h else im for im in crops]
    height = max(im.height for im in thumb)+24
    canvas = Image.new('RGB', (2*panel_w+12, height), 'white')
    draw = ImageDraw.Draw(canvas)
    for i, (label, im) in enumerate(zip(('A: REFERENCE', 'B: CANDIDATE'), thumb)):
        x = i*(panel_w+12)
        draw.text((x+2,2), label, fill='black')
        canvas.paste(im, (x+(panel_w-im.width)//2, 24))
    return canvas


def verify_request(req, qa, mapping):
    require(req['artifact_sha256'] == qa['artifact_sha256'], 'request candidate changed')
    require(req['region_plan_sha256'] == qa['region_plan_sha256'], 'request region plan changed')
    require(req['mapping_sha256'] == digest(mapping), 'request mapping changed')
    require(req['reference_sha256'] == mapping['reference_sha256'], 'request reference changed')
    row = next((r for r in qa['regions'] if r['id'] == req['region_id']), None)
    require(row and row['slide'] == req['slide'] and row['box'] == req['box'], 'request region changed')
    require(row['image_sha256'] == req['candidate_crop_sha256'] and sha(row['image']) == row['image_sha256'], 'crop changed')
    for item in req['inputs']:
        require(sha(item['path']) == item['sha256'], 'review input changed')
    from PIL import Image, ImageChops
    expected = plate(req['inputs'][0]['path'], req['inputs'][1]['path'], req['box'], req['max_side'])
    with Image.open(req['inputs'][2]['path']) as actual:
        require(actual.size == expected.size and ImageChops.difference(actual.convert('RGB'), expected).getbbox() is None,
                'review image is not derived from locked renders')
    return row


def prepare(plan, reference, qa, mapping, output, max_side=1024):
    require(qa.get('schema') == 'kit.visual.v2', 'recreate QA crops using current render_regions.py')
    require(qa['artifact_sha256'] == plan['artifact_sha256'] and qa['region_plan_sha256'] == digest(plan), 'stale QA plan')
    require(reference['artifact_sha256'] == mapping['reference_sha256'], 'wrong reference render roster')
    require(mapping.get('locked') is True, 'mapping not locked')
    refs = {s['slide']: s for s in reference['slides']}
    require(len(refs) == len(reference['slides']) == len(plan['slides']), 'reference render roster mismatch')
    dest = Path(output).resolve(); dest.mkdir(parents=True, exist_ok=True)
    requests = []
    rows = {r['id']:r for r in qa['regions']}
    require(len(rows) == len(qa['regions']), 'duplicate QA rows')
    for slide in plan['slides']:
        ref = refs[slide['slide']]
        for record in (ref, slide):
            require(sha(record['image']) == record['image_sha256'], 'render hash changed')
        for region in slide['regions']:
            rid = region['id']
            require(re.fullmatch(r'[A-Za-z0-9_-]+', rid), 'unsafe region id')
            require(rid in rows and rows[rid]['box'] == region['box'], 'missing/stale region crop')
            side = min(max_side,768) if region.get('full_slide') else max_side
            image_path = dest/(rid+'-review.png')
            plate(ref['image'], slide['image'], region['box'], side).save(image_path)
            slots = [s for s in mapping['slots'] if s['slide'] == slide['slide'] and s['target'] in region.get('targets', [])]
            request = {'schema':'kit.review-request.v1', 'region_id':rid,'slide':slide['slide'],
                       'artifact_sha256':qa['artifact_sha256'], 'reference_sha256':reference['artifact_sha256'],
                       'region_plan_sha256':digest(plan), 'mapping_sha256':digest(mapping),
                       'candidate_crop_sha256':rows[rid]['image_sha256'], 'box':region['box'],
                       'max_side':side, 'scope':'overview' if region.get('full_slide') else 'detail',
                       'checks':required_checks(region),
                       'expected_text':[s['expected_text'] for s in slots if s.get('expected_text')],
                       'slot_roles':[{k:s[k] for k in ('target','role','content_kind')} for s in slots],
                       'inputs':[{'role':role,'path':str(Path(path).resolve()),'sha256':sha(path)} for role,path in
                                 [('reference_render',ref['image']),('candidate_render',slide['image']),('review_plate',image_path)]],
                       'image_path':str(image_path),
                       'instruction': 'Inspect this one image only: A is design reference, B is candidate. '
                                      'Use expected_text as the intended new wording; do not flag intentional copy changes. '
                                      'Check each listed item. Return JSON text only with region_id, '
                                      'checks (each PASS/FAIL/NOT REVIEWED), unreadable (boolean), notes (specific observations). '
                                      'If unreadable or uncertain, use NOT REVIEWED; do not invent evidence. '
                                      'Overview checks cover layout only; never infer tiny text quality from the preview.'}
            verify_request(request, qa, mapping)
            path = dest/(rid+'-request.json'); write(path, request)
            requests.append({'region_id':rid,'scope':request['scope'],'request':str(path),'image':str(image_path)})
    # Review details first; overview only aggregates overall composition.
    return {'schema':'kit.review-queue.v1','status':'NOT REVIEWED',
            'requests':sorted(requests,key=lambda r:r['scope']=='overview'),
            'dispatch':'one image per call; serial; do not paste base64 or all raw reports into GLM context'}


def report_values(report, req):
    require(report.get('region_id') == req['region_id'], 'wrong report region')
    checks = report.get('checks', {})
    require(set(checks) == set(req['checks']) and all(v in ('PASS','FAIL','NOT REVIEWED') for v in checks.values()), 'missing/invalid report checks')
    require(type(report.get('unreadable')) is bool and isinstance(report.get('notes'),str) and report['notes'].strip(), 'missing readability/observations')
    if report['unreadable']:
        checks = {key: 'NOT REVIEWED' for key in checks}
    status = 'FAIL' if 'FAIL' in checks.values() else ('NOT REVIEWED' if 'NOT REVIEWED' in checks.values() else 'PASS')
    return checks,status


def record(request_path, report_path, qa, mapping, tool, call_id):
    require(tool in TOOLS and call_id.strip(), 'actual tool and call id required')
    req, report = read(request_path), read(report_path)
    row = verify_request(req,qa,mapping)
    checks,status = report_values(report,req)
    row.update(checks=checks,status=status,reviewer=tool,notes=report['notes'],
               review_evidence={'request':{'path':str(Path(request_path).resolve()),'sha256':sha(request_path)},
                                'report':{'path':str(Path(report_path).resolve()),'sha256':sha(report_path)},
                                'tool':tool,'call_id':call_id})
    statuses = [r['status'] for r in qa['regions']]
    qa['status'] = 'FAIL' if 'FAIL' in statuses else ('PASS' if all(s=='PASS' for s in statuses) else 'NOT REVIEWED')
    return qa


def verify_evidence(row, qa, mapping):
    evidence = row.get('review_evidence', {})
    require(evidence.get('tool') == row['reviewer'] and evidence.get('call_id'), 'missing vision invocation identity')
    for k in ('request','report'):
        require(sha(evidence[k]['path']) == evidence[k]['sha256'], 'vision evidence changed')
    req, report = read(evidence['request']['path']),read(evidence['report']['path'])
    verify_request(req,qa,mapping)
    checks,status = report_values(report,req)
    require(row['checks'] == checks and row['status'] == status and row['notes'] == report['notes'], 'QA row diverges from actual report')


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('action',choices=['prepare','record']); p.add_argument('--qa',required=True)
    p.add_argument('--mapping',required=True); p.add_argument('-o','--output',required=True)
    p.add_argument('--plan');p.add_argument('--reference-renders');p.add_argument('--output-dir')
    p.add_argument('--max-side',type=int,default=1024)
    p.add_argument('--request');p.add_argument('--report');p.add_argument('--tool',choices=TOOLS);p.add_argument('--call-id')
    a=p.parse_args()
    try:
        if a.action=='prepare':
            require(a.plan and a.reference_renders and a.output_dir,'plan, reference-renders and output-dir required')
            value=prepare(read(a.plan),read(a.reference_renders),read(a.qa),read(a.mapping),a.output_dir,a.max_side)
        else:
            require(a.request and a.report and a.tool and a.call_id,'request, report, tool and call-id required')
            value=record(a.request,a.report,read(a.qa),read(a.mapping),a.tool,a.call_id)
        write(a.output,value);print('Saved: '+a.output+'; status='+value['status'])
        return 1 if value['status']=='FAIL' else 0
    except Exception as e:
        # Never overwrite a QA document with a malformed error envelope.
        print(type(e).__name__+': '+str(e));return 1

if __name__=='__main__':
    raise SystemExit(main())
