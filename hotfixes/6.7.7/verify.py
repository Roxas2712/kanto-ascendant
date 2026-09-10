"""Run regression tests against an extracted release with a Gen1 Recomp engine."""
from pathlib import Path
import argparse, os, subprocess, json
p=argparse.ArgumentParser()
p.add_argument("package",type=Path)
p.add_argument("engine",type=Path)
p.add_argument("engine_tests",type=Path)
p.add_argument("--runner",nargs="+",default=["luajit"])
p.add_argument("--results",type=Path,required=True)
a=p.parse_args(); here=Path(__file__).resolve().parent
root=a.package.resolve()
env=dict(os.environ,TRACE_FIX_ROOT=str(root),GEN1RECOMP_DIR=str(a.engine.resolve()),GEN1RECOMP_TEST_DIR=str(a.engine_tests.resolve()),TRACE_TEST_ROOT=str(here))
rows=[]
for test in sorted((here/"tests").glob("*_test.lua")):
    result=subprocess.run(a.runner+[str(test)],cwd=root,env=env,capture_output=True,text=True,timeout=180)
    rows.append(dict(test=test.name,exit=result.returncode,output=result.stdout+result.stderr))
    print(test.name,"PASS" if result.returncode==0 else "FAIL",flush=True)
a.results.write_text(json.dumps(rows,indent=2)+"\n")
raise SystemExit(0 if all(row["exit"]==0 for row in rows) else 1)
