"""Run focused regressions against the extracted candidate."""
import argparse,subprocess,json,os
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('package',type=Path);p.add_argument('--engine',type=Path,required=True);p.add_argument('--runner',nargs='+',default=['luajit']);p.add_argument('--results',type=Path,required=True);a=p.parse_args()
env=dict(os.environ,GEN1RECOMP_DIR=str(a.engine.resolve()))
rows=[]
for test in sorted((Path(__file__).resolve().parent/'tests').glob('*_test.lua')):
 r=subprocess.run(a.runner+[str(test)],cwd=a.package,env=env,capture_output=True,text=True,timeout=180)
 rows.append(dict(test=test.name,exit=r.returncode,output=r.stdout+r.stderr))
a.results.write_text(json.dumps(rows,indent=2)+'\n')
raise SystemExit(int(any(row['exit'] for row in rows)))
