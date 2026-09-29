# -*- coding: utf-8 -*-
"""
swamp_interior_design.py — 늪지대 집 인테리어 손배치표. (2026-09-28)
swamp_rooms.py 가 불러 쓴다. 좌표는 에셋 좌표(참고 파이썬 코드와 같음: x·y 바닥, z 위, 방 치수는 각 에셋 코드에서).
  ROOMS[에셋](ia)  → 방 바닥 사각형 [(M, x0, x1, y0, y1, z)] (바닥 받침판용)
  DESIGN[에셋](ia) → 소품을 ia 에 놓는다(swamplib 소품 함수 그대로라 기존 집과 모양·색이 같다)
자리는 평면도(tools/swamp/room_<에셋>_plan.png, 모눈 1 스터드)를 보고 기존 가구·문·창을 피해 손으로 정했다.
"""
import math

from mathutils import Matrix, Vector

from swamplib import shapes as S
from swamplib.asset import rot_matrix

I = Matrix.Identity(4)
D = 10.0  # StiltHouseB2 몸체 밀림


def _witch_tilt():
    """마녀 집 몸체 틀(witch_hut.py 와 같은 변환) — 벽에 붙는 것은 이 틀."""
    return Matrix.Translation(Vector((0, 1.2, 0))) @ rot_matrix((1.5, -2.5, 3))


def _witch_flat():
    """바닥은 기울지 않았다 — 바닥에 놓는 것은 방향(3°)만 맞춘 이 틀."""
    return Matrix.Translation(Vector((0, 1.2, 0))) @ rot_matrix((0, 0, 3))


ROOMS = {
    "Longhouse": lambda ia: [(I, -16, 16, -3, 15, 7.0)],
    "StiltHouseA": lambda ia: [(I, -8.5, 8.5, -4.5, 9.0, 7.0)],
    "StiltHouseB2": lambda ia: [(I, -7.5, 7.5, -6 + D, 7.5 + D, 7.0), (I, -9.1, 9.1, 2.4, 17.7, 18.2)],
    "StiltHutC": lambda ia: [(I, -6, 6, -4.5, 6, 6.0)],
    "WitchHut": lambda ia: [(_witch_flat(), -6.5, 6.5, -5, 7, 6.5)],
}


# ─────────────────────────────────────────────────────────────
# 가구 조각(모두 z = 바닥 윗면, yaw = 도)
# ─────────────────────────────────────────────────────────────
def table(ia, x, y, z, w, d, h=2.6, yaw=0.0, top="wood_c", leg="wood_dark"):
    with ia.at(loc=(x, y, z), rot=(0, 0, yaw)):
        ia.box((0, 0, h - 0.15), (w, d, 0.3), top, bevel=0.06)
        for sx in (-1, 1):
            for sy in (-1, 1):
                ia.box((sx * (w / 2 - 0.35), sy * (d / 2 - 0.35), (h - 0.3) / 2), (0.3, 0.3, h - 0.3), leg, bevel=0.04)
        # 다리 잇는 가로대
        ia.box((0, 0, 0.6), (w - 0.8, 0.18, 0.18), leg, bevel=0.02)
    return z + h


def stool(ia, x, y, z, h=1.6, key="wood_b", leg="wood_dark", r=0.6, yaw=0.0):
    with ia.at(loc=(x, y, z), rot=(0, 0, yaw)):
        ia.cyl((0, 0, h - 0.2), (0, 0, h), r, key, sides=10)
        for k in range(3):
            a = math.radians(90 + k * 120)
            ia.box_between((math.cos(a) * r * 0.55, math.sin(a) * r * 0.55, h - 0.2), (math.cos(a) * r * 0.85, math.sin(a) * r * 0.85, 0), 0.16, leg, width=0.16)


def chair(ia, x, y, z, yaw=0.0, seat="wood_b", frame="wood_dark", cushion=None):
    """등받이 의자. yaw 0 = 앉은 사람이 +Y 를 봄."""
    with ia.at(loc=(x, y, z), rot=(0, 0, yaw)):
        ia.box((0, 0, 1.55), (1.5, 1.5, 0.22), seat, bevel=0.04)
        for sx in (-1, 1):
            for sy in (-1, 1):
                ia.box((sx * 0.6, sy * 0.6, 0.75), (0.2, 0.2, 1.5), frame, bevel=0.03)
            ia.box((sx * 0.6, -0.62, 2.55), (0.2, 0.2, 2.0), frame, bevel=0.03)
        ia.box((0, -0.62, 3.0), (1.3, 0.14, 0.7), seat, bevel=0.03)
        ia.box((0, -0.62, 2.2), (1.3, 0.12, 0.16), frame, bevel=0.02)
        if cushion:
            ia.box((0, 0.05, 1.75), (1.25, 1.25, 0.2), cushion, bevel=0.08)


def bench(ia, x, y, z, length, yaw=0.0, key="wood_b"):
    with ia.at(loc=(x, y, z), rot=(0, 0, yaw)):
        ia.box((0, 0, 1.55), (length, 1.2, 0.26), key, bevel=0.05)
        for sx in (-1, 1):
            ia.box((sx * (length / 2 - 0.5), 0, 0.72), (0.3, 1.0, 1.44), "wood_dark", bevel=0.03)


def rug(ia, x, y, z, w, d, key="cloth_red", border="cloth_green", yaw=0.0, stripes=0):
    """얇은 깔개(윗면 z+0.1 — 판자 윗면 들쭉날쭉보다 위라 겹쳐 반짝이지 않는다)."""
    with ia.at(loc=(x, y, z), rot=(0, 0, yaw)):
        ia.box((0, 0, 0.05), (w, d, 0.1), border, bevel=0.0)
        ia.box((0, 0, 0.07), (w - 0.6, d - 0.6, 0.1), key, bevel=0.0)
        for k in range(stripes):
            u = -d / 2 + 0.3 + (d - 0.6) * (k + 1) / (stripes + 1)
            ia.box((0, u, 0.09), (w - 0.6, 0.22, 0.1), border, bevel=0.0)


