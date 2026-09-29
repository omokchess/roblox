# -*- coding: utf-8 -*-
"""
ruin_lib.py — 다 지은 로마 건물을 폐허로 만든다. (2026-09-29 요청: 사람이 사는 곳보다 폐허가 된 느낌, 칙칙하게)

모든 부재는 상자·원기둥·구 같은 닫힌 덩어리(bmesh 섬)다. 건물 위에 들쭉날쭉한 **붕괴 높이** H(x, y) 를 깔고
  - 땅에서 올라온 덩어리(벽·기둥)는 H 를 넘는 꼭짓점을 H 로 눌러 깨진 윗면(비스듬히 부러진 벽, 부러진 기둥)으로 만든다.
    꼭짓점만 옮기므로 덩어리는 닫힌 채로 남는다.
  - 밑면이 H 위에 뜨는 덩어리(지붕·인방·위층 판·처마)는 통째로 없앤다.
    잔해는 메시에 굽지 않는다(2026-09-29 사용자: "잔해들이 공중에 떠 있다" — 건물을 기단·비탈에 앉히면 구운 잔해도 같이 떴다).
    잔해는 Studio 에서 Roman_City 가 지붕이 사라진 자리를 광선으로 찾아 실제 바닥 위에 블록으로 얹는다.
  - 마지막으로 **받침을 잃은 덩어리**(부러진 기둥 위 동상·머리돌, 무너진 벽 위에 남은 처마 조각)를 지운다:
    바닥에 닿았거나, 아래에 닿는(윗면이 제 밑면 가까이까지 오는) 받쳐진 덩어리가 겹치는 것만 남긴다.
  - 사람 사는 흔적(창 불빛 Glow·점광원 LampPt)은 없애고, 천(차양·깃발)은 대부분 찢겨 없다.
모드
  full  일반 건물: H 가 건물 키의 15~75% 사이에서 물결친다(모든 곳이 무너짐)
  half  랜드마크: 두세 곳 파손 구역(원)만 H 가 낮고 나머지는 온전. 파손 구역에 걸친 지붕·보는 무너진다
  keep_below: 이 높이 아래 덩어리는 손대지 않는다(다리 바닥 등 걸어야 하는 곳)
씨앗이 같으면 결과도 같다.
"""
import math
import random

import bmesh
from mathutils import Vector

DROP = {"Glow", "LampPt"}
TEAR = {"Fabric"}


def _hash(ix, iy, seed):
    n = (ix * 374761393 + iy * 668265263 + seed * 1442695041) & 0xFFFFFFFF
    n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0


def _vnoise(x, y, seed):
    ix, iy = math.floor(x), math.floor(y)
    fx, fy = x - ix, y - iy
    sx, sy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    a, b = _hash(ix, iy, seed), _hash(ix + 1, iy, seed)
    c, d = _hash(ix, iy + 1, seed), _hash(ix + 1, iy + 1, seed)
    return (a * (1 - sx) + b * sx) * (1 - sy) + (c * (1 - sx) + d * sx) * sy


def fbm(x, y, seed):
    return 0.55 * _vnoise(x, y, seed) + 0.3 * _vnoise(2.1 * x, 2.1 * y, seed + 7) + 0.15 * _vnoise(4.3 * x, 4.3 * y, seed + 13)


def _islands(bm):
    # 새로 만든 꼭짓점은 번호가 -1 이다 — 먼저 매겨야 섬을 제대로 가른다
    bm.verts.index_update()
    bm.verts.ensure_lookup_table()
    seen = set()
    out = []
    for v in bm.verts:
        if v.index in seen:
            continue
        stack = [v]
        seen.add(v.index)
        isl = []
        while stack:
            u = stack.pop()
            isl.append(u)
            for e in u.link_edges:
                w = e.other_vert(u)
                if w.index not in seen:
                    seen.add(w.index)
                    stack.append(w)
        out.append(isl)
    return out


def _bounds(groups):
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for name, g in groups.items():
        if name in ("Vent", "LampPt"):
            continue
        for v in g.bm.verts:
            lo = Vector((min(lo.x, v.co.x), min(lo.y, v.co.y), min(lo.z, v.co.z)))
            hi = Vector((max(hi.x, v.co.x), max(hi.y, v.co.y), max(hi.z, v.co.z)))
    return lo, hi


