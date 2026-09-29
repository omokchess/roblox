# -*- coding: utf-8 -*-
"""
build_roman.py — 칼로도르 폴리스(화산섬 로마풍 제국 도시)의 건물·석상·소품. (2026-09-28)

설정(사용자 글): 유일한 황제(임페라토)가 다스리는 제국, 거인들의 옛땅. 제국이 무너지고 세워지기를
되풀이해 유물이 많다. 예술·기술이 로마 시대에 머물러 있다. 컨셉 = 로마 · 거인 · 석상.
거인은 이그너스가 죽은 생물로 빚었고, 땅을 밟아 문명을 세우고 또 밟아 무너뜨렸다.
모두 죽고 하나(문명 멸전의 거인)만 봉인되어 남았다. 길드 파빌라키니스(실리아→밀레우스·임모로우→트리부누스→레가투스),
레가투스는 불로 엮은 글라디우스를 받는다.

단위 스터드(캐릭터 키 5), 원점 = 바닥 가운데(원형 투기장 4분의 1은 원의 중심), 앞 = -y.
표지: Vent(김·불꽃 — Studio 에서 투명 + 입자), LampPt(점광원).

돌리는 법: blender --background --python build_roman.py [-- 이름 ...]   (미리보기 PNG 가 models/<이름>/ 에)
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import hanok_lib as L  # noqa: E402
import roman_lib as R  # noqa: E402
from roman_lib import G, PALETTE, TAU  # noqa: E402

col = R.column


# ================================================================ 신전

def temple_ignus(g):
    """이그너스 신전. 포디움 5, 코린트 기둥 8 x 3줄 현관, 벽에 붙은 반기둥, 박공에 금빛 해 원반."""
    PH = 5.0
    R.podium(g, 0, 6, 48, 72, PH, mat="MarbleWall")                     # y -30..42
    R.stairs(g, 0, -30, PH, 36, 10, tread=1.4, mat="Marble")
    for s in (-1, 1):                                  # 계단 옆 볼(cheek)
        g["MarbleDark"].box(s * 19.5, -37, PH / 2, 3, 14, PH)
    top = PH + 30
    xs = [-21, -15, -9, -3, 3, 9, 15, 21]
    R.colonnade(g, xs, [-27, -21], PH, 30, 2.1, "corinthian", "Marble", flutes=True)
    R.colonnade(g, [-21, 21], [-15], PH, 30, 2.1, "corinthian", "Marble", flutes=True)
    # 셀라: y -12..40, 벽 두께 3
    g["MarbleWall"].box(0, 40.5, PH + 15, 42, 3, 30)
    for s in (-1, 1):
        g["MarbleWall"].box(s * 19.5, 14, PH + 15, 3, 55, 30)
        for yy in (-6, 1, 8, 15, 22, 29, 36):          # 벽에 붙은 반기둥
            col(g, s * 21, yy, PH, 30, 1.7, "corinthian", "MarbleWall")
    R.wall_with_openings(g, -18, 18, -12, PH, 30, 3, [(0, 9, 0, 17)], mat="MarbleWall", glow="Glow", frame="Gold")
    g["Bronze"].box(-2.3, -13.2, PH + 8.5, 4.2, 0.5, 17)   # 청동 문짝(반쯤 열림)
    g["Bronze"].obox(3.2, -14.5, PH + 8.5, 4.2, 0.5, 17, rz=0.9)
    g["LampPt"].box(0, -9, PH + 6, 1, 1, 1)
    R.entablature(g, -24, 24, -30, 42, top, 5, "MarbleWall", frieze="MarbleDark")
    R.pediment(g, 0, -30, 42, top + 5, 47, 11, "MarbleWall", tympanum="MarbleDark")
    R.gable_roof(g, 0, 6, top + 5, 47, 72, 11, along="y", over=1.0, mat="Tile")
    g["Gold"].hcyl(0, -30.4, top + 9.3, 2.6, 0.5, axis="y", seg=20)            # 해 원반
    for k in range(12):
        a = TAU * k / 12
        g["Gold"].obox(3.6 * math.cos(a), -30.5, top + 9.3 + 3.6 * math.sin(a), 1.6, 0.3, 0.35, ry=-a)
    for sx in (-23.5, 23.5):                                                     # 모서리 장식(아크로테리온)
        g["Gold"].box(sx, -30, top + 6.2, 1.6, 1.6, 2.4)
    g["Gold"].cyl(0, -30, top + 16, 1.0, 0.2, 3.0, seg=10)


def temple_small(g):
    """작은 신전(4주 전주식). 이오니아 기둥."""
    PH = 3.0
    R.podium(g, 0, 5, 20, 32, PH)                      # y -11..21
    R.stairs(g, 0, -11, PH, 14, 6, tread=1.3)
    xs = [-7.5, -2.5, 2.5, 7.5]
    R.colonnade(g, xs, [-9.2, -4.4], PH, 16, 1.25, "ionic", "Marble")
    g["Marble"].box(0, 20, PH + 8, 18, 1.8, 16)
    for s in (-1, 1):
        g["Marble"].box(s * 8.1, 9, PH + 8, 1.8, 24, 16)
    R.wall_with_openings(g, -9, 9, -2.2, PH, 16, 1.8, [(0, 5, 0, 10)], mat="Marble", glow="Glow")
    R.entablature(g, -10, 10, -11, 21, PH + 16, 2.6, "Marble")
    R.pediment(g, 0, -11, 21, PH + 18.6, 20.5, 5.2, "Marble", tympanum="MarbleDark")
    R.gable_roof(g, 0, 5, PH + 18.6, 20.5, 32, 5.2, along="y", over=0.6)
    g["LampPt"].box(0, 1, PH + 4, 0.6, 0.6, 0.6)


# ================================================================ 공공건물

def basilica(g):
    """바실리카(재판·상거래 홀). 가로 90 x 깊이 44. 신랑 30, 측랑 18, 앞 주랑."""
    base = 1.5
    g["BasaltLight"].box(0, 0, base / 2, 94, 50, base)
    # 측랑 바깥벽(벽돌 + 창)
    wins = [(x, 4.5, 7, 14) for x in range(-39, 40, 13)]
    for y in (-22, 22):
        R.wall_with_openings(g, -45, 45, y, base, 18, 1.8, wins if y > 0 else [(x, 4.5, 0, 14) if abs(x) < 7 else (x, 4.5, 7, 14) for x in range(-39, 40, 13)],
                             mat="Brick", glow="Glow", frame="Travertine")
    for x in (-45, 45):
        R.wall_with_openings(g, -22, 22, x, base, 18, 1.8, [(0, 6, 6, 14)], mat="Brick", axis="y", glow="Glow", frame="Travertine")
    # 신랑 높은 벽(클리어스토리)
    for y in (-9, 9):
        R.wall_with_openings(g, -45, 45, y, base + 18, 12, 1.4, [(x, 3.5, 3, 9) for x in range(-39, 40, 9)],
                             mat="Plaster", glow="Glow")
    for x in (-45, 45):
        g["Plaster"].box(x, 0, base + 24, 1.4, 18, 12)
    # 지붕: 측랑은 외쪽 경사, 신랑은 박공
    for s in (-1, 1):
        g["Tile"].obox(0, s * 15.5, base + 18 + 1.6, 94, 15.2, 0.8, rx=-s * 0.2)
    R.gable_roof(g, 0, 0, base + 30, 92, 18.4, 5.5, along="x", over=1.2, end_mat="Plaster")
    g["Travertine"].box(0, 0, base + 18.2, 92, 45, 0.6)       # 처마 띠
    # 앞 주랑(-y): 투스칸 기둥 10
    xs = [-36 + 8 * i for i in range(10)]
    R.colonnade(g, xs, [-27.5], base, 14, 1.25, "tuscan", "Travertine")
    R.entablature(g, -38, 38, -29, -22.5, base + 14, 2.6, "Travertine")
    g["Tile"].obox(0, -25.5, base + 17.6, 78, 8, 0.7, rx=0.18)
    R.stairs(g, 0, -29, base, 60, 2, tread=1.3, mat="BasaltLight")
    g["LampPt"].box(0, 0, base + 10, 1, 1, 1)
    g["LampPt"].box(-30, 0, base + 10, 1, 1, 1)
    g["LampPt"].box(30, 0, base + 10, 1, 1, 1)


def thermae(g):
    """목욕장. 벽돌 몸체, 가운데 뒤 칼다리움 큰 돔, 양옆 작은 돔, 앞 프리기다리움 궁륭, 김 나는 곳 셋."""
    W, D, H = 64.0, 56.0, 16.0
    g["BasaltLight"].box(0, 0, 0.6, W + 4, D + 4, 1.2)
    z0 = 1.2
    arches = [(x, 6, 4, 13) for x in (-24, -12, 12, 24)]
    R.wall_with_openings(g, -W / 2, W / 2, -D / 2, z0, H, 2, arches + [(0, 8, 0, 11)], mat="Brick", glow="Glow",
                         frame="Travertine")
    R.wall_with_openings(g, -W / 2, W / 2, D / 2, z0, H, 2, [(x, 5, 5, 12) for x in (-20, -8, 8, 20)], mat="Brick",
                         glow="Glow", frame="Travertine")
    for x in (-W / 2, W / 2):
        R.wall_with_openings(g, -D / 2, D / 2, x, z0, H, 2, [(y, 5, 5, 12) for y in (-16, 0, 16)], mat="Brick",
                             axis="y", glow="Glow", frame="Travertine")
    g["Travertine"].box(0, 0, z0 + H + 0.4, W + 1.2, D + 1.2, 0.8)       # 코니스
    g["Brick"].box(0, 0, z0 + H + 1.2, W - 2, D - 2, 0.8)               # 평지붕
    # 칼다리움(뒤 가운데) 큰 돔
    top = R.dome(g, 0, 10, z0 + H + 1.6, 13, mat="Plaster", drum=4, drum_mat="Brick", rings=10, seg=28)
    g["Gold"].cyl(0, 10, top, 1.2, 0.3, 1.6, seg=10)
    for sx in (-20, 20):                                                    # 테피다리움 작은 돔
        R.dome(g, sx, 10, z0 + H + 1.6, 7.5, mat="Plaster", drum=2.5, drum_mat="Brick", rings=8, seg=20)
    # 프리기다리움: 앞쪽 궁륭(반원통 지붕을 x 로)
    for k in range(10):
        a0, a1 = math.pi * k / 10, math.pi * (k + 1) / 10
        am = (a0 + a1) / 2
        rr = 9.0
        g["Tile"].obox(0, -12 + rr * math.cos(am), z0 + H + 1.6 + rr * math.sin(am), 40,
                       2 * rr * math.sin((a1 - a0) / 2) + 0.1, 0.8, rx=am - math.pi / 2)
    for x in (-20, 20):
        R.prism(g["Brick"], [(-12 - 9, z0 + H + 1.6), (-12 + 9, z0 + H + 1.6), (-12, z0 + H + 10.6)], x - 0.8, x + 0.8, axis="x")
    # 앞 현관: 기둥 6 + 박공
    xs = [-12.5, -7.5, -2.5, 2.5, 7.5, 12.5]
    R.colonnade(g, xs, [-D / 2 - 5], z0, 12, 1.1, "doric", "Travertine")
    R.entablature(g, -15, 15, -D / 2 - 7, -D / 2, z0 + 12, 2.2, "Travertine")
    R.pediment(g, 0, -D / 2 - 7, -D / 2, z0 + 14.2, 30.5, 5, "Travertine", tympanum="Plaster")
    R.gable_roof(g, 0, -D / 2 - 3.5, z0 + 14.2, 30.5, 7, 5, along="y", over=0.4)
    R.stairs(g, 0, -D / 2 - 7, z0, 30, 2, tread=1.2, mat="BasaltLight")
    for (vx, vy, vz) in ((0, 10, top + 1.6), (-20, 10, z0 + H + 12), (20, 10, z0 + H + 12)):
        g["Vent"].box(vx, vy, vz, 1, 1, 1)
    for x in (-18, 0, 18):
        g["LampPt"].box(x, -4, z0 + 8, 1, 1, 1)


def amph_quarter(g):
    """
    원형 투기장 4분의 1(0°→90°, +x +y 사분면). 원점은 원의 중심. 네 개를 90° 씩 돌려 한 바퀴.
    바깥 반지름 66, 아케이드 3층(층 12) + 아틱 5. 투기장 반지름 30, 관람석 계단 8단.
    """
    RO, RW = 66.0, 4.0            # 바깥 반지름, 바깥벽 두께
    NB = 10                       # 이 사분면의 칸 수
    tiers = [(0.0, 12.0, 7.0, "tuscan"), (12.0, 12.0, 7.0, "ionic"), (24.0, 12.0, 7.0, "corinthian")]
    dA = (math.pi / 2) / NB
    rc = RO - RW / 2
    span = 2 * rc * math.sin(dA / 2) - 3.2            # 기둥 사이 안쪽 폭
    for b in range(NB):
        am = dA * (b + 0.5)
        ap = dA * b
        cx, cy = rc * math.cos(am), rc * math.sin(am)
        for (z0, h, spring, order) in tiers:
            # 이 칸의 아치 벽: 로컬 x = 원 둘레 방향, 로컬 y = 반지름 방향. 제자리에서 짓고 돌려 옮긴다
            def bay(tg, z0=z0, h=h, spring=spring):
                R.arch_wall(tg, 0, 0, z0, span + 0.05, h, RW, span, spring, mat="Travertine", arch_mat="MarbleDark")
                g_ = tg
                g_["Travertine"].box(0, -RW / 2 - 0.3, z0 + h - 0.6, span + 3.2, 0.6, 1.2)    # 층 띠
            m = R.Matrix.Translation((cx, cy, 0)) @ R.Matrix.Rotation(am - math.pi / 2, 4, "Z")
            L.transformed(g, m, bay)
            # 칸 사이 기둥(피어 + 붙임기둥)
            px, py = rc * math.cos(ap), rc * math.sin(ap)
            g["Travertine"].obox(px, py, z0 + h / 2, 3.2, RW, h, rz=ap - math.pi / 2)
            ex, ey = (RO + 0.5) * math.cos(ap), (RO + 0.5) * math.sin(ap)
            col(g, ex, ey, z0, h - 1.2, 0.8, order, "MarbleWall", base=False)
    # 마지막 피어(90°)
    for (z0, h, spring, order) in tiers:
        ap = math.pi / 2
        g["Travertine"].obox(rc * math.cos(ap), rc * math.sin(ap), z0 + h / 2, 3.2, RW, h, rz=ap - math.pi / 2)
    # 아틱(맨 위 막힌 층)과 돛대 받침
    R.ring_band(g["Travertine"], 0, 0, 36.0, RO - RW, RO + 0.6, 5.0, seg=NB * 2, a0=0, a1=math.pi / 2)
    R.ring_band(g["MarbleDark"], 0, 0, 40.6, RO - RW - 0.3, RO + 1.0, 0.6, seg=NB * 2, a0=0, a1=math.pi / 2)
    for b in range(0, NB + 1, 2):
        a = dA * b
        g["Wood"].box((RO - 1) * math.cos(a), (RO - 1) * math.sin(a), 44.5, 0.5, 0.5, 7)   # 차양 돛대
    # 관람석: 투기장 벽(반지름 30~31.5, 높이 4.5)부터 바깥벽 안쪽(62)까지 8단
    R.ring_band(g["Marble"], 0, 0, 0.0, 30.0, 31.5, 4.5, seg=NB * 2, a0=0, a1=math.pi / 2)
    steps = 8
    for i in range(steps):
        r0 = 31.5 + i * (RO - RW - 31.5) / steps
        zt = 4.5 + (i + 1) * (33.0 - 4.5) / steps
        R.ring_band(g["Travertine" if i % 2 == 0 else "MarbleDark"], 0, 0, 0.0, r0, RO - RW + 0.1, zt,
                    seg=NB * 2, a0=0, a1=math.pi / 2)
    # 투기장 모래(사분면 부채꼴)
    R.ring_band(g["Sand"], 0, 0, 0.0, 0.0, 30.05, 0.6, seg=NB * 2, a0=0, a1=math.pi / 2)
    g["LampPt"].box(40, 40, 36, 1, 1, 1)


# ================================================================ 집

def domus(g):
    """귀족 저택(도무스). 앞 가게 둘 + 현관, 아트리움(가운데 못), 뒤 페리스틸리움 정원."""
    W, D, H = 36.0, 48.0, 11.0
    x0, x1, y0, y1 = -W / 2, W / 2, -D / 2, D / 2
    g["BasaltLight"].box(0, 0, 0.4, W + 1, D + 1, 0.8)
    z0 = 0.8
    # 바깥벽: 아래 붉은 띠(높이 3) + 흰 회벽
    front = [(-11, 7, 0, 8.5), (11, 7, 0, 8.5), (0, 4.2, 0, 8.8)]
    R.wall_with_openings(g, x0, x1, y0, z0, 3, 1.4, [(c, w, lo, min(hi, 3)) for c, w, lo, hi in front], mat="PlasterRed",
                         glow="Glow")
    R.wall_with_openings(g, x0, x1, y0, z0 + 3, H - 3, 1.4, [(c, w, 0, hi - 3) for c, w, lo, hi in front], mat="Plaster")
    g["Wood"].box(-2.1, y0 - 0.1, z0 + 4.4, 2.0, 0.4, 8.8)      # 문짝
    g["Wood"].box(2.1, y0 - 0.1, z0 + 4.4, 2.0, 0.4, 8.8)
    for s in (-1, 1):                                            # 가게 차양
        g["Fabric"].obox(s * 11, y0 - 2.2, z0 + 9.2, 8, 4.4, 0.25, rx=0.35)
        g["Terracotta"].cyl(s * 11 + 2.5, y0 - 1.2, z0, 0.7, 0.4, 2.2, seg=10)
    for y in (y1,):
        R.wall_with_openings(g, x0, x1, y, z0, H, 1.4, [(-8, 2, 6, 8.5), (8, 2, 6, 8.5)], mat="Plaster")
    for x in (x0, x1):
        R.wall_with_openings(g, y0, y1, x, z0, H, 1.4, [(yy, 2, 6.5, 8.5) for yy in (-14, -2, 12)], mat="Plaster",
                             axis="y")
        g["PlasterRed"].box(x, 0, z0 + 1.5, 1.5, D, 3.0)
    # 앞채(y -24..-12) 박공, 뒤채(y 18..24) 박공
    R.gable_roof(g, 0, -18, z0 + H, W, 12, 3.6, along="x", over=0.9)
    R.gable_roof(g, 0, 21, z0 + H, W, 6, 2.4, along="x", over=0.9)
    # 아트리움(y -12..4): 양옆 방 위 외쪽 지붕이 안으로 기운다 + 가운데 못
    # 콤플루비움: 가운데 구멍(8 x 6)을 두고 네 판이 안으로 기운다. 바깥 옆방(x ±13..18)은 밖으로 기운다
    for s in (-1, 1):
        g["Tile"].obox(s * 8.5, -4, z0 + H + 1.2, 9.6, 16.4, 0.6, ry=-s * 0.3)
        g["Tile"].obox(s * 15.6, -4, z0 + H + 0.9, 5.8, 16.4, 0.6, ry=s * 0.22)
    g["Tile"].obox(0, -9.6, z0 + H + 1.0, 8.4, 5.2, 0.6, rx=-0.32)
    g["Tile"].obox(0, 1.6, z0 + H + 1.0, 8.4, 5.2, 0.6, rx=0.32)
    g["Marble"].box(0, -4, z0 + 0.25, 7, 5, 0.5)
    g["HotWater"].box(0, -4, z0 + 0.52, 6, 4, 0.1)
    g["Plaster"].box(-13, -4, z0 + H / 2, 1.0, 16, H)      # 아트리움 옆방 칸막이
    g["Plaster"].box(13, -4, z0 + H / 2, 1.0, 16, H)
    # 페리스틸리움(y 4..18): 정원 둘레 기둥 + 처마
    g["Garden"].box(0, 11, z0 + 0.2, 22, 11, 0.4)
    xs = [-12, -6, 0, 6, 12]
    for x in xs:
        for y in (5.0, 17.0):
            col(g, x, y, z0, 8, 0.6, "tuscan", "Plaster", base=False)
    for y in (8.0, 11.0, 14.0):
        for x in (-12, 12):
            col(g, x, y, z0, 8, 0.6, "tuscan", "Plaster", base=False)
    for s in (-1, 1):
        g["Tile"].obox(s * 15, 11, z0 + 9, 6.5, 14, 0.6, ry=-s * 0.25)
        g["Tile"].obox(0, 11 + s * 8.6, z0 + 9, 30, 5, 0.6, rx=s * 0.25)
    g["Marble"].cyl(0, 11, z0 + 0.4, 1.6, 1.4, 0.8, seg=14)     # 정원 분수
    g["HotWater"].cyl(0, 11, z0 + 1.2, 1.3, 1.3, 0.05, seg=14)
    g["LampPt"].box(0, -10, z0 + 7, 0.6, 0.6, 0.6)


def insula_a(g):
    """인술라(평민 공동주택) 가. 30x30, 3층. 1층 벽돌 가게 아치, 위층 황토 회벽 창, 앞 나무 발코니."""
    W, D, FH = 30.0, 30.0, 12.0
    z = 0.0
    shops = [(x, 5, 0, 8) for x in (-9, 0, 9)]
    R.wall_with_openings(g, -W / 2, W / 2, -D / 2, z, FH, 1.6, shops, mat="Brick", glow="Glow", frame="Travertine")
    R.wall_with_openings(g, -D / 2, D / 2, -W / 2, z, FH, 1.6, [(y, 5, 0, 8) for y in (-8, 4)], mat="Brick", axis="y",
                         glow="Glow", frame="Travertine")
    R.wall_with_openings(g, -D / 2, D / 2, W / 2, z, FH, 1.6, [(0, 4, 0, 8.5)], mat="Brick", axis="y", glow="Glow")
    g["Brick"].box(0, D / 2, FH / 2, W, 1.6, FH)
    wins = [(x, 2.6, 4, 8) for x in (-10, -3.5, 3.5, 10)]
    for f, mat in ((1, "PlasterOchre"), (2, "PlasterOchre")):
        zf = f * FH
        for y in (-D / 2, D / 2):
            R.wall_with_openings(g, -W / 2, W / 2, y, zf, FH, 1.6, wins, mat=mat, glow="Glow", frame="Travertine")
        for x in (-W / 2, W / 2):
            R.wall_with_openings(g, -D / 2, D / 2, x, zf, FH, 1.6, wins, mat=mat, axis="y", glow="Glow",
                                 frame="Travertine")
        g["Travertine"].box(0, 0, zf, W + 0.8, D + 0.8, 0.6)             # 층 띠
    # 발코니(2층 앞): 까치발 + 마루 + 난간
    zb = FH + 0.3
    g["Wood"].box(0, -D / 2 - 1.8, zb, W - 2, 3.6, 0.5)
    for x in range(-13, 14, 4):
        g["Wood"].obox(x, -D / 2 - 1.1, zb - 1.2, 0.4, 2.6, 0.4, rx=0.6)
        g["Wood"].box(x, -D / 2 - 3.4, zb + 1.8, 0.3, 0.3, 3.2)
    g["Wood"].box(0, -D / 2 - 3.4, zb + 3.3, W - 2, 0.3, 0.3)
    g["Wood"].box(0, -D / 2 - 3.4, zb + 1.8, W - 2, 0.2, 0.2)
    R.hip_roof(g, 0, 0, 3 * FH, W, D, 5.5, mat="Tile", over=1.2)
    for x in (-9, 0, 9):
        g["Fabric"].obox(x, -D / 2 - 1.8, 8.8, 5.4, 3.6, 0.2, rx=0.4)   # 가게 차양
    g["LampPt"].box(0, -D / 2 + 3, 5, 0.6, 0.6, 0.6)


def insula_b(g):
    """인술라 나. 24x44, 4층 좁고 높은 붉은 회벽 집. 1층 가게, 옥상 모임지붕."""
    W, D, FH = 24.0, 44.0, 11.0
    R.wall_with_openings(g, -W / 2, W / 2, -D / 2, 0, FH, 1.5, [(-6, 5, 0, 8), (6, 5, 0, 8)], mat="Brick", glow="Glow",
                         frame="Travertine")
    g["Brick"].box(0, D / 2, FH / 2, W, 1.5, FH)
    for x in (-W / 2, W / 2):
        R.wall_with_openings(g, -D / 2, D / 2, x, 0, FH, 1.5, [(y, 4.5, 0, 8) for y in (-14, 0, 14)], mat="Brick",
                             axis="y", glow="Glow", frame="Travertine")
    for f in (1, 2, 3):
        zf = f * FH
        mat = "PlasterRed" if f < 3 else "PlasterOchre"
        for y in (-D / 2, D / 2):
            R.wall_with_openings(g, -W / 2, W / 2, y, zf, FH, 1.5, [(-6, 2.4, 4, 7.5), (6, 2.4, 4, 7.5)], mat=mat,
                                 glow="Glow", frame="Travertine")
        for x in (-W / 2, W / 2):
            R.wall_with_openings(g, -D / 2, D / 2, x, zf, FH, 1.5, [(y, 2.4, 4, 7.5) for y in (-16, -8, 0, 8, 16)],
                                 mat=mat, axis="y", glow="Glow", frame="Travertine")
        g["Travertine"].box(0, 0, zf, W + 0.7, D + 0.7, 0.5)
    # 옆 나무 발코니(3층 오른쪽)
    zb = 2 * FH + 0.3
    g["Wood"].box(W / 2 + 1.6, 0, zb, 3.2, D - 8, 0.5)
    for y in range(-17, 18, 5):
        g["Wood"].box(W / 2 + 3.0, y, zb + 1.7, 0.3, 0.3, 3.0)
    g["Wood"].box(W / 2 + 3.0, 0, zb + 3.1, 0.3, D - 8, 0.3)
    R.hip_roof(g, 0, 0, 4 * FH, W, D, 5.0, mat="Tile", over=1.0)
    for x in (-6, 6):
        g["Fabric"].obox(x, -D / 2 - 1.7, 8.7, 5.2, 3.4, 0.2, rx=0.4)
    g["LampPt"].box(0, -D / 2 + 3, 5, 0.6, 0.6, 0.6)


def taberna_row(g):
    """가게 줄(주랑 딸린 단층 가게 넷). 36 x 10."""
    W, D, H = 36.0, 10.0, 9.0
    shops = [(x, 6, 0, 7) for x in (-13.5, -4.5, 4.5, 13.5)]
    R.wall_with_openings(g, -W / 2, W / 2, -D / 2 + 3, 0, H, 1.2, shops, mat="PlasterOchre", glow="Glow",
                         frame="Travertine")
    g["PlasterOchre"].box(0, D / 2, H / 2, W, 1.2, H)
    for x in (-W / 2, W / 2):
        g["PlasterOchre"].box(x, 1.5, H / 2, 1.2, D - 3, H)
    for x in (-9, 0, 9):
        g["PlasterOchre"].box(x, 1.5, H / 2, 0.8, D - 3, H)
    for x in (-17, -8.5, 0, 8.5, 17):
        col(g, x, -D / 2 - 0.5, 0, 7.5, 0.55, "tuscan", "Travertine", base=False)
    g["Travertine"].box(0, -D / 2 - 0.5, 8.0, W + 1, 1.4, 1.0)
    R.gable_roof(g, 0, -0.5, H, W + 2, D + 3, 2.6, along="x", over=0.6)
    for x in (-13.5, 4.5):
        g["Terracotta"].cyl(x + 2, -D / 2 + 2, 0, 0.6, 0.35, 2.0, seg=10)
    g["LampPt"].box(0, -1, 5, 0.6, 0.6, 0.6)


# ================================================================ 궁·군단

def palatium(g):
    """황궁(팔라티움). 포디움 8 위 코린트 주랑 12, 가운데 박공, 뒤 옥좌의 돔, 양 날개채, 반암 띠."""
    PH = 8.0
    g["Basalt"].box(0, 4, PH / 2, 116, 70, PH)                 # 포디움 y -31..39
    g["Porphyry"].box(0, 4, PH - 0.6, 117, 71, 1.2)
    R.stairs(g, 0, -31, PH, 44, 14, tread=1.3, mat="Marble", z_bottom=0.0)
    for s in (-1, 1):
        g["Porphyry"].box(s * 23.5, -40, PH / 2 + 0.5, 3, 18, PH + 1)
        R.figure(g, "Bronze", s=0.95, x=s * 23.5, y=-45, z=PH + 1, face=-1, robe="Bronze", arm_raise=0.3)  # 계단 옆 석상
    xs = [-44 + 8 * i for i in range(12)]
    R.colonnade(g, xs, [-27], PH, 26, 2.3, "corinthian", "Marble", cap="Gold", flutes=True)
    # 본채: y -22..30, 높이 30
    top = PH + 30
    g["MarbleWall"].box(0, 30, PH + 15, 96, 2.4, 30)
    for s in (-1, 1):
        g["MarbleWall"].box(s * 47, 4, PH + 15, 2.4, 52, 30)
    wins = [(x, 5, 3, 16) for x in (-38, -26, -14, 14, 26, 38)] + [(0, 12, 0, 20)]
    R.wall_with_openings(g, -48, 48, -22, PH, 30, 2.4, wins, mat="MarbleWall", glow="Glow", frame="Gold")
    g["Porphyry"].box(0, -22, PH + 2, 96.5, 2.6, 4)          # 반암 허리띠
    g["Bronze"].box(-3.2, -23.4, PH + 10, 6, 0.5, 20)
    g["Bronze"].box(3.2, -23.4, PH + 10, 6, 0.5, 20)
    R.entablature(g, -48, 48, -29, 30, PH + 26, 4, "MarbleWall", frieze="Porphyry")
    g["MarbleWall"].box(0, 4, PH + 30 + 1, 94, 52, 2)            # 평지붕
    R.pediment(g, 0, -29, -20, PH + 30, 38, 9, "Marble", tympanum="Porphyry")
    R.gable_roof(g, 0, -24.5, PH + 30, 38, 9.4, 9, along="y", over=0.4)
    g["Gold"].hcyl(0, -29.4, PH + 33.5, 2.4, 0.5, axis="y", seg=20)
    # 옥좌의 돔(가운데 뒤)
    dtop = R.dome(g, 0, 10, PH + 32, 15, mat="Marble", drum=6, drum_mat="Porphyry", rings=11, seg=30)
    g["Gold"].cyl(0, 10, dtop, 2.0, 0.4, 3, seg=12)
    for k in range(12):                                       # 돔 받침 둘레 창
        a = TAU * k / 12
        g["Glow"].obox(15.5 * math.cos(a), 10 + 15.5 * math.sin(a), PH + 35, 2.2, 0.4, 3.2, rz=a + math.pi / 2)
    # 날개채(x ±50..±58): 2층 박공
    for s in (-1, 1):
        cx = s * 54
        R.wall_with_openings(g, -20, 28, cx + s * 4, PH, 24, 2, [(y, 3, 4, 10) for y in (-12, 0, 12, 22)], mat="MarbleWall",
                             axis="y", glow="Glow", frame="Gold")
        g["MarbleWall"].box(cx, -20, PH + 12, 10, 2, 24)
        g["MarbleWall"].box(cx, 28, PH + 12, 10, 2, 24)
        R.gable_roof(g, cx, 4, PH + 24, 11, 50, 4.5, along="y", over=0.8, end_mat="MarbleWall")
    # 지붕 난간 석상
    for x in (-36, 36):
        g["Marble"].box(x, -21, PH + 32.5, 2.4, 2.4, 1.4)
        R.figure(g, "MarbleDark", s=0.6, x=x, y=-21, z=PH + 33.2, face=-1, robe="MarbleDark")
    g["LampPt"].box(0, 0, PH + 12, 1, 1, 1)
    g["LampPt"].box(-30, 0, PH + 12, 1, 1, 1)
    g["LampPt"].box(30, 0, PH + 12, 1, 1, 1)


def principia(g):
    """군단 본부(프린키피아). 네 채가 안뜰을 두르고, 앞 문루, 뒤 깃발 사당(아이데스). 안뜰에 불의 글라디우스를 세운다."""
    W, D, H = 50.0, 44.0, 11.0
    g["BasaltLight"].box(0, 0, 0.4, W + 2, D + 2, 0.8)
    z0 = 0.8
    ring = 8.0
    for y in (-D / 2, D / 2):
        R.wall_with_openings(g, -W / 2, W / 2, y, z0, H, 1.6,
                             [(0, 8, 0, 9)] if y < 0 else [(x, 2, 6, 8) for x in (-18, -9, 9, 18)],
                             mat="Plaster", glow="Glow", frame="Travertine")
    for x in (-W / 2, W / 2):
        R.wall_with_openings(g, -D / 2, D / 2, x, z0, H, 1.6, [(y, 2, 6, 8) for y in (-12, 0, 12)], mat="Plaster",
                             axis="y", glow="Glow")
    for s in (-1, 1):
        g["PlasterRed"].box(s * W / 2, 0, z0 + 1.2, 1.7, D, 2.4)
    # 안쪽 주랑(안뜰 x ±17, y -14..10)
    for x in (-17, -11, -5.5, 5.5, 11, 17):
        col(g, x, -14, z0, 8, 0.6, "tuscan", "Travertine", base=False)
        col(g, x, 10, z0, 8, 0.6, "tuscan", "Travertine", base=False)
    for y in (-8, -2, 4):
        col(g, -17, y, z0, 8, 0.6, "tuscan", "Travertine", base=False)
        col(g, 17, y, z0, 8, 0.6, "tuscan", "Travertine", base=False)
    # 지붕: 네 채(안쪽으로 기우는 외쪽 + 바깥 박공 느낌)
    R.gable_roof(g, 0, -D / 2 + ring / 2, z0 + H, W, ring, 2.8, along="x", over=0.8)
    R.gable_roof(g, 0, D / 2 - ring / 2 - 2, z0 + H, W, ring + 4, 3.2, along="x", over=0.8)
    for s in (-1, 1):
        R.gable_roof(g, s * (W / 2 - ring / 2), -2, z0 + H, ring, D - 2 * ring - 4, 2.8, along="y", over=0.2)
    g["BasaltLight"].box(0, -2, z0 + 0.15, 32, 22, 0.3)
    # 문루(앞)
    R.arch_wall(g, 0, -D / 2 - 1.5, z0, 16, 16, 4, 7, 7, mat="Travertine", key="Gold")
    for s in (-1, 1):
        g["Travertine"].box(s * 6, -D / 2 - 1.5, z0 + 17.5, 3.6, 4.4, 3)
    g["Fabric"].box(0, -D / 2 - 3.8, z0 + 12.5, 5, 0.2, 5)       # 군단 깃발
    g["Gold"].box(0, -D / 2 - 3.9, z0 + 12.5, 1.6, 0.25, 1.6)
    # 뒤 사당(아이데스): 계단 + 기둥 둘 + 박공
    R.stairs(g, 0, 12, z0 + 2, 10, 3, tread=1.0, mat="Marble", z_bottom=z0)
    g["Marble"].box(0, 16, z0 + 1, 12, 6, 2)
    for x in (-4, 4):
        col(g, x, 13.8, z0 + 2, 9, 0.7, "corinthian", "Marble")
    R.pediment(g, 0, 13, 20, z0 + 11, 12, 3.2, "Marble", tympanum="Porphyry")
    g["Glow"].box(0, 19, z0 + 6, 5, 0.3, 8)
    g["LampPt"].box(0, 16, z0 + 6, 0.6, 0.6, 0.6)


def barracks(g):
    """병영(콘투베르니움 줄). 60 x 12, 문 여덟, 앞 나무 처마."""
    W, D, H = 60.0, 12.0, 9.0
    g["BasaltLight"].box(0, 0, 0.3, W + 1, D + 5, 0.6)
    doors = [(x, 3.6, 0, 7.5) for x in range(-26, 27, 7)][:8]
    wins = [(x + 3.5, 1.6, 5, 7) for x in range(-26, 22, 7)]
    R.wall_with_openings(g, -W / 2, W / 2, -D / 2, 0.6, H, 1.2, doors + wins, mat="Plaster", glow="Glow")
    g["Plaster"].box(0, D / 2, 0.6 + H / 2, W, 1.2, H)
    for x in (-W / 2, W / 2):
        g["Plaster"].box(x, 0, 0.6 + H / 2, 1.2, D, H)
    R.gable_roof(g, 0, 0, 0.6 + H, W + 1, D + 1, 3.2, along="x", over=0.6)
    for x in range(-28, 29, 8):
        g["Wood"].box(x, -D / 2 - 2.8, 0.6 + 3.5, 0.5, 0.5, 7)
    g["Tile"].obox(0, -D / 2 - 1.6, 0.6 + 7.4, W + 1, 3.8, 0.5, rx=0.28)
    for x in (-20, 0, 20):
        g["Wood"].box(x, -D / 2 - 2.6, 1.2, 3, 1, 1.2)            # 병사 짐 궤짝
    g["LampPt"].box(0, -D / 2 - 2.5, 6, 0.6, 0.6, 0.6)


def watchtower(g):
    """망루. 돌 밑동 12 + 나무 망대 + 기와 모임지붕."""
    g["BasaltLight"].box(0, 0, 6, 10, 10, 12)
    g["Travertine"].box(0, 0, 12.3, 11, 11, 0.6)
    R.wall_with_openings(g, -5, 5, -5, 0, 9, 0.2, [(0, 3, 0, 6.5)], mat="BasaltLight", glow="Glow")
    for x in (-4.6, 4.6):
        for y in (-4.6, 4.6):
            g["Wood"].box(x, y, 16.5, 0.6, 0.6, 8)
    g["Wood"].box(0, 0, 12.8, 10.5, 10.5, 0.5)
    for (x, y, sx, sy) in ((0, -4.6, 9.6, 0.3), (0, 4.6, 9.6, 0.3), (-4.6, 0, 0.3, 9.6), (4.6, 0, 0.3, 9.6)):
        g["Wood"].box(x, y, 14.6, sx, sy, 0.35)
        g["Wood"].box(x, y, 13.8, sx, sy, 0.25)
    R.hip_roof(g, 0, 0, 20.5, 10, 10, 4.5, mat="Tile", over=1.0)
    g["Fabric"].box(0, 0, 27, 0.2, 3, 1.8)
    g["Wood"].box(0, 0, 25.5, 0.25, 0.25, 4)
    g["LampPt"].box(0, 0, 15.5, 0.6, 0.6, 0.6)


def crane(g):
    """임모로우의 답륜 기중기. A자 붐 + 발로 도는 큰 바퀴 + 매단 돌."""
    for s in (-1, 1):
        R.seg_box(g["Wood"], (s * 3, -2, 0.45), (s * 0.4, 6, 24), 0.7, 0.7)
        R.seg_box(g["Wood"], (s * 3, 5, 0.45), (s * 0.4, 6, 24), 0.6, 0.6)
        g["Wood"].box(s * 3, -2, 0.25, 1.2, 1.2, 0.5)
        g["Wood"].box(s * 3, 5, 0.25, 1.2, 1.2, 0.5)
    g["Wood"].box(0, 6, 24, 2, 1, 1)
    R.seg_box(g["Wood"], (-3, -2, 8), (3, -2, 8), 0.5, 0.5)
    # 답륜: 반지름 4.5 테 두 줄 + 살
    for yy in (-4.0, -1.0):
        for k in range(16):
            a0, a1 = TAU * k / 16, TAU * (k + 1) / 16
            R.seg_box(g["Wood"], (4.5 * math.cos(a0), yy, 5 + 4.5 * math.sin(a0)),
                      (4.5 * math.cos(a1), yy, 5 + 4.5 * math.sin(a1)), 0.5, 0.5)
        for k in range(8):
            a = TAU * k / 8
            R.seg_box(g["Wood"], (0, yy, 5), (4.5 * math.cos(a), yy, 5 + 4.5 * math.sin(a)), 0.3, 0.3)
    for k in range(16):
        a = TAU * k / 16
        R.seg_box(g["Wood"], (4.5 * math.cos(a), -4, 5 + 4.5 * math.sin(a)), (4.5 * math.cos(a), -1, 5 + 4.5 * math.sin(a)),
                  0.35, 0.35)
    g["Wood"].hcyl(0, -2.5, 5, 0.6, 5, axis="y", seg=10)
    for s in (-1, 1):
        g["Wood"].box(s * 1.2, -2.5, 2.5, 0.8, 0.8, 5)
    R.seg_cyl(g["Iron"], (0, 6.5, 23.5), (0, 9, 8), 0.12)
    g["Travertine"].box(0, 9, 6, 3.4, 3.4, 3.4)
    R.seg_cyl(g["Iron"], (0, -2.5, 5.5), (0, 6, 23.3), 0.12)


def fire_gladius(g):
    """레가투스의 불로 엮은 글라디우스. 받침 + 칼끝이 위를 향한 큰 글라디우스 + 칼날을 감는 불."""
    g["Marble"].box(0, 0, 1.0, 7, 7, 2)
    g["Porphyry"].box(0, 0, 2.6, 5.6, 5.6, 1.2)
    g["Marble"].box(0, 0, 3.6, 5, 5, 0.8)
    z = 4.0
    g["Gold"].box(0, 0, z + 0.4, 1.6, 1.6, 0.8)                    # 폼멜
    g["Wood"].cyl(0, 0, z + 0.8, 0.45, 0.45, 2.6, seg=10)          # 손잡이
    g["Gold"].box(0, 0, z + 3.7, 4.2, 1.1, 0.7)                    # 코등이
    blade_z0 = z + 4.05
    L_ = 13.0
    R.prism(g["Iron"], [(-0.95, blade_z0), (0.95, blade_z0), (0.95, blade_z0 + L_ - 2.5), (0, blade_z0 + L_),
                        (-0.95, blade_z0 + L_ - 2.5)], -0.2, 0.2)
    g["Gold"].box(0, 0, blade_z0 + L_ * 0.45, 0.25, 0.46, L_ * 0.7)   # 피홈 금상감
    # 칼날을 감아 오르는 불(나선)
    n = 22
    for i in range(n):
        t = i / n
        a = TAU * 2.2 * t
        r = 1.4 + 0.4 * math.sin(t * math.pi)
        R.seg_box(g["Lava"], (r * math.cos(a), r * math.sin(a), blade_z0 + L_ * t),
                  (r * math.cos(a + 0.6), r * math.sin(a + 0.6), blade_z0 + L_ * (t + 0.9 / n)), 0.35, 0.35)
    g["Vent"].box(0, 0, blade_z0 + L_ + 0.5, 1, 1, 1)
    g["LampPt"].box(0, 0, blade_z0 + 5, 1, 1, 1)


# ================================================================ 수도교·다리·성벽

def aqueduct_span(g):
    """수도교 한 칸(x 로 40, 이어 붙인다). 아래 큰 아치 2 + 위 작은 아치 4, 꼭대기 온천물 도랑. 높이 43."""
    Dl, Du = 6.0, 4.6
    for cx in (-10.0, 10.0):
        R.arch_wall(g, cx, 0, 0, 20.02, 26, Dl, 14, 16, mat="Travertine", arch_mat="MarbleDark")
    g["Travertine"].box(0, 0, 26.3, 40.02, Dl + 0.6, 0.6)
    for cx in (-15.0, -5.0, 5.0, 15.0):
        R.arch_wall(g, cx, 0, 26.6, 10.02, 13.4, Du, 6, 6.5, mat="Travertine", arch_mat="MarbleDark")
    g["Travertine"].box(0, 0, 40.3, 40.02, Du + 0.4, 0.6)
    for s in (-1, 1):
        g["Travertine"].box(0, s * (Du / 2 - 0.4), 42.0, 40.02, 0.8, 2.8)
    g["HotWater"].box(0, 0, 41.8, 40.02, Du - 1.6, 0.2)
    for x in (-15, 5):
        g["Travertine"].box(x, 0, 43.5, 6, Du, 0.4)          # 덮개돌(드문드문)
    g["Vent"].box(10, 0, 42.4, 0.8, 0.8, 0.8)


def bridge_span(g):
    """칼데라를 건너는 다리 한 칸(x 로 40). 교각은 수면(원점)에서 솟고, 반원 아치(너비 28), 난간. 윗면 80."""
    DECK = 78.0
    Dp = 12.0
    for s in (-1, 1):
        x = s * 17.5
        g["BasaltLight"].box(x, 0, 30, 5.02, Dp, 60)                  # 교각 반쪽(이웃 칸과 합쳐 10)
        g["Travertine"].box(x, 0, 60.5, 5.02, Dp + 0.6, 1.0)
    for yy in (-1, 1):                                                # 물가름: 칸마다 +x 끝 교각에만(이웃과 겹치지 않게)
        g["BasaltLight"].obox(20, yy * Dp / 2, 25, 7.07, 7.07, 50, rz=math.pi / 4)
        g["BasaltLight"].obox(20, yy * Dp / 2, 51, 5.0, 5.0, 2.0, rz=math.pi / 4)
    R.arch_wall(g, 0, 0, 60, 40.02, DECK - 60, Dp, 28, 1.0, mat="Travertine", arch_mat="MarbleDark", key="Gold")
    g["Travertine"].box(0, 0, DECK + 0.5, 40.02, Dp + 1.0, 1.0)
    for s in (-1, 1):
        g["Travertine"].box(0, s * (Dp / 2 + 0.2), DECK + 2.4, 40.02, 0.8, 2.8)
        for x in (-12, 0, 12):
            g["Travertine"].box(x, s * (Dp / 2 + 0.2), DECK + 4.1, 1.4, 1.4, 0.8)
    g["Basalt"].box(0, 0, DECK + 1.05, 40.02, Dp - 1.2, 0.1)


def wall_seg(g):
    """성벽 한 칸(x 로 40). 현무암 밑 5 + 트래버틴 위 11, 두께 5, 흉벽 총안."""
    L_, T = 40.02, 5.0
    g["Basalt"].box(0, 0, 2.5, L_, T + 1.2, 5)
    g["Travertine"].box(0, 0, 5 + 5.5, L_, T, 11)
    g["Travertine"].box(0, 0, 16.3, L_, T + 0.6, 0.6)
    for x in range(-18, 19, 4):
        g["Travertine"].box(x, -T / 2 + 0.5, 17.6 + 0.9, 2.2, 1.0, 1.8)    # 바깥 흉벽 총안
    g["Travertine"].box(0, -T / 2 + 0.5, 17.1, L_, 1.0, 0.9)
    g["Travertine"].box(0, T / 2 - 0.4, 17.3, L_, 0.8, 1.4)                # 안쪽 낮은 난간


def wall_tower(g):
    """성벽 탑(네모 14 x 14 x 26). 아치 창, 총안."""
    g["Basalt"].box(0, 0, 3, 15, 15, 6)
    g["Travertine"].box(0, 0, 6 + 10, 14, 14, 20)
    for y in (-7, 7):
        R.wall_with_openings(g, -5, 5, y, 16, 6, 0.3, [(0, 2, 1, 5)], mat="Travertine", glow="Glow")
    g["Travertine"].box(0, 0, 26.3, 15, 15, 0.6)
    for x in (-6, -2, 2, 6):                       # 총안(앞뒤)
        for y in (-7, 7):
            g["Travertine"].box(x, y, 27.5, 2, 1.2, 1.8)
    for y in (-2, 2):                              # 총안(양옆)
        for x in (-7, 7):
            g["Travertine"].box(x, y, 27.5, 1.2, 2, 1.8)
    g["LampPt"].box(0, -6, 18, 0.6, 0.6, 0.6)


def city_gate(g):
    """성문(포르타). 쌍둥이 아치 통로 + 위 회랑 창 + 양옆 반원 탑. 폭 48."""
    for s in (-1, 1):
        x = s * 18
        g["Basalt"].cyl(x, 0, 0, 8.4, 8.4, 6, seg=24)
        g["Travertine"].cyl(x, 0, 6, 8, 8, 22, seg=24)
        g["Travertine"].cyl(x, 0, 28, 8.4, 8.4, 0.6, seg=24)
        for k in range(12):
            a = TAU * k / 12
            g["Travertine"].obox(x + 7.8 * math.cos(a), 7.8 * math.sin(a), 29.5, 2, 1.2, 1.8, rz=a + math.pi / 2)
        for k in (-2, -1, 0, 1, 2):
            a = -math.pi / 2 + k * 0.45
            g["Glow"].obox(x + 8.05 * math.cos(a), 8.05 * math.sin(a), 18, 1.4, 0.3, 3.2, rz=a + math.pi / 2)
    # 가운데 문채(x -10..10): 아치 둘
    for cx in (-5.0, 5.0):
        R.arch_wall(g, cx, 0, 0, 10.02, 16, 8, 7, 7.5, mat="Travertine", arch_mat="MarbleDark", key="Gold")
    R.wall_with_openings(g, -10, 10, 0, 16, 9, 8, [(x, 2.2, 2, 6.5) for x in (-6, -2, 2, 6)], mat="Travertine",
                         glow="Glow")
    g["Travertine"].box(0, 0, 25.3, 21, 9, 0.6)
    for x in range(-8, 9, 4):
        g["Travertine"].box(x, -4, 26.5, 2, 1, 1.8)
        g["Travertine"].box(x, 4, 26.5, 2, 1, 1.8)
    g["Fabric"].box(0, -4.6, 21, 5, 0.2, 6)
    g["Gold"].box(0, -4.7, 21.5, 1.8, 0.25, 1.8)
    g["LampPt"].box(0, -5, 12, 0.6, 0.6, 0.6)


def triumphal_arch(g):
    """개선문(세 아치). 가운데 큰 아치 + 양옆 작은 아치, 붙임 코린트 기둥, 아틱 명판, 꼭대기 청동 기마상 대신 황제상."""
    W, D = 38.0, 10.0
    # 몸채를 가운데 아치 벽 + 양옆 작은 아치 벽으로
    R.arch_wall(g, 0, 0, 0, 14.02, 24, D, 10, 13, mat="Marble", arch_mat="MarbleDark", key="Gold")
    for s in (-1, 1):
        R.arch_wall(g, s * 12, 0, 0, 10.02, 24, D, 5, 8.5, mat="Marble", arch_mat="MarbleDark")
        g["Marble"].box(s * 18, 0, 12, 2.02, D, 24)
    for s in (-1, 1):
        for x in (-17.2, -7.6, 7.6, 17.2):
            col(g, x, s * (D / 2 + 1.0), 1.2, 21, 0.95, "corinthian", "Marble")
            g["MarbleDark"].box(x, s * (D / 2 + 0.9), 0.6, 2.8, 2.8, 1.2)
    R.entablature(g, -W / 2, W / 2, -D / 2 - 1.2, D / 2 + 1.2, 24, 3, "Marble")
    g["Marble"].box(0, 0, 27 + 4, W - 1, D + 1, 8)                 # 아틱
    g["Bronze"].box(0, -D / 2 - 1.0, 31, 16, 0.3, 5)               # 명판
    for x in range(-6, 7, 2):
        g["Gold"].box(x, -D / 2 - 1.2, 31.6, 1.2, 0.2, 1.8)        # 글자 자리
    g["MarbleDark"].box(0, 0, 35.3, W - 0.4, D + 1.4, 0.6)
    R.figure(g, "Bronze", s=1.2, x=0, y=0, z=35.6, face=-1, robe="Bronze", arm_raise=0.8)
    for s in (-1, 1):
        g["Bronze"].box(s * 13, 0, 36.5, 5, 2, 1.8)                # 청동 전리품 더미
        g["Bronze"].box(s * 13, 0, 38, 1.2, 1.2, 2.4)


# ================================================================ 거인·석상

def colossus(g):
    """
    거인 석상(콜로수스). 받침 10 위에 한 발을 바위(땅)에 올린 청동 거인, 키 약 60.
    치켜든 오른손에 이그너스의 불그릇, 왼손은 땅에 짚은 큰 망치 — 땅을 밟아 문명을 세운 거인들.
    """
    g["Marble"].box(0, 0, 4, 22, 22, 8)
    g["Gold"].box(0, 0, 8.3, 22.6, 22.6, 0.6)
    g["MarbleDark"].box(0, 0, 9.3, 20, 20, 1.4)
    for k in range(4):                                             # 받침 네 면의 청동 부조판
        a = k * math.pi / 2
        g["Bronze"].obox(11.05 * math.cos(a), 11.05 * math.sin(a), 4.2, 12, 0.3, 5, rz=a + math.pi / 2)
    g["BasaltLight"].obox(-2.5, -3.5, 12.0, 8, 9, 3.4, rz=0.3)       # 밟고 선 바위(땅)
    out = R.figure(g, "Bronze", s=7.2, pose="step", x=0.5, y=1.0, z=10.0, face=-1, stride=0.35, arm_raise=1.0,
                   seg=10, cloak="Verdigris")
    hx, hy, hz = out["rh"]
    g["Bronze"].cyl(hx, hy, hz + 1.0, 1.4, 2.6, 2.4, seg=14)          # 불그릇
    for k in range(7):
        a = TAU * k / 7
        R.seg_box(g["Lava"], (hx + 1.6 * math.cos(a), hy + 1.6 * math.sin(a), hz + 3.2),
                  (hx + 0.5 * math.cos(a + 1), hy + 0.5 * math.sin(a + 1), hz + 7.8), 0.5, 0.5)
    g["Vent"].box(hx, hy, hz + 4.5, 1, 1, 1)
    g["LampPt"].box(hx, hy, hz + 5, 1, 1, 1)
    lx, ly, lz = out["lh"]
    R.seg_cyl(g["Bronze"], (lx, ly, lz + 1.5), (lx - 0.8, ly - 2.0, 10.9), 0.55, 0.55, seg=10)   # 망치 자루
    g["Bronze"].obox(lx - 0.8, ly - 2.0, 12.4, 5.5, 3.2, 3.0, rz=0.4)                             # 망치 머리


def giant_head(g):
    """쓰러진 거인 머리(옛 제국의 유물). 옆으로 누워 반쯤 묻혔다."""
    g["BasaltLight"].box(0, 0, 0.8, 22, 18, 1.6)
    R.sphere(g["MarbleDark"], 0, 0, 7.5, 8.5, seg=18, rings=12, sz=7.5)
    g["MarbleDark"].obox(-1, -8.2, 7.8, 2.6, 3.4, 5.0, rx=0.2)                 # 코
    for s in (-1, 1):
        g["MarbleDark"].box(s * 3.2, -6.8, 10.8, 4.4, 2.2, 1.0)                  # 눈썹
        R.sphere(g["Marble"], s * 3.2, -7.4, 9.3, 1.1, seg=10, rings=6)           # 눈
    g["MarbleDark"].box(0, -7.4, 4.6, 5.0, 1.8, 0.8)                            # 입
    for k in range(9):                                                          # 곱슬 머리칼
        a = TAU * k / 9
        R.sphere(g["MarbleDark"], 7.4 * math.cos(a) * 0.9, 1 + 5 * math.sin(a) * 0.5, 12.5 + 1.5 * math.sin(a * 2),
                 1.8, seg=8, rings=5)
    g["BasaltLight"].obox(6, 6, 1.5, 6, 4, 3, rz=0.5)
    g["BasaltLight"].obox(-7, 5, 1.2, 4, 5, 2.4, rz=-0.3)


def giant_hand(g):
    """거인의 손(검지를 치켜든 채 부러진 손목). 옛 제국 황제 거상의 조각."""
    g["BasaltLight"].box(0, 0, 0.6, 16, 12, 1.2)
    g["MarbleDark"].box(0, 0, 4.5, 9, 4.2, 7.5)                                   # 손바닥
    g["MarbleDark"].obox(-5.5, 0, 3.5, 3.0, 3.0, 6, ry=0.7)                       # 엄지
    for i, (x, h) in enumerate(((-3.0, 7.5), (-1.0, 11), (1.2, 7), (3.3, 6))):
        g["MarbleDark"].box(x, 0, 8.25 + h / 2, 2.0, 2.8, h)
        if i != 1:
            g["MarbleDark"].box(x, -1.6, 8.25 + h - 1, 2.0, 3.2, 1.8)            # 굽은 끝마디
    g["MarbleDark"].cyl(0, 3.6, 1.2, 3.2, 3.0, 2.2, seg=14)                        # 부러진 손목
    g["Marble"].cyl(0, 3.6, 3.35, 2.6, 2.6, 0.1, seg=14)


def giant_foot(g):
    """거인의 발(받침 위, 발목에서 부러짐)."""
    g["Travertine"].box(0, 0, 1.5, 16, 22, 3)
    g["MarbleDark"].box(0, 1.5, 5.5, 9, 14, 5)
    for i, x in enumerate((-3.4, -1.5, 0.4, 2.2, 3.8)):
        ln = (4.2, 3.4, 3.0, 2.6, 2.2)[i]
        R.sphere(g["MarbleDark"], x, -6.3 - ln * 0.35, 4.4, 0.95 + 0.25 * (i == 0), seg=10, rings=6, sz=1.2)
    g["MarbleDark"].cyl(0, 4.5, 8, 4.2, 3.6, 7, seg=16)
    g["Marble"].cyl(0, 4.5, 15.0, 3.1, 3.1, 0.1, seg=16)


def _band(g, c, d, r, w, t, n=18):
    """축 d 둘레에 두른 띠(반지름 r, 폭 w, 두께 t). 팔·허리의 봉인 고리."""
    c, d = R.Vector(c), R.Vector(d).normalized()
    u = d.orthogonal().normalized()
    v = d.cross(u)
    for k in range(n):
        a0, a1 = TAU * k / n, TAU * (k + 1) / n
        p0 = c + (u * math.cos(a0) + v * math.sin(a0)) * r
        p1 = c + (u * math.cos(a1) + v * math.sin(a1)) * r
        R.seg_box(g, tuple(p0), tuple(p1), w, t, up=tuple(d))


def _limb(g, a, b, r0, r1, seg=14, joint=True):
    R.seg_cyl(g, a, b, r0, r1, seg=seg)
    if joint:
        R.sphere(g, *b, r1 * 1.05, seg=12, rings=8)


def _vein(g, pts, w=0.55):
    for p0, p1 in zip(pts, pts[1:]):
        R.seg_box(g, p0, p1, w, w * 0.8)


def _vein_ell(g, c, rx, ry, rz, angs, w=0.6):
    """타원체(가운데 c, 반지름 rx ry rz) 겉면을 따라 가는 용암 핏줄. angs = [(방위각, 앙각)] 도.
    방위 0 = 앞(-y), 90 = +x. 겉면에서 살짝(2%) 띄워 박는다."""
    pts = []
    for az, el in angs:
        a, e = math.radians(az), math.radians(el)
        d = (math.cos(e) * math.sin(a), -math.cos(e) * math.cos(a), math.sin(e))
        pts.append((c[0] + rx * d[0] * 1.02, c[1] + ry * d[1] * 1.02, c[2] + rz * d[2] * 1.02))
    _vein(g, pts, w)


def _vein_limb(g, a, b, r0, r1, n, wig=0.35, w=0.55, k=7):
    """팔다리(a→b, 반지름 r0→r1) 겉면을 따라 방향 n 쪽으로 흐르는 핏줄."""
    a, b, n = R.Vector(a), R.Vector(b), R.Vector(n)
    d = (b - a).normalized()
    n = (n - d * n.dot(d)).normalized()
    side = d.cross(n)
    pts = []
    for i in range(k + 1):
        t = i / k
        r = (r0 + (r1 - r0) * t) * 1.02
        off = n * r + side * (wig * r * math.sin(t * 9.0))
        p = a + (b - a) * t
        pts.append(tuple(p + off.normalized() * r))
    _vein(g, pts, w)


def sealed_giant(g):
    """
    문명 멸전의 거인 — 봉인된 마지막 거인. 발뒤꿈치에 주저앉아 무릎을 꿇고, 몸을 앞으로 숙인 채 고개를 떨궜다.
    두 팔은 사슬에 끌려 위·옆으로 벌어졌고 손은 힘없이 늘어졌다. 현무암 몸에 용암 핏줄, 목·두 팔·허리에 봉인 띠,
    가슴에 금 봉인판. 이마에서 뒤로 휜 뿔 둘(이그너스가 죽은 짐승의 뼈로 빚었다는 흔적). 꿇은 키 약 72.
    손목 쇠고랑 = (±34, 8, 63.5). Studio 가 여기서 오벨리스크로 사슬을 건다(Roman_City.luau 의 SEAL_CHAINS).
    """
    B, BL, C = "Basalt", "BasaltLight", "Lava"
    # ---- 다리: 허벅지는 앞으로 내려가 무릎이 땅, 정강이는 뒤로 눕고 발등이 땅
    for sd in (-1, 1):
        hip = (sd * 7.5, 3.0, 21.0)
        knee = (sd * 9.5, -15.0, 6.2)
        ankle = (sd * 9.8, 9.5, 3.6)
        R.sphere(g[B], *hip, 6.0, seg=14, rings=10)
        _limb(g[B], hip, knee, 6.2, 4.6, seg=16)
        R.seg_cyl(g[B], knee, ankle, 4.4, 2.6, seg=16)
        R.sphere(g[B], sd * 9.6, 0.0, 6.2, 3.8, seg=12, rings=8, sz=3.0)          # 장딴지
        R.sphere(g[B], sd * 9.8, 14.0, 2.0, 2.4, seg=12, rings=8, sz=1.8)         # 발(발등이 땅)
        R.seg_cyl(g[B], ankle, (sd * 9.8, 15.5, 1.8), 2.4, 1.6, seg=12)
        _vein_limb(g[C], hip, knee, 6.2, 4.6, (sd * 0.3, -0.2, 1.0), k=6)
    # ---- 몸통: 골반 → 배 → 갈비 우리(앞으로 숙임)
    R.sphere(g[B], 0, 4.5, 23.0, 10.5, seg=18, rings=12, sz=7.5)                    # 골반·엉덩이
    R.sphere(g[B], 0, 0.5, 33.0, 8.8, seg=18, rings=12, sz=8.5)                     # 배
    R.sphere(g[B], 0, -4.5, 44.5, 12.5, seg=20, rings=14, sz=10.5)                  # 갈비 우리
    R.sphere(g[B], 0, 1.5, 47.0, 11.0, seg=16, rings=10, sz=9.0)                    # 등(넓은 등근육)
    for sd in (-1, 1):
        R.sphere(g[B], sd * 5.5, -12.0, 45.5, 5.2, seg=12, rings=8, sz=4.0)        # 가슴근
        R.seg_cyl(g[B], (0, -1.0, 55.0), (sd * 12.0, -2.0, 52.5), 4.2, 3.8)          # 승모근→어깨
    _band(g["Rune"], (0, 1.0, 30.5), (0, 0.1, 1), 9.6, 1.4, 0.9, n=22)              # 허리 봉인 띠
    _band(g["Iron"], (0, 1.0, 29.0), (0, 0.1, 1), 9.8, 1.6, 1.0, n=22)
    rib = ((0, -4.5, 44.5), 12.5, 12.5, 10.5)
    _vein_ell(g[C], *rib, [(-62, -30), (-48, -12), (-40, 4), (-30, 18), (-22, 32)])
    _vein_ell(g[C], *rib, [(38, -38), (44, -20), (55, -6), (62, 10)])
    _vein_ell(g[C], *rib, [(148, -20), (160, -2), (172, 12), (190, 24), (205, 30)])      # 등
    _vein_ell(g[C], (0, 1.5, 47.0), 11.0, 11.0, 9.0, [(120, 5), (135, 20), (150, 32)])
    _vein_ell(g[C], (0, 0.5, 33.0), 8.8, 8.8, 8.5, [(20, -30), (28, -12), (30, 6)])       # 배
    # 가슴 봉인판(못 넷)
    g["Gold"].obox(0, -16.2, 45.5, 8.5, 1.0, 8.5, rx=0.35)
    g["Rune"].obox(0, -16.8, 45.4, 5.8, 0.4, 5.8, rx=0.35)
    for (px, pz) in ((-3.6, 49.0), (3.6, 49.0), (-3.6, 41.8), (3.6, 41.8)):
        R.seg_cyl(g["Iron"], (px, -16.0, pz), (px, -19.0, pz + 1.0), 0.7, 0.4, seg=8)
    # ---- 목과 떨군 머리
    _limb(g[B], (0, -4.0, 54.0), (0, -10.5, 57.0), 4.2, 3.6)
    _band(g["Rune"], (0, -6.5, 55.4), (0, -0.9, 0.45), 4.6, 1.3, 0.9, n=18)
    _band(g["Iron"], (0, -5.8, 55.0), (0, -0.9, 0.45), 4.9, 1.0, 1.2, n=18)
    R.sphere(g[B], 0, -15.0, 56.5, 5.4, seg=16, rings=12, sz=6.4)                    # 머리(얼굴이 아래를 향함)
    R.sphere(g[B], 0, -18.5, 52.5, 3.6, seg=12, rings=8, sz=3.0)                     # 턱
    g[B].obox(0, -19.4, 58.6, 8.6, 2.6, 2.0, rx=0.9)                                 # 눈두덩
    for sx in (-2.2, 2.2):
        g[C].obox(sx, -20.2, 56.8, 1.8, 0.5, 0.45, rx=0.9)                          # 감긴 눈 틈의 불빛
    g[C].obox(0, -20.6, 51.2, 3.2, 0.5, 0.4, rx=0.6)                                 # 입 틈
    # 뿔: 관자놀이에서 뒤·위로 휜다
    for sd in (-1, 1):
        pts = []
        for k in range(8):
            t = k / 7
            a = math.pi * 0.95 * t
            pts.append((sd * (4.8 + 3.2 * t), -14.5 + 9.5 * math.sin(a * 0.9) + 2.0 * t, 60.5 + 6.5 * math.sin(a) - 3.0 * t * t))
        for k, (p0, p1) in enumerate(zip(pts, pts[1:])):
            r0 = 2.0 * (1 - k / 8) + 0.25
            R.seg_cyl(g[BL], p0, p1, r0, max(0.2, r0 - 0.25), seg=10)
    # ---- 두 팔: 사슬에 끌려 위·옆으로 벌어진다. 손은 늘어진다
    for sd in (-1, 1):
        sh = (sd * 13.0, -2.5, 52.5)
        el = (sd * 24.0, 2.5, 57.5)
        wr = (sd * 33.0, 7.5, 63.5)
        R.sphere(g[B], *sh, 5.6, seg=14, rings=10)                                    # 어깨(삼각근)
        _limb(g[B], sh, el, 4.6, 3.4, seg=14)
        R.sphere(g[B], sd * 18.5, 0.6, 56.2, 3.9, seg=12, rings=8, sz=3.2)           # 이두
        R.seg_cyl(g[B], el, wr, 3.4, 2.4, seg=14)
        R.sphere(g[B], sd * 27.0, 4.2, 59.8, 3.0, seg=12, rings=8)                   # 아래팔 근육
        hand = (sd * 36.0, 8.5, 60.5)
        R.seg_cyl(g[B], wr, hand, 2.5, 2.2, seg=12)
        g[B].obox(sd * 36.2, 8.6, 58.8, 4.2, 2.2, 5.0, ry=sd * 0.25)               # 늘어진 손바닥
        for fx in (-1.3, 0.0, 1.3):
            R.seg_cyl(g[B], (sd * 36.2 + fx, 8.6, 56.6), (sd * 36.6 + fx, 7.6, 52.8), 0.75, 0.5, seg=8)
        R.seg_cyl(g[B], (sd * 34.3, 7.4, 59.5), (sd * 33.0, 6.0, 56.5), 0.9, 0.6, seg=8)   # 엄지
        _band(g["Iron"], wr, (sd * 9.0, 5.0, 6.0), 3.2, 2.6, 1.3, n=16)             # 쇠고랑
        _band(g["Rune"], (sd * 30.0, 5.8, 61.5), (sd * 9.0, 5.0, 6.0), 3.1, 0.9, 0.7, n=16)
        _band(g["Rune"], (sd * 19.0, 0.0, 55.2), (sd * 11.0, 5.0, 5.0), 4.3, 1.1, 0.8, n=16)   # 위팔 봉인 띠
        _vein_limb(g[C], sh, el, 4.6, 3.4, (0, -0.6, 1.0), k=6)
        _vein_limb(g[C], el, wr, 3.4, 2.4, (0, -0.5, 1.0), k=6, w=0.45)
    g["Vent"].box(0, -21.0, 52.0, 1, 1, 1)                                         # 입김
    g["LampPt"].box(0, -24.0, 46.0, 1, 1, 1)


def seal_obelisk(g):
    """봉인 오벨리스크. 현무암 기둥에 빛나는 봉인 문자 줄, 금 피라미디온, 사슬 고리."""
    g["Basalt"].box(0, 0, 2, 10, 10, 4)
    g["Gold"].box(0, 0, 4.2, 10.4, 10.4, 0.4)
    g["Basalt"].box(0, 0, 5.4, 8, 8, 2)
    H = 34.0
    for i in range(12):                                          # 가늘어지는 몸(단면 줄여 가며)
        z0 = 6.4 + H * i / 12
        w0 = 6.4 - 2.0 * i / 12
        w1 = 6.4 - 2.0 * (i + 1) / 12
        g["Basalt"].box(0, 0, z0 + H / 24, (w0 + w1) / 2, (w0 + w1) / 2, H / 12 + 0.02)
    R.prism(g["Gold"], [(-2.2, 6.4 + H), (2.2, 6.4 + H), (0, 6.4 + H + 4)], -2.2, 2.2)
    R.prism(g["Gold"], [(-2.2, 6.4 + H), (2.2, 6.4 + H), (0, 6.4 + H + 4)], -2.2, 2.2, axis="x")
    for face in range(4):
        a = face * math.pi / 2
        for i in range(9):
            z = 9 + i * 3.4
            w = 6.4 - 2.0 * (z - 6.4) / H
            dx, dy = math.cos(a) * (w / 2 + 0.05), math.sin(a) * (w / 2 + 0.05)
            g["Rune"].obox(dx, dy, z, 1.4 if i % 3 else 2.0, 0.2, 0.5 if i % 2 else 1.2, rz=a + math.pi / 2)
    for side in (-1, 1):                                         # 사슬 고리
        g["Iron"].hcyl(side * 5.4, 0, 4.8, 1.3, 0.6, axis="x", seg=12)
    g["LampPt"].box(0, -3.5, 20, 0.6, 0.6, 0.6)


def statue_human(g):
    """사람 석상(연설하는 황제·장군). 받침 4 + 토가 입은 대리석 상."""
    g["Marble"].box(0, 0, 1.8, 4, 4, 3.6)
    g["MarbleDark"].box(0, 0, 0.3, 4.6, 4.6, 0.6)
    g["MarbleDark"].box(0, 0, 3.8, 4.4, 4.4, 0.4)
    R.figure(g, "Marble", s=1.12, x=0, y=0, z=4.0, face=-1, robe="Marble", arm_raise=0.7)


def aquila(g):
    """군단기(아퀼라). 장대 + 금 독수리 + 붉은 기."""
    g["Wood"].cyl(0, 0, 0, 0.22, 0.2, 11, seg=8)
    g["Gold"].box(0, 0, 11.2, 0.8, 0.8, 0.5)
    g["Gold"].box(0, 0, 11.9, 0.9, 1.4, 0.9)                     # 몸통
    R.sphere(g["Gold"], 0, -0.8, 12.6, 0.38, seg=8, rings=6)     # 머리
    for s in (-1, 1):
        g["Gold"].obox(s * 1.1, 0, 12.5, 2.0, 0.3, 0.8, ry=-s * 0.6)
        g["Gold"].obox(s * 2.0, 0, 13.3, 1.2, 0.25, 0.7, ry=-s * 1.0)
    g["Gold"].box(0, 0, 8.6, 3.2, 0.25, 0.25)                    # 가로대
    g["Fabric"].box(0, 0.1, 6.9, 2.8, 0.1, 3.2)
    g["Gold"].box(0, 0.05, 7.3, 1.0, 0.12, 1.0)
    for x in (-1.2, 0, 1.2):
        g["Gold"].box(x, 0.1, 5.2, 0.2, 0.12, 0.6)


def victory_column(g):
    """승전 기둥. 받침 6 + 나선 띠 두른 기둥 34 + 꼭대기 청동 상."""
    g["Marble"].box(0, 0, 3, 9, 9, 6)
    g["MarbleDark"].box(0, 0, 0.4, 10, 10, 0.8)
    g["MarbleDark"].box(0, 0, 6.2, 9.6, 9.6, 0.4)
    g["Marble"].cyl(0, 0, 6.4, 2.6, 2.3, 34, seg=18)
    n = 60
    for i in range(n):
        t = i / n
        a = TAU * 7 * t
        z = 7 + 32 * t
        R.seg_box(g["MarbleDark"], (2.55 * math.cos(a), 2.55 * math.sin(a), z),
                  (2.55 * math.cos(a + 0.75), 2.55 * math.sin(a + 0.75), z + 32 / n), 0.3, 0.6)
    g["Marble"].box(0, 0, 41.1, 6, 6, 1.2)
    g["Marble"].cyl(0, 0, 41.7, 1.6, 1.6, 1.6, seg=14)
    R.figure(g, "Bronze", s=1.0, x=0, y=0, z=43.3, face=-1, robe="Bronze", arm_raise=0.9)


def brazier(g):
    """불화로(삼각대 + 용암 숯 그릇)."""
    for k in range(3):
        a = TAU * k / 3
        R.seg_box(g["Bronze"], (1.6 * math.cos(a), 1.6 * math.sin(a), 0.2), (0.7 * math.cos(a), 0.7 * math.sin(a), 3.4),
                  0.25, 0.25)
        g["Bronze"].box(1.62 * math.cos(a), 1.62 * math.sin(a), 0.12, 0.5, 0.5, 0.24)
    g["Bronze"].cyl(0, 0, 3.2, 0.8, 1.7, 1.3, seg=14)
    g["Lava"].cyl(0, 0, 4.3, 1.4, 1.2, 0.35, seg=14)
    g["Vent"].box(0, 0, 4.9, 0.6, 0.6, 0.6)
    g["LampPt"].box(0, 0, 5.5, 0.6, 0.6, 0.6)


def fountain(g):
    """분수(온천물이 솟는 둥근 못)."""
    R.ring_band(g["Marble"], 0, 0, 0.0, 5.2, 6.0, 1.6, seg=28)
    g["BasaltLight"].cyl(0, 0, 0, 5.3, 5.3, 0.9, seg=28)
    g["HotWater"].cyl(0, 0, 0.9, 5.2, 5.2, 0.15, seg=28)
    g["Marble"].cyl(0, 0, 0.9, 0.8, 0.6, 3.2, seg=12)
    g["Marble"].cyl(0, 0, 4.0, 0.6, 2.2, 0.9, seg=16)
    g["HotWater"].cyl(0, 0, 4.9, 1.9, 1.9, 0.05, seg=16)
    g["Vent"].box(0, 0, 5.3, 0.6, 0.6, 0.6)


def market_stall(g):
    """시장 가판(나무 틀 + 차양 + 항아리)."""
    for x in (-3, 3):
        for y in (-2, 2):
            g["Wood"].box(x, y, 3, 0.35, 0.35, 6)
    g["Wood"].box(0, -2, 2.2, 6.6, 1.2, 0.4)
    g["Wood"].box(0, -2, 1.1, 6.4, 1.0, 2.0)
    g["Fabric"].obox(0, 0, 6.3, 7.4, 5.4, 0.2, rx=0.15)
    for i, x in enumerate((-2.2, -0.8, 0.6, 2.0)):
        g["Terracotta"].cyl(x, -2, 2.4, 0.35, 0.22, 1.0 + 0.2 * (i % 2), seg=10)
    g["Terracotta"].cyl(3.8, 1, 0, 0.7, 0.4, 2.2, seg=10)


def amphorae(g):
    """항아리 무더기(암포라 다섯)."""
    spots = ((0, 0, 0.0), (1.5, 0.4, 0.2), (-1.4, 0.6, -0.2), (0.6, 1.7, 0.1), (-0.6, -1.5, -0.1))
    for (x, y, tilt) in spots:
        g["Terracotta"].cyl(x, y, 0, 0.25, 0.6, 0.6, seg=10)
        g["Terracotta"].cyl(x, y, 0.6, 0.6, 0.62, 1.2, seg=10)
        g["Terracotta"].cyl(x, y, 1.8, 0.62, 0.25, 0.7, seg=10)
        g["Terracotta"].cyl(x, y, 2.5, 0.2, 0.2, 0.7, seg=8)
        g["Terracotta"].box(x + 0.35, y, 2.8, 0.15, 0.2, 0.6)
        g["Terracotta"].box(x - 0.35, y, 2.8, 0.15, 0.2, 0.6)


def ruin_temple(g):
    """옛 제국의 무너진 신전. 부서진 기단, 높이가 제각각인 기둥 다섯, 들보 한 조각, 쓰러진 기둥."""
    g["BasaltLight"].box(0, 0, 1.2, 34, 22, 2.4)
    g["BasaltLight"].box(-6, -12.5, 0.6, 18, 3, 1.2)
    g["MarbleDark"].box(3, 0, 2.6, 30, 18, 0.4)
    heights = (18, 11, 18, 6.5, 14)
    for i, (x, h) in enumerate(zip((-12, -6, 0, 6, 12), heights)):
        if h >= 18:
            col(g, x, -7, 2.8, h, 1.3, "doric", "MarbleDark", base=True)
        else:
            g["MarbleDark"].box(x, -7, 2.8 + 0.4, 3.2, 3.2, 0.8)
            g["MarbleDark"].cyl(x, -7, 3.6, 1.3, 1.2, h - 1, seg=16)
            g["MarbleDark"].obox(x + 0.3, -7, 2.8 + h + 0.2, 2.2, 2.4, 0.9, ry=0.5)   # 부서진 윗머리
    g["MarbleDark"].box(-6, -7, 2.8 + 18 + 1.0, 15, 2.8, 2.0)                    # 두 기둥에 걸친 들보 조각
    for k in range(4):                                                            # 쓰러진 기둥(북)
        g["MarbleDark"].hcyl(-4 + k * 3.3 + 0.2 * k, 5, 4.1, 1.3, 3.1, axis="x", seg=16, rz=0.1 * k)
    g["MarbleDark"].box(12, 6, 3.6, 3.2, 3.2, 1.6)
    for (x, y, sx, sy, sz, rz) in ((8, 8, 3, 2, 1.5, 0.4), (-12, 7, 2.5, 2.5, 1.2, 0.9), (15, -2, 2, 3, 1.0, 0.2)):
        g["BasaltLight"].obox(x, y, 2.4 + sz / 2, sx, sy, sz, rz=rz)


def column_drums(g):
    """쓰러진 기둥 북과 주두 하나."""
    for k, (x, y, rz) in enumerate(((0, 0, 0.2), (3.4, 0.6, 0.1), (6.4, 1.8, 0.5))):
        g["MarbleDark"].hcyl(x, y, 1.3, 1.3, 3.0, axis="x", seg=16, rz=rz)
    g["MarbleDark"].box(-3.5, 1.5, 0.6, 3.2, 3.2, 1.2)
    g["MarbleDark"].cyl(-3.5, 1.5, 1.2, 1.0, 1.4, 1.0, seg=14)


# ================================================================ 내놓기

JOBS = [
    ("Temple_Ignus", "TIg", temple_ignus, [("front", (40, -110, 30), (0, 0, 22)), ("corner", (80, -90, 60), (0, 0, 20))]),
    ("Temple_Small", "TSm", temple_small, [("front", (22, -52, 16), (0, 0, 12))]),
    ("Basilica", "Bas", basilica, [("front", (40, -110, 30), (0, 0, 14)), ("corner", (90, -80, 60), (0, 0, 14))]),
    ("Thermae", "Thm", thermae, [("front", (30, -110, 40), (0, 0, 14)), ("corner", (80, -80, 70), (0, 0, 14))]),
    ("Amph_Quarter", "AmQ", amph_quarter, [("out", (140, 90, 60), (30, 30, 20)), ("in", (10, 10, 60), (40, 40, 15))]),
    ("Domus", "Dom", domus, [("front", (20, -70, 30), (0, 0, 6)), ("top", (30, -40, 60), (0, 0, 0))]),
    ("Insula_A", "InA", insula_a, [("front", (30, -60, 30), (0, 0, 18))]),
    ("Insula_B", "InB", insula_b, [("front", (34, -64, 34), (0, 0, 20))]),
    ("Taberna_Row", "Tab", taberna_row, [("front", (18, -40, 14), (0, 0, 5))]),
    ("Palatium", "Pal", palatium, [("front", (60, -150, 50), (0, 0, 28)), ("corner", (130, -110, 90), (0, 0, 25))]),
    ("Principia", "Pri", principia, [("front", (30, -70, 34), (0, 0, 6)), ("top", (20, -40, 70), (0, 0, 0))]),
    ("Barracks", "Brk", barracks, [("front", (30, -50, 20), (0, 0, 5))]),
    ("Watchtower", "Wtc", watchtower, [("corner", (22, -26, 24), (0, 0, 14))]),
    ("Crane", "Crn", crane, [("corner", (26, -26, 20), (0, 2, 12))]),
    ("Fire_Gladius", "FGl", fire_gladius, [("front", (8, -18, 14), (0, 0, 10))]),
    ("Aqueduct_Span", "Aqd", aqueduct_span, [("corner", (60, -60, 40), (0, 0, 22))]),
    ("Bridge_Span", "Brg", bridge_span, [("corner", (70, -80, 70), (0, 0, 50))]),
    ("Wall_Seg", "Wal", wall_seg, [("corner", (40, -40, 25), (0, 0, 10))]),
    ("Wall_Tower", "Wtw", wall_tower, [("corner", (28, -30, 30), (0, 0, 15))]),
    ("City_Gate", "Gat", city_gate, [("front", (0, -70, 20), (0, 0, 15))]),
    ("Triumphal_Arch", "TAr", triumphal_arch, [("front", (10, -70, 25), (0, 0, 20))]),
    ("Colossus", "Col", colossus, [("front", (40, -120, 40), (0, 0, 36))]),
    ("Giant_Head", "GHd", giant_head, [("front", (10, -35, 14), (0, 0, 7))]),
    ("Giant_Hand", "GHn", giant_hand, [("front", (14, -30, 14), (0, 0, 9))]),
    ("Giant_Foot", "GFt", giant_foot, [("front", (16, -32, 14), (0, 0, 6))]),
    ("Sealed_Giant", "SGi", sealed_giant, [("front", (30, -130, 55), (0, 0, 38)), ("side", (120, -30, 50), (0, 0, 38)),
                                           ("low", (-40, -80, 18), (0, -10, 45))]),
    ("Seal_Obelisk", "SOb", seal_obelisk, [("front", (10, -40, 25), (0, 0, 20))]),
    ("Statue_Human", "Stt", statue_human, [("front", (6, -16, 9), (0, 0, 7))]),
    ("Aquila", "Aqu", aquila, [("front", (4, -10, 10), (0, 0, 9))]),
    ("Victory_Column", "VCl", victory_column, [("front", (20, -50, 30), (0, 0, 25))]),
    ("Brazier", "Brz", brazier, [("front", (5, -7, 5), (0, 0, 3))]),
    ("Fountain", "Fnt", fountain, [("front", (8, -12, 8), (0, 0, 2))]),
    ("Market_Stall", "Mkt", market_stall, [("front", (8, -14, 7), (0, 0, 3))]),
    ("Amphorae", "Amp", amphorae, [("front", (4, -6, 4), (0, 0, 1.5))]),
    ("Ruin_Temple", "RTm", ruin_temple, [("front", (20, -45, 22), (0, 0, 9))]),
    ("Column_Drums", "CDr", column_drums, [("front", (6, -12, 6), (2, 0, 1))]),
]

if __name__ == "__main__":
    only = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for name, prefix, fn, renders in JOBS:
        if only and name not in only:
            continue
        L.clear_scene()
        g = G(prefix)
        fn(g)
        L.export_model(name, g, 1.0, renders=renders, min_objs=1, palette=PALETTE)
