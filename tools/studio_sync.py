# -*- coding: utf-8 -*-
"""
studio_sync.py — src/ 를 Studio 로 옮길 목록(sync.json)을 만든다. (2026-09-28)

rojo 연결은 default.project.json 의 Lighting·Workspace $properties 까지 덮어써서(맵 조명이 바뀜) 쓰지 않는다.
대신 커맨드 바 로더가 tools/StudioSync.luau 를 받아, 이 목록대로 각 스크립트의 Source 만 바꾼다.
  - src/shared/X.luau              → ReplicatedStorage.Shared.X            (ModuleScript)
  - src/shared/D/init.luau         → ReplicatedStorage.Shared.D            (ModuleScript)
  - src/server/init.server.luau    → ServerScriptService.Server            (Script)
  - src/client/init.client.luau    → StarterPlayer.StarterPlayerScripts.Client (LocalScript)
  - init 없는 하위 폴더는 Folder
Studio 에만 있는 스크립트(PlayerService·BiomeAtmosphere 등)는 건드리지 않는다.
돌리는 법: python tools/studio_sync.py [파일이름 걸러내기...]  → tools/sync.json
그다음 프로젝트 뿌리를 python -m http.server 35001 로 띄운 채 tools/StudioSync.luau 를 로더로 실행.
"""
import json
import os
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
MAP = [("src/shared", ["ReplicatedStorage", "Shared"]),
       ("src/server", ["ServerScriptService", "Server"]),
       ("src/client", ["StarterPlayer", "StarterPlayerScripts", "Client"])]


def main():
    only = sys.argv[1:]
    items = []
    for rel, base in MAP:
        top = os.path.join(ROOT, rel)
        for dirpath, dirnames, filenames in os.walk(top):
            dirnames.sort()
            sub = os.path.relpath(dirpath, top).replace("\\", "/")
            parts = [] if sub == "." else sub.split("/")
            for f in sorted(filenames):
                if not f.endswith(".luau"):
                    continue
                name = f[:-5]
                if name in ("init", "init.server", "init.client"):
                    path = base + parts
                    cls = {"init": "ModuleScript", "init.server": "Script", "init.client": "LocalScript"}[name]
                    if not parts and name == "init":
                        continue
                else:
                    path = base + parts + [name]
                    cls = "ModuleScript"
                # 폴더 중간 마디: init 이 있으면 ModuleScript, 없으면 Folder
                chain = []
                for i in range(len(parts)):
                    d = os.path.join(top, *parts[:i + 1])
                    has_init = os.path.exists(os.path.join(d, "init.luau"))
                    chain.append("ModuleScript" if has_init else "Folder")
                file_rel = os.path.relpath(os.path.join(dirpath, f), ROOT).replace("\\", "/")
                if only and not any(o in file_rel for o in only):
                    continue
                items.append({"file": file_rel, "path": path, "class": cls, "chain": chain, "base": len(base)})
    out = os.path.join(ROOT, "tools", "sync.json")
    open(out, "w", encoding="utf-8", newline="\n").write(json.dumps(items, ensure_ascii=False))
    print("%d 개 → %s" % (len(items), out))


if __name__ == "__main__":
    main()
