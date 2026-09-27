"""수상 가옥 (Stilt House) — 늪 마을의 기본 주거 건물.

변형
  StiltHouseA : 단층, 앞 베란다, 맞배지붕, 돌 굴뚝
  StiltHouseB : 2층 (위층 돌출), 측면 계단, 외쪽 차양
  StiltHouseC : 소형 오두막, 초가 지붕, 그물/건조대
"""

import math

from mathutils import Vector

from swamplib.asset import Asset
from swamplib import shapes as S


def _stilt_grid(a, x0, x1, y0, y1, z_top, nx, ny, braces=True):
    posts = []
    for i in range(nx):
        for j in range(ny):
            x = x0 + (x1 - x0) * i / (nx - 1)
            y = y0 + (y1 - y0) * j / (ny - 1)
            bot, top = S.stilt(a, x, y, z_top - 0.7, z_bottom=-8.0, r=0.62)
            posts.append(((i, j), bot, top))
            a.collider((x, y, (z_top - 8) / 2 - 0.5), (1.1, 1.1, z_top + 7), tag="Stilt")
    if braces:
        byidx = {k: (b, t) for k, b, t in posts}
        for i in range(nx - 1):
            for j in (0, ny - 1):
                (b0, t0), (b1, t1) = byidx[(i, j)], byidx[(i + 1, j)]
                lo = 0.6
                S.cross_brace(a, t0 - Vector((0, 0, 1.4)), Vector((b0.x, b0.y, lo)), t1 - Vector((0, 0, 1.4)), Vector((b1.x, b1.y, lo)))
        for j in range(ny - 1):
            for i in (0, nx - 1):
                (b0, t0), (b1, t1) = byidx[(i, j)], byidx[(i, j + 1)]
                S.cross_brace(a, t0 - Vector((0, 0, 1.4)), Vector((b0.x, b0.y, 0.6)), t1 - Vector((0, 0, 1.4)), Vector((b1.x, b1.y, 0.6)))
    # 기둥 위 거더 (둘레 보)
    for j in (0, ny - 1):
        y = y0 + (y1 - y0) * j / (ny - 1)
        a.box(((x0 + x1) / 2, y, z_top - 1.25), (x1 - x0 + 1.4, 0.9, 1.0), "wood_dark", bevel=0.1)
    for i in (0, nx - 1):
        x = x0 + (x1 - x0) * i / (nx - 1)
        a.box((x, (y0 + y1) / 2, z_top - 1.25), (0.9, y1 - y0 + 1.4, 1.0), "wood_dark", bevel=0.1)


def _stone_chimney(a, x, y, z0, z1, w=2.4):
    z = z0
    row = 0
    while z < z1:
        h = a.rng.uniform(0.7, 1.0)
        n = 2
        for k in range(n):
            for side in range(4):
                ang = side * 90
                rad = math.radians(ang)
                off = Vector((math.cos(rad), math.sin(rad), 0)) * (w / 2 - 0.3)
                t = Vector((-math.sin(rad), math.cos(rad), 0))
                shift = (k - 0.5) * w / 2 + (0.3 if row % 2 else -0.3)
                c = Vector((x, y, z + h / 2)) + off + t * shift
                a.box(c, (w / 2 + 0.1, 0.7, h - 0.06), "stone" if a.rng.random() > 0.25 else "stone_moss",
                      rot=(0, 0, ang + a.rng.uniform(-3, 3)), bevel=0.0, part=False)
        a._prim_box_only((x, y, z + h / 2), (w, w, h), "stone")
        z += h
        row += 1
    a.box((x, y, z1 + 0.2), (w + 0.5, w + 0.5, 0.4), "stone_dk", bevel=0.1)
    a.collider((x, y, (z0 + z1) / 2), (w, w, z1 - z0), tag="Wall")
    a.marker("Smoke", (x, y, z1 + 0.6))


