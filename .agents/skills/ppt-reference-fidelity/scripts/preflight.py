"""Probe actual imports in isolated subprocesses, without installing anything."""
import argparse
import platform
import shutil
import subprocess
import sys
from pathlib import Path
from common import emit, sha, cli_error


def probe(code):
    try:
        r = subprocess.run([sys.executable, '-c', code], capture_output=True, text=True, timeout=15)
        return {'status': 'PASS' if r.returncode == 0 else 'FAIL',
                'detail': (r.stdout + r.stderr)[-3000:]}
    except (OSError, subprocess.TimeoutExpired) as e:
        return {'status': 'FAIL', 'detail': str(e)}


def preflight(master=None, visual_reviewer=None):
    modules = {m: probe('import '+m+'; print(getattr('+m+', "__version__", "stdlib"))')
               for m in ('zipfile', 'xml.etree.ElementTree', 'pptx', 'lxml', 'PIL')}
    executables = {k: shutil.which(k) for k in ('libreoffice', 'soffice', 'pdftoppm', 'powershell', 'pwsh')}
    required = ['attribution_guard.py','pptx_to_svg.py','svg_to_pptx.py',
                'svg_authoring_view.py','svg_quality_checker.py','pptx_delivery_check.py']
    master_files = {}
    if master:
        root = Path(master).resolve()
        for name in required:
            f = root/'scripts'/name
            master_files[name] = {'exists': f.is_file(), 'sha256': sha(f) if f.is_file() else None}
        docs = all((root/p).is_file() for p in ('SKILL.md','workflows/routing.md','workflows/edit-native-pptx.md'))
    else:
        docs = False
    ready = docs and all(x['exists'] for x in master_files.values())
    return {'schema': 'kit.preflight.v1', 'status': 'PASS' if ready else 'FAIL',
            'python': platform.python_version(), 'os': platform.system(),
            'context_budget_reported': 200000,
            'native_probe': str(Path(__file__).with_name('powerpoint_probe.ps1').resolve()), 'imports': modules, 'executables': executables,
            'ppt_master': str(Path(master).resolve()) if master else None, 'master_files': master_files,
            'visual_reviewer': visual_reviewer, 'render_ready': bool(executables['pdftoppm'] and
                   (executables['libreoffice'] or executables['soffice'])),
            'notes': ['PASS means inventory completed with engine files present, not engine execution proven.',
                      'Run the upstream attribution guard before importing. Do not bypass failures.',
                      'Missing optional imports require an explicit alternative path.',
                      'Run powerpoint_probe.ps1 in the actual Windows desktop session; command presence is not COM readiness.',
                      'Image-tool limits differ from the reported total 200000-token context budget.',
                      'No image reviewer means residual visual QA remains NOT REVIEWED.']}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--ppt-master', help='Absolute installed skill directory; never guessed')
    p.add_argument('--visual-reviewer', help='Observed human or image-tool identity; not model branding')
    p.add_argument('-o', '--output', required=True); a = p.parse_args()
    try:
        return emit(a.output, preflight(a.ppt_master, a.visual_reviewer))
    except Exception as e:
        return cli_error(a.output, e)

if __name__ == '__main__':
    raise SystemExit(main())
