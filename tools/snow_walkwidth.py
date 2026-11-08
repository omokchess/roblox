# -*- coding: utf-8 -*-
"""
snow_walkwidth.py — 2026-11-08. 슈네라이히 걷는 자리 너비 지도.
사용자: "너비가 못해도 플레이어 두 명이 앞만 보고 걸어갔을 때 약간 남을 수 있는 너비여야 해" → R6 폭 4 × 2 + 여유 = 10.

Studio 에서 tools/Snow_WalkScan.luau 를 돌려 recv/walk_*.txt(칸마다 걸을 수 있는 층 높이)와
tools/Snow_WalkModels.luau 로 recv/walk_models.txt(모델 상자)를 받은 뒤:
  "<블렌더>/5.2/python/bin/python.exe" tools/snow_walkwidth.py <recv 폴더> [출력 폴더]
1. 이웃 칸(8방)의 층이 높이 1.25 안이면 이어진 것으로 보고 가장 큰 덩이(길·광장·건물 안)를 '갈 수 있는 곳'으로
2. 벽(이어진 이웃이 없는 쪽)까지 거리 d 를 길 따라 잼(다익스트라)
3. d >= 5 인 자리(지름 10 원이 들어감)에서 5 안에 닿는 곳 = 넉넉함. 닿지 않는 곳 = 좁은 곳 → 덩이로 묶어 번호·건물 이름
출력: walk_ground.png(땅 층), walk_upper.png(윗층), walk_report.txt
"""
import heapq
import math
import os
import sys
from collections import deque

import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from plan_png import Canvas  # noqa: E402

A = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-_"
DEC = {c: i for i, c in enumerate(A)}
STEP = 1.4       # 한 칸 사이 오를 수 있는 높이(공장 계단 한 단 1.3)
NEED = 10.0      # 두 사람 + 여유
R = NEED / 2 - 0.5   # 칸 n 개가 비면 실제 틈은 n 이상 — 벽 옆 칸 d=0.5 이므로 n 칸 띠 가운데 d = n/2 - 0.5 (2026-11-08 기물군 회랑 10 칸이 좁게 나오던 것)
GROUND_TOP = 66.0  # 이보다 낮으면 땅 층(마을 땅 59.8 + 계단·턱)


def load(recv):
    x0, z0, nx, nz = map(int, open(os.path.join(recv, "walk_info.txt")).read().split())
    rows = []
    k = 0
    while os.path.exists(os.path.join(recv, "walk_%03d.txt" % k)):
        rows += open(os.path.join(recv, "walk_%03d.txt" % k), encoding="utf-8").read().split("\n")
        k += 1
    assert len(rows) == nz, (len(rows), nz)
    H = np.full((6, nz, nx), np.nan, dtype=np.float32)
    for iz, line in enumerate(rows):
        i = ix = 0
        while i < len(line):
            n = int(line[i])
            i += 1
            for lv in range(n):
                v = DEC[line[i]] * 64 + DEC[line[i + 1]]
                H[lv, iz, ix] = 40 + v * 0.05
                i += 2
            ix += 1
        assert ix == nx, (iz, ix, nx)
    models = []
    for ln in open(os.path.join(recv, "walk_models.txt"), encoding="utf-8").read().splitlines():
        f, name, cx, cy, cz, sx, sy, sz, yaw = ln.split("\t")
        models.append((f, name, float(cx), float(cy), float(cz), float(sx), float(sy), float(sz), float(yaw)))
    return x0, z0, nx, nz, H, models


def crop(x0, z0, H, models, pad=40):
    """마을 모델(가스등·관 빼고 큰 것) 둘레만 남긴다(눈밭까지 재면 덩이가 너무 크다)"""
    big = [m for m in models if m[5] * m[7] > 150 and m[0] not in ("가스등", "난방관", "톱니", "나무")]
    xs = [m[2] - m[5] / 2 for m in big] + [m[2] + m[5] / 2 for m in big]
    zs = [m[4] - m[7] / 2 for m in big] + [m[4] + m[7] / 2 for m in big]
    ax0, ax1 = int(min(xs) - pad - x0), int(max(xs) + pad - x0)
    az0, az1 = int(min(zs) - pad - z0), int(max(zs) + pad - z0)
    ax0, az0 = max(ax0, 0), max(az0, 0)
    ax1, az1 = min(ax1, H.shape[2]), min(az1, H.shape[1])
    return x0 + ax0, z0 + az0, H[:, az0:az1, ax0:ax1]


NB = [(-1, 0, 1.0), (1, 0, 1.0), (0, -1, 1.0), (0, 1, 1.0),
      (-1, -1, 1.4142), (1, -1, 1.4142), (-1, 1, 1.4142), (1, 1, 1.4142)]


