# -*- coding: utf-8 -*-
"""
zfight_scan.py — 2026-10-24. 설원 마을 키트의 반짝임(z-fighting) 찾기·고치기.

사용자(2026-10-24): "겹쳐서 반짝거리는 부분들 다 체크해서 수정하고."
두 면이 같은 쪽을 보고(법선 0.01 안) 같은 평면(0.012 안)에서 넓이가 겹치면 카메라가 움직일 때 번갈아 비친다.
틀마다 모든 재질 덩이의 면을 법선·평면 칸으로 묶고, 칸 안에서 평면 위 2D 상자로 훑은 뒤 볼록 다각형을 잘라 겹친 넓이를 잰다.
빼는 것: 같은 모습(Snow_TownKit SKIN 의 색·재질이 같음 — 반짝여도 안 보임), 땅에 닿은 밑면,
겹친 곳 바로 앞(0.03)이 다른 덩이 속인 면(광선이 처음 맞힌 자리의 면 가운데 광선 쪽을 보는 것이 있으면 속 — 겹친 면까지 본다).

fix(g): 보이는 쌍마다 두 면 중 작은 쪽(띠·장식·판)을 제 법선 쪽으로 STEP 밀어(그 덩이의 꼭짓점을 옮겨 그만큼 두꺼워짐) 앞으로 나오게 한다.
  다시 재어 0 이 될 때까지 몇 번. 뜰처럼 다른 틀(같은 자리 건물)과 겹치면 extra 로 그 틀의 면을 주고 제 면만 민다.
  build_steam_town.py · build_kit_snow.py 가 내보내기 직전에 부른다.
보고: blender -b -P models/zfight_scan.py [-- 이름...]   → tools/zfight_kit.txt (두 키트, 고친 뒤 남은 것)
"""
import os
import sys
from collections import defaultdict

from mathutils import Vector
from mathutils.bvhtree import BVHTree

HERE = os.path.dirname(os.path.abspath(__file__))
SKIP = {"Cut", "Pane", "LampPt", "Vent"}
EPS_N, EPS_D, MIN_A, STEP = 0.01, 0.012, 0.03, 0.02


def _looks():
    """Snow_TownKit SKIN: 재질 이름 → (색, Studio 재질). 같은 모습끼리는 반짝여도 보이지 않는다"""
    import re
    src = open(os.path.join(HERE, "..", "tools", "Snow_TownKit.luau"), encoding="utf-8").read()
    return {m.group(1): (m.group(2).replace(" ", ""), m.group(3)) for m in re.finditer(r"^\t(\w+) = \{ RGB\(([\d, ]+)\), M\.(\w+) \}", src, re.M)}


LOOK = _looks()


def collect(g, tag, movable=True):
    """[(틀, 재질, 법선, 꼭짓점, 짝 후보?, BMFace 또는 None)]"""
    out = []
    for mat, grp in g.items():
        if mat in SKIP or not grp.bm.faces:
            continue
        grp.bm.normal_update()
        for f in grp.bm.faces:
            n = f.normal
            if n.length < 0.5:
                continue
            vs = [v.co.copy() for v in f.verts]
            ground = n.z < -0.99 and max(v.z for v in vs) < 0.05
            out.append((tag, mat, n.copy(), vs, not ground, f if movable else None))
    return out


def _clip(poly, a, b):
    out = []
    for i in range(len(poly)):
        p, q = poly[i], poly[(i + 1) % len(poly)]
        cp = (b[0] - a[0]) * (p[1] - a[1]) - (b[1] - a[1]) * (p[0] - a[0])
        cq = (b[0] - a[0]) * (q[1] - a[1]) - (b[1] - a[1]) * (q[0] - a[0])
        if cp >= 0:
            out.append(p)
        if (cp >= 0) != (cq >= 0):
            t = cp / (cp - cq)
            out.append((p[0] + t * (q[0] - p[0]), p[1] + t * (q[1] - p[1])))
    return out


def _area(poly):
    return 0.5 * sum(poly[i][0] * poly[(i + 1) % len(poly)][1] - poly[(i + 1) % len(poly)][0] * poly[i][1] for i in range(len(poly)))


def _visible(faces, bvh, poly2d, u, v, n, d):
    cx = sum(p[0] for p in poly2d) / len(poly2d)
    cy = sum(p[1] for p in poly2d) / len(poly2d)
    pts = [(cx, cy)] + [((cx + p[0]) / 2, (cy + p[1]) / 2) for p in poly2d[:4]]
    for a, b in pts:
        q = u * a + v * b + n * d + n * 0.03
        if q.z < 0.0:
            continue
        hit = bvh.ray_cast(q, n, 200.0)
        # 진짜 법선을 쓴다(광선이 주는 법선은 늘 광선 쪽으로 뒤집힌다). 겹친 면이 여럿일 수 있어 맞은 자리 둘레 면을 다 본다
        if hit[0] is not None and any(faces[k][2].dot(n) > 0.2 for _, _, k, _ in bvh.find_nearest_range(hit[0], 0.004)):
            continue
        return True
    return False


