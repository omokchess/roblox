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

# (2팀 2026-11-18) 문 높이 판정: lib.DOOR_INFO 에는 문 밑 높이(z0)가 없어 2층 문(여관 발코니 문, z0 14.4)으로 나간 광선을 틈으로 셌다.
# lib.py 는 공용이라 고치지 않고, 여기서 door_open 을 감싸 z0 를 따로 적는다(DOOR_INFO 와 같은 순서).
DOOR_Z = {}
_door_open = K.door_open


def _door_open_z(g, ax, c, u, w, h, z0, *a, **kw):
    DOOR_Z.setdefault(K._name(), []).append(z0)
    return _door_open(g, ax, c, u, w, h, z0, *a, **kw)


K.door_open = _door_open_z


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


def door_exit(doors, o, d, zs=()):
    """광선이 문 구멍으로 나갔나(문 벽 평면을 문 폭·높이 안에서 지나는가). zs = 문마다 밑 높이(없으면 2 = FZ 로 본다 — 바닥 문은 예전과 같은 h + 3)"""
    for k, ((px, py), w, h, f, ax) in enumerate(doors):
        z0 = zs[k] if k < len(zs) else 2.0
        zlo, zhi = z0 - 0.5, z0 + h + 1.0
        if ax == "x":                     # 벽이 x 를 따라 — 평면 y = py
            if abs(d.y) < 1e-6:
                continue
            t = (py - o.y) / d.y
            if t <= 0 and abs(py - o.y) > 0.8:       # (2팀) 출발점이 문 구멍 속(벽 두께 안)이면 이미 평면을 지났어도 문으로 나간 것
                continue
            q = o + d * t
            if abs(q.x - px) <= w / 2 + 0.6 and zlo <= q.z <= zhi:
                return True
        else:                             # 벽이 y 를 따라 — 평면 x = px
            if abs(d.x) < 1e-6:
                continue
            t = (px - o.x) / d.x
            if t <= 0 and abs(px - o.x) > 0.8:
                continue
            q = o + d * t
            if abs(q.y - py) <= w / 2 + 0.6 and zlo <= q.z <= zhi:
                return True
    return False


def in_zone(zones, o):
    """(2팀 2026-11-18) 건물 파일의 OPEN_ZONES = [(x0, x1, y0, y1, z0, z1, 이유)] — 일부러 트인 자리(회랑·차양 밑·망루·격자탑).
    그 안의 점에서 밖으로 나가는 광선은 틈으로 세지 않는다(뒷면은 그대로 센다)"""
    return any(z[0] <= o.x <= z[1] and z[2] <= o.y <= z[3] and z[4] <= o.z <= z[5] for z in zones)


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
    dz = DOOR_Z.get(mod.NAME, [])
    zones = getattr(mod, "OPEN_ZONES", ())
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
    # (1팀 2026-11-18) 판 속 자리 빼기: 지붕 개판·덮개·눈 판이 맞닿은 같은 평면(위·아래 면이 한 자리)에서 광선이
    # 아무 면이나 먼저 돌려줘, 판 속(덮개 0.4 속) 자리가 '안쪽'으로 뽑혀 판 안벽을 '안에서 본 뒷면'으로 셌다(잡화 622·대장간 491·시계탑 10 전부).
    # 사람(눈)이 설 수 있는 자리만: 가장 가까운 면까지 0.5 이상 + 120 방향 중 뒷면에 맞는 것이 절반 미만(절반 넘으면 덩이 속)
    solid = n_air = n_hid = 0
    back_in, gap = [], []
    keep = []
    # (1팀 2026-11-18) 방에서 보이는 자리만: 처마·박공 내밈 서까래 칸(벽 밖) 자리가 사방이 서까래·도리에 맞아 '안쪽'으로 뽑혔다(물약 16).
    # 건물 INFO 의 카운터 앞 빈 바닥·통로 끝(층마다)에서 눈높이로 곧게 보이는 자리만 센다. INFO 가 없으면 이 거름은 건너뛴다
    seeds = []
    info = getattr(mod, "INFO", None) or {}
    for sub in [info] + list(info.get("floors", ())):
        if "free" in sub and "floor" in sub:
            fx0, fx1, fy0, fy1 = sub["free"]
            seeds.append(Vector(((fx0 + fx1) / 2, (fy0 + fy1) / 2, sub["floor"] + K.EYE)))
        if "walk" in sub and "floor" in sub:
            seeds.append(Vector((sub["walk"][1][0], sub["walk"][1][1], sub["floor"] + K.EYE)))
    seeds += [Vector(v) for v in info.get("hole_seeds", ())]        # 건물 파일이 더하는 눈 자리(금고실·회랑 등)
    n_open = 0
    for o in inside:
        if bvh.find_nearest(o)[3] < 0.5:
            solid += 1
            continue
        if seeds and not any(trace(bvh, keys, e, (o - e).normalized(), (o - e).length)[0] == "out" for e in seeds):
            n_hid += 1
            continue
        rs = [(d, trace(bvh, keys, o, d, 120.0)) for d in dirs]
        if sum(1 for _, r in rs if r[0] == "back") * 2 > len(rs):
            solid += 1
            continue
        # 처마 밑·박공 내밈 서까래 칸처럼 바깥(문 말고)으로 4 분의 1 넘게 트인 자리는 방이 아니다(바깥 공기) — 방의 틈은 몇 줄기다
        if sum(1 for d, r in rs if r[0] == "out" and not door_exit(doors, o, d, dz)) * 4 > len(rs):
            n_air += 1
            continue
        keep.append(o)
        opened = in_zone(zones, o)
        n_open += opened
        for d, r in rs:
            if r[0] == "back":
                back_in.append((r[1], r[2]))
            elif r[0] == "out" and d.z > -0.2 and not opened and not door_exit(doors, o, d, dz):
                gap.append((o + d * 6.0, "틈"))
    inside = keep
    # (1팀 2026-11-18) 김(Vent): Studio 는 Vent 덩이 하나에 ParticleEmitter 하나를 달고, 입자는 그 메시 '상자 전체'에서 나온다.
    # 김 자리가 둘 이상 떨어져 있으면 상자가 방을 덮어 방 안에서 김이 피어난다 → 안쪽 자리가 Vent 상자(+1) 안에 들면 걸림
    vent_box, vent_in, vent_cover = None, 0, []
    for ob in objs:
        if ob.name.split("_", 1)[-1].split(".")[0] == "Vent" and len(ob.data.vertices):
            vs = [ob.matrix_world @ v.co for v in ob.data.vertices]
            vent_box = (Vector([min(v[i] for v in vs) for i in range(3)]), Vector([max(v[i] for v in vs) for i in range(3)]))
            vent_in = sum(1 for o in inside if all(vent_box[0][i] - 1 <= o[i] <= vent_box[1][i] + 1 for i in range(3)))
            # 김 자리(0.6 상자 = 꼭짓점 8 개씩)마다 위가 트였나 — 지붕·천장·처마 밑이면 김이 그것을 뚫고 나온다(방 안이면 방 안에 김)
            for k in range(0, len(vs) - 7, 8):
                cc = sum(vs[k:k + 8], Vector()) / 8
                r = trace(bvh, keys, cc + Vector((0, 0, 1.0)), Vector((0, 0, 1)), 80.0)     # 1.0 위부터 — 굴뚝 쇠 갓(0.5~0.95 위)은 김이 옆으로 나가니 괜찮다
                if r[0] != "out":
                    vent_cover.append((cc, r[2]))

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
                n_back_in=len(back_in), n_gap=len(gap), n_back_out=len(back_out), solid=solid, air=n_air, hid=n_hid, vent_box=vent_box, vent_in=vent_in, vent_cover=vent_cover,
                n_open=n_open, zones=zones)


