# -*- coding: utf-8 -*-
"""
forest_ground.py — 2026-10-09. 숲+평원 리메이크 2단계: 숲 땅 판 + 바닷가(손 표) → tools/Forest_Build_data.luau.

  땅 판: forest_plan.FOREST 다각형에서 평원 땅 판(스튜디오에서 뽑은 Land 상자, PLAINS_LAND)을 뺀 자리.
         평원 테두리 안쪽으로 파인 바다(해안 굴곡)는 숲 땅으로 메우고, 평원 땅에 둘러싸인 구멍은 그대로 둔다.
         판 하나 2048 이하로 자르고, 윗면 TOP(평원 땅 1.8·2.0 의 가운데).
  바닷가: 숲 바깥 변마다 손으로 적은 토막(COAST) — (길이, 높이, 깊이) 바위 벼랑(윗면 풀) 또는 ("S", 길이) 모래 계단.
         길이 None = 그 변 나머지. 볼록 모서리는 끝 토막을 깊이만큼 늘려 이음매를 막는다.
  묻히는 평원 바닷가 조각: 짓기(Forest_Build)가 직접 고른다(윗면 < 3.5 + 숲 판과 겹침, 몸·_풀 짝째) — 여기 buried() 는 개수 참고용.
돌리기: python tools/forest_ground.py  (문제 0건이어야) → 짓기: tools/Forest_Build.luau 머리 주석
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from forest_plan import FOREST, inside  # noqa: E402

TOP = 1.9
BOTTOM = -6.0
MAXP = 2000  # 판 한 변 상한(로블록스 2048)

# 스튜디오 Plains_EdgeDump(2026-10-09) 의 평원 Land 판 { x0, x1, z0, z1 } — 정수로
PLAINS_LAND = [
    (-420, -160, -130, 200), (-600, -420, -60, 200), (140, 420, -230, 200), (420, 640, -150, 200),
    (900, 1080, -40, 200), (-160, 140, -170, 200), (640, 900, -110, 200),
    (700, 1150, 290, 600), (700, 1130, 600, 880), (860, 1150, 200, 290), (700, 1000, 880, 980), (1080, 1150, 120, 200),
    (-745, -600, 60, 200), (-560, 760, 980, 1050), (-745, 700, 200, 980),
]

# 바닷가 손 표: 변 번호(FOREST 꼭짓점 i → i+1) → 토막들. (길이, 벼랑 높이(땅 위), 깊이) / ("S", 길이) 모래 계단
COAST = {
    0: [(140, 6, 24), (120, 11, 26), (None, 4, 22)],
    1: [(None, 8, 24)],
    2: [(160, 3, 22), (220, 9, 28), (130, 14, 26), (200, 5, 24), (180, 10, 26), (None, 2, 22)],
    3: [(110, 12, 26), (None, 7, 24)],
    4: [(None, 9, 24)],
    5: [(None, 16, 28)],
    6: [(180, 18, 30), (160, 12, 26), (240, 22, 32), (200, 14, 28), (None, 19, 30)],  # 맥동 앞(북) — 높게
    7: [(None, 15, 28)],
    8: [(200, 4, 22), (170, 8, 24), (260, 2, 22), (190, 11, 26), (200, 5, 24), (None, 7, 24)],
    9: [(None, 9, 26)],
    10: [(200, 6, 24), (220, 3, 22), (None, 10, 26)],
    11: [(300, 8, 26), (250, 3, 22), ("S", 420), (280, 12, 28), (350, 6, 24), (300, 14, 28), ("S", 380), (260, 5, 24),
         (320, 10, 26), (300, 4, 22), (None, 9, 26)],  # 동쪽(늪 쪽) 긴 해안
    12: [(260, 7, 24), ("S", 360), (300, 11, 26), (240, 4, 22), (None, 9, 26)],
    13: [(200, 13, 28), (None, 8, 24)],
    14: [(220, 16, 30), (300, 10, 26), (260, 18, 30), (None, 12, 28)],  # 솔르헨 남쪽 끝 — 높게
    15: [(240, 9, 26), (300, 14, 28), (None, 6, 24)],
    16: [(300, 5, 24), ("S", 420), (280, 9, 26), (None, 3, 22)],  # 하이우드 남쪽
    17: [(200, 7, 24), (None, 11, 26)],
    18: [(260, 4, 22), (None, 8, 24)],
    19: [(280, 10, 26), (320, 5, 24), ("S", 360), (300, 12, 28), (None, 6, 24)],  # 하이우드 서쪽
    20: [(None, 6, 24)],
    21: [(260, 9, 26), (300, 4, 22), (240, 13, 28), (None, 7, 24)],
}
SAND = [(26, 0.3), (22, -1.9)]  # 모래 계단 (깊이, 윗면) — 평원 모래와 같은 값


def in_plains_land(x, z):
    return any(a <= x <= b and c <= z <= d for a, b, c, d in PLAINS_LAND)


def ground_rects():
    xs = sorted({p[0] for p in FOREST} | {r[0] for r in PLAINS_LAND} | {r[1] for r in PLAINS_LAND})
    zs = sorted({p[1] for p in FOREST} | {r[2] for r in PLAINS_LAND} | {r[3] for r in PLAINS_LAND})
    nx, nz = len(xs) - 1, len(zs) - 1
    cell = [[False] * nz for _ in range(nx)]
    land = [[False] * nz for _ in range(nx)]
    for i in range(nx):
        for j in range(nz):
            cx, cz = (xs[i] + xs[i + 1]) / 2, (zs[j] + zs[j + 1]) / 2
            land[i][j] = in_plains_land(cx, cz)
            cell[i][j] = inside((cx, cz), FOREST) and not land[i][j]
    # 평원 땅에 둘러싸인 구멍: 평원 경계 상자 안, 땅 아닌 칸 중 상자 밖으로 이어지지 않는 것 → 채우지 않는다
    bx0, bx1 = min(r[0] for r in PLAINS_LAND), max(r[1] for r in PLAINS_LAND)
    bz0, bz1 = min(r[2] for r in PLAINS_LAND), max(r[3] for r in PLAINS_LAND)
    inbox = [[bx0 <= (xs[i] + xs[i + 1]) / 2 <= bx1 and bz0 <= (zs[j] + zs[j + 1]) / 2 <= bz1 for j in range(nz)] for i in range(nx)]
    seen = [[False] * nz for _ in range(nx)]
    stack = [(i, j) for i in range(nx) for j in range(nz) if not land[i][j] and not inbox[i][j]]
    for i, j in stack:
        seen[i][j] = True
    while stack:
        i, j = stack.pop()
        for di, dj in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            a, b = i + di, j + dj
            if 0 <= a < nx and 0 <= b < nz and not seen[a][b] and not land[a][b]:
                seen[a][b] = True
                stack.append((a, b))
    holes = 0
    for i in range(nx):
        for j in range(nz):
            if cell[i][j] and inbox[i][j] and not seen[i][j]:
                cell[i][j] = False
                holes += 1
    # 칸 묶기: z 방향으로 이어 붙이고 → 같은 z 범위면 x 로 이어 붙인다
    rects = []
    used = [[False] * nz for _ in range(nx)]
    for i in range(nx):
        for j in range(nz):
            if not cell[i][j] or used[i][j]:
                continue
            j2 = j
            while j2 + 1 < nz and cell[i][j2 + 1] and not used[i][j2 + 1]:
                j2 += 1
            i2 = i
            while i2 + 1 < nx and all(cell[i2 + 1][k] and not used[i2 + 1][k] for k in range(j, j2 + 1)):
                i2 += 1
            for a in range(i, i2 + 1):
                for b in range(j, j2 + 1):
                    used[a][b] = True
            rects.append((xs[i], xs[i2 + 1], zs[j], zs[j2 + 1]))
    # 2000 넘는 판 자르기
    out = []
    for x0, x1, z0, z1 in rects:
        nxp = max(1, -(-(x1 - x0) // MAXP))
        nzp = max(1, -(-(z1 - z0) // MAXP))
        for a in range(int(nxp)):
            for b in range(int(nzp)):
                out.append((x0 + (x1 - x0) * a / nxp, x0 + (x1 - x0) * (a + 1) / nxp, z0 + (z1 - z0) * b / nzp, z0 + (z1 - z0) * (b + 1) / nzp))
    return out, holes


def signed_area(poly):
    return sum(poly[i][0] * poly[(i + 1) % len(poly)][1] - poly[(i + 1) % len(poly)][0] * poly[i][1] for i in range(len(poly))) / 2


def coast():
    """→ 벼랑 상자 [(x0,x1,z0,z1,top)], 모래 [(x0,x1,z0,z1,top)], 문제들"""
    bad, cliffs, sands = [], [], []
    n = len(FOREST)
    for i in range(n):
        (ax, az), (bx, bz) = FOREST[i], FOREST[(i + 1) % n]
        L = abs(bx - ax) + abs(bz - az)
        ux, uz = (bx - ax) / L, (bz - az) / L
        # 바깥쪽: 변 가운데에서 왼쪽·오른쪽 중 숲 밖인 쪽
        mx, mz = (ax + bx) / 2, (az + bz) / 2
        ox, oz = -uz, ux
        if inside((mx + ox * 3, mz + oz * 3), FOREST):
            ox, oz = -ox, -oz

        def convex(k):  # 꼭짓점 k 가 볼록인가(그 자리 바깥 대각이 숲 밖)
            p, q, r = FOREST[k - 1], FOREST[k], FOREST[(k + 1) % n]
            cross = (q[0] - p[0]) * (r[1] - q[1]) - (q[1] - p[1]) * (r[0] - q[0])
            return (cross > 0) == (signed_area(FOREST) > 0)

        segs = COAST[i]
        fixed = sum(s[1] if s[0] == "S" else s[0] for s in segs if s[0] is not None and (s[0] == "S" or s[0] is not None))
        fixed = sum((s[1] if s[0] == "S" else s[0]) for s in segs if not (s[0] is None))
        rest = L - fixed
        if rest < 40 and any(s[0] is None for s in segs):
            bad.append(f"변 {i}: 남는 길이 {rest:.0f} < 40")
        if not any(s[0] is None for s in segs) and abs(rest) > 0.5:
            bad.append(f"변 {i}: 토막 합 {fixed} ≠ 변 길이 {L}")
        t = 0.0
        for k, s in enumerate(segs):
            seg_len = rest if s[0] is None else (s[1] if s[0] == "S" else s[0])
            s0, s1 = t, t + seg_len
            t = s1
            if s[0] == "S":
                d0 = 0.0
                for depth, top in SAND:
                    p0 = (ax + ux * s0 + ox * d0, az + uz * s0 + oz * d0)
                    p1 = (ax + ux * s1 + ox * (d0 + depth), az + uz * s1 + oz * (d0 + depth))
                    sands.append((min(p0[0], p1[0]), max(p0[0], p1[0]), min(p0[1], p1[1]), max(p0[1], p1[1]), top))
                    d0 += depth
                continue
            h, depth = s[1], s[2]
            e0, e1 = s0, s1
            if k == 0 and convex(i):
                e0 -= depth
            if k == len(segs) - 1 and convex((i + 1) % n):
                e1 += depth
            p0 = (ax + ux * e0 - ox * 2, az + uz * e0 - oz * 2)  # 땅 쪽으로 2 겹친다
            p1 = (ax + ux * e1 + ox * depth, az + uz * e1 + oz * depth)
            cliffs.append((min(p0[0], p1[0]), max(p0[0], p1[0]), min(p0[1], p1[1]), max(p0[1], p1[1]), TOP + h))
    return cliffs, sands, bad


def buried(dump_path):
    """평원 해안 조각 중 숲 땅 아래로 묻히는 것(윗면 < 3.5, 숲 땅 판과 겹침) 이름"""
    rects, _ = ground_rects()
    names = []
    if not os.path.exists(dump_path):
        return names
    for line in open(dump_path, encoding="utf-8"):
        f = line.strip().split("|")
        if len(f) < 9 or f[1] not in ("Cliffs", "Sand"):
            continue
        x0, x1, z0, z1, top = map(float, f[3:8])
        if top >= 3.5:
            continue
        if any(x0 < r[1] and x1 > r[0] and z0 < r[3] and z1 > r[2] for r in rects):
            names.append((f[0], f[1], f[2]))
    return names


def luau(rects, cliffs, sands, bur):
    out = ["-- forest_ground.py 가 만든 자료(손으로 고치지 말 것 — 표를 고치고 다시 돌린다)", f"local TOP, BOTTOM = {TOP}, {BOTTOM}", "local GROUND = {"]
    out += [f"\t{{ {a:.1f}, {b:.1f}, {c:.1f}, {d:.1f} }}," for a, b, c, d in rects]
    out += ["}", "local CLIFFS = {"]
    out += [f"\t{{ {a:.1f}, {b:.1f}, {c:.1f}, {d:.1f}, {t:.1f} }}," for a, b, c, d, t in cliffs]
    out += ["}", "local SANDS = {"]
    out += [f"\t{{ {a:.1f}, {b:.1f}, {c:.1f}, {d:.1f}, {t:.1f} }}," for a, b, c, d, t in sands]
    out += ["}"]
    return "\n".join(out) + "\n"


if __name__ == "__main__":
    rects, holes = ground_rects()
    cliffs, sands, bad = coast()
    # 검사: 판 크기, 평원 땅과 겹침 0
    for a, b, c, d in rects:
        if b - a > 2048 or d - c > 2048:
            bad.append(f"판 {a},{c} 가 2048 넘음")
        for r in PLAINS_LAND:
            if a < r[1] - 0.01 and b > r[0] + 0.01 and c < r[3] - 0.01 and d > r[2] + 0.01:
                bad.append(f"판 {a:.0f},{c:.0f} 가 평원 땅 {r} 과 겹침")
    dump = os.path.join(os.environ.get("RECV", ""), "plainsedge.txt")
    bur = buried(dump)
    for p in bad:
        print("문제:", p)
    open(os.path.join(HERE, "Forest_Build_data.luau"), "w", encoding="utf-8", newline="\n").write(luau(rects, cliffs, sands, bur))
    area = sum((b - a) * (d - c) for a, b, c, d in rects)
    print(f"땅 판 {len(rects)}개(넓이 {area / 1e6:.1f}M), 평원 속 구멍 칸 {holes}, 벼랑 {len(cliffs)}, 모래 {len(sands)}, 묻히는 평원 조각 {len(bur)}, 문제 {len(bad)}건")
