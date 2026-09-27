"""저수준 메시 생성 함수 (로컬 좌표계).

모든 함수는 (verts, faces, uvs, smooth) 를 반환한다.
  verts : [Vector]
  faces : [tuple[int]]            (반시계 = 바깥쪽 법선)
  uvs   : [tuple[(u,v)...]]       (faces 와 동일한 모양, 코너별 UV — 단위: stud)
  smooth: [bool]                  (면별 스무스 셰이딩)
UV 는 stud 단위로 반환하고, Asset 이 UV_STUDS_PER_TILE 로 나눈다.
"""

import math
from mathutils import Vector, Matrix, noise


def _orient_convex(verts, faces, uvs, center):
    """볼록 형상: 면 법선이 중심 바깥을 향하도록 뒤집기."""
    out_f, out_uv = [], []
    for f, uv in zip(faces, uvs):
        a, b, c = verts[f[0]], verts[f[1]], verts[f[2]]
        n = (b - a).cross(c - a)
        fc = sum((verts[i] for i in f), Vector()) / len(f)
        if n.dot(fc - center) < 0:
            f = tuple(reversed(f))
            uv = tuple(reversed(uv))
        out_f.append(f)
        out_uv.append(uv)
    return out_f, out_uv


def _proj_uv(p, normal, dims):
    """면 법선의 지배축을 제외한 두 축으로 투영. 긴 치수 축이 u (나뭇결 방향)."""
    ax = max(range(3), key=lambda i: abs(normal[i]))
    others = [i for i in range(3) if i != ax]
    if dims[others[1]] > dims[others[0]]:
        others.reverse()
    return (p[others[0]], p[others[1]])


def box(size, bevel=0.0):
    """중심 원점 박스. bevel>0 이면 1단 챔퍼(모서리 하이라이트)."""
    hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
    dims = (size[0], size[1], size[2])
    c = min(bevel, 0.45 * min(size))
    verts, faces, uvs = [], [], []
    if c <= 1e-4:
        for sx in (-1, 1):
            for sy in (-1, 1):
                for sz in (-1, 1):
                    verts.append(Vector((sx * hx, sy * hy, sz * hz)))
        idx = lambda sx, sy, sz: ((sx > 0) * 4) + ((sy > 0) * 2) + (sz > 0)
        quads = [
            [idx(1, -1, -1), idx(1, 1, -1), idx(1, 1, 1), idx(1, -1, 1)],
            [idx(-1, -1, -1), idx(-1, -1, 1), idx(-1, 1, 1), idx(-1, 1, -1)],
            [idx(-1, 1, -1), idx(-1, 1, 1), idx(1, 1, 1), idx(1, 1, -1)],
            [idx(-1, -1, -1), idx(1, -1, -1), idx(1, -1, 1), idx(-1, -1, 1)],
            [idx(-1, -1, 1), idx(1, -1, 1), idx(1, 1, 1), idx(-1, 1, 1)],
            [idx(-1, -1, -1), idx(-1, 1, -1), idx(1, 1, -1), idx(1, -1, -1)],
        ]
        for q in quads:
            faces.append(tuple(q))
        normals = [Vector((1, 0, 0)), Vector((-1, 0, 0)), Vector((0, 1, 0)), Vector((0, -1, 0)), Vector((0, 0, 1)), Vector((0, 0, -1))]
        for q, n in zip(quads, normals):
            uvs.append(tuple(_proj_uv(verts[i], n, dims) for i in q))
        faces, uvs = _orient_convex(verts, faces, uvs, Vector())
        return verts, faces, uvs, [False] * len(faces)

    # 챔퍼 박스: 코너마다 3개 정점 (X면, Y면, Z면 위)
    vid = {}
    for sx in (-1, 1):
        for sy in (-1, 1):
            for sz in (-1, 1):
                vid[(sx, sy, sz, 0)] = len(verts); verts.append(Vector((sx * hx, sy * (hy - c), sz * (hz - c))))
                vid[(sx, sy, sz, 1)] = len(verts); verts.append(Vector((sx * (hx - c), sy * hy, sz * (hz - c))))
                vid[(sx, sy, sz, 2)] = len(verts); verts.append(Vector((sx * (hx - c), sy * (hy - c), sz * hz)))
    S = (-1, 1)
    # 주 면 6개
    for s in S:
        faces.append((vid[(s, -1, -1, 0)], vid[(s, 1, -1, 0)], vid[(s, 1, 1, 0)], vid[(s, -1, 1, 0)]))
        faces.append((vid[(-1, s, -1, 1)], vid[(1, s, -1, 1)], vid[(1, s, 1, 1)], vid[(-1, s, 1, 1)]))
        faces.append((vid[(-1, -1, s, 2)], vid[(1, -1, s, 2)], vid[(1, 1, s, 2)], vid[(-1, 1, s, 2)]))
    # 모서리 면 12개
    for a in S:
        for b in S:
            faces.append((vid[(-1, a, b, 1)], vid[(1, a, b, 1)], vid[(1, a, b, 2)], vid[(-1, a, b, 2)]))  # X 방향 모서리
            faces.append((vid[(a, -1, b, 0)], vid[(a, 1, b, 0)], vid[(a, 1, b, 2)], vid[(a, -1, b, 2)]))  # Y 방향
            faces.append((vid[(a, b, -1, 0)], vid[(a, b, 1, 0)], vid[(a, b, 1, 1)], vid[(a, b, -1, 1)]))  # Z 방향
    # 코너 삼각형 8개
    for sx in S:
        for sy in S:
            for sz in S:
                faces.append((vid[(sx, sy, sz, 0)], vid[(sx, sy, sz, 1)], vid[(sx, sy, sz, 2)]))
    for f in faces:
        a, b, cc = verts[f[0]], verts[f[1]], verts[f[2]]
        n = (b - a).cross(cc - a)
        if n.length < 1e-9 and len(f) > 3:
            n = (cc - a).cross(verts[f[3]] - a)
        uvs.append(tuple(_proj_uv(verts[i], n, dims) for i in f))
    faces, uvs = _orient_convex(verts, faces, uvs, Vector())
    return verts, faces, uvs, [False] * len(faces)


