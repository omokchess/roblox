"""늪개구리 주점 (Longhouse Tavern) — 마을 중심 건물.

통나무 벽, 큰 맞배지붕, 앞 차양 베란다, 돌 굴뚝 2개, 실내(바/테이블/화덕).
"""

import math

from mathutils import Vector

from swamplib.asset import Asset
from swamplib import shapes as S
from assets.stilt_house import _stilt_grid, _stone_chimney


def _table_bench(a, x, y, z, yaw=0.0, length=6.0):
    with a.at(loc=(x, y, z), rot=(0, 0, yaw)):
        a.box((0, 0, 2.6), (length, 2.8, 0.32), "wood_c", bevel=0.06)
        for sx in (-1, 1):
            a.box_between((sx * (length / 2 - 0.8), -1.1, 0), (sx * (length / 2 - 0.8), 1.1, 2.45), 0.35, "wood_dark", width=0.3)
            a.box_between((sx * (length / 2 - 0.8), 1.1, 0), (sx * (length / 2 - 0.8), -1.1, 2.45), 0.35, "wood_dark", width=0.3)
        for sy in (-1, 1):
            a.box((0, sy * 2.4, 1.45), (length - 0.4, 1.1, 0.26), "wood_b", bevel=0.05)
            for sx in (-1, 1):
                a.box((sx * (length / 2 - 0.9), sy * 2.4, 0.7), (0.3, 0.8, 1.4), "wood_dark", bevel=0.04)
        # 잔/접시
        with a.no_parts():
            for k in range(3):
                px = -length / 2 + 1.2 + k * (length - 2.4) / 2
                a.cyl((px, 0.4 * (-1) ** k, 2.76), (px, 0.4 * (-1) ** k, 3.3), 0.26, "wood_pale", sides=8)
                a.cyl((px + 0.6, -0.3, 2.76), (px + 0.6, -0.3, 2.84), 0.5, "wood_pale", sides=10)
    a.collider((x, y, z + 1.5), (length, 2.8, 3.0), rot=(0, 0, yaw), tag="Prop")


def _frog_emblem(a, pos, s=1.0):
    """간판용 개구리 문양."""
    with a.at(loc=pos, scale=s):
        a.sphere((0, 0, 0), 0.9, "lily", seg=10, rings=6, scale=(1.2, 0.35, 0.8))
        for sx in (-1, 1):
            a.sphere((sx * 0.55, -0.1, 0.62), 0.32, "lily", seg=8, rings=5, scale=(1, 0.8, 1))
            a.sphere((sx * 0.6, -0.32, 0.68), 0.14, "wood_wet", seg=6, rings=4)
            a.box_between((sx * 0.8, 0, -0.3), (sx * 1.5, 0, -0.8), 0.22, "lily", width=0.2)
            a.box_between((sx * 1.5, 0, -0.8), (sx * 1.3, 0, -1.1), 0.2, "lily", width=0.2)


