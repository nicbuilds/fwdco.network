"""Portable ZIP with one Payload app, stable modes and no macOS extra records."""
import pathlib, stat, sys, zipfile
app=pathlib.Path(sys.argv[1]); target=pathlib.Path(sys.argv[2])
with zipfile.ZipFile(target,'w',zipfile.ZIP_DEFLATED,allowZip64=False) as z:
    for name in ['Payload/', 'Payload/NODO.app/']:
        item=zipfile.ZipInfo(name);item.create_system=3;item.external_attr=(stat.S_IFDIR|0o755)<<16|0x10;z.writestr(item,b'')
    for path in sorted(app.rglob('*')):
        assert not path.is_symlink()
        assert not path.name.startswith('._') and path.name!='.DS_Store'
        name='Payload/NODO.app/'+str(path.relative_to(app))
        if path.is_dir():
            item=zipfile.ZipInfo(name+'/');item.create_system=3;item.external_attr=(stat.S_IFDIR|0o755)<<16|0x10;z.writestr(item,b'')
        else:
            item=zipfile.ZipInfo(name);item.create_system=3
            item.external_attr=(stat.S_IFREG|(0o755 if path.name=='NODO' else 0o644))<<16
            item.compress_type=zipfile.ZIP_DEFLATED;z.writestr(item,path.read_bytes())
with zipfile.ZipFile(target) as z:
    assert z.testzip() is None
    assert all(x.startswith('Payload/') for x in z.namelist())
    assert len(z.namelist())==len(set(z.namelist()))
print('PASS: classic ZIP container; only Payload/NODO.app; executable mode 0755; no xattrs, AppleDouble or Zip64.')