def _interior(a, x0, x1, y0, y1, z):
    """간단한 실내 (문으로 들여다보이는 가구)."""
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    # 테이블
    a.box((cx, cy + 1.0, z + 2.6), (4.2, 2.6, 0.3), "wood_c", bevel=0.06)
    for sx in (-1, 1):
        for sy in (-1, 1):
            a.box((cx + sx * 1.8, cy + 1.0 + sy * 1.0, z + 1.25), (0.3, 0.3, 2.5), "wood_dark", bevel=0.04)
    S.candle(a, (cx + 0.8, cy + 1.2, z + 2.75), light=True)
    S.bottle(a, (cx - 1.0, cy + 0.6, z + 2.75), key="glass_green")
    # 의자
    for sx in (-1, 1):
        a.box((cx + sx * 3.1, cy + 1.0, z + 1.4), (1.4, 1.4, 0.25), "wood_b", bevel=0.05)
        a.box((cx + sx * 3.1, cy + 1.0, z + 0.7), (1.1, 1.1, 1.4), "wood_dark", bevel=0.05)
    # 침대
    a.box((x1 - 2.4, y1 - 3.2, z + 1.0), (3.6, 6.0, 1.2), "wood_dark", bevel=0.08)
    a.box((x1 - 2.4, y1 - 3.2, z + 1.8), (3.3, 5.7, 0.5), "cloth_green", bevel=0.2)
    a.box((x1 - 2.4, y1 - 0.9, z + 2.2), (2.6, 1.0, 0.45), "paint_white", bevel=0.2)
    # 선반 + 항아리
    a.box((x0 + 0.8, y1 - 2.5, z + 5.0), (0.9, 4.0, 0.2), "wood_c", bevel=0.03)
    for k in range(3):
        S.bottle(a, (x0 + 0.8, y1 - 4.0 + k * 1.2, z + 5.1), h=0.8, key=("glass_green", "glass", "glow_potion")[k])
    S.barrel(a, (x0 + 1.6, y0 + 2.0, z), h=2.6, r=0.95)
    S.lantern(a, (cx, cy, z + 8.2), hang=0.8, rng_range=20, brightness=1.4)


def stilt_house_a():
    a = Asset("StiltHouseA", "Building", description="단층 수상 가옥 (베란다, 굴뚝)")
    Z = 7.0  # 바닥 높이
    # 플랫폼 & 기둥
    _stilt_grid(a, -11, 11, -10, 9, Z, 4, 4)
    S.plank_floor(a, -12.5, 12.5, -11.5, 10.5, Z, along="x")
    # 집 몸체 (뒤쪽으로 배치, 앞 베란다 -Y)
    x0, x1, y0, y1 = -8.5, 8.5, -4.5, 9.0
    zt = Z + 11
    for (cx, cy) in ((x0, y0), (x1, y0), (x0, y1), (x1, y1)):
        S.post(a, cx, cy, Z, zt + 0.3, 0.9, "wood_dark")
    # 앞벽: 문 + 창
    S.plank_wall(a, (x0, y0), (x1, y0), Z, zt, openings=[(3.2, 8.2, Z, Z + 8.2), (11.0, 14.5, Z + 3.6, Z + 7.4)], outward=-1)
    with a.at(loc=(x0, y0, 0)):
        S.door(a, 3.2, 5.0, 8.2, Z, keys=("wood_red",), open_angle=100, hinge_left=True, outward=-1)
        S.window(a, 11.0, Z + 3.6, 3.5, 3.8, keys=("wood_teal",), outward=-1)
    # 뒷벽
    S.plank_wall(a, (x1, y1), (x0, y1), Z, zt, openings=[(6.5, 10.0, Z + 3.6, Z + 7.4)], outward=-1)
    with a.at(loc=(x1, y1, 0), rot=(0, 0, 180)):
        S.window(a, 6.5, Z + 3.6, 3.5, 3.8, keys=("wood_teal",), outward=-1)
    # 옆벽
    S.plank_wall(a, (x1, y0), (x1, y1), Z, zt, openings=[(4.5, 8.0, Z + 3.6, Z + 7.4)], outward=-1)
    with a.at(loc=(x1, y0, 0), rot=(0, 0, 90)):
        S.window(a, 4.5, Z + 3.6, 3.5, 3.8, keys=("wood_teal",), outward=-1)
    S.plank_wall(a, (x0, y1), (x0, y0), Z, zt, openings=[], outward=-1)
    # 박공 벽 (삼각)
    span = y1 - y0
    pitch = 36.0
    rise = span / 2 * math.tan(math.radians(pitch))
    for xw in (x0, x1):
        prof = (lambda u, s=span: zt + (s / 2 - abs(u - s / 2)) * math.tan(math.radians(pitch)) - 0.2)
        S.plank_wall(a, (xw, y0), (xw, y1), zt - 0.2, zt, top_profile=prof, battens=False, collider=False, jag=0.0, outward=-1 if xw > 0 else 1)
    zr = S.gable_roof(a, (x0 + x1) / 2, (y0 + y1) / 2, zt, x1 - x0, span, pitch=pitch, overhang=1.8, gable_over=1.4)
    # 굴뚝 (왼쪽 벽 밖)
    _stone_chimney(a, x0 - 1.6, 4.5, Z - 0.2, zr + 1.6)
    # 베란다 난간 (문 앞 계단 입구 제외)
    S.railing(a, [(-12.2, -11.2), (-4.0, -11.2)], Z)
    S.railing(a, [(4.0, -11.2), (12.2, -11.2), (12.2, 10.2)], Z)
    S.railing(a, [(-12.2, 10.2), (-12.2, -11.2)], Z)
    S.railing(a, [(12.2, 10.2), (-12.2, 10.2)], Z)
    a.marker("Entrance", (0, -11.8, Z + 0.1), rot=(0, 0, 180))
    # 베란다 소품
    S.barrel(a, (-10.5, -9.2, Z), h=3.0)
    S.barrel(a, (-10.4, -6.6, Z), h=2.6, r=1.0, key="wood_a")
    S.crate(a, (9.8, -9.5, Z), s=2.6, yaw=12)
    S.crate(a, (9.9, -9.4, Z + 2.6), s=2.0, yaw=-8)
    S.rope_coil(a, (6.0, -9.8, Z))
    S.sack(a, (-7.6, -9.6, Z), key="straw")
    S.lantern(a, (x0 + 2.4, y0 - 1.3, Z + 8.6), bracket=(0, 1), rng_range=22)
    S.lantern(a, (11.9, -11.0, Z + 4.6), light=True, rng_range=16, brightness=1.1)
    # 걸린 물고기/약초
    for k in range(4):
        S.fish(a, (x1 + 0.6, y0 + 2.5 + k * 1.1, Z + 6.2), L=1.2, yaw=90)
    a.box_between((x1 + 0.6, y0 + 1.8, Z + 7.0), (x1 + 0.6, y0 + 7.2, Z + 7.0), 0.14, "rope", width=0.14)
    _interior(a, x0 + 0.6, x1 - 0.6, y0 + 0.6, y1 - 0.6, Z)
    # 이끼 덩어리 (기둥 아래)
    with a.no_parts():
        for k in range(10):
            ang = a.rng.uniform(0, 2 * math.pi)
            p = Vector((math.cos(ang) * a.rng.uniform(8, 13), math.sin(ang) * a.rng.uniform(8, 12), 0.2))
            a.sphere(p, a.rng.uniform(0.5, 1.0), "moss", seg=8, rings=5, scale=(1.4, 1.2, 0.35))
    return a


