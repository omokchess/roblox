# -*- coding: utf-8 -*-
"""
forest_plan.py — 2026-10-09. 숲+평원 리메이크 배치표(1단계: 구역 나누기) → 평면도 SVG.

사용자 그림(C:\\프롬때 쓴 그림판\\숲 지도.jpg, 2026-10-09):
  - 평원(절화가 있는 지금 평원 섬)은 숲 **안**에 있다. 그림 아래쪽은 그 평원을 확대한 것.
  - 평원 둘레는 나무 빽빽(띠). 숲 크기 ≈ 설원 크기(지금 설원 동서 ≈ 4800).
  - 맥동(지하에 보스룸) = 숲 북쪽 가장자리 가운데, 하이우드(마을) = 숲 남서, 솔르헨의 구역 = 숲 남쪽 끝 가운데(하이우드에서 길),
    순례자의 휴식처(전직 퀘템 1/8) = 숲 북서, (3/8) = 평원 남서. 나머지는 필드. 숲 가운데 회색 돌산은 삭제.
그림 → 월드: 평원 상자가 지금 평원 섬(x -756~1182, z -242~1059)에 맞게 그림 1px ≈ 5.3 스터드.
  북쪽은 탑의 성역(z ≤ -769)이 있어 평원 위 띠를 좁혔다(그림 대비 ×0.47). 동쪽은 늪(x ≥ 1395) 앞에서 멈춘다.
좌표 = 월드(x 동, z 남; 북 = -z). 돌리기: python tools/forest_plan.py → tools/forest_plan.svg (+ 겹침 검사)
"""
import os

HERE = os.path.dirname(os.path.abspath(__file__))

# ── 2판(2026-10-09 사용자: "평원 크기를 줄이면서 숲 크기도 줄이자. 절화가 다른 마을보다 엄청 커서 줄여도 돼. 나무 너무 빽빽") ──
# 절화: 궁·광장·저자·저잣마당·관아·주막·서촌길가·동촌·척수관·마방만 남기고(≈640×660, 옛 1010×760) 서촌·북촌·남촌·산정자는 백업으로.
# 평원 = 남긴 절화 + 들판 둘레. 숲 = 그림 비율 그대로 ×0.6 정도로 줄임(옛 4600 → 약 2750×2840).
JEOLHWA_KEEP = ["궁", "광장", "저자", "저잣마당", "관아", "주막", "서촌길가", "동촌", "척수관", "마방"]
JEOLHWA_DROP = ["서촌", "북촌", "남촌", "산정자"]
JEOLHWA = (20, 300, 660, 960)  # 남긴 절화 경계(x0, z0, x1, z1)
JEOLHWA_OLD = (-305, 199, 705, 957)
DISTRICTS = {  # 스튜디오에서 잰 구역 경계(그림용)
    "궁": (20, 637, 430, 957), "광장": (177, 440, 273, 602), "저자": (318, 471, 458, 632), "저잣마당": (477, 530, 592, 628),
    "관아": (180, 300, 270, 398), "주막": (61, 492, 136, 530), "서촌길가": (27, 578, 138, 614), "동촌": (466, 719, 601, 832),
    "척수관": (584, 785, 657, 911), "마방": (602, 490, 614, 494),
    "서촌": (-270, 409, 89, 842), "북촌": (-176, 614, -7, 944), "남촌": (-244, 252, 590, 362), "산정자": (692, 250, 705, 250),
}
PLAINS = (-200, 110, 880, 1059)  # 새 평원(x0, z0, x1, z1) — 남쪽은 옛 평원 남쪽 끝 그대로
PLAINS_OLD = (-756, -242, 1182, 1059)

# 숲 땅 윤곽(축에 맞춘 계단식 다각형, 시계 방향) — 그림 꼴(북서 턱·맥동 돌출·동쪽 곧은 변·솔르헨 돌출·남서 계단)
FOREST = [
    (-1700, -120), (-1460, -120), (-1460, -170), (-860, -170), (-860, -240), (-240, -240), (-240, -170), (400, -170),
    (400, -40), (1000, -40), (1000, 2350), (80, 2350), (80, 2600), (-560, 2600), (-560, 2080), (-1400, 2080),
    (-1400, 1820), (-1750, 1820), (-1750, 620), (-1700, 620),
]

# 구역 { 이름, x0, z0, x1, z1, 색 }
ZONES = [
    ("맥동 (지하 보스룸)", -860, -240, -240, -30, "#f0b48c"),
    ("솔르헨의 구역", -560, 2080, 80, 2600, "#e6d24a"),
]
# 하이우드(마을) — 숲 남서 구석 전부(사용자: 빈공간 없이)
HIGHWOOD = [
    (-1700, 470), (-900, 470), (-900, 2080), (-1400, 2080), (-1400, 1820), (-1750, 1820), (-1750, 620), (-1700, 620),
]