def cylinder_x(length, r0, r1=None, sides=12, bevel=0.0, caps=True):
    """X 축을 따라 놓인 원기둥 (Roblox Cylinder 와 동일 축). 중심 원점."""
    r1 = r0 if r1 is None else r1
    h = length / 2
    verts, faces, uvs, smooth = [], [], [], []
    rings = []  # (x, r)
    c = min(bevel, 0.3 * min(r0, r1), 0.3 * length)
    if c > 1e-4:
        rings = [(-h, r0 - c), (-h + c, r0), (h - c, r1), (h, r1 - c)]
    else:
        rings = [(-h, r0), (h, r1)]
    ring_idx = []
    for x, r in rings:
        ids = []
        for i in range(sides):
            a = 2 * math.pi * i / sides
            ids.append(len(verts))
            verts.append(Vector((x, math.cos(a) * r, math.sin(a) * r)))
        ring_idx.append(ids)
    circ = 2 * math.pi * max(r0, r1)
    for k in range(len(rings) - 1):
        A, B = ring_idx[k], ring_idx[k + 1]
        for i in range(sides):
            j = (i + 1) % sides
            faces.append((A[i], A[j], B[j], B[i]))
            u0, u1 = rings[k][0], rings[k + 1][0]
            v0, v1 = circ * i / sides, circ * (i + 1) / sides
            uvs.append(((u0, v0), (u0, v1), (u1, v1), (u1, v0)))
            smooth.append(True)
    if caps:
        for ids, x in ((ring_idx[0], rings[0][0]), (ring_idx[-1], rings[-1][0])):
            faces.append(tuple(ids))
            uvs.append(tuple((verts[i].y, verts[i].z) for i in ids))
            smooth.append(False)
    faces, uvs = _orient_convex(verts, faces, uvs, Vector())
    return verts, faces, uvs, smooth


