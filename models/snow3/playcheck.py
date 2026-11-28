# -*- coding: utf-8 -*-
"""
playcheck.py — 2026-11-28 아트. 설원 3판 건물을 '플레이어 크기'(R6 키 5 · 폭 4 · 눈 4.5)로 자동 검사한다.
사용자 4차 점검: "'가까이에서 봤을 때 정성이 느껴지냐'를 중심으로 … 플레이어 크기를 고려해야겠지." — 비평 전에 이 검사가 0 이어야 한다.

  ① 뜬 물건  메시 덩이(이어진 조각)마다 0.1 안에 닿은 덩이를 이어 그래프를 만들고(꼭짓점 0.1 거리 + 면끼리 파고듦),
             땅(z ≤ 0.15)에 닿은 덩이에서 닿음을 따라 못 가는 덩이 무리 = 공중에 뜬 물건(받침·벽·천장 어디에도 안 붙음)
  ② 길 막힘  충돌 상자(K.I.COLL, 바닥 + 0.4 ~ 5 높이)로 0.5 격자 걷기 지도. 칸 폭 = 2 × 가장 가까운 상자까지 거리.
             사람(반폭 2)이 설 수 있는 칸만 밟아 문 밖 → 가장 넓게 가는 길(최대-최소)의 가장 좁은 폭이
             카운터 앞(INFO free)·NPC 자리·다른 문·INFO targets(계단 입구 등) 까지 8 이상인가 + 설 수 있는데 폭 8 길에서 4 넘게 떨어진 곳(막힌 방) 0
  ③ 좁은 틈  사람이 닿는 곳에서 앞뒤(x)·좌우(y) 막힌 폭 중 좁은 쪽이 3 ~ 9 인 틈(문 구멍 빼고) — 막거나 10 이상으로
  ④ 창 짝    유리(WinGlass) 판마다 안팎 두 쪽으로 광선 6개씩: 3 안에 벽·가구에 막히면(맞은편 창 자리가 벽) 걸림
  ⑤ 반짝임   zfight_scan.fix 뒤 남은 같은 평면 겹침 쌍
돌리기: ONLY=Sn3_Bank,Sn3_Inn "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b -P models/snow3/playcheck.py
        (ONLY 없으면 10채) → models/snow3/playcheck.txt (지은 건물 칸만 바꿔 쓴다). 좌표 = 블렌더 (x, y, z), 로블록스 로컬 = (-x, z, y)
"""
import heapq
import importlib
import math
import os
import re
import sys

import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import lib as K  # noqa: E402
import zfight_scan as Z  # noqa: E402

FILES = {"Sn3_Bank": "b_bank", "Sn3_General": "b_general", "Sn3_Smithy": "b_smithy", "Sn3_Clock": "b_clock", "Sn3_Ticket": "b_ticket",
         "Sn3_Inn": "b_inn", "Sn3_Potion": "b_potion", "Sn3_Hospital": "b_hospital", "Sn3_Enhance": "b_enhance", "Sn3_Gate": "b_gate"}
SKIP = {"Cut", "Pane", "Vent", "LampPt"}
CELL, HALF, NEED, TOL = 0.5, 2.0, 8.0, 0.5       # 격자 · R6 반폭 · 길 폭 · 격자 오차
GAP = (3.0, 9.0)
OUT = os.path.join(HERE, "playcheck.txt")

# 문 구멍(DOORWAY)·문 높이(door_open z0)를 따로 적는다(lib 는 공용이라 감싸기만)
DOORWAYS, DOORZ = {}, {}
_dw, _do = K.DOORWAY, K.door_open


def _dw_rec(x0, x1, y0, y1, z0, h, *a, **kw):
    DOORWAYS.setdefault(K._name(), []).append((x0, x1, y0, y1, z0))
    return _dw(x0, x1, y0, y1, z0, h, *a, **kw)


def _do_rec(g, ax, c, u, w, h, z0, *a, **kw):
    DOORZ.setdefault(K._name(), []).append(z0)
    return _do(g, ax, c, u, w, h, z0, *a, **kw)


K.DOORWAY, K.door_open = _dw_rec, _do_rec
WINS = {}                                             # 벽 창(K.window)만 본다 — 약장 유리문 같은 가구 유리는 창이 아니다
_win = K.window


