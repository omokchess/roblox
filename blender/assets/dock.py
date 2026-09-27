"""선착장 (FerryDock) — T자형 부두. 연락선이 T헤드 바깥면(-X)에 정박한다.

로컬 좌표: +X = 육지 방향, 부두 윗면 Z=7, 정박 마커 'FerryMoor' 는 배 중심(수면)과 진행방향(+Y).
"""

import math

from mathutils import Vector

from swamplib.asset import Asset
from swamplib import shapes as S

DECK = 7.0
PIER_X0, PIER_X1 = -48.0, 2.0      # 부두 몸통 (바다쪽 끝 ~ 육지쪽 끝)
PIER_W = 10.0
T_X0, T_X1 = -58.0, -48.0           # T헤드 x 범위 (바깥면 = -58)
T_Y = 38.0                          # T헤드 반길이
SHIP_HALF_BEAM = 12.5               # 배 반폭 + 여유 (ship.py 와 맞춤)


def _pilings(a, xs, ys, z_top):
    posts = {}
    for x in xs:
        for y in ys:
            b, t = S.stilt(a, x, y, z_top - 0.6, z_bottom=-9.0, r=0.7, lean=1.5)
            posts[(x, y)] = (b, t)
            a.collider((x, y, (z_top - 9.0) / 2 - 0.3), (1.3, 1.3, z_top + 9.0), tag="Stilt")
    return posts