def longhouse():
    a = Asset("Longhouse", "Building", description="늪개구리 주점 — 마을 중앙 통나무 건물")
    Z = 7.0
    _stilt_grid(a, -22, 22, -16, 16, Z, 5, 4)
    S.plank_floor(a, -24, 24, -18, 18, Z, along="x")
    x0, x1, y0, y1 = -16, 16, -3, 15
    zt = Z + 12
    # 통나무 벽 (모서리에서 교차 돌출)
    S.log_wall(a, (x0, y0), (x1, y0), Z, zt, openings=[(12.5, 19.5, Z, Z + 9.0), (4.0, 8.0, Z + 4.0, Z + 8.0), (24.0, 28.0, Z + 4.0, Z + 8.0)], keys=("wood_dark", "bark", "wood_wet"))
    S.log_wall(a, (x1, y1), (x0, y1), Z, zt, openings=[(6.0, 10.0, Z + 4.0, Z + 8.0), (22.0, 26.0, Z + 4.0, Z + 8.0)], keys=("wood_dark", "bark", "wood_wet"))
    S.log_wall(a, (x1, y0), (x1, y1), Z, zt, openings=[(7.0, 11.0, Z + 4.0, Z + 8.0)], keys=("wood_dark", "bark", "wood_wet"))
    S.log_wall(a, (x0, y1), (x0, y0), Z, zt, openings=[(7.5, 11.5, Z, Z + 8.5)], keys=("wood_dark", "bark", "wood_wet"))
    # 창문 덧문
    for (u, v) in ((4.0, Z + 4.0), (24.0, Z + 4.0)):
        with a.at(loc=(x0, y0 - 0.6, 0)):
            S.window(a, u, v, 4.0, 4.0, keys=("wood_red",), outward=-1)
    # 이중문 (열림)
    with a.at(loc=(x0, y0 - 0.6, 0)):
        S.door(a, 12.5, 3.5, 9.0, Z, keys=("wood_red",), open_angle=105, hinge_left=True)
        S.door(a, 16.0, 3.5, 9.0, Z, keys=("wood_red",), open_angle=105, hinge_left=False)
    # 박공 (세로 판자, 삼각)
    span = y1 - y0
    pitch = 34
    for xw in (x0, x1):
        prof = (lambda u, s=span: zt + (s / 2 - abs(u - s / 2)) * math.tan(math.radians(pitch)) - 0.3)
        S.plank_wall(a, (xw, y0), (xw, y1), zt - 0.6, zt, top_profile=prof, battens=True, collider=False, jag=0.0,
                     keys=("wood_b", "wood_c", "wood_moss"), outward=-1 if xw > 0 else 1)
    zr = S.gable_roof(a, 0, (y0 + y1) / 2, zt, x1 - x0, span, pitch=pitch, overhang=2.4, gable_over=2.0, moss=0.1)
    _stone_chimney(a, -9, y1 + 1.7, Z - 0.3, zr + 2.2, w=3.0)
    _stone_chimney(a, 9, y1 + 1.7, Z - 0.3, zr + 1.2, w=2.6)
    # 앞 차양 (외쪽지붕) + 기둥
    for x in (-15.5, -8, 0, 8, 15.5):
        if abs(x) < 1:
            continue
        S.post(a, x, -10.5, Z, Z + 9.6, 0.75)
        a.box_between((x, -10.5, Z + 7.6), (x, -8.6, Z + 9.4), 0.35, "wood_dark", width=0.35)
    a.box_between((-16.5, -10.5, Z + 9.7), (16.5, -10.5, Z + 9.7), 0.8, "wood_dark", width=0.7)
    S.shed_roof(a, -16.5, 16.5, -11.0, y0 - 0.4, Z + 9.9, Z + 11.8, overhang=1.2, moss=0.08)
    # 간판
    a.box_between((-1.0, -9.8, Z + 9.2), (-1.0, -9.8, Z + 8.1), 0.12, "iron", width=0.12)
    a.box_between((1.0, -9.8, Z + 9.2), (1.0, -9.8, Z + 8.1), 0.12, "iron", width=0.12)
    a.box((0, -9.8, Z + 7.2), (8.0, 0.4, 2.0), "wood_pale", bevel=0.08)
    a.box((0, -9.8, Z + 7.2), (8.5, 0.3, 2.4), "wood_dark", bevel=0.08)
    _frog_emblem(a, (-4.9, -10.0, Z + 7.2), s=0.9)
    a.marker("Sign", (0, -10.03, Z + 7.2), rot=(0, 0, 180), text="늪개구리 주점", width=7.2, height=1.8)
    # 난간 (정면/측면 입구 제외)
    S.railing(a, [(-23.6, -17.6), (-5.0, -17.6)], Z)
    S.railing(a, [(5.0, -17.6), (23.6, -17.6), (23.6, -3.0)], Z)
    S.railing(a, [(23.6, 3.0), (23.6, 17.6), (-23.6, 17.6), (-23.6, 3.0)], Z)
    S.railing(a, [(-23.6, -3.0), (-23.6, -17.6)], Z)
    for (px, py) in ((-23.6, -17.6), (23.6, -17.6), (23.6, 17.6), (-23.6, 17.6)):
        S.lantern(a, (px, py, Z + 5.2), light=True, rng_range=18, brightness=1.2)
    a.marker("Entrance", (0, -18.3, Z + 0.1), rot=(0, 0, 180))
    a.marker("EntranceE", (24.3, 0, Z + 0.1), rot=(0, 0, 90))
    a.marker("EntranceW", (-24.3, 0, Z + 0.1), rot=(0, 0, -90))
    # 베란다 테이블
    _table_bench(a, -11, -14.2, Z, 0)
    _table_bench(a, 11, -14.2, Z, 0)
    S.barrel(a, (-21.5, -8.0, Z))
    S.barrel(a, (-21.3, -5.2, Z), h=2.8, r=1.05, key="wood_c")
    S.crate(a, (21.0, -7.0, Z), 2.6, 10)
    S.crate(a, (21.2, -4.2, Z), 2.4, -6)
    S.sack(a, (18.6, -6.2, Z), key="straw")
    S.lantern(a, (-3.2, y0 - 1.6, Z + 9.6), bracket=(0, 1))
    S.lantern(a, (3.2, y0 - 1.6, Z + 9.6), bracket=(0, 1))
    # ── 실내 ──
    # 바 카운터
    a.box((6.0, 11.0, Z + 1.8), (14.0, 1.6, 3.6), "wood_dark", bevel=0.1)
    a.box((6.0, 10.9, Z + 3.75), (14.6, 2.2, 0.3), "wood_c", bevel=0.08)
    a.collider((6.0, 11.0, Z + 1.9), (14.0, 1.6, 3.8), tag="Prop")
    # 술통 선반 (뒤)
    for k in range(4):
        S.barrel(a, (0.5 + k * 3.6, 13.6, Z + 0.3), h=2.8, r=1.1, lying=False)
    a.box((6.0, 13.6, Z + 3.4), (15.0, 2.6, 0.3), "wood_c", bevel=0.05)
    for k in range(10):
        S.bottle(a, (-0.5 + k * 1.4, 13.8, Z + 3.55), h=a.rng.uniform(0.7, 1.1), key=("glass_green", "glass", "glass_green", "glow_potion")[k % 4])
    # 화덕 (왼쪽)
    a.box((-9, 13.4, Z + 2.5), (6.0, 2.4, 5.0), "stone_dk", bevel=0.2)
    a.box((-9, 12.7, Z + 1.6), (3.4, 1.2, 2.8), "wood_wet", bevel=0.1)
    for k in range(3):
        a.cyl((-10.2 + k * 1.2, 12.4, Z + 0.6), (-10.0 + k * 1.1, 13.4, Z + 0.7), 0.3, "wood_dark", sides=6)
    a.sphere((-9, 12.6, Z + 1.2), 0.8, "glow_fire", seg=8, rings=5, scale=(1.3, 0.7, 1.2))
    a.light((-9, 11.8, Z + 2.2), color=(255, 140, 60), range_=26, brightness=2.0)
    a.marker("Fire", (-9, 12.6, Z + 1.2))
    # 테이블
    _table_bench(a, -8, 3.0, Z, 90, 5.5)
    _table_bench(a, 0, 3.0, Z, 90, 5.5)
    for x in (-10, 8):
        S.lantern(a, (x, 6, zt - 1.5), hang=1.2, rng_range=24, brightness=1.3)
    # 박제 (사슴뿔 해골) 장식
    with a.no_parts():
        a.sphere((0, y1 - 0.9, Z + 9.5), 0.9, "bone", seg=8, rings=6, scale=(0.8, 0.8, 1.0))
        for sx in (-1, 1):
            pts = [Vector((sx * 0.5, y1 - 1.0, Z + 10.1)), Vector((sx * 1.6, y1 - 1.1, Z + 11.0)), Vector((sx * 2.2, y1 - 1.0, Z + 12.2)), Vector((sx * 2.0, y1 - 1.0, Z + 13.0))]
            a.tube(pts, [0.2, 0.16, 0.12, 0.05], "bone", sides=6, part=False)
    return a


ASSETS = [longhouse]