def round_rug(ia, x, y, z, r, key="cloth_purple", border="cloth_red"):
    ia.cyl((x, y, z), (x, y, z + 0.1), r, border, sides=20)
    ia.cyl((x, y, z + 0.02), (x, y, z + 0.12), r - 0.35, key, sides=20)


def bed(ia, x, y, z, yaw=0.0, w=3.4, L=6.0, blanket="cloth_green", frame="wood_dark", pillow="paint_white", fold="cloth_red"):
    """침대. yaw 0 = 머리가 +Y."""
    with ia.at(loc=(x, y, z), rot=(0, 0, yaw)):
        ia.box((0, 0, 0.8), (w, L, 0.7), frame, bevel=0.06)
        for sx in (-1, 1):
            for sy in (-1, 1):
                ia.box((sx * (w / 2 - 0.2), sy * (L / 2 - 0.2), 0.6), (0.34, 0.34, 1.2), frame, bevel=0.04)
        ia.box((0, L / 2 - 0.1, 1.9), (w, 0.3, 1.6), frame, bevel=0.05)  # 머리판
        ia.box((0, 0, 1.4), (w - 0.3, L - 0.4, 0.5), "straw", bevel=0.12)
        ia.box((0, -0.6, 1.75), (w - 0.1, L - 1.8, 0.28), blanket, bevel=0.1)
        ia.box((0, -L / 2 + 1.0, 1.95), (w - 0.04, 0.9, 0.3), fold, bevel=0.1)  # 이불과 옆면이 겹치지 않게 폭을 달리
        ia.box((0, L / 2 - 0.9, 1.9), (w - 0.9, 0.9, 0.45), pillow, bevel=0.2)


def chest(ia, x, y, z, yaw=0.0, w=2.4, d=1.2, h=1.3, key="wood_red"):
    with ia.at(loc=(x, y, z), rot=(0, 0, yaw)):
        ia.box((0, 0, h / 2), (w, d, h), key, bevel=0.06)
        ia.box((0, 0, h + 0.12), (w + 0.08, d + 0.08, 0.26), "wood_dark", bevel=0.06)
        for sx in (-1, 1):
            ia.box((sx * (w / 2 - 0.35), 0, h / 2 + 0.11), (0.14, d + 0.06, h + 0.32), "iron", bevel=0.0)  # 뚜껑 위로 0.02 (윗면이 겹쳐 반짝이지 않게)
        ia.box((0, -d / 2 - 0.04, h - 0.1), (0.36, 0.1, 0.42), "brass", bevel=0.0)


def wardrobe(ia, x, y, z, yaw=0.0, w=2.6, d=1.2, h=5.4, key="wood_c"):
    """옷장. yaw 0 = 문이 -Y 를 봄."""
    with ia.at(loc=(x, y, z), rot=(0, 0, yaw)):
        ia.box((0, 0, h / 2), (w, d, h), key, bevel=0.06)
        ia.box((0, 0, h + 0.15), (w + 0.3, d + 0.25, 0.3), "wood_dark", bevel=0.05)
        ia.box((0, -d / 2 - 0.03, h / 2), (0.08, 0.06, h - 0.6), "wood_dark", bevel=0.0)
        for sx in (-1, 1):
            ia.box((sx * 0.25, -d / 2 - 0.08, h * 0.55), (0.1, 0.12, 0.5), "brass", bevel=0.0)
            ia.box((sx * w / 4, -d / 2 - 0.03, h - 0.5), (w / 2 - 0.4, 0.06, 0.08), "wood_dark", bevel=0.0)
            ia.box((sx * w / 4, -d / 2 - 0.03, 0.5), (w / 2 - 0.4, 0.06, 0.08), "wood_dark", bevel=0.0)


def mug(ia, x, y, z, key="wood_b"):
    ia.cyl((x, y, z), (x, y, z + 0.5), 0.2, key, sides=8)
    ia.box((x + 0.24, y, z + 0.26), (0.1, 0.08, 0.28), key, bevel=0.0)


def plate(ia, x, y, z, food=None):
    ia.cyl((x, y, z), (x, y, z + 0.06), 0.42, "paint_white", sides=12)
    if food == "fish":
        S.fish(ia, (x, y, z + 0.14), L=0.8, yaw=30, pitch=0)
    elif food == "bread":
        ia.box((x, y, z + 0.2), (0.6, 0.35, 0.28), "straw", bevel=0.1)


def candle_cluster(ia, x, y, z, n=3, light=True):
    hs = (0.7, 0.45, 0.3, 0.55, 0.38)
    for k in range(n):
        a = k * 2.3
        S.candle(ia, (x + math.cos(a) * 0.28 * (k > 0), y + math.sin(a) * 0.28 * (k > 0), z), h=hs[k % 5], light=light and k == 0)


def book_row(ia, x, y, z, n, yaw=0.0):
    keys = ("cloth_red", "cloth_green", "leather", "cloth_purple", "wood_red", "paper")
    with ia.at(loc=(x, y, z), rot=(0, 0, yaw)):
        u = -n * 0.19
        for k in range(n):
            h = 0.7 + ((k * 37) % 5) * 0.08
            ia.box((u, 0, h / 2), (0.3, 0.6, h), keys[k % len(keys)], rot=(0, (k % 4 == 3) * 12, 0), bevel=0.02)
            u += 0.38


def jar(ia, x, y, z, key="glass_green", h=0.7, r=0.3, lid="wood_dark"):
    ia.cyl((x, y, z), (x, y, z + h), r, key, sides=8)
    ia.cyl((x, y, z + h), (x, y, z + h + 0.12), r * 0.8, lid, sides=8)


def herbs(ia, x, y, ztop, n=3, keys=("leaf", "leaf_dk", "straw", "flower_white")):
    """들보에 매단 약초 다발(끈 + 다발)."""
    for k in range(n):
        xx = x + (k - (n - 1) / 2) * 0.5
        L = 0.8 + (k % 2) * 0.35
        ia.box((xx, y, ztop - 0.4), (0.05, 0.05, 0.8), "rope", bevel=0.0)
        ia.box((xx, y, ztop - 0.8 - L / 2), (0.34, 0.3, L), keys[k % len(keys)], rot=(0, (k - 1) * 6, 0), bevel=0.08)


