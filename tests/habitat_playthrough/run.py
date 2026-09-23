"""Run input-driven habitat checks in an isolated native-engine QA identity."""
import argparse
import os
from pathlib import Path
import subprocess
import time

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('case', choices=['starters', 'regis', 'legends', 'portals', 'birth', 'volcano', 'rivals', 'route14-reload', 'gates'])
parser.add_argument('--host', type=Path, required=True, help='Isolated Gen1Recomp checkout with the driver hook and tested mods installed')
parser.add_argument('--love', default='love', help='LÖVE executable')
parser.add_argument('--timeout', type=int, default=600)
args = parser.parse_args()
root = Path(__file__).resolve().parent
(root / 'evidence').mkdir(exist_ok=True)
env = os.environ.copy()
env.update(POKEPORT_IDENTITY='kasc-habitat-playthrough-qa', POKEPORT_VERSION='red',
           POKEPORT_DRIVER=str(root / 'drivers' / (args.case + '.lua')),
           HABITAT_QA_ROOT=str(root), POKEPORT_SPEED='2')
log = root / 'evidence' / (args.case + '.log')
failed = None
with log.open('w') as output:
    process = subprocess.Popen([args.love, str(args.host.resolve())], env=env,
                               stdout=output, stderr=subprocess.STDOUT)
    started = time.monotonic()
    try:
        while process.poll() is None:
            time.sleep(1)
            body = log.read_text(errors='replace')
            if 'driver error:' in body or '\nError:' in body:
                failed = 'native driver failed'
                break
            if time.monotonic() - started > args.timeout:
                failed = 'timed out'
                break
    finally:
        if process.poll() is None:
            process.terminate()
        process.wait(timeout=10)
body = log.read_text(errors='replace')
failed = failed or (f'exit {process.returncode}' if process.returncode else None)
if 'driver error:' in body or '\nError:' in body:
    failed = failed or 'native driver failed'
markers = {'starters': 'PHYSICAL_STARTER_TOTAL', 'regis': 'ALL_REGI_PHYSICAL_PASS', 'legends': 'LEGEND_PHYSICAL_ROUNDTRIP_PASS', 'portals': 'GROUDON_PORTAL_PHYSICAL_PASS', 'birth': 'BIRTH_PHYSICAL_ROUNDTRIP_PASS', 'volcano': 'VOLCANO_PHYSICAL_ROUNDTRIP_PASS', 'rivals': 'RIVAL_INPUT_HINT_PASS', 'route14-reload': 'ROUTE14_NATIVE_RELOAD_PASS', 'gates': 'NGPLUS_LIVE_LEGEND_GATES_PASS'}
if markers[args.case] not in body:
    failed = failed or 'completion marker missing'
print(f'{args.case}: {failed or "completed"}; log: {log}')
print(body[-1800:])
raise SystemExit(1 if failed else 0)
