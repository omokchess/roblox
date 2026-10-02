"""결투사 대기(EG) 자세 계산(2026-10-02 사용자: "너가 나를 이길 수 있을 것 같아?" 느낌).
몸을 더 옆으로 틀어(Root Y) 오른팔을 어깨 높이로 쭉 뻗어 적 가슴을 겨누고(point_arm — 팔 축이 적 쪽),
상체는 뒤로 젖히고, 고개는 적을 내려다본다. 칼은 팔 선과 한 줄(W 숙임 -90). 주머니 왼팔은 앞·안쪽으로 살짝."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from twohand import *

KEYS = ["Root", "Torso", "Head", "RArm", "LArm", "RLeg", "LLeg", "W"]
ENEMY = (0, 0.4, -9)  # 적 가슴(캐릭터 앞 -Z)


def pose(root_y, torso, head, lleg=(-10, 0, -12), rleg=(16, -38, 10), y=-0.12, larm=(14, -6, 10)):
    P = {"Root": (0, y, 0, 0, root_y, 0), "Torso": torso, "Head": head, "RLeg": rleg, "LLeg": lleg, "LArm": larm, "RArm": (88, -40, 0)}
    P["RArm"] = point_arm(P, "R", ENEMY)
    P["W"] = (0, 0, 0, -90, 0, 0)
    return P


def show_(name, P):
    tip = wpoint(P, "W", (0, 4.6, 0))
    h = solve(P)["Head"]
    print(f"-- {name} 칼끝 {[round(v, 2) for v in tip]} 머리 앞 {[round(v, 2) for v in mv(h.R, (0, 0, -1))]}")
    print(f"local {name} = {{ " + ", ".join(f"{k} = {f(P[k])}" for k in KEYS) + " }")


if __name__ == "__main__":
    # 대기: 몸 62° 옆, 상체 뒤로 12°, 고개는 적 쪽으로 돌려 턱을 든 채 내려다봄(머리 X 는 몸통 젖힘을 조금 되돌림)
    EG = pose(62, (12, -6, 0), (-4, -54, 4))
    show_("EG", EG)
    # 숨: 조금 더 젖혔다(뽐냄) 돌아옴 — 팔 겨눔은 그대로(다시 계산)
    show_("EG_IN", pose(62, (15, -6, 1), (-6, -54, 5), y=-0.1, larm=(16, -6, 11)))
    show_("EG_OUT", pose(62, (10, -6, -1), (-3, -53, 3), y=-0.15, larm=(12, -6, 9)))