def find_pairs(faces):
    """보이는 반짝임 쌍 [(겹친 넓이, i, j)]"""
    allv, allp = [], []
    for f in faces:
        allp.append(list(range(len(allv), len(allv) + len(f[3]))))
        allv += [tuple(p) for p in f[3]]
    bvh = BVHTree.FromPolygons(allv, allp, epsilon=0.0)
    buckets = defaultdict(list)
    for fi, f in enumerate(faces):
        if not f[4]:
            continue
        n = f[2]
        buckets[((round(n.x / EPS_N), round(n.y / EPS_N), round(n.z / EPS_N)), round(n.dot(f[3][0]) / EPS_D))].append(fi)
    seen, out = set(), []
    for (nk, db), lst in buckets.items():
        cand = list(lst)
        for dd in (-1, 1):
            cand += buckets.get((nk, db + dd), [])
        if len(cand) < 2:
            continue
        n0 = faces[lst[0]][2]
        u = n0.cross(Vector((0, 0, 1)) if abs(n0.z) < 0.9 else Vector((1, 0, 0))).normalized()
        v = n0.cross(u).normalized()
        P = {}
        for fi in cand:
            pts = [(p.dot(u), p.dot(v)) for p in faces[fi][3]]
            if _area(pts) < 0:
                pts = pts[::-1]
            P[fi] = (pts, min(p[0] for p in pts), max(p[0] for p in pts), min(p[1] for p in pts), max(p[1] for p in pts))
        order = sorted(set(cand), key=lambda i: P[i][1])
        for ii, i in enumerate(order):
            for j in order[ii + 1:]:
                if P[j][1] >= P[i][2]:
                    break
                key = (min(i, j), max(i, j))
                if key in seen or P[j][3] >= P[i][4] or P[i][3] >= P[j][4]:
                    continue
                fa, fb = faces[i], faces[j]
                if fa[0] == fb[0] and fa[1] == fb[1]:
                    continue
                if LOOK.get(fa[1], fa[1]) == LOOK.get(fb[1], fb[1]):
                    continue
                di, dj = fa[2].dot(fa[3][0]), fb[2].dot(fb[3][0])
                if abs(di - dj) > EPS_D or (fa[2] - fb[2]).length > EPS_N * 1.5:
                    continue
                seen.add(key)
                poly = P[i][0]
                pj = P[j][0]
                for k in range(len(pj)):
                    poly = _clip(poly, pj[k], pj[(k + 1) % len(pj)])
                    if not poly:
                        break
                a = _area(poly) if len(poly) >= 3 else 0.0
                if a > MIN_A and _visible(faces, bvh, poly, u, v, fa[2], di):
                    out.append((a, i, j))
    return out


def fix(g, tag, extra=(), passes=12):
    """보이는 쌍마다 작은 쪽 면을 STEP 앞으로(같은 덩이 꼭짓점을 법선마다 한 번씩). 아홉째 번부터는 번갈아 큰 쪽도 민다
    (작은 쪽만 밀면 다른 면과 다시 겹쳐 오가는 곳이 있다). (민 면 수, 남은 쌍 수)"""
    total = 0
    for ps_i in range(passes):
        faces = collect(g, tag) + list(extra)
        ps = find_pairs(faces)
        if not ps:
            break
        done = set()
        for a, i, j in sorted(ps, reverse=True):
            mov = [k for k in (i, j) if faces[k][5] is not None and faces[k][5].is_valid]
            if not mov:
                continue
            pick = max if (ps_i >= 8 and ps_i % 2 == 1) else min
            k = pick(mov, key=lambda k: (faces[k][5].calc_area(), -k))
            f, n = faces[k][5], faces[k][2]
            nk = (round(n.x, 2), round(n.y, 2), round(n.z, 2))
            for vtx in f.verts:
                if (vtx, nk) not in done:
                    vtx.co += n * STEP
                    done.add((vtx, nk))
            total += 1
    left = len(find_pairs(collect(g, tag) + list(extra)))
    return total, left


def report(built):
    lines, total = [], 0
    for name, fs in built.items():
        if name.startswith("Svc_") and "Yard_" + name[4:] in built:
            continue
        if name.startswith("Yard_") and "Svc_" + name[5:] in built:
            fs = fs + built["Svc_" + name[5:]]
        ps = find_pairs(fs)
        if not ps:
            continue
        total += len(ps)
        lines.append("== %s : %d 쌍, 넓이 %.1f" % (name, len(ps), sum(p[0] for p in ps)))
        for a, i, j in sorted(ps, reverse=True)[:12]:
            c = sum(fs[i][3], Vector()) / len(fs[i][3])
            lines.append("     %.2f  %s/%s × %s/%s  at %s  n %s" % (a, fs[i][0], fs[i][1], fs[j][0], fs[j][1],
                                                              tuple(round(x, 2) for x in c), tuple(round(x, 2) for x in fs[i][2])))
    lines.insert(0, "반짝임 쌍 합계 %d (틀 %d)" % (total, len(built)))
    return lines


if __name__ == "__main__":
    sys.path.insert(0, HERE)
    import hanok_lib as L
    import build_steam_town as T
    import build_steam as S
    import build_props as PR
    only = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    L.clear_scene()
    built = {}
    jobs = [(n, p, f, T.G) for n, p, f in T.JOBS] + [(n, p, f, S.G) for n, p, f, _ in S.JOBS + PR.JOBS]
    svc_faces = {}
    for name, prefix, fn, G in jobs:
        if only and name not in only and not (name.startswith("Svc_") and "Yard_" + name[4:] in only):
            continue
        g = G(prefix)
        fn(g)
        extra = svc_faces.get("Svc_" + name[5:], ()) if name.startswith("Yard_") else ()
        moved, left = fix(g, name, extra)
        key = name if name not in built else "%s(%s)" % (name, prefix)      # 두 키트에 같은 이름(옛 겉모습)이 있다
        built[key] = collect(g, name, movable=False)
        if name.startswith("Svc_"):
            svc_faces[name] = built[key]
        print("  %-18s 민 면 %d, 남음 %d" % (name, moved, left))
        for grp in g.values():
            grp.bm.free()
    lines = report(built)
    out = os.path.join(HERE, "..", "tools", "zfight_kit.txt")
    with open(out, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(lines) + "\n")
    print("\n".join(lines[:60]))
