"""Read-only recursive manifest. Coordinates are raw local EMUs, never guessed."""
import argparse
import copy
import zipfile
from common import NS, R, xml, tree, relationships, resolve, slide_parts, sha, emit, cli_error
from validate_pptx import validate

KINDS = {'sp', 'pic', 'grpSp', 'graphicFrame', 'cxnSp', 'contentPart'}


def inspect(path):
    integrity = validate(path)
    if integrity['status'] != 'PASS':
        raise ValueError('integrity prerequisite failed: ' + '; '.join(integrity['errors']))
    with zipfile.ZipFile(path) as z:
        slides = []
        for part in slide_parts(z):
            root = xml(z.read(part)); rels = relationships(z, part)
            shapes = []
            def walk(parent, prefix=''):
                for order, node in enumerate(parent):
                    kind = node.tag.rsplit('}', 1)[-1]
                    if kind not in KINDS:
                        continue
                    cnv = node.find('./p:nvGrpSpPr/p:cNvPr', NS) if kind == 'grpSp' else next(
                        iter(node.findall('./*/p:cNvPr', NS)), None)
                    sid = cnv.get('id') if cnv is not None else 'missing'
                    key = prefix + 'shape-' + sid
                    local = copy.deepcopy(node)
                    if kind == 'grpSp':
                        for c in list(local):
                            if c.tag.rsplit('}', 1)[-1] in KINDS:
                                local.remove(c)
                    texts = [n.text or '' for n in local.findall('.//a:t', NS)]
                    # Style includes all text/run/paragraph attributes but no actual strings.
                    style = copy.deepcopy(local)
                    for n in style.findall('.//a:t', NS):
                        n.text = '__CONTENT__'
                    images = []
                    for n in local.findall('.//a:blip', NS):
                        for attr in ('embed', 'link'):
                            rid = n.get('{'+R+'}'+attr)
                            if rid:
                                rel = rels[rid]; external = rel.get('TargetMode') == 'External'
                                target = rel['Target'] if external else resolve(part, rel['Target'])
                                images.append({'id': rid, 'target': target, 'external': external,
                                               'sha256': None if external else __import__('hashlib').sha256(z.read(target)).hexdigest()})
                    xforms = [tree(n) for n in local.iter() if n.tag.rsplit('}', 1)[-1] == 'xfrm']
                    shapes.append({'key': key, 'kind': kind, 'parent': prefix.rstrip('/'),
                                   'z_order': order, 'name': cnv.get('name') if cnv is not None else None,
                                   'text': texts, 'images': images, 'transforms_local_emu': xforms,
                                   'style_xml': tree(style)})
                    if kind == 'grpSp':
                        walk(node, key + '/')
            sp = root.find('p:cSld/p:spTree', NS)
            if sp is None:
                raise ValueError('missing shape tree: ' + part)
            walk(sp)
            shell = copy.deepcopy(root)
            st = shell.find('p:cSld/p:spTree', NS)
            for node in list(st):
                if node.tag.rsplit('}', 1)[-1] in KINDS:
                    st.remove(node)
            slides.append({'part': part, 'shapes': shapes, 'shape_count': len(shapes),
                           'shell_xml': tree(shell), 'relationships': rels})
        pres = xml(z.read('ppt/presentation.xml'))
        size = pres.find('p:sldSz', NS)
        # Hash themes/layouts/masters and all non-slide payloads; content edits must
        # explicitly whitelist intended media/notes changes. Catch inherited drift too.
        slidefiles = {s['part'] for s in slides}
        backing = {n: __import__('hashlib').sha256(z.read(n)).hexdigest() for n in sorted(z.namelist())
                   if not n.endswith('/') and n not in slidefiles and '/slides/_rels/' not in n}
    return {'schema': 'kit.manifest.v1', 'status': 'PASS', 'artifact_sha256': sha(path),
            'slide_size': dict(size.attrib) if size is not None else None,
            'slides': slides, 'backing_parts': backing,
            'limitations': ['style_xml records explicit XML, not computed theme fonts/effects',
                            'group transforms remain local; use rendered regions for visual QA',
                            'no text-fit, content truth or visual quality inference']}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('pptx'); p.add_argument('-o', '--output', required=True)
    a = p.parse_args()
    try:
        return emit(a.output, inspect(a.pptx))
    except Exception as e:
        return cli_error(a.output, e)

if __name__ == '__main__':
    raise SystemExit(main())