def _win_rec(g, ax, c, u, z0, w=K.WIN_W, h=K.WIN_H, *a, **kw):
    WINS.setdefault(K._name(), []).append((ax, c, u, z0, w, h))
    return _win(g, ax, c, u, z0, w, h, *a, **kw)


K.window = _win_rec


# ------------------------------------------------------------------ ① 뜬 물건 · ④ 창
def islands(g):
    V, P, PI, isl = [], [], [], []
    for k, grp in g.items():
        if k in SKIP or not grp.bm.verts:
            continue
        for vs, fs in K.S._comps(grp.bm):
            base = len(V)
            loc = {v.index: base + i for i, v in enumerate(vs)}
            V += [v.co.copy() for v in vs]
            for f in fs:
                P.append([loc[v.index] for v in f.verts])
                PI.append(len(isl))
            isl.append((k, base, len(V)))
    return V, P, PI, isl


def floating(V, P, PI, isl):
    bvh = BVHTree.FromPolygons(V, P, epsilon=0.0)
    vi = np.empty(len(V), dtype=np.int64)
    for i, (k, a, b) in enumerate(isl):
        vi[a:b] = i
    adj = [set() for _ in isl]
    for n, co in enumerate(V):
        i = vi[n]
        for hit in bvh.find_nearest_range(co, 0.1):
            j = PI[hit[2]]
            if j != i:
                adj[i].add(j)
                adj[j].add(i)
    for p, q in bvh.overlap(bvh):
        i, j = PI[p], PI[q]
        if i != j:
            adj[i].add(j)
            adj[j].add(i)
    zmin = [min(V[n].z for n in range(a, b)) for k, a, b in isl]
    seen = [z <= 0.15 for z in zmin]
    st = [i for i, s in enumerate(seen) if s]
    while st:
        i = st.pop()
        for j in adj[i]:
            if not seen[j]:
                seen[j] = True
                st.append(j)
    out, done = [], set()
    for i in range(len(isl)):
        if seen[i] or i in done:
            continue
        grp, st = [], [i]
        done.add(i)
        while st:
            a = st.pop()
            grp.append(a)
            for j in adj[a]:
                if j not in done and not seen[j]:
                    done.add(j)
                    st.append(j)
        pts = [V[n] for a in grp for n in range(isl[a][1], isl[a][2])]
        lo = [min(p[c] for p in pts) for c in range(3)]
        hi = [max(p[c] for p in pts) for c in range(3)]
        out.append((sorted({isl[a][0] for a in grp}), lo, hi, len(grp)))
    return out


def windows(g, V, P, PI, isl, name):
    if not g["WinGlass"].bm.verts:
        return [], 0
    keep = [n for n, i in enumerate(PI) if isl[i][0] != "WinGlass"]
    bvh = BVHTree.FromPolygons(V, [P[n] for n in keep], epsilon=0.0)
    bad, n = [], 0
    for vs, fs in K.S._comps(g["WinGlass"].bm):
        lo = Vector([min(v.co[c] for v in vs) for c in range(3)])
        hi = Vector([max(v.co[c] for v in vs) for c in range(3)])
        sz = hi - lo
        a = 0 if sz.x < sz.y else 1
        if sz.z < min(sz.x, sz.y) or sz[a] > 0.4:
            continue                                  # 누운 유리(천창)·두꺼운 유리 덩이는 안 본다
        m = (lo + hi) / 2
        if not any((ax == "x") == (a == 1) and abs(m[a] - c) < 1.0 and abs(m[1 - a] - u) <= w / 2 and z0 <= m.z <= z0 + h
                   for ax, c, u, z0, w, h in WINS.get(name, ())):
            continue                                  # 벽 창이 아님(약장 유리문 등)
        n += 1
        u = 1 - a
        side_bad = []
        for s in (-1, 1):
            clear = 0
            for fu in (0.25, 0.75):
                for fz in (0.17, 0.5, 0.83):
                    o = Vector(lo)
                    o[u] = lo[u] + sz[u] * fu
                    o.z = lo.z + sz.z * fz
                    o[a] = (hi[a] if s > 0 else lo[a]) + 0.05 * s
                    d = Vector((0, 0, 0))
                    d[a] = s
                    clear += bvh.ray_cast(o, d, 3.0)[0] is None
            if clear < 2:
                side_bad.append("+" if s > 0 else "-")
        if side_bad:
            c = (lo + hi) / 2
            bad.append("   창: 블렌더 (%.1f, %.1f, %.1f) 폭 %.1f 높이 %.1f — %s%s 쪽 3 안이 막힘" % (
                c.x, c.y, c.z, sz[u], sz.z, "/".join(side_bad), "xy"[a]))
    return bad, n