def hang_fish(ia, x, y, ztop, n=3):
    for k in range(n):
        xx = x + (k - (n - 1) / 2) * 0.55
        ia.box((xx, y, ztop - 0.35), (0.05, 0.05, 0.7), "rope", bevel=0.0)
        S.fish(ia, (xx, y, ztop - 1.2), L=1.0, yaw=90)


def beam(ia, p0, p1, r=0.38, key="wood_dark"):
    ia.cyl(p0, p1, r, key, sides=8)


def stove(ia, x, y, z, pipe_top, pipe_to=None, yaw=0.0):
    """쇠난로 + 연통. pipe_to = 연통이 꺾여 들어갈 벽 쪽 (dx, dy) 거리."""
    with ia.at(loc=(x, y, z), rot=(0, 0, yaw)):
        ia.box((0, 0, 1.4), (1.8, 1.6, 2.0), "iron", bevel=0.08)
        for sx in (-1, 1):
            for sy in (-1, 1):
                ia.box((sx * 0.7, sy * 0.6, 0.22), (0.2, 0.2, 0.44), "iron", bevel=0.0)  # 윗면을 몸통 속으로
        ia.box((0, -0.82, 1.2), (0.9, 0.08, 0.7), "glow_fire", bevel=0.0)
        ia.box((0, -0.86, 1.2), (1.1, 0.06, 0.9), "stone_dk", bevel=0.0)
        ia.cyl((0.35, 0.2, 2.4), (0.35, 0.2, 2.62), 0.4, "iron", sides=10)  # 주전자 받침
        ia.cyl((0.35, 0.2, 2.62), (0.35, 0.2, 3.3), 0.36, "brass", sides=10)
        ia.cyl((-0.3, 0.3, 2.4), (-0.3, 0.3, pipe_top), 0.24, "iron", sides=8)
        if pipe_to:
            ia.cyl((-0.3, 0.3, pipe_top), (-0.3 + pipe_to[0], 0.3 + pipe_to[1], pipe_top), 0.24, "iron", sides=8)
    ia.light((x, y - 1.2, z + 1.3), color=(255, 140, 60), range_=12, brightness=1.2)


def firewood(ia, x, y, z, n=7, along="y", L=2.2):
    k = 0
    row, rows = 0, 3
    while k < n and row < rows:
        m = 3 - row
        for i in range(m):
            if k >= n:
                break
            off = (i - (m - 1) / 2) * 0.62
            zz = z + 0.3 + row * 0.52
            if along == "y":
                ia.cyl((x + off, y - L / 2, zz), (x + off, y + L / 2, zz), 0.28, ("wood_dark", "bark", "wood_wet")[k % 3], sides=7)
            else:
                ia.cyl((x - L / 2, y + off, zz), (x + L / 2, y + off, zz), 0.28, ("wood_dark", "bark", "wood_wet")[k % 3], sides=7)
            k += 1
        row += 1


def picture(ia, x, y, zc, w, h, yaw=0.0, paint=("paint_red", "leaf", "sand")):
    """벽 액자(yaw 0 = 그림이 -Y 를 봄, 벽은 +Y)."""
    with ia.at(loc=(x, y, zc), rot=(0, 0, yaw)):
        ia.box((0, 0, 0), (w, 0.12, h), "wood_dark", bevel=0.03)
        ia.box((0, -0.06, 0), (w - 0.4, 0.06, h - 0.4), paint[2], bevel=0.0)
        ia.box((0, -0.08, -h * 0.15), (w - 0.6, 0.06, h * 0.25), paint[1], bevel=0.0)
        ia.box((w * 0.18, -0.09, h * 0.18), (w * 0.25, 0.06, w * 0.25), paint[0], bevel=0.0)


def rod(ia, base, tip):
    ia.box_between(base, tip, 0.08, "wood_pale", width=0.08)
    ia.box_between(Vector(base) + Vector((0, 0, 0.3)), Vector(base) + Vector((0, 0, 0.9)), 0.14, "leather", width=0.14)


def oar(ia, p0, p1):
    p0, p1 = Vector(p0), Vector(p1)
    ia.box_between(p0, p1, 0.16, "wood_b", width=0.16)
    d = (p1 - p0).normalized()
    ia.box_between(p1 - d * 1.2, p1 + d * 0.2, 0.08, "wood_b", width=0.55)


def net_wall(ia, x, y, zc, w, h, yaw=0.0):
    with ia.at(loc=(x, y, zc), rot=(0, 0, yaw)):
        ia.box((0, 0, 0), (w, 0.05, h), "net", bevel=0.0)
        for k in range(3):
            ia.sphere(((k - 1) * w * 0.3, -0.33, -h * 0.3 + k * 0.4), 0.28, ("paint_red", "paint_white", "wood_pale")[k], seg=8, rings=5)


def dresser_with_plates(ia, x, y, z, yaw=0.0):
    """그릇 찬장(아래 서랍장 + 위 선반 둘에 접시·잔). yaw 0 = 앞이 -Y."""
    with ia.at(loc=(x, y, z), rot=(0, 0, yaw)):
        ia.box((0, 0, 1.3), (3.2, 1.3, 2.6), "wood_c", bevel=0.06)
        for k in range(2):
            ia.box((0, -0.68, 0.7 + k * 1.1), (2.8, 0.08, 0.8), "wood_b", bevel=0.02)
            ia.box((0, -0.74, 0.7 + k * 1.1), (0.5, 0.08, 0.12), "brass", bevel=0.0)
        ia.box((0, 0.35, 4.0), (3.2, 0.5, 2.8), "wood_dark", bevel=0.04)  # 뒤판
        for k in range(2):
            zz = 3.2 + k * 1.2
            ia.box((0, 0.15, zz), (3.1, 0.8, 0.14), "wood_c", bevel=0.02)
            for i in range(4):
                ia.cyl((-1.1 + i * 0.73, 0.36, zz + 0.5), (-1.1 + i * 0.73, 0.28, zz + 0.5), 0.4, "paint_white", sides=12)
        ia.box((0, 0.1, 5.5), (3.4, 1.0, 0.2), "wood_dark", bevel=0.04)


