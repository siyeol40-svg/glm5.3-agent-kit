"""Synthetic OPC regression tests. No real company files or actual engine claims."""
import copy
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
import zipfile

SCRIPTS = Path(__file__).resolve().parents[2]/'.agents/skills/ppt-reference-fidelity/scripts'
sys.path.insert(0, str(SCRIPTS))
from common import NS, sha, write, read, digest
from validate_pptx import validate
from inspect_pptx import inspect
from compare_manifests import compare
from render_regions import crop_regions, CHECKS
from gate import verify_stage, validate_mapping

P, A, R, PR = NS['p'], NS['a'], NS['r'], NS['pr']

def fixture(path, text='SYNTHETIC OLD', mutate=None):
    rel = lambda body: f'<Relationships xmlns="{PR}">{body}</Relationships>'
    rr = lambda i,t,target: f'<Relationship Id="{i}" Type="{R}/{t}" Target="{target}"/>'
    shape = f'''<p:sp><p:nvSpPr><p:cNvPr id="4" name="card-title"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>
    <p:spPr><a:xfrm><a:off x="10" y="20"/><a:ext cx="300" cy="80"/></a:xfrm>
    <a:solidFill><a:srgbClr val="FFFFFF"/></a:solidFill><a:ln w="100"/><a:effectLst><a:outerShdw blurRad="20"/></a:effectLst></p:spPr>
    <p:txBody><a:bodyPr/><a:lstStyle/><a:p><a:r><a:rPr sz="2000" b="1"/><a:t>{text}</a:t></a:r></a:p></p:txBody></p:sp>'''
    group = lambda i,content: f'<p:grpSp><p:nvGrpSpPr><p:cNvPr id="{i}" name="group"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x="1" y="2"/><a:ext cx="1000" cy="1000"/><a:chOff x="0" y="0"/><a:chExt cx="1000" cy="1000"/></a:xfrm></p:grpSpPr>{content}</p:grpSp>'
    pic = '<p:pic><p:nvPicPr><p:cNvPr id="5" name="photo"/><p:cNvPicPr/><p:nvPr/></p:nvPicPr><p:blipFill><a:blip r:embed="img1"/><a:srcRect l="100"/></p:blipFill><p:spPr/></p:pic>'
    parts = {
      '[Content_Types].xml': '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="xml" ContentType="application/xml"/><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="png" ContentType="image/png"/></Types>',
      '_rels/.rels': rel(rr('r1','officeDocument','ppt/presentation.xml')),
      'ppt/presentation.xml': f'<p:presentation xmlns:p="{P}" xmlns:r="{R}"><p:sldIdLst><p:sldId id="256" r:id="s1"/></p:sldIdLst><p:sldSz cx="1000" cy="1000"/></p:presentation>',
      'ppt/_rels/presentation.xml.rels': rel(rr('s1','slide','slides/slide1.xml')),
      'ppt/slides/slide1.xml': f'<p:sld xmlns:p="{P}" xmlns:a="{A}" xmlns:r="{R}"><p:cSld><p:spTree><p:nvGrpSpPr/><p:grpSpPr/>{group(2,group(3,shape))}{pic}</p:spTree></p:cSld></p:sld>',
      'ppt/slides/_rels/slide1.xml.rels': rel(rr('img1','image','../media/image1.png')),
      'ppt/media/image1.png': b'synthetic-image-bytes-not-a-render',
    }
    if mutate:
        mutate(parts)
    with zipfile.ZipFile(path, 'w') as z:
        for name, data in parts.items():
            z.writestr(name, data)
    return path


class KitTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name); self.source = fixture(self.root/'source.pptx')
        self.result = fixture(self.root/'result.pptx', 'SYNTHETIC NEW')

    def bad(self, mutate, needle):
        path = fixture(self.root/'bad.pptx', mutate=mutate)
        report = validate(path)
        self.assertEqual(report['status'], 'FAIL')
        self.assertTrue(any(needle in e for e in report['errors']), report)

    def test_valid_synthetic_package(self):
        self.assertEqual(validate(self.source)['status'], 'PASS')

    def test_missing_media(self):
        self.bad(lambda p:p.pop('ppt/media/image1.png'), 'dangling')

    def test_missing_image_relationship(self):
        self.bad(lambda p:p.pop('ppt/slides/_rels/slide1.xml.rels'), 'unresolved')

    def test_orphan_slide(self):
        self.bad(lambda p:p.update({'ppt/slides/slide2.xml':'<s/>'}), 'orphan slide')

    def test_orphan_notes(self):
        self.bad(lambda p:p.update({'ppt/notesSlides/notesSlide1.xml':'<s/>'}), 'orphan notes')

    def test_dangling_relationship_owner(self):
        self.bad(lambda p:p.update({'ppt/slides/_rels/ghost.xml.rels':f'<Relationships xmlns="{PR}"/>'}), 'owner missing')

    def test_invalid_xml(self):
        self.bad(lambda p:p.update({'ppt/slides/slide1.xml':'<broken>'}), 'XML parse')

    def test_entities_rejected(self):
        self.bad(lambda p:p.update({'ppt/evil.xml':'<!DOCTYPE x [<!ENTITY y "z">]><x>&y;</x>'}), 'DTD/entities')

    def test_traversal_zip(self):
        self.bad(lambda p:p.update({'../bad.xml':'<s/>'}), 'unsafe')

    def test_traversal_target(self):
        def change(p):
            k='ppt/slides/_rels/slide1.xml.rels'; p[k]=p[k].replace('../media/image1.png','../../../outside.png')
        self.bad(change, 'escapes')

    def test_percent_encoded_target(self):
        def change(p):
            k='ppt/slides/_rels/slide1.xml.rels'; p[k]=p[k].replace('image1.png','image%31.png')
        self.assertEqual(validate(fixture(self.root/'encoded.pptx', mutate=change))['status'],'PASS')

    def test_invalid_slide_id(self):
        def change(p):
            k='ppt/presentation.xml'; p[k]=p[k].replace('id="256"','id="1"')
        self.bad(change,'slideId')

    def test_duplicate_relationship(self):
        def change(p):
            k='ppt/slides/_rels/slide1.xml.rels'; s=p[k]; p[k]=s.replace('</Relationships>',s[s.index('<Relationship Id'):s.index('</Relationships>')]+'</Relationships>')
        self.bad(change,'duplicate/invalid relationship')

    def test_nonimage_relationship(self):
        def change(p):
            k='ppt/slides/_rels/slide1.xml.rels'; p[k]=p[k].replace('/image"','/slide"')
        self.bad(change,'non-image')

    def test_corrupt_zip_cli(self):
        bad=self.root/'broken.pptx'; bad.write_bytes(b'not zip')
        output=self.root/'report.json'
        r=subprocess.run([sys.executable,str(SCRIPTS/'validate_pptx.py'),str(bad),'-o',str(output)],capture_output=True)
        self.assertEqual(r.returncode,1); self.assertEqual(read(output)['status'],'FAIL')

    def test_group_recursive_text(self):
        m=inspect(self.source); shapes=m['slides'][0]['shapes']
        self.assertEqual(shapes[2]['key'],'shape-2/shape-3/shape-4')
        self.assertEqual(shapes[2]['text'],['SYNTHETIC OLD'])
        self.assertTrue(shapes[3]['images'][0]['sha256'])

    def test_identity_compare(self):
        self.assertEqual(compare(inspect(self.source),inspect(self.source),{})['status'],'PASS')

    def test_changed_text_fail(self):
        self.assertEqual(compare(inspect(self.source),inspect(self.result),{})['status'],'FAIL')

    def test_exact_text_allowlist(self):
        a,b=inspect(self.source),inspect(self.result)
        change=compare(a,b,{})['changes']; self.assertEqual(len(change),1)
        mapping={'allowed_changes':[{**change[0],'reason':'synthetic replacement'}]}
        self.assertEqual(compare(a,b,mapping)['status'],'PASS')
        mapping['allowed_changes'][0]['after']='wrong'
        self.assertEqual(compare(a,b,mapping)['status'],'FAIL')

    def test_geometry_shadow_border_drift(self):
        for before,after in [('x="10"','x="99"'),('w="100"','w="99"'),('blurRad="20"','blurRad="1"')]:
            def change(p):
                k='ppt/slides/slide1.xml'; p[k]=p[k].replace(before,after)
            target=fixture(self.root/'drift.pptx',mutate=change)
            self.assertEqual(compare(inspect(self.source),inspect(target),{})['status'],'FAIL')

    def test_unexpected_added_shape(self):
        def change(p):
            k='ppt/slides/slide1.xml'; p[k]=p[k].replace('</p:spTree>','<p:sp><p:nvSpPr><p:cNvPr id="9"/></p:nvSpPr></p:sp></p:spTree>')
        target=fixture(self.root/'extra.pptx',mutate=change)
        self.assertEqual(compare(inspect(self.source),inspect(target),{})['status'],'FAIL')

    def test_media_drift(self):
        target=fixture(self.root/'media.pptx',mutate=lambda p:p.update({'ppt/media/image1.png':b'new'}))
        self.assertEqual(compare(inspect(self.source),inspect(target),{})['status'],'FAIL')

    def test_mapping_recursive_coverage_and_stale_content(self):
        ref=inspect(self.source); facts=self.root/'facts.txt'; facts.write_text('SYNTHETIC NEW photo evidence')
        mapping={'schema':'kit.mapping.v1','locked':True,'reference_sha256':sha(self.source),'slots':[
          {'slide':1,'target':'shape-2/shape-3/shape-4','role':'text','content_kind':'text','source_file':str(facts),'source_sha256':sha(facts),'source_quote':'SYNTHETIC NEW','expected_text':['SYNTHETIC NEW']},
          {'slide':1,'target':'shape-5','role':'photo','content_kind':'photo','source_file':str(facts),'source_sha256':sha(facts),'source_quote':'photo evidence','expected_image_sha256':[ref['slides'][0]['shapes'][3]['images'][0]['sha256']]}]}
        validate_mapping(mapping,ref,inspect(self.result))
        with self.assertRaises(ValueError): validate_mapping(mapping,ref,ref)
        m=copy.deepcopy(mapping); m['slots'].pop()
        with self.assertRaises(ValueError): validate_mapping(m,ref)
        m=copy.deepcopy(mapping); m['slots'][1]['content_kind']='diagram'
        with self.assertRaises(ValueError): validate_mapping(m,ref)
        facts.write_text('changed')
        with self.assertRaises(ValueError): validate_mapping(mapping,ref)

    def test_missing_final_gates(self):
        base=[sys.executable,str(SCRIPTS/'gate.py')]
        args=['--work',str(self.root/'run'),'--source',str(self.source),'--candidate',str(self.result)]
        self.assertEqual(subprocess.run(base+['init']+args,capture_output=True).returncode,0)
        self.assertEqual(subprocess.run(base+['advance']+args+['--stage','mapping'],capture_output=True).returncode,1)
        self.assertEqual(subprocess.run(base+['finalize']+args,capture_output=True).returncode,1)
        self.assertEqual(read(self.root/'run/final_receipt.json')['status'],'FAIL')

    def test_inspect_compare_clis(self):
        a,b=self.root/'ref.json',self.root/'out.json'
        for src,out in [(self.source,a),(self.result,b)]:
            self.assertEqual(subprocess.run([sys.executable,str(SCRIPTS/'inspect_pptx.py'),str(src),'-o',str(out)],capture_output=True).returncode,0)
        mapping=self.root/'map.json'; write(mapping,{'allowed_changes':[]})
        self.assertEqual(subprocess.run([sys.executable,str(SCRIPTS/'compare_manifests.py'),str(a),str(b),'--mapping',str(mapping),'-o',str(self.root/'diff.json')],capture_output=True).returncode,1)

    def test_duplicate_shape_id(self):
        def change(p):
            k='ppt/slides/slide1.xml'; p[k]=p[k].replace('id="5"','id="4"')
        self.bad(change,'shape id')

    def test_preflight_missing_engine_cli(self):
        output=self.root/'preflight.json'
        r=subprocess.run([sys.executable,str(SCRIPTS/'preflight.py'),'-o',str(output)],capture_output=True)
        self.assertEqual(r.returncode,1)
        self.assertEqual(read(output)['status'],'FAIL')