# ------------------------------------------------------------------ ② 길 · ③ 틈
def level_grid(name, fz, inside, voids=(), outdoor=False):
    x0, x1, y0, y1 = inside
    nx, ny = int(round((x1 - x0) / CELL)), int(round((y1 - y0) / CELL))
    X, Y = np.meshgrid(x0 + (np.arange(nx) + 0.5) * CELL, y0 + (np.arange(ny) + 0.5) * CELL, indexing="ij")
    boxes = [(cx, cy, sx / 2, sy / 2, math.cos(rz), math.sin(rz)) for cx, cy, cz, sx, sy, sz, rz in K.I.COLL[name]
             if cz - sz / 2 < fz + 5.0 and cz + sz / 2 > fz + 0.4]
    boxes += [((a + b) / 2, (c + d) / 2, (b - a) / 2, (d - c) / 2, 1.0, 0.0) for a, b, c, d in voids]
    big = np.full(X.shape, np.inf)
    D = big.copy() if outdoor else np.minimum(np.minimum(X - x0, x1 - X), y1 - Y)       # 바깥 문(outdoor): 범위 끝은 벽이 아니다
    T = {d: (big.copy() if outdoor else e.copy()) for d, e in (((1, 0), x1 - X), ((-1, 0), X - x0), ((0, 1), y1 - Y), ((0, -1), big))}
    for cx, cy, hx, hy, c, s in boxes:
        u, v = (X - cx) * c + (Y - cy) * s, -(X - cx) * s + (Y - cy) * c
        D = np.minimum(D, np.hypot(np.maximum(np.abs(u) - hx, 0), np.maximum(np.abs(v) - hy, 0)))
        for (dx, dy), t in T.items():
            du, dv = dx * c + dy * s, -dx * s + dy * c
            te, tx = np.full(X.shape, -np.inf), np.full(X.shape, np.inf)
            for o, d, h in ((u, du, hx), (v, dv, hy)):
                if abs(d) < 1e-9:
                    te = np.where(np.abs(o) <= h, te, np.inf)
                else:
                    t1, t2 = (-h - o) / d, (h - o) / d
                    te, tx = np.maximum(te, np.minimum(t1, t2)), np.minimum(tx, np.maximum(t1, t2))
            hit = tx >= np.maximum(te, 0)
            np.minimum(t, np.where(hit, np.maximum(te, 0), np.inf), out=t)
    D = np.maximum(D, 0)
    span_x, span_y = T[(1, 0)] + T[(-1, 0)], T[(0, 1)] + T[(0, -1)]
    return X, Y, D, span_x, span_y


def idx(X, Y, p):
    i = int(np.clip(round((p[0] - X[0, 0]) / CELL), 0, X.shape[0] - 1))
    j = int(np.clip(round((p[1] - Y[0, 0]) / CELL), 0, X.shape[1] - 1))
    return i, j


def widest(D, start):
    """사람이 설 수 있는 칸(D ≥ 반폭)만 밟는 최대-최소 길: best = 시작에서 그 칸까지 가장 넓은 길의 가장 좁은 반폭"""
    ok = D >= HALF - 0.1
    best = np.full(D.shape, -1.0)
    si, sj = start
    if not ok[si, sj]:
        cand = np.argwhere(ok)
        if not len(cand):
            return best
        k = np.argmin((cand[:, 0] - si) ** 2 + (cand[:, 1] - sj) ** 2)
        si, sj = cand[k]
    best[si, sj] = D[si, sj]
    pq = [(-D[si, sj], si, sj)]
    nx, ny = D.shape
    while pq:
        w, i, j = heapq.heappop(pq)
        w = -w
        if w < best[i, j]:
            continue
        for a, b in ((i + 1, j), (i - 1, j), (i, j + 1), (i, j - 1)):
            if 0 <= a < nx and 0 <= b < ny and ok[a, b]:
                nw = min(w, D[a, b])
                if nw > best[a, b]:
                    best[a, b] = nw
                    heapq.heappush(pq, (-nw, a, b))
    return best


