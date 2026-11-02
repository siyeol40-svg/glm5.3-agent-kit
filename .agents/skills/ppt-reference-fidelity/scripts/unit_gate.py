"""Sequential, evidence-bound unit gates. Does not edit Office or inspect PPTX bytes."""
import argparse
from pathlib import Path
import com_workflow as c

PROPERTIES={'geometry','z_order','fill','line','shadow','picture_crop','font_runs','text_frame','type','name','parent'}
LIMITATIONS=['Document bytes/content hash unavailable; readback covers readable properties only.',
             'Master/layout inheritance completeness unverified; zero/null is not proof of absence.',
             'Effective auto-shrunk font size unavailable; COM font size is nominal.',
             'Image content identity unavailable; geometry/crop does not prove image meaning.',
             'Chart series/values and OLE internals unverified.',
             'Hidden slide state unverified; null must not become visible/false.']


def projection(snapshot):
    shapes=c.validate_manifest(snapshot)
    return {'slide_size':snapshot.get('slide_size'),'slides':[s['slide'] for s in snapshot['slides']],
            'shapes':{str(i)+':'+k:{p:v for p,v in shape.items() if p!='text_bounds'} for (i,k),shape in shapes.items()}}


def snapshot(item):
    c.evidence(item);value=c.read(item['path']);c.validate_manifest(value);return value


def load(work):
    work=Path(work);plan=c.read(work/'unit_plan.json');state=c.read(work/'unit_state.json')
    c.need(state['plan_sha256']==c.sha(work/'unit_plan.json'),'unit plan changed; start a new RUN')
    for name,value in state['bindings'].items():
        c.need(c.sha(work/name)==value,'upstream plan/confirmation changed; start a new RUN')
    for record in state['units'].values():
        for name in ('analysis','operation_log','before','after'):
            if record.get(name):c.evidence(record[name])
    return plan,state


def init(work):
    work=Path(work);c.need(not (work/'unit_state.json').exists(),'unit state exists; preserve history')
    c.validate_consultation(work)
    blueprint=c.read(work/'content_blueprint.json');reference=c.read(work/'reference_native.json')
    c.validate_blueprint(blueprint,reference)
    lock=c.read(work/'plan_lock.json')
    c.need(lock.get('consultation')==c.validate_consultation(work) and
           lock['blueprint_sha256']==c.sha(work/'content_blueprint.json') and
           lock['reference_sha256']==c.sha(work/'reference_native.json'),'missing/stale overall plan lock')
    plan=c.read(work/'unit_plan.json');c.need(plan.get('schema')=='kit.unit-plan.v1' and plan.get('units'),'unit plan missing')
    base=snapshot(plan['baseline']);c.need(base['identity']['path']!=reference['identity']['path'],'unit baseline must be a working copy')
    rows=plan['units'];ids=[u['id'] for u in rows]
    c.need(len(ids)==len(set(ids)),'duplicate unit id')
    seen=set();coverage=set()
    for unit in rows:
        c.need(unit.get('purpose') and type(unit.get('slide')) is int and unit.get('targets'),'unit scope incomplete')
        c.need(set(unit.get('depends_on',[]))<=seen,'dependencies must identify earlier units')
        c.need(unit['slide'] in [s['slide'] for s in base['slides']],'unit slide missing')
        for name in unit.get('new_shapes',[]):
            c.need(name.get('name') and len(name.get('bounds',[]))==4,'new shape needs exact name and bounds')
        coverage.update((unit['slide'],key) for key in unit['targets']);seen.add(unit['id'])
    expected={(s['slide'],x['target']) for s in blueprint['slides'] for x in s['classification']}
    c.need(expected<=coverage,'every selected source object must belong to a unit')
    state={'schema':'kit.unit-state.v1','plan_sha256':c.sha(work/'unit_plan.json'),
           'bindings':{name:c.sha(work/name) for name in ('plan_lock.json','content_blueprint.json','reference_native.json','plan_confirmation.json')},
           'latest':plan['baseline'],'active':None,'units':{},'limitations':LIMITATIONS}
    c.write(work/'unit_state.json',state);return state