def apply(groups, mode, seed=1, keep_below=1.2, level=0.45, amp=0.6, breaches=None):
    """groups: 재질 이름 → Group. 돌려주는 값: (눌린 덩어리 수, 없앤 덩어리 수, 잔해 수)"""
    if mode == "none":
        return 0, 0, 0
    rng = random.Random(seed)
    lo, hi = _bounds(groups)
    top = hi.z
    wx, wy = max(1.0, hi.x - lo.x), max(1.0, hi.y - lo.y)
    scale = max(wx, wy) / 3.2  # 건물 하나에 물결 서너 개

    if mode == "full":
        def H(x, y):
            return top * (level + amp * (fbm((x - lo.x) / scale + seed * 3.1, (y - lo.y) / scale, seed) - 0.5))
    else:
        # 파손 구역: 가장자리에 걸치도록 두세 개. (가운데 x, y, 반지름, 남는 높이 비율)
        if breaches is None:
            n = rng.choice((3, 4))
            breaches = []
            for _ in range(n):
                side = rng.random()
                bx = lo.x + wx * (rng.choice((0.12, 0.88)) if side < 0.5 else rng.uniform(0.2, 0.8))
                by = lo.y + wy * (rng.uniform(0.2, 0.8) if side < 0.5 else rng.choice((0.12, 0.88)))
                breaches.append((bx, by, max(wx, wy) * rng.uniform(0.2, 0.32), rng.uniform(0.15, 0.4)))

        def H(x, y):
            h = top + 50
            for bx, by, r, keep in breaches:
                d = math.hypot(x - bx, y - by)
                if d < r:
                    # 가장자리로 갈수록 덜 무너진다 + 잔물결
                    t = d / r
                    edge = top * (keep + (1 - keep) * t * t)
                    edge *= 0.85 + 0.3 * fbm(x / 4.0, y / 4.0, seed + 5)
                    h = min(h, edge)
            return h

    pressed = removed = 0
    for name, g in groups.items():
        bm = g.bm
        if name in DROP:
            bmesh.ops.delete(bm, geom=list(bm.verts), context="VERTS")
            continue
        if name == "Vent":
            continue
        dead = []
        for isl in _islands(bm):
            zs = [v.co.z for v in isl]
            bottom, itop = min(zs), max(zs)
            if name in TEAR and rng.random() < 0.75:
                dead.append(isl)
                continue
            if itop <= keep_below:
                continue
            # 넓은 지붕·보는 꼭짓점 사이 한가운데에 파손 구역이 걸칠 수 있다 — 밑면 전체를 격자로 잰다
            xs = [v.co.x for v in isl]
            ys = [v.co.y for v in isl]
            ax, bx, ay, by = min(xs), max(xs), min(ys), max(ys)
            nx = max(1, min(14, int((bx - ax) / 2.0)))
            ny = max(1, min(14, int((by - ay) / 2.0)))
            hmin = min(H(v.co.x, v.co.y) for v in isl)
            for i in range(nx + 1):
                for j in range(ny + 1):
                    hmin = min(hmin, H(ax + (bx - ax) * i / nx, ay + (by - ay) * j / ny))
            if bottom >= hmin - 0.05 and bottom > keep_below - 0.3:
                dead.append(isl)
                continue
            if itop <= hmin:
                continue
            # 붕괴 높이에 걸친 덩어리: 긴 쪽을 2.5 간격으로 잘라(꼭짓점을 늘려) 윗면이 파손선을 따라 들쭉날쭉 부서지게.
            # 상자는 꼭짓점이 여덟뿐이라 그냥 누르면 한 덩어리 긴 경사면이 된다
            if (bx - ax) > 3.0 or (by - ay) > 3.0:
                verts = set(isl)
                edges = {e for v in isl for e in v.link_edges}
                faces = {f for v in isl for f in v.link_faces}
                geom = list(verts) + list(edges) + list(faces)
                for axis, a0, a1 in ((0, ax, bx), (1, ay, by)):
                    n = min(12, int((a1 - a0) / 2.5))
                    for k in range(1, n + 1):
                        c = a0 + (a1 - a0) * k / (n + 1)
                        co = Vector((c, 0, 0)) if axis == 0 else Vector((0, c, 0))
                        no = Vector((1, 0, 0)) if axis == 0 else Vector((0, 1, 0))
                        res = bmesh.ops.bisect_plane(bm, geom=geom, plane_co=co, plane_no=no)
                        geom = list({*geom, *res["geom_cut"]}) if res else geom
                        geom = [x for x in geom if x.is_valid]
                isl = [x for x in geom if isinstance(x, bmesh.types.BMVert)]
            changed = False
            for v in isl:
                h = H(v.co.x, v.co.y)
                if v.co.z > h and v.co.z > keep_below:
                    v.co.z = max(bottom + 0.25, h + rng.uniform(-0.15, 0.15))
                    changed = True
            pressed += changed
        if dead:
            geom = [v for isl in dead for v in isl]
            bmesh.ops.delete(bm, geom=geom, context="VERTS")
            removed += len(dead)
    rubble = drop_unsupported(groups, lo.z)
    return pressed, removed, rubble


