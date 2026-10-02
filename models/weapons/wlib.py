# -*- coding: utf-8 -*-
"""
wlib.py — 무기 메시를 **무기 공간**(WeaponDefinitions 약속)으로 짓는 도구. (2026-10-02)

무기 공간: 원점 = 손에 쥐는 점, +Y = 날·머리 쪽, -Z = 날이 향하는 쪽, +X = 로블록스 +X.
블렌더 좌표로는 (bx, by, bz) = (-X, Z, Y) 로 옮겨 짓는다 — FBX(-Z forward, Y up)로 내보내면
로블록스에서 다시 (X, Y, Z) 가 된다(회전이지 미러가 아님, 메모리 roblox-project-edit-workflow).

모든 모양은 **닫힌 덩어리**로 짓는다(로블록스 MeshPart 는 한쪽 면만 그린다 — 얇은 판도 두께를 준다).
한 무기 조각(Main/Off)은 재질 묶음(Group)마다 메시 하나: 이름 "<무기Id>_<Main|Off>_<묶음>".
"""
import math

import bmesh
import bpy
from mathutils import Matrix, Vector

TAU = math.pi * 2


def W2B(p):
    x, y, z = p
    return Vector((-x, z, y))


def _v(p):
    return Vector(p)


class Group:
    """재질 묶음 하나 = 메시 하나. 모양 함수가 여기에 면을 더한다."""

    def __init__(self, name, color=(0.7, 0.7, 0.7), smooth=40.0, alpha=1.0):
        self.name = name
        self.color = color
        self.smooth = smooth  # 이 각도보다 완만한 모서리는 매끈하게(None 이면 모두 각지게)
        self.alpha = alpha
        self.bm = bmesh.new()

    # 무기 공간 꼭짓점·면을 그대로 넣는다
    def add(self, verts, faces):
        vs = [self.bm.verts.new(W2B(v)) for v in verts]
        for f in faces:
            try:
                self.bm.faces.new([vs[i] for i in f])
            except ValueError:
                pass
        return vs

    def merge(self, other_bm, matrix=None):
        """다른 bmesh(블렌더 좌표)를 붙인다"""
        m = {}
        for v in other_bm.verts:
            co = v.co.copy()
            if matrix is not None:
                co = matrix @ co
            m[v.index] = self.bm.verts.new(co)
        other_bm.verts.index_update()
        for f in other_bm.faces:
            try:
                self.bm.faces.new([m[v.index] for v in f.verts])
            except ValueError:
                pass

    def finish(self):
        bm = self.bm
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        me = bpy.data.meshes.new(self.name)
        bm.to_mesh(me)
        bm.free()
        ob = bpy.data.objects.new(self.name, me)
        bpy.context.scene.collection.objects.link(ob)
        if self.smooth is not None:
            me.shade_smooth()
            me.set_sharp_from_angle(angle=math.radians(self.smooth))
        else:
            me.shade_flat()
        mat = bpy.data.materials.new(self.name + "_M")
        mat.diffuse_color = (*self.color, self.alpha)
        me.materials.append(mat)
        return ob