# ─────────────────────────────────────────────────────────────
# 주점(Longhouse): 방 x -16..16, y -3..15, 바닥 7, 벽 위 19
#   문: 앞(x -3.5..3.5), 서벽(y 3.5..7.5) / 창: 앞 x -12..-8·8..12, 뒤 x 6..10·-10..-6, 동벽 y 4..8 (높이 11..15)
#   기존: 바 카운터(x -1..13, y 10.2..11.8), 뒤 술통·선반, 화덕(x -12..-6, y 12.2..14.6), 탁자 x -8·0 (y 0..6)
# ─────────────────────────────────────────────────────────────
def longhouse(ia):
    Z = 7.0
    # 천장 들보(짧은 쪽으로 가로질러) — 등불 자리(x -10, 8)는 비킨다
    for x in (-13, -5, 3, 11):
        beam(ia, (x, -2.7, 17.6), (x, 14.7, 17.6))
    beam(ia, (-15.6, 6.0, 18.2), (15.6, 6.0, 18.2), r=0.42)
    # 들보에 매단 것: 약초·말린 생선·마늘
    herbs(ia, -13, 2.0, 17.25, 3)
    herbs(ia, -13, 9.0, 17.25, 2, keys=("paint_white", "straw"))
    hang_fish(ia, 11, 1.5, 17.25, 3)
    herbs(ia, 3, -0.5, 17.25, 2)
    herbs(ia, -5, 12.8, 17.25, 3, keys=("straw", "leaf_dk", "flower_white"))
    # 들보(z 17.6, 반지름 0.38) 밑면 17.22 에 사슬 끝이 닿게: 몸 = 17.22 − 1.1 − 매단 길이
    S.lantern(ia, (-5, 9.0, 17.22 - 1.1 - 0.9), hang=0.9, rng_range=22, brightness=1.2)
    S.lantern(ia, (3, 3.5, 17.22 - 1.1 - 0.9), hang=0.9, rng_range=22, brightness=1.2)

    # 기존 두 탁자 밑 큰 깔개 + 탁자 위 차림
    rug(ia, -4, 3.0, Z, 13.5, 7.4, "cloth_red", "cloth_green", stripes=2)
    # 기존 탁자엔 잔 3·접시 3 이 이미 있다(메시 전용): 탁자 중심 기준 잔 (-0.4,-1.55)(0.4,0)(-0.4,1.55), 접시 (0.3,-0.95)(0.3,0.6)(0.3,2.15)
    # → 비어 있는 서쪽 가장자리에만 더한다
    tz = Z + 2.75
    plate(ia, -8.8, 2.3, tz, "fish")
    S.candle(ia, (-8.75, 3.5, tz), h=0.5, light=True)
    plate(ia, -0.8, 2.3, tz, "bread")
    S.bottle(ia, (-0.8, 3.6, tz), key="glass_green")

    # 바: 높은 의자 다섯 + 카운터 위 잔·꼭지 달린 작은 통·초
    for x in (0.4, 3.2, 6.0, 8.8, 11.6):
        stool(ia, x, 8.9, Z, h=2.5, r=0.65)
    cz = Z + 3.9
    for x in (1.2, 4.6, 9.8):
        mug(ia, x, 10.7, cz)
    S.barrel(ia, (12.0, 11.0, cz), h=1.6, r=0.7, lying=True, yaw=90)
    ia.box((12.0, 10.1, cz + 0.75), (0.2, 0.5, 0.2), "brass", bevel=0.0)
    S.candle(ia, (7.2, 10.9, cz), h=0.45, light=True)
    plate(ia, 3.0, 10.9, cz)
    # 바 끝 창고 구석: 상자·통·자루
    S.crate(ia, (14.4, 13.4, Z), s=2.2, yaw=6)
    S.crate(ia, (14.3, 13.2, Z + 2.2), s=1.7, yaw=-10)
    S.barrel(ia, (14.6, 10.4, Z), h=2.6, r=0.95)
    S.sack(ia, (14.8, 8.5, Z), key="straw")

    # 동쪽 빈 곳: 네모 탁자 둘 + 의자
    tz = table(ia, 6.5, 2.0, Z, 3.6, 3.6)
    for (dx, dy, yaw) in ((0, -2.4, 0), (0, 2.4, 180), (-2.4, 0, -90), (2.4, 0, 90)):
        chair(ia, 6.5 + dx, 2.0 + dy, Z, yaw=yaw)
    mug(ia, 6.0, 1.5, tz)
    mug(ia, 7.2, 2.6, tz)
    plate(ia, 6.6, 1.9, tz, "fish")
    S.candle(ia, (7.3, 1.3, tz), h=0.5, light=True)
    tz = table(ia, 11.8, 5.2, Z, 3.2, 3.2)
    for (dx, dy, yaw) in ((0, -2.2, 0), (-2.2, 0, -90), (0, 2.2, 180)):
        chair(ia, 11.8 + dx, 5.2 + dy, Z, yaw=yaw)
    for k in range(3):  # 카드 몇 장
        ia.box((11.4 + k * 0.35, 5.0 + k * 0.1, tz + 0.03 + k * 0.012), (0.5, 0.7, 0.04), "paper", rot=(0, 0, k * 17), bevel=0.0)
    mug(ia, 12.4, 5.8, tz)

    # 동남 구석 음유시인 무대(앞 창 x 8..12 은 비킨다)
    ia.box((14.0, -0.9, Z + 0.25), (3.2, 3.8, 0.5), "wood_dark", bevel=0.06)
    stool(ia, 14.0, -0.6, Z + 0.5, h=1.7)
    # 류트(몸통 + 목) — 무대 벽에 기대어
    ia.sphere((15.2, -2.2, Z + 1.8), 0.7, "wood_c", seg=10, rings=6, scale=(0.5, 1.0, 1.25))
    ia.box_between((15.3, -2.2, Z + 2.6), (15.45, -2.2, Z + 4.4), 0.22, "wood_dark", width=0.22)
    S.barrel(ia, (13.0, -2.0, Z + 0.5), h=1.5, r=0.75, key="wood_a")  # 북
    ia.cyl((13.0, -2.0, Z + 2.0), (13.0, -2.0, Z + 2.08), 0.72, "paper", sides=12)

    # 서쪽: 화덕 앞 깔개·흔들의자 둘·곁탁자, 장작더미, 화덕 위 초·병, 걸린 솥
    rug(ia, -9.0, 9.9, Z, 6.6, 3.4, "cloth_green", "cloth_red")
    chair(ia, -11.2, 9.4, Z, yaw=200, cushion="cloth_red")
    chair(ia, -6.8, 9.4, Z, yaw=160, cushion="cloth_green")
    stool(ia, -9.0, 8.8, Z, h=1.4, key="wood_c")
    mug(ia, -9.0, 8.8, Z + 1.4)
    firewood(ia, -14.3, 13.4, Z, n=6, along="x", L=2.0)
    candle_cluster(ia, -11.2, 13.4, Z + 5.0, n=3, light=False)
    S.bottle(ia, (-7.0, 13.4, Z + 5.0), key="glow_potion")
    ia.box((-9.0, 12.7, Z + 3.3), (0.08, 0.08, 1.2), "iron", bevel=0.0)
    ia.cyl((-9.0, 12.7, Z + 2.2), (-9.0, 12.7, Z + 2.7), 0.55, "iron", sides=10)

    # 그릇 찬장(바와 화덕 사이 뒷벽)
    dresser_with_plates(ia, -3.3, 14.0, Z, yaw=0)

    # 서벽 장식: 박제 물고기 판 둘, 엇건 노, 옷걸이
    for (y, zc) in ((-0.5, 14.4), (5.5, 17.0)):
        ia.box((-15.55, y, zc), (0.12, 2.4, 1.2), "wood_dark", bevel=0.04)
        S.fish(ia, (-15.35, y, zc), L=1.8, yaw=0, pitch=0)
    oar(ia, (-15.5, 13.8, 10.0), (-15.5, 9.0, 16.0))
    oar(ia, (-15.5, 9.0, 10.0), (-15.5, 13.8, 16.0))
    ia.box((-15.6, 1.8, 12.4), (0.12, 2.6, 0.3), "wood_dark", bevel=0.03)
    for y in (0.9, 1.8, 2.7):
        ia.box((-15.3, y, 12.4), (0.5, 0.12, 0.12), "wood_c", bevel=0.0)
    ia.box((-15.25, 0.9, 11.0), (0.3, 1.1, 2.6), "cloth_green", bevel=0.1)  # 걸린 망토
    ia.box((-15.2, 2.7, 12.0), (0.5, 0.9, 0.5), "leather", bevel=0.1)  # 걸린 모자

    # 앞벽 안쪽: 차림판(칠판)·현상 수배지, 앞 서쪽 구석 통·자루
    ia.box((-5.6, -2.55, 12.2), (3.0, 0.14, 2.2), "wood_dark", bevel=0.04)
    ia.box((-5.6, -2.64, 12.2), (2.6, 0.06, 1.8), "stone_dk", bevel=0.0)
    for k in range(3):
        ia.box((-5.8 + (k % 2) * 0.3, -2.7, 12.8 - k * 0.5), (1.6 - k * 0.3, 0.04, 0.12), "paint_white", bevel=0.0)
    ia.box((5.8, -2.6, 12.4), (1.6, 0.06, 2.0), "paper", rot=(0, 3, 0), bevel=0.0)
    ia.box((5.8, -2.66, 12.6), (0.8, 0.04, 0.7), "paint_red", bevel=0.0)
    S.barrel(ia, (-14.2, -1.4, Z), h=2.8, r=1.0)
    S.barrel(ia, (-12.0, -1.7, Z), h=2.4, r=0.85, key="wood_c")
    S.sack(ia, (-14.6, 0.9, Z), key="cloth_green")


