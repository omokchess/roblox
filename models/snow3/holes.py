# -*- coding: utf-8 -*-
"""
holes.py — 2026-11-18 총괄. 설원 마을 3판 건물의 '구멍' 찾기(Roblox 처럼 뒷면을 그리지 않는다고 보고 광선을 쏜다).
사용자(2026-11-18): "집집마다 구멍이 나있는 곳이 있고, 은행은 또 벽에 문만 달려있는 식이야."

Roblox MeshPart 는 면의 뒷면을 그리지 않는다. 그래서
  ① 뒷면 구멍: 광선이 처음 맞은 면이 뒷면(면 법선 · 광선 방향 > 0)이면 Roblox 에선 그 면이 안 보여 뒤가 비쳐 보인다
     (한쪽만 있는 판, 뒤집힌 면, 상자 안쪽에서 본 면).
  ② 틈 구멍: 지붕 밑 안쪽 자리에서 쏜 광선이 문 말고 다른 데로 밖까지 빠져나간다(벽·지붕·바닥 이음 틈).
안쪽 자리 = 8 스터드 위로 쏜 광선이 앞면(천장·지붕)에 맞고, 아래 3 안에 바닥 앞면이 있고, 여섯 축 방향 중 다섯 이상이 앞면에 맞거나
밖으로 트인 자리(벽 속 같은 막힌 자리는 빠진다). 바깥 자리 = 둘레 고리(눈높이 4.5 · 12 · 지붕 위)에서 건물 안쪽 점들을 겨눔.
투명 재질(Vent·LampPt — Roblox 에서 Transparency 1)은 지나간다고 본다.

돌리기: ONLY=Sn3_Bank,Sn3_Inn "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b -P models/snow3/holes.py
       (ONLY 없으면 b_*.py 전부) → models/snow3/holes.txt (로블록스 로컬 좌표 (-x, z, y) — 모델 원점 = 발자국 가운데 땅)
"""
import glob
import importlib
import math
import os
import sys

import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import lib as K  # noqa: E402

PASS = {"Vent", "LampPt"}
STEP = 2.0


def fib_dirs(n):
    out = []
    g = math.pi * (3 - math.sqrt(5))
    for i in range(n):
        z = 1 - 2 * (i + 0.5) / n
        r = math.sqrt(1 - z * z)
        out.append(Vector((r * math.cos(g * i), r * math.sin(g * i), z)))
    return out


def build_bvh(objs):
    verts, polys, keys = [], [], []
    for ob in objs:
        key = ob.name.split("_", 1)[1] if "_" in ob.name else ob.name
        key = key.split(".")[0]
        mw = ob.matrix_world
        base = len(verts)
        verts += [mw @ v.co for v in ob.data.vertices]
        for p in ob.data.polygons:
            polys.append([base + i for i in p.vertices])
            keys.append(key)
    return BVHTree.FromPolygons(verts, polys, all_triangles=False), keys


def trace(bvh, keys, o, d, maxd=400.0):
    """앞면에 맞을 때까지(투명 재질은 지나감). 돌려줌: ('front'|'back'|'out', 위치, 재질, 거리)"""
    o = o.copy()
    gone = 0.0
    for _ in range(12):
        loc, nrm, idx, dist = bvh.ray_cast(o, d, maxd - gone)
        if loc is None:
            return "out", None, None, None
        gone += dist
        k = keys[idx]
        if k in PASS:
            o = loc + d * 1e-3
            continue
        return ("back" if nrm.dot(d) > 0 else "front"), loc, k, gone
    return "out", None, None, None


def rbx(p):
    return (round(-p.x, 1), round(p.z, 1), round(p.y, 1))


def door_exit(doors, o, d):
    """광선이 문 구멍으로 나갔나(문 벽 평면을 문 폭·높이 안에서 지나는가)"""
    for (px, py), w, h, f, ax in doors:
        if ax == "x":                     # 벽이 x 를 따라 — 평면 y = py
            if abs(d.y) < 1e-6:
                continue
            t = (py - o.y) / d.y
            if t <= 0:
                continue
            q = o + d * t
            if abs(q.x - px) <= w / 2 + 0.6 and q.z <= h + 3.0:
                return True
        else:                             # 벽이 y 를 따라 — 평면 x = px
            if abs(d.x) < 1e-6:
                continue
            t = (px - o.x) / d.x
            if t <= 0:
                continue
            q = o + d * t
            if abs(q.y - py) <= w / 2 + 0.6 and q.z <= h + 3.0:
                return True
    return False


def cluster(hits, cell=3.0):
    c = {}
    for p, k in hits:
        key = (k, round(p.x / cell), round(p.y / cell), round(p.z / cell))
        c.setdefault(key, []).append(p)
    out = []
    for (k, *_), ps in c.items():
        m = sum(ps, Vector()) / len(ps)
        out.append((len(ps), k, m))
    out.sort(key=lambda t: -t[0])
    return out


