import base64,json,pathlib,subprocess
root=pathlib.Path(__file__).parent
run=(root/'current-run.txt').read_text().strip()
p=subprocess.run(['ssh','-o','BatchMode=yes','-o','ConnectTimeout=10','-o','ServerAliveInterval=15','-o','ServerAliveCountMax=2','winhome',f'powershell -NoProfile -ExecutionPolicy Bypass -File C:\\AutoFrogE2E\\status.ps1 -RunId {run}'],capture_output=True,check=True,timeout=45)
j=json.loads(base64.b64decode(p.stdout.strip()))
out=root/'results'/run
(out/'status-latest.json').write_text(json.dumps(j,ensure_ascii=False,indent=2))
with (out/'status-history.jsonl').open('a') as f:f.write(json.dumps(j,ensure_ascii=False)+'\n')
brief={"time":j["time"],"processes":j["processes"],"tasks":j["tasks"],"files":{}}
for k,v in j["files"].items():
 if k.endswith(('result-first.json','result-second.json')):
  brief['files'][k]={"allOk":v.get('allOk'),"steps":{n:{"state":x["state"],"sec":x.get("sec")} for n,x in v.get("steps",{}).items()},"verifyFailures":{n:x for n,x in v.get('verify',{}).items() if not x.get('ok')}}
 else:brief['files'][k]=v
print(json.dumps(brief,ensure_ascii=False,indent=2))
