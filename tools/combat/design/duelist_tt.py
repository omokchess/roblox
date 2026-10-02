"""결투사 찔러찔러또찔러 새 자세(2026-10-02 사용자: "오른쪽에서 중앙으로 한번, 왼쪽에서 중앙으로 한번 총 2초,
1초 텀 두면서 뒤로 약간 빠지고 대기동작 후에 대시하면서 강하게 찌르기").
대상 가슴 T = 대상 앞 3.2 스터드로 다가선 뒤의 자리(0, 0.3, -3.6).
  R_COCK / R_THRUST  오른쪽으로 비켜서(Root x +) 몸을 연 채(돌기 34) 손을 오른 허리 뒤로 당겼다가 → 오른쪽에서 가운데로 비스듬히 찌름
  L_COCK / L_THRUST  왼쪽으로 비켜서(Root x -) 몸을 더 감아(돌기 96 — 오른 어깨가 가운데보다 왼쪽) 손을 왼쪽 앞으로 → 왼쪽에서 가운데로
  STRONG             대시하며 몸을 다 던진 깊은 찌르기(왼팔은 뒤로 뻗어 균형)
쓰는 법: python duelist_tt.py → Luau 줄"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from twohand import *  # noqa: F401,F403

KEYS = ["Root", "Torso", "Head", "RArm", "LArm", "RLeg", "LLeg", "W"]
T = (0, 0.3, -3.6)
POCKET = (14, -6, 10)


def base(root, torso, head, rleg, lleg, larm=POCKET):
    return {"Root": root, "Torso": torso, "Head": head, "RLeg": rleg, "LLeg": lleg, "LArm": larm, "RArm": (60, -30, 0)}


def cock(P, direction):
    pv = pivot(P, "R")
    P["RArm"], err = reach(P, "R", add(pv, scale(norm(direction), ARM)))
    P["W"] = aim_axis(P, "W", sub(T, hand(P, "R")))
    return err


def thrust(P, target=T):
    P["RArm"] = point_arm(P, "R", target)
    P["W"] = (0, 0, 0, -90, 0, 0)


def out(name, P, note=""):
    tip = wpoint(P, "W", (0, 4.6, 0))
    hd = hand(P, "R")
    print(f"-- {name}: 손 {[round(v, 2) for v in hd]} 칼끝 {[round(v, 2) for v in tip]} {note}")
    print(f"local {name} = {{ " + ", ".join(f"{k} = {f(P[k])}" for k in KEYS) + " }")


if __name__ == "__main__":
    R_COCK = base((0.5, -0.45, 0.3, 0, 34, 0), (2, -8, 0), (-2, -28, 0), (24, -20, 12), (-22, 0, -14))
    e = cock(R_COCK, (0.5, -0.72, 0.48))
    out("R_COCK", R_COCK, f"(팔 어긋남 {e:.3f})")
    R_THRUST = base((0.45, -0.58, -0.3, 0, 36, 0), (-14, -6, 0), (10, -26, 0), (52, -20, 10), (-38, 0, -10), (-18, 0, 8))
    thrust(R_THRUST)
    out("R_THRUST", R_THRUST)

    L_COCK = base((-0.85, -0.45, 0.3, 0, 104, 0), (2, -4, 0), (-2, -84, 0), (24, -20, 12), (-22, 0, -14))
    e = cock(L_COCK, (-0.62, -0.55, -0.55))
    out("L_COCK", L_COCK, f"(팔 어긋남 {e:.3f})")
    L_THRUST = base((-0.9, -0.58, -0.3, 0, 104, 0), (-14, -4, 0), (10, -84, 0), (52, -20, 10), (-38, 0, -10), (-18, 0, 8))
    thrust(L_THRUST)
    out("L_THRUST", L_THRUST)

    STRONG = base((-0.8, -0.84, -0.75, 0, 36, 0), (-24, -8, 0), (18, -28, 0), (66, -20, 10), (-50, 0, -10), (-34, 0, -30))
    # 강한 찌르기는 곧게 앞으로(멀리 앞 한 점을 겨눔) — 대시가 손을 대상 바로 앞에 데려다 놓는다
    thrust(STRONG, (0, 0.1, -9))
    out("STRONG", STRONG)
