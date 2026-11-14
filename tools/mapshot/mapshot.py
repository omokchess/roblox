# -*- coding: utf-8 -*-
"""
mapshot.py — 지역 공용 사진 도구 (2026-11-14, 프로그래밍 부서). 기준: 회사/맵_기준.md 3·4절.

지형 자료로 블렌더 장면을 짓고 ① 위에서 내려다본 3D 렌더 ② 1인칭(눈높이 4.5, 세로 시야각 70°, 1280x720) 사진
③ 꽉참 지수·꽉참 지도 ④ 사진판 ⑤ 지수.txt ⑥ shots.json 을 한 번에 뽑는다. 지역마다 어댑터(scene_<지역>.py)만 새로 쓴다.

■ 돌리기:  "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b -P tools/mapshot/scene_<지역>.py
   (어댑터가 아래 API 로 장면을 만들고 마지막에 ms.run(scene, out_dir) 를 부른다. 설원 본보기 = scene_snow_town3.py)

■ 장면 설명(파이썬 API, 좌표는 전부 **로블록스** (x 동, y 위, z 남) 스터드 — 변환은 이 파일 안에서만)
   S = ms.Scene("지역이름", bounds=(x0, x1, z0, z1))        위에서 본 그림이 덮는 범위
   S.boxes(kind, rows, color, emit=0)    rows = [(x0, x1, y0, y1, z0, z1), ...] 축 맞춘 상자. color = (r,g,b) 0~255 또는 "#rrggbb".
   S.oriented(kind, cx, cy, cz, length, width, thick, dx, dz, color)   (dx, dz) 방향으로 길이 length 인 얇은 판(길 조각)
   S.cone(kind, cx, y, cz, r, h, color, n=8) / S.convex(kind, 로블록스 꼭짓점 목록, 면 목록, color)   나무·지붕 같은 볼록 덩어리
   S.place(objs, x, y, z, yaw, kind="building")     블렌더에서 지은 오브젝트(키트 모델: 블렌더 로컬 (x, y 뒤, z 위), 앞 = -y)를
                                                    로블록스 자리·yaw 에 앉힌다. yaw 0 = 앞이 북(-Z), 90 = 서, 180 = 남(로블록스 CFrame.Angles(0, rad(yaw), 0))
   S.light(x, y, z, color, power)        점광(그림자 없음)    S.landmark(x, y, z)  랜드마크 꼭대기 점
   S.walk_grid(x0, z0, cell, H)          걸을 수 있는 면: H[j][i] = 칸 (i, j) 의 바닥 y, 못 걷는 칸은 nan (i 가 x, j 가 z 방향)
   kind: ground(맨바닥) slab(눈 판) terrace(건물 단) step(넓은 단) path(길·광장) rock(바위 몸통) snowcap(바위 윗면 눈)
         building prop context(둘레 지형)
   ms.run(S, out_dir, seed=20261114)

■ 좌표 규칙: 로블록스 (x, y, z) → 블렌더 (x, -z, y). 키트 모델 블렌더 로컬 (bx, by, bz) → 로블록스 로컬 (-bx, bz, by)
   → yaw 돌림 → 이동. 합치면 블렌더 월드 = Rz(180° + yaw) · local + (x, -z, y). 앞(-by)은 yaw 0 에서 북(+Y 블렌더)을 본다.
   위에서 본 그림은 위 = 북(블렌더 +Y = 로블록스 -Z), 오른쪽 = 동.

■ 꽉참 지수 (0~100, 높을수록 꽉 참)  — 맵_기준.md 3절 표의 통과 기준에서 벗어난 만큼 깎는 가중합
   하늘 15 : 하늘% ≤ 45 만점, 90 에서 0 (선형)            맨바닥 15 : 맨바닥% ≤ 35 만점, 85 에서 0
   겹 15 · 하늘선 10 · 수평선 15 · 랜드마크 10 · 민짜 면 20 : 민짜 면% ≤ 25 만점, 75 에서 0 (아래)
   겹 15   : 겹 수/2 (≥2 만점)                             하늘선 10 : 하늘선 표준편차/0.05 (≥0.05 만점)
   (수평선 = 막힌 방향 수/6, 자리마다 / 랜드마크 = 보이면 만점 (자리마다))
   민짜 면 % = 거리 30 안에서 맞은 (kind, 같은 평면) 묶음 중 가장 큰 것이 화면에서 차지하는 비율. 위를 보는 면(바닥·바위 윗면)은 뺀다.
   지역 값(지수에 안 넣음, 지수.txt·사진판 머리에 통과/미달): 열림 비율 = 걸을 수 있는 땅 넓이/bounds 넓이 (30~50%),
   크기 위계 = rock 덩어리(발자국이 겹치거나 2 안으로 붙은 상자끼리)를 폭 큰 60↑/중 20~60/작 20↓ 로 나눈 넓이 비(큰 것 ≥ 40%) + 상자 하나하나 긴 변 분포.
   앞 넷은 방향마다 재어 여덟 방향 평균(자리 지수) — 사진 한 장의 지수는 그 방향 값. 뒤 둘은 자리 값.
   지도: 8 스터드 격자, 방향마다 광선 24x9. 사진: 광선 64x36. 지도 색: 60 미만 빨강 / 60~70 주황 / 70~85 연두 / 85~ 초록.
   - 하늘 = 아무것도 안 맞은 광선(허공 포함). 맨바닥 = 위를 보는 면에 맞고 kind 가 ground·slab·terrace·context(둘레 평지) 인 광선
     (눈 판·건물 단 윗면도 "꾸밈 없는 눈 바닥"으로 센다 — 느슨하게 하지 않으려고). 길·넓은 단 윗면은 맨바닥도 물건도 아님.
     나머지(바위·건물·소품·단 옆면·둘레 산·바위 윗눈)는 물건.
   - 겹: 물건 광선이 거리 0~30 / 30~120 / 120~ 에서 각각 화면의 3% 이상이면 그 겹이 있다.
   - 하늘선 변화 = 화면 열마다 (맨 위에서 처음 하늘이 아닌 행) 높이/화면높이 의 표준편차.
   - 수평선 막힘 = 눈높이 수평 광선 8방향(45° 간격)이 300 안에서 ground 아닌 것에 맞은 수.
   - 랜드마크 = 눈 → 랜드마크 점 직선이 안 막힘(어느 한 점이라도).
■ 알려진 한계: 맨바닥 "반지름 20 맨바닥 원" 은 재지 않는다(지도 위에서 눈으로). 지도의 하늘선은 9행이라 거칠다(0.11 단위).
"""
import json
import math
import os
import random
import time

import bmesh
import bpy
import gpu
import blf
import numpy as np
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

