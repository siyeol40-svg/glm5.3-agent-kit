"""DRM-safe evidence orchestration: no ZIP/PPTX byte reads, no automatic export.
COM snapshots and user captures are inputs, not proof of unobservable internals.
"""
import argparse
import hashlib
import json
import math
import copy
from pathlib import Path

ROLES={'text','photo','diagram','chart','decoration','logo','container','design_anchor'}
VISUAL_TYPES={3,11,13,24,28,29}
DETAIL_CHECKS={'text_clipping','overlap','image_crop','alignment','spacing','shadow','border',
               'hierarchy','reference_structure','content_relevance','visual_brief_match'}
OVERVIEW_CHECKS={'alignment','hierarchy','reference_structure','content_relevance','visual_brief_match'}


def read(path):return json.loads(Path(path).read_text(encoding='utf-8-sig'))
def digest(value):return hashlib.sha256(json.dumps(value,sort_keys=True,ensure_ascii=False).encode()).hexdigest()
def sha(path):
    need(Path(path).suffix.lower() not in {'.pptx','.pptm','.ppt','.potx','.docx','.doc','.xlsx','.xls','.xlsm'},
         'DRM profile does not read protected Office document bytes')
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def write(path,value):
    p=Path(path);p.parent.mkdir(parents=True,exist_ok=True)
    p.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def need(test,message):
    if not test:raise ValueError(message)
