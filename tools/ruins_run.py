# -*- coding: utf-8 -*-
"""ruins_run.py — Ruins_Build.luau 에 표·계단 점·올림 값을 넣어 커맨드 바용 Ruins_Build_run.luau 를 만든다.
먼저 ruins_plan.py, build_kit_ruins.py 를 돌려 둘 것"""
import os

HERE = os.path.dirname(os.path.abspath(__file__))


def read(n):
    with open(os.path.join(HERE, n), encoding="utf-8") as f:
        return f.read()


src = read("Ruins_Build.luau")
for marker, name in (("--@@DATA@@", "Ruins_data.luau"), ("--@@STEPS@@", "Ruins_steps.luau"), ("--@@LIFTS@@", "Ruins_lifts.luau")):
    assert src.count("\n" + marker + "\n") == 1, marker
    src = src.replace("\n" + marker + "\n", "\n" + read(name).rstrip("\n") + "\n")
with open(os.path.join(HERE, "Ruins_Build_run.luau"), "w", encoding="utf-8") as f:
    f.write(src)
print("Ruins_Build_run.luau %d 줄" % src.count("\n"))