# 점 표시 { 이름, x, z, 색 }
SPOTS = [
    ("순례자의 휴식처 1/8", -1550, -60, "#2f5fd0"),
    ("순례자의 휴식처 3/8", -150, 950, "#2f5fd0"),
]
# 길(꺾은선) { 이름, 점들 }
ROADS = [
    ("하이우드 → 솔르헨", [(-900, 1900), (-450, 1900), (-450, 2080)]),
    ("평원 서문 → 하이우드", [(-200, 640), (-650, 640), (-650, 900), (-900, 900)]),
    ("평원 서문 → 맥동", [(-650, 640), (-650, -30)]),
    ("평원 남문 → 솔르헨", [(340, 1059), (340, 1700), (-240, 1700), (-240, 2080)]),
]

# 큰 나무(사용자: "나무 너무 빽빽 → 커다란 나무 몇개") { x, z, 크기 배율 } — 손으로. 길(±20)·구역·평원을 비켜서
BIG_TREES = [
    # 북쪽 띠
    (-1550, 40, 1.8), (-1300, -60, 2.2), (-1050, 60, 1.6), (-120, -120, 2.0), (150, 10, 1.7), (520, 40, 1.9), (800, 30, 1.4), (930, 300, 1.5),
    # 서쪽(맥동 남쪽 ~ 하이우드 위)
    (-1500, 250, 2.0), (-1250, 420, 1.7), (-950, 180, 2.3), (-800, 450, 1.6), (-420, 300, 1.9), (-400, 60, 1.5), (-1150, 380, 1.4),
    # 하이우드와 평원 사이
    (-780, 780, 2.0), (-450, 820, 1.7), (-350, 1000, 1.6), (-800, 1050, 1.9), (-500, 1200, 2.2),
    # 동쪽 좁은 띠
    (940, 600, 1.4), (940, 950, 1.5),
    # 남쪽
    (-700, 1350, 2.0), (-300, 1450, 1.8), (80, 1300, 2.4), (560, 1250, 1.7), (800, 1500, 2.0), (150, 1550, 1.6), (-600, 1600, 1.7),
    (-100, 1850, 2.1), (600, 1850, 1.9), (850, 2100, 2.2), (300, 2200, 1.8), (560, 2250, 1.6), (-800, 1700, 1.5), (-750, 2000, 1.8),
]
# 1판 숲 윤곽(그림 비교용 — 지금 Studio 의 R_숲2)
FOREST_V1 = [
    (-3190, -342), (-2792, -342), (-2792, -418), (-1740, -418), (-1740, -640), (-1600, -640), (-1600, -790), (-500, -790),
    (-500, -640), (706, -640), (706, -417), (1330, -417), (1330, 3418), (-222, 3418), (-222, 3815), (-1255, 3815),
    (-1255, 2967), (-2633, 2967), (-2633, 2543), (-3269, 2543), (-3269, 914), (-3190, 914),
]

# 맥락: 지금 있는 것(건드리지 않음 / 갈아엎을 것)
CONTEXT = [
    # 스튜디오 조사(2026-10-09 Forest_Survey): 타일 경계 상자
    ("탑의 성역", -349, -2216, 1145, -712, "#b8b8c8"),
    ("오염지대", -3550, -2080, -1798, -478, "#9a8fb0"),
    ("사막", 1660, -1330, 3600, -300, "#e8cf9a"),
    ("늪(다음 차례)", 1395, 469, 3295, 1682, "#8fae8a"),
]
OLD_FOREST = (-1610, 523, 900)  # 지금 둥근 숲 섬(가운데 돌산) — 갈아엎는다


def inside(pt, poly):
    x, z = pt
    n, hit = len(poly), False
    for i in range(n):
        (ax, az), (bx, bz) = poly[i], poly[(i + 1) % n]
        if (az > z) != (bz > z) and x < ax + (z - az) * (bx - ax) / (bz - az):
            hit = not hit
    return hit


