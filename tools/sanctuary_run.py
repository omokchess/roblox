# -*- coding: utf-8 -*-
"""sanctuary_run.py — Sanctuary_Build.luau 에 표(Sanctuary_data.luau)와 탑 계단 점(Sanctuary_steps.luau)을 넣어
커맨드 바에 붙일 Sanctuary_Build_run.luau 를 만든다. 먼저 sanctuary_plan.py, build_kit_sanctuary.py 를 돌려 둘 것"""
import os

HERE = os.path.dirname(os.path.abspath(__file__))


def read(n):
    with open(os.path.join(HERE, n), encoding="utf-8") as f:
        return f.read()


src = read("Sanctuary_Build.luau")
for marker, name in (("--@@DATA@@", "Sanctuary_data.luau"), ("--@@STEPS@@", "Sanctuary_steps.luau")):
    assert src.count("\n" + marker + "\n") == 1, marker
    src = src.replace("\n" + marker + "\n", "\n" + read(name).rstrip("\n") + "\n")
with open(os.path.join(HERE, "Sanctuary_Build_run.luau"), "w", encoding="utf-8") as f:
    f.write(src)
print("Sanctuary_Build_run.luau %d 줄" % src.count("\n"))
