from pathlib import Path
import zipfile,hashlib,json,copy,difflib
import argparse
parser=argparse.ArgumentParser()
parser.add_argument('base',type=Path)
parser.add_argument('output',type=Path)
args=parser.parse_args()
WORK=Path(__file__).resolve().parents[2]
OUT=args.output.resolve(); OUT.mkdir(parents=True,exist_ok=True)
BASE=args.base.resolve()
VERSION='6.7.9'
EXPECTED='07b0748c6fe8ccadc0bff789fd029a8a13ad70cd36818b4a720933703275dc07'
sha=lambda b:hashlib.sha256(b).hexdigest()
assert sha(BASE.read_bytes())==EXPECTED
names=['hoenn_discovery.lua','pokemon_equipment_67.lua','pokemon_equipment_runtime_67.lua']
patches={n:(WORK/n).read_bytes()for n in names}
with zipfile.ZipFile(BASE)as old:
 manifest=json.loads(old.read('manifest.json'));manifest['version']=VERSION
 patches['manifest.json']=(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n').encode()
 pack=json.loads(old.read('.modkit/pack.json'));pack['version']=VERSION
 for row in pack['files']:
  if row['path']in patches:
   b=patches[row['path']];row.update(bytes=len(b),sha256=sha(b))
 patches['.modkit/pack.json']=(json.dumps(pack,ensure_ascii=False,indent=2)+'\n').encode()
 target=OUT/('kanto_ascendant-'+VERSION+'.zip')
 with zipfile.ZipFile(target,'w')as new:
  for item in old.infolist():new.writestr(copy.copy(item),patches.get(item.filename,old.read(item.filename)))
 with zipfile.ZipFile(target)as new:
  assert new.testzip()is None
  changed=[n for n in old.namelist()if old.read(n)!=new.read(n)]
  assert set(changed)==set(patches)
  for row in pack['files']:
   b=new.read(row['path']);assert len(b)==row['bytes']and sha(b)==row['sha256'],row['path']
  new.extractall(OUT/'packed')
 diff=''.join(''.join(difflib.unified_diff(old.read(n).decode().splitlines(True),patches[n].decode().splitlines(True),fromfile='a/'+n,tofile='b/'+n))for n in names)
 (OUT/'changes.patch').write_text(diff)
receipt=dict(version=VERSION,base_sha256=EXPECTED,sha256=sha(target.read_bytes()),changed_files=changed,zip_integrity='PASS',all_pack_file_hashes='PASS',published=False)
(OUT/'PACKAGE-RECEIPT.json').write_text(json.dumps(receipt,indent=2)+'\n')
(OUT/(target.name+'.sha256')).write_text(receipt['sha256']+'  '+target.name+'\n')
print(json.dumps(receipt,indent=2))