def uv_sphere(radius, seg=12, rings=8, scale=(1, 1, 1)):
    verts, faces, uvs = [], [], []
    top = len(verts); verts.append(Vector((0, 0, radius * scale[2])))
    ring_ids = []
    for r in range(1, rings):
        th = math.pi * r / rings
        ids = []
        for s in range(seg):
            ph = 2 * math.pi * s / seg
            ids.append(len(verts))
            verts.append(Vector((math.sin(th) * math.cos(ph) * radius * scale[0],
                                 math.sin(th) * math.sin(ph) * radius * scale[1],
                                 math.cos(th) * radius * scale[2])))
        ring_ids.append(ids)
    bot = len(verts); verts.append(Vector((0, 0, -radius * scale[2])))
    circ = 2 * math.pi * radius
    for s in range(seg):
        t = (s + 1) % seg
        faces.append((top, ring_ids[0][s], ring_ids[0][t]))
        uvs.append(((circ * (s + 0.5) / seg, 0), (circ * s / seg, radius * math.pi / rings), (circ * (s + 1) / seg, radius * math.pi / rings)))
    for r in range(len(ring_ids) - 1):
        A, B = ring_ids[r], ring_ids[r + 1]
        for s in range(seg):
            t = (s + 1) % seg
            faces.append((A[s], B[s], B[t], A[t]))
            v0 = radius * math.pi * (r + 1) / rings
            v1 = radius * math.pi * (r + 2) / rings
            uvs.append(((circ * s / seg, v0), (circ * s / seg, v1), (circ * (s + 1) / seg, v1), (circ * (s + 1) / seg, v0)))
    for s in range(seg):
        t = (s + 1) % seg
        faces.append((bot, ring_ids[-1][t], ring_ids[-1][s]))
        uvs.append(((circ * (s + 0.5) / seg, radius * math.pi), (circ * (s + 1) / seg, radius * math.pi * (rings - 1) / rings), (circ * s / seg, radius * math.pi * (rings - 1) / rings)))
    faces, uvs = _orient_convex(verts, faces, uvs, Vector())
    return verts, faces, uvs, [True] * len(faces)


def _frames(points):
    """평행 이동 프레임 (접선, 법선, 종법선)."""
    n = len(points)
    tangents = []
    for i in range(n):
        if i == 0:
            t = points[1] - points[0]
        elif i == n - 1:
            t = points[-1] - points[-2]
        else:
            t = (points[i + 1] - points[i - 1])
        if t.length < 1e-9:
            t = Vector((0, 0, 1))
        tangents.append(t.normalized())
    ref = Vector((0, 0, 1)) if abs(tangents[0].z) < 0.9 else Vector((1, 0, 0))
    normal = tangents[0].cross(ref).normalized()
    frames = []
    for i in range(n):
        if i > 0:
            axis = tangents[i - 1].cross(tangents[i])
            if axis.length > 1e-9:
                ang = math.acos(max(-1.0, min(1.0, tangents[i - 1].dot(tangents[i]))))
                normal = Matrix.Rotation(ang, 3, axis.normalized()) @ normal
        binormal = tangents[i].cross(normal).normalized()
        normal = binormal.cross(tangents[i]).normalized()
        frames.append((tangents[i], normal, binormal))
    return frames


def tube(points, radii, sides=8, caps=True, noise_amp=0.0, noise_freq=0.6, seed=0.0, twist=0.0):
    """폴리라인을 따라가는 튜브(나무 줄기, 뿌리, 밧줄). radii 는 점별 반지름."""
    pts = [Vector(p) for p in points]
    frames = _frames(pts)
    verts, faces, uvs, smooth = [], [], [], []
    rings = []
    along = [0.0]
    for i in range(1, len(pts)):
        along.append(along[-1] + (pts[i] - pts[i - 1]).length)
    offs = Vector((seed * 13.1, seed * 7.7, seed * 3.3))
    for i, (p, (t, nrm, bn)) in enumerate(zip(pts, frames)):
        ids = []
        for s in range(sides):
            a = 2 * math.pi * s / sides + twist * along[i]
            d = nrm * math.cos(a) + bn * math.sin(a)
            r = radii[i]
            if noise_amp > 0:
                q = p + d * r
                r *= 1.0 + noise_amp * noise.noise(q * noise_freq + offs)
            ids.append(len(verts))
            verts.append(p + d * r)
        rings.append(ids)
    for i in range(len(pts) - 1):
        A, B = rings[i], rings[i + 1]
        rr = max(radii[i], radii[i + 1])
        circ = 2 * math.pi * rr
        for s in range(sides):
            t = (s + 1) % sides
            faces.append((A[s], A[t], B[t], B[s]))
            uvs.append(((along[i], circ * s / sides), (along[i], circ * (s + 1) / sides), (along[i + 1], circ * (s + 1) / sides), (along[i + 1], circ * s / sides)))
            smooth.append(True)
    if caps:
        for k, ids in ((0, rings[0]), (len(pts) - 1, rings[-1])):
            f = tuple(ids) if k == len(pts) - 1 else tuple(reversed(ids))
            faces.append(f)
            uvs.append(tuple((verts[i].x, verts[i].y) for i in f))
            smooth.append(False)
    # (nrm, bn, t) 는 오른손 좌표계이므로 위 링 면/캡은 이미 바깥을 향한다.
    return verts, faces, uvs, smooth


