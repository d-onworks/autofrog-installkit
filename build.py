#!/usr/bin/env python3
"""오토프로그 윈도우 설치 키트 빌드 — 최신 안정판을 받아 zip 하나로 묶는다.

받는 것(모두 공식 배포처, 체크섬 확인):
  Git for Windows · Node.js 24 LTS · GitHub CLI · Supabase CLI · VS Code(사용자 설치판) · 코덱스 패키지
클로드 코드는 재배포 금지라 묶지 않는다(설치할 때 공식 서버에서 받는다). Vercel CLI 는 npm 으로 받는다.

사용: python3 build.py           → dist/autofrog-setup-kit-YYYYMMDD.zip  (설치 파일 동봉판 · 수강생용 드라이브)
      python3 build.py --online  → dist/autofrog-setup-kit.zip           (온라인판 · 공개용 깃허브 Releases)
      python3 build.py --mac     → dist/autofrog-setup-kit-mac.zip       (맥 온라인판 · kit-mac/ 을 그대로 묶음)
온라인판은 payload 없이 스크립트만 담는다. 설치할 때 kit/scripts/online.ps1 이 공식 배포처에서 최신판을 받는다.
이름이 늘 같아야 https://github.com/d-onworks/autofrog-installkit/releases/latest/download/autofrog-setup-kit.zip 이 고정 주소가 된다.
"""
import hashlib, json, os, re, shutil, subprocess, sys, urllib.request, zipfile
from datetime import datetime
from pathlib import Path
from zoneinfo import ZoneInfo

HERE = Path(__file__).resolve().parent
KIT = HERE / "kit"
KIT_MAC = HERE / "kit-mac"
CACHE = HERE / ".cache"
DIST = HERE / "dist"
NODE_MAJOR = 24  # 수업 기간 동안 고정(2026-10-28 에 26 이 LTS 가 된다)


def gh_token():
    try:
        return subprocess.run(["gh", "auth", "token"], capture_output=True, text=True, timeout=10).stdout.strip()
    except Exception:
        return ""


TOKEN = gh_token()


def get(url, accept="application/json"):
    req = urllib.request.Request(url, headers={"User-Agent": "autofrog-kit", "Accept": accept})
    if TOKEN and "api.github.com" in url:
        req.add_header("Authorization", f"Bearer {TOKEN}")
    with urllib.request.urlopen(req, timeout=60) as r:
        return r.read()


def gh_latest(repo, pattern):
    rel = json.loads(get(f"https://api.github.com/repos/{repo}/releases/latest"))
    for a in rel["assets"]:
        if re.fullmatch(pattern, a["name"]):
            sha = (a.get("digest") or "").removeprefix("sha256:")
            return rel["tag_name"], a["name"], a["browser_download_url"], sha
    raise SystemExit(f"{repo}: {pattern} 자산을 못 찾음")


def resolve():
    out = {}
    tag, name, url, sha = gh_latest("git-for-windows/git", r"Git-[\d.]+-64-bit\.exe")
    out["git"] = dict(version=tag.removeprefix("v"), file=name, url=url, sha256=sha)

    idx = json.loads(get("https://nodejs.org/dist/index.json"))
    v = next(x["version"] for x in idx if x["lts"] and x["version"].startswith(f"v{NODE_MAJOR}."))
    name = f"node-{v}-win-x64.zip"
    sums = get(f"https://nodejs.org/dist/{v}/SHASUMS256.txt", "text/plain").decode()
    sha = next(l.split()[0] for l in sums.splitlines() if l.endswith(" " + name))
    out["node"] = dict(version=v.lstrip("v"), file=name, url=f"https://nodejs.org/dist/{v}/{name}", sha256=sha)

    tag, name, url, sha = gh_latest("cli/cli", r"gh_[\d.]+_windows_amd64\.zip")
    out["gh"] = dict(version=tag.lstrip("v"), file=name, url=url, sha256=sha)

    tag, name, url, sha = gh_latest("supabase/cli", r"supabase_[\d.]+_windows_amd64\.zip")
    out["supabase"] = dict(version=tag.lstrip("v"), file=name, url=url, sha256=sha)

    tag, name, url, sha = gh_latest("openai/codex", r"codex-package-x86_64-pc-windows-msvc\.tar\.gz")
    ver = tag.removeprefix("rust-v")
    out["codex"] = dict(version=ver, file=f"codex-package-{ver}-x86_64-pc-windows-msvc.tar.gz", url=url, sha256=sha)

    vs = json.loads(get("https://update.code.visualstudio.com/api/update/win32-x64-user/stable/latest"))
    out["vscode"] = dict(version=vs["productVersion"], file=f"VSCodeUserSetup-x64-{vs['productVersion']}.exe",
                         url=vs["url"], sha256=vs["sha256hash"])
    return out