def dilate(m, r):
    k = int(r / CELL)
    out = m.copy()
    nx, ny = m.shape
    for di in range(-k, k + 1):
        for dj in range(-k, k + 1):
            if di * di + dj * dj > k * k or (di == 0 and dj == 0):
                continue
            src = m[max(0, -di):nx - max(0, di), max(0, -dj):ny - max(0, dj)]
            out[max(0, di):nx - max(0, -di), max(0, dj):ny - max(0, -dj)] |= src
    return out


def regions(m, min_cells):
    seen = np.zeros(m.shape, bool)
    out = []
    for i, j in np.argwhere(m):
        if seen[i, j]:
            continue
        st, cells = [(i, j)], []
        seen[i, j] = True
        while st:
            a, b = st.pop()
            cells.append((a, b))
            for c, d in ((a + 1, b), (a - 1, b), (a, b + 1), (a, b - 1)):
                if 0 <= c < m.shape[0] and 0 <= d < m.shape[1] and m[c, d] and not seen[c, d]:
                    seen[c, d] = True
                    st.append((c, d))
        if len(cells) >= min_cells:
            out.append(cells)
    return out


def walk_level(name, lab, fz, inside, start, targets, voids=(), outdoor=False):
    X, Y, D, sx, sy = level_grid(name, fz, inside, voids, outdoor)
    best = widest(D, idx(X, Y, start))
    lines, bad = [], 0
    for tl, (tx, ty), r in targets:
        m = (X - tx) ** 2 + (Y - ty) ** 2 <= r * r
        w = 2 * best[m].max() if m.any() else -2
        if w < NEED - TOL:
            bad += 1
            lines.append("   길(%s): 문 → %s (%.1f, %.1f) 가장 넓은 길 폭 %s" % (lab, tl, tx, ty, "%.1f" % w if w > 0 else "못 감"))
    reach = best > 0
    wide = 2 * best >= NEED - TOL
    stranded = reach & ~dilate(wide, 4.0)
    for cells in regions(stranded, 16):
        bad += 1
        c = np.mean([(X[a, b], Y[a, b]) for a, b in cells], axis=0)
        w = 2 * max(best[a, b] for a, b in cells)
        lines.append("   길(%s): 폭 8 길에서 떨어진 곳 (%.1f, %.1f) 넓이 %.0f — 들어가는 길 폭 %.1f" % (lab, c[0], c[1], len(cells) * CELL * CELL, w))
    door = np.zeros(D.shape, bool)
    for x0, x1, y0, y1, z0 in DOORWAYS.get(name, ()):
        if abs(z0 - fz) < 1.0:
            ex, ey = (0.0, 1.5) if x1 - x0 >= y1 - y0 else (1.5, 0.0)
            door |= (X >= x0 - ex) & (X <= x1 + ex) & (Y >= y0 - ey) & (Y <= y1 + ey)
    near, free = reach.copy(), D > 0                      # 사람이 선 칸에서 빈 칸을 따라 2.5 안(벽 너머로 새지 않게)
    for _ in range(int(2.5 / CELL)):
        nb = near.copy()
        nb[1:] |= near[:-1]
        nb[:-1] |= near[1:]
        nb[:, 1:] |= near[:, :-1]
        nb[:, :-1] |= near[:, 1:]
        near = nb & free
    narrow = lambda s: (s >= GAP[0]) & (s < GAP[1])      # noqa: E731
    gap = (D > 0) & near & ~door & narrow(np.minimum(sx, sy))      # 틈 폭 = 앞뒤·좌우 중 좁은 쪽(1 폭 홈의 긴 쪽 길이는 폭이 아니다)
    gaps = []
    for cells in regions(gap, 12):
        c = np.mean([(X[a, b], Y[a, b]) for a, b in cells], axis=0)
        w = min(min(sx[a, b], sy[a, b]) for a, b in cells)
        gaps.append("   틈(%s): (%.1f, %.1f) 폭 %.1f 넓이 %.0f" % (lab, c[0], c[1], w, len(cells) * CELL * CELL))
    return bad, lines, gaps


