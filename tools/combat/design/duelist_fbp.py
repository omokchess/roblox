"""결투사 앞뒤관통 새 자세(2026-10-02 사용자: "준비동작(오른쪽 아래로 검을 한번 휘둘렀다가, 펜싱처럼 찌르기 준비) 뒤 쭉 찌르고,
다시 준비동작 하고 뒤에서 한번 더 강하게 찌르도록").
  RISE   휘두르기 전 — 칼끝을 왼쪽 위로 살짝 들어 올림
  SWISH  오른쪽 아래로 휙 — 팔이 오른쪽 아래 바깥, 칼끝은 오른쪽 아래 앞(땅에 안 닿게)
  COCK   펜싱 찌르기 준비 — 뒷발에 무게, 손은 오른 허리 앞으로 당기고 칼끝은 적 가슴을 겨눔(왼손 주머니)
  COCK2  두 번째(더 강하게) — 더 낮고 깊게 웅크리고 왼팔을 뒤로 들어 균형(고전 펜싱 앙가르드)
뒤에서 찌르는 자세는 같은 값에 Root 돌기 +180(몸 전체를 돌리면 팔·칼도 따라 돈다).
쓰는 법: python duelist_fbp.py → Luau 줄"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from twohand import *  # noqa: F401,F403
from duelist_gen import ENEMY, pose

KEYS = ["Root", "Torso", "Head", "RArm", "LArm", "RLeg", "LLeg", "W"]


def arm_to(P, side, direction):
    """어깨 축에서 direction 쪽으로 팔을 쭉 뻗은 손 자리에 팔을 맞춘다"""
    pv = pivot(P, side)
    target = add(pv, scale(norm(direction), ARM))
    v, err = reach(P, side, target)
    return v, err


def blade_to(P, direction):
    return aim_axis(P, "W", direction)


def tip(P):
    return wpoint(P, "W", (0, 4.6, 0))


def out(name, P, note=""):
    t = tip(P)
    print(f"-- {name}: 칼끝 {[round(v, 2) for v in t]} {note}")
    print(f"local {name} = {{ " + ", ".join(f"{k} = {f(P[k])}" for k in KEYS) + " }")


if __name__ == "__main__":
    # 휘두르기 전: 몸은 겨눔 그대로, 팔을 조금 왼쪽 위로 — 칼끝은 왼쪽 위 앞
    RISE = pose(58, (10, -6, 0), (-4, -52, 4))
    RISE["RArm"], e1 = arm_to(RISE, "R", (-0.25, 0.35, -0.9))
    RISE["W"] = blade_to(RISE, (-0.35, 0.55, -0.75))
    out("RISE", RISE, f"(팔 어긋남 {e1:.3f})")

    # 오른쪽 아래로 휙: 몸을 조금 더 열고(돌기 52) 무게를 살짝 낮춤 — 팔은 오른쪽 아래 바깥, 칼끝은 오른쪽 아래 앞
    SWISH = pose(52, (4, -10, -2), (-2, -46, 4), y=-0.22)
    SWISH["RArm"], e2 = arm_to(SWISH, "R", (0.7, -0.62, -0.35))
    SWISH["W"] = blade_to(SWISH, (0.62, -0.34, -0.7))
    out("SWISH", SWISH, f"(팔 어긋남 {e2:.3f})")

    # 펜싱 찌르기 준비: 뒷발에 무게(Root z +), 앞 무릎 굽힘, 손은 오른 허리 앞으로, 칼끝은 적 가슴
    COCK = pose(48, (2, -6, 0), (-2, -44, 2), lleg=(-26, 0, -14), rleg=(30, -26, 12), y=-0.48)
    COCK["Root"] = (0, -0.48, 0.38, 0, 48, 0)
    COCK["RArm"], e3 = arm_to(COCK, "R", (0.28, -0.72, -0.62))
    COCK["W"] = blade_to(COCK, sub(ENEMY, hand(COCK, "R")))
    out("COCK", COCK, f"(팔 어긋남 {e3:.3f})")

    # 두 번째 준비(더 강하게): 더 낮게 웅크리고 손을 더 뒤로, 왼팔은 뒤 위로 들어 균형
    COCK2 = pose(44, (-2, -8, 0), (2, -40, 2), lleg=(-34, 0, -14), rleg=(40, -24, 12), y=-0.66, larm=(150, 0, -50))
    COCK2["Root"] = (0, -0.66, 0.5, 0, 44, 0)
    COCK2["RArm"], e4 = arm_to(COCK2, "R", (0.4, -0.78, -0.48))
    COCK2["W"] = blade_to(COCK2, sub(ENEMY, hand(COCK2, "R")))
    out("COCK2", COCK2, f"(팔 어긋남 {e4:.3f})")
