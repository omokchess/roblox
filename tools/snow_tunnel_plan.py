# -*- coding: utf-8 -*-
"""
snow_tunnel_plan.py — 2026-10-31. 설원 동굴 입구 셋을 비스듬한 굴(지하 터널)로 → tools/Snow_Tunnels_data.luau
사용자: "동굴이 지하에 있는 건 의도한 사항이 맞는데, 들어갈 땐 비스듬하게, 지하 터널 들어가는 것처럼".

예전: 땅에 뚫린 네모 구멍(snow3_ground.HOLES) + 구멍 벽을 도는 디딤 블록(Snow3_Under 의 ShaftWall · Ledge).
이제: 굴마다 북쪽 바위 언덕에 판 갱도 입구 → 1:2 로 내려가는 굴(바닥은 높이 1 · 깊이 2 블록 계단, 벽·천장은 같이 기울어짐,
      12 스터드마다 갱목 틀, 세 틀마다 등잔 — 진짜 불) → 바닥 -70 평지 → 그 굴 방의 북쪽 벽을 뚫고 들어간다.
      예전 구멍은 땅으로 메우고(땅 규칙: 바위 + 눈 윗판), 굴 방 천장도 막는다.
  - 땅 속을 지나는 굴 위는 도랑을 파서(Land 상자 빼기) 굴을 넣고 그 위를 다시 땅으로 덮는다(땅 밑 -24 아래로 들어가면 덮을 필요 없음)
  - 입구 바위 언덕(손 표 PORTAL_ROCKS — 굴 몸 쪽 좌표): 굴 지붕이 땅 위로 나오는 첫 38 스터드를 덮는다. 굴 안을 침범하지 않게 확인
  - 3번 입구: 입구에 잠긴 쇠창살(속성 QuestLocked — 예전 구멍 위 창살 대신)
  - 순간이동 명소(TeleportSpot): 입구마다 앞 14 스터드
굴 셋은 다 북 → 남으로 내려간다(입 = 굴 방 북쪽 벽). 지하 방은 snow3_under(그림 좌표 + UNDER_SHIFT).
돌리기: python tools/snow_tunnel_plan.py (문제 0건) → 짓기: tools/Snow_Tunnels.luau (Snow3_Build · Snow3_Under · Snow_City2 뒤 — 다시 지으면 이것도 다시)
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from snow3_plan import SCALE, world  # noqa: E402
import snow3_ground as SG  # noqa: E402
import snow3_under as U  # noqa: E402

G = SG.grid()[0]
W, T, HV = 14.0, 3.0, 16.0          # 굴 안 폭 · 벽 두께 · 안 높이(세로, 계단 선 위)
TH = math.atan(0.5)                 # 1 내려가고 2 나아감
CO, SI = math.cos(TH), math.sin(TH)
HC = HV * CO                        # 천장 밑까지(굴 몸에 수직)
LAND_BOTTOM = -24
FLOOR = -70
LANDING = 24                        # 바닥 -70 평지 길이(벽 두께 18.5 포함)
WALL_CELL = U.CELL * SCALE          # 지하 벽 한 칸 = 18.5

# 손 표: 이름, 굴 가운데 그림 X, 들어갈 굴 방, 메울 옛 구멍, 잠김
TUNNELS = [
    ("동굴 입구 2", 293, "입구2 방", "동굴 입구 2", False),
    ("동굴 입구 1", 700, "동굴입구1 굴", "동굴 입구 1", False),
    ("3번 입구", 841, "입구1 굴", "3번 입구", True),
]
# 입구 바위 언덕(굴 몸 좌표: lx 옆(+ 동), lz 굴 안쪽으로(+ 남), ly 땅 위) { lx0, lx1, lz0, lz1, ly0, ly1, 돌림, 색 1/2 }
# 굴 안(|lx| < 7, ly < 16 - lz/2)을 침범하면 안 된다 — 덮개는 앞 끝의 굴 천장 높이에서 시작해 계단처럼 내려간다.
PORTAL_ROCKS = [
    (-12, 12, -1, 10, 16.5, 29.0, 0, 1),     # 덮개 1(입구 위 — 갱목 윗보 바로 위)
    (-12.5, 11.5, 10, 20, 11.2, 25.4, 0, 2),  # 덮개 2
    (-11.5, 12.5, 20, 30, 6.1, 20.6, 0, 1),   # 덮개 3
    (-12, 12, 30, 40, 1.2, 13.8, 0, 2),       # 덮개 4
    (-13, 11, 40, 49, -0.2, 6.6, 0, 1),       # 뒤 꼬리
    (-26, -9, -2, 22, -0.2, 27.6, 0, 2),      # 왼 어깨
    (-24, -9, 22, 40, -0.2, 17.8, 0, 1),      # 왼 뒤
    (-31, -21, -7, 9, -0.2, 11.4, 6, 2),      # 왼 발치(앞으로 나온 돌)
    (9, 25, -1, 20, -0.2, 24.8, 0, 1),        # 오른 어깨
    (9, 23, 20, 38, -0.2, 15.6, 0, 2),        # 오른 뒤
    (18, 28, -8, 5, -0.2, 8.6, -8, 1),        # 오른 발치
    (-17, -3, 4, 16, 28.6, 34.4, 4, 2),       # 위 왼 혹
    (2, 14, 11, 22, 24.9, 30.2, -5, 1),       # 위 오른 혹
    (-8, 3, 22, 31, 20.2, 24.6, 9, 2),        # 위 뒤 혹
]

parts = []    # (종류, cx, cy, cz, sx, sy, sz, rx 도, ry 도)
carve_land = []   # (x0, x1, y0, y1, z0, z1)
carve_under = []
air = []
lamps = []    # (x, y, z, rx)
spots = []    # (이름, x, y, z, 보는 x, 보는 z)
caps = []     # 옛 구멍 메움 (이름, x0, x1, z0, z1, 땅 높이)
gates = []    # 쇠창살 (이름, [parts])
bad = []


def P(kind, cx, cy, cz, sx, sy, sz, rx=0.0, ry=0.0):
    parts.append((kind, cx, cy, cz, sx, sy, sz, rx, ry))


def room(name):
    for r in U.rects_all():
        if r[0] == name or r[0].startswith(name + "("):
            return r
    raise KeyError(name)


def land_block(x0, x1, z0, z1, y0, top):
    """땅 규칙: 바위(y0 ~ top-2) + 눈 윗판(top-2.2 ~ top-0.2, 0.1 넓게)."""
    if top - 2 - y0 > 0.3:
        P("Backfill", (x0 + x1) / 2, (y0 + top - 2) / 2, (z0 + z1) / 2, x1 - x0, top - 2 - y0, z1 - z0)
    P("Snow", (x0 + x1) / 2, top - 1.2, (z0 + z1) / 2, x1 - x0 + 0.1, 2, z1 - z0 + 0.1)


for name, X, roomName, hole, locked in TUNNELS:
    r = room(roomName)
    y0 = r[2]
    edge = 5 * math.ceil((y0 - 2.5) / 5)        # 굴 방 맨 북쪽 칸의 북쪽 변(그림)
    xc, zend = world(X, edge)
    hx = SG.HOLES[hole]
    top = SG.zone_at((hx[0] + hx[1]) / 2, (hx[2] + hx[3]) / 2, G)
    S = top - 0.2                                 # 걷는 땅 높이
    R = 2 * (S - FLOOR)
    zl = zend - LANDING
    zp = zl - R
    zwall = zend - WALL_CELL                      # 벽 북쪽 면

    def floor_at(z):
        return S - (z - zp) / 2 if z < zl else FLOOR

    # 길 위 땅 높이가 한결같은지(도랑·입구 언덕 자리)
    for z in [zp - 30 + k * 4 for k in range(int((zl - zp + 30) // 4))]:
        for dx in (-12, 0, 12):
            Xp, Yp = (xc + dx - (world(0, 0)[0])) / SCALE, (z - world(0, 0)[1]) / SCALE
            t = SG.zone_at(Xp, Yp, G)
            if t != top and floor_at(z) + HV + 3.4 > LAND_BOTTOM:
                bad.append(f"{name}: z {z:.0f} 땅 {t} (입구 {top})")
                break
    # 굴 밑 끝 벽이 정말 벽인지(지하 자료)
    uparts = U.build()[0]
    if not any(k == "Wall" and a <= xc <= b and c <= zwall + 9 <= d for k, a, b, c, d, *_ in uparts):
        bad.append(f"{name}: 굴 방 북쪽 벽을 못 찾음 (x {xc:.0f}, z {zwall + 9:.0f})")
    # 바위 무리·오르막과 겹침
    for _, (a, b, c, d), lo, tp, _c in SG.main()[4]:
        if a < xc + 30 and b > xc - 30 and c < zp + 50 and d > zp - 10:
            bad.append(f"{name}: 입구가 단 사이 바위 무리와 겹침")

    # ── 기울어진 몸 ──
    L = R / CO
    mz, my = (zp + zl) / 2, (S + FLOOR) / 2
    deg = math.degrees(TH)

    def slope(h, lz=0.0):
        """기울어진 몸 좌표(옆 0, 몸에 수직 h, 몸 따라 lz — 가운데 기준) → (y, z)."""
        return my + h * CO - lz * SI, mz + h * SI + lz * CO

    y, z = slope(HC + 1.5)
    P("Ceil", xc, y, z, W + 2 * T, 3, L + 4, deg)
    y, z = slope((HC - 1) / 2)
    for s in (-1, 1):
        P("Wall", xc + s * (W / 2 + T / 2), y, z, T, HC + 7, L + 4, deg)
    y, z = slope(-3.05)
    P("Under", xc, y, z, W, 2.9, L, deg)
    n = int(round(S - FLOOR))
    step = R / n
    for k in range(n):
        tz0, tz1 = zp + k * step, zp + (k + 1) * step
        tt = S - (k + 1) * step / 2
        P("Step" if k % 2 == 0 else "Step2", xc, tt - 1, (tz0 + tz1) / 2, W, 2, tz1 - tz0)
    # 갱목 틀: 12 마다(몸 따라), 세 틀마다 등잔
    k = 0
    for lz in [-L / 2 + 6 + 12 * i for i in range(int((L - 10) // 12))]:
        for s in (-1, 1):
            y, z = slope(HC / 2, lz)
            P("Timber", xc + s * (W / 2 - 0.6), y, z, 1.2, HC, 1.2, deg)
        y, z = slope(HC - 0.7, lz)
        P("Timber", xc, y, z, W, 1.2, 1.4, deg)
        if k % 3 == 1:
            y, z = slope(9.5, lz + 1.4)
            lamps.append((xc - W / 2 + 1.3, y, z, deg))
        k += 1
    # ── 바닥 -70 평지(벽 북쪽 면까지 — 벽 안은 판 벽이 굴 몸) ──
    a, b = zl - 2, zwall
    P("Floor", xc, FLOOR - 1.5, (a + b) / 2, W, 3, b - a)
    P("Ceil", xc, FLOOR + HV + 1.5, (a + b) / 2, W + 2 * T, 3, b - a)
    for s in (-1, 1):
        P("Wall", xc + s * (W / 2 + T / 2), FLOOR + HV / 2, (a + b) / 2, T, HV + 6, b - a)
    for zz in (zl + 4, zwall - 1):
        for s in (-1, 1):
            P("Timber", xc + s * (W / 2 - 0.6), FLOOR + (HV - 0.7) / 2, zz, 1.2, HV - 0.7, 1.2)
        P("Timber", xc, FLOOR + HV - 0.7, zz, W, 1.2, 1.4)
    lamps.append((xc - W / 2 + 1.3, FLOOR + 9.5, zl + 5.4, 0.0))
    carve_under.append((xc - W / 2, xc + W / 2, FLOOR, FLOOR + HV, zwall - 0.5, zend + 0.5))
    # ── 도랑(땅 빼기)과 다시 덮기 ──
    send = 2 * (S + 19.4 - LAND_BOTTOM)          # 천장 윗면이 땅 밑(-24)보다 위인 동안
    carve_land.append((xc - 10, xc + 10, LAND_BOTTOM - 0.5, top + 1, zp, zp + send + 2))
    za = zp + 38
    while za < zp + send:
        zb = min(za + 6, zp + send + 2)
        bottom = floor_at(za) + HV + 3.4
        if bottom < top - 2.4:
            land_block(xc - 10, xc + 10, za, zb, max(bottom, LAND_BOTTOM), top)
        za = zb
    air.append((xc - 11, xc + 11, FLOOR - 6, top + 4, zp - 2, zwall))
    # ── 입구 바위 언덕 · 갱목 문틀 · 등잔 ──
    for lx0, lx1, lz0, lz1, ly0, ly1, ry, tone in PORTAL_ROCKS:
        for lx in (lx0 + 0.01, lx1 - 0.01):
            for lz in (lz0 + 0.01, lz1 - 0.01):
                if abs(lx) < W / 2 and lz > -0.5 and ly0 < HV - lz / 2:
                    bad.append(f"{name}: 입구 바위 ({lx0},{lz0}) 가 굴 안을 침범")
        cx, cz = xc + (lx0 + lx1) / 2, zp + (lz0 + lz1) / 2
        P("Rock" if tone == 1 else "Rock2", cx, S + (ly0 + ly1) / 2, cz, lx1 - lx0, ly1 - ly0, lz1 - lz0, 0, ry)
        P("RockSnow", cx, S + ly1 + 0.3, cz, lx1 - lx0 + 0.4, 1.0, lz1 - lz0 + 0.4, 0, ry)
    for s in (-1, 1):
        P("Timber", xc + s * (W / 2 - 0.7), S + 7.6, zp - 0.6, 1.4, 15.6, 1.4)
    P("Timber", xc, S + 15.9, zp - 0.6, W + 1.6, 1.4, 1.6)
    for s in (-1, 1):
        lamps.append((xc + s * (W / 2 + 2.2), S + 10, zp - 2.4, 0.0))
    if locked:
        bars = []
        for i in range(9):
            bx = xc - 6.4 + i * 1.6
            bars.append(("Bar", bx, S + 6.2, zp + 1.0, 0.5, 15.4, 0.5))
        for yy in (S + 1.2, S + 7.5, S + 13.6):
            bars.append(("Bar", xc, yy, zp + 1.0, W - 0.2, 0.5, 0.6))
        gates.append((name, bars))
    spots.append((name, xc, S + 0.5, zp - 16, xc, zp))
    caps.append((hole, *world(hx[0], hx[2]), *world(hx[1], hx[3]), top))
    print(f"{name}: 입구 z {zp:.0f} (땅 {S:.1f}) → 평지 z {zl:.0f} → 굴 방 z {zend:.0f} · 길이 {R + LANDING:.0f} · 계단 {n} · 도랑 {send:.0f}")

# 옛 구멍 메우기(땅 규칙) — 지하 천장도 그 자리만 막는다
for hole, x0, z0, x1, z1, top in caps:
    land_block(x0, x1, z0, z1, LAND_BOTTOM, top)
    P("CaveCeil", (x0 + x1) / 2, -33, (z0 + z1) / 2, x1 - x0, 6, z1 - z0)


if __name__ == "__main__":
    for p in bad:
        print("문제:", p)

    def row(t):
        return "\t{ " + ", ".join(f'"{v}"' if isinstance(v, str) else f"{v:.2f}" for v in t) + " },"

    out = ["-- snow_tunnel_plan.py 가 만든 자료(손으로 고치지 말 것)", "local PARTS = {"]
    out += [row(p) for p in parts]
    out += ["}", "local CARVE_LAND = {"] + [row(c) for c in carve_land]
    out += ["}", "local CARVE_UNDER = {"] + [row(c) for c in carve_under]
    out += ["}", "local AIR = {"] + [row(c) for c in air]
    out += ["}", "local LAMPS = {"] + [row(l) for l in lamps]
    out += ["}", "local SPOTS = {"] + [row(s) for s in spots]
    out += ["}", "local SHAFTS = {"] + [f'\t"{c[0]}",' for c in caps]
    out += ["}", "local GATES = {"]
    for gname, bars in gates:
        out.append(f'\t{{ "{gname}", {{')
        out += ["\t" + row(b) for b in bars]
        out.append("\t} },")
    out += ["}"]
    open(os.path.join(HERE, "Snow_Tunnels_data.luau"), "w", encoding="utf-8", newline="\n").write("\n".join(out) + "\n")
    print(f"파트 {len(parts)} · 등잔 {len(lamps)} · 땅 빼기 {len(carve_land)} · 지하 빼기 {len(carve_under)} · 문제 {len(bad)}건")
