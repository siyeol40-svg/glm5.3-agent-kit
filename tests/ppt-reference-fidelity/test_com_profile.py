"""Synthetic protocol tests; no Windows COM, DRM, actual vision call or user approval."""
import copy
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

SCRIPTS=Path(__file__).resolve().parents[2]/'.agents/skills/ppt-reference-fidelity/scripts'
sys.path.insert(0,str(SCRIPTS))
import com_workflow as c


class ComProfileTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup);self.root=Path(self.tmp.name)
        self.source=self.root/'reference.pptx';self.source.write_bytes(b'opaque reference stand-in')
        self.candidate=self.root/'candidate.pptx';self.candidate.write_bytes(b'opaque candidate stand-in')
        self.log=self.root/'operation.log';self.log.write_text('Synthetic test log only; not actual COM/vision/user evidence')
        self.doc=self.root/'AGENTS.md';self.doc.write_text('synthetic loaded instruction')
        receipt=self.root/'bootstrap-receipt.json';c.write(receipt,{'status':'APPLIED'})
        c.write(self.root/'instruction_loading.json',{'status':'PASS','active_files':[self.ev(self.doc)],'evidence':self.ev(self.log),'bootstrap_receipt':self.ev(receipt)})
        self.ref={'schema':'kit.com-manifest.v1','status':'PASS','identity':c.identity(self.source),'slide_size':[960,540],
                  'errors':[],'unreadable_properties':[],'slides':[{'slide':1,'shapes':[
                      {'key':'shape-4','type':17,'text':'OLD','geometry':[10,10,300,40,0]},
                      {'key':'shape-5','type':13,'text':'','geometry':[10,60,300,200,0]}]}]}
        self.result=copy.deepcopy(self.ref);self.result['identity']=c.identity(self.candidate)
        self.result['slides'][0]['shapes'][0]['text']='NEW'
        self.plan={'schema':'kit.content-blueprint.v1','locked':True,'reference_revision':c.digest(self.ref['identity']),
                   'allowed_native_changes':[{'path':'/shapes/1:shape-4/text','before':'OLD','after':'NEW','reason':'New topic title'}],
                   'slides':[{'slide':1,'message':'New message','audience_takeaway':'Understand the new mechanism',
                     'visual_story':'New photo demonstrates the new subject',
                     'visual_options':[{'id':'A','concept':'A new subject photo with concise evidence callouts','source_refs':['new source']},
                                       {'id':'B','concept':'A source-grounded process explanation in the bottom diagram','source_refs':['new source']}],
                     'selected_option':'A','selection_reason':'Photographic evidence fits this source frame',
                     'design_anchors':['Frame and spacing'],
                     'source_refs':['user supplied new topic'],
                     'classification':[{'target':'shape-4','role':'text','reason':'Heading'},
                                       {'target':'shape-5','role':'photo','reason':'Old subject photo must change'}],
                     'visual_slots':[{'id':'photo-1','target':'shape-5','role':'photo','decision':'replace',
                        'rationale':'Old photo does not support new topic','source_refs':['new subject photo'],
                        'new_concept':'Show the new subject and relevant mechanism','implementation':'Approved native photo replacement',
                        'acceptance_criteria':['New subject visible; old photo absent; preserve frame'],
                        'asset_origin':'user_supplied','fact_role':'evidence'}],
                     'text_slots':[{'target':'shape-4','source_ref':'new topic heading','expected_text':'NEW'}],
                     'capture_regions':[{'id':'s1-full','scope':'overview'},
                                        {'id':'s1-content','scope':'detail','targets':['shape-4','shape-5']}]}]}
        self.asset=self.root/'new-photo.bin';self.asset.write_bytes(b'synthetic asset bytes; not a real image')
        self.impl={'candidate_revision':c.digest(self.result['identity']),'items':[{'id':'photo-1','decision':'replace',
                   'result_targets':['shape-5'],'observations':'Synthetic protocol trace only',
                   'implemented_concept':self.plan['slides'][0]['visual_slots'][0]['new_concept'],
                   'operation_log':self.ev(self.log),'asset':self.ev(self.asset)}]}
        self.save()
        c.write(self.root/'com_capabilities.json',{'route':'COM_USER_CAPTURE','operations':{
          op:{'status':'PASS','exit_code':0,'log':self.ev(self.log)} for op in ('open','read_objects','create_copy','edit','save','reopen')}})
        c.write(self.root/'known_issues.json',{'issues':[]})
        self.lock()

    def ev(self,p):return {'path':str(p),'sha256':c.sha(p)}
    def save(self):
        for name,obj in [('reference_native.json',self.ref),('result_native.json',self.result),('content_blueprint.json',self.plan),('visual_implementation.json',self.impl)]:c.write(self.root/name,obj)
    def lock(self):c.write(self.root/'plan_lock.json',{'blueprint_sha256':c.sha(self.root/'content_blueprint.json'),'reference_sha256':c.sha(self.root/'reference_native.json')})
    def capture(self):
        img=self.root/'user-capture.png';img.write_bytes(b'synthetic capture stand-in; no real review')
        rows=[]
        for r in self.plan['slides'][0]['capture_regions']:
            checks=c.OVERVIEW_CHECKS if r['scope']=='overview' else c.DETAIL_CHECKS
            rows.append({'id':r['id'],'provided_by':'user','capture_origin':'user_screenshot','image':self.ev(img),
                         'reference_image':self.ev(img),'checks':{k:'PASS' for k in checks},
                         'reviewer':'look_at','reviewer_mode':'tool','tool_evidence':{'call_id':'synthetic-not-real','input_image_sha256':c.sha(img)},'observations':'Synthetic test only; not a quality finding','review_report':self.ev(self.log)})
        qa={'candidate_revision':c.digest(self.result['identity']),'regions':rows};c.write(self.root/'capture_qa.json',qa);return qa
    def approve(self):
        c.write(self.root/'user_acceptance.json',{'approved_by':'user','decision':'APPROVED',
            'candidate_revision':c.digest(self.result['identity']),'capture_qa_sha256':c.sha(self.root/'capture_qa.json'),
            'acknowledged_limitations':True,'message_evidence':self.ev(self.log)})

    def test_blueprint(self):self.assertEqual(c.validate_blueprint(self.plan,self.ref)['status'],'PASS')
    def test_missing_photo_decision_rejected(self):
        self.plan['slides'][0]['visual_slots']=[]
        with self.assertRaises(ValueError):c.validate_blueprint(self.plan,self.ref)
    def test_old_photo_not_decoration(self):
        self.plan['slides'][0]['visual_slots'][0]['decision']='retain_decoration'
        with self.assertRaises(ValueError):c.validate_blueprint(self.plan,self.ref)
    def test_old_visual_needs_user_permission(self):
        self.plan['slides'][0]['visual_slots'][0]['decision']='retain_content_approved'
        with self.assertRaises(ValueError):c.validate_blueprint(self.plan,self.ref)
    def test_generated_photo_not_factual_evidence(self):
        self.plan['slides'][0]['visual_slots'][0]['asset_origin']='illustrative_generated'
        with self.assertRaises(ValueError):c.validate_blueprint(self.plan,self.ref)
    def test_visual_options_must_be_concrete_and_selected(self):
        self.plan['slides'][0]['visual_options']=[]
        with self.assertRaises(ValueError):c.validate_blueprint(self.plan,self.ref)
    def test_no_visual_concept_rejected(self):
        self.plan['slides'][0]['visual_slots'][0].pop('new_concept')
        with self.assertRaises(ValueError):c.validate_blueprint(self.plan,self.ref)
    def test_inventory_coverage(self):
        self.plan['slides'][0]['classification'].pop()
        with self.assertRaises(ValueError):c.validate_blueprint(self.plan,self.ref)
    def test_no_captures_never_visual_pass(self):self.assertEqual(c.audit(self.root)['status'],'AWAITING_USER_CAPTURE')
    def test_model_pass_never_user_acceptance(self):
        self.capture();self.assertEqual(c.audit(self.root)['status'],'AWAITING_USER_ACCEPTANCE')
    def test_auto_generated_capture_rejected(self):
        qa=self.capture();qa['regions'][0]['capture_origin']='automatic_export';c.write(self.root/'capture_qa.json',qa)
        with self.assertRaises(ValueError):c.audit(self.root)
    def test_photo_cannot_evade_inventory_as_decoration(self):
        self.plan['slides'][0]['classification'][1]['role']='decoration'
        self.plan['slides'][0]['visual_slots']=[]
        with self.assertRaises(ValueError):c.validate_blueprint(self.plan,self.ref)
    def test_missing_tool_input_evidence(self):
        qa=self.capture();qa['regions'][0].pop('tool_evidence');c.write(self.root/'capture_qa.json',qa)
        with self.assertRaises(ValueError):c.audit(self.root)
    def test_user_can_correct_an_advisory_false_positive(self):
        qa=self.capture();qa['regions'][1]['checks']['alignment']='FAIL'
        qa['regions'][1]['user_disposition']={'decision':'ACCEPT_AS_IS','message_evidence':self.ev(self.log)}
        c.write(self.root/'capture_qa.json',qa);self.approve()
        self.assertEqual(c.audit(self.root)['status'],'USER_ACCEPTED_WITH_LIMITATIONS')
    def test_office_bytes_refused(self):
        with self.assertRaises(ValueError):c.sha(self.candidate)
    def test_model_failure_requires_fix(self):
        qa=self.capture();qa['regions'][1]['checks']['content_relevance']='FAIL';c.write(self.root/'capture_qa.json',qa)
        self.assertEqual(c.audit(self.root)['status'],'REQUIRES_FIX')
    def test_user_acceptance_keeps_limitations(self):
        self.capture();self.approve();out=c.audit(self.root)
        self.assertEqual(out['status'],'USER_ACCEPTED_WITH_LIMITATIONS')
        self.assertEqual(out['checks']['package_integrity'],'NOT_CHECKED_DRM_PROFILE')
    def test_user_issue_cannot_be_self_closed(self):
        self.capture();c.write(self.root/'known_issues.json',{'issues':[{'id':'old-photo','reported_by':'user','report_evidence':self.ev(self.log),'status':'RESOLVED','fix_description':'Claimed fixed','confirmed_by':'agent'}]})
        with self.assertRaises(ValueError):c.audit(self.root)
    def test_open_issue_visible_even_without_capture(self):
        c.write(self.root/'known_issues.json',{'issues':[{'id':'old-photo','reported_by':'user','report_evidence':self.ev(self.log),'status':'OPEN'}]})
        result=c.audit(self.root)
        self.assertEqual(result['status'],'REQUIRES_FIX');self.assertIn('old-photo',result['unresolved_issues'])
    def test_open_issue_blocks_acceptance(self):
        self.capture();self.approve();c.write(self.root/'known_issues.json',{'issues':[{'id':'old-photo','reported_by':'user','report_evidence':self.ev(self.log),'status':'OPEN'}]})
        self.assertEqual(c.audit(self.root)['status'],'REQUIRES_FIX')
    def test_stale_capture_bytes(self):
        self.capture();(self.root/'user-capture.png').write_bytes(b'changed')
        with self.assertRaises(ValueError):c.audit(self.root)
    def test_stale_metadata_revision(self):
        self.candidate.write_bytes(b'candidate changed after snapshot')
        with self.assertRaises(ValueError):c.audit(self.root)
    def test_changed_plan_invalidates_lock(self):
        self.plan['slides'][0]['message']='changed after locking';self.save()
        with self.assertRaises(ValueError):c.audit(self.root)
    def test_no_presentation_byte_read(self):
        original=c.sha
        def forbid_pptx(path):
            if Path(path).suffix=='.pptx':raise AssertionError('Protected presentation bytes must not be opened')
            return original(path)
        with patch.object(c,'sha',forbid_pptx):self.assertEqual(c.audit(self.root)['status'],'AWAITING_USER_CAPTURE')
    def test_supported_native_text_overflow(self):
        shape=self.result['slides'][0]['shapes'][0]
        shape['parent']='';shape['text_frame']=[0,0,0,0,0,1,-1,1];shape['text_bounds']=[10,10,500,30]
        self.ref['slides'][0]['shapes'][0]['parent']='';self.ref['slides'][0]['shapes'][0]['text_frame']=[0,0,0,0,0,1,-1,1]
        self.save();self.lock()
        with self.assertRaises(ValueError):c.audit(self.root)
    def test_locked_native_creation_region(self):
        self.plan['slides'][0]['visual_slots'][0]['native_policy']={'allow_new':True,'bounds':[10,60,300,200],'name_prefix':'new-topic-','max_new_objects':2,'remove_targets':['shape-5']}
        self.plan['slides'][0]['visual_slots'][0]['decision']='rebuild'
        self.impl['items'][0].update(decision='rebuild',result_targets=['shape-9'])
        self.result['slides'][0]['shapes'][1]={'key':'shape-9','type':1,'name':'new-topic-process','text':'','geometry':[10,60,300,200,0]}
        self.save();self.lock()
        self.assertEqual(c.audit(self.root)['status'],'AWAITING_USER_CAPTURE')
        self.result['slides'][0]['shapes'][1]['geometry'][2]=301;self.save()
        with self.assertRaises(ValueError):c.audit(self.root)
    def test_unknown_properties_not_falsely_verified(self):
        self.result['unreadable_properties']=['SmartArt details'];self.save();self.capture();self.approve()
        out=c.audit(self.root);self.assertEqual(out['checks']['native_properties'],'PARTIAL')
    def test_unplanned_style_change(self):
        self.result['slides'][0]['shapes'][1]['geometry'][0]=100;self.save()
        with self.assertRaises(ValueError):c.audit(self.root)
    def test_missing_new_photo_asset(self):
        self.impl['items'][0].pop('asset');self.save()
        with self.assertRaises(ValueError):c.audit(self.root)
    def test_missing_visual_implementation(self):
        self.impl['items']=[];self.save()
        with self.assertRaises(ValueError):c.audit(self.root)
    def test_cli(self):
        for action,code in [('blueprint',0),('audit',2)]:
            r=subprocess.run([sys.executable,str(SCRIPTS/'com_workflow.py'),action,'--work',str(self.root)],capture_output=True)
            self.assertEqual(r.returncode,code,r.stdout+r.stderr)
        self.capture();self.approve()
        r=subprocess.run([sys.executable,str(SCRIPTS/'com_workflow.py'),'audit','--work',str(self.root)],capture_output=True)
        self.assertEqual(r.returncode,0,r.stdout+r.stderr)

if __name__=='__main__':unittest.main()