def walk(m):
    info = getattr(m, "INFO", {})
    name, fz = m.NAME, info.get("floor", 0.0)
    if "walk" not in info:
        return 0, [], []
    targets = [("카운터 앞", ((info["free"][0] + info["free"][1]) / 2, (info["free"][2] + info["free"][3]) / 2), 3.0)]
    for x, y, z, yaw in K.I.NPCS.get(name, ()):
        if abs(z - fz) < 1.0:
            targets.append(("NPC 앞", (x + 5.0 * math.sin(math.radians(yaw)), y - 5.0 * math.cos(math.radians(yaw))), 5.0))
    for (p, w, h, f, ax), z0 in zip(K.DOOR_INFO.get(name, ()), DOORZ.get(name, ())):
        if abs(z0 - fz) < 1.0:
            targets.append(("문", p, 5.0))
    up = {}
    for tl, p, z, r in info.get("targets", ()):
        (targets if abs(z - fz) < 1.0 else up.setdefault(z, [])).append((tl, p, r))
    b, l1, g1 = walk_level(name, "1층", fz, info["inside"], info["walk"][0], targets, outdoor=info.get("outdoor", False))
    for k, sub in enumerate(info.get("floors", ())):
        t2 = [("쉬는 자리", sub["walk"][1], 3.0), ("빈 바닥", ((sub["free"][0] + sub["free"][1]) / 2, (sub["free"][2] + sub["free"][3]) / 2), 3.0)]
        t2 += up.get(sub["floor"], [])
        for (p, w, h, f, ax), z0 in zip(K.DOOR_INFO.get(name, ()), DOORZ.get(name, ())):
            if abs(z0 - sub["floor"]) < 1.0:
                t2.append(("문", p, 5.0))
        b2, l2, g2 = walk_level(name, sub.get("name", "2층"), sub["floor"], sub["inside"], sub["walk"][0], t2, sub.get("voids", ()))
        b, l1, g1 = b + b2, l1 + l2, g1 + g2
    return b, l1, g1


# ------------------------------------------------------------------ 한 채
def check(name):
    m = importlib.import_module(FILES[name])
    K.L.clear_scene()
    g = K.G(m.PREFIX)
    K.I.job(m.NAME, m.build)(g)
    zm, zl = Z.fix(g, m.NAME)
    tri = max(sum(len(f.verts) - 2 for f in grp.bm.faces) for grp in g.values())
    V, P, PI, isl = islands(g)
    fl = floating(V, P, PI, isl)
    wbad, nwin = windows(g, V, P, PI, isl, m.NAME)
    nb, wl, gl = walk(m)
    for grp in g.values():
        grp.bm.free()
    tot = len(fl) + nb + len(gl) + len(wbad) + zl
    lines = ["■ %s  합 %d  (뜬 %d · 길 %d · 틈 %d · 창 %d/%d · 반짝 %d)  덩이 %d · 재질 덩이 최대 %d 삼각형%s" % (
        name, tot, len(fl), nb, len(gl), len(wbad), nwin, zl, len(isl), tri, " ← 10000 넘음" if tri > 10000 else "")]
    for mats, lo, hi, n in sorted(fl, key=lambda f: -f[3])[:30]:
        lines.append("   뜬: %s 조각 %d  블렌더 x %.1f..%.1f y %.1f..%.1f z %.1f..%.1f" % ("+".join(mats), n, lo[0], hi[0], lo[1], hi[1], lo[2], hi[2]))
    lines += wl + gl[:30] + wbad[:30]
    print("\n".join(lines))
    return tot, lines


def main():
    only = [s for s in os.environ.get("ONLY", "").split(",") if s] or list(FILES)
    blocks = {}
    if os.path.exists(OUT):
        cur = None
        for ln in open(OUT, encoding="utf-8").read().splitlines():
            if ln.startswith("■ "):
                cur = ln.split()[1]
                blocks[cur] = []
            if cur and not ln.startswith("합계"):
                blocks[cur].append(ln)
    for name in only:
        blocks[name] = check(name)[1]
    tot = sum(int(re.search(r"합 (\d+)", b[0]).group(1)) for n, b in blocks.items() if n in FILES)
    head = ["playcheck — 설원 3판 10채 플레이어 크기 검사 (models/snow3/playcheck.py). 건물마다 합 0 이어야 통과. 좌표 = 블렌더 (x, y, z)", ""]
    body = [ln for n in FILES if n in blocks for ln in blocks[n] + [""]]
    with open(OUT, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(head + body + ["합계 %d" % tot]) + "\n")
    print("합계 %d → %s" % (tot, OUT))


main()