KINDS = ["ground", "slab", "terrace", "step", "path", "rock", "snowcap", "building", "prop", "context"]
KID = {k: i for i, k in enumerate(KINDS)}
BARE_K = frozenset(KID[k] for k in ("ground", "slab", "terrace", "context"))
FLOOR_K = frozenset(KID[k] for k in ("path", "step"))
GROUND_ID = KID["ground"]
SKY, BARE, FLOOR, THING = 0, 1, 2, 3
EYE = 4.5
FOV_V = 70.0
ASPECT = 16.0 / 9.0
W_SKY, W_BARE, W_LAYER, W_LINE, W_HOR, W_LM, W_FLAT = 15, 15, 15, 10, 15, 10, 20
FONT = "C:/Program Files/Blender Foundation/Blender 5.2/5.2/datafiles/fonts/Noto Sans CJK Regular.woff2"


def log(*a):
    print("[mapshot]", *a, flush=True)


# ------------------------------------------------------------------ 색
def _lin(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def rgb255(c):
    if isinstance(c, str):
        h = c.lstrip("#")
        return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))
    return tuple(int(v) for v in c[:3])


_MATS = {}


def make_mat(rgb, emit=0.0, name="m"):
    key = (rgb, round(emit, 2))
    m = _MATS.get(key)
    if m:
        return m
    m = bpy.data.materials.new("%s_%02x%02x%02x%s" % (name, *rgb, "_e" if emit else ""))
    m.use_nodes = True
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    lin = tuple(_lin(v) for v in rgb)
    bsdf.inputs["Base Color"].default_value = (*lin, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.92
    for nm in ("Specular IOR Level", "Specular"):
        if nm in bsdf.inputs:
            bsdf.inputs[nm].default_value = 0.15
    if emit:
        bsdf.inputs["Emission Color"].default_value = (*lin, 1.0)
        bsdf.inputs["Emission Strength"].default_value = emit
    m.diffuse_color = (*lin, 1.0)
    _MATS[key] = m
    return m


# ------------------------------------------------------------------ 상자 꼭짓점
_CV = np.array([[-1, -1, -1], [1, -1, -1], [1, 1, -1], [-1, 1, -1], [-1, -1, 1], [1, -1, 1], [1, 1, 1], [-1, 1, 1]], np.float64)
_CF = np.array([[0, 3, 2, 1], [4, 5, 6, 7], [0, 1, 5, 4], [2, 3, 7, 6], [3, 0, 4, 7], [1, 2, 6, 5]], np.int64)


def rbx_to_bl(x, y, z):
    return (x, -z, y)


class Scene:
    def __init__(self, name, bounds):
        self.name, self.bounds = name, bounds
        self.groups = {}           # (kind, rgb, emit) → [verts 목록, faces 목록, 꼭짓점 수]
        self.lights, self.landmarks = [], []
        self.walk = None
        self.nobj = 0
        self.rects = []            # rock 발자국 (x0, x1, z0, z1)

    # -- 모으기
    def _grp(self, kind, color, emit):
        key = (kind, rgb255(color), emit)
        return self.groups.setdefault(key, [[], [], 0])

    def _push(self, kind, color, emit, V, F):
        g = self._grp(kind, color, emit)
        g[0].append(V)
        g[1].append(F + g[2])
        g[2] += len(V)

    def _cubes(self, kind, color, emit, c, h, psi):
        """c, h = (N,3) 블렌더 중심·반 크기, psi = (N,) 블렌더 z 축 돌림"""
        c, h, psi = np.asarray(c, float), np.asarray(h, float), np.asarray(psi, float)
        n = len(c)
        if not n:
            return
        off = _CV[None, :, :] * h[:, None, :]
        cs, sn = np.cos(psi)[:, None], np.sin(psi)[:, None]
        x, y = off[:, :, 0], off[:, :, 1]
        V = np.stack([cs * x - sn * y, sn * x + cs * y, off[:, :, 2]], axis=2) + c[:, None, :]
        F = (_CF[None, :, :] + (np.arange(n) * 8)[:, None, None]).reshape(-1, 4)
        F = np.concatenate([F[:, [0, 1, 2]], F[:, [0, 2, 3]]])
        self._push(kind, color, emit, V.reshape(-1, 3), F)
        self.nobj += n

    def boxes(self, kind, rows, color, emit=0.0):
        r = np.asarray(rows, float).reshape(-1, 6)
        if kind == "rock":
            self.rects += [tuple(q) for q in r[:, [0, 1, 4, 5]].tolist()]
        c = np.stack([(r[:, 0] + r[:, 1]) / 2, -(r[:, 4] + r[:, 5]) / 2, (r[:, 2] + r[:, 3]) / 2], 1)
        h = np.stack([(r[:, 1] - r[:, 0]) / 2, (r[:, 5] - r[:, 4]) / 2, (r[:, 3] - r[:, 2]) / 2], 1)
        self._cubes(kind, color, emit, c, h, np.zeros(len(r)))

    def oriented(self, kind, cx, cy, cz, length, width, thick, dx, dz, color, emit=0.0):
        psi = math.atan2(-dz, dx)
        self._cubes(kind, color, emit, [(cx, -cz, cy)], [(length / 2, width / 2, thick / 2)], [psi])

    def convex(self, kind, verts_rbx, faces, color, emit=0.0):
        V = np.array([rbx_to_bl(*p) for p in verts_rbx], float)
        F = [list(f) for f in faces]
        cen = V.mean(0)
        out = []
        for f in F:                                   # 바깥 보기로 감는 순서를 맞춘다(볼록 덩어리 전제)
            p = V[f]
            nrm = np.cross(p[1] - p[0], p[2] - p[0])
            if np.dot(nrm, p.mean(0) - cen) < 0:
                f = f[::-1]
            out.append(f)
        # 면이 3·4 각형 섞여도 되도록 삼각형으로 쪼갠다
        tris = []
        for f in out:
            for k in range(1, len(f) - 1):
                tris.append([f[0], f[k], f[k + 1]])
        self._push(kind, color, emit, V, np.array(tris, np.int64))
        self.nobj += 1

    def cone(self, kind, cx, y, cz, r, h, color, n=8):
        pts = [(cx + r * math.cos(2 * math.pi * k / n), y, cz + r * math.sin(2 * math.pi * k / n)) for k in range(n)]
        pts.append((cx, y + h, cz))
        pts.append((cx, y, cz))
        faces = [[k, (k + 1) % n, n] for k in range(n)] + [[(k + 1) % n, k, n + 1] for k in range(n)]
        self.convex(kind, pts, faces, color)

    def place(self, objs, x, y, z, yaw, kind="building", name=None):
        a = math.pi + math.radians(yaw)
        M = Matrix.Rotation(a, 4, "Z")
        M.translation = Vector(rbx_to_bl(x, y, z))
        for ob in objs:
            ob["kind"] = kind
            ob.matrix_world = M @ ob.matrix_world
            self.nobj += 1
        return M

    def instance(self, objs, x, y, z, yaw, kind="prop"):
        """이미 지은 오브젝트의 메시를 나눠 쓰는 복사본을 앉힌다(가스등 같은 되풀이 소품)"""
        out = []
        a = math.pi + math.radians(yaw)
        M = Matrix.Rotation(a, 4, "Z")
        M.translation = Vector(rbx_to_bl(x, y, z))
        for ob in objs:
            n = bpy.data.objects.new(ob.name + "_i", ob.data)
            bpy.context.collection.objects.link(n)
            n.matrix_world = M @ ob.matrix_world
            n["kind"] = kind
            out.append(n)
        self.nobj += 1
        return M, out

    def light(self, x, y, z, color=(255, 190, 120), power=300.0):
        self.lights.append((x, y, z, rgb255(color), power))

    def landmark(self, x, y, z):
        self.landmarks.append((x, y, z))

    def walk_grid(self, x0, z0, cell, H):
        self.walk = (x0, z0, cell, np.asarray(H, float))

    # -- 블렌더 오브젝트로 굳히기
    def build(self):
        for (kind, rgb, emit), (vs, fs, _) in self.groups.items():
            V, F = np.concatenate(vs), np.concatenate(fs)
            me = bpy.data.meshes.new("%s_%02x%02x%02x" % (kind, *rgb))
            n, m = len(V), len(F)
            me.vertices.add(n)
            me.vertices.foreach_set("co", V.astype(np.float32).ravel())
            cnt = F.shape[1]
            me.loops.add(m * cnt)
            me.polygons.add(m)
            me.loops.foreach_set("vertex_index", F.astype(np.int32).ravel())
            me.polygons.foreach_set("loop_start", np.arange(m, dtype=np.int32) * cnt)
            me.polygons.foreach_set("loop_total", np.full(m, cnt, np.int32))
            me.update()
            me.validate()
            me.materials.append(make_mat(rgb, emit, kind))
            ob = bpy.data.objects.new(me.name, me)
            ob["kind"] = kind
            bpy.context.collection.objects.link(ob)
        self.groups = {}
        for (x, y, z, col, p) in self.lights:
            ld = bpy.data.lights.new("lamp", "POINT")
            ld.color = tuple(_lin(v) for v in col)
            ld.energy = p
            ld.shadow_soft_size = 0.6
            ld.use_shadow = False
            lo = bpy.data.objects.new("lamp", ld)
            lo.location = rbx_to_bl(x, y, z)
            bpy.context.collection.objects.link(lo)


# ------------------------------------------------------------------ 광선(BVH 하나에 장면 전체)
class Rays:
    def __init__(self):
        dg = bpy.context.evaluated_depsgraph_get()
        V, T, K = [], [], []
        base = 0
        for ob in bpy.context.scene.objects:
            if ob.type != "MESH" or "kind" not in ob or ob.hide_render:
                continue
            ev = ob.evaluated_get(dg)
            me = ev.to_mesh()
            me.calc_loop_triangles()
            nv, nt = len(me.vertices), len(me.loop_triangles)
            if not nt:
                ev.to_mesh_clear()
                continue
            co = np.empty(nv * 3, np.float64)
            me.vertices.foreach_get("co", co)
            co = co.reshape(-1, 3)
            M = np.array(ev.matrix_world)
            V.append(co @ M[:3, :3].T + M[:3, 3])
            tr = np.empty(nt * 3, np.int64)
            me.loop_triangles.foreach_get("vertices", tr)
            T.append(tr.reshape(-1, 3) + base)
            K.append(np.full(nt, KID[ob["kind"]], np.int8))
            base += nv
            ev.to_mesh_clear()
        V, T = np.concatenate(V), np.concatenate(T)
        self.kind = bytes(np.concatenate(K).tolist())
        self.tris = len(T)
        v0, v1, v2 = V[T[:, 0]], V[T[:, 1]], V[T[:, 2]]
        nn = np.cross(v1 - v0, v2 - v0)
        nn /= np.maximum(np.linalg.norm(nn, axis=1), 1e-12)[:, None]
        dd = (nn * v0).sum(1)
        key = np.column_stack([np.round(nn * 50), np.round(dd * 4), np.concatenate(K)])
        self.gid = np.unique(key, axis=0, return_inverse=True)[1].ravel().tolist()
        self.bvh = BVHTree.FromPolygons(V.tolist(), T.tolist(), epsilon=0.0)

    def cast(self, o, dirs):
        """방향 목록 → (범주 배열, 거리 배열). 범주: 0 하늘 1 맨바닥 2 길 3 물건"""
        rc, kind = self.bvh.ray_cast, self.kind
        n = len(dirs)
        cat, dist, gid = [0] * n, [1e9] * n, [-1] * n
        gids = self.gid
        for i, d in enumerate(dirs):
            loc, nrm, idx, dd = rc(o, d, 3000.0)
            if idx is None:
                continue
            k = kind[idx]
            up = nrm.z > 0.9
            cat[i] = 1 if (up and k in BARE_K) else (2 if (up and k in FLOOR_K) else 3)
            dist[i] = dd
            if dd < 30 and cat[i] == 3 and nrm.z <= 0.9:
                gid[i] = gids[idx]
        return np.array(cat, np.int8), np.array(dist, np.float32), np.array(gid, np.int64)

    def horizon(self, o, hdirs):
        rc, kind = self.bvh.ray_cast, self.kind
        n = 0
        for d in hdirs:
            loc, nrm, idx, dd = rc(o, d, 300.0)
            if idx is not None and kind[idx] != GROUND_ID:
                n += 1
        return n

    def lm_visible(self, o, lms):
        rc = self.bvh.ray_cast
        for p in lms:
            v = p - o
            L = v.length
            if rc(o, v / L, max(L - 0.6, 0.1))[0] is None:
                return 1
        return 0

    def lm_blocker(self, o, lms):
        """첫 랜드마크까지 직선이 막히면 막은 kind 이름(안 막히면 None)"""
        v = lms[0] - o
        L = v.length
        loc, nrm, idx, dd = self.bvh.ray_cast(o, v / L, max(L - 0.6, 0.1))
        return None if idx is None else KINDS[self.kind[idx]]


def view_dirs(heading, nx, ny):
    """블렌더 xy 평면 heading(라디안, +X 가 0, +Y 가 90°) 쪽을 보는 화면의 nx*ny 광선(행 위→아래, 열 왼→오른)"""
    th = math.tan(math.radians(FOV_V / 2))
    tw = th * ASPECT
    f = Vector((math.cos(heading), math.sin(heading), 0.0))
    r = Vector((math.sin(heading), -math.cos(heading), 0.0))
    out = []
    for j in range(ny):
        yy = (1 - (j + 0.5) / ny * 2) * th
        for i in range(nx):
            xx = ((i + 0.5) / nx * 2 - 1) * tw
            out.append((f + r * xx + Vector((0, 0, yy))).normalized())
    return out


HEADS8 = [k * math.pi / 4 for k in range(8)]
HDIRS8 = [Vector((math.cos(h), math.sin(h), 0.0)) for h in HEADS8]


def view_metrics(cat, dist, gid, nx, ny):
    c = cat.reshape(ny, nx)
    d = dist.reshape(ny, nx)
    sky = float((c == SKY).mean() * 100)
    bare = float((c == BARE).mean() * 100)
    thing = c == THING
    layers = int(sum(((thing & m).mean() >= 0.03) for m in (d < 30, (d >= 30) & (d < 120), d >= 120)))
    nonsky = c != SKY
    first = np.where(nonsky.any(0), nonsky.argmax(0), ny)
    std = float(np.std(1.0 - first / ny))
    g = gid[gid >= 0]
    flat = float(np.bincount(g).max() / len(gid) * 100) if len(g) else 0.0
    return dict(sky=sky, bare=bare, layers=layers, std=std, flat=flat)


def sub_scores(m, hor, lm):
    s = dict(
        sky=1.0 if m["sky"] <= 45 else max(0.0, 1 - (m["sky"] - 45) / 45),
        bare=1.0 if m["bare"] <= 35 else max(0.0, 1 - (m["bare"] - 35) / 50),
        layers=min(1.0, m["layers"] / 2),
        line=min(1.0, m["std"] / 0.05),
        hor=min(1.0, hor / 6),
        lm=float(lm),
        flat=1.0 if m["flat"] <= 25 else max(0.0, 1 - (m["flat"] - 25) / 50),
    )
    vs = W_SKY * s["sky"] + W_BARE * s["bare"] + W_LAYER * s["layers"] + W_LINE * s["line"] + W_FLAT * s["flat"]
    s["view"] = vs / (W_SKY + W_BARE + W_LAYER + W_LINE + W_FLAT)
    s["index"] = vs + W_HOR * s["hor"] + W_LM * s["lm"]
    return s


def shortfalls(m, hor, lm):
    out = []
    if m["sky"] > 45:
        out.append("하늘 %d%%" % round(m["sky"]))
    if m["bare"] > 35:
        out.append("맨바닥 %d%%" % round(m["bare"]))
    if m["layers"] < 2:
        out.append("겹 %d" % m["layers"])
    if m["std"] < 0.05:
        out.append("하늘선 %.2f" % m["std"])
    if m["flat"] > 25:
        out.append("민짜 면 %d%%" % round(m["flat"]))
    if hor < 6:
        out.append("수평선 막힘 %d/8" % hor)
    if not lm:
        out.append("랜드마크 안 보임")
    return "·".join(out) if out else "통과"


# ------------------------------------------------------------------ 글자(블렌더 글꼴 → 마스크)
_FID = None
_TXT = {}


def text_mask(txt, size):
    global _FID
    key = (txt, size)
    if key in _TXT:
        return _TXT[key]
    gpu.init()
    if _FID is None:
        _FID = blf.load(FONT)
    blf.size(_FID, size)
    w, h = blf.dimensions(_FID, txt)
    W, H = int(w) + 8, int(size * 1.5) + 4
    off = gpu.types.GPUOffScreen(W, H)
    with off.bind():
        fb = gpu.state.active_framebuffer_get()
        fb.clear(color=(0, 0, 0, 1))
        blf.size(_FID, size)
        blf.color(_FID, 1, 1, 1, 1)
        blf.position(_FID, 4, int(size * 0.4), 0)
        with gpu.matrix.push_pop():
            gpu.matrix.load_matrix(Matrix.Identity(4))
            gpu.matrix.load_projection_matrix(Matrix(((2.0 / W, 0, 0, -1), (0, 2.0 / H, 0, -1), (0, 0, -1, 0), (0, 0, 0, 1))))
            blf.draw(_FID, txt)
        buf = fb.read_color(0, 0, W, H, 4, 0, "FLOAT")
    off.free()
    a = np.array(buf.to_list(), np.float32)[::-1, :, 0]
    _TXT[key] = a
    return a


def blit(cv, mask, x, y, color):
    h, w = mask.shape
    x, y = int(x), int(y)
    x0, y0, x1, y1 = max(x, 0), max(y, 0), min(x + w, cv.shape[1]), min(y + h, cv.shape[0])
    if x1 <= x0 or y1 <= y0:
        return
    m = mask[y0 - y:y1 - y, x0 - x:x1 - x][:, :, None]
    cv[y0:y1, x0:x1] = cv[y0:y1, x0:x1] * (1 - m) + np.array(color, np.float32) * m


def put_text(cv, txt, x, y, size, color=(1, 1, 1), shadow=True):
    m = text_mask(txt, size)
    if shadow:
        blit(cv, m, x + 1, y + 1, (0, 0, 0))
    blit(cv, m, x, y, color)
    return m.shape[1]


def fill_rect(cv, x0, y0, x1, y1, color, a=1.0):
    x0, y0, x1, y1 = max(int(x0), 0), max(int(y0), 0), min(int(x1), cv.shape[1]), min(int(y1), cv.shape[0])
    if x1 > x0 and y1 > y0:
        cv[y0:y1, x0:x1] = cv[y0:y1, x0:x1] * (1 - a) + np.array(color, np.float32) * a


# ------------------------------------------------------------------ 이미지 입출력
def load_png(path):
    img = bpy.data.images.load(path)
    img.colorspace_settings.name = "Non-Color"
    w, h = img.size
    a = np.empty(w * h * 4, np.float32)
    img.pixels.foreach_get(a)
    bpy.data.images.remove(img)
    return a.reshape(h, w, 4)[::-1, :, :3].copy()


def save_png(arr, path):
    h, w = arr.shape[:2]
    rgba = np.ones((h, w, 4), np.float32)
    rgba[:, :, :3] = np.clip(arr[::-1], 0, 1)
    img = bpy.data.images.new("out", w, h, alpha=False, float_buffer=False)
    img.colorspace_settings.name = "Non-Color"
    img.pixels.foreach_set(rgba.ravel())
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)