# ─────────────────────────────────────────────────────────────
# 수상가옥 A: 방 x -8.5..8.5, y -4.5..9, 바닥 7, 벽 위 18
#   문 x -5.3..-0.3(앞, 문짝이 안쪽 x≈-5.3 에 열림) / 창: 앞 x 2.5..6, 뒤 x -1.5..2, 동벽 y 0..3.5
#   기존: 탁자(0, 3.25) 걸상 x ±3.1, 침대 x 3.7..7.3 y 2.2..8.2, 서벽 선반 y 3.9..7.9(높이 12), 통(-6.3,-1.9), 가운데 등불
# ─────────────────────────────────────────────────────────────
def _house_common(ia, Z, zt, table_c, bed_foot, x0, x1, y0, y1, flavor):
    """수상가옥 공통: 탁자 밑 깔개·차림, 침대 발치 궤짝, 들보·약초."""
    tx, ty = table_c
    rug(ia, tx, ty, Z, 6.6, 4.4, *flavor["rug"], stripes=1)
    tz = Z + 2.75
    plate(ia, tx - 0.9, ty - 0.5, tz, "fish")
    plate(ia, tx + 0.4, ty + 0.6, tz, "bread")
    mug(ia, tx - 1.6, ty + 0.6, tz, key="wood_c")
    bx, by = bed_foot
    chest(ia, bx, by, Z, key=flavor["chest"])
    for x in (x0 + 4.0, x1 - 4.0):
        beam(ia, (x, y0 + 0.2, zt - 1.6), (x, y1 - 0.2, zt - 1.6), r=0.32)


