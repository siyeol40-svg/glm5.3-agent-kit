"""Shared stdlib I/O and OOXML helpers. No package extraction or source mutation."""
import hashlib
import json
from pathlib import Path
import posixpath
import sys
import xml.etree.ElementTree as ET
from urllib.parse import unquote, urlsplit
import zipfile

NS = {'p': 'http://schemas.openxmlformats.org/presentationml/2006/main',
      'a': 'http://schemas.openxmlformats.org/drawingml/2006/main',
      'r': 'http://schemas.openxmlformats.org/officeDocument/2006/relationships',
      'pr': 'http://schemas.openxmlformats.org/package/2006/relationships'}
R = NS['r']

def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, ensure_ascii=False).encode()).hexdigest()

def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8'))

def write(path, value):
    p = Path(path)
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')

def emit(path, value):
    write(path, value)
    print(json.dumps({'status': value.get('status'), 'output': str(path)}, ensure_ascii=False))
    return 0 if value.get('status') == 'PASS' else 1

def xml(data):
    if b'<!DOCTYPE' in data.upper() or b'<!ENTITY' in data.upper():
        raise ValueError('DTD/entities are not accepted')
    return ET.fromstring(data)

def tree(node):
    """Namespace-prefix-independent semantic XML; preserve text and ordered children."""
    return {'tag': node.tag, 'attrs': dict(sorted(node.attrib.items())),
            'text': node.text if node.text and node.text.strip() else '',
            'children': [tree(c) for c in node]}

def owner_of(relpart):
    if relpart == '_rels/.rels':
        return ''
    parent, name = posixpath.split(relpart)
    if not parent.endswith('/_rels') or not name.endswith('.rels'):
        raise ValueError('invalid relationship part: ' + relpart)
    return posixpath.join(parent[:-6], name[:-5])

def resolve(owner, target):
    u = urlsplit(target)
    if u.scheme or u.netloc or u.query or '\\' in target:
        raise ValueError('invalid internal target: ' + target)
    raw = unquote(u.path)
    part = posixpath.normpath(raw.lstrip('/') if raw.startswith('/') else
                             posixpath.join(posixpath.dirname(owner), raw))
    if part in ('', '.', '..') or part.startswith('../') or '\\' in part:
        raise ValueError('target escapes package: ' + target)
    return part

def relpath(owner):
    return posixpath.join(posixpath.dirname(owner), '_rels', posixpath.basename(owner) + '.rels')

def relationships(z, owner):
    rp = relpath(owner) if owner else '_rels/.rels'
    if rp not in z.namelist():
        return {}
    return {n.get('Id'): dict(n.attrib) for n in xml(z.read(rp))}

def slide_parts(z):
    root = xml(z.read('ppt/presentation.xml'))
    rels = relationships(z, 'ppt/presentation.xml')
    return [resolve('ppt/presentation.xml', rels[n.get('{'+R+'}id')]['Target'])
            for n in root.findall('p:sldIdLst/p:sldId', NS)]

def cli_error(output, exc):
    return emit(output, {'status': 'FAIL', 'errors': [type(exc).__name__ + ': ' + str(exc)]})