def identity(path):
    p=Path(path).resolve();s=p.stat()
    return {'path':str(p),'size_bytes':s.st_size,'mtime_ticks_utc':s.st_mtime_ns//100+621355968000000000}
def evidence(item):
    need(item.get('path') and item.get('sha256')==sha(item['path']),'missing/stale evidence file')
def norm(text):return text.replace('\r\n','\n').replace('\r','\n')


def validate_manifest(manifest):
    need(manifest.get('schema')=='kit.com-manifest.v1' and manifest.get('status')=='PASS','COM snapshot unavailable')
    need(manifest.get('identity') and manifest.get('slides') and not manifest.get('errors'),'incomplete COM snapshot')
    slides=manifest['slides']
    need([s['slide'] for s in slides]==list(range(1,len(slides)+1)),'invalid COM slide roster')
    for slide in slides:
        keys=[s['key'] for s in slide['shapes']]
        need(len(keys)==len(set(keys)),'duplicate COM shape key')
    return {(s['slide'],x['key']):x for s in slides for x in s['shapes']}


def validate_blueprint(plan,reference):
    reference=planned_reference(reference,plan)
    shapes=validate_manifest(reference)
    need(plan.get('schema')=='kit.content-blueprint.v1' and plan.get('locked') is True,'blueprint not locked')
    need(plan.get('reference_revision')==digest(reference['identity']),'blueprint reference mismatch')
    need(plan.get('slides') and [s['slide'] for s in plan['slides']]==list(range(1,len(reference['slides'])+1)),'blueprint slide coverage')
    classified=set();visual_ids=set();region_ids=set()
    for slide in plan['slides']:
        i=slide['slide']
        for field in ('message','audience_takeaway','visual_story','design_anchors','source_refs'):
            need(slide.get(field),'missing slide thinking: '+field)
        options=slide.get('visual_options',[])
        need(len(options)>=2 and len({o.get('id') for o in options})==len(options) and
             len({o.get('concept') for o in options})==len(options) and
             all(o.get('id') and o.get('concept') and o.get('source_refs') for o in options),
             'compare at least two concrete, source-grounded visual approaches')
        need(slide.get('selected_option') in {o['id'] for o in options} and slide.get('selection_reason'),
             'selected visual approach and rationale required')
        # A slogan such as "replace text" is not a useful visual brief; require explicit visual decisions.
        for item in slide.get('classification',[]):
            key=(i,item['target']);need(key in shapes and key not in classified,'missing/duplicate classification target')
            need(item.get('role') in ROLES and item.get('reason'),'visual role decision missing')
            if shapes[key].get('type') in VISUAL_TYPES:
                need(item['role'] in {'photo','diagram','chart','decoration','logo'},'substantive visual cannot be hidden as text/container')
            classified.add(key)
        content_visuals={c['target'] for c in slide.get('classification',[]) if c['role'] in {'photo','diagram','chart'}}
        briefs=slide.get('visual_slots',[])
        visual_targets=content_visuals | {key for (page,key),shape in shapes.items() if page==i and shape.get('type') in VISUAL_TYPES}
        need(visual_targets <= {v.get('target') for v in briefs},'reference visual left without a content decision')
        for visual in briefs:
            vid=visual['id'];need(vid not in visual_ids,'duplicate visual id');visual_ids.add(vid)
            need(visual.get('role') in {'photo','diagram','chart','decoration','logo'},'invalid visual role')
            if visual.get('target'):
                need((i,visual['target']) in shapes,'visual target missing')
            old_role=next((x['role'] for x in slide['classification'] if x['target']==visual.get('target')),None)
            if old_role in {'photo','diagram','chart'} and old_role!=visual['role']:
                need(visual.get('role_change_reason'),'unplanned photo/diagram role change')
            decision=visual.get('decision')
            need(decision in {'replace','rebuild','create','retain_decoration','retain_content_approved','remove'},'missing visual action')
            need(visual.get('rationale') and visual.get('source_refs'),'visual rationale/source missing')
            if decision in {'replace','rebuild','create'}:
                need(visual.get('new_concept') and visual.get('implementation') and visual.get('acceptance_criteria'),
                     'new visual requires concept, implementation and concrete acceptance criteria')
                if visual['role']=='photo':
                    need(visual.get('asset_origin') in {'user_supplied','approved_source','illustrative_generated'},'unknown photo origin')
                    need(visual.get('fact_role') in {'evidence','illustration'},'photo evidence/illustration role missing')
                    need(not (visual['asset_origin']=='illustrative_generated' and visual['fact_role']=='evidence'),'generated picture is not factual evidence')
            elif decision=='retain_decoration':
                need(visual['role'] in {'decoration','logo'},'old photo/diagram cannot be retained as decoration')
                need(visual.get('decoration_basis'),'retained design asset needs classification rationale')
                evidence(visual.get('approval_evidence',{}))
            elif decision=='retain_content_approved':
                need(visual.get('approval_evidence'),'old substantive visual requires actual user authorization')
                evidence(visual['approval_evidence'])
        # Any page with substantive visuals needs a newly considered visual treatment, unless explicitly retained by the user.
        if content_visuals:
            need(any(v['decision'] in {'replace','rebuild','create','retain_content_approved','remove'} for v in briefs),
                 'text-only copy is not content adaptation')
        regions=slide.get('capture_regions',[])
        need(len([r for r in regions if r.get('scope')=='overview'])==1,'one overview capture per slide required')
        covered=set()
        for region in regions:
            need(region['id'] not in region_ids and region.get('scope') in {'overview','detail'},'invalid/duplicate capture region')
            region_ids.add(region['id'])
            if region['scope']=='detail':covered.update(region.get('targets',[]))
        need(content_visuals <= covered,'detail captures must cover content visuals')
        text_slots=slide.get('text_slots',[])
        need({key for (page,key),shape in shapes.items() if page==i and shape.get('text')} <= {x.get('target') for x in text_slots},
             'reference text left without a content decision')
        for slot in text_slots:
            need((i,slot['target']) in shapes and slot.get('source_ref') and (slot.get('decision')=='remove' or 'expected_text' in slot),'text slot incomplete')
            need(slot['target'] in covered,'detail capture must cover replaced text')
    need(classified==set(shapes),'every recursive shape requires a role decision')
    return {'status':'PASS','slides':len(plan['slides']),'visual_slots':len(visual_ids)}


def planned_reference(reference,plan):
    """Select/reorder/repeat native source skeletons; do not force whole-deck cloning."""
    validate_manifest(reference)
    rows=plan.get('slides',[])
    need(rows and [s['slide'] for s in rows]==list(range(1,len(rows)+1)), 'invalid output slide roster')
    selected=[]
    for row in rows:
        source=row.get('reference_slide',row['slide'])
        need(type(source) is int and 1<=source<=len(reference['slides']), 'reference_slide must identify a native source skeleton')
        if source!=row['slide'] or len(rows)!=len(reference['slides']):
            need(row.get('adaptation_reason'), 'slide selection/reorder needs an adaptation reason')
        slide=copy.deepcopy(reference['slides'][source-1]);slide['slide']=row['slide'];selected.append(slide)
    planned=copy.deepcopy(reference);planned['slides']=selected
    return planned


def validate_consultation(work):
    """Bind a concrete analysis/material review and actual user confirmation to this plan."""
    work=Path(work);ref=read(work/'reference_native.json');validate_manifest(ref)
    analysis=read(work/'reference_analysis.json');materials=read(work/'material_review.json')
    need(analysis.get('reference_sha256')==sha(work/'reference_native.json'), 'stale reference analysis')
    rows=analysis.get('slides',[])
    need([s['slide'] for s in rows]==list(range(1,len(ref['slides'])+1)), 'analyze every source slide before selecting patterns')
    for row in rows:
        need(row.get('composition') and row.get('useful_patterns') and row.get('adaptation') and row.get('unknowns') is not None,
             'reference analysis must describe composition, useful patterns, adaptation and unknowns')
    need(materials.get('available') and materials.get('proposed_use') and isinstance(materials.get('questions'),list), 'material review incomplete')
    for item in materials['available']:
        need(item.get('id') and item.get('source_ref') and item.get('use'), 'available material needs source and planned use')
    for question in materials['questions']:
        need(question.get('question') and question.get('resolution') in {'ANSWERED','USER_WAIVED'} and question.get('answer'), 'unanswered production question')
        evidence(question.get('message_evidence',{}))
    confirmation=read(work/'plan_confirmation.json')
    need(confirmation.get('confirmed_by')=='user' and confirmation.get('decision')=='APPROVED_FOR_EDIT', 'user plan confirmation missing')
    for name in ('reference_analysis','material_review','content_blueprint'):
        need(confirmation.get(name+'_sha256')==sha(work/(name+'.json')), 'stale consultation: '+name)
    evidence(confirmation.get('message_evidence',{}))
    return {name:sha(work/(name+'.json')) for name in ('reference_analysis','material_review','plan_confirmation')}


def differences(a,b,path=''):
    if type(a)!=type(b):return [{'path':path,'before':a,'after':b}]
    if isinstance(a,dict):
        out=[]
        for key in sorted(a.keys()|b.keys()):
            p=path+'/'+key.replace('~','~0').replace('/','~1')
            if key not in a or key not in b:out.append({'path':p,'before':a.get(key),'after':b.get(key)})
            else:out.extend(differences(a[key],b[key],p))
        return out
    if isinstance(a,list):
        if len(a)!=len(b):return [{'path':path,'before':a,'after':b}]
        return [d for i,(x,y) in enumerate(zip(a,b)) for d in differences(x,y,path+'/'+str(i))]
    return [] if a==b else [{'path':path,'before':a,'after':b}]


def compare_native(reference,result,plan):
    reference=planned_reference(reference,plan)
    before=validate_manifest(reference);after=validate_manifest(result)
    need(len(result['slides'])==len(plan['slides']), 'result slide count differs from approved plan')
    # Compare explicit design properties; text strings and derived text bounds are
    # checked separately. Adjacent equivalent font runs are normalized for resegmentation.
    def stable(shape):
        shape=dict(shape);shape.pop('text',None);shape.pop('text_bounds',None)
        fonts=[]
        for run in shape.get('font_runs',[]):
            font=run.get('font')
            if not fonts or fonts[-1]!=font:fonts.append(font)
        if 'font_runs' in shape:shape['font_runs']=fonts
        return shape
    aa={'slide_size':reference.get('slide_size'),'shapes':{str(i)+':'+k:stable(v) for (i,k),v in before.items()}}
    bb={'slide_size':result.get('slide_size'),'shapes':{str(i)+':'+k:stable(v) for (i,k),v in after.items()}}
    delta=differences(aa,bb);allow=plan.get('allowed_native_changes',[])
    for item in allow:
        need(item.get('reason') and item.get('path') and 'before' in item and 'after' in item,'invalid native change allowance')
    rules=[(s['slide'],v.get('native_policy',{})) for s in plan['slides'] for v in s.get('visual_slots',[]) if v.get('native_policy')]
    used={};unplanned=[]
    for d in delta:
        if any(all(d[k]==a.get(k) for k in ('path','before','after')) for a in allow):continue
        accepted=False
        # Newly created objects need a locked name prefix, bounded canvas and count.
        if d['path'].startswith('/shapes/') and d['path'].count('/')==2:
            encoded=d['path'][8:].replace('~1','/').replace('~0','~')
            page,key=encoded.split(':',1);page=int(page)
            for index,(slide,policy) in enumerate(rules):
                if slide!=page:continue
                if d['after'] is None and key in policy.get('remove_targets',[]):accepted=True;break
                obj=d['after']
                if d['before'] is not None or not obj or not policy.get('allow_new'):continue
                bounds=policy.get('bounds',[]);geo=obj.get('geometry',[]);prefix=policy.get('name_prefix','')
                limit=policy.get('max_new_objects',0)
                if not (prefix and obj.get('name','').startswith(prefix) and len(bounds)==4 and len(geo)>=5 and
                        type(limit) is int and 0 < limit <= 100 and used.get(index,0)<limit):continue
                x,y,w,h=bounds;gx,gy,gw,gh,rot=geo[:5]
                if w>0 and h>0 and gw>0 and gh>0 and abs(rot)<0.01 and x<=gx and y<=gy and gx+gw<=x+w and gy+gh<=y+h:
                    used[index]=used.get(index,0)+1;accepted=True;break
        if not accepted:unplanned.append(d)
    text_errors=[]
    for slide in plan['slides']:
        for slot in slide.get('text_slots',[]):
            if slot.get('decision')=='remove':
                if (slide['slide'],slot['target']) in after:text_errors.append(slot['target']+': old text object still present')
                continue
            target=(slide['slide'],slot.get('result_target',slot['target']))
            matches=[obj for (page,key),obj in after.items() if page==slide['slide'] and obj.get('name')==slot.get('result_name')] if slot.get('result_name') else [after[target]] if target in after else []
            if len(matches)!=1 or norm(matches[0].get('text',''))!=norm(slot['expected_text']):
                text_errors.append(str(target)+': expected content not found')
    unknown=reference.get('unreadable_properties',[])+result.get('unreadable_properties',[])
    for (page,key),shape in after.items():
        if not shape.get('text'):continue
        geo=shape.get('geometry',[]);frame=shape.get('text_frame',[]);bounds=shape.get('text_bounds',[])
        values=geo[:5]+frame[:4]+bounds if isinstance(frame,list) and isinstance(bounds,list) else []
        supported=(not shape.get('parent') and shape.get('type') in {1,14,17} and len(geo)>=5 and len(frame or [])>=8 and
                   len(bounds or [])==4 and frame[7]==1 and all(type(v) in (int,float) and math.isfinite(v) for v in values) and abs(geo[4])<0.01)
        if not supported:
            unknown.append(str((page,key))+': text-fit geometry unverified');continue
        x,y,w,h=geo[:4];ml,mt,mr,mb=frame[:4];bx,by,bw,bh=bounds;eps=0.5
        if bw<=0 or bh<=0 or bx<x+ml-eps or by<y+mt-eps or bx+bw>x+w-mr+eps or by+bh>y+h-mb+eps:
            text_errors.append(str((page,key))+': native text bounds exceed inner frame')
        unknown.append(str((page,key))+': effective rendered font size unavailable; nominal font only')
    return {'schema':'kit.com-diff.v1','status':'FAIL' if unplanned or text_errors else ('PARTIAL' if unknown else 'PASS'),
            'changes':delta,'unplanned':unplanned,'text_errors':text_errors,'unreadable_properties':unknown,
            'scope':'COM-readable object properties only; no ZIP relationships/media-byte inspection'}


def audit(work):
    work=Path(work)
    loading=read(work/'instruction_loading.json')
    need(loading.get('status')=='PASS' and loading.get('active_files'),'active instruction loading not verified')
    for entry in loading['active_files']+[loading['evidence']]:evidence(entry)
    evidence(loading['bootstrap_receipt'])
    need(read(loading['bootstrap_receipt']['path']).get('status')=='APPLIED','local migration not applied')
    plan=read(work/'content_blueprint.json');ref=read(work/'reference_native.json');result=read(work/'result_native.json')
    lock=read(work/'plan_lock.json')
    need(lock['blueprint_sha256']==sha(work/'content_blueprint.json') and lock['reference_sha256']==sha(work/'reference_native.json'), 'plan changed after locking; create a new planned revision')
    need(lock.get('consultation')==validate_consultation(work), 'consultation changed after locking')
    validate_blueprint(plan,ref);validate_manifest(result)
    need(ref['identity']['path']!=result['identity']['path'],'source must not be overwritten')
    for snapshot in (ref,result):
        need(identity(snapshot['identity']['path'])==snapshot['identity'],'file metadata revision changed; refresh snapshot/captures')
    import unit_gate
    source_readback=read(work/'source_readback.json');validate_manifest(source_readback)
    need(source_readback['identity']['path']==ref['identity']['path'] and
         unit_gate.projection(source_readback)==unit_gate.projection(ref),'original readable content changed or readback missing')
    unit_receipt=unit_gate.finish(work)
    caps=read(work/'com_capabilities.json')
    need(caps.get('route')=='COM_USER_CAPTURE','wrong execution profile')
    for operation in ('open','read_objects','create_copy','edit','save','reopen'):
        entry=caps.get('operations',{}).get(operation,{})
        need(entry.get('status')=='PASS' and entry.get('exit_code')==0,'COM capability missing: '+operation)
        evidence(entry['log'])
    diff=compare_native(ref,result,plan);write(work/'native_diff.json',diff)
    need(diff['status']!='FAIL','unplanned native changes or content readback failure')
    impl=read(work/'visual_implementation.json')
    need(impl.get('candidate_revision')==digest(result['identity']),'stale visual implementation record')
    byid={v['id']:v for v in impl.get('items',[])}
    need(len(byid)==len(impl.get('items',[])),'duplicate visual implementation')
    result_shapes=validate_manifest(result)
    planned=[(s['slide'],v) for s in plan['slides'] for v in s.get('visual_slots',[])]
    need(set(byid)=={v['id'] for _,v in planned},'visual implementation coverage incomplete')
    for slide,v in planned:
        item=byid[v['id']]
        need(item.get('decision')==v['decision'] and item.get('observations'),'visual action mismatch')
        if v['decision']=='remove' and v.get('target'):
            need((slide,v['target']) not in result_shapes,'removed visual is still present')
        if v['decision']!='remove':
            need(item.get('result_targets') and all((slide,k) in result_shapes for k in item['result_targets']),'visual result object missing')
        if v['decision'] in {'replace','rebuild','create','remove'}:
            evidence(item['operation_log'])
            need(item.get('implemented_concept')==v.get('new_concept') if v['decision']!='remove' else True,'visual concept not implemented')
            if v['role']=='photo' and v['decision'] in {'replace','create'}:
                need(item.get('asset'),'new photo asset evidence is required')
            if item.get('asset'):
                evidence(item['asset'])
    revision=digest(result['identity'])
    receipt={'schema':'kit.com-receipt.v1','status':'AWAITING_USER_CAPTURE','candidate_revision':revision,
             'checks':{'com_operations':'PASS','content_blueprint':'PASS','native_properties':diff['status'],
                       'unit_loop':unit_receipt['status'],'source_readback':'READABLE_PROPERTIES_MATCH_ONLY',
                       'visual_implementation_trace':'PASS','package_integrity':'NOT_CHECKED_DRM_PROFILE',
                       'automatic_render':'NOT_USED_USER_CAPTURE'},
             'limitations':['Metadata binds the document revision weakly; it is not a byte hash.',
                            'Operation logs and manifests do not prove image meaning or visual quality.',
                            'User capture provenance/acceptance must be explicit; model opinion is advisory.']+unit_receipt['limitations']}
    issues=read(work/'known_issues.json')
    unresolved=[]
    for issue in issues.get('issues',[]):
        if issue.get('reported_by')=='user':
            evidence(issue['report_evidence'])
        if issue.get('status')!='RESOLVED':unresolved.append(issue['id']);continue
        need(issue.get('fix_description') and issue.get('confirmed_by')=='user','user issues cannot be self-dismissed')
        evidence(issue['confirmation_evidence'])
    if unresolved:
        receipt.update(status='REQUIRES_FIX',unresolved_issues=unresolved,pending_inputs=['user captures/confirmation'])
    capfile=work/'capture_qa.json'
    if not capfile.exists():return receipt
    qa=read(capfile);need(qa.get('candidate_revision')==revision,'captures refer to a different candidate revision')
    rows=qa.get('regions',[]);byregion={r['id']:r for r in rows}
    expected={r['id']:r for s in plan['slides'] for r in s['capture_regions']}
    need(len(rows)==len(byregion) and set(byregion)<=set(expected),'unknown/duplicate capture region')
    if set(byregion)!=set(expected):return receipt
    advisory=[];unreviewed=[]
    for rid,r in byregion.items():
        need(r.get('provided_by')=='user' and r.get('capture_origin')=='user_screenshot','only actual user supplied captures are allowed')
        evidence(r['image']);evidence(r['reference_image'])
        checks=OVERVIEW_CHECKS if expected[rid]['scope']=='overview' else DETAIL_CHECKS
        need(set(r.get('checks',{}))==checks and all(v in {'PASS','FAIL','NOT REVIEWED'} for v in r['checks'].values()),'incomplete capture review checklist')
        need(r.get('reviewer') and r.get('observations'),'capture observations missing')
        evidence(r['review_report'])
        need(r.get('reviewer_mode') in {'user','tool'},'reviewer origin missing')
        if r['reviewer_mode']=='tool':
            te=r.get('tool_evidence',{})
            need(r['reviewer'] in {'look_at','call_omo_agent:multimodal-looker'} and te.get('call_id') and
                 te.get('input_image_sha256')==r['image']['sha256'],'tool image processing not evidenced')
        else:
            evidence(r['user_review_evidence'])
        if 'FAIL' in r['checks'].values():advisory.append(rid)
        if 'NOT REVIEWED' in r['checks'].values():unreviewed.append(rid)
    if advisory:
        receipt['advisory_failed_regions']=advisory
        unresolved_advisory=[]
        for rid in advisory:
            disposition=byregion[rid].get('user_disposition',{})
            if disposition.get('decision')!='ACCEPT_AS_IS':unresolved_advisory.append(rid)
            else:evidence(disposition['message_evidence'])
        if unresolved_advisory:
            receipt.update(status='REQUIRES_FIX',unresolved_advisory_regions=unresolved_advisory);return receipt
    if unresolved:return receipt
    receipt['status']='AWAITING_USER_ACCEPTANCE'
    approvalfile=work/'user_acceptance.json'
    if not approvalfile.exists():return receipt
    approval=read(approvalfile)
    need(approval.get('approved_by')=='user' and approval.get('candidate_revision')==revision and
         approval.get('capture_qa_sha256')==sha(capfile),'user approval is missing, stale or refers to another capture set')
    if approval.get('decision')!='APPROVED':return receipt
    need(approval.get('acknowledged_limitations') is True,'limited verification scope not acknowledged')
    evidence(approval['message_evidence'])
    if unreviewed:
        receipt['model_unreviewed_regions']=unreviewed
    receipt['status']='USER_ACCEPTED_WITH_LIMITATIONS'
    receipt['checks']['user_capture_acceptance']='APPROVED'
    return receipt


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('action',choices=['blueprint','lock','audit']);p.add_argument('--work',required=True);a=p.parse_args();work=Path(a.work)
    try:
        if a.action=='blueprint':
            print(json.dumps(validate_blueprint(read(work/'content_blueprint.json'),read(work/'reference_native.json')),ensure_ascii=False));return 0
        if a.action=='lock':
            validate_blueprint(read(work/'content_blueprint.json'),read(work/'reference_native.json'))
            consultation=validate_consultation(work)
            need(not (work/'plan_lock.json').exists(),'lock already exists; keep history and start a new revision')
            write(work/'plan_lock.json',{'blueprint_sha256':sha(work/'content_blueprint.json'),'reference_sha256':sha(work/'reference_native.json'),'consultation':consultation})
            print('LOCKED; not edited or reviewed');return 0
        result=audit(work);write(work/'com_receipt.json',result);print(result['status'])
        return 0 if result['status']=='USER_ACCEPTED_WITH_LIMITATIONS' else 2
    except Exception as e:
        if a.action=='audit':write(work/'com_receipt.json',{'schema':'kit.com-receipt.v1','status':'FAIL','errors':[str(e)]})
        print(type(e).__name__+': '+str(e));return 1

if __name__=='__main__':raise SystemExit(main())