def stilt_house_a(ia):
    Z, zt = 7.0, 18.0
    _house_common(ia, Z, zt, (0, 3.25), (5.5, 1.3), -8.5, 8.5, -4.5, 9.0, {"rug": ("cloth_green", "wood_red"), "chest": "wood_red"})
    # 부엌: 서벽 앞 쇠난로 + 연통(벽으로 꺾임) + 장작 바구니·물통
    stove(ia, -7.3, 1.3, Z, pipe_top=15.6, pipe_to=(-1.2, 0))
    firewood(ia, -7.5, -0.25, Z, n=4, along="x", L=1.5)
    ia.cyl((-4.8, 0.8, Z), (-4.8, 0.8, Z + 1.1), 0.5, "wood_b", sides=10)  # 물통
    ia.cyl((-4.8, 0.8, Z + 1.05), (-4.8, 0.8, Z + 1.12), 0.46, "glass", sides=10)
    # 뒷벽: 옷장, 그 옆 자루·항아리
    wardrobe(ia, -3.8, 8.25, Z, yaw=0)
    S.sack(ia, (-6.9, 8.0, Z), key="straw")
    jar(ia, -5.6, 7.0, Z, key="wood_c", h=1.0, r=0.45)
    # 앞 오른쪽 구석: 찬장
    ia.box((7.2, -3.6, Z + 1.9), (2.2, 1.4, 3.8), "wood_c", bevel=0.06)
    ia.box((7.2, -4.34, Z + 2.6), (1.8, 0.08, 1.6), "wood_b", bevel=0.02)
    for k in range(3):
        jar(ia, 6.5 + k * 0.7, -3.6, Z + 3.8, key=("glass_green", "wood_b", "glass")[k], h=0.6, r=0.25)
    # 동벽 창 아래 작업대 + 낚시 도구
    # (침대가 y 2.2 부터라 작업대는 y -0.4..1.9 까지만)
    ia.box((7.6, 0.75, Z + 2.2), (1.4, 2.3, 0.2), "wood_c", bevel=0.04)
    for y in (-0.2, 1.7):
        ia.box((7.6, y, Z + 1.05), (1.2, 0.2, 2.1), "wood_dark", bevel=0.02)
    ia.box((7.6, 0.3, Z + 2.5), (0.8, 0.8, 0.4), "wood_red", bevel=0.04)  # 낚시 상자
    S.rope_coil(ia, (7.6, 1.35, Z + 2.3), r=0.45)
    # 벽 장식: 침대 위 액자, 문 옆 옷걸이, 들보 약초
    picture(ia, 8.3, 6.0, 12.4, 2.4, 1.8, yaw=-90, paint=("flower_pink", "leaf", "sand"))
    ia.box((-7.6, -4.3, 12.2), (1.8, 0.12, 0.26), "wood_dark", bevel=0.02)
    ia.box((-7.9, -4.05, 11.1), (0.9, 0.3, 2.2), "cloth_red", bevel=0.1)
    herbs(ia, -4.5, 6.0, 16.1, 3)
    hang_fish(ia, 4.5, -1.5, 16.1, 2)
    # 낚싯대 둘(앞 오른쪽, 창 옆 벽에 기댐)
    rod(ia, (1.4, -4.2, Z), (1.8, -4.3, 15.0))
    rod(ia, (0.8, -4.2, Z), (0.4, -4.3, 14.6))


# ─────────────────────────────────────────────────────────────
# 수상가옥 B2 1층: 방 x -7.5..7.5, y 4..17.5, 바닥 7, 벽 위 17
#   문 x -2.5..2.5(앞 y 4, 문짝이 서쪽 x≈-5.3 로 열림) / 창: 동벽 y 9..12.4, 서벽 y 9.1..12.5
#   기존: 탁자(0, 11.75) 걸상 x ±3.1, 침대 x 2.7..6.3 y 10.7..16.7, 서벽 선반 y 12.4..16.4(높이 12), 통(-5.3, 6.6)
# 2층: 방 x -9.1..9.1, y 2.4..17.7, 바닥 18.2, 벽 위 26.7
#   창: 앞 x -6.1..-2.7·2.7..6.1, 뒤 x -1.3..2.1 (높이 21..24.6) / 동벽 발코니 문 y 8.4..14.4 / 등불(0, 10, 25.7)
# ─────────────────────────────────────────────────────────────
def stilt_house_b2(ia):
    Z, zt = 7.0, 17.0
    _house_common(ia, Z, zt, (0, 11.75), (4.5, 9.7), -7.5, 7.5, 4.0, 17.5, {"rug": ("cloth_red", "cloth_green"), "chest": "wood_teal"})
    # 뒷벽 서쪽: 옷장(선반 x≤-5.65 를 비킴)
    wardrobe(ia, -4.0, 16.8, Z, yaw=0, key="wood_b")
    # 앞 동쪽: 부엌 조리대(동벽을 따라) + 대야·도마·걸린 냄비
    ia.box((6.7, 6.4, Z + 1.7), (1.4, 4.2, 0.24), "wood_c", bevel=0.04)
    ia.box((6.7, 6.4, Z + 0.8), (1.3, 4.0, 1.6), "wood_dark", bevel=0.05)
    ia.cyl((6.7, 5.2, Z + 1.82), (6.7, 5.2, Z + 2.3), 0.55, "iron", sides=12)
    ia.box((6.6, 7.2, Z + 1.88), (0.9, 1.4, 0.12), "wood_pale", bevel=0.02)
    S.fish(ia, (6.6, 7.2, Z + 2.02), L=1.1, yaw=90, pitch=0)
    ia.box((7.3, 6.4, 12.2), (0.12, 3.4, 0.2), "wood_dark", bevel=0.02)
    for k in range(3):
        ia.cyl((7.0, 5.2 + k * 1.2, 11.0), (7.0, 5.2 + k * 1.2, 11.6), 0.42 - k * 0.06, ("iron", "brass", "iron")[k], sides=10)
    # 난로: 뒤 서쪽 구석, 벽 선반 아래(열린 문짝이 앞 서쪽을 차지한다) + 연통은 선반 옆으로 올라 서벽으로
    stove(ia, -6.5, 14.2, Z, pipe_top=15.4, pipe_to=(0, 1.2), yaw=90)
    # 앞벽 문 동쪽: 낚싯대·그물
    rod(ia, (3.4, 4.3, Z), (3.6, 4.2, 15.2))
    net_wall(ia, 5.2, 4.25, 12.4, 2.8, 2.6, yaw=180)  # 부표가 방 쪽(+y)에 오게(yaw 0 이면 벽 밖으로 튀어나왔다)
    picture(ia, -7.3, 7.0, 12.8, 1.8, 1.4, yaw=90, paint=("paint_red", "leaf_dk", "paper"))
    herbs(ia, -3.5, 14.0, 15.1, 3)

    # ── 2층: 다락 침실 ──
    Z2 = 18.2
    rug(ia, 0, 10.2, Z2, 7.0, 5.2, "cloth_purple", "wood_red", stripes=2)
    bed(ia, -7.0, 12.0, Z2, yaw=0, w=3.4, L=6.0, blanket="cloth_red", fold="cloth_green")
    bed(ia, -7.2, 5.4, Z2, yaw=0, w=2.8, L=4.4, blanket="cloth_green", fold="paint_white")
    chest(ia, -7.2, 16.4, Z2, key="wood_red")
    # 뒷창 밑 책상 + 의자·책·촛불
    tz = table(ia, 0.4, 16.7, Z2, 3.6, 1.4)
    chair(ia, 0.4, 15.2, Z2, yaw=0)
    book_row(ia, -0.6, 16.9, tz, 5)
    S.candle(ia, (1.5, 16.6, tz), h=0.5, light=True)
    ia.box((0.8, 16.5, tz + 0.02), (1.0, 0.7, 0.04), "paper", rot=(0, 0, 8), bevel=0.0)
    wardrobe(ia, 6.5, 17.0, Z2, yaw=0, key="wood_c")
    # 앞창 사이 작은 탁자 + 화분
    table(ia, 0, 3.4, Z2, 2.0, 1.2, h=2.2)
    ia.cyl((0, 3.4, Z2 + 2.2), (0, 3.4, Z2 + 2.9), 0.4, "wood_red", sides=10)
    for k in range(4):
        ia.sphere((math.cos(k * 1.6) * 0.3, 3.4 + math.sin(k * 1.6) * 0.3, Z2 + 3.2 + k * 0.09), 0.34, "leaf", seg=6, rings=4)
    # 장난감 배, 바구니, 빨랫줄
    ia.box((3.0, 7.2, Z2 + 0.3), (1.4, 0.5, 0.4), "wood_teal", bevel=0.1)
    ia.box((3.0, 7.2, Z2 + 0.9), (0.06, 0.06, 0.9), "wood_pale", bevel=0.0)
    ia.box((3.2, 7.2, Z2 + 1.0), (0.4, 0.04, 0.5), "sail", bevel=0.0)
    ia.cyl((7.4, 4.0, Z2), (7.4, 4.0, Z2 + 1.0), 0.6, "straw", sides=10)
    beam(ia, (-8.9, 6.5, 25.4), (8.9, 6.5, 25.4), r=0.3)
    herbs(ia, -4.0, 6.5, 25.1, 2, keys=("paint_white", "cloth_red"))


