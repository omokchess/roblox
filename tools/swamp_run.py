# -*- coding: utf-8 -*-
"""swamp_run.py — Swamp_Kit.luau 에 Swamp_assets.luau 를 넣어 커맨드 바용 Swamp_Kit_run.luau 를 만든다"""
import os
HERE = os.path.dirname(os.path.abspath(__file__))
src = open(os.path.join(HERE, "Swamp_Kit.luau"), encoding="utf-8").read()
data = open(os.path.join(HERE, "Swamp_assets.luau"), encoding="utf-8").read().rstrip("\n")
assert src.count("\n--@@ASSETS@@\n") == 1
src = src.replace("\n--@@ASSETS@@\n", "\n" + data + "\n")
open(os.path.join(HERE, "Swamp_Kit_run.luau"), "w", encoding="utf-8").write(src)
print("Swamp_Kit_run.luau %d 줄" % src.count("\n"))
