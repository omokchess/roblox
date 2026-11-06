# -*- coding: utf-8 -*-
"""
check_fx.py — 모션이 부르는 이펙트 이름(Fx n= / Hit fx=)이 Fx/<직업>.luau 에 실제로 있는지 대조한다. (2026-09-28)
이름이 어긋나면 게임에서는 조용히 기본 타격만 나오므로(연출이 오류를 내지 않음) 여기서 잡는다.
  python tools/combat/check_fx.py   → 빠진 것이 있으면 목록을 찍고 1 로 끝난다
"""
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
MOTIONS = os.path.join(ROOT, "src", "shared", "Combat", "Motions")
FX = os.path.join(ROOT, "src", "client", "Combat", "Fx")
SKIP = {"Common", "Test"}

missing = []
for name in sorted(os.listdir(MOTIONS)):
    cls = name[:-5]
    if not name.endswith(".luau") or cls in SKIP:
        continue
    used = set(re.findall(r'\b(?:n|fx) = "([A-Za-z]+)"', open(os.path.join(MOTIONS, name), encoding="utf-8").read()))
    fx_path = os.path.join(FX, cls + ".luau")
    have = set()
    if os.path.exists(fx_path):
        have = set(re.findall(r"^function Fx\.([A-Za-z]+)\(", open(fx_path, encoding="utf-8").read(), re.M))
    for n in sorted(used - have):
        missing.append(f"{cls}: {n}")
    print(f"{cls:12s} 사용 {len(used):2d} / 있음 {len(have):2d}")

if missing:
    print("빠진 이펙트:", *missing, sep="\n  ")
    sys.exit(1)
print("모든 이펙트 이름이 맞다")

# Pack("팩/이펙트") 이름이 VFX 팩 목록(vfx_textures.tsv 경로)에 있는지 대조 — 없으면 게임에서 조용히 false 가 된다 (2026-11-06)
TSV = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out", "vfx_textures.tsv")
paths = [l.split("\t")[1] for l in open(TSV, encoding="utf-8") if "\t" in l]
bad = set()
SRC = os.path.join(ROOT, "src")
for dp, _, files in os.walk(SRC):
    for f in files:
        if f.endswith(".luau"):
            for n in re.findall(r'\bPack\("([^"]+)"', open(os.path.join(dp, f), encoding="utf-8").read()):
                if not any(p == n or p.startswith(n + "/") for p in paths):
                    bad.add(f"{f}: {n}")
if bad:
    print("팩에 없는 Pack 이름:", *sorted(bad), sep="\n  ")
    sys.exit(1)
print("모든 Pack 이름이 팩 목록에 있다")