def stilt_house_b():
    a = Asset("StiltHouseB", "Building", description="2층 수상 가옥 (돌출 2층, 외부 계단)")
    Z = 7.0
    _stilt_grid(a, -10, 10, -9, 9, Z, 4, 4)
    S.plank_floor(a, -11.5, 11.5, -10.5, 10.5, Z, along="y")
    x0, x1, y0, y1 = -7.5, 7.5, -6.0, 7.5
    z1 = Z + 10
    for (cx, cy) in ((x0, y0), (x1, y0), (x0, y1), (x1, y1)):
        S.post(a, cx, cy, Z, z1 + 0.4, 0.9)
    S.plank_wall(a, (x0, y0), (x1, y0), Z, z1, openings=[(5.0, 10.0, Z, Z + 8.0)], outward=-1, keys=("wood_b", "wood_c", "wood_pale"))
    with a.at(loc=(x0, y0, 0)):
        S.door(a, 5.0, 5.0, 8.0, Z, keys=("wood_teal",), open_angle=95, outward=-1)
    S.plank_wall(a, (x1, y0), (x1, y1), Z, z1, openings=[(5.0, 8.4, Z + 3.5, Z + 7.2)], outward=-1, keys=("wood_b", "wood_c", "wood_pale"))
    with a.at(loc=(x1, y0, 0), rot=(0, 0, 90)):
        S.window(a, 5.0, Z + 3.5, 3.4, 3.7, keys=("wood_red",))
    S.plank_wall(a, (x1, y1), (x0, y1), Z, z1, outward=-1, keys=("wood_b", "wood_c", "wood_pale"))
    S.plank_wall(a, (x0, y1), (x0, y0), Z, z1, openings=[(5.0, 8.4, Z + 3.5, Z + 7.2)], outward=-1, keys=("wood_b", "wood_c", "wood_pale"))
    with a.at(loc=(x0, y1, 0), rot=(0, 0, -90)):
        S.window(a, 5.0, Z + 3.5, 3.4, 3.7, keys=("wood_red",))
    # 2층 (앞쪽/옆으로 1.5 돌출)
    Z2 = z1 + 0.6
    S.plank_floor(a, x0 - 1.8, x1 + 1.8, y0 - 1.8, y1 + 0.4, Z2 + 0.6, along="x", joists=True)
    # 까치발(브래킷)
    for x in (x0, 0, x1):
        a.box_between((x, y0, z1 - 2.5), (x, y0 - 1.6, Z2 - 0.4), 0.45, "wood_dark", width=0.45)
    X0, X1, Y0, Y1 = x0 - 1.6, x1 + 1.6, y0 - 1.6, y1 + 0.2
    z2 = Z2 + 0.6 + 8.5
    for (cx, cy) in ((X0, Y0), (X1, Y0), (X0, Y1), (X1, Y1)):
        S.post(a, cx, cy, Z2, z2 + 0.3, 0.8)
    wk = ("wood_a", "wood_moss", "wood_b")
    S.plank_wall(a, (X0, Y0), (X1, Y0), Z2 + 0.6, z2, openings=[(3.0, 6.4, Z2 + 3.4, Z2 + 7.0), (11.8, 15.2, Z2 + 3.4, Z2 + 7.0)], outward=-1, keys=wk)
    with a.at(loc=(X0, Y0, 0)):
        S.window(a, 3.0, Z2 + 3.4, 3.4, 3.6, keys=("wood_red",))
        S.window(a, 11.8, Z2 + 3.4, 3.4, 3.6, keys=("wood_red",))
    S.plank_wall(a, (X1, Y0), (X1, Y1), Z2 + 0.6, z2, openings=[(6.0, 12.0, Z2 + 0.6, Z2 + 8.0)], outward=-1, keys=wk)
    S.plank_wall(a, (X1, Y1), (X0, Y1), Z2 + 0.6, z2, openings=[(7.0, 10.4, Z2 + 3.4, Z2 + 7.0)], outward=-1, keys=wk)
    with a.at(loc=(X1, Y1, 0), rot=(0, 0, 180)):
        S.window(a, 7.0, Z2 + 3.4, 3.4, 3.6, keys=("wood_red",))
    S.plank_wall(a, (X0, Y1), (X0, Y0), Z2 + 0.6, z2, outward=-1, keys=wk)
    span = Y1 - Y0
    pitch = 40
    for xw in (X0, X1):
        prof = (lambda u, s=span: z2 + (s / 2 - abs(u - s / 2)) * math.tan(math.radians(pitch)) - 0.2)
        S.plank_wall(a, (xw, Y0), (xw, Y1), z2 - 0.2, z2, top_profile=prof, battens=False, collider=False, jag=0.0)
    zr = S.gable_roof(a, 0, (Y0 + Y1) / 2, z2, X1 - X0, span, pitch=pitch, overhang=1.8, gable_over=1.5, moss=0.12)
    # 2층 옆 발코니 + 외부 계단 (오른쪽)
    S.plank_floor(a, X1, X1 + 5.5, Y0 + 3.5, Y1 - 0.5, Z2 + 0.6, along="y", joists=False)
    for (px, py) in ((X1 + 5.2, Y0 + 3.8), (X1 + 5.2, Y1 - 0.8)):
        S.post(a, px, py, Z - 0.3, Z2 + 0.6, 0.7)
    S.railing(a, [(X1 + 5.3, Y1 - 0.6), (X1 + 5.3, Y0 + 3.6)], Z2 + 0.6)
    S.stairs(a, (X1 + 2.8, -10.2, Z), (X1 + 2.8, Y0 + 3.6, Z2 + 0.6), width=4.2)
    # 아래층 앞 난간
    S.railing(a, [(-11.2, -10.2), (-4.0, -10.2)], Z)
    S.railing(a, [(4.0, -10.2), (7.5, -10.2)], Z)
    S.railing(a, [(-11.2, 10.2), (-11.2, -10.2)], Z)
    S.railing(a, [(11.2, 10.2), (-11.2, 10.2)], Z)
    a.marker("Entrance", (0, -10.8, Z + 0.1), rot=(0, 0, 180))
    S.lantern(a, (x0 + 3.5, y0 - 1.2, Z + 8.0), bracket=(0, 1))
    S.lantern(a, (X1 + 5.3, Y0 + 3.6, Z2 + 4.2), light=True, brightness=1.1)
    S.barrel(a, (-9.5, -8.6, Z))
    S.crate(a, (9.4, 8.2, Z), s=2.4)
    S.crate(a, (9.0, 5.4, Z), s=2.4, yaw=20)
    # 창가 화분
    for x in (X0 + 3.2, X0 + 12.0):
        a.box((x + 1.7, Y0 - 0.7, Z2 + 3.1), (3.6, 1.0, 0.8), "wood_dark", bevel=0.05)
        for k in range(4):
            a.sphere((x + 0.4 + k * 0.85, Y0 - 0.7, Z2 + 3.7), 0.5, "leaf", seg=6, rings=4)
            a.sphere((x + 0.4 + k * 0.85, Y0 - 0.9, Z2 + 4.1), 0.18, "flower_pink" if k % 2 else "flower_white", seg=5, rings=3)
    _interior(a, x0 + 0.6, x1 - 0.6, y0 + 0.6, y1 - 0.6, Z)
    S.lantern(a, (0, 0, z2 - 1.0), hang=0.6, rng_range=18)
    return a


