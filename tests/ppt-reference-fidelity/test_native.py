import copy
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'.agents/skills/ppt-reference-fidelity/scripts'))
sys.path.insert(0,str(ROOT/'scripts'))
from common import sha,write,read
from layout_check import check_layout
import bootstrap


class LayoutTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup)
        self.root=Path(self.tmp.name);self.candidate=self.root/'fixture.pptx';self.candidate.write_bytes(b'synthetic-measurement-unit-test')
        self.manifest={'artifact_sha256':sha(self.candidate),'slides':[{'shapes':[{'key':'shape-4','text':['New title']}]}]}
        self.snapshot={'schema':'kit.powerpoint-snapshot.v1','status':'PASS','artifact_sha256':sha(self.candidate),
            'renderer':'synthetic-only','environment':{'test':True},'errors':[],
            'text_shapes':[{'slide':1,'key':'shape-4','text':'New title','supported':True,
              'inner_box':[0,0,100,30],'text_bounds':[5,5,90,20],'auto_size':0,'font_available':True}]}

    def check(self):return check_layout(self.snapshot,self.manifest,self.candidate)
    def test_bounds_fit(self):self.assertEqual(self.check()['status'],'PASS')
    def test_overflow(self):
        self.snapshot['text_shapes'][0]['text_bounds']=[5,5,110,20]
        self.assertEqual(self.check()['status'],'FAIL')
    def test_unknown_group_not_reviewed(self):
        self.snapshot['text_shapes'][0].update(supported=False,reason='Group unqualified')
        self.assertEqual(self.check()['status'],'NOT REVIEWED')
    def test_autoshrink_not_pass(self):
        self.snapshot['text_shapes'][0]['auto_size']=2
        self.assertEqual(self.check()['status'],'NOT REVIEWED')
    def test_missing_font_not_pass(self):
        self.snapshot['text_shapes'][0]['font_available']=False
        self.assertEqual(self.check()['status'],'NOT REVIEWED')
    def test_missing_shape(self):
        self.snapshot['text_shapes']=[]
        self.assertEqual(self.check()['status'],'FAIL')
    def test_stale_snapshot(self):
        self.snapshot['artifact_sha256']='stale'
        self.assertEqual(self.check()['status'],'FAIL')
    def test_changed_text(self):
        self.snapshot['text_shapes'][0]['text']='Old title'
        self.assertEqual(self.check()['status'],'FAIL')
    def test_layout_cli(self):
        snapshot=self.root/'snapshot.json';manifest=self.root/'manifest.json';out=self.root/'layout.json'
        write(snapshot,self.snapshot);write(manifest,self.manifest)
        r=subprocess.run([sys.executable,str(ROOT/'.agents/skills/ppt-reference-fidelity/scripts/layout_check.py'),str(snapshot),'--manifest',str(manifest),'--candidate',str(self.candidate),'-o',str(out)],capture_output=True)
        self.assertEqual(r.returncode,0);self.assertEqual(read(out)['status'],'PASS')
    def test_invalid_bounds(self):
        self.snapshot['text_shapes'][0]['text_bounds']=[0,0,float('nan'),5]
        self.assertEqual(self.check()['status'],'FAIL')


class BootstrapTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup)
        self.root=Path(self.tmp.name);project=self.root/'project';project.mkdir()
        self.agent=project/'AGENTS.md';self.agent.write_text('Old company rule')
        self.old=project/'.agents/skills/old-ppt';self.old.mkdir(parents=True);(self.old/'SKILL.md').write_text('---\nname: old-ppt\n---\nold')
        self.overlay=self.root/'overlay.txt';self.overlay.write_text('Preserved company-only command')
        self.plan={'schema':'kit.bootstrap-plan.v1','conflicts_resolved':True,'loading_evidence':'Observed test scanner paths',
            'project_root':str(project),'backup_root':str(self.root/'backup'),
            'skill_destination':str(project/'.agents/skills/ppt-reference-fidelity'),
            'local_overlay_file':str(self.overlay),
            'agents_files':[{'path':str(self.agent),'expected_sha256':sha(self.agent),'review_note':'Required company rule moved to overlay'}],
            'disable_skill_dirs':[str(self.old)]}
        self.planfile=self.root/'plan.json';write(self.planfile,self.plan)

    def save(self):write(self.planfile,self.plan)
    def test_apply_verify_and_rollback(self):
        receipt=bootstrap.apply(self.planfile)
        self.assertIn('FILES VERIFIED',bootstrap.verify(receipt))
        self.assertIn('Preserved company-only command',self.agent.read_text())
        self.assertFalse(self.old.exists())
        self.assertTrue((Path(self.plan['skill_destination'])/'SKILL.md').is_file())
        self.assertIn('ROLLED BACK',bootstrap.rollback(receipt))
        self.assertEqual(self.agent.read_text(),'Old company rule');self.assertTrue(self.old.exists())
    def test_stale_instruction_refused(self):
        self.agent.write_text('Changed')
        with self.assertRaises(ValueError):bootstrap.apply(self.planfile)
    def test_repeated_apply_does_not_overwrite_backup(self):
        bootstrap.apply(self.planfile)
        with self.assertRaises(ValueError):bootstrap.apply(self.planfile)
    def test_ppt_master_kept(self):
        (self.old/'SKILL.md').write_text('---\nname: ppt-master\n---\nengine')
        with self.assertRaises(ValueError):bootstrap.apply(self.planfile)
    def test_backup_in_scanner_refused(self):
        self.plan['backup_root']=str(self.agent.parent/'backup');self.save()
        with self.assertRaises(ValueError):bootstrap.apply(self.planfile)
    def test_post_apply_edits_not_clobbered(self):
        receipt=bootstrap.apply(self.planfile);self.agent.write_text('Later manual changes')
        with self.assertRaises(ValueError):bootstrap.rollback(receipt)
    def test_bootstrap_cli(self):
        r=subprocess.run([sys.executable,str(ROOT/'scripts/bootstrap.py'),'check',str(self.planfile)],capture_output=True)
        self.assertEqual(r.returncode,0)
        for action,arg in [('apply',str(self.planfile)),('verify',str(self.root/'backup/receipt.json')),('rollback',str(self.root/'backup/receipt.json'))]:
            r=subprocess.run([sys.executable,str(ROOT/'scripts/bootstrap.py'),action,arg],capture_output=True)
            self.assertEqual(r.returncode,0,r.stdout+r.stderr)


@unittest.skipUnless(importlib.util.find_spec('PIL'),'optional Pillow missing')
class PixelTests(unittest.TestCase):
    def setUp(self):
        from PIL import Image
        self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup);self.root=Path(self.tmp.name)
        self.a=self.root/'a.png';self.b=self.root/'b.png'
        Image.new('RGB',(100,100),'white').save(self.a);Image.new('RGB',(100,100),'white').save(self.b)
        self.ref={'artifact_sha256':'source','renderer':'synthetic','environment':{'fonts':'same'},'slides':[{'slide':1,'image':str(self.a),'image_sha256':sha(self.a)}]}
        self.out=copy.deepcopy(self.ref);self.out['artifact_sha256']='candidate';self.out['slides'][0].update(image=str(self.b),image_sha256=sha(self.b))
        self.mapping={'reference_sha256':'source','slots':[{'slide':1,'target':'shape-4'}],'pixel_masks':[]}
    def result(self):
        from pixel_diff import compare_pixels
        return compare_pixels(self.ref,self.out,self.mapping)
    def change(self,x=10,y=10):
        from PIL import Image
        with Image.open(self.b) as im:im.putpixel((x,y),(0,0,0));im.save(self.b)
        self.out['slides'][0]['image_sha256']=sha(self.b)
    def test_pixel_cli(self):
        a,b,m,out=[self.root/n for n in ('ref.json','out.json','mapping.json','diff.json')]
        write(a,self.ref);write(b,self.out);write(m,self.mapping)
        r=subprocess.run([sys.executable,str(ROOT/'.agents/skills/ppt-reference-fidelity/scripts/pixel_diff.py'),str(a),str(b),'--mapping',str(m),'-o',str(out)],capture_output=True)
        self.assertEqual(r.returncode,0);self.assertEqual(read(out)['status'],'PASS')
    def test_identity(self):self.assertEqual(self.result()['status'],'PASS')
    def test_unexpected_pixel(self):
        self.change();self.assertEqual(self.result()['status'],'FAIL')
    def test_locked_mask(self):
        self.change();self.mapping['pixel_masks']=[{'slide':1,'box':[10,10,11,11],'targets':['shape-4'],'reason':'Planned title glyph change'}]
        self.assertEqual(self.result()['status'],'PASS')
        self.change(11,10);self.assertEqual(self.result()['status'],'FAIL')
    def test_excessive_mask(self):
        self.mapping['pixel_masks']=[{'slide':1,'box':[0,0,100,100],'targets':['shape-4'],'reason':'Not acceptable'}]
        self.assertEqual(self.result()['status'],'FAIL')
    def test_environment_change(self):
        self.out['environment']['fonts']='changed';self.assertEqual(self.result()['status'],'FAIL')
    def test_stale_render(self):
        self.change();self.out['slides'][0]['image_sha256']='stale';self.assertEqual(self.result()['status'],'FAIL')
    def test_unknown_target_mask(self):
        self.mapping['pixel_masks']=[{'slide':1,'box':[0,0,10,10],'targets':['unknown'],'reason':'bad'}]
        with self.assertRaises(ValueError):self.result()


