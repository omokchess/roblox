"""시장 가판대 & 안내판."""

import math

from mathutils import Vector

from swamplib.asset import Asset
from swamplib import geom, shapes as S


def _awning(a, x0, x1, y_front, y_back, z_front, z_back, key, stripes=None):
    """처진 천 차양 (메시) + Part 근사."""
    def fn(u, v):
        x = x0 + (x1 - x0) * u
        y = y_back + (y_front - y_back) * v
        z = z_back + (z_front - z_back) * v - 0.5 * math.sin(math.pi * u) * math.sin(math.pi * v) * 0.8
        return (x, y, z)
    geo = geom.solidify(*geom.grid_surface(fn, 12, 6), 0.08)
    a.mesh(geo, key)
    L = math.hypot(y_front - y_back, z_front - z_back)
    ang = math.degrees(math.atan2(z_front - z_back, abs(y_front - y_back)))
    a._prim_box_only(((x0 + x1) / 2, (y_front + y_back) / 2, (z_front + z_back) / 2 - 0.2), (x1 - x0, L, 0.1), key, rot=(ang if y_front < y_back else -ang, 0, 0))
    # 앞 끝 술 장식
    with a.no_parts():
        n = int((x1 - x0) / 0.9)
        for i in range(n):
            x = x0 + (i + 0.5) * (x1 - x0) / n
            kk = stripes[i % len(stripes)] if stripes else key
            a.box((x, y_front, z_front - 0.45), (0.8, 0.06, 0.9), kk, rot=(0, 0, 0), bevel=0.0)


def _basket(a, pos, r=0.9, h=0.8, content=None):
    p = Vector(pos)
    with a.at(loc=p):
        prof = [(0.0, r * 0.8), (h * 0.5, r * 0.95), (h, r)]
        a.tube([Vector((0, 0, z)) for z, _ in prof], [rr for _, rr in prof], "straw", sides=12, part_step=2)
        with a.no_parts():
            ring = [Vector((math.cos(t) * r, math.sin(t) * r, h)) for t in [i * 2 * math.pi / 12 for i in range(13)]]
            a.tube(ring, 0.1, "rope", sides=4, caps=False, part=False)
        if content:
            for k in range(5):
                ang = k * 2 * math.pi / 5
                a.sphere((math.cos(ang) * r * 0.45, math.sin(ang) * r * 0.45, h - 0.05), r * 0.33, content, seg=7, rings=5)
            a.sphere((0, 0, h + 0.1), r * 0.35, content, seg=7, rings=5)


def _pot(a, pos, r=0.7, key="brick"):
    p = Vector(pos)
    prof = [(0.0, r * 0.55), (r * 0.6, r), (r * 1.2, r * 0.8), (r * 1.5, r * 0.45), (r * 1.7, r * 0.5)]
    a.tube([p + Vector((0, 0, z)) for z, _ in prof], [rr for _, rr in prof], key, sides=12, part_step=2)


def _stall(a, name_key, awning_key, stripes, goods):
    Z = 0.0
    W, D = 10.0, 6.0
    x0, x1, y0, y1 = -W / 2, W / 2, -D / 2, D / 2
    for (px, py, h) in ((x0, y0, 7.6), (x1, y0, 7.6), (x0, y1, 9.0), (x1, y1, 9.0)):
        S.post(a, px, py, Z, Z + h, 0.55)
    # 카운터
    a.box((0, y0 + 0.9, Z + 3.4), (W - 0.2, 1.8, 0.3), "wood_c", bevel=0.05)
    S.plank_wall(a, (x0 + 0.3, y0 + 0.2), (x1 - 0.3, y0 + 0.2), Z, Z + 3.25, battens=False, collider=False, jag=0.05, keys=("wood_a", "wood_b"))
    a.collider((0, y0 + 0.9, Z + 1.7), (W, 1.8, 3.4), tag="Prop")
    # 뒤 선반
    for z in (Z + 2.4, Z + 4.6):
        a.box((0, y1 - 0.6, z), (W - 0.6, 1.2, 0.22), "wood_c", bevel=0.04)
    a.collider((0, y1 - 0.6, Z + 3.0), (W, 1.2, 6.0), tag="Prop")
    _awning(a, x0 - 0.6, x1 + 0.6, y0 - 1.8, y1 + 0.2, Z + 7.2, Z + 9.2, awning_key, stripes)
    # 상품
    goods(a, Z, x0, x1, y0, y1)
    # 간판
    a.box((0, y0 - 0.2, Z + 6.9), (5.0, 0.25, 1.1), "wood_pale", bevel=0.05)
    a.marker("Sign", (0, y0 - 0.34, Z + 6.9), rot=(0, 0, 180), text=name_key, width=4.6, height=0.9)
    S.lantern(a, (x1 + 0.2, y0 - 0.9, Z + 6.2), hang=0.3, rng_range=14, brightness=1.0)
    a.marker("Shopkeeper", (0, y1 - 2.2, Z + 0.1), rot=(0, 0, 180))


