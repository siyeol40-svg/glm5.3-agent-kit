"""Validate native PowerPoint measurements, not guessed typography."""
import argparse
import math
from common import read, sha, emit, cli_error


def normalized(text):
    return ''.join(text.split())


def check_layout(snapshot, manifest, candidate):
    errors, unsupported = [], []
    if snapshot.get('schema') != 'kit.powerpoint-snapshot.v1' or snapshot.get('status') != 'PASS':
        errors.append('PowerPoint snapshot is unavailable or incomplete')
    if snapshot.get('artifact_sha256') != sha(candidate) or manifest.get('artifact_sha256') != sha(candidate):
        errors.append('stale candidate/snapshot/manifest')
    if snapshot.get('errors'):
        errors.extend(snapshot['errors'])
    expected = {(i+1,s['key']):s for i,slide in enumerate(manifest['slides']) for s in slide['shapes'] if s['text']}
    rows = snapshot.get('text_shapes',[])
    measured = {(s['slide'],s['key']):s for s in rows}
    if len(measured) != len(rows) or set(measured) != set(expected):
        errors.append('native text shape coverage differs from recursive manifest')
    for key, item in measured.items():
        if key not in expected:
            continue
        label = str(key)
        if not item.get('supported'):
            unsupported.append(label+': '+item.get('reason','unsupported native text geometry')); continue
        if normalized(item.get('text','')) != normalized(''.join(expected[key]['text'])):
            errors.append(label+': native readback text differs')
        inner, bounds = item.get('inner_box',[]),item.get('text_bounds',[])
        if len(inner) != 4 or len(bounds) != 4 or not all(type(x) in (int,float) and math.isfinite(x) for x in inner+bounds):
            errors.append(label+': invalid measurement'); continue
        if inner[2] <= 0 or inner[3] <= 0 or bounds[2] <= 0 or bounds[3] <= 0:
            errors.append(label+': nonpositive measurement');continue
        # A small geometric tolerance in points is fixed here, never learned from failures.
        eps = 0.5
        if (bounds[0] < inner[0]-eps or bounds[1] < inner[1]-eps or
            bounds[0]+bounds[2] > inner[0]+inner[2]+eps or bounds[1]+bounds[3] > inner[1]+inner[3]+eps):
            errors.append(label+': text bounding box exceeds inner frame')
        if item.get('auto_size') == 2:
            unsupported.append(label+': automatic text shrinking requires separate effective-font verification')
        if not item.get('font_available'):
            unsupported.append(label+': declared font availability not established')
    if not snapshot.get('renderer') or not snapshot.get('environment'):
        errors.append('missing renderer/environment fingerprint')
    return {'schema':'kit.layout-check.v1','status':'FAIL' if errors else ('NOT REVIEWED' if unsupported else 'PASS'),
            'artifact_sha256':sha(candidate),'errors':errors,'unsupported':unsupported,
            'checked_text_shapes':len(measured),'tolerance_pt':0.5,
            'limitation':'Text bounds do not prove absence of occlusion, effects clipping, or visual/semantic defects.'}


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('snapshot');p.add_argument('--manifest',required=True);p.add_argument('--candidate',required=True)
    p.add_argument('-o','--output',required=True);a=p.parse_args()
    try:
        return emit(a.output,check_layout(read(a.snapshot),read(a.manifest),a.candidate))
    except Exception as e:
        return cli_error(a.output,e)

if __name__=='__main__':
    raise SystemExit(main())