def drop_unsupported(groups, floor, reach=0.35, cell=4.0):
    """
    받침을 잃은 덩어리를 지운다. 돌려주는 값: 지운 수.
    밑면이 바닥(floor + reach) 이하면 받쳐진 것. 아니면 밑면 순서대로 보며, xy 가 겹치고 윗면이 제 밑면 - reach 이상인
    받쳐진 덩어리가 아래에 있으면 받쳐진 것. 받쳐진 덩어리는 cell 격자에 넣어 찾는다(한 모델에 섬이 수천 개).
    """
    items = []
    for name, g in groups.items():
        if name in ("Vent", "LampPt") or name in DROP:
            continue
        for isl in _islands(g.bm):
            xs = [v.co.x for v in isl]
            ys = [v.co.y for v in isl]
            zs = [v.co.z for v in isl]
            items.append((min(zs), max(zs), min(xs), max(xs), min(ys), max(ys), name, isl))
    items.sort(key=lambda t: t[0])
    grid = {}

    def cells(x0, x1, y0, y1):
        for i in range(math.floor(x0 / cell), math.floor(x1 / cell) + 1):
            for j in range(math.floor(y0 / cell), math.floor(y1 / cell) + 1):
                yield (i, j)

    dead = {}
    for it in items:
        z0, z1, x0, x1, y0, y1, name, isl = it
        ok = z0 <= floor + reach
        if not ok:
            for key in cells(x0, x1, y0, y1):
                for o in grid.get(key, ()):
                    if o[1] >= z0 - reach and o[0] < z0 and o[2] <= x1 + 0.05 and o[3] >= x0 - 0.05 and o[4] <= y1 + 0.05 and o[5] >= y0 - 0.05:
                        ok = True
                        break
                if ok:
                    break
        if ok:
            for key in cells(x0, x1, y0, y1):
                grid.setdefault(key, []).append(it)
        else:
            dead.setdefault(name, []).extend(isl)
    n = 0
    for name, verts in dead.items():
        bm = groups[name].bm
        verts = [v for v in verts if v.is_valid]
        n += len(verts)
        bmesh.ops.delete(bm, geom=verts, context="VERTS")
    return n


# 모델별 폐허 방식(요청: 일반 건물은 완전 폐허, 랜드마크는 반쯤). 없는 모델은 손대지 않는다
SPEC = {
    "Domus": ("full", {}), "Insula_A": ("full", {"level": 0.42}), "Insula_B": ("full", {"level": 0.4}),
    "Taberna_Row": ("full", {}), "Barracks": ("full", {}), "Thermae": ("full", {"level": 0.5}),
    "Basilica": ("full", {"level": 0.5}), "Temple_Small": ("full", {"level": 0.5}), "Watchtower": ("full", {"level": 0.55}),
    "Wall_Seg": ("full", {"level": 0.6, "amp": 0.7}), "Wall_Tower": ("full", {"level": 0.55}), "Principia": ("full", {}),
    "Market_Stall": ("full", {"level": 0.6}),
    "Palatium": ("half", {}), "Temple_Ignus": ("half", {}), "Amph_Quarter": ("half", {}), "City_Gate": ("half", {}),
    "Triumphal_Arch": ("half", {}), "Aqueduct_Span": ("half", {}), "Victory_Column": ("half", {}),
    # 다리는 바닥(79)까지 온전해야 걷는다 — 난간만 부서진다
    "Bridge_Span": ("half", {"keep_below": 79.2}),
}
