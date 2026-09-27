"""나무 산책로(보드워크) 모듈 & 흔들다리.

모든 모듈은 윗면 Z=7, 길이 방향 = 로컬 X. 레이아웃이 폴리라인을 따라 배치한다.
  BoardwalkStraight  : 16 x 7, 낮은 밧줄 난간
  BoardwalkStraightB : 16 x 7, 난간 없음 + 가로등 (변형)
  BoardwalkJunction  : 9 x 9 교차 플랫폼
  BoardwalkRamp      : 16 길이, Z 7 -> 1.2 (땅으로 내려가는 경사로)
  RopeBridge         : 36 길이 처진 흔들다리
"""

import math

from mathutils import Vector

from swamplib.asset import Asset
from swamplib import shapes as S
from assets.dock import lamp_post

DECK = 7.0
W = 7.0
L = 16.0


def _frame(a, x0, x1, w, z, posts=True):
    for x in (x0 + 1.0, x1 - 1.0):
        for y in (-w / 2 + 0.5, w / 2 - 0.5):
            if posts:
                S.stilt(a, x, y, z - 0.6, z_bottom=-7.0, r=0.5, lean=2.0, lash=False)
                a.collider((x, y, (z - 7.0) / 2 - 0.3), (1.0, 1.0, z + 7.0), tag="Stilt")
        a.box((x, 0, z - 1.1), (0.8, w + 0.8, 0.8), "wood_dark", bevel=0.08)
    for y in (-w / 2 + 0.5, w / 2 - 0.5):
        a.box(((x0 + x1) / 2, y, z - 0.8), (x1 - x0, 0.6, 0.6), "wood_dark", bevel=0.06)


def boardwalk_straight():
    a = Asset("BoardwalkStraight", "Path", description="나무 산책로 직선 16 stud (밧줄 난간)")
    _frame(a, -L / 2, L / 2, W, DECK)
    S.plank_floor(a, -L / 2, L / 2, -W / 2, W / 2, DECK, along="y", joists=False, overhang=0.15, keys=("wood_a", "wood_b", "wood_c", "wood_moss"))
    for sy in (-1, 1):
        pts = [(-L / 2 + 0.6, sy * (W / 2 - 0.2)), (0, sy * (W / 2 - 0.2)), (L / 2 - 0.6, sy * (W / 2 - 0.2))]
        S.rope_railing(a, pts, DECK, h=2.6, sag=0.35)
    return a


def boardwalk_straight_b():
    a = Asset("BoardwalkStraightB", "Path", description="나무 산책로 직선 16 stud (난간 없음, 가로등)")
    _frame(a, -L / 2, L / 2, W, DECK)
    S.plank_floor(a, -L / 2, L / 2, -W / 2, W / 2, DECK, along="y", joists=False, overhang=0.15, missing=0.06, keys=("wood_a", "wood_b", "wood_c", "wood_moss"))
    lamp_post(a, (2.0, W / 2 - 0.3, DECK), h=8.0)
    with a.no_parts():
        for k in range(5):
            a.sphere((a.rng.uniform(-7, 7), a.rng.choice((-1, 1)) * (W / 2 - 0.2), DECK - 0.5), a.rng.uniform(0.4, 0.8), "moss", seg=7, rings=4, scale=(1.5, 1.0, 0.5))
    return a


def boardwalk_junction():
    a = Asset("BoardwalkJunction", "Path", description="나무 산책로 교차 플랫폼 9x9")
    J = 9.0
    for x in (-J / 2 + 0.6, J / 2 - 0.6):
        for y in (-J / 2 + 0.6, J / 2 - 0.6):
            S.stilt(a, x, y, DECK - 0.6, z_bottom=-7.0, r=0.6)
            a.collider((x, y, (DECK - 7.0) / 2 - 0.3), (1.1, 1.1, DECK + 7.0), tag="Stilt")
    for x in (-J / 2 + 0.6, J / 2 - 0.6):
        a.box((x, 0, DECK - 1.1), (0.8, J + 0.6, 0.8), "wood_dark", bevel=0.08)
    S.plank_floor(a, -J / 2, J / 2, -J / 2, J / 2, DECK, along="x", joists=False, overhang=0.1)
    # 중앙 모서리 기둥 + 랜턴
    S.post(a, J / 2 - 0.6, J / 2 - 0.6, DECK, DECK + 7.5, 0.6)
    a.box_between((J / 2 - 0.6, J / 2 - 0.6, DECK + 7.3), (J / 2 - 2.2, J / 2 - 2.2, DECK + 7.3), 0.3, "wood_dark", width=0.3)
    S.lantern(a, (J / 2 - 2.2, J / 2 - 2.2, DECK + 6.2), hang=0.3, rng_range=22, brightness=1.4)
    return a