def build(H):
    L, nz, nx = H.shape
    hl = [[[] for _ in range(nx)] for _ in range(nz)]   # 칸마다 (높이, 노드 번호)
    hs = []
    for iz in range(nz):
        for ix in range(nx):
            for k in range(L):
                h = H[k, iz, ix]
                if not np.isnan(h) and 50.0 <= h <= 140.0:
                    hl[iz][ix].append((float(h), len(hs)))
                    hs.append((ix, iz, float(h)))

    def nbrs(i):
        ix, iz, h = hs[i]
        for dx, dz, w in NB:
            jx, jz = ix + dx, iz + dz
            if 0 <= jx < nx and 0 <= jz < nz:
                best = None
                for h2, j in hl[jz][jx]:
                    if abs(h2 - h) <= STEP and (best is None or abs(h2 - h) < abs(best[0] - h)):
                        best = (h2, j)
                yield (dx, dz, w, best[1] if best else None)

    return hs, nbrs


def main():
    recv = sys.argv[1]
    out = sys.argv[2] if len(sys.argv) > 2 else os.path.dirname(os.path.abspath(__file__))
    x0, z0, nx, nz, H, models = load(recv)
    X0, Z0, H = crop(x0, z0, H, models)
    L, nz, nx = H.shape
    print("자른 범위 x %d..%d z %d..%d (%d×%d)" % (X0, X0 + nx, Z0, Z0 + nz, nx, nz))
    hs, nbrs = build(H)
    N = len(hs)
    adj = [None] * N
    for i in range(N):
        adj[i] = list(nbrs(i))
    # 1. 가장 큰 덩이
    comp = [-1] * N
    sizes = []
    for s in range(N):
        if comp[s] >= 0:
            continue
        c = len(sizes)
        comp[s] = c
        q = deque([s])
        n = 0
        while q:
            i = q.popleft()
            n += 1
            for _, _, _, j in adj[i]:
                if j is not None and comp[j] < 0:
                    comp[j] = c
                    q.append(j)
        sizes.append(n)
    main_c = max(range(len(sizes)), key=lambda c: sizes[c])
    reach = [comp[i] == main_c for i in range(N)]
    print("노드 %d, 덩이 %d, 큰 덩이 %d" % (N, len(sizes), sizes[main_c]))
    # 2. 벽까지 거리
    INF = 1e9
    d = [INF] * N
    pq = []
    for i in range(N):
        if reach[i] and any(j is None for _, _, _, j in adj[i]):
            d[i] = 0.5
            pq.append((0.5, i))
    heapq.heapify(pq)
    while pq:
        di, i = heapq.heappop(pq)
        if di > d[i]:
            continue
        for _, _, w, j in adj[i]:
            if j is not None and di + w < d[j]:
                d[j] = di + w
                heapq.heappush(pq, (d[j], j))
    # 3. 지름 10 원이 닿는 곳
    cov = [INF] * N
    pq = [(0.0, i) for i in range(N) if reach[i] and d[i] >= R]
    for _, i in pq:
        cov[i] = 0.0
    heapq.heapify(pq)
    while pq:
        ci, i = heapq.heappop(pq)
        if ci > cov[i]:
            continue
        for _, _, w, j in adj[i]:
            if j is not None and ci + w < cov[j] and ci + w <= R - 0.5 + 1e-6:
                cov[j] = ci + w
                heapq.heappush(pq, (cov[j], j))
    narrow = [reach[i] and cov[i] >= INF for i in range(N)]
    # 좁은 덩이
    lab = [-1] * N
    groups = []
    for s in range(N):
        if not narrow[s] or lab[s] >= 0:
            continue
        g = []
        lab[s] = len(groups)
        q = deque([s])
        while q:
            i = q.popleft()
            g.append(i)
            for _, _, _, j in adj[i]:
                if j is not None and narrow[j] and lab[j] < 0:
                    lab[j] = lab[s]
                    q.append(j)
        groups.append(g)

    def where(x, z, y):
        best = None
        for f, name, cx, cy, cz, sx, sy, sz, yaw in models:
            if f in ("가스등", "톱니"):
                continue
            a = math.radians(yaw)
            lx = (x - cx) * math.cos(a) - (z - cz) * math.sin(a)
            lz = (x - cx) * math.sin(a) + (z - cz) * math.cos(a)
            if abs(lx) <= sx / 2 + 1 and abs(lz) <= sz / 2 + 1 and abs(y - cy) <= sy / 2 + 3:
                area = sx * sz
                if best is None or area < best[0]:
                    best = (area, f + "/" + name)
        return best[1] if best else "길(건물 밖)"

    HOUSE = ("Steam_House_A", "Steam_House_B", "Steam_House_C", "Big_Gear", "Boiler_Tank", "Vertical_Boiler", "Gear_10", "Gear_16")
    rep = []
    cracks = [0]
    for gi, g in enumerate(groups):
        if len(g) < 12:
            continue
        xs = [hs[i][0] for i in g]
        zs = [hs[i][1] for i in g]
        ys = [hs[i][2] for i in g]
        span = math.hypot(max(xs) - min(xs), max(zs) - min(zs))
        if span < 6:
            continue
        w = 2 * (max(d[i] for i in g) + 0.5)   # 빈 칸 수 = 폭(아래 끝)
        if w <= 3.0:        # 벽 모서리 테두리·집 사이 틈(한 칸) — 길이 아니다
            cracks[0] += 1
            continue
        cx, cz = X0 + (min(xs) + max(xs)) / 2 + 0.5, Z0 + (min(zs) + max(zs)) / 2 + 0.5
        y = float(np.median(ys))
        wh = where(cx, cz, y)
        f, _, nm = wh.partition("/")
        if nm in HOUSE or wh == "길(건물 밖)":
            wh = (f + " 집 사이·길가") if nm else "길(건물 밖)"
        if y >= GROUND_TOP:
            wh += " (윗층)"
        rep.append([len(g), w, cx, cz, y, span, wh, g])
    # 자리별로 묶음
    places = {}
    for r in rep:
        places.setdefault(r[6], []).append(r)
    order = sorted(places, key=lambda k: -sum(r[0] for r in places[k]))
    SC = 2
    lines = ["슈네라이히 걷는 자리 너비 점검 (2026-11-08) — 기준 폭 %.0f(R6 4 × 2 + 여유)" % NEED,
             "범위 x %d..%d z %d..%d, 갈 수 있는 칸 %d" % (X0, X0 + nx, Z0, Z0 + nz, sizes[main_c]),
             "그림: 연녹 = 넉넉함(지름 10 원이 지나감), 주황 = 좁음(그 덩이 가장 넓은 곳 6~10), 빨강 = 아주 좁음(6 미만), 짙은 회색 = 못 감(벽·물건·끊긴 곳)",
             "      번호 = 아래 표의 자리(좁은 칸이 많은 순)", ""]
    for upper in (False, True):
        cv = Canvas(X0, Z0, X0 + nx, Z0 + nz, SC)
        cv.px[:] = bytes((34, 36, 40)) * (cv.W * cv.H)
        top = {}
        for i in range(N):
            if not reach[i]:
                continue
            ix, iz, h = hs[i]
            if (h >= GROUND_TOP) != upper:
                continue
            if (ix, iz) not in top or (h > hs[top[(ix, iz)]][2]) == upper:
                top[(ix, iz)] = i
        gwid = {}
        for (ix, iz), i in top.items():
            if narrow[i]:
                if lab[i] not in gwid:
                    gwid[lab[i]] = 2 * (max(d[j] for j in groups[lab[i]]) + 0.5)
                col = (225, 55, 50) if gwid[lab[i]] < 6 else (245, 150, 40)
            elif upper:
                t = min(1.0, max(0.0, (hs[i][2] - 62) / 30))
                col = (int(150 + 80 * t), int(190 - 50 * t), int(210 - 10 * t))
            else:
                col = (170, 205, 170)
            for b_ in range(SC):
                o = ((iz * SC + b_) * cv.W + ix * SC) * 3
                cv.px[o:o + 3 * SC] = bytes(col) * SC
        for no, k in enumerate(order, 1):
            if ("(윗층)" in k) != upper or k.startswith("길(") or "집 사이" in k:
                continue
            rs = places[k]
            tot = sum(r[0] for r in rs)
            cx = sum(r[2] * r[0] for r in rs) / tot
            cz = sum(r[3] * r[0] for r in rs) / tot
            ring = [(cx + 7 * math.cos(t * math.pi / 10), cz + 7 * math.sin(t * math.pi / 10)) for t in range(20)]
            cv.outline(ring, 1.5, "#ffffff")
            cv.text(cx - 2 * len(str(no)), cz - 3, str(no), "#ffffff", px=2)
        cv.save(os.path.join(out, "walk_upper.png" if upper else "walk_ground.png"))
    lines.append("한 칸짜리 틈·벽 모서리(뺌): %d 곳" % cracks[0])
    lines.append("")
    lines.append("번호  자리                                  좁은 칸  덩이  덩이별 가장 넓은 폭(큰 덩이 순)")
    for no, k in enumerate(order, 1):
        rs = sorted(places[k], key=lambda r: -r[0])
        lines.append("%-4d  %-36s %7d  %4d  %s" % (no, k, sum(r[0] for r in rs), len(rs),
                                                    ", ".join("%.0f" % r[1] for r in rs[:8]) + (" …" if len(rs) > 8 else "")))
    open(os.path.join(out, "walk_report.txt"), "w", encoding="utf-8").write("\n".join(lines) + "\n")
    print("\n".join(lines[:90]))


if __name__ == "__main__":
    main()


if __name__ == "__main__":
    main()
