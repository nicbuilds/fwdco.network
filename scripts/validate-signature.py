"""Verify Mach-O signature structure and entitlements read by AltSign's parser."""
import pathlib, plistlib, struct, sys
app=pathlib.Path(sys.argv[1])
info=plistlib.loads((app/'Info.plist').read_bytes())
assert info['CFBundleExecutable']=='NODO'
assert info['CFBundleIdentifier']=='help.nodo.mobile'
assert not (app/'embedded.mobileprovision').exists()
assert (app/'_CodeSignature/CodeResources').is_file()
assert not (app/'PlugIns').exists()
assert not (app/'Frameworks').exists()
b=(app/'NODO').read_bytes()
h=struct.unpack_from('<8I', b)
assert h[0]==0xfeedfacf and h[1]==0x100000c and h[3]==2, h
pos=32; signature=None
for _ in range(h[4]):
    cmd,size=struct.unpack_from('<II',b,pos)
    assert size>=8 and pos+size<=len(b)
    if cmd==0x1d:
        assert signature is None
        signature=struct.unpack_from('<II',b,pos+8)
    if cmd==0x2c:
        assert struct.unpack_from('<I',b,pos+16)[0]==0, 'Encrypted binary'
    if cmd==0x32:
        platform, minimum=struct.unpack_from('<II',b,pos+8)
        assert platform==2 and minimum==0x100000
    pos+=size
assert signature
start,size=signature
assert start+size<=len(b)
magic,length,count=struct.unpack_from('>III',b,start)
assert magic==0xfade0cc0 and length<=size
entitlements=None; code_directory=False
for i in range(count):
    slot,offset=struct.unpack_from('>II',b,start+12+i*8)
    m,n=struct.unpack_from('>II',b,start+offset)
    assert offset+n<=length
    if slot==0:
        assert m==0xfade0c02
        flags=struct.unpack_from('>I',b,start+offset+12)[0]
        assert flags & 2, 'Expected ad-hoc signature'
        code_directory=True
    if slot==5:
        assert m==0xfade7171
        entitlements=plistlib.loads(b[start+offset+8:start+offset+n])
assert code_directory and entitlements=={}, entitlements
assert plistlib.loads(pathlib.Path('build/extracted-entitlements.plist').read_bytes())=={}
print('PASS: unencrypted iOS arm64; complete ad-hoc CodeDirectory; empty XML entitlements readable via AltSign layout; no profile or embedded extensions/frameworks.')
