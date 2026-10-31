import importlib.util
import pathlib
import struct
import unittest

spec=importlib.util.spec_from_file_location('packager',pathlib.Path(__file__).parents[1]/'scripts/package_ipa.py')
packager=importlib.util.module_from_spec(spec)
spec.loader.exec_module(packager)

def image(padding=4096, encrypted=0):
    header=struct.pack('<8I',0xfeedfacf,0x100000c,0,2,3,152+24+16,0,0)
    segment=bytearray(152)
    struct.pack_into('<II',segment,0,0x19,152)
    struct.pack_into('<I',segment,64,1)
    struct.pack_into('<I',segment,72+48,padding)
    enc=struct.pack('<6I',0x2c,24,padding,16,encrypted,0)
    sig=struct.pack('<4I',0x1d,16,padding+16,16)
    data=header+segment+enc+sig
    return data+b'\0'*max(0,padding-len(data))+b'ABCD'*16

class PackageTests(unittest.TestCase):
    def test_inserts_load_without_moving_code(self):
        original=image();result=packager.patch_executable(original)
        self.assertEqual(original[4096:],result[4096:])
        self.assertEqual(len(original),len(result))
        pos=32;commands=[]
        for _ in range(struct.unpack_from('<I',result,16)[0]):
            cmd,size=struct.unpack_from('<II',result,pos);commands.append(cmd);pos+=size
        self.assertIn(0xc,commands);self.assertNotIn(0x1d,commands)
        self.assertIn(packager.LOAD_PATH,result[:4096])
        with self.assertRaises(ValueError):packager.patch_executable(result)
    def test_rejects_encryption_and_short_padding(self):
        with self.assertRaises(ValueError):packager.patch_executable(image(encrypted=1))
        with self.assertRaises(ValueError):packager.patch_executable(image(padding=224))
    def test_rejects_bad_command(self):
        raw=bytearray(image());struct.pack_into('<I',raw,36,0)
        with self.assertRaises(ValueError):packager.patch_executable(raw)

if __name__=='__main__':unittest.main()