@unittest.skipUnless(importlib.util.find_spec('PIL'),'optional Pillow missing')
class VisionEvidenceTests(unittest.TestCase):
    def setUp(self):
        from PIL import Image
        from render_regions import crop_regions
        from visual_review import prepare
        self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup);self.root=Path(self.tmp.name)
        image=self.root/'render.png';Image.new('RGB',(800,450),'white').save(image)
        self.plan={'artifact_sha256':'candidate','slides':[{'slide':1,'image':str(image),'image_sha256':sha(image),
            'regions':[{'id':'s1-full','full_slide':True,'box':[0,0,800,450]},
                       {'id':'s1-title','targets':['shape-4'],'box':[10,10,700,100]}]}]}
        self.ref={'artifact_sha256':'source','slides':[{'slide':1,'image':str(image),'image_sha256':sha(image)}]}
        self.mapping={'locked':True,'reference_sha256':'source','slots':[{'slide':1,'target':'shape-4','role':'text','content_kind':'text','expected_text':['New title']}]}
        self.qa=crop_regions(self.plan,self.root/'qa')
        self.queue=prepare(self.plan,self.ref,self.qa,self.mapping,self.root/'inputs')
        self.request=Path(self.queue['requests'][0]['request'])
        req=read(self.request)
        self.report=self.root/'report.json'
        write(self.report,{'region_id':req['region_id'],'checks':{k:'PASS' for k in req['checks']},'unreadable':False,'notes':'Synthetic report for record validation only'})

    def record(self):
        from visual_review import record
        return record(self.request,self.report,self.qa,self.mapping,'look_at','synthetic-invocation')
    def test_visual_clis(self):
        plan,ref,qa,mapping=[self.root/n for n in ('plan.json','reference.json','qa.json','mapping.json')]
        for p,v in ((plan,self.plan),(ref,self.ref),(qa,self.qa),(mapping,self.mapping)):write(p,v)
        script=str(ROOT/'.agents/skills/ppt-reference-fidelity/scripts/visual_review.py')
        r=subprocess.run([sys.executable,script,'prepare','--qa',str(qa),'--mapping',str(mapping),'--plan',str(plan),'--reference-renders',str(ref),'--output-dir',str(self.root/'cli-inputs'),'-o',str(self.root/'queue.json')],capture_output=True)
        self.assertEqual(r.returncode,0,r.stdout+r.stderr)
        r=subprocess.run([sys.executable,script,'record','--qa',str(qa),'--mapping',str(mapping),'--request',str(self.request),'--report',str(self.report),'--tool','look_at','--call-id','synthetic-only','-o',str(qa)],capture_output=True)
        self.assertEqual(r.returncode,0,r.stdout+r.stderr);self.assertEqual(read(qa)['status'],'NOT REVIEWED')
    def test_bounded_images_and_overview_scope(self):
        from PIL import Image
        for entry in self.queue['requests']:
            with Image.open(entry['image']) as im:self.assertLessEqual(max(im.size),1024)
        overview=next(x for x in self.qa['regions'] if x['id']=='s1-full')
        self.assertEqual(set(overview['checks']),{'alignment','hierarchy','reference_structure'})
    def test_record_not_complete_until_all_regions(self):
        result=self.record();self.assertEqual(result['status'],'NOT REVIEWED')
        from visual_review import verify_evidence
        row=next(x for x in result['regions'] if x['id']==read(self.request)['region_id'])
        verify_evidence(row,result,self.mapping)
    def test_unreadable_never_passes(self):
        report=read(self.report);report['unreadable']=True;write(self.report,report)
        result=self.record();self.assertTrue(all(x=='NOT REVIEWED' for x in result['regions'][1]['checks'].values()))
    def test_report_missing_check(self):
        report=read(self.report);report['checks'].pop('overflow');write(self.report,report)
        with self.assertRaises(ValueError):self.record()
    def test_request_mapping_stale(self):
        self.mapping['slots'][0]['expected_text']=['changed']
        with self.assertRaises(ValueError):self.record()
    def test_natural_language_not_silently_passed(self):
        self.report.write_text('Everything looks fine')
        with self.assertRaises(json.JSONDecodeError):self.record()

if __name__=='__main__':unittest.main()
