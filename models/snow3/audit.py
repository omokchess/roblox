# -*- coding: utf-8 -*-
"""
audit.py — 2026-11-13. 설원 3판 키트 점검 두 가지.
  1. 구조: models/audit_struct.py 의 판정(islands·audit — 난간 위 기둥·뜬 기둥·얇은 받침)을 그대로 빌려 b_*.py 건물마다 돌린다.
     audit_struct.py 는 불러오면 옛 키트 전체 점검(main)을 돌리므로, 소스에서 맨 끝 main() 호출만 빼고 실행해 함수만 가져온다(원본은 고치지 않음).
  2. 통로 폭: 충돌 상자(C)를 바닥 + 2.5 높이에서 0.5 격자로 깔고, INFO["walk"] 의 문 밖 점 → 카운터 앞 빈 바닥 가운데까지
     "가장 넓게 지나갈 수 있는 길"의 가장 좁은 폭(= 2 × 막힌 칸까지 거리, 최대-최소 길)을 잰다. 10 이상이어야 통과.
     카운터 앞 빈 바닥(INFO["free"])이 막힌 칸 없이 비었는지도 본다.
돌리기: blender -b -P models/snow3/audit.py [-- Sn3_Smithy]   → models/snow3/audit.txt
"""
import heapq
import importlib
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import lib as K  # noqa: E402

_src = open(os.path.join(K.MODELS, "audit_struct.py"), encoding="utf-8").read()
_src = _src[:_src.rstrip().rfind("main()")]
AS = {"__name__": "audit_struct_lib", "__file__": os.path.join(K.MODELS, "audit_struct.py")}
exec(compile(_src, "audit_struct.py", "exec"), AS)
islands, audit = AS["islands"], AS["audit"]

CELL = 0.5


def walk_width(name, info):
    """(최소 폭, 이 높이 충돌 상자 수, 빈 바닥 막힘 칸 수). 폭 = 2 × 칸 가운데에서 가장 가까운 상자까지 거리(0.5 격자 위 최대-최소 길)"""
    fz = info["floor"]
    zq = fz + 2.5
    x0, x1, y0, y1 = info["inside"]
    nx, ny = int((x1 - x0) / CELL), int((y1 - y0) / CELL)
    boxes = [(cx, cy, sx, sy, math.cos(rz), math.sin(rz)) for cx, cy, cz, sx, sy, sz, rz in K.I.COLL[name]
             if cz - sz / 2 <= zq <= cz + sz / 2]

    def dist(px, py):
        """칸 가운데에서 가장 가까운 충돌 상자(이 높이 단면) 가장자리까지 — 상자 속이면 0. 옆·뒤 범위 끝도 벽으로 본다(앞 = 문 밖 마루는 열림)"""
        d = min(px - x0, x1 - px, y1 - py)
        for cx, cy, sx, sy, c, s_ in boxes:
            u, v = (px - cx) * c + (py - cy) * s_, -(px - cx) * s_ + (py - cy) * c
            du, dv = max(abs(u) - sx / 2, 0.0), max(abs(v) - sy / 2, 0.0)
            d = min(d, math.hypot(du, dv))
            if d <= 0:
                return 0.0
        return d
    clear = [[2 * dist(x0 + (i + 0.5) * CELL, y0 + (j + 0.5) * CELL) for j in range(ny)] for i in range(nx)]
    blocked = [[clear[i][j] <= 0 for j in range(ny)] for i in range(nx)]
    (sx_, sy_), (gx, gy) = info["walk"]
    si, sj = int((sx_ - x0) / CELL), int((sy_ - y0) / CELL)
    gi, gj = int((gx - x0) / CELL), int((gy - y0) / CELL)
    sj = max(0, sj)
    fx0, fx1, fy0, fy1 = info["free"]

    def inside_free(i, j):
        return fx0 + 2 <= x0 + (i + 0.5) * CELL <= fx1 - 2 and fy0 <= y0 + (j + 0.5) * CELL <= fy1 - 4
    best = {(si, sj): clear[si][sj]}
    pq = [(-clear[si][sj], si, sj)]
    par = {}
    while pq:
        w, i, j = heapq.heappop(pq)
        w = -w
        if inside_free(i, j):           # 카운터 앞 빈 바닥에 들어서면 끝(그 안 폭은 빈 바닥 검사가 맡는다)
            gi, gj = i, j
            break
        for di, dj in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            a, b = i + di, j + dj
            if 0 <= a < nx and 0 <= b < ny and not blocked[a][b]:
                nw = min(w, clear[a][b])
                if nw > best.get((a, b), -1):
                    best[(a, b)] = nw
                    par[(a, b)] = (i, j)
                    heapq.heappush(pq, (-nw, a, b))
    free_bad = sum(1 for i in range(nx) for j in range(ny) if blocked[i][j]
                   and fx0 < x0 + (i + 0.5) * CELL < fx1 and fy0 < y0 + (j + 0.5) * CELL < fy1)
    # 가장 좁은 자리(길을 거꾸로 따라가며 폭이 가장 작은 칸)
    k, worst = (gi, gj), ((gi, gj), clear[gi][gj])
    while k in par:
        if clear[k[0]][k[1]] < worst[1]:
            worst = (k, clear[k[0]][k[1]])
        k = par[k]
    wx, wy = x0 + (worst[0][0] + 0.5) * CELL, y0 + (worst[0][1] + 0.5) * CELL
    return best.get((gi, gj), 0.0), (round(wx, 2), round(wy, 2)), free_bad


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    only = set(args[0].split(",")) if args else None
    lines = ["설원 3판 키트 점검 (models/snow3/audit.py)"]
    K.L.clear_scene()
    total = 0
    for p in sorted(os.listdir(HERE)):
        if not (p.startswith("b_") and p.endswith(".py")):
            continue
        m = importlib.import_module(p[:-3])
        if only and m.NAME not in only:
            continue
        g = K.G(m.PREFIX)
        K.I.job(m.NAME, m.build)(g)
        isl = islands(g)
        f = audit(m.NAME, isl)
        total += len(f)
        lines.append("%s (안 %s, 덩이 %d): 구조 걸림 %d" % (m.NAME, getattr(m, "VARIANT", "-"), len(isl), len(f)))
        lines += f
        info = getattr(m, "INFO", None)
        if info:
            w, at, fb = walk_width(m.NAME, info)
            ok = w >= K.WALK - 1e-6 and fb == 0
            if not ok:
                total += 1
            lines.append("  통로: 문 → 카운터 앞 가장 좁은 폭 %.1f (기준 %.0f, 가장 좁은 자리 블렌더 x %.1f y %.1f) · 카운터 앞 빈 바닥 %.0f×%.0f 막힌 칸 %d → %s" % (
                w, K.WALK, at[0], at[1], info["free"][1] - info["free"][0], info["free"][3] - info["free"][2], fb, "통과" if ok else "걸림"))
        for grp in g.values():
            grp.bm.free()
    lines.append("걸림 합계 %d" % total)
    out = os.path.join(HERE, "audit.txt")
    with open(out, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(lines) + "\n")
    print("\n".join(lines))
    print("→", out)


main()