@unittest.skipUnless(importlib.util.find_spec('PIL'), 'optional Pillow not installed')
class ImageTests(unittest.TestCase):
    setUp = KitTests.setUp
    def test_region_crops_never_pass_qa(self):
        from PIL import Image
        image=self.root/'slide.png'; Image.new('RGB',(400,300),'white').save(image)
        plan={'artifact_sha256':sha(self.result),'slides':[{'slide':1,'image':str(image),'image_sha256':sha(image),
              'regions':[{'id':'s1-full','box':[0,0,400,300]},{'id':'s1-title','box':[0,0,400,50]}]}]}
        qa=crop_regions(plan,self.root/'qa'); self.assertEqual(qa['status'],'NOT REVIEWED')
        write(self.root/'region_plan.json',plan); write(self.root/'visual_qa.json',qa)
        with self.assertRaises(ValueError): verify_stage('visual',self.root,self.source,self.result)
        qa['status']='PASS'
        for r in qa['regions']:
            r.update(status='PASS',reviewer='synthetic-test-human',notes='Synthetic white image only; not a real PPT review.',checks={k:'PASS' for k in r['checks']})
        write(self.root/'visual_qa.json',qa); verify_stage('visual',self.root,self.source,self.result)
        qa['regions'][1]['checks']['text_clipping']='NOT REVIEWED'
        write(self.root/'visual_qa.json',qa)
        with self.assertRaises(ValueError): verify_stage('visual',self.root,self.source,self.result)

    def test_gate_full_synthetic_evidence_and_invalidation(self):
        # These fake engine/render logs exercise the evidence protocol only.
        # They explicitly do not establish an actual ppt-master or render run.
        from PIL import Image
        self.result.write_bytes(self.source.read_bytes())
        run=self.root/'run'; run.mkdir()
        ref=inspect(self.source)
        facts=self.root/'facts.txt'; facts.write_text('SYNTHETIC OLD photo evidence')
        image=self.root/'render.png'; Image.new('RGB',(400,300),'white').save(image)
        regions=[{'slide':1,'id':'s1-full','full_slide':True,'box':[0,0,400,300]},
                 {'slide':1,'id':'s1-card','targets':['shape-2/shape-3/shape-4','shape-5'],'box':[0,0,400,150]}]
        mapping={'schema':'kit.mapping.v1','locked':True,'reference_sha256':sha(self.source),
          'regions':regions,'allowed_changes':[],'slots':[
            {'slide':1,'target':'shape-2/shape-3/shape-4','role':'text','content_kind':'text','source_file':str(facts),'source_sha256':sha(facts),'source_quote':'SYNTHETIC OLD','expected_text':['SYNTHETIC OLD']},
            {'slide':1,'target':'shape-5','role':'photo','content_kind':'photo','source_file':str(facts),'source_sha256':sha(facts),'source_quote':'photo evidence','expected_image_sha256':[ref['slides'][0]['shapes'][3]['images'][0]['sha256']]}]}
        master=self.root/'synthetic-engine'; (master/'scripts').mkdir(parents=True)
        enginefile=master/'scripts/synthetic-protocol-marker.py'
        enginefile.write_text('# Synthetic inventory only; not an actual engine')
        write(run/'preflight.json',{'schema':'kit.preflight.v1','status':'PASS','ppt_master':str(master),
              'master_files':{'synthetic-protocol-marker.py':{'exists':True,'sha256':sha(enginefile)}},
              'imports':{k:{'status':'PASS'} for k in ('zipfile','xml.etree.ElementTree')}})
        loadinglog=run/'loading.log';loadinglog.write_text('SYNTHETIC loading evidence; not an actual engine observation')
        receipt=run/'bootstrap-receipt.json'
        write(receipt,{'schema':'kit.bootstrap-receipt.v1','status':'APPLIED',
                      'entries':[{'path':str(enginefile),'after':{'':sha(enginefile)}}]})
        write(run/'instruction_loading.json',{'schema':'kit.loading.v1','status':'PASS',
              'active_files':[{'path':str(enginefile),'sha256':sha(enginefile)}],
              'evidence':{'path':str(loadinglog),'sha256':sha(loadinglog)},
              'bootstrap_receipt':{'path':str(receipt),'sha256':sha(receipt)}})
        write(run/'route.json',{'route':'Edit Native PPTX','reason':'synthetic protocol test'})
        write(run/'authority_contract.json',{'design_sha256':sha(self.source),'facts':[{'path':str(facts),'sha256':sha(facts)}]})
        write(run/'reference_manifest.json',ref); write(run/'content_mapping.json',mapping)
        edit={'artifact_sha256':sha(self.result),'engine':'ppt-master','mode':'roundtrip','quality_gate':'PASS','delivery_gate':'PASS'}
        for key in ('guard_log','quality_log','export_log','delivery_log','readback'):
            f=run/(key+'.log')
            f.write_text('SYNTHETIC protocol evidence ONLY. Round-trip export summary: output_pages=1 passthrough=1 cloned_passthrough=0 patched=0 rebuilt=0')
            if key=='delivery_log': write(f,{'schema':'ppt-master.pptx-delivery-check.v1','status':'passed','errors':[]})
            edit[key]={'path':str(f),'sha256':sha(f),'exit_code':0}
        write(run/'edit_evidence.json',edit)
        write(run/'result_manifest.json',inspect(self.result)); write(run/'structural_diff.json',compare(ref,inspect(self.result),mapping))
        write(run/'package_integrity.json',validate(self.result))
        log=run/'render.log'; log.write_text('SYNTHETIC image creation, not actual PPT render')
        write(run/'render_evidence.json',{'artifact_sha256':sha(self.result),'renderer':'synthetic-test-only',
              'command':'synthetic-test-only','exit_code':0,'log':{'path':str(log),'sha256':sha(log)}})
        plan={'artifact_sha256':sha(self.result),'slides':[{'slide':1,'image':str(image),'image_sha256':sha(image),
              'regions':[{k:v for k,v in r.items() if k!='slide'} for r in regions]}]}
        snapshot={'schema':'kit.powerpoint-snapshot.v1','status':'PASS','artifact_sha256':sha(self.result),
                  'renderer':'synthetic-protocol-only','environment':{'test':True},'errors':[],
                  'slides':[{k:v for k,v in plan['slides'][0].items() if k!='regions'}],
                  'text_shapes':[{'slide':1,'key':'shape-2/shape-3/shape-4','text':'SYNTHETIC OLD','supported':True,
                                  'inner_box':[0,0,100,50],'text_bounds':[1,1,50,20],'auto_size':0,'font_available':True}]}
        write(run/'candidate_powerpoint.json',snapshot)
        write(run/'reference_powerpoint.json',snapshot)
        from layout_check import check_layout
        from pixel_diff import compare_pixels
        write(run/'layout_check.json',check_layout(snapshot,inspect(self.result),self.result))
        write(run/'pixel_diff.json',compare_pixels(snapshot,snapshot,mapping))
        write(run/'region_plan.json',plan)
        write(run/'visual_qa.json',crop_regions(plan,run/'qa'))
        args=['--work',str(run),'--source',str(self.source),'--candidate',str(self.result)]
        def gate(action,*extra):
            return subprocess.run([sys.executable,str(SCRIPTS/'gate.py'),action]+args+list(extra),capture_output=True,text=True)
        self.assertEqual(gate('init').returncode,0)
        from gate import STAGES
        for stage in STAGES[:-1]:
            r=gate('advance','--stage',stage); self.assertEqual(r.returncode,0,r.stdout+r.stderr)
        self.assertEqual(gate('advance','--stage','visual').returncode,1)
        qa=read(run/'visual_qa.json'); qa['status']='PASS'
        for row in qa['regions']:
            row.update(status='PASS',reviewer='synthetic-test-only',notes='Synthetic protocol verification only',checks={k:'PASS' for k in row['checks']})
        write(run/'visual_qa.json',qa)
        r=gate('advance','--stage','visual'); self.assertEqual(r.returncode,0,r.stdout+r.stderr)
        r=gate('finalize'); self.assertEqual(r.returncode,0,r.stdout+r.stderr)
        self.assertEqual(read(run/'final_receipt.json')['status'],'PASS')
        qa['regions'][1]['notes']='changed after review'; write(run/'visual_qa.json',qa)
        self.assertEqual(gate('finalize').returncode,1)
        self.assertEqual(read(run/'final_receipt.json')['status'],'FAIL')
        self.assertEqual(gate('invalidate','--stage','visual','--reason','new review').returncode,0)
        self.assertFalse((run/'final_receipt.json').exists())
        self.assertEqual(gate('advance','--stage','visual').returncode,0)
        self.result.write_bytes(b'changed candidate')
        self.assertEqual(gate('finalize').returncode,1)

    def test_region_cropping_bounds(self):
        from PIL import Image
        image=self.root/'slide.png'; Image.new('RGB',(100,100)).save(image)
        for box in ([0,0,200,100],[-1,0,10,10],[0,0,0,10]):
            with self.assertRaises(ValueError): crop_regions({'artifact_sha256':'x','slides':[{'slide':1,'image':str(image),'regions':[{'id':'bad','box':box}]}]},self.root/'qa')

if __name__ == '__main__':
    unittest.main()
