# -*- coding: utf-8 -*-
"""
forest_plan.py — 2026-10-09. 숲+평원 리메이크 배치표(1단계: 구역 나누기) → 평면도 SVG.

사용자 그림(C:\\프롬때 쓴 그림판\\숲 지도.jpg, 2026-10-09):
  - 평원(절화가 있는 지금 평원 섬)은 숲 **안**에 있다. 그림 아래쪽은 그 평원을 확대한 것.
  - 평원 둘레는 나무 빽빽(띠). 숲 크기 ≈ 설원 크기(지금 설원 동서 ≈ 4800).
  - 맥동(지하에 보스룸) = 숲 북쪽 가장자리 가운데, 하이우드(마을) = 숲 남서, 솔리테의 기억 = 숲 남쪽 끝 가운데(하이우드에서 길),
    순례자의 휴식처(전직 퀘템 1/8) = 숲 북서, (3/8) = 평원 남서. 나머지는 필드. 숲 가운데 회색 돌산은 삭제.
그림 → 월드: 평원 상자가 지금 평원 섬(x -756~1182, z -242~1059)에 맞게 그림 1px ≈ 5.3 스터드.
  북쪽은 탑의 성역(z ≤ -769)이 있어 평원 위 띠를 좁혔다(그림 대비 ×0.47). 동쪽은 늪(x ≥ 1395) 앞에서 멈춘다.
좌표 = 월드(x 동, z 남; 북 = -z). 돌리기: python tools/forest_plan.py → tools/forest_plan.svg (+ 겹침 검사)
"""
import os

HERE = os.path.dirname(os.path.abspath(__file__))

# 숲 땅 윤곽(축에 맞춘 계단식 다각형, 시계 방향)
FOREST = [
    (-3190, -342), (-2792, -342), (-2792, -692), (-1450, -692), (-1450, -790), (-350, -790), (-350, -692), (706, -692), (706, -417), (1330, -417),
    (1330, 3418), (-222, 3418), (-222, 3815), (-1255, 3815), (-1255, 2967), (-2633, 2967),
    (-2633, 2543), (-3269, 2543), (-3269, 914), (-3190, 914),
]
# 평원(지금 섬 그대로 — 절화) / 그 둘레 나무 빽빽 띠
PLAINS = (-756, -242, 1182, 1059)
BELT = (-1020, -330, 1250, 1280)
JEOLHWA = (-305, 199, 705, 957)

# 구역 { 이름, x0, z0, x1, z1, 색 }
ZONES = [
    ("하이우드 (마을 1000×1000)", -2960, 1200, -1960, 2200, "#5aa0e6"),
    ("맥동 (지하 보스룸)", -1450, -790, -350, -450, "#f0b48c"),
    ("솔리테의 기억", -1255, 2967, -222, 3815, "#e6d24a"),
]
# 점 표시 { 이름, x, z, 색 }
SPOTS = [
    ("순례자의 휴식처 1/8", -2633, -592, "#2f5fd0"),
    ("순례자의 휴식처 3/8", -705, 786, "#2f5fd0"),
]
# 길(꺾은선) { 이름, 점들 }
ROADS = [
    ("하이우드 → 솔리테", [(-1960, 2384), (-1157, 2384), (-1157, 2967)]),
]

# 맥락: 지금 있는 것(건드리지 않음 / 갈아엎을 것)
CONTEXT = [
    ("탑의 성역", -287, -2145, 1078, -769, "#b8b8c8"),
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
        if name == "탑의 성역" and fz0 - z1 < 60:
            bad.append(f"탑의 성역과 틈 {fz0 - z1} < 60")
        if name.startswith("늪") and x0 - fx1 < 50:
            bad.append(f"늪과 틈 {x0 - fx1} < 50")
    for name, x, z, _ in SPOTS:
        if not inside((x, z), FOREST) and not (PLAINS[0] < x < PLAINS[2] and PLAINS[1] < z < PLAINS[3]):
            bad.append(f"{name} 이 숲·평원 밖")
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
    cx, cz, r = OLD_FOREST
    pts = " ".join(f"{x},{z}" for x, z in FOREST)
    out.append(f'<polygon points="{pts}" fill="#2f6b34" stroke="#183d1b" stroke-width="18"/>')
    out.append(f'<polygon points="{pts}" fill="url(#h)"/>')
    rect(*BELT, "#123a16", 1)
    label((BELT[0] + BELT[2]) / 2, BELT[3] - 40, "나무 빽빽", 60, "#cfe8c8")
    rect(*PLAINS, "#8fbf5a", 1)
    out.append(f'<rect x="{PLAINS[0]}" y="{PLAINS[1]}" width="{PLAINS[2] - PLAINS[0]}" height="{PLAINS[3] - PLAINS[1]}" fill="url(#h)"/>')
    rect(*JEOLHWA, "#d8d0c0", 1, "#333", 10)
    label((JEOLHWA[0] + JEOLHWA[2]) / 2, (JEOLHWA[1] + JEOLHWA[3]) / 2 + 30, "절화 (그대로)", 80)
    label((PLAINS[0] + PLAINS[2]) / 2, PLAINS[1] + 110, "평원 (지금 섬 그대로)", 75)
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
    out.append(f'<circle cx="{cx}" cy="{cz}" r="{r}" fill="none" stroke="#ffffff" stroke-width="14" stroke-dasharray="40 30"/>')
    label(-900, 1000, "필드 (숲)", 110, "#7a1d14")
    label(cx, cz + r + 90, "지금 둥근 숲 섬 + 가운데 돌산 → 갈아엎음", 55, "#fff")
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