def ferry_dock():
    a = Asset("FerryDock", "Dock", description="T자형 연락선 선착장 (정박면, 종, 매표소)")
    # ── 부두 몸통 ──
    xs = [PIER_X0 + 2 + i * 8 for i in range(int((PIER_X1 - PIER_X0) / 8) + 1)]
    _pilings(a, xs, [-PIER_W / 2 + 0.6, PIER_W / 2 - 0.6], DECK)
    for x in xs:
        a.box((x, 0, DECK - 1.25), (1.0, PIER_W + 1.2, 1.0), "wood_dark", bevel=0.1)
    S.plank_floor(a, PIER_X0, PIER_X1, -PIER_W / 2, PIER_W / 2, DECK, along="y", joists=False)
    for y in (-PIER_W / 2 + 0.6, PIER_W / 2 - 0.6):
        a.box(((PIER_X0 + PIER_X1) / 2, y, DECK - 1.25), (PIER_X1 - PIER_X0, 0.9, 1.0), "wood_dark", bevel=0.1)
    # ── T 헤드 ──
    tys = [-T_Y + 2 + i * 8 for i in range(int((2 * T_Y - 4) / 8) + 1)]
    posts = _pilings(a, [T_X0 + 0.8, T_X1 - 0.8], tys, DECK)
    for y in tys:
        a.box(((T_X0 + T_X1) / 2, y, DECK - 1.25), (T_X1 - T_X0 + 1.4, 1.0, 1.0), "wood_dark", bevel=0.1)
    for x in (T_X0 + 0.8, T_X1 - 0.8):
        a.box((x, 0, DECK - 1.25), (0.9, 2 * T_Y, 1.0), "wood_dark", bevel=0.1)
    S.plank_floor(a, T_X0, T_X1, -T_Y, T_Y, DECK, along="x", joists=False)
    # X 버팀 (바깥면)
    for i in range(len(tys) - 1):
        b0, t0 = posts[(T_X0 + 0.8, tys[i])]
        b1, t1 = posts[(T_X0 + 0.8, tys[i + 1])]
        S.cross_brace(a, t0 - Vector((0, 0, 1.5)), Vector((b0.x, b0.y, 0.5)), t1 - Vector((0, 0, 1.5)), Vector((b1.x, b1.y, 0.5)))
    # 방현재 (펜더): 바깥면에 매달린 통나무
    for y in range(int(-T_Y + 4), int(T_Y - 3), 6):
        a.cyl((T_X0 - 0.9, y, -1.5), (T_X0 - 0.9, y, DECK - 0.4), 0.55, "wood_wet", sides=8, bevel=0.1)
        with a.no_parts():
            for z in (DECK - 1.0, 2.0):
                ring = [Vector((T_X0 - 0.9 + math.cos(t) * 0.65, y + math.sin(t) * 0.65, z)) for t in [i * 2 * math.pi / 8 for i in range(9)]]
                a.tube(ring, 0.12, "rope", sides=4, caps=False, part=False)
    a.box((T_X0 - 0.3, 0, DECK - 0.35), (0.6, 2 * T_Y, 0.7), "wood_dark", bevel=0.1)
    # 계선주 (볼라드)
    for y in (-30, -12, 12, 30):
        x = T_X0 + 1.6
        a.cyl((x, y, DECK - 0.2), (x, y, DECK + 1.6), 0.7, "iron", r1=0.6, sides=12, bevel=0.1)
        a.cyl((x, y, DECK + 1.6), (x, y, DECK + 1.9), 0.9, "iron", sides=12, bevel=0.08)
        S.rope_coil(a, (x + 1.9, y, DECK - 0.1), r=0.8, turns=3)
        a.collider((x, y, DECK + 0.9), (1.4, 1.4, 1.8), tag="Prop")
    # ── 난간 (정박면 제외) ──
    S.rope_railing(a, [(PIER_X1 - 0.5, -PIER_W / 2 + 0.3), (T_X1 + 0.3, -PIER_W / 2 + 0.3)], DECK)
    S.rope_railing(a, [(PIER_X1 - 0.5, PIER_W / 2 - 0.3), (T_X1 + 0.3, PIER_W / 2 - 0.3)], DECK)
    S.rope_railing(a, [(T_X1 - 0.3, -PIER_W / 2 - 0.4), (T_X1 - 0.3, -T_Y + 0.3), (T_X0 + 2.8, -T_Y + 0.3)], DECK)
    S.rope_railing(a, [(T_X1 - 0.3, PIER_W / 2 + 0.4), (T_X1 - 0.3, T_Y - 0.3), (T_X0 + 2.8, T_Y - 0.3)], DECK)
    # ── 가로등 ──
    for (x, y) in ((PIER_X1 - 4, -PIER_W / 2 + 0.3), (-22, PIER_W / 2 - 0.3), (T_X1 - 0.3, -T_Y + 0.3), (T_X1 - 0.3, T_Y - 0.3)):
        lamp_post(a, (x, y, DECK))
    # ── 출항 종 ──
    bx, by = T_X1 - 2.0, -PIER_W / 2 - 4.0
    for dy in (-1.6, 1.6):
        S.post(a, bx, by + dy, DECK, DECK + 8.0, 0.55)
    a.box((bx, by, DECK + 8.1), (0.8, 4.4, 0.6), "wood_dark", bevel=0.06)
    bell = Vector((bx, by, DECK + 7.6))
    prof = [(0.0, 0.25), (-0.35, 0.45), (-1.0, 0.65), (-1.5, 0.95), (-1.65, 1.02)]
    a.tube([bell + Vector((0, 0, z)) for z, _ in prof], [r for _, r in prof], "brass", sides=14, part_step=2)
    a.sphere(bell + Vector((0, 0, -1.55)), 0.25, "iron", seg=8, rings=5)
    a.marker("DepartureBell", tuple(bell))
    a.collider((bx, by, DECK + 4.0), (1.0, 4.2, 8.0), tag="Prop")
    # ── 매표소 (항로 안내) ──
    kiosk(a, T_X1 - 5.0, 20.0)
    # 화물
    S.crate(a, (T_X1 - 3.0, -20.0, DECK), 2.6, 5)
    S.crate(a, (T_X1 - 3.2, -23.0, DECK), 2.6, -10)
    S.crate(a, (T_X1 - 3.1, -21.5, DECK + 2.6), 2.2, 30)
    S.barrel(a, (T_X1 - 3.0, -27.0, DECK))
    S.barrel(a, (T_X1 - 5.4, -27.5, DECK), h=2.6, r=1.0, key="wood_c")
    S.sack(a, (T_X1 - 5.2, -24.8, DECK), key="straw")
    S.sack(a, (T_X1 - 6.0, -22.0, DECK), key="cloth_green")
    # ── 육지 경사로 (부두 → 해안) ──
    _ramp(a)
    # 정박 마커: 배 중심, 진행 방향 +Y
    a.marker("FerryMoor", (T_X0 - 1.5 - SHIP_HALF_BEAM, 0, 0))
    a.marker("BoardingZone", ((T_X0 + T_X1) / 2, 0, DECK + 3), size=[T_X1 - T_X0, 2 * T_Y, 6])
    a.marker("ShoreEnd", (PIER_X1 + 16.0, 0, 1.2))
    a.marker("Sign", (T_X1 - 5.0 + 3.21, 20.0, DECK + 7.6), rot=(0, 0, 90), text="안개늪 연락선", width=5.0, height=1.2)
    return a