def scan(mod):
    K.L.clear_scene()
    objs, tris, _ = K.build_model(mod)
    bvh, keys = build_bvh(objs)
    lo = Vector((min(v[0] for ob in objs for v in ob.bound_box), min(v[1] for ob in objs for v in ob.bound_box), 0.0))
    hi = Vector((max(v[0] for ob in objs for v in ob.bound_box), max(v[1] for ob in objs for v in ob.bound_box),
                 max(v[2] for ob in objs for v in ob.bound_box)))
    doors = K.DOOR_INFO.get(mod.NAME, [])
    axes = [Vector(a) for a in ((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1))]
    dirs = fib_dirs(120)

    # ── 안쪽 자리
    inside = []
    z = 1.0
    while z < min(hi.z, 40.0):
        x = lo.x + 1.0
        while x < hi.x:
            y = lo.y + 1.0
            while y < hi.y:
                o = Vector((x, y, z))
                up = trace(bvh, keys, o, Vector((0, 0, 1)), 40.0)
                dn = trace(bvh, keys, o, Vector((0, 0, -1)), 3.5)
                if up[0] == "front" and dn[0] == "front":
                    # 닫힌 방만: 수평 넷이 모두 앞면(벽 안쪽)에 맞는 자리(처마 밑 마당·지붕 속 틈은 빠짐)
                    if all(trace(bvh, keys, o, a, 60.0)[0] == "front" for a in axes[:4]):
                        inside.append(o)
                y += STEP
            x += STEP
        z += 3.0
    back_in, gap = [], []
    for o in inside:
        for d in dirs:
            r = trace(bvh, keys, o, d, 120.0)
            if r[0] == "back":
                back_in.append((r[1], r[2]))
            elif r[0] == "out" and d.z > -0.2 and not door_exit(doors, o, d):
                gap.append((o + d * 6.0, "틈"))

    # ── 바깥 자리
    c = (lo + hi) / 2
    rad = max(hi.x - lo.x, hi.y - lo.y) / 2 + 10
    targets = []
    for tz in (1.5, 5.0, 10.0, 16.0, 24.0, 34.0):
        if tz > hi.z:
            continue
        for fx in (0.15, 0.35, 0.5, 0.65, 0.85):
            for fy in (0.15, 0.35, 0.5, 0.65, 0.85):
                targets.append(Vector((lo.x + (hi.x - lo.x) * fx, lo.y + (hi.y - lo.y) * fy, tz)))
    eyes = []
    for h in (4.5, 12.0, hi.z + 15.0):
        for i in range(24):
            a = 2 * math.pi * i / 24
            eyes.append(Vector((c.x + rad * math.cos(a), c.y + rad * math.sin(a), h)))
    back_out = []
    for e in eyes:
        for t in targets:
            d = (t - e).normalized()
            r = trace(bvh, keys, e, d, 400.0)
            if r[0] == "back":
                back_out.append((r[1], r[2]))
    return dict(inside=len(inside), back_in=cluster(back_in), gap=cluster(gap, 4.0), back_out=cluster(back_out),
                n_back_in=len(back_in), n_gap=len(gap), n_back_out=len(back_out))


def main():
    only = os.environ.get("ONLY")
    mods = []
    for p in sorted(glob.glob(os.path.join(HERE, "b_*.py"))):
        m = importlib.import_module(os.path.splitext(os.path.basename(p))[0])
        if not only or m.NAME in only.split(","):
            mods.append(m)
    lines = ["holes.py — 뒷면 구멍(Roblox 에서 비쳐 보임)·틈 구멍(문 말고 밖으로 트임). 좌표 = 로블록스 로컬 (x, y, z)", ""]
    for m in mods:
        r = scan(m)
        lines.append("■ %s  안쪽 자리 %d · 안에서 뒷면 %d · 틈 %d · 밖에서 뒷면 %d" % (m.NAME, r["inside"], r["n_back_in"], r["n_gap"], r["n_back_out"]))
        for label, cl in (("안에서 본 뒷면", r["back_in"]), ("밖에서 본 뒷면", r["back_out"]), ("틈(밖으로 트임)", r["gap"])):
            for n, k, p in cl[:8]:
                lines.append("   %-14s %4d  %-10s @ %s" % (label, n, k, rbx(p)))
        lines.append("")
        print(lines[-2 - min(24, len(lines) - 2)] if False else "%s 끝" % m.NAME)
    out = os.path.join(HERE, "holes.txt")
    with open(out, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(lines) + "\n")
    print("\n".join(lines))


main()
