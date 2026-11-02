"""Apply an agent-reviewed local migration plan. Never guesses scanner locations."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import re
import sys

KIT=Path(__file__).resolve().parents[1]
SKILL=KIT/'.agents/skills/ppt-reference-fidelity'


def hash_file(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def files(path):
    p=Path(path)
    if p.is_symlink() or any(x.is_symlink() for x in p.rglob('*')):
        raise ValueError('Symlinks are not accepted in a migration path')
    if p.is_file():
        return {'':hash_file(p)}
    return {str(f.relative_to(p)):hash_file(f) for f in sorted(p.rglob('*')) if f.is_file() and '__pycache__' not in f.parts}


def inside(path,parent):
    return path==parent or parent in path.parents


def load_plan(path):
    plan=json.loads(Path(path).read_text(encoding='utf-8'))
    if plan.get('schema')!='kit.bootstrap-plan.v1' or plan.get('conflicts_resolved') is not True or not plan.get('loading_evidence'):
        raise ValueError('Plan requires schema, conflict resolution and actual loading evidence')
    for key in ('project_root','backup_root','skill_destination','local_overlay_file'):
        p=Path(plan[key]).expanduser()
        if p.is_symlink():
            raise ValueError('Symlink plan paths are not accepted')
        if not p.is_absolute():
            raise ValueError(key+' must be an observed absolute path')
        plan[key]=str(p.resolve())
    if not Path(plan['local_overlay_file']).is_file():
        raise ValueError('Reviewed company-only overlay file is required, even if empty')
    agents=plan.get('agents_files',[])
    if not agents:
        raise ValueError('Explicit agent instruction destinations required')
    raw_targets=[Path(s['path']) for s in agents]+[Path(plan['skill_destination'])]+[Path(p) for p in plan.get('disable_skill_dirs',[])]
    if any(p.is_symlink() for p in raw_targets):
        raise ValueError('Symlink migration targets are not accepted')
    targets=[Path(s['path']).resolve() for s in agents]+[Path(plan['skill_destination'])]+[Path(p).resolve() for p in plan.get('disable_skill_dirs',[])]
    for item in agents:
        if not Path(item['path']).is_absolute() or not item.get('review_note'):
            raise ValueError('Agent file needs absolute path and review note')
        p=Path(item['path'])
        if item.get('overlay_file') and (not Path(item['overlay_file']).is_absolute() or not Path(item['overlay_file']).is_file()):
            raise ValueError('Scoped overlay must be an existing absolute file')
        if p.exists() and (not item.get('expected_sha256') or hash_file(p)!=item['expected_sha256']):
            raise ValueError('Unread/stale AGENTS file: '+str(p))
    backup=Path(plan['backup_root']);project=Path(plan['project_root'])
    if inside(backup,project) or inside(backup,KIT):
        raise ValueError('Backup must be outside project/Kit scanner trees')
    for p in targets:
        if inside(p,KIT) or p==Path(plan['local_overlay_file']):
            raise ValueError('Do not mutate the Kit checkout or overlay source')
        if inside(backup,p) or inside(p,backup):
            raise ValueError('Backup must be outside every target/scanned directory')
    for i,a in enumerate(targets):
        if any(inside(a,b) or inside(b,a) for b in targets[i+1:]):
            raise ValueError('Overlapping/duplicate migration targets')
    for p in plan.get('disable_skill_dirs',[]):
        root=Path(p)
        if not root.is_absolute() or not (root/'SKILL.md').is_file():
            raise ValueError('Disable only exact reviewed Skill directories')
        front=(root/'SKILL.md').read_text(encoding='utf-8')
        if root.name=='ppt-master' or re.search(r'''(?m)^name:\s*['"]?ppt-master['"]?\s*$''',front):
            raise ValueError('ppt-master must remain enabled')
    return plan,targets


def apply(plan_path):
    plan,targets=load_plan(plan_path)
    backup=Path(plan['backup_root'])
    if backup.exists():
        raise ValueError('Use a fresh backup root; existing backups are never overwritten')
    backup.mkdir(parents=True)
    journal={'schema':'kit.bootstrap-receipt.v1','status':'PREPARING','plan_sha256':hash_file(plan_path),
             'loading_status':'NOT VERIFIED','entries':[]}
    journal_path=backup/'receipt.json'
    # Back up every original before the first target mutation.
    for i,target in enumerate(targets):
        entry={'path':str(target),'existed':target.exists(),'backup':str(backup/str(i)),'before':{},'after':None}
        if target.exists():
            entry['before']=files(target)
            if target.is_dir():
                shutil.copytree(target,entry['backup'],ignore=shutil.ignore_patterns('__pycache__'))
            else:
                shutil.copy2(target,entry['backup'])
            if files(entry['backup'])!=entry['before']:
                raise ValueError('Backup verification failed')
        journal['entries'].append(entry)
    journal['status']='BACKED UP';journal_path.write_text(json.dumps(journal,ensure_ascii=False,indent=2),encoding='utf-8')
    content=(KIT/'AGENTS.md').read_text(encoding='utf-8')
    overlay=Path(plan['local_overlay_file']).read_text(encoding='utf-8')
    if overlay.strip():
        content+='\n\n# Company-local rules preserved after conflict review\n'+overlay+'\n'
    disable={str(Path(p).resolve()) for p in plan.get('disable_skill_dirs',[])}
    for entry in journal['entries']:
        target=Path(entry['path'])
        if str(target) in disable:
            shutil.rmtree(target)
            entry['after']=None
        elif target==Path(plan['skill_destination']):
            if target.exists():
                shutil.rmtree(target)
            shutil.copytree(SKILL,target,ignore=shutil.ignore_patterns('__pycache__'))
            entry['after']=files(target)
        else:
            target.parent.mkdir(parents=True,exist_ok=True)
            scoped=next((x.get('overlay_file') for x in plan['agents_files'] if Path(x['path']).resolve()==target),None)
            local=content+('\n\n# Rules for this instruction scope\n'+Path(scoped).read_text(encoding='utf-8') if scoped else '')
            target.write_text(local,encoding='utf-8')
            entry['after']=files(target)
        journal_path.write_text(json.dumps(journal,ensure_ascii=False,indent=2),encoding='utf-8')
    journal['status']='APPLIED';journal_path.write_text(json.dumps(journal,ensure_ascii=False,indent=2),encoding='utf-8')
    return journal_path


def verify(receipt):
    data=json.loads(Path(receipt).read_text(encoding='utf-8'))
    if data.get('status')!='APPLIED':
        raise ValueError('Migration not fully applied; inspect receipt before retry')
    for e in data['entries']:
        p=Path(e['path'])
        if e['after'] is None:
            if p.exists():raise ValueError('Disabled Skill reappeared: '+str(p))
        elif not p.exists() or files(p)!=e['after']:
            raise ValueError('Applied instruction files changed: '+str(p))
    return 'FILES VERIFIED; runtime loading still requires agent evidence'


def rollback(receipt):
    path=Path(receipt);data=json.loads(path.read_text(encoding='utf-8'))
    if data.get('status')=='ROLLED BACK':
        return 'Already rolled back'
    # Refuse to overwrite edits made after migration; restore only known states.
    for e in data['entries']:
        target=Path(e['path'])
        current=files(target) if target.exists() else None
        if current not in (e['after'],e['before'] if e['existed'] else None):
            raise ValueError('Target changed after migration; reconcile first: '+str(target))
        if e['existed'] and files(e['backup'])!=e['before']:
            raise ValueError('Backup changed; refusing rollback')
    for e in reversed(data['entries']):
        p=Path(e['path'])
        if p.exists():
            shutil.rmtree(p) if p.is_dir() else p.unlink()
        if e['existed']:
            if Path(e['backup']).is_dir():shutil.copytree(e['backup'],p)
            else:
                p.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(e['backup'],p)
    data['status']='ROLLED BACK';path.write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
    return 'ROLLED BACK'


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('action',choices=['check','apply','verify','rollback']);p.add_argument('file')
    a=p.parse_args()
    try:
        if a.action=='check':
            plan,targets=load_plan(a.file);print('PLAN VALID: '+str(len(targets))+' exact targets')
        elif a.action=='apply': print(apply(a.file))
        elif a.action=='verify': print(verify(a.file))
        else: print(rollback(a.file))
        return 0
    except Exception as e:
        print(type(e).__name__+': '+str(e));return 1

if __name__=='__main__':
    raise SystemExit(main())