def check():
    bad = []
    for name, x0, z0, x1, z1, _ in ZONES:
        for c in ((x0, z0), (x1, z0), (x0, z1), (x1, z1)):
            c2 = (c[0] + (1 if c[0] == x0 else -1), c[1] + (1 if c[1] == z0 else -1))
            if not inside(c2, FOREST):
                bad.append(f"{name} 모서리 {c} 가 숲 밖")
    for name, x0, z0, x1, z1, _ in CONTEXT:
        for x, z in ((x0, z0), (x1, z0), (x0, z1), (x1, z1), ((x0 + x1) / 2, (z0 + z1) / 2)):
            if inside((x, z), FOREST):
                bad.append(f"숲이 {name} 을 덮는다 ({x},{z})")
        fx0, fx1 = min(p[0] for p in FOREST), max(p[0] for p in FOREST)
        # 그 상자 x 범위 안 숲 윤곽의 가장 북쪽
        fz0 = min([p[1] for p in FOREST if x0 <= p[0] <= x1] or [99999])
        if name in ("탑의 성역", "오염지대") and fz0 - z1 < 60:
            bad.append(f"{name}과 틈 {fz0 - z1} < 60")
        if name.startswith("늪") and x0 - fx1 < 50:
            bad.append(f"늪과 틈 {x0 - fx1} < 50")
    for x, z in HIGHWOOD:
        # 꼭짓점 둘레 네 대각 중 하이우드 안쪽인 점이 숲 안이어야
        qs = [(x + dx, z + dz) for dx in (-2, 2) for dz in (-2, 2) if inside((x + dx, z + dz), HIGHWOOD)]
        if not qs or not all(inside(q, FOREST) for q in qs):
            bad.append(f"하이우드 꼭짓점 {(x, z)} 가 숲 밖")
    for name, x, z, _ in SPOTS:
        if not inside((x, z), FOREST) and not (PLAINS[0] < x < PLAINS[2] and PLAINS[1] < z < PLAINS[3]):
            bad.append(f"{name} 이 숲·평원 밖")
    import math

    def seg_d(px, pz, ax, az, bx, bz):
        dx, dz = bx - ax, bz - az
        t = max(0.0, min(1.0, ((px - ax) * dx + (pz - az) * dz) / (dx * dx + dz * dz)))
        return math.hypot(px - (ax + t * dx), pz - (az + t * dz))

    for x, z, sc in BIG_TREES:
        r = 19 * sc
        where = f"큰 나무 ({x},{z})"
        if not inside((x, z), FOREST) or any(seg_d(x, z, *FOREST[i], *FOREST[(i + 1) % len(FOREST)]) < r for i in range(len(FOREST))):
            bad.append(where + " 가 숲 가장자리 밖·걸침")
        if PLAINS[0] - r < x < PLAINS[2] + r and PLAINS[1] - r < z < PLAINS[3] + r:
            bad.append(where + " 가 평원에 걸침")
        if inside((x, z), HIGHWOOD):
            bad.append(where + " 가 하이우드 안")
        for name, x0, z0, x1, z1, _ in ZONES:
            if x0 - r < x < x1 + r and z0 - r < z < z1 + r:
                bad.append(where + f" 가 {name} 에 걸침")
        for name, pts in ROADS:
            for k in range(len(pts) - 1):
                if seg_d(x, z, *pts[k], *pts[k + 1]) < r * 0.6 + 12:
                    bad.append(where + f" 가 길({name})에 걸침")
    return bad