def main():
    only = os.environ.get("ONLY")
    mods = []
    if os.environ.get("HOLES_MOD"):     # (1팀 2026-11-24) 다른 키트 모델: NAME·PREFIX·build·INFO 를 가진 .py (예: models/figuren_check.py — 기물군 본부)
        import importlib.util as _ilu   # (2팀 2026-11-24) 'import importlib.util' 이 함수 안에서 importlib 를 지역 이름으로 만들어 HOLES_MOD 없을 때 아래 줄이 UnboundLocalError → 별명으로
        spec = _ilu.spec_from_file_location("holes_extra", os.environ["HOLES_MOD"])
        m = _ilu.module_from_spec(spec)
        spec.loader.exec_module(m)
        mods.append(m)
    for p in sorted(glob.glob(os.path.join(HERE, "b_*.py"))) if not os.environ.get("HOLES_MOD") else ():
        m = importlib.import_module(os.path.splitext(os.path.basename(p))[0])
        if not only or m.NAME in only.split(","):
            mods.append(m)
    lines = ["holes.py — 뒷면 구멍(Roblox 에서 비쳐 보임)·틈 구멍(문 말고 밖으로 트임). 좌표 = 로블록스 로컬 (x, y, z)", ""]
    for m in mods:
        r = scan(m)
        lines.append("■ %s  안쪽 자리 %d · 안에서 뒷면 %d · 틈 %d · 밖에서 뒷면 %d · 김 상자 속 안쪽 자리 %d · 위 막힌 김 %d  (판 속이라 뺀 자리 %d · 바깥 공기라 뺀 자리 %d · 방에서 안 보여 뺀 자리 %d)" % (
            m.NAME, r["inside"], r["n_back_in"], r["n_gap"], r["n_back_out"], r["vent_in"], len(r["vent_cover"]), r["solid"], r["air"], r["hid"])
            + (" · 일부러 트인 자리 안 점 %d(틈 안 셈)" % r["n_open"] if r["zones"] else ""))
        for z in r["zones"]:      # (2팀) 건물 파일 OPEN_ZONES — 이유와 함께 적는다
            lines.append("   트인 자리(블렌더 x %.1f..%.1f y %.1f..%.1f z %.1f..%.1f): %s" % tuple(z))
        if r["vent_box"]:
            a, b = r["vent_box"]
            lines.append("   김(Vent) 상자 로블록스 %s ~ %s  크기 %.1f×%.1f×%.1f" % (rbx(a), rbx(b), b.x - a.x, b.z - a.z, b.y - a.y))
        for cc, k in r["vent_cover"]:
            lines.append("   김 자리 위가 막힘(%s) @ %s" % (k, rbx(cc)))
        for label, cl in (("안에서 본 뒷면", r["back_in"]), ("밖에서 본 뒷면", r["back_out"]), ("틈(밖으로 트임)", r["gap"])):
            for n, k, p in cl[:8]:
                lines.append("   %-14s %4d  %-10s @ %s" % (label, n, k, rbx(p)))
        lines.append("")
        print(lines[-2 - min(24, len(lines) - 2)] if False else "%s 끝" % m.NAME)
    out = os.environ.get("HOLES_OUT") or os.path.join(HERE, "holes.txt")     # (1팀) 두 팀이 같이 돌릴 때 HOLES_OUT 으로 따로 쓴다
    with open(out, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(lines) + "\n")
    print("\n".join(lines))


main()