def sha256(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def fetch(item):
    CACHE.mkdir(exist_ok=True)
    dest = CACHE / item["file"]
    if dest.exists() and sha256(dest) == item["sha256"]:
        print(f"  캐시 사용  {item['file']}")
        return dest
    print(f"  내려받기  {item['file']} …", flush=True)
    tmp = dest.with_suffix(dest.suffix + ".part")
    subprocess.run(["curl", "-fL", "--retry", "3", "-o", str(tmp), item["url"]], check=True)
    got = sha256(tmp)
    if item["sha256"] and got != item["sha256"]:
        tmp.unlink()
        raise SystemExit(f"체크섬 불일치: {item['file']}")
    tmp.rename(dest)
    return dest


def text_for_windows(src: Path, dst: Path):
    """ps1·txt 는 UTF-8 BOM + CRLF(PowerShell 5.1 이 한글을 읽게), bat 은 ASCII + CRLF."""
    raw = src.read_text(encoding="utf-8").replace("\r\n", "\n").replace("\n", "\r\n")
    if src.suffix == ".bat":
        raw.encode("ascii")  # 한글이 섞이면 여기서 멈춘다
        dst.write_bytes(raw.encode("ascii"))
    else:
        dst.write_bytes(b"\xef\xbb\xbf" + raw.encode("utf-8"))


def build_mac():
    """맥판: 설치 파일 없이 스크립트만. LF 줄바꿈 그대로, .command·.sh 는 실행 권한(755)을 zip 에 기록한다
    (맥 기본 압축 풀기가 이 권한을 살려야 더블클릭으로 열린다)."""
    name = "autofrog-setup-kit-mac"
    DIST.mkdir(exist_ok=True)
    zpath = DIST / f"{name}.zip"
    if zpath.exists():
        zpath.unlink()
    with zipfile.ZipFile(zpath, "w", zipfile.ZIP_DEFLATED) as z:
        stamp = datetime.now().timetuple()[:6]
        for d in [name, f"{name}/scripts"]:
            zi = zipfile.ZipInfo(d + "/", date_time=stamp)
            zi.external_attr = (0o40755 << 16) | 0x10
            z.writestr(zi, b"")
        for p in sorted(KIT_MAC.rglob("*")):
            if not p.is_file() or p.name == ".DS_Store":
                continue
            data = p.read_bytes().replace(b"\r\n", b"\n")
            zi = zipfile.ZipInfo(f"{name}/{p.relative_to(KIT_MAC).as_posix()}", date_time=stamp)
            zi.compress_type = zipfile.ZIP_DEFLATED
            zi.create_system = 3  # 유닉스 — 권한 비트를 읽게
            mode = 0o755 if p.suffix in (".command", ".sh") else 0o644
            zi.external_attr = (0o100000 | mode) << 16
            z.writestr(zi, data)
    print(f"완성: {zpath}  ({zpath.stat().st_size / 1e3:.0f} KB)\nsha256 {sha256(zpath)}")


def main():
    if "--mac" in sys.argv[1:]:
        return build_mac()
    now = datetime.now(ZoneInfo("Asia/Seoul"))
    online = "--online" in sys.argv[1:]
    files = {}
    if not online:
        print("최신 안정판 확인 중…")
        files = resolve()
        for k, v in files.items():
            print(f"  {k:9} {v['version']}")
        for v in files.values():
            fetch(v)

    name = "autofrog-setup-kit" if online else f"autofrog-setup-kit-{now:%Y%m%d}"
    stage = DIST / "stage" / name
    if stage.exists():
        shutil.rmtree(stage)
    (stage / "scripts").mkdir(parents=True)
    for p in KIT.rglob("*"):
        if p.is_file() and p.name != ".DS_Store":
            text_for_windows(p, stage / p.relative_to(KIT))
    if not online:
        (stage / "payload").mkdir()
        for v in files.values():
            os.link(CACHE / v["file"], stage / "payload" / v["file"])
        manifest = {"built": now.strftime("%Y-%m-%d %H:%M KST"),
                    "files": {k: {kk: v[kk] for kk in ("version", "file", "sha256")} for k, v in files.items()}}
        (stage / "payload" / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")

    zpath = DIST / f"{name}.zip"
    if zpath.exists():
        zpath.unlink()
    with zipfile.ZipFile(zpath, "w") as z:
        for p in sorted(stage.rglob("*")):
            if p.is_file():
                arc = f"{name}/{p.relative_to(stage).as_posix()}"
                packed = p.parent.name == "payload" and p.suffix != ".json"
                z.write(p, arc, compress_type=zipfile.ZIP_STORED if packed else zipfile.ZIP_DEFLATED)
    print(f"\n완성: {zpath}  ({zpath.stat().st_size / 1e6:.0f} MB)\nsha256 {sha256(zpath)}")


if __name__ == "__main__":
    main()
