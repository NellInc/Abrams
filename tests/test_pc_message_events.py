import copy
import struct
import unittest
from tools.pc_message_events import MessageAssignments,visible_messages


class MessageTests(unittest.TestCase):
    def setUp(self):
        self.events=MessageAssignments()
        self.regs={'cs':0x100,'ds':0x1AE0}

    def assign(self,primary=b"We've been hit! Bearing ",secondary=b'043',ip=0x3D6A):
        ram=bytearray(640*1024);ds=self.regs['ds']*16
        for at,pointer,text in [(0x094C,0x095D,primary),(0x646A,0x6472,secondary),(0x094E,0x0200,b'Hold position.')]:
            struct.pack_into('<H',ram,ds+at,pointer if text is not None else 0)
            if text is not None:ram[ds+pointer:ds+pointer+len(text)+1]=text+b'\0'
        ram[ds+0x6464]=3
        self.events.observe(bytes(ram),self.regs,ip)
        return ram

    def run_part(self,text,part=0,radio=False):
        run={'kind':'radio' if radio else 'crew_secondary' if part else 'crew_primary',
             'source_pointer':0x0200 if radio else 0x6472 if part else 0x095D,
             'text':text.decode('cp437'),'rect':[190 if part else 46,112,6*len(text),6],
             'speaker':None if radio else 3,'font_sha256':'f'*64,'page_offset':0,
             'foreground':0,'background':14,'transparent':True,'draw_sequence':part+1,'pixel_sha256':'a'*64}
        self.events.bind(run,text)
        return run

    def test_all_parts_of_one_assignment_required(self):
        self.assign()
        a=self.run_part(b"We've been hit! Bearing ");b=self.run_part(b'043',1)
        self.assertEqual(visible_messages([a]),[])
        self.assertEqual(visible_messages([b]),[])
        message,=visible_messages([b,a])
        self.assertEqual(message['text'],"We've been hit! Bearing 043")
        self.assertEqual((message['id'],message['assignment_ip'],message['speaker']),(1,0x3D6A,3))
        self.assertEqual(len(message['parts']),2)
        self.assertNotIn('043',str(a['message_ref']))

    def test_identical_reassignment_gets_distinct_identity_and_cannot_mix_parts(self):
        self.assign();a=self.run_part(b"We've been hit! Bearing ")
        self.assign();b=self.run_part(b'043',1)
        self.assertNotEqual(a['message_ref']['id'],b['message_ref']['id'])
        self.assertEqual(visible_messages([a,b]),[])
        new=self.run_part(b"We've been hit! Bearing ")
        self.assertEqual(visible_messages([new,b])[0]['id'],2)

    def test_unobserved_and_changed_strings_never_claim_identity(self):
        a=self.run_part(b"We've been hit! Bearing ")
        self.assertNotIn('message_ref',a)
        self.assign();self.assertNotIn('message_ref',self.run_part(b'140',1))
        altered=self.run_part(b'043',1);altered.pop('message_ref');altered['source_pointer']=1
        self.events.bind(altered,b'043');self.assertNotIn('message_ref',altered)
        altered['source_pointer']=0x6472;altered['speaker']=1
        self.events.bind(altered,b'043');self.assertNotIn('message_ref',altered)

    def test_single_part_crew_and_reopened_radio(self):
        self.assign(b'No smoke mortars left',None,0x3D8E)
        message,=visible_messages([self.run_part(b'No smoke mortars left')])
        self.assertEqual(message['text'],'No smoke mortars left')
        self.assign(ip=0x3CD4)
        # Assignment alone has no public text; a verified displayed run is needed.
        self.assertEqual(visible_messages([]),[])
        old=self.run_part(b'Hold position.',radio=True)
        self.assign(ip=0x3F73)
        new=self.run_part(b'Hold position.',radio=True)
        self.assertNotEqual(old['message_ref']['id'],new['message_ref']['id'])
        self.assertEqual(visible_messages([new])[0]['channel'],'radio')

    def test_different_pages_geometry_style_or_duplicate_parts_do_not_group(self):
        self.assign();a=self.run_part(b"We've been hit! Bearing ");b=self.run_part(b'043',1)
        for field,value in [('page_offset',8192),('font_sha256','e'*64),('speaker',0),
                            ('foreground',2),('background',3),('transparent',False),('rect',[191,112,18,6])]:
            wrong=copy.deepcopy(b);wrong[field]=value
            self.assertEqual(visible_messages([a,wrong]),[],field)
        self.assertEqual(visible_messages([a,a,b]),[])
        wrong=copy.deepcopy(b);wrong['message_ref']['ip']=0x3D8E
        self.assertEqual(visible_messages([a,wrong]),[])

    def test_unsupported_new_assignment_invalidates_old_identity_and_history_bounded(self):
        self.assign();self.assign(b'',None)
        self.assertNotIn('message_ref',self.run_part(b"We've been hit! Bearing "))
        self.assertEqual(self.events.counts['unsupported'],1)
        ram=self.assign()
        for _ in range(600):self.events.observe(bytes(ram),self.regs,0x3D6A)
        self.assertEqual(len(self.events.history),512)
        self.assertEqual(self.events.sequence,603)

    def test_schema_rejects_unknown_addresses_and_segments(self):
        ram=self.assign()
        with self.assertRaisesRegex(ValueError,'assignment'):self.events.observe(bytes(ram),self.regs,123)
        with self.assertRaisesRegex(ValueError,'snapshot'):self.events.observe(b'',self.regs,0x3D6A)
        with self.assertRaisesRegex(ValueError,'snapshot'):self.events.observe(bytes(ram),{'cs':0,'ds':1},0x3D6A)


if __name__=='__main__':unittest.main()
