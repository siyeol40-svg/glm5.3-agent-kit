"""Synthetic unit state machine: no Office, DRM, vision or actual user approvals."""
import copy
import subprocess
import sys
import unittest
import test_com_profile as fixture
import unit_gate as u
import com_workflow as c


class UnitGateTests(unittest.TestCase):
    def setUp(self):
        self.f=fixture.ComProfileTests(methodName='runTest');self.f.setUp();self.addCleanup(self.f.doCleanups)
        self.root=self.f.root;self.analysis=self.root/'analysis-new.json'
        (self.root/'unit_state.json').unlink();u.init(self.root)
        self.a={'unit_id':'slide-1','facts':['Frame readback'],'source_refs':['Synthetic new source'],
                'adaptation':'New heading and new photo','unknowns':[],'questions':[],
                'before':self.f.ev(self.root/'unit-baseline.json'),
                'checks':[{'id':'heading','kind':'text','target':'shape-4','expected':'NEW'},
                          {'id':'photo-frame','kind':'property','target':'shape-5','property':'geometry','expected':[10,60,300,200,0]}]}
        self.write()

    def write(self):c.write(self.analysis,self.a)
    def prepare(self):u.analyze(self.root,'slide-1',self.analysis);u.ready(self.root,'slide-1')
    def apply(self):return u.check(self.root,'slide-1',self.root/'result_native.json',self.f.log)

    def test_ready_needs_analysis(self):
        with self.assertRaises(ValueError):u.ready(self.root,'slide-1')
    def test_unknown_must_be_a_question(self):
        self.a['unknowns']=[{'description':'Missing photo'}];self.write()
        with self.assertRaises(ValueError):u.analyze(self.root,'slide-1',self.analysis)
    def test_question_blocks_editing(self):
        self.a['questions']=[{'id':'q1','question':'Reuse old photo?'}];self.write()
        self.assertEqual(u.analyze(self.root,'slide-1',self.analysis)['status'],'NEEDS_INPUT')
        with self.assertRaises(ValueError):u.ready(self.root,'slide-1')
    def test_real_answer_can_unlock(self):
        self.a['unknowns']=[{'description':'Photo permission','question_id':'q1'}]
        self.a['questions']=[{'id':'q1','question':'Reuse?', 'resolution':'ANSWERED','answer':'Use new asset', 'message_evidence':self.f.ev(self.f.log)}]
        self.write();self.prepare();self.assertEqual(self.apply()['status'],'NONVISUAL_CHECKED')
    def test_waiver_without_alternative_rejected(self):
        self.a['questions']=[{'id':'q1','question':'Missing asset?', 'resolution':'USER_WAIVED','answer':'Proceed', 'message_evidence':self.f.ev(self.f.log)}]
        self.write()
        with self.assertRaises(ValueError):u.analyze(self.root,'slide-1',self.analysis)
    def test_readback_required(self):
        with self.assertRaises(ValueError):self.apply()
    def test_mismatched_content_blocks_finish(self):
        self.a['checks'][0]['expected']='DIFFERENT';self.write();self.prepare()
        self.assertEqual(self.apply()['status'],'REQUIRES_FIX')
        with self.assertRaises(ValueError):u.finish(self.root)
    def test_invalidation_retains_history_and_can_retry(self):
        self.a['checks'][0]['expected']='DIFFERENT';self.write();self.prepare();self.apply()
        u.invalidate(self.root,'slide-1','Correct a wrong expectation after explicit user clarification')
        self.assertTrue(c.read(self.root/'unit_state.json')['history'])
        self.analysis=self.root/'analysis-retry.json';self.a['before']=self.f.ev(self.root/'result_native.json')
        self.a['checks'][0]['expected']='NEW';self.write();self.prepare();self.apply()
        self.assertEqual(u.finish(self.root)['status'],'NONVISUAL_CHECKED_WITH_LIMITATIONS')
    def test_before_must_match_current_reality(self):
        altered=copy.deepcopy(self.f.ref);altered['identity']=self.f.result['identity'];altered['slides'][0]['shapes'][0]['text']='Unexpected'
        c.write(self.root/'altered-before.json',altered);self.a['before']=self.f.ev(self.root/'altered-before.json');self.write()
        u.analyze(self.root,'slide-1',self.analysis)
        with self.assertRaises(ValueError):u.ready(self.root,'slide-1')
    def test_unobservable_size_claim_rejected(self):
        self.a['checks'][1]['property']='effective_font_size';self.write()
        u.analyze(self.root,'slide-1',self.analysis)
        with self.assertRaises(ValueError):u.ready(self.root,'slide-1')
    def test_hidden_null_cannot_be_asserted(self):
        self.a['checks'][1]['property']='hidden';self.a['checks'][1]['expected']=False;self.write()
        u.analyze(self.root,'slide-1',self.analysis)
        with self.assertRaises(ValueError):u.ready(self.root,'slide-1')
    def test_modified_analysis_invalidates_ticket(self):
        self.prepare();self.a['adaptation']='Changed after READY';self.write()
        with self.assertRaises(ValueError):self.apply()
    def test_final_reopen_must_match(self):
        self.prepare();self.apply()
        altered=copy.deepcopy(self.f.result);altered['slides'][0]['shapes'][0]['text']='Changed'
        c.write(self.root/'new-final.json',altered)
        # Keep the after evidence intact; final snapshot is a separate file in real runs.
        c.write(self.root/'checked.json',self.f.result)
        state=c.read(self.root/'unit_state.json');state['latest']=self.f.ev(self.root/'checked.json')
        state['units']['slide-1']['after']=state['latest'];c.write(self.root/'unit_state.json',state)
        c.write(self.root/'result_native.json',altered)
        with self.assertRaises(ValueError):u.finish(self.root)
    def test_original_readback_change_blocks_audit(self):
        self.prepare();self.apply();altered=copy.deepcopy(self.f.ref)
        altered['slides'][0]['shapes'][0]['text']='Original changed'
        c.write(self.root/'source_readback.json',altered)
        with self.assertRaisesRegex(ValueError,'original readable'):c.audit(self.root)
    def test_dependency_and_outside_unit_checks(self):
        plan=c.read(self.root/'unit_plan.json');plan['units']=[
            {'id':'title','slide':1,'purpose':'Title','targets':['shape-4'],'depends_on':[]},
            {'id':'photo','slide':1,'purpose':'Photo','targets':['shape-5'],'depends_on':['title']}]
        c.write(self.root/'unit_plan.json',plan);(self.root/'unit_state.json').unlink();u.init(self.root)
        self.a['unit_id']='photo';self.a['checks']=self.a['checks'][1:];self.write()
        u.analyze(self.root,'photo',self.analysis)
        with self.assertRaisesRegex(ValueError,'dependency'):u.ready(self.root,'photo')
        self.analysis=self.root/'title.json';self.a['unit_id']='title';self.a['checks']=[{'id':'text','kind':'text','target':'shape-4','expected':'NEW'}]
        self.write();u.analyze(self.root,'title',self.analysis);u.ready(self.root,'title')
        changed=copy.deepcopy(self.f.result);changed['slides'][0]['shapes'][1]['geometry'][0]=99
        c.write(self.root/'wrong.json',changed)
        self.assertEqual(u.check(self.root,'title',self.root/'wrong.json',self.f.log)['status'],'REQUIRES_FIX')
        with self.assertRaises(ValueError):u.ready(self.root,'photo')
        self.assertEqual(set(u.invalidate(self.root,'title','Repair outside-unit edit')['units']),{'title','photo'})
    def test_success_still_preserves_limitations(self):
        self.prepare();self.apply();r=u.finish(self.root)
        self.assertIn('WITH_LIMITATIONS',r['status']);self.assertEqual(len(r['limitations']),6)
    def test_cli_unready_fails(self):
        r=subprocess.run([sys.executable,str(fixture.SCRIPTS/'unit_gate.py'),'ready','--work',str(self.root),'--unit','slide-1'],capture_output=True)
        self.assertEqual(r.returncode,1)


if __name__=='__main__':unittest.main()