def boardwalk_ramp():
    a = Asset("BoardwalkRamp", "Path", description="나무 산책로 경사로 (Z 7 -> 1.2)")
    z0, z1 = DECK, 1.2
    x0, x1 = -L / 2, L / 2
    ang = math.degrees(math.atan2(z0 - z1, x1 - x0))
    n = 14
    for i in range(n):
        t = (i + 0.5) / n
        x = x0 + (x1 - x0) * t
        z = z0 + (z1 - z0) * t
        a.box((x, 0, z - 0.2), ((x1 - x0) / n + 0.1, W - 0.3 + a.rng.uniform(-0.2, 0.2), 0.34), S.pick(a, S.WOOD), rot=(0, ang + a.rng.uniform(-1, 1), a.rng.uniform(-1, 1)), bevel=0.05)
    for y in (-W / 2 + 0.5, W / 2 - 0.5):
        a.box_between((x0, y, z0 - 0.7), (x1, y, z1 - 0.7), 0.8, "wood_dark", width=0.5)
        for t in (0.1, 0.5):
            x = x0 + (x1 - x0) * t
            z = z0 + (z1 - z0) * t
            a.cyl((x, y, -3.0), (x, y, z - 0.6), 0.5, "wood_wet", sides=8)
    a.collider_between((x0, 0, z0 + 0.05), (x1, 0, z1 + 0.05), W - 0.3, 1.0, tag="Ramp")
    return a


def rope_bridge():
    a = Asset("RopeBridge", "Path", description="흔들다리 36 stud (처진 판자 + 밧줄 손잡이)")
    Lb = 36.0
    sag = 2.6
    x0, x1 = -Lb / 2, Lb / 2
    def zc(x):
        t = (x - x0) / (x1 - x0)
        return DECK - sag * 4 * t * (1 - t)
    # 양끝 기둥
    for x in (x0, x1):
        for y in (-3.0, 3.0):
            S.post(a, x, y, DECK - 1.5, DECK + 4.2, 0.7)
            a.cyl((x, y, DECK + 4.2), (x, y, DECK + 4.5), 0.5, "wood_dark", sides=8)
    # 판자
    n = int(Lb / 1.25)
    for i in range(n):
        x = x0 + (i + 0.5) * Lb / n
        dz = (zc(x + 0.1) - zc(x - 0.1)) / 0.2
        a.box((x, 0, zc(x) - 0.15), (1.0, 5.2 + a.rng.uniform(-0.3, 0.3), 0.26), S.pick(a, S.WOOD),
              rot=(a.rng.uniform(-2, 2), -math.degrees(math.atan(dz)), a.rng.uniform(-3, 3)), bevel=0.04)
    # 밧줄: 바닥 지지줄 + 손잡이줄 + 수직 연결줄
    for y in (-2.5, 2.5):
        pts = [Vector((x0 + Lb * k / 16, y, zc(x0 + Lb * k / 16) - 0.35)) for k in range(17)]
        a.tube(pts, 0.14, "rope", sides=5, caps=False, part_step=4)
    for y in (-3.0, 3.0):
        pts = [Vector((x0 + Lb * k / 16, y, zc(x0 + Lb * k / 16) + 3.4 + sag * 0.55 * 4 * (k / 16) * (1 - k / 16))) for k in range(17)]
        a.tube(pts, 0.16, "rope", sides=5, caps=False, part_step=4)
        with a.no_parts():
            for k in range(1, 16):
                x = x0 + Lb * k / 16
                a.cyl((x, y * 0.85, zc(x) - 0.3), (x, y, zc(x) + 3.4 + sag * 0.55 * 4 * (k / 16) * (1 - k / 16)), 0.06, "rope", sides=4)
    # 콜라이더: 처진 곡선을 따라 분절
    seg = 6
    for k in range(seg):
        xa = x0 + Lb * k / seg
        xb = x0 + Lb * (k + 1) / seg
        a.collider_between((xa, 0, zc(xa) + 0.05), (xb, 0, zc(xb) + 0.05), 5.4, 0.8, tag="Bridge")
        for y in (-3.3, 3.3):
            zm = (zc(xa) + zc(xb)) / 2
            a.collider(((xa + xb) / 2, y, zm + 1.8), (xb - xa, 0.4, 3.6), rot=(0, -math.degrees(math.atan2(zc(xb) - zc(xa), xb - xa)), 0), tag="Rail")
    return a


ASSETS = [boardwalk_straight, boardwalk_straight_b, boardwalk_junction, boardwalk_ramp, rope_bridge]
