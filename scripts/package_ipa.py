"""Package an operator-supplied IPA locally; never upload it to GitHub."""
import hashlib
import pathlib
import plistlib
import struct
import sys
import zipfile

EXPECTED = '74a4e8aae310e6f479f52688b09a7be260677ef54648499f2acac66a3f6d5ff1'
LOAD_PATH = b'@executable_path/Frameworks/ProcreateRulers.dylib\0'

def patch_executable(data):
    if data[:4] != b'\xcf\xfa\xed\xfe' or struct.unpack_from('<I', data, 4)[0] != 0x100000c:
        raise ValueError('Expected thin ARM64 Mach-O')
    ncmds, sizeofcmds = struct.unpack_from('<II', data, 16)
    if sizeofcmds > len(data)-32 or ncmds > sizeofcmds//8:
        raise ValueError('Invalid load-command table')
    pos, first_data = 32, len(data)
    commands = []
    for _ in range(ncmds):
        cmd, size = struct.unpack_from('<II', data, pos)
        if size < 8 or size % 8 or pos+size > 32+sizeofcmds:
            raise ValueError('Invalid load command')
        if cmd == 0x2c and struct.unpack_from('<I', data, pos+16)[0] != 0:
            raise ValueError('Encrypted executable is unsupported')
        if cmd == 0x19:
            count = struct.unpack_from('<I', data, pos+64)[0]
            if 72+80*count > size:
                raise ValueError('Invalid sections')
            for i in range(count):
                section = pos+72+i*80
                offset = struct.unpack_from('<I', data, section+48)[0]
                if offset:
                    first_data = min(first_data, offset)
        if cmd == 0xc and LOAD_PATH.rstrip(b'\0') in data[pos:pos+size]:
            raise ValueError('Extension already inserted')
        if cmd != 0x1d:  # The old main code signature is invalid after this edit.
            commands.append(data[pos:pos+size])
        pos += size
    if pos != 32+sizeofcmds:
        raise ValueError('Load command size mismatch')
    length = (24+len(LOAD_PATH)+7)&~7
    commands.append(struct.pack('<6I', 0xc, length, 24, 0, 0x10000, 0x10000)+LOAD_PATH+b'\0'*(length-24-len(LOAD_PATH)))
    table = b''.join(commands)
    end = 32+len(table)
    if end > first_data:
        raise ValueError('Insufficient Mach-O header padding; refusing to move executable code')
    if end > pos and any(data[pos:end]):
        raise ValueError('Nonzero header padding; refusing to overwrite')
    result = bytearray(data)
    result[32:max(pos,end)] = table+b'\0'*(max(pos,end)-end)
    struct.pack_into('<II', result, 16, len(commands), len(table))
    return bytes(result)

def package(source, dylib, output):
    source, dylib, output = map(pathlib.Path, (source,dylib,output))
    if output.exists() or output.resolve() in (source.resolve(),dylib.resolve()):
        raise ValueError('Output must be a new file')
    library = dylib.read_bytes()
    if len(library)<32 or library[:4] != b'\xcf\xfa\xed\xfe' or struct.unpack_from('<II',library,4)[0] != 0x100000c or struct.unpack_from('<I',library,12)[0] != 6:
        raise ValueError('Expected an ARM64 Mach-O dylib')
    with zipfile.ZipFile(source) as archive:
        names = archive.namelist()
        if len(names)!=len(set(names)):
            raise ValueError('Duplicate archive members')
        infos = [n for n in names if n.startswith('Payload/') and n.count('/')==2 and n.endswith('.app/Info.plist')]
        if len(infos)!=1:
            raise ValueError('Expected exactly one main app')
        root = infos[0].rsplit('/',1)[0]+'/'
        metadata = plistlib.loads(archive.read(infos[0]))
        if metadata.get('CFBundleIdentifier')!='au.com.savageinteractive.procreate':
            raise ValueError('Unexpected app identity')
        executable = root+metadata['CFBundleExecutable']
        raw = archive.read(executable)
        if hashlib.sha256(raw).hexdigest()!=EXPECTED:
            raise ValueError('Executable differs from analyzed Procreate 5.4.8 build 57066')
        patched = patch_executable(raw)
        member = root+'Frameworks/ProcreateRulers.dylib'
        if member in names:
            raise ValueError('Extension already present')
        try:
            with zipfile.ZipFile(output,'x',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as dest:
                for info in archive.infolist():
                    if info.filename.startswith(root+'_CodeSignature/'):
                        continue
                    if info.filename==executable:
                        dest.writestr(info,patched)
                    else:
                        with archive.open(info) as src,dest.open(info,'w') as dst:
                            import shutil
                            shutil.copyfileobj(src,dst)
                info = zipfile.ZipInfo(member)
                info.external_attr = 0o100755 << 16
                info.compress_type = zipfile.ZIP_DEFLATED
                dest.writestr(info,library)
            with zipfile.ZipFile(output) as check:
                if check.testzip() is not None:
                    raise ValueError('Output ZIP integrity check failed')
                if check.read(member)!=library or check.read(executable)!=patched:
                    raise ValueError('Output byte verification failed')
        except BaseException:
            output.unlink(missing_ok=True)
            raise
    print(f'Created {output} (requires signing; not device-tested)')

if __name__=='__main__':
    if len(sys.argv)!=4:
        raise SystemExit('Usage: package_ipa.py ORIGINAL.ipa ProcreateRulers.dylib NEW.ipa')
    package(*sys.argv[1:])
