"""결투사 방어 태세 자세(2026-11-07 리메이크: 결투 신청·강제 결투 응수).
  GD      방어 태세 가드 대기 — 무게 중심 낮추고 뒷발에 싣고, 칼을 몸 앞에 세워(칼끝 위·앞) 가드
  POINTC  결투 신청의 도전 — 팔을 쭉 뻗어 칼끝을 적 얼굴 높이에 겨눔
  FLOURISH 경례를 푸는 휘두름 — 칼이 오른쪽 아래 바깥으로 갈라짐(칼끝은 땅 위)
  SPREAD  보호막을 펼침 — 칼을 높이 세우고 왼팔을 바깥으로 활짝, 가슴을 엶
  P_OUT / P_IN / P_HIGH  패리 셋 — 바깥(식스트) · 안쪽(바트) · 머리 위(프라임 계열 횡 받기)
쓰는 법: python duelist_guard.py → Luau 줄"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from twohand import *  # noqa: F401,F403
from duelist_gen import pose
from duelist_fbp import arm_to, blade_to, out

if __name__ == "__main__":
    GD = pose(54, (8, -4, 0), (-2, -50, 2), y=-0.36, rleg=(30, -30, 10), lleg=(-24, 0, -12))
    GD["Root"] = (0, -0.36, 0.3, 0, 54, 0)
    GD["RArm"], e = arm_to(GD, "R", (0.12, -0.3, -0.95))
    GD["W"] = blade_to(GD, (0.02, 0.96, -0.28))
    out("GD", GD, f"(어긋남 {e:.3f})")

    PC = pose(62, (10, -6, 0), (-6, -54, 4), y=-0.22)
    PC["Root"] = (0, -0.22, -0.2, 0, 62, 0)
    PC["RArm"] = point_arm(PC, "R", (0, 1.7, -9))
    PC["W"] = (0, 0, 0, -90, 0, 0)
    out("POINTC", PC)

    FL = pose(52, (4, -8, -2), (-2, -44, 4), y=-0.24)
    FL["RArm"], e = arm_to(FL, "R", (0.62, -0.5, -0.6))
    FL["W"] = blade_to(FL, (0.7, -0.25, -0.66))
    out("FLOURISH", FL, f"(어긋남 {e:.3f})")

    SP = pose(30, (-4, -4, 0), (6, -26, 0), y=-0.1, larm=(95, 0, -75))
    SP["Root"] = (0, -0.1, 0.1, 0, 30, 0)
    SP["RArm"], e = arm_to(SP, "R", (0.25, 0.85, -0.45))
    SP["W"] = blade_to(SP, (0.1, 1, -0.1))
    out("SPREAD", SP, f"(어긋남 {e:.3f})")

    for nm, ry, d_arm, d_blade in (
        ("P_OUT", 46, (0.6, -0.1, -0.8), (0.05, 1, -0.1)),
        ("P_IN", 52, (-0.4, -0.05, -0.92), (-0.45, 0.88, -0.15)),
        ("P_HIGH", 44, (0.1, 0.6, -0.8), (0.95, 0.2, -0.25)),
    ):
        P = pose(ry, (8, -4, 0), (-2, -46, 2), y=-0.38, rleg=(32, -28, 10), lleg=(-26, 0, -12))
        P["Root"] = (0, -0.38, 0.45, 0, ry, 0)
        P["RArm"], e = arm_to(P, "R", d_arm)
        P["W"] = blade_to(P, d_blade)
        out(nm, P, f"(어긋남 {e:.3f})")
