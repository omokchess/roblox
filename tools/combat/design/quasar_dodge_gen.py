"""퀘이사 회피 다시(2026-10-03 사용자: "역수로 고쳐 쥐고, 오른손을 왼쪽 허리로 움직이면서 우아하게 피하는 느낌").
  RG_MID   왼손을 놓고 오른손 하나로 역수 — 손은 오른 허리 앞, 날이 팔뚝을 따라 오른 허리 바깥 뒤로(골반 덮기), 왼팔은 펴기 시작
  RG_LEFT  골반은 오른쪽으로 크게 돌리고(뒤 오른쪽으로 비켜섬) 상체는 왼쪽으로 감아(어깨가 적을 봄) — 그 비틀림으로
           역수 쥔 오른손이 왼 허리 앞에 닿고, 날은 왼 허리 바깥을 따라 뒤로(칼집에 꽂듯). 왼팔은 옆으로 길게 뻗어 선을 그린다.
  R6 팔은 곧아 오른 어깨에서 왼 허리까지 닿지 않는다 → 몸통을 왼쪽으로 비틀어 어깨를 가운데로 데려온다.
손 자리·날 방향은 **골반(Root) 공간**으로 준다. 결과는 quasar2_out.txt 에 덧붙인다(quasar_motions.py 가 읽음).
쓰는 법: python quasar_dodge_gen.py"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from twohand import *  # noqa: F401,F403

HERE = os.path.dirname(os.path.abspath(__file__))
KEYS = ["Root", "Torso", "Head", "RArm", "LArm", "RLeg", "LLeg", "W"]
OUTF = os.path.join(HERE, "quasar2_out.txt")
src = open(OUTF, encoding="utf-8").read()
REF = [float(x) for x in re.search(r"local STANCE = .*W = \{ ([^}]*) \}", src).group(1).split(",")]


def root_cf(P):
    r = P["Root"]
    return cfp(r[0], r[1], r[2]) * orient(r[3], r[4], r[5])


def place(P, hand_hip, dir_hip, hint):
    """골반 공간 손 자리·날 방향(앞날 위 → 면이 바깥)으로 오른팔·W 를 맞춘다"""
    R = root_cf(P)
    target = R.pt(hand_hip)
    v, err = reach(P, "R", target, hint=hint)
    P["RArm"] = v
    d = norm(mv(R.R, dir_hip))
    P["W"] = aim(P, "W", frame(d, (0, 1, 0)), hand(P, "R"))
    return err


def put(name, P, note):
    global src
    line = f"local {name} = {{ " + ", ".join(f"{k} = {f(P[k])}" for k in KEYS) + " }"
    R = root_cf(P)
    h = R.inv().pt(hand(P, "R"))
    tip = wpoint(P, "W", (0, 6.9, 0))
    note = f"-- {name} {note} (손·골반 공간 {[round(v, 2) for v in h]}, 칼끝 높이 {tip[1]:.2f})"
    print(note)
    print(line)
    src = re.sub(rf"^-- {name} .*\n^local {name} = .*\n", "", src, flags=re.M)
    src = src.rstrip("\n") + "\n" + note + "\n" + line + "\n"


MID = {"Root": (0.15, -0.4, 0.1, 0, -40, 0), "Torso": (-6, -6, 0), "Head": (0, 40, 0), "LArm": (40, 0, -55), "RLeg": (16, 0, 12), "LLeg": (-12, 0, -12)}
e = place(MID, (0.85, -0.5, -0.6), (0.62, -0.2, 0.76), (40, 30, 0))
MID["W"] = near(MID["W"], REF)
put("RG_MID", MID, f"(팔 어긋남 {e:.3f})")

LEFT = {"Root": (0.6, -0.5, 0.3, 0, -78, 0), "Torso": (-8, 62, 0), "Head": (4, 6, 0), "LArm": (80, 0, -75), "RLeg": (-18, 0, 12), "LLeg": (20, 0, -12)}
e = place(LEFT, (-0.6, -0.55, -0.7), (-0.62, -0.2, 0.76), (60, 20, 0))
LEFT["W"] = near(LEFT["W"], MID["W"])
put("RG_LEFT", LEFT, f"(팔 어긋남 {e:.3f})")
open(OUTF, "w", encoding="utf-8", newline="\n").write(src)