def tri_count(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


# ── 모양 ─────────────────────────────────────────


def lathe(g, profile, seg=24, center=(0, 0, 0), axis="Y", phase=0.0, scale_xz=(1.0, 1.0)):
    """profile = [(반지름, 높이)] 를 축(+Y 기본) 둘레로 돌린다. 반지름 0 이면 극점 하나. 끝이 열려 있으면 막는다."""
    cx, cy, cz = center
    verts, rings = [], []
    sx, sz = scale_xz
    for r, h in profile:
        if r <= 1e-6:
            rings.append([len(verts)])
            if axis == "Y":
                verts.append((cx, cy + h, cz))
            elif axis == "X":
                verts.append((cx + h, cy, cz))
            else:
                verts.append((cx, cy, cz + h))
            continue
        ring = []
        for i in range(seg):
            a = phase + TAU * i / seg
            u, w = r * math.cos(a) * sx, r * math.sin(a) * sz
            ring.append(len(verts))
            if axis == "Y":
                verts.append((cx + u, cy + h, cz + w))
            elif axis == "X":
                verts.append((cx + h, cy + u, cz + w))
            else:
                verts.append((cx + u, cy + w, cz + h))
        rings.append(ring)
    faces = []
    for a, b in zip(rings, rings[1:]):
        if len(a) == 1 and len(b) == 1:
            continue
        if len(a) == 1:
            for i in range(seg):
                faces.append((a[0], b[(i + 1) % seg], b[i]))
        elif len(b) == 1:
            for i in range(seg):
                faces.append((a[i], a[(i + 1) % seg], b[0]))
        else:
            for i in range(seg):
                faces.append((a[i], a[(i + 1) % seg], b[(i + 1) % seg], b[i]))
    if len(rings[0]) > 1:
        faces.append(tuple(reversed(rings[0])))
    if len(rings[-1]) > 1:
        faces.append(tuple(rings[-1]))
    g.add(verts, faces)


def loft(g, loops, cap_start=True, cap_end=True):
    """같은 개수의 꼭짓점 고리(3D 점 목록)를 차례로 잇는다. 고리가 점 하나면 뾰족한 끝."""
    verts, idx = [], []
    for loop in loops:
        ids = []
        for p in loop:
            ids.append(len(verts))
            verts.append(tuple(p))
        idx.append(ids)
    faces = []
    for a, b in zip(idx, idx[1:]):
        n = max(len(a), len(b))
        if len(a) == 1:
            for i in range(n):
                faces.append((a[0], b[(i + 1) % n], b[i]))
        elif len(b) == 1:
            for i in range(n):
                faces.append((a[i], a[(i + 1) % n], b[0]))
        else:
            for i in range(n):
                faces.append((a[i], a[(i + 1) % n], b[(i + 1) % n], b[i]))
    if cap_start and len(idx[0]) > 2:
        faces.append(tuple(reversed(idx[0])))
    if cap_end and len(idx[-1]) > 2:
        faces.append(tuple(idx[-1]))
    g.add(verts, faces)


def section_y(y, pts2d, cx=0.0, cz=0.0):
    """Y 높이의 단면(XZ 평면 점들)"""
    return [(cx + x, y, cz + z) for x, z in pts2d]


def diamond(w, t):
    """날 단면: 마름모(±w 는 X 날끝, ±t 는 Z 두께)"""
    return [(w, 0), (0, t), (-w, 0), (0, -t)]


def hexa(w, t, shoulder=0.55):
    """납작 육각 단면: 날끝 ±w, 어깨(±w·shoulder, ±t)"""
    s = w * shoulder
    return [(w, 0), (s, t), (-s, t), (-w, 0), (-s, -t), (s, -t)]


def rrect(w, d, r, n=3):
    """모서리 둥근 직사각형 단면(X 반폭 w, Z 반깊이 d, 둥글기 r)"""
    r = min(r, w * 0.99, d * 0.99)
    pts = []
    for cxs, czs, a0 in ((1, 1, 0), (-1, 1, 90), (-1, -1, 180), (1, -1, 270)):
        for i in range(n + 1):
            a = math.radians(a0 + 90 * i / n)
            pts.append((cxs * (w - r) + r * math.cos(a), czs * (d - r) + r * math.sin(a)))
    return pts


def _frames(path):
    """경로를 따라가는 (점, 접선, 법선, 종법선) — 평행 이동 틀(비틀림 없음)"""
    P = [Vector(p) for p in path]
    T = []
    for i in range(len(P)):
        a = P[max(0, i - 1)]
        b = P[min(len(P) - 1, i + 1)]
        T.append((b - a).normalized())
    ref = Vector((0, 0, 1)) if abs(T[0].z) < 0.9 else Vector((1, 0, 0))
    N = [(ref - T[0] * ref.dot(T[0])).normalized()]
    for i in range(1, len(P)):
        n = N[-1] - T[i] * N[-1].dot(T[i])
        if n.length < 1e-6:
            n = N[-1]
        N.append(n.normalized())
    B = [T[i].cross(N[i]) for i in range(len(P))]
    return P, T, N, B


def tube(g, path, radius, seg=8, cap=True, section=None, twist=0.0):
    """경로를 따라 굵기 radius(숫자 또는 목록)의 관. section=[(u,v)] 이면 그 단면으로(반지름 곱함)."""
    P, T, N, B = _frames(path)
    n = len(P)
    radii = radius if isinstance(radius, (list, tuple)) else [radius] * n
    sec = section or [(math.cos(TAU * i / seg), math.sin(TAU * i / seg)) for i in range(seg)]
    loops = []
    for i in range(n):
        r = radii[i]
        tw = twist * i / max(1, n - 1)
        c, s = math.cos(tw), math.sin(tw)
        if r <= 1e-6:
            loops.append([tuple(P[i])])
            continue
        loop = []
        for u, v in sec:
            uu, vv = u * c - v * s, u * s + v * c
            q = P[i] + N[i] * (uu * r) + B[i] * (vv * r)
            loop.append(tuple(q))
        loops.append(loop)
    loft(g, loops, cap, cap)


def ring(g, center, radius, thickness, normal=(0, 1, 0), seg=24, tseg=8):
    """고리(도넛). normal 축 둘레"""
    nrm = Vector(normal).normalized()
    a = Vector((1, 0, 0)) if abs(nrm.x) < 0.9 else Vector((0, 0, 1))
    u = (a - nrm * a.dot(nrm)).normalized()
    v = nrm.cross(u)
    c = Vector(center)
    path = [c + (u * math.cos(TAU * i / seg) + v * math.sin(TAU * i / seg)) * radius for i in range(seg + 1)]
    # 닫힌 관: 끝 고리를 첫 고리에 겹친다(remove_doubles 가 붙인다)
    tube(g, [tuple(p) for p in path], thickness, tseg, cap=False)


def ball(g, center, radius, seg=20, rings=12, squash=(1, 1, 1)):
    sx, sy, sz = squash
    prof = []
    for i in range(rings + 1):
        a = math.pi * i / rings - math.pi / 2
        prof.append((math.cos(a) * radius, math.sin(a) * radius * sy))
    prof[0] = (0, prof[0][1])
    prof[-1] = (0, prof[-1][1])
    lathe(g, prof, seg, center, scale_xz=(sx, sz))


def bbox(g, center, size, bevel=0.0, rot=(0, 0, 0), seg=2):
    """모서리를 깎은 상자(무기 공간 중심·크기·회전(도, fromOrientation 순))"""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=seg, affect="EDGES", profile=0.5)
    rx, ry, rz = (math.radians(a) for a in rot)
    R = Matrix.Rotation(ry, 4, "Y") @ Matrix.Rotation(rx, 4, "X") @ Matrix.Rotation(rz, 4, "Z")
    for v in bm.verts:
        p = R @ v.co + Vector(center)
        v.co = W2B(tuple(p))
    g.merge(bm)
    bm.free()


