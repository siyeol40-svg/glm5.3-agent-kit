"""Conservative OPC integrity checks; not an Office conformance validator."""
import argparse
from collections import Counter, deque
from pathlib import Path
import posixpath
import zipfile
from common import NS, R, xml, owner_of, resolve, relationships, sha, emit, cli_error


def validate(path):
    errors, warnings, external = [], [], []
    with zipfile.ZipFile(path) as z:
        names = z.namelist()
        files = {n for n in names if not n.endswith('/')}
        for n, count in Counter(names).items():
            if count > 1:
                errors.append('duplicate ZIP entry: ' + n)
            if n.startswith('/') or '\\' in n or any(p in ('.', '..') for p in n.split('/')):
                errors.append('unsafe package path: ' + n)
        bad = z.testzip()
        if bad:
            errors.append('CRC failure: ' + bad)
        roots = {}
        for n in files:
            if n.endswith(('.xml', '.rels')) or n == '[Content_Types].xml':
                try:
                    roots[n] = xml(z.read(n))
                except Exception as e:
                    errors.append('XML parse failure: ' + n + ': ' + str(e))
        for n in ('[Content_Types].xml', '_rels/.rels', 'ppt/presentation.xml'):
            if n not in roots:
                errors.append('missing required part: ' + n)
        ct = roots.get('[Content_Types].xml')
        if ct is not None:
            defaults = {c.get('Extension') for c in ct if c.tag.endswith('}Default')}
            overrides = {c.get('PartName', '').lstrip('/') for c in ct if c.tag.endswith('}Override')}
            for n in overrides - files:
                errors.append('content type targets missing part: ' + n)
            for n in files - {'[Content_Types].xml'}:
                if n not in overrides and n.rsplit('.', 1)[-1] not in defaults:
                    errors.append('missing content type: ' + n)
        graph, relmaps = {}, {}
        for rp, root in roots.items():
            if not rp.endswith('.rels'):
                continue
            try:
                owner = owner_of(rp)
            except ValueError as e:
                errors.append(str(e)); continue
            if owner and owner not in files:
                errors.append('relationship owner missing: ' + owner)
            ids, rels = set(), {}
            for rel in root:
                rid, typ, target = rel.get('Id'), rel.get('Type'), rel.get('Target')
                if not rid or not typ or not target or rid in ids:
                    errors.append('duplicate/invalid relationship: ' + rp + ':' + str(rid))
                    continue
                ids.add(rid); rels[rid] = rel.attrib
                mode = rel.get('TargetMode', 'Internal')
                if mode == 'External':
                    external.append({'owner': owner, 'id': rid, 'target': target})
                    continue
                if mode != 'Internal':
                    errors.append('invalid TargetMode: ' + rp); continue
                try:
                    part = resolve(owner, target)
                except ValueError as e:
                    errors.append(str(e)); continue
                graph.setdefault(owner, set()).add(part)
                if part not in files:
                    errors.append('dangling relationship: ' + rp + ' -> ' + part)
            relmaps[owner] = rels
        for owner, root in roots.items():
            if owner.startswith('ppt/slides/') and owner.endswith('.xml') and '/_rels/' not in owner:
                shape_ids = [n.get('id') for n in root.findall('.//p:cNvPr', NS)]
                if any(not sid or not sid.isdigit() for sid in shape_ids) or len(shape_ids) != len(set(shape_ids)):
                    errors.append('duplicate/invalid shape id: ' + owner)
            if owner.endswith('.rels'):
                continue
            for node in root.iter():
                for key, rid in node.attrib.items():
                    if key.startswith('{'+R+'}') and rid not in relmaps.get(owner, {}):
                        errors.append('unresolved relationship id: ' + owner + ':' + rid)
        office = [r for r in relmaps.get('', {}).values() if r.get('Type', '').endswith('/officeDocument')]
        if len(office) != 1 or office[0].get('TargetMode', 'Internal') != 'Internal':
            errors.append('package requires one internal officeDocument relationship')
        elif resolve('', office[0]['Target']) != 'ppt/presentation.xml':
            errors.append('unexpected presentation root')
        presentation = roots.get('ppt/presentation.xml')
        active, ids = [], set()
        if presentation is not None:
            for n in presentation.findall('p:sldIdLst/p:sldId', NS):
                sid = n.get('id')
                if not sid or not sid.isdigit() or not 256 <= int(sid) <= 2147483647 or sid in ids:
                    errors.append('duplicate/invalid slideId: ' + str(sid))
                ids.add(sid)
                rel = relmaps.get('ppt/presentation.xml', {}).get(n.get('{'+R+'}id'), {})
                if not rel.get('Type', '').endswith('/slide') or rel.get('TargetMode', 'Internal') != 'Internal':
                    errors.append('slideId does not resolve to internal slide')
                elif rel.get('Target'):
                    active.append(resolve('ppt/presentation.xml', rel['Target']))
        if not active:
            errors.append('empty slide roster')
        if len(active) != len(set(active)):
            errors.append('multiple slideIds point to same slide part')
        for n in files:
            if n.startswith('ppt/slides/') and n.endswith('.xml') and '/_rels/' not in n and n not in active:
                errors.append('orphan slide: ' + n)
        reachable, queue = set(), deque([''])
        while queue:
            cur = queue.popleft()
            if cur in reachable:
                continue
            reachable.add(cur); queue.extend(graph.get(cur, set()) - reachable)
        for n in files:
            if n.startswith('ppt/notesSlides/') and n.endswith('.xml') and '/_rels/' not in n and n not in reachable:
                errors.append('orphan notes: ' + n)
        # Picture blips must identify an actual image relationship, not merely any rel.
        for n, root in roots.items():
            for blip in root.findall('.//a:blip', NS):
                for key in ('embed', 'link'):
                    rid = blip.get('{'+R+'}'+key)
                    if rid and not relmaps.get(n, {}).get(rid, {}).get('Type', '').endswith('/image'):
                        errors.append('blip has non-image relationship: ' + n + ':' + rid)
        if external:
            warnings.append('External targets were inventoried, not fetched or validated.')
    return {'schema': 'kit.integrity.v1', 'status': 'FAIL' if errors else 'PASS',
            'artifact_sha256': sha(path), 'errors': errors, 'warnings': warnings,
            'external_relationships': external, 'slide_count': len(active)}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('pptx'); p.add_argument('-o', '--output', required=True)
    a = p.parse_args()
    try:
        return emit(a.output, validate(a.pptx))
    except Exception as e:
        return cli_error(a.output, e)

if __name__ == '__main__':
    raise SystemExit(main())
