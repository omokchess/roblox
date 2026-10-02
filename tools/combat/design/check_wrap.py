"""모션의 무기 W/O 키 사이 한 값이 180° 넘게 바뀌는 곳(= 오일러로 돌림)을 찾는다. 일부러 돌린 곳인지 눈으로 확인용.
쓰는 법: python check_wrap.py <직업> (먼저 lune run tools/combat/export_motions.luau)"""
import json
import os
import sys

data = json.load(open(os.path.join(os.path.dirname(__file__), "..", "out", "motions.json"), encoding="utf-8"))
cls = data[sys.argv[1]]
stance = None


def walk(name, m):
    keys = m.get("Keys") or []
    pairs = list(zip(keys, keys[1:]))
    if m.get("Loop") and len(keys) > 1:
        pairs.append((keys[-1], keys[0]))
    for a, b in pairs:
        for s in ("W", "O"):
            if s in a and s in b:
                d = [abs(b[s][i] - a[s][i]) for i in (3, 4, 5)]
                if max(d) > 180:
                    print(f"{name} {s} t={a['t']}→{b['t']}: {a[s][3:]} → {b[s][3:]}")


for k, m in cls.items():
    if k == "Skills":
        for sk, sm in m.items():
            walk("Skills." + sk, sm)
    elif k == "Fidgets":
        for i, fm in enumerate(m):
            walk(f"Fidgets.{i + 1}", fm)
    elif isinstance(m, dict) and "Keys" in m:
        walk(k, m)
print("끝")