# ─────────────────────────────────────────────────────────────
# 어부 오두막 C: 방 x -6..6, y -4.5..6, 바닥 6, 벽 위 15, 초가지붕 / 문 없는 출입구 x -4.8..-0.6(앞)
#   창: 앞 x 2..4.6, 뒤 x -1.5..1.5 (높이 9.4..12.2) / 기존 실내 없음
# ─────────────────────────────────────────────────────────────
def stilt_hut_c(ia):
    Z = 6.0
    # 동벽을 따라 간이침대
    with ia.at(loc=(4.3, 2.4, Z)):
        ia.box((0, 0, 0.9), (2.6, 5.8, 0.3), "wood_b", bevel=0.05)
        for sx in (-1, 1):
            for sy in (-1, 1):
                ia.box((sx * 1.1, sy * 2.7, 0.45), (0.25, 0.25, 0.9), "wood_dark", bevel=0.03)
        ia.box((0, 0.2, 1.25), (2.4, 5.2, 0.4), "straw", bevel=0.14)
        ia.box((0, -0.55, 1.5), (2.5, 3.5, 0.2), "cloth_green", bevel=0.08)
        ia.box((0, 2.3, 1.55), (1.8, 0.8, 0.35), "paint_white", bevel=0.15)
    # 뒤 서쪽 구석 쇠난로 + 연통(초가 지붕 위로)
    stove(ia, -4.7, 4.6, Z, pipe_top=17.0, yaw=0)
    firewood(ia, -2.6, 5.0, Z, n=3, along="x", L=1.4)
    # 작은 탁자 + 걸상 + 도마 위 생선·칼 + 등불
    rug(ia, -1.6, 1.2, Z, 4.0, 3.2, "straw", "wood_c")
    tz = table(ia, -1.6, 1.2, Z, 2.6, 1.8, h=2.5)
    stool(ia, -1.6, -0.6, Z, h=1.5)
    ia.box((-2.0, 1.2, tz + 0.05), (1.2, 0.8, 0.1), "wood_pale", bevel=0.02)
    S.fish(ia, (-2.0, 1.2, tz + 0.2), L=1.0, yaw=90, pitch=0)
    ia.box((-1.1, 1.0, tz + 0.08), (0.08, 0.7, 0.06), "steel", bevel=0.0)
    # 밑판이 −0.62 까지 내려오므로 탁자 위에 얹으려면 +0.62
    S.lantern(ia, (-0.8, 1.6, tz + 0.62), light=True, rng_range=16, brightness=1.1)
    # 앞 동쪽 구석: 낚싯대 셋·통발
    for k in range(3):
        rod(ia, (5.3 - k * 0.35, -3.9, Z), (5.6 - k * 0.5, -4.2, Z + 8.2 - k * 0.4))
    with ia.at(loc=(3.6, -3.2, Z)):
        ia.box((0, 0, 0.7), (1.6, 1.2, 1.4), "net", bevel=0.0)
        for sx in (-1, 1):
            ia.box((sx * 0.8, 0, 0.7), (0.1, 1.26, 1.46), "wood_dark", bevel=0.0)
    # 출입구 옆: 소금 절인 생선 통·밧줄 뭉치
    S.barrel(ia, (-5.1, -1.9, Z), h=2.4, r=0.85)
    S.rope_coil(ia, (-5.0, 0.3, Z), r=0.7)
    # 서벽 그물·뒷벽 노·들보·말린 생선
    net_wall(ia, -5.85, 2.0, Z + 5.2, 3.6, 3.0, yaw=90)
    oar(ia, (2.6, 5.75, Z + 3.0), (5.2, 5.75, Z + 7.6))
    beam(ia, (-5.8, 0.8, Z + 7.4), (5.8, 0.8, Z + 7.4), r=0.3)
    hang_fish(ia, -2.5, 0.8, Z + 7.1, 4)
    herbs(ia, 2.8, 0.8, Z + 7.1, 2, keys=("straw", "leaf_dk"))
    # 들보(Z+7.4, 반지름 0.3) 밑면에 사슬 끝
    S.lantern(ia, (1.0, 0.8, Z + 7.1 - 1.1 - 0.5), hang=0.5, rng_range=16, brightness=1.0)