def grid_surface(fn, nu, nv, closed_u=False):
    """파라메트릭 표면 fn(u,v)->Vector (u,v in [0,1]). 돛, 선체 등."""
    verts, faces, uvs, smooth = [], [], [], []
    cols = nu if closed_u else nu + 1
    for j in range(nv + 1):
        for i in range(cols):
            verts.append(Vector(fn(i / nu, j / nv)))
    # 실제 거리 기반 UV
    def vid(i, j):
        return j * cols + (i % cols if closed_u else i)
    ulen = [[0.0] * (nu + 1) for _ in range(nv + 1)]
    vlen = [[0.0] * (nu + 1) for _ in range(nv + 1)]
    for j in range(nv + 1):
        for i in range(1, nu + 1):
            ulen[j][i] = ulen[j][i - 1] + (verts[vid(i, j)] - verts[vid(i - 1, j)]).length
    for i in range(nu + 1):
        for j in range(1, nv + 1):
            vlen[j][i] = vlen[j - 1][i] + (verts[vid(i, j)] - verts[vid(i, j - 1)]).length
    for j in range(nv):
        for i in range(nu):
            f = (vid(i, j), vid(i + 1, j), vid(i + 1, j + 1), vid(i, j + 1))
            faces.append(f)
            uvs.append(((ulen[j][i], vlen[j][i]), (ulen[j][i + 1], vlen[j][i + 1]), (ulen[j + 1][i + 1], vlen[j + 1][i + 1]), (ulen[j + 1][i], vlen[j + 1][i])))
            smooth.append(True)
    return verts, faces, uvs, smooth


def solidify(verts, faces, uvs, smooth, thickness):
    """얇은 표면에 두께 부여 (양면 렌더 의존 제거). 정점 법선 방향으로 오프셋."""
    vn = [Vector() for _ in verts]
    for f in faces:
        a, b, c = verts[f[0]], verts[f[1]], verts[f[2]]
        n = (b - a).cross(c - a)
        for i in f:
            vn[i] += n
    vn = [n.normalized() if n.length > 1e-9 else Vector((0, 0, 1)) for n in vn]
    n0 = len(verts)
    out_v = [v + n * thickness * 0.5 for v, n in zip(verts, vn)] + [v - n * thickness * 0.5 for v, n in zip(verts, vn)]
    out_f, out_uv, out_s = list(faces), list(uvs), list(smooth)
    for f, uv, s in zip(faces, uvs, smooth):
        out_f.append(tuple(i + n0 for i in reversed(f)))
        out_uv.append(tuple(reversed(uv)))
        out_s.append(s)
    # 경계 모서리 벽
    edge_count = {}
    for f in faces:
        for k in range(len(f)):
            e = (f[k], f[(k + 1) % len(f)])
            key = tuple(sorted(e))
            edge_count.setdefault(key, []).append(e)
    for key, es in edge_count.items():
        if len(es) == 1:
            a, b = es[0]
            out_f.append((b, a, a + n0, b + n0))
            L = (verts[a] - verts[b]).length
            out_uv.append(((0, 0), (L, 0), (L, thickness), (0, thickness)))
            out_s.append(False)
    return out_v, out_f, out_uv, out_s


def blob(radius, seg=12, rings=8, amp=0.25, freq=0.8, seed=0.0, scale=(1, 1, 1), flat_bottom=None):
    """노이즈로 울퉁불퉁한 구 (나뭇잎 덩어리, 이끼, 바위)."""
    verts, faces, uvs, smooth = uv_sphere(radius, seg, rings, scale)
    offs = Vector((seed * 5.3, seed * 9.1, seed * 2.7))
    out = []
    for v in verts:
        d = v.normalized() if v.length > 1e-9 else Vector((0, 0, 1))
        n = noise.noise(v * (freq / max(radius, 0.1)) * 2.0 + offs)
        nv = v * (1.0 + amp * n)
        if flat_bottom is not None and nv.z < flat_bottom:
            nv.z = flat_bottom + (nv.z - flat_bottom) * 0.15
        out.append(nv)
    return out, faces, uvs, smooth
