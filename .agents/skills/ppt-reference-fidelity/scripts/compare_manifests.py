"""Exact JSON-pointer allowlist; no wildcard or blanket ignore fields."""
import argparse
from common import read, emit, cli_error, digest


def differences(a, b, path=''):
    if type(a) != type(b):
        return [{'path': path, 'before': a, 'after': b}]
    if isinstance(a, dict):
        out = []
        for k in sorted(a.keys() | b.keys()):
            p = path + '/' + k.replace('~', '~0').replace('/', '~1')
            if k not in a or k not in b:
                out.append({'path': p, 'before': a.get(k), 'after': b.get(k)})
            else:
                out.extend(differences(a[k], b[k], p))
        return out
    if isinstance(a, list):
        if len(a) != len(b):
            return [{'path': path, 'before': a, 'after': b}]
        return [d for i, (x, y) in enumerate(zip(a, b)) for d in differences(x, y, path+'/'+str(i))]
    return [] if a == b else [{'path': path, 'before': a, 'after': b}]


def compare(a, b, mapping):
    if a.get('schema') != 'kit.manifest.v1' or b.get('schema') != 'kit.manifest.v1':
        raise ValueError('unsupported manifest schema')
    aa, bb = dict(a), dict(b)
    aa.pop('artifact_sha256'); bb.pop('artifact_sha256')
    changes = differences(aa, bb)
    allowed = mapping.get('allowed_changes', [])
    for item in allowed:
        if not item.get('reason') or not item.get('path') or 'before' not in item or 'after' not in item:
            raise ValueError('allowlist requires path, reason, exact before and after')
    unexpected = [d for d in changes if not any(all(d[k] == x.get(k) for k in ('path','before','after')) for x in allowed)]
    return {'schema': 'kit.structural.v1', 'status': 'FAIL' if unexpected else 'PASS',
            'reference_sha256': a['artifact_sha256'], 'artifact_sha256': b['artifact_sha256'],
            'mapping_sha256': digest(mapping), 'changes': changes, 'unexpected': unexpected}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('reference'); p.add_argument('result'); p.add_argument('--mapping', required=True)
    p.add_argument('-o', '--output', required=True); a = p.parse_args()
    try:
        return emit(a.output, compare(read(a.reference), read(a.result), read(a.mapping)))
    except Exception as e:
        return cli_error(a.output, e)

if __name__ == '__main__':
    raise SystemExit(main())
