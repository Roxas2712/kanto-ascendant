"""Build the narrow hotfix from a SHA256-pinned published RC3 archive."""
import copy, difflib, hashlib, json, sys, zipfile
from pathlib import Path
ROOT = Path(__file__).resolve().parent
SOURCE = Path(sys.argv[1]) if len(sys.argv)>1 else ROOT.parent/'KASC-6.7.0-rc.3-CARDS-RIOLU/kanto_ascendant-6.7.0-rc.3.zip'
EXPECTED = '77746d4b533d4f61bf0e0f49231f33b7ed9ca034fd84ee9d1c70578f72cc5069'
VERSION = '6.7.0-rc.4'
def sha(b): return hashlib.sha256(b).hexdigest()
assert sha(SOURCE.read_bytes()) == EXPECTED, 'Base release differs'
names = ['legacy_archive.lua','legacy_journey.lua','support_session_log.lua','main.lua']
patches = {n:(ROOT/'runtime'/n).read_bytes() for n in names}
with zipfile.ZipFile(SOURCE) as old:
    manifest = json.loads(old.read('manifest.json'))
    manifest['version'] = VERSION
    patches['manifest.json'] = (json.dumps(manifest,ensure_ascii=False,indent=2)+'\n').encode()
    pack = json.loads(old.read('.modkit/pack.json'))
    pack['version'] = VERSION
    for row in pack['files']:
        if row['path'] in patches:
            b = patches[row['path']]
            row.update(bytes=len(b),sha256=sha(b))
    patches['.modkit/pack.json'] = (json.dumps(pack,ensure_ascii=False,indent=2)+'\n').encode()
    target = ROOT/('kanto_ascendant-'+VERSION+'.zip')
    with zipfile.ZipFile(target,'w') as new:
        for item in old.infolist():
            new.writestr(copy.copy(item),patches[item.filename] if item.filename in patches else old.read(item.filename))
    with zipfile.ZipFile(target) as new:
        assert new.testzip() is None
        changed = [n for n in old.namelist() if old.read(n)!=new.read(n)]
        assert set(changed)==set(patches)
        for row in pack['files']:
            b = new.read(row['path'])
            assert len(b)==row['bytes'] and sha(b)==row['sha256'], row['path']
    diff = ''.join(''.join(difflib.unified_diff(old.read(n).decode().splitlines(True),patches[n].decode().splitlines(True),fromfile='a/'+n,tofile='b/'+n)) for n in names)
    (ROOT/'ngplus-performance.patch').write_text(diff)
receipt = dict(version=VERSION,base_sha256=EXPECTED,sha256=sha(target.read_bytes()),
    changed_files=changed,zip_integrity='PASS',all_pack_file_hashes='PASS')
(ROOT/'PACKAGE-RECEIPT.json').write_text(json.dumps(receipt,indent=2)+'\n')
(ROOT/('kanto_ascendant-'+VERSION+'.sha256')).write_text(receipt['sha256']+'  '+target.name+'\n')
print(json.dumps(receipt,indent=2))