def half(a):
    h, w = a.shape[0] // 2 * 2, a.shape[1] // 2 * 2
    return a[:h, :w].reshape(h // 2, 2, w // 2, 2, -1).mean((1, 3))


# ------------------------------------------------------------------ 렌더
def _try(obj, name, val):
    try:
        setattr(obj, name, val)
    except Exception:
        pass


class Renderer:
    def __init__(self, S, sky=None, fog=0.0012, sun_elev=26.0, sun_az=235.0):
        self.S = S
        sc = bpy.context.scene
        self.sc = sc
        sc.render.engine = "BLENDER_EEVEE"
        sc.render.image_settings.file_format = "PNG"
        sc.render.image_settings.color_mode = "RGB"
        sc.view_settings.view_transform = "Standard"
        sc.view_settings.exposure = -0.2
        e = sc.eevee
        for n, v in (("taa_render_samples", 24), ("use_raytracing", False), ("use_shadows", True), ("shadow_ray_count", 2),
                     ("shadow_step_count", 8), ("volumetric_end", 700.0), ("volumetric_samples", 48), ("volumetric_tile_size", "4"),
                     ("use_volumetric_shadows", False)):
            _try(e, n, v)
        sky = sky or {}
        zen, hor = sky.get("zenith", (0.40, 0.55, 0.72)), sky.get("horizon", (0.80, 0.86, 0.92))
        w = bpy.data.worlds.new("w")
        w.use_nodes = True
        nt = w.node_tree
        nt.nodes.clear()
        tc = nt.nodes.new("ShaderNodeTexCoord")
        sep = nt.nodes.new("ShaderNodeSeparateXYZ")
        mp = nt.nodes.new("ShaderNodeMapRange")
        mp.inputs["From Min"].default_value, mp.inputs["From Max"].default_value = -0.05, 0.75
        ramp = nt.nodes.new("ShaderNodeValToRGB")
        ramp.color_ramp.elements[0].color = (*hor, 1)
        ramp.color_ramp.elements[1].color = (*zen, 1)
        bg = nt.nodes.new("ShaderNodeBackground")
        bg.inputs["Strength"].default_value = sky.get("strength", 1.0)
        out = nt.nodes.new("ShaderNodeOutputWorld")
        nt.links.new(tc.outputs["Generated"], sep.inputs[0])
        nt.links.new(sep.outputs["Z"], mp.inputs["Value"])
        nt.links.new(mp.outputs["Result"], ramp.inputs["Fac"])
        nt.links.new(ramp.outputs["Color"], bg.inputs["Color"])
        nt.links.new(bg.outputs["Background"], out.inputs["Surface"])
        vol = nt.nodes.new("ShaderNodeVolumePrincipled")
        vol.inputs["Color"].default_value = (*hor, 1)
        vol.inputs["Density"].default_value = fog
        self.world, self.vol, self.out, self.fog = w, vol, out, fog
        sc.world = w
        sun = bpy.data.lights.new("sun", "SUN")
        sun.energy = 3.6
        sun.color = (1.0, 0.94, 0.86)
        sun.angle = math.radians(1.6)
        so = bpy.data.objects.new("sun", sun)
        so.rotation_euler = (math.radians(90 - sun_elev), 0, math.radians(sun_az))
        bpy.context.collection.objects.link(so)
        cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
        bpy.context.collection.objects.link(cam)
        sc.camera = cam
        self.cam = cam

    def _fog(self, on):
        for l in list(self.out.inputs["Volume"].links):
            self.world.node_tree.links.remove(l)
        if on and self.fog > 0:
            self.world.node_tree.links.new(self.vol.outputs["Volume"], self.out.inputs["Volume"])

    def top(self, path, width=2560):
        x0, x1, z0, z1 = self.S.bounds
        bw, bh = x1 - x0, z1 - z0
        H = int(round(width * bh / bw))
        sc, cam = self.sc, self.cam
        sc.render.resolution_x, sc.render.resolution_y = width, H
        cam.data.type = "ORTHO"
        cam.data.ortho_scale = bw
        cam.data.sensor_fit = "HORIZONTAL"
        cam.data.clip_start, cam.data.clip_end = 1.0, 4000.0
        cam.location = ((x0 + x1) / 2, -(z0 + z1) / 2, 1500.0)
        cam.rotation_euler = (0, 0, 0)
        self._fog(False)
        sc.render.filepath = path
        bpy.ops.render.render(write_still=True)
        return width, H

    def fp(self, path, eye, heading):
        """eye = 블렌더 좌표 Vector, heading = 블렌더 xy 방향 라디안"""
        sc, cam = self.sc, self.cam
        sc.render.resolution_x, sc.render.resolution_y = 1280, 720
        cam.data.type = "PERSP"
        cam.data.sensor_fit = "VERTICAL"
        cam.data.angle_y = math.radians(FOV_V)
        cam.data.clip_start, cam.data.clip_end = 0.15, 4000.0
        cam.location = eye
        fwd = Vector((math.cos(heading), math.sin(heading), 0.0))
        cam.rotation_euler = fwd.to_track_quat("-Z", "Y").to_euler()
        self._fog(True)
        sc.render.filepath = path
        bpy.ops.render.render(write_still=True)


# ------------------------------------------------------------------ 본체
def color_for(idx):
    if idx < 60:
        return (0.86, 0.12, 0.10)
    if idx < 70:
        return (0.96, 0.58, 0.12)
    if idx < 85:
        return (0.62, 0.82, 0.25)
    return (0.14, 0.62, 0.30)


def roblox_yaw(heading):
    return math.degrees(math.atan2(-math.cos(heading), math.sin(heading)))


def region_metrics(S, H):
    x0, x1, z0, z1 = S.bounds
    area = (x1 - x0) * (z1 - z0)
    wx0, wz0, cell, _ = S.walk
    opn = float((~np.isnan(H)).sum() * cell * cell / area * 100)
    out = dict(open=opn, open_ok=30 <= opn <= 50)
    R = np.array(S.rects, float).reshape(-1, 4)
    n = len(R)
    if not n:
        return out
    par = list(range(n))

    def find(a):
        while par[a] != a:
            par[a] = par[par[a]]
            a = par[a]
        return a
    for i in range(n):
        ov = (R[i + 1:, 0] <= R[i, 1] + 2) & (R[i + 1:, 1] >= R[i, 0] - 2) & (R[i + 1:, 2] <= R[i, 3] + 2) & (R[i + 1:, 3] >= R[i, 2] - 2)
        for j in np.nonzero(ov)[0]:
            a, b = find(i), find(i + 1 + int(j))
            if a != b:
                par[a] = b
    roots = np.array([find(i) for i in range(n)])
    gw, gh = int(x1 - x0) + 1, int(z1 - z0) + 1
    lab = np.full((gh, gw), -1, np.int32)
    for i in range(n):
        a, b = int(max(R[i, 0] - x0, 0)), int(min(np.ceil(R[i, 1] - x0), gw))
        c, d = int(max(R[i, 2] - z0, 0)), int(min(np.ceil(R[i, 3] - z0), gh))
        lab[c:d, a:b] = roots[i]
    areas, widths = {}, {}
    for r in np.unique(roots):
        m = roots == r
        areas[r] = float((lab == r).sum())
        widths[r] = float(max(R[m, 1].max() - R[m, 0].min(), R[m, 3].max() - R[m, 2].min()))
    tot = sum(areas.values())
    bins = [0.0, 0.0, 0.0]
    for r in areas:
        bins[0 if widths[r] >= 60 else (1 if widths[r] >= 20 else 2)] += areas[r]
    out.update(clusters=len(areas), big=bins[0] / tot * 100, mid=bins[1] / tot * 100, small=bins[2] / tot * 100,
               hier_ok=bins[0] / tot >= 0.4, max_cluster_w=max(widths.values()), max_cluster_area_pct=max(areas.values()) / tot * 100)
    ls = np.maximum(R[:, 1] - R[:, 0], R[:, 3] - R[:, 2])
    fa = (R[:, 1] - R[:, 0]) * (R[:, 3] - R[:, 2])
    edges = [(0, 12), (12, 20), (20, 60), (60, 1e9)]
    out["box_dist"] = [(a, b, float(fa[(ls >= a) & (ls < b)].sum() / fa.sum() * 100), int(((ls >= a) & (ls < b)).sum())) for a, b in edges]
    return out


def run(S, out_dir, seed=20261114, lattice=8.0, sky=None, fog=0.0):
    t00 = time.time()
    os.makedirs(out_dir, exist_ok=True)
    name = S.name
    T = {}
    t = time.time()
    S.build()
    R = Rays()
    T["장면 굳히기·BVH"] = time.time() - t
    log("삼각형 %d (%.1fs)" % (R.tris, T["장면 굳히기·BVH"]))
    rd = Renderer(S, sky=sky, fog=fog)
    P = lambda s: os.path.join(out_dir, "%s_%s" % (name, s))  # noqa: E731

    # 1. 위에서
    t = time.time()
    top_path = P("위.png")
    tw, th = rd.top(top_path)
    T["위에서 렌더"] = time.time() - t
    top = load_png(top_path)

    # 2. 꽉참 지도 — 걸을 수 있는 면 위 격자 전부
    t = time.time()
    wx0, wz0, cell, H = S.walk
    nz, nx = H.shape
    step = max(1, int(round(lattice / cell)))
    pos = []
    for j in range(step // 2, nz, step):
        for i in range(step // 2, nx, step):
            if not np.isnan(H[j, i]):
                pos.append((wx0 + (i + 0.5) * cell, float(H[j, i]), wz0 + (j + 0.5) * cell))
    lms = [Vector(rbx_to_bl(*p)) for p in S.landmarks]
    NXc, NYc = 24, 9
    dirs8 = [view_dirs(h, NXc, NYc) for h in HEADS8]
    rec = []
    for n, (x, y, z) in enumerate(pos):
        o = Vector(rbx_to_bl(x, y + EYE, z))
        hor = R.horizon(o, HDIRS8)
        lm = R.lm_visible(o, lms)
        blk_k = None if lm or not lms else R.lm_blocker(o, lms)
        subs, mets = [], []
        for dd in dirs8:
            cat, dist, gid = R.cast(o, dd)
            m = view_metrics(cat, dist, gid, NXc, NYc)
            mets.append(m)
            subs.append(sub_scores(m, hor, lm))
        idx = float(np.mean([s["index"] for s in subs]))
        wi = int(np.argmin([s["view"] for s in subs]))
        rec.append(dict(x=x, y=y, z=z, hor=hor, lm=lm, blk=blk_k, index=idx, worst=wi, mets=mets, subs=subs))
        if n % 400 == 0:
            log("지도 %d/%d (%.0fs)" % (n, len(pos), time.time() - t))
    T["꽉참 지도 재기(%d자리 x 8방향 x %dx%d)" % (len(pos), NXc, NYc)] = time.time() - t

    # 3. 사진 자리 고르기
    rng = random.Random(seed)
    order = list(range(len(rec)))
    rng.shuffle(order)
    chosen = []
    for k in order:
        r = rec[k]
        if all(math.hypot(r["x"] - rec[c]["x"], r["z"] - rec[c]["z"]) >= 40 for c, _ in chosen):
            chosen.append((k, rng.uniform(0, 2 * math.pi)))
        if len(chosen) == 12:
            break
    low = []
    for k in sorted(range(len(rec)), key=lambda k: rec[k]["index"]):
        r = rec[k]
        if all(math.hypot(r["x"] - rec[c]["x"], r["z"] - rec[c]["z"]) >= 60 for c in low):
            low.append(k)
        if len(low) == 4:
            break
    shots = [("%02d" % (i + 1), "1인칭_%02d" % (i + 1), k, h) for i, (k, h) in enumerate(chosen)]
    shots += [("L%d" % (i + 1), "1인칭_낮은_%d" % (i + 1), k, HEADS8[rec[k]["worst"]]) for i, k in enumerate(low)]

    # 4. 1인칭 사진(+ 64x36 재기)
    t = time.time()
    NXf, NYf = 64, 36
    info = []
    photos = []
    tr = 0.0
    for label, fname, k, heading in shots:
        r = rec[k]
        o = Vector(rbx_to_bl(r["x"], r["y"] + EYE, r["z"]))
        cat, dist, gid = R.cast(o, view_dirs(heading, NXf, NYf))
        m = view_metrics(cat, dist, gid, NXf, NYf)
        s = sub_scores(m, r["hor"], r["lm"])
        t1 = time.time()
        path = P(fname + ".png")
        rd.fp(path, o, heading)
        tr += time.time() - t1
        photos.append(load_png(path))
        info.append(dict(label=label, file=os.path.basename(path), pos=(round(r["x"], 1), round(r["y"], 2), round(r["z"], 1)),
                         eye=(round(r["x"], 1), round(r["y"] + EYE, 2), round(r["z"], 1)), heading=heading, m=m, s=s,
                         hor=r["hor"], lm=r["lm"], mapindex=r["index"]))
    T["1인칭 16장 (렌더 %.0fs 포함)" % tr] = time.time() - t

    # 5. 그림들
    t = time.time()
    sx = tw / (S.bounds[1] - S.bounds[0])

    def px(x, z):
        return (x - S.bounds[0]) * sx, (z - S.bounds[2]) * sx

    fmap = top.copy()
    hw = lattice / 2 * sx
    for r in rec:
        cx, cz = px(r["x"], r["z"])
        fill_rect(fmap, cx - hw, cz - hw, cx + hw, cz + hw, color_for(r["index"]), 0.62)

    def markers(cv, big=1.0):
        for e in info:
            cx, cz = px(e["pos"][0], e["pos"][2])
            low_ = e["label"].startswith("L")
            col = (1.0, 0.2, 0.85) if low_ else (0.1, 0.85, 1.0)
            fill_rect(cv, cx - 14 * big, cz - 14 * big, cx + 14 * big, cz + 14 * big, (0, 0, 0), 0.9)
            fill_rect(cv, cx - 11 * big, cz - 11 * big, cx + 11 * big, cz + 11 * big, col, 1.0)
            hx, hz = math.cos(e["heading"]), -math.sin(e["heading"])
            for q in range(1, 40):
                fill_rect(cv, cx + hx * q * big - 3, cz + hz * q * big - 3, cx + hx * q * big + 3, cz + hz * q * big + 3, col, 1.0)
            put_text(cv, e["label"], cx + 16 * big, cz - 34 * big, int(34 * big), (1, 1, 1))

    markers(fmap)
    legend = [("60 미만", color_for(0)), ("60~70", color_for(65)), ("70~85", color_for(75)), ("85 이상", color_for(90))]
    lx = 30
    fill_rect(fmap, 14, th - 70, 14 + 620, th - 14, (0, 0, 0), 0.7)
    for lab, col in legend:
        fill_rect(fmap, lx, th - 56, lx + 28, th - 28, col, 1.0)
        lx += 36 + put_text(fmap, lab, lx + 36, th - 62, 26)
        lx += 24
    save_png(fmap, P("꽉참지도.png"))
    topm = top.copy()
    markers(topm)
    T["지도·사진판 그리기"] = time.time() - t

    # 6. 숫자
    idxs = np.array([r["index"] for r in rec])
    allm = [(m, r) for r in rec for m in r["mets"]]
    npos = len(rec)
    p_sky = np.mean([m["sky"] <= 45 for m, _ in allm]) * 100
    p_bare = np.mean([m["bare"] <= 35 for m, _ in allm]) * 100
    p_lay = np.mean([m["layers"] >= 2 for m, _ in allm]) * 100
    p_line = np.mean([m["std"] >= 0.05 for m, _ in allm]) * 100
    p_hor = np.mean([r["hor"] >= 6 for r in rec]) * 100
    p_lm = np.mean([r["lm"] for r in rec]) * 100
    n60 = int((idxs < 60).sum())
    RG = region_metrics(S, H)
    p_flat = np.mean([m["flat"] <= 25 for m, _ in allm]) * 100
    blk = {}
    for r in rec:
        if not r["lm"]:
            blk[r["blk"]] = blk.get(r["blk"], 0) + 1
    walk_cells = int((~np.isnan(H)).sum())
    avg = lambda key: float(np.mean([m[key] for m, _ in allm]))  # noqa: E731
    # 가장 낮은 열 자리(서로 20 이상)
    lows = []
    for k in sorted(range(npos), key=lambda k: rec[k]["index"]):
        r = rec[k]
        if all(math.hypot(r["x"] - rec[c]["x"], r["z"] - rec[c]["z"]) >= 20 for c in lows):
            lows.append(k)
        if len(lows) == 10:
            break
    L = []
    L.append("%s 꽉참 지수 (mapshot.py, %s)" % (name, time.strftime("%Y-%m-%d")))
    L.append("공식: 지수 = 하늘 15·s + 맨바닥 15·s + 겹 15·s + 하늘선 10·s + 수평선 15·s + 랜드마크 10·s + 민짜 면 20·s  (s = 0~1, 통과 기준이면 1, 벗어난 만큼 깎음)")
    L.append("  하늘 s = 하늘% ≤ 45 → 1, 90 에서 0 선형 / 맨바닥 s = ≤ 35 → 1, 85 에서 0 / 겹 s = 겹 수/2 / 하늘선 s = 표준편차/0.05 / 민짜 s = ≤ 25 → 1, 75 에서 0")
    L.append("  수평선 s = 8방향 중 300 안에서 막힌 수/6 / 랜드마크 s = 보이면 1 아니면 0. 수평선·랜드마크는 자리마다, 나머지는 방향마다(자리 지수 = 여덟 방향 평균).")
    L.append("  민짜 면 % = 거리 30 안에서 맞은 (kind, 같은 평면) 묶음 중 가장 큰 것의 화면 비율(위를 보는 면 제외). 지역 값(열림·크기 위계)은 지수에 안 넣고 아래에 통과/미달로.")
    L.append("  지도 = 8 스터드 격자 · 방향당 광선 24x9 · 사진 = 64x36. 맨바닥 = 위를 보는 ground·slab·terrace·context(평지) 면. 눈높이 %.1f · 세로 시야각 %d°." % (EYE, FOV_V))
    L.append("")
    L.append("걸을 수 있는 칸 %d (1 스터드 칸) · 잰 자리 %d (8 스터드 격자)" % (walk_cells, npos))
    L.append("지수 평균 %.1f · 최저 %.1f · 최고 %.1f" % (idxs.mean(), idxs.min(), idxs.max()))
    L.append("60 미만 자리 %d / %d = %.1f%% (칸으로 치면 약 %d)" % (n60, npos, n60 / npos * 100, n60 * step * step))
    L.append("기준별 통과율: 하늘 %.0f%% · 맨바닥 %.0f%% · 겹 %.0f%% · 하늘선 %.0f%% (방향 표본 %d) · 수평선 %.0f%% · 랜드마크 %.0f%% (자리 %d)" % (
        p_sky, p_bare, p_lay, p_line, len(allm), p_hor, p_lm, npos))
    L.append("방향 표본 평균: 하늘 %.1f%% · 맨바닥 %.1f%% · 겹 %.2f · 하늘선 표준편차 %.3f · 수평선 막힘 %.2f/8" % (
        avg("sky"), avg("bare"), avg("layers"), avg("std"), np.mean([r["hor"] for r in rec])))
    L.append("민짜 면: 방향 표본 평균 %.1f%%, 통과(≤25%%) %.0f%%" % (avg("flat"), p_flat))
    L.append("지역 값: 열림 비율 %.1f%% (걸을 수 있는 땅/지역, 기준 30~50) → %s" % (RG["open"], "통과" if RG["open_ok"] else "미달"))
    if "big" in RG:
        L.append("지역 값: 크기 위계 — 바위 덩어리 %d개(맞닿은 것끼리), 넓이 비 큰(폭 60↑) %.0f%% · 중간(20~60) %.0f%% · 작은(20↓) %.0f%% (큰 것 ≥ 40%% 통과) → %s" % (
            RG["clusters"], RG["big"], RG["mid"], RG["small"], "통과" if RG["hier_ok"] else "미달"))
        L.append("  가장 큰 덩어리 폭 %.0f, 덩어리 넓이의 %.0f%%" % (RG["max_cluster_w"], RG["max_cluster_area_pct"]))
        L.append("  상자 하나하나 긴 변(넓이 가중, 윗면 겹침 중복 포함): " + " · ".join("%s %.0f%% (%d개)" % ("%d~%d" % (a, b) if b < 1e8 else "%d↑" % a, pc, nb) for a, b, pc, nb in RG["box_dist"]))
    nlm = sum(blk.values())
    L.append("랜드마크 안 보이는 자리 %d/%d — 시계탑 꼭대기 직선을 막은 것: %s" % (nlm, npos, " · ".join("%s %.0f%%" % (k, v / max(nlm, 1) * 100) for k, v in sorted(blk.items(), key=lambda kv: -kv[1])) or "없음"))
    L.append("")
    L.append("가장 낮은 열 자리(서로 20 이상 — 로블록스 월드 x, z / 바닥 y, 가장 낮은 방향 = 로블록스 yaw)")
    for n, k in enumerate(lows):
        r = rec[k]
        w = r["worst"]
        L.append("  %2d. (%.0f, %.0f) y %.1f  지수 %.1f  yaw %.0f°  — %s" % (
            n + 1, r["x"], r["z"], r["y"], r["index"], roblox_yaw(HEADS8[w]), shortfalls(r["mets"][w], r["hor"], r["lm"])))
    L.append("")
    L.append("사진(씨앗 %d). 지수 = 그 사진 방향 값(64x36), 지도 지수 = 그 자리 여덟 방향 평균" % seed)
    for e in info:
        m = e["m"]
        L.append("  %-3s %s  자리 (%.0f, %.0f) y %.1f  yaw %.0f°  지수 %.1f (지도 %.1f)  하늘 %.0f%% 맨바닥 %.0f%% 겹 %d 하늘선 %.3f 민짜 %.0f%% 수평선 %d/8 랜드마크 %s  — %s" % (
            e["label"], e["file"], e["pos"][0], e["pos"][2], e["pos"][1], roblox_yaw(e["heading"]), e["s"]["index"], e["mapindex"],
            m["sky"], m["bare"], m["layers"], m["std"], m["flat"], e["hor"], "예" if e["lm"] else "아니오", shortfalls(m, e["hor"], e["lm"])))
    L.append("")
    L.append("걸린 시간:")
    for k, v in T.items():
        L.append("  %-44s %6.1f s" % (k, v))
    with open(P("지수.txt"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(L) + "\n")

    # 7. shots.json
    js = dict(region=name, seed=seed, eye=EYE, fov_v=FOV_V, size=[1280, 720], shots=[])
    for e in info:
        js["shots"].append(dict(label=e["label"], file=e["file"], floor=list(e["pos"]), eye=list(e["eye"]),
                                yaw_roblox=round(roblox_yaw(e["heading"]), 1),
                                look=[round(math.cos(e["heading"]), 4), 0, round(-math.sin(e["heading"]), 4)],
                                index=round(e["s"]["index"], 1), map_index=round(e["mapindex"], 1)))
    with open(P("shots.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(js, f, ensure_ascii=False, indent=1)

    # 8. 사진판
    t = time.time()
    SW = 2560
    th2 = half(topm)
    fm2 = half(fmap)
    hh = th2.shape[0]
    head = 140
    rows = 4
    capH = 82
    cellH = 360 + capH
    sheet = np.full((head + hh + rows * cellH, SW, 3), 0.08, np.float32)
    put_text(sheet, "%s  사진판 — 지수 평균 %.1f · 최저 %.1f · 60 미만 %d/%d (%.1f%%) · 하늘 %.0f%% 맨바닥 %.0f%% 겹 %.0f%% 하늘선 %.0f%% 수평선 %.0f%% 랜드마크 %.0f%% 통과" % (
        name, idxs.mean(), idxs.min(), n60, npos, n60 / npos * 100, p_sky, p_bare, p_lay, p_line, p_hor, p_lm), 20, 10, 36)
    put_text(sheet, "지역 값(지수 밖): 열림 비율 %.0f%% (30~50) %s · 크기 위계 큰 덩어리 %s (큰 것 ≥ 40%%) %s · 민짜 면 평균 %.0f%% (≤25) 통과 %.0f%%" % (
        RG["open"], "통과" if RG["open_ok"] else "미달", ("%.0f%%" % RG["big"]) if "big" in RG else "-", "통과" if RG.get("hier_ok") else "미달", avg("flat"), p_flat), 20, 70, 34,
        (0.6, 1.0, 0.6) if (RG["open_ok"] and RG.get("hier_ok")) else (1.0, 0.7, 0.4))
    sheet[head:head + hh, 0:th2.shape[1]] = th2
    sheet[head:head + hh, 1280:1280 + fm2.shape[1]] = fm2[:, :SW - 1280]
    for n, e in enumerate(info):
        r_, c_ = divmod(n, 4)
        x, y = c_ * 640, head + hh + r_ * cellH
        sheet[y:y + 360, x:x + 640] = half(photos[n])
        m = e["m"]
        cap = "%s  지수 %d  하늘 %d 맨 %d 겹 %d 선 %.2f 수평 %d/8 랜드 %s" % (
            e["label"], round(e["s"]["index"]), round(m["sky"]), round(m["bare"]), m["layers"], m["std"], e["hor"], "예" if e["lm"] else "아니오")
        col_ = (1, 0.5, 0.9) if e["label"].startswith("L") else (0.7, 0.95, 1.0)
        put_text(sheet, cap, x + 6, y + 362, 24, col_)
        put_text(sheet, "민 %d%%%s" % (round(m["flat"]), " (25 넘음)" if m["flat"] > 25 else ""), x + 6, y + 392, 24, (1.0, 0.6, 0.4) if m["flat"] > 25 else (0.7, 1.0, 0.7))
    save_png(sheet, P("사진판.png"))
    T["사진판"] = time.time() - t
    save_png(topm, P("위_표시.png"))
    log("끝 — 전체 %.0fs" % (time.time() - t00))
    return dict(index_mean=float(idxs.mean()), index_min=float(idxs.min()), n60=n60, npos=npos, seconds=time.time() - t00, times=T)