def analyze(work,uid,analysis_file):
    plan,state=load(work);unit=next((u for u in plan['units'] if u['id']==uid),None)
    c.need(unit is not None,'unknown unit')
    c.need(uid not in state['units'] or state['units'][uid]['status'] in {'ANALYZED','NEEDS_INPUT'},'unit already authorized/applied; start a new RUN for rework')
    a=c.read(analysis_file)
    c.need(a.get('unit_id')==uid and a.get('facts') and a.get('source_refs') and a.get('adaptation'),'unit analysis incomplete')
    c.need(isinstance(a.get('unknowns'),list) and isinstance(a.get('questions'),list),'explicit unknowns/questions required')
    questions=a['questions'];qids=[q.get('id') for q in questions]
    c.need(all(qids) and len(set(qids))==len(qids),'question IDs missing/duplicate')
    for unknown in a['unknowns']:
        c.need(unknown.get('description') and unknown.get('question_id') in qids,'unknown must link to a question before editing')
    pending=[]
    for q in questions:
        c.need(q.get('question'),'question text missing')
        if q.get('resolution') not in {'ANSWERED','USER_WAIVED'}:pending.append(q['id']);continue
        c.need(q.get('answer'),'question answer missing');c.evidence(q.get('message_evidence',{}))
        if q['resolution']=='USER_WAIVED':c.need(q.get('alternative'),'waiver needs explicit alternative')
    record={'status':'NEEDS_INPUT' if pending else 'ANALYZED','pending_questions':pending,
            'analysis':{'path':str(Path(analysis_file).resolve()),'sha256':c.sha(analysis_file)}}
    state['units'][uid]=record;c.write(Path(work)/'unit_state.json',state);return record


def ready(work,uid):
    plan,state=load(work);record=state['units'].get(uid,{})
    c.need(record.get('status')=='ANALYZED','analyze and resolve user questions before editing')
    c.need(state['active'] is None,'another unit is active; do not parallelize COM edits')
    unit=next(u for u in plan['units'] if u['id']==uid)
    c.need(all(r['status']!='REQUIRES_FIX' for r in state['units'].values()),'repair failed work in a new RUN before further editing')
    for dep in unit.get('depends_on',[]):
        c.need(state['units'].get(dep,{}).get('status')=='NONVISUAL_CHECKED','dependency not checked: '+dep)
    analysis=c.read(record['analysis']['path']);before=snapshot(analysis['before'])
    latest=snapshot(state['latest'])
    c.need(before['identity']['path']==latest['identity']['path'] and projection(before)==projection(latest),'stale/out-of-band before snapshot')
    checks=analysis.get('checks',[])
    c.need(checks and len({x.get('id') for x in checks})==len(checks),'concrete unique checks required')
    for check in checks:
        c.need(check.get('id') and check.get('kind') in {'text','property','exists','absent'},'unsupported QA claim; keep it as a limitation')
        c.need(check.get('target') in unit['targets'] or check.get('result_name') in {n['name'] for n in unit.get('new_shapes',[])},'check outside unit scope')
        if check['kind']=='property':c.need(check.get('property') in PROPERTIES,'unobservable property cannot PASS')
        if check['kind'] in {'property','text'}:c.need('expected' in check and check['expected'] is not None,'expected value required')
    record.update(status='READY',before=analysis['before']);state['active']=uid
    c.write(Path(work)/'unit_state.json',state);return record