def plate(g, outline, center, thick, rings=(1.0, 0.78, 0.52, 0.26), plane="ZY", offset=0.0):
    """평면 모양(outline = [(u,v)], 반시계)을 두께 thick(u,v)·(고리 비율) 로 부풀린 닫힌 판.
    plane: "ZY" = u→Z, v→Y, 두께는 X / "XY" = u→X, v→Y, 두께 Z / "XZ" = u→X, v→Z, 두께 Y.
    고리마다 윤곽을 중심 쪽으로 줄여 두께가 가운데로 갈수록 바뀌게(날은 끝이 얇고 가운데가 두껍다)."""
    cu, cv = center

    def to3(u, v, w):
        if plane == "ZY":
            return (offset + w, v, u)
        if plane == "XY":
            return (u, v, offset + w)
        return (u, offset + w, v)

    loops_top, loops_bot = [], []
    for k in rings:
        top, bot = [], []
        for u, v in outline:
            uu, vv = cu + (u - cu) * k, cv + (v - cv) * k
            t = thick(uu, vv, k) / 2
            top.append(to3(uu, vv, t))
            bot.append(to3(uu, vv, -t))
        loops_top.append(top)
        loops_bot.append(bot)
    n = len(outline)
    verts, faces = [], []

    def put(loop):
        base = len(verts)
        verts.extend(loop)
        return list(range(base, base + n))

    T = [put(l) for l in loops_top]
    Bt = [put(l) for l in loops_bot]
    ct = thick(cu, cv, 0) / 2
    ci_t = len(verts)
    verts.append(to3(cu, cv, ct))
    ci_b = len(verts)
    verts.append(to3(cu, cv, -ct))
    # 윗면: 고리 사이 + 가운데 부채
    for a, b in zip(T, T[1:]):
        for i in range(n):
            faces.append((a[i], a[(i + 1) % n], b[(i + 1) % n], b[i]))
    for i in range(n):
        faces.append((T[-1][i], T[-1][(i + 1) % n], ci_t))
    for a, b in zip(Bt, Bt[1:]):
        for i in range(n):
            faces.append((a[(i + 1) % n], a[i], b[i], b[(i + 1) % n]))
    for i in range(n):
        faces.append((Bt[-1][(i + 1) % n], Bt[-1][i], ci_b))
    # 옆(바깥 고리 위아래 잇기)
    for i in range(n):
        faces.append((T[0][(i + 1) % n], T[0][i], Bt[0][i], Bt[0][(i + 1) % n]))
    g.add(verts, faces)


def smooth_outline(points, steps=6, closed=True):
    """꺾은선을 캣멀-롬으로 매끈하게(윤곽 다듬기)"""
    P = [Vector((p[0], p[1])) for p in points]
    n = len(P)
    out = []
    rng = range(n) if closed else range(n - 1)
    for i in rng:
        p0 = P[(i - 1) % n] if closed else P[max(0, i - 1)]
        p1 = P[i]
        p2 = P[(i + 1) % n] if closed else P[min(n - 1, i + 1)]
        p3 = P[(i + 2) % n] if closed else P[min(n - 1, i + 2)]
        for s in range(steps):
            t = s / steps
            t2, t3 = t * t, t * t * t
            q = 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
            out.append((q.x, q.y))
    if not closed:
        out.append((P[-1].x, P[-1].y))
    return out


def helix(center_y0, center_y1, radius, turns, steps_per_turn=16, cx=0.0, cz=0.0, phase=0.0):
    """Y 축 둘레 나선 경로(손잡이 감은 철사·끈)"""
    n = int(turns * steps_per_turn)
    pts = []
    for i in range(n + 1):
        t = i / n
        a = phase + TAU * turns * t
        pts.append((cx + radius * math.cos(a), center_y0 + (center_y1 - center_y0) * t, cz + radius * math.sin(a)))
    return pts
