"""광전사 자세 다시(2026-10-03 사용자: "공격할 때 도끼를 이상하게 잡아. 스탠딩 때 도끼를 뒤가 아니라 앞을 향하게.
격분(피격 포효)·스킬 모션 수정"). 데인 액스: 두 손을 벌려 오른손은 머리 쪽(무기 y 1.1), 왼손은 자루 아래(y -0.45).
베기마다 날(-Z)이 휘두르는 쪽을 앞서게, 땅에 닿는 자세는 도끼 머리 가장 낮은 점을 땅 바로 위로(기울기 찾기).
결과: berserker2_out.txt (berserker_motions.py 가 읽어 Berserker.luau 를 만든다). 쓰는 법: python berserker2_gen.py"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from twohand import *  # noqa: F401,F403

HERE = os.path.dirname(os.path.abspath(__file__))
KEYS = ["Root", "Torso", "Head", "RArm", "LArm", "RLeg", "LLeg", "W"]
HEAD_PTS = [(0, 3.45, 0), (0, 4.32, -1.3), (0, 4.0, -1.0), (0, 3.6, -1.39), (0, 2.6, -1.33), (0, 1.96, -1.26), (0, 2.2, -0.7), (0, 4.0, 0), (0, 3.45, 0.45)]
RY, LY = 1.1, -0.45
GRIP_Y = -0.15
lines = []
ONLY = set(sys.argv[1:])  # 이름을 주면 그 자세만 다시 구해 berserker2_out.txt 에 덮어 넣는다


def want_pose(name):
    return not ONLY or name in ONLY


def lowest(P):
    return min(wpoint(P, "W", p)[1] for p in HEAD_PTS)


def base(root, torso, head, rleg, lleg, larm=(4, 0, -12), rarm=(60, 0, 0)):
    return {"Root": root, "Torso": torso, "Head": head, "RLeg": rleg, "LLeg": lleg, "LArm": larm, "RArm": rarm}


def show(name, P, note=""):
    line = f"local {name} = {{ " + ", ".join(f"{k} = {f(P[k])}" for k in KEYS) + " }"
    lines.append(f"-- {name} {note} (머리 가장 낮은 점 {lowest(P):.2f})")
    lines.append(line)
    print(lines[-2])


def fit(name, P, grip_t, dirxz, pitches, zhint, want=None, ry=RY, ly=LY, **kw):
    if not want_pose(name):
        return
    pitch, eR, eL, m = two_fit(P, grip_t, dirxz, pitches, zhint, measure=lowest, want=want, left_y=ly, right_y=ry, **kw)
    show(name, P, f"(기울기 {pitch}°, 팔 어긋남 {eR}/{eL})")


def frame_flat(d):
    """날 축 d, 날 면이 땅에 눕게(무기 X 가 위), 날(-Z)은 바깥 오른쪽"""
    up = (0, 1, 0)
    x = norm(sub(up, scale(d, sum(a * b for a, b in zip(up, d)))))
    z = cross(x, d)
    if -z[0] < 0:
        x = scale(x, -1)
        z = cross(x, d)
    return tuple(tuple(v[i] for v in (x, d, z)) for i in range(3))


def one_drag(name, P, yaw_deg, back, want=-2.97):
    """한 손으로 자루 아래를 쥐고 도끼 머리를 땅에 눕혀 둔다(back = 뒤쪽이면 True). 머리 가장 낮은 점이 want 가 되게 기울기를 찾는다"""
    if not want_pose(name):
        return
    h = hand(P, "R")
    best = None
    for k in range(5, 80):
        p, yw = math.radians(k), math.radians(yaw_deg)
        dz = math.cos(yw) * math.cos(p) * (1 if back else -1)
        d = norm((math.sin(yw) * math.cos(p), -math.sin(p), dz))
        Q = dict(P)
        Q["W"] = aim(Q, "W", frame_flat(d), add(h, scale(d, -GRIP_Y)))
        e = abs(lowest(Q) - want)
        if best is None or e < best[0]:
            best = (e, Q, k)
    P.update(best[1])
    show(name, P, f"(한 손, 자루 기울기 {best[2]}°)")


if __name__ == "__main__":
    # 대기(차분한 전투광): 꼿꼿이 힘 빼고, 오른손을 늘어뜨려 자루 아래를 쥐고 도끼 머리는 **오른쪽 앞** 땅에 눕힌다(2026-10-03: 뒤 → 앞)
    CALM = base((0, -0.06, 0, 0, -18, 0), (-6, 2, 0), (-6, 16, -3), (4, 0, 7), (-3, 0, -7), (2, 0, -7), (12, 0, 8))
    one_drag("CALM", CALM, 24, False)
    # 돌진·회피: 웅크려 한 손으로 도끼를 뒤 땅에 끈다
    DRAG = base((0, -1.0, 0.2, 0, -16, 0), (-40, 0, 0), (30, 12, 0), (40, 0, 18), (-34, 0, -18), (24, -22, 0), (20, 22, 14))
    one_drag("DRAG", DRAG, 20, True)

    # 머리 위 치켜듦(내려찍기 예비): 두 손을 머리 위로, 도끼 머리는 등 뒤, 날은 위
    RAISE = base((0, -0.15, 0.25, 0, -16, 0), (14, 0, 0), (18, 12, 0), (16, 0, 14), (-18, 0, -14))
    fit("RAISE", RAISE, (0.1, 2.0, -0.2), (0.15, 0.99), range(-10, 61, 4), (0, 1, 0), hintR=(165, 20, 0), hintL=(165, -20, 0))
    # 내려찍은 끝: 깊게 숙여 두 손이 배 앞 아래, 날이 앞 땅에 박힌다
    CHOP = base((0, -0.95, -0.6, 0, -16, 0), (-38, 0, 0), (26, 10, 0), (46, 0, 14), (-36, 0, -14))
    fit("CHOP", CHOP, (0.05, -0.4, -1.1), (0, -1), range(-10, 41, 2), (0, -1, 0), want=-3.02, hintR=(60, 20, 0), hintL=(60, -20, 0))
    # 쌍베기: 오른 위 예비 → 왼 아래 끝, 왼 위 예비 → 오른 아래 끝 (날은 늘 휘두르는 쪽)
    A0 = base((0, -0.3, 0.2, 0, -40, 0), (-2, -28, 0), (12, 40, 0), (30, 0, 18), (-24, 0, -18))
    fit("CUT_A0", A0, (0.65, 1.2, -0.3), (0.6, 0.8), range(10, 71, 4), (-0.5, -0.3, -0.8), hintR=(150, 30, 0), hintL=(130, -10, 0))
    A1 = base((0, -0.8, -0.5, 0, 0, 0), (-34, 22, 0), (24, -12, 0), (40, 0, 18), (-34, 0, -18))
    # 크게 벤 끝은 위 손을 아래로 미끄러뜨려 두 손을 모은다(데인 액스 쥐는 법) — 곧은 R6 팔로 왼쪽 아래까지 닿게
    fit("CUT_A1", A1, (-0.25, -0.45, -1.05), (-0.6, -0.8), range(-40, 21, 4), (-0.6, -0.8, 0), want=-2.9, ry=0.35, hintR=(70, -20, 0), hintL=(70, -60, 0))
    B0 = base((0, -0.4, -0.3, 0, 20, 0), (-6, 34, 0), (14, -22, 0), (30, 0, 18), (-24, 0, -18))
    fit("CUT_B0", B0, (-0.35, 1.4, -0.5), (-0.6, 0.8), range(20, 81, 4), (0.5, -0.3, -0.8), hintR=(140, -10, 0), hintL=(150, -40, 0))
    B1 = base((0, -0.8, -0.9, 0, -30, 0), (-34, -28, 0), (26, 30, 0), (44, 0, 18), (-38, 0, -18))
    fit("CUT_B1", B1, (0.45, -0.45, -1.0), (0.6, -0.8), range(-30, 41, 2), (0.6, -0.8, 0), want=-2.95, hintR=(70, 40, 0), hintL=(70, -20, 0))
    # 회오리: 두 손을 자루 아래에 모아 도끼를 오른쪽으로 수평으로 뻗는다
    WH = base((0, -0.5, 0, 0, 30, 0), (-14, 30, 0), (20, -30, 0), (30, 0, 18), (-24, 0, -18))
    fit("WHIRL", WH, (0.55, -0.1, -0.75), (1, -0.15), range(-10, 31, 4), (0, 0, -1), want=-1.2, ry=0.2, ly=-0.5, hintR=(80, 60, 0), hintL=(80, 0, 0))
    # 막기: 자루를 가로로 들어 얼굴 앞에서 받는다(두 손을 벌려)
    BL = base((0, -0.6, 0.25, 0, -10, 0), (-12, 0, 0), (16, 10, 0), (28, 0, 16), (-22, 0, -16))
    fit("BLOCK", BL, (-0.3, 1.0, -0.9), (1, 0), [4], (0, 1, 0), hintR=(100, 40, 0), hintL=(100, -40, 0))
    # 호흡: 도끼 머리를 앞 땅에 짚고(자루가 몸보다 길어 비스듬히) 두 손을 가슴 앞 자루 끝에 포갠 채 기댄다
    BR = base((0, -0.08, 0, 0, -18, 0), (-4, 0, 0), (-2, 16, 0), (6, 0, 8), (-4, 0, -8))
    fit("BREATH", BR, (0.0, 0.35, -1.0), (0, -1), range(-80, -29, 2), (0, 0, -1), want=-2.98, ry=-0.85, ly=-1.1, hintR=(80, 20, 0), hintL=(80, -20, 0))
    # 포효(피격): 한 손으로 도끼를 머리 위로 치켜들고 가슴을 펴 고개를 젖힌다. 왼 주먹은 쥐고 아래로
    ROAR = base((0, -0.22, 0.1, 0, -18, 0), (18, 0, 0), (34, 12, 0), (16, 0, 14), (-14, 0, -14), (34, 0, -18), (168, 10, 6))
    h = hand(ROAR, "R")
    d = norm((0.1, 0.95, 0.3))
    ROAR["W"] = aim(ROAR, "W", frame(d, (0, 0, -1)), add(h, scale(d, -GRIP_Y)))
    if want_pose("ROAR"):
        show("ROAR", ROAR, "(한 손)")
    # 들림(차분): 축 늘어져 매달리고 도끼는 한 손에 머리가 아래로 — berserker_calm.py 와 같은 값
    HANG = base((0, 0, 0, 2, -18, 0), (-4, 0, 0), (-12, 20, 0), (6, 0, 4), (-2, 0, -4), (0, 0, -6), (-4, 0, 6))
    h = hand(HANG, "R")
    d = norm((0.08, -1, 0.12))
    HANG["W"] = aim(HANG, "W", frame(d, (1, 0, 0)), add(h, scale(d, -GRIP_Y)))
    if want_pose("CALM_HANG"):
        show("CALM_HANG", HANG, "(한 손)")
    # 덮어 넣기(이름 단위)
    import re

    path = os.path.join(HERE, "berserker2_out.txt")
    old = open(path, encoding="utf-8").read() if ONLY and os.path.exists(path) else ""
    new = "\n".join(lines) + "\n"
    for name in re.findall(r"^local (\w+) =", new, re.M):
        old = re.sub(r"^-- " + name + r" .*\n^local " + name + r" = .*\n", "", old, flags=re.M)
    open(path, "w", encoding="utf-8", newline="\n").write(old + new)