def check(work,uid,after_file,log_file):
    plan,state=load(work);record=state['units'].get(uid,{})
    c.need(record.get('status')=='READY' and state['active']==uid,'no editing ticket for unit')
    unit=next(u for u in plan['units'] if u['id']==uid);analysis=c.read(record['analysis']['path'])
    after_item={'path':str(Path(after_file).resolve()),'sha256':c.sha(after_file)};after=snapshot(after_item)
    before=snapshot(record['before']);c.need(before['identity']['path']==after['identity']['path'],'working copy changed')
    operation={'path':str(Path(log_file).resolve()),'sha256':c.sha(log_file)};c.evidence(operation)
    errors=[];delta=c.differences(projection(before),projection(after));page=unit['slide']
    shapes=c.validate_manifest(after);new_allowed={n['name']:n['bounds'] for n in unit.get('new_shapes',[])}
    for change in delta:
        if not change['path'].startswith('/shapes/'):errors.append('unplanned deck change: '+change['path']);continue
        encoded=change['path'].split('/')[2].replace('~1','/').replace('~0','~');slide,key=encoded.split(':',1)
        if int(slide)==page and key in unit['targets']:continue
        obj=shapes.get((int(slide),key),{});name=obj.get('name')
        # New IDs need an exact planned name and an unrotated bounded frame.
        permitted=False
        if int(slide)==page and change['before'] is None and change['path'].count('/')==2 and name in new_allowed:
            x,y,w,h=new_allowed[name];geo=obj.get('geometry',[])
            if len(geo)==5:
                gx,gy,gw,gh,rot=geo
                permitted=(w>0 and h>0 and gw>0 and gh>0 and rot==0 and x<=gx and y<=gy and gx+gw<=x+w and gy+gh<=y+h and
                           len([v for (s,k),v in shapes.items() if s==page and v.get('name')==name])==1)
        if not permitted:errors.append('change outside active unit: '+change['path'])
    results=[]
    for rule in analysis['checks']:
        matches=[s for (p,k),s in shapes.items() if p==page and s.get('name')==rule['result_name']] if rule.get('result_name') else [shapes[(page,rule['target'])]] if (page,rule.get('target')) in shapes else []
        kind=rule['kind'];actual=None
        if kind in {'exists','absent'}:
            actual=len(matches);passed=(len(matches)==1 if kind=='exists' else len(matches)==0)
        elif len(matches)!=1:passed=False
        else:
            actual=matches[0].get('text' if kind=='text' else rule['property'])
            def known(value):
                if value is None:return False
                if isinstance(value,list):return all(known(x) for x in value)
                if isinstance(value,dict):return all(known(x) for x in value.values())
                return True
            passed=(isinstance(actual,str) and c.norm(actual)==c.norm(rule['expected'])) if kind=='text' else known(actual) and actual==rule['expected']
        results.append({'id':rule['id'],'status':'PASS' if passed else 'FAIL','expected':rule.get('expected'),'observed':actual})
        if not passed:errors.append('readback mismatch: '+rule['id'])
    record.update(status='REQUIRES_FIX' if errors else 'NONVISUAL_CHECKED',after=after_item,operation_log=operation,results=results,errors=errors)
    state['active']=None;state['latest']=after_item;c.write(Path(work)/'unit_state.json',state)
    return record


def invalidate(work,uid,reason):
    plan,state=load(work);c.need(reason and state['active'] is None,'reason required; finish readback of any active edit first')
    c.need(uid in {u['id'] for u in plan['units']},'unknown unit')
    affected={uid}
    for unit in plan['units']:
        if set(unit.get('depends_on',[])) & affected:affected.add(unit['id'])
    archived={key:state['units'].pop(key) for key in list(state['units']) if key in affected}
    state.setdefault('history',[]).append({'reason':reason,'invalidated':sorted(affected),'records':archived})
    # Keep latest actual snapshot. Rework starts from current reality, never rewinds the PPT.
    c.write(Path(work)/'unit_state.json',state);return {'status':'INVALIDATED','units':sorted(affected)}


def finish(work):
    plan,state=load(work)
    c.need(state['active'] is None and all(state['units'].get(u['id'],{}).get('status')=='NONVISUAL_CHECKED' for u in plan['units']), 'unit loop incomplete/failed')
    current=c.read(Path(work)/'result_native.json');latest=snapshot(state['latest'])
    c.need(current['identity']['path']==latest['identity']['path'] and projection(current)==projection(latest),'final snapshot differs from checked units')
    return {'status':'NONVISUAL_CHECKED_WITH_LIMITATIONS','units':len(plan['units']),'limitations':LIMITATIONS}


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('action',choices=['init','analyze','ready','check','invalidate','finish'])
    p.add_argument('--work',required=True);p.add_argument('--unit');p.add_argument('--analysis');p.add_argument('--after');p.add_argument('--log');p.add_argument('--reason');a=p.parse_args()
    try:
        if a.action=='init':r=init(a.work)
        elif a.action=='analyze':r=analyze(a.work,a.unit,a.analysis)
        elif a.action=='ready':r=ready(a.work,a.unit)
        elif a.action=='check':r=check(a.work,a.unit,a.after,a.log)
        elif a.action=='invalidate':r=invalidate(a.work,a.unit,a.reason)
        else:r=finish(a.work)
        status=r.get('status','INITIALIZED');print(status)
        return 2 if status in {'NEEDS_INPUT','REQUIRES_FIX'} else 0
    except Exception as e:print(type(e).__name__+': '+str(e));return 1


if __name__=='__main__':raise SystemExit(main())
