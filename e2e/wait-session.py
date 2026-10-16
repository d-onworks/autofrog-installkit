import subprocess,time,json,base64,pathlib
root=pathlib.Path(__file__).parent
out=root/'results'/(root/'current-run.txt').read_text()
for i in range(21):
    p=subprocess.run(['ssh','-o','BatchMode=yes','-o','ConnectTimeout=15','winhome',r'powershell -NoProfile -ExecutionPolicy Bypass -File C:\AutoFrogE2E\preflight.ps1'],capture_output=True)
    try:
        s=json.loads(base64.b64decode(p.stdout.strip()).decode('utf-8-sig'))
    except Exception:
        s={'active':False,'sshExit':p.returncode,'error':p.stderr.decode('utf-8','replace')}
    with (out/'session-checks.jsonl').open('a') as f: f.write(json.dumps(s,ensure_ascii=False)+'\n')
    print(json.dumps({'attempt':i+1,'active':s.get('active'),'sshExit':p.returncode}),flush=True)
    if s.get('active'): (out/'session-active.json').write_text(json.dumps(s,ensure_ascii=False,indent=2));break
    if i==20: (out/'session-timeout.json').write_text(json.dumps(s,ensure_ascii=False,indent=2));break
    time.sleep(60)