# ─────────────────────────────────────────────────────────────
# 마녀 오두막: 몸체가 기운 틀 안 방 x -6.5..6.5, y -5..7, 바닥 6.5, 벽 위 16.5 / 문 x -2.5..1.9(앞)
#   창: 동벽 y -1..2.5(둥근 창), 서벽 y -1..2 / 기존: 서벽 선반(y -1..5, 높이 10)·병, 탁자(x -1.5..3.5, y 3..6)·해골·초, 가운데 등불
# ─────────────────────────────────────────────────────────────
def witch_hut(ia):
    Z = 6.5
    with ia.at(matrix=_witch_flat()):
        # 바닥 룬 원진 + 촛불 다섯(가운데)
        round_rug(ia, 0.2, 0.2, Z, 2.6, "cloth_purple", "cloth_red")
        ia.cyl((0.2, 0.2, Z + 0.1), (0.2, 0.2, Z + 0.16), 1.6, "stone_rune", sides=16)
        for k in range(5):
            a = math.radians(90 + k * 72)
            S.candle(ia, (0.2 + math.cos(a) * 2.0, 0.2 + math.sin(a) * 2.0, Z + 0.12), h=0.4 + (k % 2) * 0.25, light=(k == 0))
        ia.light((0.2, 0.2, Z + 1.0), color=(180, 110, 255), range_=10, brightness=0.7)
        # 동쪽 뒤: 짚 침대 + 누더기 이불
        with ia.at(loc=(4.9, 3.6, Z)):
            ia.box((0, 0, 0.4), (2.6, 5.0, 0.8), "straw", bevel=0.2)
            ia.box((0, -0.4, 0.9), (2.5, 3.4, 0.2), "cloth_purple", bevel=0.1)
            ia.box((0.3, 0.8, 1.02), (1.0, 1.0, 0.06), "cloth_green", rot=(0, 0, 12), bevel=0.0)
            ia.box((-0.4, -1.2, 1.02), (0.9, 0.8, 0.06), "cloth_red", rot=(0, 0, -8), bevel=0.0)
        # 서쪽 뒤: 책장(책·해골·병)
        with ia.at(loc=(-3.6, 6.3, Z)):
            ia.box((0, 0, 3.0), (3.2, 1.0, 6.0), "wood_dark", bevel=0.05)
            for k in range(3):
                zz = 1.2 + k * 1.6
                ia.box((0, -0.35, zz), (2.9, 0.5, 0.12), "wood_moss", bevel=0.0)
        book_row(ia, -4.4, 6.0, Z + 1.26, 6)
        book_row(ia, -3.2, 6.0, Z + 2.86, 4)
        jar(ia, -2.5, 6.0, Z + 2.86, key="glow_mushroom", h=0.8)
        ia.sphere((-4.2, 6.0, Z + 4.8), 0.45, "bone", seg=8, rings=6)
        jar(ia, -3.2, 6.0, Z + 4.46, key="glow_potion", h=0.9, r=0.35)
        # 수정구(받침대)
        ia.cyl((-4.4, 3.4, Z), (-4.4, 3.4, Z + 2.4), 0.25, "wood_dark", sides=8)
        ia.cyl((-4.4, 3.4, Z + 2.4), (-4.4, 3.4, Z + 2.6), 0.5, "brass", sides=10)
        ia.sphere((-4.4, 3.4, Z + 3.1), 0.55, "glow_potion", seg=12, rings=8)
        ia.light((-4.4, 3.4, Z + 3.2), color=(150, 120, 255), range_=8, brightness=0.5)
        # 문 옆 빗자루·버섯 무리·뼈 무더기
        ia.box_between((2.6, -4.5, Z), (2.9, -4.7, Z + 5.2), 0.14, "wood_dark", width=0.14)
        ia.box((2.6, -4.5, Z + 0.6), (0.9, 0.5, 1.2), "straw", rot=(0, 3, 0), bevel=0.1)
        for k in range(5):
            ia.cyl((-5.4 + k * 0.35, -3.9 + (k % 2) * 0.4, Z), (-5.4 + k * 0.35, -3.9 + (k % 2) * 0.4, Z + 0.4 + k * 0.1), 0.08, "mushroom_stem", sides=6)
            ia.sphere((-5.4 + k * 0.35, -3.9 + (k % 2) * 0.4, Z + 0.45 + k * 0.1), 0.2, "glow_mushroom", seg=8, rings=4, scale=(1, 1, 0.5))
        for k in range(4):
            ia.box_between((4.2 + k * 0.2, -3.0, Z + 0.1), (5.2 - k * 0.1, -2.4 + k * 0.2, Z + 0.15), 0.12, "bone", width=0.12)
        ia.sphere((4.8, -3.6, Z + 0.35), 0.35, "bone", seg=8, rings=6)
        candle_cluster(ia, 5.4, -4.2, Z, n=4, light=False)
    # 벽·천장에 붙는 것은 기운 틀에
    with ia.at(matrix=_witch_tilt()):
        beam(ia, (-6.2, 1.0, 15.0), (6.2, 1.0, 15.0), r=0.3, key="bark")
        herbs(ia, -3.5, 1.0, 14.7, 3, keys=("leaf_dk", "moss", "flower_white"))
        herbs(ia, 3.5, 1.0, 14.7, 2, keys=("mushroom_cap", "straw"))
        hang_fish(ia, 0.8, 1.0, 14.7, 2)
        ia.box((6.2, -3.4, 11.8), (0.1, 1.2, 1.6), "paper", rot=(4, 0, 0), bevel=0.0)  # 동벽 부적 종이
        ia.box((6.15, -3.4, 12.3), (0.06, 0.5, 0.5), "paint_red", bevel=0.0)


DESIGN = {
    "Longhouse": longhouse,
    "StiltHouseA": stilt_house_a,
    "StiltHouseB2": stilt_house_b2,
    "StiltHutC": stilt_hut_c,
    "WitchHut": witch_hut,
}
