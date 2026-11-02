"""Compare unchanged pixels using pre-locked masks and matched render environments."""
import argparse
from pathlib import Path
from common import read, sha, digest, emit, cli_error


def compare_pixels(reference, result, mapping):
    from PIL import Image, ImageChops, ImageDraw
    errors, pages = [], []
    if reference.get('artifact_sha256') != mapping.get('reference_sha256'):
        errors.append('reference render does not match mapping')
    if not reference.get('renderer') or reference.get('renderer') != result.get('renderer'):
        errors.append('renderer mismatch or unknown')
    if not reference.get('environment') or reference.get('environment') != result.get('environment'):
        errors.append('render environment/font fingerprint mismatch or unknown')
    refs=reference.get('slides',[]); outs=result.get('slides',[])
    if not refs or [r['slide'] for r in refs] != list(range(1,len(refs)+1)) or [r['slide'] for r in refs] != [r['slide'] for r in outs]:
        errors.append('render roster missing, unordered, duplicated or changed')
    policy=mapping.get('pixel_policy',{})
    tolerance=policy.get('channel_tolerance',0)
    max_fraction=policy.get('max_mask_fraction',0.65)
    if type(tolerance) is not int or not 0 <= tolerance <= 5 or type(max_fraction) not in (int,float) or not 0 <= max_fraction <= 0.8:
        raise ValueError('invalid pre-locked pixel policy')
    masks=mapping.get('pixel_masks',[])
    targets={(s['slide'],s['target']) for s in mapping['slots']}
    if any(m.get('slide') not in range(1,len(refs)+1) for m in masks):
        raise ValueError('mask refers to unknown slide')
    for a,b in zip(refs,outs):
        for r in (a,b):
            if sha(r['image']) != r['image_sha256']:
                errors.append('render bytes changed: '+r['image'])
        with Image.open(a['image']) as aa,Image.open(b['image']) as bb:
            if aa.size != bb.size:
                errors.append('render canvas size differs');continue
            aa,bb=aa.convert('RGB'),bb.convert('RGB')
            mask=Image.new('L',aa.size,0);draw=ImageDraw.Draw(mask)
            for m in masks:
                if m['slide'] != a['slide']:
                    continue
                if not m.get('reason') or not m.get('targets') or any((m['slide'],k) not in targets for k in m['targets']):
                    raise ValueError('mask requires reason and authorized content targets')
                box=m['box']
                if len(box)!=4 or not all(type(v) is int for v in box):
                    raise ValueError('mask integer box required')
                x0,y0,x1,y1=box
                if not 0 <= x0 < x1 <= aa.width or not 0 <= y0 < y1 <= aa.height:
                    raise ValueError('invalid mask bounds')
                # Pillow rectangles include endpoints; convert half-open box explicitly.
                draw.rectangle([x0,y0,x1-1,y1-1],fill=255)
            masked=mask.histogram()[255]; total=aa.width*aa.height
            if masked/total > max_fraction:
                errors.append('mask hides too much of slide '+str(a['slide']))
            diff=ImageChops.difference(aa,bb)
            channels=diff.split(); maximum=ImageChops.lighter(ImageChops.lighter(channels[0],channels[1]),channels[2])
            changed=maximum.point(lambda v:255 if v>tolerance else 0)
            outside=ImageChops.subtract(changed,mask)
            count=outside.histogram()[255]
            if count:
                errors.append('unexpected pixel change on slide '+str(a['slide']))
            pages.append({'slide':a['slide'],'unexpected_pixels':count,'unexpected_bbox':outside.getbbox(),
                          'masked_fraction':masked/total,'checked_pixels':total-masked})
    return {'schema':'kit.pixel-diff.v1','status':'FAIL' if errors else 'PASS',
            'reference_sha256':reference.get('artifact_sha256'),'artifact_sha256':result.get('artifact_sha256'),
            'mapping_sha256':digest(mapping),'errors':errors,'pages':pages,
            'limitation':'Masked edits still require content/layout/visual review. Mask correctness is a planning responsibility.'}


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('reference');p.add_argument('result');p.add_argument('--mapping',required=True)
    p.add_argument('-o','--output',required=True);a=p.parse_args()
    try:
        return emit(a.output,compare_pixels(read(a.reference),read(a.result),read(a.mapping)))
    except Exception as e:
        return cli_error(a.output,e)

if __name__=='__main__':
    raise SystemExit(main())