def svg():
    X0, Z0, X1, Z1 = -3500, -2250, 1700, 4000
    k = 0.19
    W, H = (X1 - X0) * k, (Z1 - Z0) * k
    out = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W:.0f}" height="{H:.0f}" viewBox="{X0} {Z0} {X1 - X0} {Z1 - Z0}" font-family="Malgun Gothic, sans-serif">',
           '<defs><pattern id="h" width="160" height="160" patternUnits="userSpaceOnUse" patternTransform="rotate(-35)">'
           '<line x1="0" y1="0" x2="0" y2="160" stroke="#d24a3c" stroke-width="10" stroke-opacity="0.55"/></pattern></defs>',
           f'<rect x="{X0}" y="{Z0}" width="{X1 - X0}" height="{Z1 - Z0}" fill="#1f6f9a"/>']

    def rect(x0, z0, x1, z1, fill, op=1, stroke=None, sw=0, dash=None):
        s = f' stroke="{stroke}" stroke-width="{sw}"' if stroke else ""
        d = f' stroke-dasharray="{dash}"' if dash else ""
        out.append(f'<rect x="{x0}" y="{z0}" width="{x1 - x0}" height="{z1 - z0}" fill="{fill}" fill-opacity="{op}"{s}{d}/>')

    def label(x, z, t, size=70, col="#111", anchor="middle"):
        out.append(f'<text x="{x}" y="{z}" font-size="{size}" fill="{col}" text-anchor="{anchor}" font-weight="700" '
                   f'stroke="#ffffff" stroke-width="{size / 9:.0f}" paint-order="stroke">{t}</text>')

    for name, x0, z0, x1, z1, col in CONTEXT:
        rect(x0, z0, x1, z1, col, 0.85)
        label((x0 + x1) / 2, (z0 + z1) / 2, name, 80, "#333")
    pts = " ".join(f"{x},{z}" for x, z in FOREST)
    out.append(f'<polygon points="{pts}" fill="#2f6b34" stroke="#183d1b" stroke-width="18"/>')
    out.append(f'<polygon points="{pts}" fill="url(#h)"/>')
    v1 = " ".join(f"{x},{z}" for x, z in FOREST_V1)
    out.append(f'<polygon points="{v1}" fill="none" stroke="#ffffff" stroke-width="12" stroke-dasharray="50 35"/>')
    rect(*PLAINS, "#8fbf5a", 1)
    out.append(f'<rect x="{PLAINS[0]}" y="{PLAINS[1]}" width="{PLAINS[2] - PLAINS[0]}" height="{PLAINS[3] - PLAINS[1]}" fill="url(#h)"/>')
    po = PLAINS_OLD
    out.append(f'<rect x="{po[0]}" y="{po[1]}" width="{po[2] - po[0]}" height="{po[3] - po[1]}" fill="none" stroke="#f4f0a0" stroke-width="12" stroke-dasharray="40 30"/>')
    for name, (x0, z0, x1, z1) in DISTRICTS.items():
        keep = name in JEOLHWA_KEEP
        x1, z1 = max(x1, x0 + 12), max(z1, z0 + 12)
        rect(x0, z0, x1, z1, "#e8dcc4" if keep else "#d24a3c", 0.95 if keep else 0.75, "#333", 6)
        label((x0 + x1) / 2, (z0 + z1) / 2 + 12, name, 34, "#222" if keep else "#fff")
    jx0, jz0, jx1, jz1 = JEOLHWA
    out.append(f'<rect x="{jx0}" y="{jz0}" width="{jx1 - jx0}" height="{jz1 - jz0}" fill="none" stroke="#111" stroke-width="10"/>')
    label((jx0 + jx1) / 2, jz0 - 25, "절화 (남김 ≈640×660)", 48)
    label((PLAINS[0] + PLAINS[2]) / 2, PLAINS[3] - 30, "새 평원", 60)
    label(po[0] + 20, po[1] - 20, "옛 평원", 50, "#f4f0a0", "start")
    hw = " ".join(f"{x},{z}" for x, z in HIGHWOOD)
    out.append(f'<polygon points="{hw}" fill="#5aa0e6" fill-opacity="0.9" stroke="#222" stroke-width="10"/>')
    label(-1320, 1300, "하이우드 (마을)", 70)
    for x, z, sc in BIG_TREES:
        out.append(f'<circle cx="{x}" cy="{z}" r="{19 * sc:.0f}" fill="#163f1c" stroke="#0a220d" stroke-width="5"/>')
    for name, x0, z0, x1, z1, col in ZONES:
        rect(x0, z0, x1, z1, col, 0.9, "#222", 10)
        label((x0 + x1) / 2, (z0 + z1) / 2 + 25, name, 75)
    for name, p in ROADS:
        d = " ".join(f"{x},{z}" for x, z in p)
        out.append(f'<polyline points="{d}" fill="none" stroke="#3aa0ff" stroke-width="40"/>')
        label(p[1][0], p[1][1] - 50, name, 55, "#0b3d78")
    for name, x, z, col in SPOTS:
        rect(x - 45, z - 45, x + 45, z + 45, col, 1, "#fff", 10)
        label(x + 70, z + 20, name, 58, "#0b2a6b", "start")
    label(250, 1450, "필드 (숲)", 90, "#7a1d14")
    label(-2400, 3000, "흰 점선 = 1판 숲(지금 지어진 것)", 60, "#fff")
    # 축척·방위
    rect(-3300, 3700, -2300, 3740, "#fff")
    label(-2800, 3690, "1000 스터드", 60, "#fff")
    label(1500, -2100, "북 ↑", 80, "#fff", "end")
    out.append("</svg>")
    return "\n".join(out)


if __name__ == "__main__":
    problems = check()
    for p in problems:
        print("문제:", p)
    open(os.path.join(HERE, "forest_plan.svg"), "w", encoding="utf-8").write(svg())
    xs, zs = [p[0] for p in FOREST], [p[1] for p in FOREST]
    print(f"숲 {max(xs) - min(xs)} × {max(zs) - min(zs)} 스터드, 문제 {len(problems)}건")
