"""Crop previously rendered final slides. Never claims rendering or visual PASS."""
import argparse
import math
from pathlib import Path
import re
from common import read, emit, sha, digest, cli_error

CHECKS = ['text_clipping','overflow','overlap','image_crop','alignment','spacing',
          'shadow','border','hierarchy','reference_structure']

OVERVIEW_CHECKS = ['alignment', 'hierarchy', 'reference_structure']

def required_checks(region):
    return OVERVIEW_CHECKS if region.get('full_slide') else CHECKS

def crop_regions(plan, output):
    from PIL import Image
    dest = Path(output).resolve(); dest.mkdir(parents=True, exist_ok=True)
    regions, seen = [], set()
    if not plan.get('slides'):
        raise ValueError('nonempty slides required')
    for slide in plan['slides']:
        if not slide.get('regions'):
            raise ValueError('each slide requires regions, including full-slide')
        source = Path(slide['image']).resolve()
        with Image.open(source) as im:
            w, h = im.size
            full = False
            for r in slide['regions']:
                rid = r['id']
                if not re.fullmatch(r'[a-zA-Z0-9_-]+', rid) or rid in seen:
                    raise ValueError('unsafe/duplicate region id: '+rid)
                seen.add(rid)
                box = r['box']
                if len(box) != 4 or not all(isinstance(v, (int,float)) and math.isfinite(v) for v in box):
                    raise ValueError('invalid crop box')
                x0,y0,x1,y1 = box
                if not (0 <= x0 < x1 <= w and 0 <= y0 < y1 <= h):
                    raise ValueError('crop box outside image')
                full = full or box == [0,0,w,h]
                target = dest/(rid+'.png'); im.crop(tuple(box)).save(target)
                regions.append({'id': rid, 'slide': slide['slide'], 'image': str(target),
                                'image_sha256': sha(target), 'source_image': str(source),
                                'source_sha256': sha(source), 'box': box,
                                'status': 'NOT REVIEWED', 'reviewer': '', 'notes': '',
                                'scope': 'overview' if r.get('full_slide') else 'detail',
                                'checks': {k: 'NOT REVIEWED' for k in required_checks(r)}})
            if not full:
                raise ValueError('each slide requires a full-slide region')
    qa = {'schema': 'kit.visual.v2', 'status': 'NOT REVIEWED',
          'artifact_sha256': plan['artifact_sha256'], 'region_plan_sha256': digest(plan),
          'regions': regions}
    return qa


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('plan'); p.add_argument('--output-dir', required=True)
    p.add_argument('-o', '--output', required=True); a = p.parse_args()
    try:
        qa = crop_regions(read(a.plan), a.output_dir)
        # Successful cropping returns 0, while the QA document remains NOT REVIEWED.
        from common import write
        write(a.output, qa)
        print('Crops created. Visual QA: NOT REVIEWED')
        return 0
    except Exception as e:
        return cli_error(a.output, e)

if __name__ == '__main__':
    raise SystemExit(main())