def _ramp(a):
    x0, x1 = PIER_X1, PIER_X1 + 16.0
    z0, z1 = DECK, 1.2
    n = 16
    for i in range(n):
        t = (i + 0.5) / n
        x = x0 + (x1 - x0) * t
        z = z0 + (z1 - z0) * t
        a.box((x, 0, z - 0.2), ((x1 - x0) / n + 0.08, PIER_W - 0.6, 0.35), S.pick(a, S.WOOD), rot=(0, math.degrees(math.atan2(z0 - z1, x1 - x0)) + a.rng.uniform(-1, 1), 0), bevel=0.05)
    for y in (-PIER_W / 2 + 0.5, PIER_W / 2 - 0.5):
        a.box_between((x0, y, z0 - 0.8), (x1, y, z1 - 0.8), 0.9, "wood_dark", width=0.5)
        for t in (0.25, 0.6):
            x = x0 + (x1 - x0) * t
            z = z0 + (z1 - z0) * t
            a.cyl((x, y, -2.0), (x, y, z - 0.6), 0.55, "wood_dark", sides=8)
    a.collider_between((x0, 0, z0 + 0.05), (x1, 0, z1 + 0.05), PIER_W - 0.6, 1.0, tag="Ramp")


def lamp_post(a, pos, h=9.0):
    p = Vector(pos)
    S.post(a, p.x, p.y, p.z - 0.2, p.z + h, 0.6, "wood_dark")
    a.box_between((p.x, p.y, p.z + h - 0.3), (p.x + 1.6, p.y, p.z + h - 0.3), 0.35, "wood_dark", width=0.3)
    a.box_between((p.x, p.y, p.z + h - 1.6), (p.x + 1.2, p.y, p.z + h - 0.35), 0.25, "wood_dark", width=0.2)
    S.lantern(a, (p.x + 1.6, p.y, p.z + h - 1.9), hang=0.4, rng_range=24, brightness=1.5)
    a.collider((p.x, p.y, p.z + h / 2), (0.8, 0.8, h), tag="Prop")


def kiosk(a, cx, cy, w=6.0, d=7.0):
    Z = DECK
    x0, x1, y0, y1 = cx - w / 2, cx + w / 2, cy - d / 2, cy + d / 2
    for (px, py) in ((x0, y0), (x1, y0), (x0, y1), (x1, y1)):
        S.post(a, px, py, Z, Z + 8.5, 0.6)
    S.plank_wall(a, (x0, y0), (x0, y1), Z, Z + 8, openings=[(1.6, 5.4, Z + 3.4, Z + 6.6)], keys=("wood_teal", "wood_b", "wood_c"))
    S.plank_wall(a, (x1, y1), (x1, y0), Z, Z + 8, openings=[(2.0, 5.0, Z, Z + 7.0)], keys=("wood_teal", "wood_b", "wood_c"))
    S.plank_wall(a, (x0, y1), (x1, y1), Z, Z + 8, keys=("wood_teal", "wood_b", "wood_c"))
    S.plank_wall(a, (x1, y0), (x0, y0), Z, Z + 8, keys=("wood_teal", "wood_b", "wood_c"))
    a.box((x0 - 0.8, cy, Z + 3.3), (1.6, 4.4, 0.3), "wood_c", bevel=0.05)
    _flat_roof(a, x0, x1, y0, y1, Z + 8.0)
    # 안내판 (벽면 SurfaceGui 대상)
    a.box((x1 + 0.25, cy, Z + 7.6), (0.3, 5.4, 1.6), "wood_pale", bevel=0.05)
    a.box((x0 - 0.2, cy, Z + 9.9), (0.3, 5.6, 1.8), "wood_dark", bevel=0.05)
    a.marker("ScheduleBoard", (x0 - 0.4, cy, Z + 9.9), rot=(0, 0, -90), width=5.2, height=1.5)
    S.lantern(a, (x0 - 0.6, y0 + 0.4, Z + 6.8), bracket=(1, 0), rng_range=16)


def _flat_roof(a, x0, x1, y0, y1, z):
    """살짝 기운 판자 지붕."""
    S.shed_roof(a, x0 - 0.2, x1 + 0.2, y0 - 0.2, y1 + 0.2, z, z + 1.2, overhang=1.0)


ASSETS = [ferry_dock]