def stilt_hut_c():
    a = Asset("StiltHutC", "Building", description="초가 지붕 소형 오두막 (어부 오두막)")
    Z = 6.0
    _stilt_grid(a, -7, 7, -6, 6, Z, 3, 3, braces=True)
    S.plank_floor(a, -8.5, 8.5, -9.5, 7.5, Z, along="x", missing=0.04)
    x0, x1, y0, y1 = -6, 6, -4.5, 6.0
    zt = Z + 9
    for (cx, cy) in ((x0, y0), (x1, y0), (x0, y1), (x1, y1)):
        S.post(a, cx, cy, Z, zt + 0.3, 0.8)
    keys = ("wood_moss", "wood_b", "wood_a")
    S.plank_wall(a, (x0, y0), (x1, y0), Z, zt, openings=[(1.2, 5.4, Z, Z + 7.5), (8.0, 10.6, Z + 3.4, Z + 6.2)], keys=keys)
    with a.at(loc=(x0, y0, 0)):
        S.window(a, 8.0, Z + 3.4, 2.6, 2.8, shutters=False)
    S.plank_wall(a, (x1, y0), (x1, y1), Z, zt, keys=keys)
    S.plank_wall(a, (x1, y1), (x0, y1), Z, zt, openings=[(4.5, 7.5, Z + 3.4, Z + 6.2)], keys=keys)
    S.plank_wall(a, (x0, y1), (x0, y0), Z, zt, keys=keys)
    span = y1 - y0
    for xw in (x0, x1):
        prof = (lambda u, s=span: zt + (s / 2 - abs(u - s / 2)) * math.tan(math.radians(45)) - 0.3)
        S.plank_wall(a, (xw, y0), (xw, y1), zt - 0.2, zt, top_profile=prof, battens=False, collider=False, jag=0.0, keys=keys)
    S.thatch_roof(a, 0, (y0 + y1) / 2, zt, x1 - x0, span, pitch=45, overhang=1.8)
    # 그물 건조대 (오른쪽 측면, 통로를 막지 않도록)
    for y in (-8.6, 5.8):
        S.post(a, 8.1, y, Z, Z + 7.0, 0.5)
    a.box_between((8.1, -8.6, Z + 6.8), (8.1, 5.8, Z + 6.8), 0.3, "wood_c", width=0.3)
    with a.no_parts():
        for i in range(13):
            y = -8.0 + i * 13.2 / 12
            pts = [Vector((8.1 + 0.3 * math.sin(k * 0.8 + i), y, Z + 6.7 - k * 0.75 - 0.3 * math.sin(i * 0.5))) for k in range(7)]
            a.tube(pts, 0.05, "net", sides=3, caps=False, part=False)
        for k in range(6):
            z = Z + 6.3 - k * 0.75
            pts = [Vector((8.1 + 0.3 * math.sin(k * 0.8 + i), -8.0 + i * 13.2 / 12, z - 0.3 * math.sin(i * 0.5))) for i in range(13)]
            a.tube(pts, 0.05, "net", sides=3, caps=False, part=False)
    a._prim_box_only((8.1, -1.4, Z + 4.5), (0.1, 13.2, 4.5), "net")
    for k in range(5):
        S.fish(a, (-6.8 + k * 1.6, -8.9, Z + 6.0), L=1.2)
    a.box_between((-7.8, -8.9, Z + 6.9), (-0.5, -8.9, Z + 6.9), 0.14, "rope", width=0.14)
    for x in (-7.8, -0.5):
        S.post(a, x, -8.9, Z, Z + 7.2, 0.45)
    S.ladder(a, 8.4, -2.0, -1.0, Z, yaw=90)
    S.rope_coil(a, (-6.2, -7.5, Z))
    S.barrel(a, (5.8, -7.2, Z), h=2.4, r=0.95, key="wood_c")
    S.lantern(a, (x0 + 6.4, y0 - 1.2, Z + 5.6), bracket=(0, 1), rng_range=16)
    a.marker("Entrance", (3.3, -9.8, Z + 0.1), rot=(0, 0, 180))
    return a


ASSETS = [stilt_house_a, stilt_house_b, stilt_hut_c]