def _fish_goods(a, Z, x0, x1, y0, y1):
    for k in range(6):
        S.fish(a, (x0 + 1.2 + k * 1.5, y0 + 0.9, Z + 3.75), L=1.3, pitch=0, yaw=90 + a.rng.uniform(-20, 20))
    for k in range(4):
        S.fish(a, (x0 + 1.5 + k * 2.2, y0 - 0.2, Z + 6.4), L=1.2)
    _basket(a, (x0 + 1.5, y1 - 0.6, Z + 2.5), content="fish")
    S.barrel(a, (x1 - 1.4, y1 - 1.5, Z), h=2.2, r=0.85)
    for k in range(3):
        _basket(a, (x0 + 1.0 + k * 1.8, y0 - 1.4, Z), r=0.8, content=("fish", "mushroom_cap", "lily")[k])


def _potion_goods(a, Z, x0, x1, y0, y1):
    for k in range(8):
        S.bottle(a, (x0 + 1.0 + k * 1.1, y0 + 0.8, Z + 3.55), h=a.rng.uniform(0.7, 1.1), key=("glow_potion", "glass_green", "glow_mushroom", "glass")[k % 4])
    for k in range(6):
        S.bottle(a, (x0 + 1.2 + k * 1.4, y1 - 0.6, Z + 4.7), h=0.9, key=("glass_green", "glow_potion")[k % 2])
    for k in range(4):
        _pot(a, (x0 + 1.4 + k * 2.3, y1 - 0.6, Z + 2.5), r=0.5)
    # 매달린 약초 묶음
    with a.no_parts():
        for k in range(5):
            x = x0 + 1.5 + k * 1.8
            a.cyl((x, y0 - 0.1, Z + 7.0), (x, y0 - 0.1, Z + 6.2), 0.03, "rope", sides=3)
            a.blob((x, y0 - 0.1, Z + 5.8), 0.35, "leaf", seg=6, rings=4, amp=0.4, scale=(0.8, 0.8, 1.3))
    _pot(a, (x1 + 1.0, y0 - 0.8, Z), r=0.9)
    _pot(a, (x1 + 1.6, y0 + 1.0, Z), r=0.7, key="stone_dk")


def market_stall_a():
    a = Asset("MarketStallA", "Prop", description="생선 가판대 (녹색 줄무늬 차양)")
    _stall(a, "늪 생선", "cloth_green", ("cloth_green", "sail"), _fish_goods)
    return a


def market_stall_b():
    a = Asset("MarketStallB", "Prop", description="물약 가판대 (보라 차양)")
    _stall(a, "물약 상점", "cloth_purple", ("cloth_purple", "sail_patch"), _potion_goods)
    return a


def notice_board():
    a = Asset("NoticeBoard", "Prop", description="게시판 (퀘스트/안내 SurfaceGui 대상)")
    for sx in (-1, 1):
        S.post(a, sx * 3.2, 0, 0, 7.5, 0.5)
    S.plank_wall(a, (-3.0, 0), (3.0, 0), 2.2, 6.4, battens=False, collider=False, jag=0.02, keys=("wood_c", "wood_pale"))
    a.box((0, 0, 7.4), (8.0, 1.6, 0.3), "wood_dark", rot=(8, 0, 0), bevel=0.04)
    a.box((0, -0.3, 7.25), (8.0, 1.4, 0.2), "wood_dark", rot=(-20, 0, 0), bevel=0.04)
    for k, (x, z) in enumerate(((-1.8, 5.3), (0.6, 5.0), (1.9, 3.5), (-1.0, 3.3))):
        a.box((x, -0.25, z), (1.4, 0.04, 1.8), "paper", rot=(0, a.rng.uniform(-6, 6), 0), bevel=0.0)
    a.marker("Board", (0, -0.3, 4.3), rot=(0, 0, 180), width=5.6, height=3.8)
    a.collider((0, 0, 3.8), (7.0, 0.8, 7.6), tag="Prop")
    return a


def signpost():
    a = Asset("Signpost", "Prop", description="방향 표지판 (SurfaceGui 로 목적지 표시)")
    S.post(a, 0, 0, -0.5, 9.0, 0.6)
    for i, (z, yaw, name) in enumerate(((7.6, 20, "SignA"), (6.2, -35, "SignB"), (4.8, 150, "SignC"))):
        with a.at(loc=(0, 0, z), rot=(0, 0, yaw)):
            a.box((2.2, 0, 0), (4.0, 0.3, 1.0), "wood_pale", bevel=0.05)
            a.box((4.45, 0, 0), (0.7, 0.3, 0.7), "wood_pale", rot=(0, 45, 0), bevel=0.02)
            a.marker(name, (2.3, -0.17, 0), rot=(0, 0, 180), width=3.6, height=0.8)
    a.collider((0, 0, 4.5), (0.8, 0.8, 9.0), tag="Prop")
    return a


ASSETS = [market_stall_a, market_stall_b, notice_board, signpost]
