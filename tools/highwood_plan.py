# -*- coding: utf-8 -*-
"""
highwood_plan.py — 2026-10-09. 하이우드(나무 위 마을) 배치표 → tools/highwood_plan.svg (위에서 본 그림 + 옆에서 본 그림)

사용자(2026-10-09): "하이우드는 엄청 커다란 나무들에 마을을 만든 거야. 저 나무들보다 몇십 배는 큰 나무에 판을 깔고 집을 놔야 해."
  숲 거목(옛 숲 틀) ≈ 높이 90 → 하이우드 거대수는 높이 1100~2000(12~22배), 줄기 굵기 160~260.
  하이우드 자리 = forest_plan.HIGHWOOD(숲 남서 구석). 양식은 맵 규칙대로 각진 상자(줄기·가지·잎 덩어리 모두 축에 맞춘 상자 + 돌림).
구성(손 표):
  GIANTS  거대수 { 이름, x, z, 줄기 굵기, 잎 시작 높이, 꼭대기 }
  DECKS   판(나무 둘레 네모 고리) { 나무, 높이, 고리 폭(줄기 밖으로), 이름 } — 집은 고리 위에(HOUSES 수)
  BRIDGES 다리 { (나무, 판 높이) → (나무, 판 높이) } — 높이가 다르면 비탈 다리
  STAIRS  땅 → 첫 판, 판 → 판: 줄기를 감는 계단(나무, 아래 높이, 위 높이)
좌표 = 월드(x 동, z 남; 북 = -z). 돌리기: python tools/highwood_plan.py (문제 0건이어야)
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from forest_plan import HIGHWOOD, inside  # noqa: E402

GROUND = 1.9
GIANTS = [
    # 이름, x, z, 줄기, 잎 시작, 꼭대기
    ("어머니 나무", -1330, 1250, 260, 1450, 2000),
    ("북서 나무", -1520, 720, 180, 950, 1300),
    ("북동 나무", -1090, 780, 160, 850, 1150),
    ("남서 나무", -1560, 1680, 200, 1100, 1500),
    ("남동 나무", -1130, 1830, 170, 880, 1200),
]
# 판 { 나무, 높이, 고리 폭, 이름, 집 수 }
DECKS = [
    ("어머니 나무", 140, 110, "아랫장터", 8),
    ("어머니 나무", 380, 80, "어머니 1단 주거", 6),
    ("어머니 나무", 640, 80, "어머니 2단 주거", 6),
    ("어머니 나무", 900, 100, "장로 회당", 2),
    ("어머니 나무", 1200, 70, "잎맥 사당", 1),
    ("북서 나무", 160, 80, "북서 1단", 5),
    ("북서 나무", 380, 70, "북서 2단", 4),
    ("북서 나무", 640, 60, "북서 망루", 1),
    ("북동 나무", 140, 70, "북동 1단", 4),
    ("북동 나무", 380, 70, "북동 공방", 3),
    ("남서 나무", 140, 90, "남서 1단", 5),
    ("남서 나무", 380, 80, "남서 2단", 5),
    ("남서 나무", 640, 70, "남서 3단", 3),
    ("남동 나무", 140, 70, "남동 1단(솔르헨 쪽 문)", 4),
    ("남동 나무", 380, 60, "남동 2단", 3),
]
# 다리 { (나무, 높이), (나무, 높이) }
BRIDGES = [
    (("어머니 나무", 140), ("북서 나무", 160)),
    (("어머니 나무", 140), ("북동 나무", 140)),
    (("어머니 나무", 140), ("남서 나무", 140)),
    (("어머니 나무", 140), ("남동 나무", 140)),
    (("어머니 나무", 380), ("북서 나무", 380)),
    (("어머니 나무", 380), ("북동 나무", 380)),
    (("어머니 나무", 380), ("남서 나무", 380)),
    (("어머니 나무", 380), ("남동 나무", 380)),
    (("어머니 나무", 640), ("남서 나무", 640)),
    (("어머니 나무", 640), ("북서 나무", 640)),
]
# 계단(줄기를 감아 오름) { 나무, 아래, 위 }
STAIRS = [
    ("어머니 나무", GROUND, 140), ("어머니 나무", 140, 380), ("어머니 나무", 380, 640), ("어머니 나무", 640, 900), ("어머니 나무", 900, 1200),
    ("북서 나무", GROUND, 160), ("북동 나무", GROUND, 140), ("남서 나무", GROUND, 140), ("남동 나무", GROUND, 140),
    ("남서 나무", 380, 640),
]
# 숲 길과 만나는 자리(forest_plan.ROADS 끝): 서문→하이우드 (-900, 900), 하이우드→솔르헨 (-900, 1900)
ROAD_ENDS = [(-900, 900), (-900, 1900)]


def giant(name):
    return next(g for g in GIANTS if g[0] == name)


def deck(name, h):
    return next(d for d in DECKS if d[0] == name and d[1] == h)


def check():
    bad = []
    for n, x, z, w, leaf, top in GIANTS:
        r = w / 2 + 10
        for cx, cz in ((x - r, z - r), (x + r, z - r), (x - r, z + r), (x + r, z + r)):
            if not inside((cx, cz), HIGHWOOD):
                bad.append(f"{n} 줄기가 하이우드 밖으로 ({cx},{cz})")
        if top - leaf < 300:
            bad.append(f"{n} 잎 덩어리가 얇다")
    for i, a in enumerate(GIANTS):
        for b in GIANTS[i + 1:]:
            d = math.hypot(a[1] - b[1], a[2] - b[2])
            if d < (a[3] + b[3]) / 2 + 250:
                bad.append(f"{a[0]}–{b[0]} 줄기 사이 {d:.0f} 가 너무 좁다")
    for t, h, ring, name, houses in DECKS:
        g = giant(t)
        if h >= g[4] - 60:
            bad.append(f"{name}: 판이 잎 속({h} ≥ {g[4] - 60})")
        side = g[3] + ring * 2
        if houses > 0 and ring < 50:
            bad.append(f"{name}: 고리 폭 {ring} 로는 집을 못 놓는다")
        # 집 하나 ≈ 고리 폭 0.8 정사각 — 네 변 둘레에 들어가나
        if houses * ring * 0.9 > side * 4 * 0.85:
            bad.append(f"{name}: 집 {houses}채가 판 둘레에 안 들어간다")
    for (ta, ha), (tb, hb) in BRIDGES:
        deck(ta, ha), deck(tb, hb)
        a, b = giant(ta), giant(tb)
        span = math.hypot(a[1] - b[1], a[2] - b[2]) - (a[3] + b[3]) / 2 - deck(ta, ha)[2] - deck(tb, hb)[2]
        if span <= 0:
            bad.append(f"다리 {ta}{ha}–{tb}{hb}: 판끼리 겹친다")
        if abs(ha - hb) / max(span, 1) > 0.25:
            bad.append(f"다리 {ta}{ha}–{tb}{hb}: 기울기 {abs(ha - hb) / max(span, 1):.2f} > 0.25")
    for t, lo, hi in STAIRS:
        giant(t)
        if lo != GROUND:
            deck(t, lo)
        deck(t, hi)
    return bad


def svg():
    # 왼쪽: 위에서 본 그림(하이우드 둘레), 오른쪽: 옆에서 본 그림(x-높이)
    X0, Z0, X1, Z1 = -1850, 380, -800, 2180
    sk = 0.45
    TW, TH = (X1 - X0) * sk, (Z1 - Z0) * sk
    SW, SH = 620, TH
    hs = SH / 2150  # 높이 비
    o = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{TW + SW + 40:.0f}" height="{TH + 40:.0f}" font-family="Malgun Gothic, sans-serif">',
         f'<rect width="{TW + SW + 40:.0f}" height="{TH + 40:.0f}" fill="#1b2a1e"/>']

    def P(x, z):
        return (20 + (x - X0) * sk, 20 + (z - Z0) * sk)

    hw = " ".join("%.1f,%.1f" % P(x, z) for x, z in HIGHWOOD)
    o.append(f'<polygon points="{hw}" fill="#2f4f32" stroke="#8fb8e8" stroke-width="2"/>')
    for x, z in ROAD_ENDS:
        px, pz = P(x, z)
        o.append(f'<rect x="{px - 2}" y="{pz - 8}" width="40" height="16" fill="#b08850"/>')
    for (ta, ha), (tb, hb) in BRIDGES:
        a, b = giant(ta), giant(tb)
        (ax, az), (bx, bz) = P(a[1], a[2]), P(b[1], b[2])
        o.append(f'<line x1="{ax}" y1="{az}" x2="{bx}" y2="{bz}" stroke="#c8a060" stroke-width="{3 if ha < 300 else 2}" stroke-dasharray="{"" if ha < 300 else "6 3"}"/>')
    for n, x, z, w, leaf, top in GIANTS:
        rings = [d for d in DECKS if d[0] == n]
        widest = max(d[2] for d in rings)
        px, pz = P(x - w / 2 - widest, z - w / 2 - widest)
        s = (w + 2 * widest) * sk
        o.append(f'<rect x="{px}" y="{pz}" width="{s}" height="{s}" fill="#9a7a50" fill-opacity="0.7" stroke="#e8d0a0"/>')
        px, pz = P(x - w / 2, z - w / 2)
        o.append(f'<rect x="{px}" y="{pz}" width="{w * sk}" height="{w * sk}" fill="#4a3320"/>')
        cx, cz = P(x, z)
        o.append(f'<text x="{cx}" y="{cz + 4}" font-size="11" fill="#fff" text-anchor="middle" font-weight="700">{n}</text>')
        o.append(f'<text x="{cx}" y="{cz + 17}" font-size="9" fill="#e8d0a0" text-anchor="middle">높이 {top}</text>')
    o.append(f'<text x="24" y="{TH + 34}" font-size="11" fill="#cde">위에서 본 하이우드 · 갈색 네모 = 판(가장 넓은 고리) · 선 = 다리(점선 = 위층) · 주황 = 숲길 끝</text>')
    # 옆 그림
    ox = TW + 40
    gy = 20 + SH
    o.append(f'<line x1="{ox}" y1="{gy}" x2="{ox + SW - 20}" y2="{gy}" stroke="#6a8a5a" stroke-width="2"/>')
    order = sorted(GIANTS, key=lambda g: g[1])
    slot = (SW - 60) / len(order)
    for k, (n, x, z, w, leaf, top) in enumerate(order):
        cx = ox + 40 + slot * (k + 0.5)
        tw = w * hs  # 높이와 같은 축척
        o.append(f'<rect x="{cx - tw / 2}" y="{gy - top * hs}" width="{tw}" height="{top * hs}" fill="#4a3320"/>')
        cw = min(slot * 1.6, tw * 2.6)
        o.append(f'<rect x="{cx - cw / 2}" y="{gy - top * hs}" width="{cw}" height="{(top - leaf) * hs}" fill="#2f6a34" fill-opacity="0.85"/>')
        for t, h, ring, name, houses in DECKS:
            if t == n:
                dw = (w + 2 * ring) * hs
                o.append(f'<rect x="{cx - dw / 2}" y="{gy - h * hs - 2}" width="{dw}" height="3" fill="#e8d0a0"/>')
        o.append(f'<text x="{cx}" y="{gy + 14}" font-size="9" fill="#cde" text-anchor="middle">{n}</text>')
    for h in (100, 500, 1000, 1500, 2000):
        o.append(f'<text x="{ox}" y="{gy - h * hs + 3}" font-size="8" fill="#8a9">{h}</text>')
    # 비교: 숲 거목 90
    o.append(f'<rect x="{ox + SW - 40}" y="{gy - 90 * hs}" width="4" height="{90 * hs}" fill="#9c6"/>')
    o.append(f'<text x="{ox + SW - 38}" y="{gy - 90 * hs - 4}" font-size="8" fill="#9c6" text-anchor="middle">숲 거목 90</text>')
    o.append(f'<text x="{ox}" y="{TH + 34}" font-size="11" fill="#cde">옆에서 본 높이(동서 순) · 노란 줄 = 판 · 초록 = 잎 덩어리</text>')
    o.append("</svg>")
    return "\n".join(o)


if __name__ == "__main__":
    problems = check()
    for p in problems:
        print("문제:", p)
    open(os.path.join(HERE, "highwood_plan.svg"), "w", encoding="utf-8").write(svg())
    print(f"거대수 {len(GIANTS)}, 판 {len(DECKS)}(집 {sum(d[4] for d in DECKS)}), 다리 {len(BRIDGES)}, 계단 {len(STAIRS)}, 문제 {len(problems)}건")
