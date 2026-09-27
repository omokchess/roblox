"""고수준 건축 부품: 판자 바닥/벽, 지붕널 지붕, 기둥, 난간, 사다리, 계단, 랜턴, 문/창문, 소품.

모든 함수는 Asset 의 현재 변환 프레임 기준 로컬 좌표를 사용한다.
"""

import math

from mathutils import Vector

from . import geom

WOOD = ("wood_a", "wood_b", "wood_c")
SHINGLES = ("shingle_a", "shingle_b", "shingle_c")


def pick(a, keys):
    return keys[a.rng.randrange(len(keys))]


# ─────────────────────────────────────────────────────────────
# 바닥 / 데크
# ─────────────────────────────────────────────────────────────

def plank_floor(a, x0, x1, y0, y1, z, plank_w=1.15, thick=0.34, along="x", keys=WOOD, gap=0.07,
                joists=True, joist_key="wood_dark", joist_every=4.5, overhang=0.25, collider=True, tag="Floor",
                missing=0.0):
    """z = 바닥 윗면 높이. along='x' 이면 판자가 X 방향으로 뻗음."""
    if along == "x":
        span0, span1, stack0, stack1 = x0, x1, y0, y1
    else:
        span0, span1, stack0, stack1 = y0, y1, x0, x1
    n = max(1, int(round((stack1 - stack0) / plank_w)))
    w = (stack1 - stack0) / n
    for i in range(n):
        if missing and a.rng.random() < missing and 0 < i < n - 1:
            continue
        c = stack0 + (i + 0.5) * w
        s0 = span0 - a.rng.uniform(0, overhang)
        s1 = span1 + a.rng.uniform(0, overhang)
        # 긴 바닥은 이음매로 분할
        segs = []
        L = s1 - s0
        if L > 14:
            k = int(L // 10) + 1
            cuts = sorted(s0 + L * (j + a.rng.uniform(0.3, 0.7)) / k for j in range(1, k))
            pts = [s0] + cuts + [s1]
            segs = list(zip(pts[:-1], pts[1:]))
        else:
            segs = [(s0, s1)]
        for (u0, u1) in segs:
            zz = z - thick / 2 + a.rng.uniform(-0.03, 0.03)
            yaw = a.rng.uniform(-0.5, 0.5)
            roll = a.rng.uniform(-1.2, 1.2)
            size = (u1 - u0 - 0.04, w - gap, thick)
            if along == "x":
                a.box(((u0 + u1) / 2, c, zz), size, pick(a, keys), rot=(roll, 0, yaw), bevel=0.06)
            else:
                a.box((c, (u0 + u1) / 2, zz), (size[1], size[0], size[2]), pick(a, keys), rot=(0, roll, yaw), bevel=0.06)
    if joists:
        # 장선: 판자 방향과 수직
        jn = max(2, int((span1 - span0) / joist_every) + 1)
        for j in range(jn):
            u = span0 + 0.4 + (span1 - span0 - 0.8) * j / (jn - 1)
            if along == "x":
                a.box((u, (y0 + y1) / 2, z - thick - 0.4), (0.7, (y1 - y0) + 0.3, 0.8), joist_key, bevel=0.08)
            else:
                a.box(((x0 + x1) / 2, u, z - thick - 0.4), ((x1 - x0) + 0.3, 0.7, 0.8), joist_key, bevel=0.08)
    if collider:
        a.collider(((x0 + x1) / 2, (y0 + y1) / 2, z - 0.6), (x1 - x0, y1 - y0, 1.2), tag=tag)


# ─────────────────────────────────────────────────────────────
# 벽
# ─────────────────────────────────────────────────────────────

def _subtract(intervals, cut):
    out = []
    for (a0, a1) in intervals:
        c0, c1 = cut
        if c1 <= a0 or c0 >= a1:
            out.append((a0, a1))
            continue
        if c0 > a0:
            out.append((a0, c0))
        if c1 < a1:
            out.append((c1, a1))
    return out


def plank_wall(a, p0, p1, z0, z1, openings=(), plank_w=1.05, thick=0.32, keys=WOOD, battens=True,
               batten_key="wood_dark", trim_key="wood_dark", top_profile=None, collider=True, jag=0.18,
               lean=0.0, outward=-1):
    """세로 판자벽. p0->p1 (XY 평면) 을 따라 지어지고 높이 z0..z1.
    openings: [(u0,u1,v0,v1)] — 벽 시작점 기준 거리 u, 높이 v (z 절대값).
    top_profile: f(u)->z  (박공 벽처럼 윗선이 기울 때)
    outward: 벽 바깥쪽이 로컬 -Y(=-1) 인지 +Y(=+1) 인지 (배튼/트림이 붙는 면)
    """
    p0, p1 = Vector(p0), Vector(p1)
    d = p1 - p0
    L = d.length
    yaw = math.degrees(math.atan2(d.y, d.x))
    with a.at(loc=(p0.x, p0.y, 0), rot=(lean, 0, yaw)):
        n = max(1, int(round(L / plank_w)))
        w = L / n
        for i in range(n):
            u0 = i * w
            u1 = u0 + w
            uc = (u0 + u1) / 2
            top = top_profile(uc) if top_profile else z1
            top += a.rng.uniform(-jag, jag * 0.5)
            spans = [(z0 - a.rng.uniform(0, 0.25), top)]
            for (ou0, ou1, ov0, ov1) in openings:
                if uc > ou0 - 0.05 and uc < ou1 + 0.05:
                    spans = _subtract(spans, (ov0, ov1))
            for (v0, v1) in spans:
                if v1 - v0 < 0.15:
                    continue
                a.box((uc, a.rng.uniform(-0.04, 0.04), (v0 + v1) / 2), (w - 0.05, thick, v1 - v0), pick(a, keys),
                      rot=(0, a.rng.uniform(-0.6, 0.6), 0), bevel=0.05)
        if battens:
            for i in range(1, n):
                u = i * w
                top = (top_profile(u) if top_profile else z1) - 0.3
                spans = [(z0 + 0.1, top)]
                for (ou0, ou1, ov0, ov1) in openings:
                    if u > ou0 - 0.3 and u < ou1 + 0.3:
                        spans = _subtract(spans, (ov0 - 0.3, ov1 + 0.3))
                for (v0, v1) in spans:
                    if v1 - v0 < 0.5:
                        continue
                    if i % 2 == 0:
                        a.box((u, outward * (thick / 2 + 0.07), (v0 + v1) / 2), (0.38, 0.14, v1 - v0), batten_key, bevel=0.03)
        # 개구부 트림(문틀/창틀)
        for (ou0, ou1, ov0, ov1) in openings:
            tw = 0.42
            yo = outward * (thick / 2 + 0.08)
            a.box(((ou0 + ou1) / 2, yo, ov1 + tw / 2), (ou1 - ou0 + 2 * tw + 0.3, 0.2, tw), trim_key, bevel=0.05)
            if ov0 > z0 + 0.5:
                a.box(((ou0 + ou1) / 2, yo * 1.3, ov0 - tw / 2), (ou1 - ou0 + 2 * tw + 0.5, 0.45, tw), trim_key, bevel=0.05)
            for uu in (ou0 - tw / 2, ou1 + tw / 2):
                a.box((uu, yo, (ov0 + ov1) / 2), (tw, 0.2, ov1 - ov0), trim_key, bevel=0.05)
        if collider:
            segs = [(0.0, L)]
            for (ou0, ou1, ov0, ov1) in openings:
                if ov0 <= z0 + 0.6:  # 문: 벽을 전체 높이로 끊음
                    segs = _subtract(segs, (ou0, ou1))
            for (s0, s1) in segs:
                if s1 - s0 > 0.2:
                    a.collider(((s0 + s1) / 2, 0, (z0 + z1) / 2), (s1 - s0, max(thick, 0.8), z1 - z0), tag="Wall")
            for (ou0, ou1, ov0, ov1) in openings:
                if ov0 <= z0 + 0.6:
                    a.collider(((ou0 + ou1) / 2, 0, (ov1 + z1) / 2), (ou1 - ou0, max(thick, 0.8), max(0.2, z1 - ov1)), tag="Wall")


def log_wall(a, p0, p1, z0, z1, r=0.55, key="wood_dark", keys=None, overhang=0.9, collider=True, openings=()):
    """가로 통나무 벽 (롱하우스). 개구부가 있으면 통나무를 분할."""
    p0, p1 = Vector(p0), Vector(p1)
    d = p1 - p0
    L = d.length
    yaw = math.degrees(math.atan2(d.y, d.x))
    with a.at(loc=(p0.x, p0.y, 0), rot=(0, 0, yaw)):
        n = max(1, int((z1 - z0) / (2 * r * 0.92)))
        for i in range(n):
            z = z0 + r + i * (z1 - z0 - 2 * r) / max(1, n - 1)
            spans = [(-overhang * a.rng.uniform(0.6, 1.0), L + overhang * a.rng.uniform(0.6, 1.0))]
            for (ou0, ou1, ov0, ov1) in openings:
                if z + r > ov0 and z - r < ov1:
                    spans = _subtract(spans, (ou0, ou1))
            for (u0, u1) in spans:
                if u1 - u0 < 0.6:
                    continue
                rr = r * a.rng.uniform(0.9, 1.08)
                k = key if keys is None else pick(a, keys)
                a.cyl((u0, 0, z), (u1, 0, z), rr, k, r1=rr * a.rng.uniform(0.88, 1.0), sides=10, bevel=0.12)
        for (ou0, ou1, ov0, ov1) in openings:
            a.box(((ou0 + ou1) / 2, 0, ov1 + 0.25), (ou1 - ou0 + 1.0, 1.5, 0.5), "wood_c", bevel=0.06)
            for uu in (ou0 - 0.2, ou1 + 0.2):
                a.box((uu, 0, (ov0 + ov1) / 2), (0.4, 1.5, ov1 - ov0), "wood_c", bevel=0.05)
        if collider:
            segs = [(0.0, L)]
            for (ou0, ou1, ov0, ov1) in openings:
                if ov0 <= z0 + 0.6:
                    segs = _subtract(segs, (ou0, ou1))
            for (s0, s1) in segs:
                if s1 - s0 > 0.2:
                    a.collider(((s0 + s1) / 2, 0, (z0 + z1) / 2), (s1 - s0, 2 * r, z1 - z0), tag="Wall")
            for (ou0, ou1, ov0, ov1) in openings:
                if ov0 <= z0 + 0.6:
                    a.collider(((ou0 + ou1) / 2, 0, (ov1 + z1) / 2), (ou1 - ou0, 2 * r, max(0.2, z1 - ov1)), tag="Wall")


# ─────────────────────────────────────────────────────────────
# 지붕
# ─────────────────────────────────────────────────────────────

def _shingle_slope(a, length, slope_len, keys, row_h=0.95, sh_len=1.9, thick=0.13, part_rows=True, moss=0.0):
    """로컬 프레임: X=능선 방향(0..length, 중심 기준 -L/2..L/2), Y=경사 위쪽(0=처마 .. slope_len=능선), Z=지붕 법선."""
    rows = max(1, int(slope_len / row_h))
    with a.no_parts():
        for r in range(rows):
            y = r * row_h
            x = -length / 2 - a.rng.uniform(0.1, 0.4) - (0.5 if r % 2 else 0)
            while x < length / 2:
                w = a.rng.uniform(0.9, 1.5)
                if x + w > length / 2 + 0.3:
                    w = length / 2 + 0.3 - x
                if w > 0.3:
                    k = pick(a, keys)
                    if moss and a.rng.random() < moss:
                        k = "moss"
                    a.box((x + w / 2, y + sh_len / 2, 0.08 + thick / 2 + r * 0.004), (w - 0.06, sh_len, thick), k,
                          rot=(-5 + a.rng.uniform(-1.5, 1.5), a.rng.uniform(-1.5, 1.5), a.rng.uniform(-2.5, 2.5)), bevel=0.0)
                x += w
    if part_rows:
        # Part 버전: 행 단위 긴 판 (적당한 디테일 + 적은 파트 수)
        with a.at():
            for r in range(rows):
                y = r * row_h
                k = pick(a, keys)
                a._prim_box_only((0, y + sh_len / 2, 0.14 + r * 0.004), (length + 0.4, sh_len, 0.2), k, rot=(-5, 0, 0))


def gable_roof(a, cx, cy, z_eave, length, span, pitch=38.0, overhang=1.4, gable_over=1.2, keys=SHINGLES,
               deck_key="wood_dark", ridge_key="wood_dark", moss=0.06, rafters=True, yaw=0.0, collider=True):
    """맞배지붕. 능선은 로컬 X 방향. (cx,cy) 중심, z_eave = 벽 윗선 높이."""
    half = span / 2 + overhang
    rise = (span / 2) * math.tan(math.radians(pitch))
    slope_len = half / math.cos(math.radians(pitch))
    L = length + 2 * gable_over
    z_ridge = z_eave + rise
    z_edge = z_eave - overhang * math.tan(math.radians(pitch))
    with a.at(loc=(cx, cy, 0), rot=(0, 0, yaw)):
        for side in (-1, 1):
            # 경사면 프레임: X=능선 방향, Y=처마->능선, Z=지붕 법선 (오른손 좌표계)
            base = Vector((0, side * half, z_edge))
            up_dir = Vector((0, -side * math.cos(math.radians(pitch)), math.sin(math.radians(pitch))))
            normal = Vector((0, side * math.sin(math.radians(pitch)), math.cos(math.radians(pitch))))
            xdir = Vector((1, 0, 0)) if side < 0 else Vector((-1, 0, 0))
            from mathutils import Matrix
            R = Matrix((xdir, up_dir, normal)).transposed().to_4x4()
            with a.at(matrix=Matrix.Translation(base) @ R):
                # 지붕 덮개판
                a.box((0, slope_len / 2, -0.12), (L, slope_len + 0.2, 0.28), deck_key, bevel=0.04)
                _shingle_slope(a, L, slope_len, keys, moss=moss)
                if collider:
                    a.collider((0, slope_len / 2, 0.0), (L, slope_len, 0.6), tag="Roof")
        # 용마루
        a.cyl((-L / 2 - 0.3, 0, z_ridge + 0.35), (L / 2 + 0.3, 0, z_ridge + 0.35), 0.42, ridge_key, sides=8, bevel=0.08)
        with a.no_parts():
            n = int(L / 1.3)
            for i in range(n):
                x = -L / 2 + (i + 0.5) * L / n
                a.box((x, 0, z_ridge + 0.55), (1.2, 1.3, 0.14), pick(a, keys), rot=(0, 0, a.rng.uniform(-3, 3)), bevel=0.0)
        if rafters:
            # 박공 끝 서까래 (바지보드)
            for sx in (-1, 1):
                for side in (-1, 1):
                    p0 = (sx * (L / 2 + 0.05), side * (half + 0.1), z_edge - 0.25)
                    p1 = (sx * (L / 2 + 0.05), 0, z_ridge + 0.05)
                    a.box_between(p0, p1, 0.5, "wood_dark", width=0.35, bevel=0.05)
                # 박공 장식 (교차 끝)
                a.box_between((sx * (L / 2 + 0.1), -0.9, z_ridge - 0.2), (sx * (L / 2 + 0.1), 0.9, z_ridge + 1.6), 0.3, "wood_dark", width=0.3)
    return z_ridge


def pyramid_roof(a, cx, cy, z_base, half, height, overhang=1.2, keys=SHINGLES, deck_key="wood_dark", finial=True, moss=0.05, collider=True):
    """사각뿔 지붕 (망루, 등대 등). 4개의 삼각 경사면에 지붕널."""
    H = half + overhang
    drop = overhang * height / half
    zb = z_base - drop
    apex = Vector((cx, cy, z_base + height))
    for k in range(4):
        yaw = k * 90
        rad = math.radians(yaw)
        # 면 로컬: 밑변 중심 -> 꼭짓점
        outward = Vector((math.cos(rad), math.sin(rad), 0))
        base_c = Vector((cx, cy, zb)) + outward * H
        up_vec = (apex - base_c)
        slope_len = up_vec.length
        up_dir = up_vec.normalized()
        xdir = Vector((-math.sin(rad), math.cos(rad), 0))
        normal = xdir.cross(up_dir).normalized()
        if normal.z < 0:
            normal = -normal
            xdir = -xdir
        from mathutils import Matrix
        R = Matrix((xdir, up_dir, normal)).transposed().to_4x4()
        with a.at(matrix=Matrix.Translation(base_c) @ R):
            # 삼각형 덮개 (메시) + Part 근사
            tri_v = [Vector((-H, 0, -0.1)), Vector((H, 0, -0.1)), Vector((0, slope_len, -0.1)),
                     Vector((-H, 0, -0.35)), Vector((H, 0, -0.35)), Vector((0, slope_len, -0.35))]
            tri_f = [(0, 1, 2), (5, 4, 3), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)]
            tri_uv = [tuple((v.x, v.y) for v in (tri_v[i] for i in f)) for f in tri_f]
            a.mesh((tri_v, tri_f, tri_uv, [False] * 5), deck_key)
            rows = int(slope_len / 0.95)
            for r in range(rows):
                y = r * 0.95
                wrow = H * (1 - (y + 0.9) / slope_len) * 2
                if wrow < 0.4:
                    continue
                with a.no_parts():
                    x = -wrow / 2 - (0.4 if r % 2 else 0)
                    while x < wrow / 2:
                        w = min(a.rng.uniform(0.8, 1.3), wrow / 2 + 0.2 - x)
                        if w > 0.25:
                            kk = "moss" if a.rng.random() < moss else pick(a, keys)
                            a.box((x + w / 2, y + 0.95, 0.1 + r * 0.004), (w - 0.05, 1.9, 0.13), kk,
                                  rot=(-5, a.rng.uniform(-1.5, 1.5), a.rng.uniform(-2, 2)), bevel=0.0)
                        x += w
                a._prim_box_only((0, y + 0.95, 0.12), (wrow, 1.9, 0.2), pick(a, keys), rot=(-5, 0, 0))
            if collider:
                a.collider((0, slope_len * 0.45, -0.1), (H * 1.1, slope_len * 0.9, 0.5), tag="Roof")
        # 모서리 마루
        corner = Vector((cx, cy, zb)) + Vector((math.cos(rad) - math.sin(rad), math.sin(rad) + math.cos(rad), 0)) * H
        a.box_between(corner, apex, 0.36, "wood_dark", width=0.36)
    if finial:
        a.cyl((cx, cy, z_base + height - 0.4), (cx, cy, z_base + height + 1.4), 0.18, "iron", sides=6)
        a.sphere((cx, cy, z_base + height + 1.5), 0.3, "iron", seg=8, rings=6)


def thatch_roof(a, cx, cy, z_eave, length, span, pitch=45.0, overhang=1.6, layers=None, keys=("thatch", "thatch_dk"), collider=True):
    """초가 지붕: 들쭉날쭉한 짚단 층을 겹쳐 쌓는다."""
    from mathutils import Matrix
    half = span / 2 + overhang
    rise = (span / 2) * math.tan(math.radians(pitch))
    slope_len = half / math.cos(math.radians(pitch))
    z_edge = z_eave - overhang * math.tan(math.radians(pitch))
    z_ridge = z_eave + rise
    L = length + 2 * overhang
    rows = layers or max(3, int(slope_len / 1.4))
    for side in (-1, 1):
        base = Vector((cx, cy + side * half, z_edge))
        up_dir = Vector((0, -side * math.cos(math.radians(pitch)), math.sin(math.radians(pitch))))
        normal = Vector((0, side * math.sin(math.radians(pitch)), math.cos(math.radians(pitch))))
        xdir = Vector((1, 0, 0)) if side < 0 else Vector((-1, 0, 0))
        R = Matrix((xdir, up_dir, normal)).transposed().to_4x4()
        with a.at(matrix=Matrix.Translation(base) @ R):
            a.box((0, slope_len / 2, -0.15), (L, slope_len, 0.3), "wood_dark", bevel=0.03)
            for r in range(rows):
                y0 = r * slope_len / rows
                h = slope_len / rows * 1.9
                nx = int(L / 0.7)
                # 들쭉날쭉한 아래 끝단을 가진 짚 층 메시
                verts, faces, uvs = [], [], []
                for i in range(nx + 1):
                    x = -L / 2 + L * i / nx
                    jag = a.rng.uniform(-0.35, 0.05)
                    th = 0.55 + a.rng.uniform(-0.1, 0.1)
                    verts += [Vector((x, y0 + jag, 0.0 + r * 0.05)), Vector((x, y0 + jag - 0.05, th + r * 0.05)),
                              Vector((x, y0 + h, th * 0.5 + r * 0.05)), Vector((x, y0 + h, 0.0 + r * 0.05))]
                for i in range(nx):
                    b0, b1 = i * 4, (i + 1) * 4
                    for q in ((b0, b1, b1 + 1, b0 + 1), (b0 + 1, b1 + 1, b1 + 2, b0 + 2), (b0 + 3, b0 + 2, b1 + 2, b1 + 3), (b0, b0 + 3, b1 + 3, b1)):
                        faces.append(q)
                        uvs.append(tuple((verts[k].x, verts[k].y + verts[k].z) for k in q))
                faces.append((0, 1, 2, 3)); uvs.append(tuple((verts[k].y, verts[k].z) for k in (0, 1, 2, 3)))
                e = nx * 4
                faces.append((e + 3, e + 2, e + 1, e)); uvs.append(tuple((verts[k].y, verts[k].z) for k in (e + 3, e + 2, e + 1, e)))
                a.mesh((verts, faces, uvs, [True] * len(faces)), pick(a, keys),
                       part_boxes=[((0, y0 + h / 2, 0.3 + r * 0.05), (L, h, 0.55), None)])
            if collider:
                a.collider((0, slope_len / 2, 0.1), (L, slope_len, 0.7), tag="Roof")
    # 용마루 짚단
    a.cyl((cx - L / 2, cy, z_ridge + 0.2), (cx + L / 2, cy, z_ridge + 0.2), 0.75, keys[0], sides=10)
    for i in range(int(L / 3) + 1):
        x = cx - L / 2 + 0.5 + i * (L - 1) / max(1, int(L / 3))
        a.cyl((x - 0.2, cy, z_ridge + 0.2), (x + 0.2, cy, z_ridge + 0.2), 0.82, "rope", sides=10)
    return z_ridge


def shed_roof(a, x0, x1, y_low, y_high, z_low, z_high, keys=SHINGLES, overhang=1.0, collider=True, moss=0.05):
    """외쪽지붕 (차양, 가판대)."""
    from mathutils import Matrix
    base = Vector(((x0 + x1) / 2, y_low - overhang * (1 if y_high > y_low else -1), z_low - overhang * (z_high - z_low) / abs(y_high - y_low)))
    top = Vector(((x0 + x1) / 2, y_high, z_high))
    up = top - base
    slope_len = up.length
    up_dir = up.normalized()
    xdir = Vector((1, 0, 0)) if y_high > y_low else Vector((-1, 0, 0))
    normal = xdir.cross(up_dir)
    if normal.z < 0:
        xdir = -xdir
        normal = -normal
    R = Matrix((xdir, up_dir, normal)).transposed().to_4x4()
    L = abs(x1 - x0) + 2 * overhang
    with a.at(matrix=Matrix.Translation(base) @ R):
        a.box((0, slope_len / 2, -0.12), (L, slope_len + 0.3, 0.26), "wood_dark", bevel=0.04)
        _shingle_slope(a, L, slope_len, keys, moss=moss)
        if collider:
            a.collider((0, slope_len / 2, 0), (L, slope_len, 0.6), tag="Roof")


# ─────────────────────────────────────────────────────────────
# 구조물
# ─────────────────────────────────────────────────────────────

def stilt(a, x, y, z_top, z_bottom=-7.0, r=0.62, lean=2.5, lash=True, key="wood_dark"):
    """늪 기둥: 수면 아래 부분은 젖은 색, 윗부분에 밧줄 결속."""
    lx = a.rng.uniform(-lean, lean)
    ly = a.rng.uniform(-lean, lean)
    dx = math.tan(math.radians(lx)) * (z_top - z_bottom)
    dy = math.tan(math.radians(ly)) * (z_top - z_bottom)
    top = Vector((x, y, z_top))
    bot = Vector((x + dx, y + dy, z_bottom))
    t_w = (0.9 - z_bottom) / (z_top - z_bottom)
    mid = bot.lerp(top, t_w)
    rr = r * a.rng.uniform(0.9, 1.1)
    a.cyl(bot, mid, rr * 1.05, "wood_wet", r1=rr, sides=10, bevel=0.0)
    a.cyl(mid, top, rr, key, r1=rr * 0.95, sides=10, bevel=0.1)
    if lash:
        with a.no_parts():
            for dz in (-1.8,):
                zc = z_top + dz
                c = bot.lerp(top, (zc - z_bottom) / (z_top - z_bottom))
                for k in range(2):
                    ring = [c + Vector((math.cos(t) * (rr + 0.1), math.sin(t) * (rr + 0.1), 0.25 * k)) for t in [i * 2 * math.pi / 8 for i in range(9)]]
                    a.tube(ring, 0.12, "rope", sides=4, caps=False, part=False)
    return bot, top


def cross_brace(a, p_top0, p_bot0, p_top1, p_bot1, key="wood_dark"):
    a.box_between(p_top0, p_bot1, 0.4, key, width=0.3, bevel=0.05)
    a.box_between(p_top1, p_bot0, 0.4, key, width=0.3, bevel=0.05)


def post(a, x, y, z0, z1, w=0.55, key="wood_dark", bevel=0.08):
    a.box((x, y, (z0 + z1) / 2), (w, w, z1 - z0), key, rot=(a.rng.uniform(-0.8, 0.8), a.rng.uniform(-0.8, 0.8), a.rng.uniform(-3, 3)), bevel=bevel)


def railing(a, pts, z, h=3.3, post_every=4.0, key="wood_dark", rail_keys=WOOD, collider=True, mid=True, closed=False):
    """난간: pts 는 (x,y) 목록."""
    pts = [Vector((p[0], p[1], z)) for p in pts]
    if closed:
        pts = pts + [pts[0]]
    for i in range(len(pts) - 1):
        p0, p1 = pts[i], pts[i + 1]
        L = (p1 - p0).length
        n = max(1, int(round(L / post_every)))
        for k in range(n + (1 if i == len(pts) - 2 and not closed else 0)):
            t = k / n
            p = p0.lerp(p1, t)
            post(a, p.x, p.y, z - 0.2, z + h + 0.25, 0.45, key)
        top0, top1 = p0 + Vector((0, 0, h)), p1 + Vector((0, 0, h))
        a.box_between(top0, top1, 0.38, pick(a, rail_keys), width=0.5, bevel=0.06)
        if mid:
            a.box_between(p0 + Vector((0, 0, h * 0.5)), p1 + Vector((0, 0, h * 0.5)), 0.28, pick(a, rail_keys), width=0.24, bevel=0.04)
        if collider:
            d = (p1 - p0)
            mid_p = (p0 + p1) / 2 + Vector((0, 0, h / 2 + 0.3))
            yaw = math.degrees(math.atan2(d.y, d.x))
            a.collider(mid_p, (L, 0.6, h + 0.6), rot=(0, 0, yaw), tag="Rail")


def rope_railing(a, pts, z, h=3.0, sag=0.5, key="wood_dark", collider=True):
    """부두용 밧줄 난간: 기둥 사이 처진 밧줄."""
    pts = [Vector((p[0], p[1], z)) for p in pts]
    for p in pts:
        post(a, p.x, p.y, z - 0.3, z + h + 0.3, 0.55, key)
        a.cyl((p.x, p.y, z + h + 0.3), (p.x, p.y, z + h + 0.55), 0.38, key, sides=8)
    for i in range(len(pts) - 1):
        for hh, sg in ((h, sag), (h * 0.55, sag * 0.7)):
            p0 = pts[i] + Vector((0, 0, hh))
            p1 = pts[i + 1] + Vector((0, 0, hh))
            seg = [p0.lerp(p1, t) - Vector((0, 0, sg * 4 * t * (1 - t))) for t in [j / 8 for j in range(9)]]
            a.tube(seg, 0.13, "rope", sides=6, caps=False, part_step=4)
        if collider:
            d = pts[i + 1] - pts[i]
            yaw = math.degrees(math.atan2(d.y, d.x))
            a.collider((pts[i] + pts[i + 1]) / 2 + Vector((0, 0, h / 2 + 0.3)), (d.length, 0.5, h + 0.6), rot=(0, 0, yaw), tag="Rail")


def ladder(a, x, y, z0, z1, yaw=0.0, width=2.2, key="wood_c", lean=12.0):
    with a.at(loc=(x, y, z0), rot=(0, 0, yaw)):
        H = z1 - z0
        dy = math.tan(math.radians(lean)) * H
        for sx in (-1, 1):
            a.box_between((sx * width / 2, dy, 0), (sx * width / 2, 0, H + 0.8), 0.35, "wood_dark", width=0.3)
        n = int(H / 1.1)
        for i in range(1, n + 1):
            t = i / (n + 1)
            z = t * H
            yy = dy * (1 - t)
            a.cyl((-width / 2, yy, z), (width / 2, yy, z), 0.12, key, sides=6)
        # Roblox 에서 오르려면 TrussPart 가 필요 -> shape="Truss" (투명 트러스로 생성, 크기는 2의 배수)
        a.collider((0, dy / 2, H / 2 + 0.4), (2, 2, max(2, round((H + 0.8) / 2) * 2)), rot=(math.degrees(math.atan2(dy, H)), 0, 0), shape="Truss", tag="Ladder")
        a.marker("Ladder", (0, dy / 2, H / 2))


def stairs(a, p_bottom, p_top, width=4.0, key_tread=WOOD, key_side="wood_dark", rails=True):
    p0, p1 = Vector(p_bottom), Vector(p_top)
    d = p1 - p0
    horiz = Vector((d.x, d.y, 0))
    yaw = math.degrees(math.atan2(d.y, d.x))
    run = horiz.length
    rise = d.z
    n = max(2, int(rise / 0.8))
    with a.at(loc=p0, rot=(0, 0, yaw)):
        for sy in (-1, 1):
            a.box_between((0, sy * width / 2, -0.4), (run, sy * width / 2, rise - 0.4), 0.9, key_side, width=0.35)
        for i in range(n):
            t = (i + 0.5) / n
            a.box((run * t, 0, rise * t - 0.1), (run / n + 0.35, width - 0.1, 0.3), pick(a, key_tread), bevel=0.05)
        a.collider_between((0, 0, 0.05), (run, 0, rise + 0.05), width, 0.8, tag="Stairs")
        if rails:
            for sy in (-1, 1):
                a.box_between((0, sy * width / 2, 3.0), (run, sy * width / 2, rise + 3.0), 0.3, "wood_c", width=0.3)
                for t in (0.0, 0.5, 1.0):
                    a.box((run * t, sy * width / 2, rise * t + 1.4), (0.35, 0.35, 3.2), key_side, bevel=0.04)


def lantern(a, pos, hang=0.0, light=True, glow="glow_lantern", scale=1.0, bracket=None, rng_range=18, brightness=1.6, color=(255, 176, 96)):
    """철제 랜턴. bracket=(dx,dy): 벽에서 뻗는 L자 브래킷 방향."""
    p = Vector(pos)
    with a.at(loc=p, scale=scale):
        if bracket:
            bx, by = bracket
            a.box_between((-bx * 1.6, -by * 1.6, 1.3 + hang), (0, 0, 1.3 + hang), 0.18, "iron", width=0.14)
            a.box_between((-bx * 1.6, -by * 1.6, 0.4 + hang), (-bx * 0.5, -by * 0.5, 1.3 + hang), 0.14, "iron", width=0.12)
        if hang > 0:
            with a.no_parts():
                for i in range(int(hang / 0.35)):
                    z = 1.1 + hang - i * 0.35
                    a.box((0, 0, z), (0.1, 0.22 if i % 2 else 0.08, 0.3), "iron", rot=(0, 0, 90 * (i % 2)), bevel=0.0)
            a.cyl((0, 0, 1.1), (0, 0, 1.1 + hang), 0.05, "iron", sides=4)
        a.cyl((0, 0, 0.78), (0, 0, 1.05), 0.48, "iron", r1=0.2, sides=8, bevel=0.03)
        a.cyl((0, 0, -0.62), (0, 0, -0.5), 0.46, "iron", sides=8, bevel=0.02)
        for k in range(4):
            ang = math.radians(45 + 90 * k)
            a.box((math.cos(ang) * 0.38, math.sin(ang) * 0.38, 0.12), (0.09, 0.09, 1.3), "iron", bevel=0.0)
        a.cyl((0, 0, -0.5), (0, 0, 0.72), 0.3, glow, sides=8)
        with a.no_parts():
            a.cyl((0, 0, 0.72), (0, 0, 0.8), 0.4, "iron", sides=8)
    if light:
        a.light((p.x, p.y, p.z + 0.1 * scale), color=color, range_=rng_range, brightness=brightness)


def door(a, u, width, height, z0, thick=0.28, keys=("wood_red",), open_angle=0.0, hinge_left=True, outward=-1):
    """벽 로컬(벽 방향 X) 기준 판자문. open_angle>0 이면 열린 채로 배치."""
    hx = u if hinge_left else u + width
    sgn = 1 if hinge_left else -1
    with a.at(loc=(hx, outward * 0.2, z0), rot=(0, 0, -outward * sgn * open_angle)):
        n = 4
        for i in range(n):
            x = sgn * (i + 0.5) * width / n
            a.box((x, 0, height / 2), (width / n - 0.04, thick, height - 0.1), pick(a, keys), bevel=0.04)
        for z in (height * 0.2, height * 0.8):
            a.box((sgn * width / 2, outward * 0.2, z), (width - 0.2, 0.14, 0.45), "wood_dark", bevel=0.03)
        a.box_between((sgn * 0.3, outward * 0.2, height * 0.22), (sgn * (width - 0.3), outward * 0.2, height * 0.78), 0.14, "wood_dark", width=0.4)
        with a.no_parts():
            ring_c = Vector((sgn * (width - 0.55), outward * 0.35, height * 0.5))
            ring = [ring_c + Vector((math.cos(t) * 0.22, 0, math.sin(t) * 0.22)) for t in [i * 2 * math.pi / 10 for i in range(11)]]
            a.tube(ring, 0.05, "iron", sides=4, caps=False, part=False)
            for z in (height * 0.2, height * 0.8):
                a.box((sgn * 0.5, outward * 0.3, z), (0.9, 0.06, 0.2), "iron", bevel=0.0)


def window(a, u, v, w, h, shutters=True, keys=("wood_teal",), glass=False, outward=-1, sill=True):
    """벽 로컬 기준 창문 (u=창 왼쪽 거리, v=창 아래 높이). 덧문 활짝."""
    yo = outward * 0.35
    a.box((u + w / 2, 0, v + h / 2), (0.16, 0.2, h), "wood_dark", bevel=0.0)
    a.box((u + w / 2, 0, v + h / 2), (w, 0.2, 0.16), "wood_dark", bevel=0.0)
    if glass:
        a.box((u + w / 2, 0, v + h / 2), (w, 0.08, h), "glass", bevel=0.0)
    if shutters:
        for side in (0, 1):
            x = u - w / 4 - 0.25 if side == 0 else u + w + w / 4 + 0.25
            ang = a.rng.uniform(-12, 12)
            with a.at(loc=(x, yo, v + h / 2), rot=(0, 0, ang)):
                for i in range(3):
                    a.box((-w / 4 + (i + 0.5) * w / 6, 0, 0), (w / 6 - 0.04, 0.18, h), pick(a, keys), bevel=0.03)
                a.box((0, outward * 0.12, h * 0.25), (w / 2, 0.1, 0.3), "wood_dark", bevel=0.0)
                a.box((0, outward * 0.12, -h * 0.25), (w / 2, 0.1, 0.3), "wood_dark", bevel=0.0)


# ─────────────────────────────────────────────────────────────
# 소품
# ─────────────────────────────────────────────────────────────

def barrel(a, pos, h=3.0, r=1.15, key="wood_b", hoop="iron", lid=True, yaw=0.0, lying=False):
    p = Vector(pos)
    rot = (0, 90, yaw) if lying else (0, 0, yaw)
    with a.at(loc=p, rot=rot):
        prof = [(0.0, r * 0.86), (h * 0.15, r * 0.95), (h * 0.5, r), (h * 0.85, r * 0.95), (h, r * 0.86)]
        pts = [Vector((0, 0, z)) for z, _ in prof]
        radii = [rr for _, rr in prof]
        with a.no_parts():
            a.tube(pts, radii, key, sides=16, caps=True, noise_amp=0.0, part=False)
            for z in (h * 0.12, h * 0.3, h * 0.7, h * 0.88):
                rr = r * (0.95 if z in (h * 0.12, h * 0.88) else 0.995) + 0.04
                ring = [Vector((math.cos(t) * rr, math.sin(t) * rr, z)) for t in [i * 2 * math.pi / 16 for i in range(17)]]
                a.tube(ring, 0.08, hoop, sides=4, caps=False, part=False)
            if lid:
                a.cyl((0, 0, h - 0.12), (0, 0, h - 0.02), r * 0.8, "wood_dark", sides=16)
        a._prim_cyl_only((0, 0, 0), (0, 0, h), r * 0.95, key)
    return p


def crate(a, pos, s=2.6, yaw=0.0, keys=WOOD, frame_key="wood_dark"):
    p = Vector(pos)
    with a.at(loc=(p.x, p.y, p.z + s / 2), rot=(0, 0, yaw)):
        a.box((0, 0, 0), (s - 0.2, s - 0.2, s - 0.2), pick(a, keys), bevel=0.04)
        with a.no_parts():
            # 판자 이음선 + 프레임
            for ax in range(3):
                for sgn in (-1, 1):
                    for k in range(-1, 2, 2):
                        c = [0, 0, 0]; c[ax] = sgn * (s / 2 - 0.08)
                        c2 = list(c); oth = [i for i in range(3) if i != ax]
                        c2[oth[0]] = k * (s / 2 - 0.12)
                        size = [0, 0, 0]; size[ax] = 0.16; size[oth[0]] = 0.26; size[oth[1]] = s
                        a.box(c2, size, frame_key, bevel=0.03)
            for sgn in (-1, 1):
                a.box_between((-s / 2 + 0.2, sgn * (s / 2 - 0.06), -s / 2 + 0.2), (s / 2 - 0.2, sgn * (s / 2 - 0.06), s / 2 - 0.2), 0.14, frame_key, width=0.3)
    a.collider((p.x, p.y, p.z + s / 2), (s, s, s), rot=(0, 0, yaw), tag="Prop")


def sack(a, pos, r=0.9, key="cloth_green", yaw=0.0):
    p = Vector(pos)
    with a.at(loc=(p.x, p.y, p.z + r * 0.75), rot=(a.rng.uniform(-8, 8), a.rng.uniform(-8, 8), yaw)):
        a.sphere((0, 0, 0), r, "straw" if key == "straw" else key, seg=10, rings=7, scale=(1.0, 0.85, 0.8))
        a.cyl((0, 0, r * 0.55), (0, 0, r * 1.1), r * 0.3, key, r1=r * 0.18, sides=8)
        with a.no_parts():
            ring = [Vector((math.cos(t) * r * 0.33, math.sin(t) * r * 0.33, r * 0.75)) for t in [i * 2 * math.pi / 8 for i in range(9)]]
            a.tube(ring, 0.06, "rope", sides=4, caps=False, part=False)


def rope_coil(a, pos, r=0.9, turns=4, thick=0.16):
    p = Vector(pos)
    pts = []
    n = turns * 14
    for i in range(n + 1):
        t = i / 14 * 2 * math.pi
        rr = r - (i / n) * r * 0.45
        pts.append(p + Vector((math.cos(t) * rr, math.sin(t) * rr, thick + (i % 14 == 0) * 0.0 + (i / n) * thick * 1.2)))
    a.tube(pts, thick, "rope", sides=5, caps=True, part_step=7)


def bottle(a, pos, h=0.9, r=0.22, key="glass_green", cork=True):
    p = Vector(pos)
    with a.at(loc=p):
        prof = [(0, r), (h * 0.55, r), (h * 0.72, r * 0.45), (h, r * 0.35)]
        a.tube([Vector((0, 0, z)) for z, _ in prof], [rr for _, rr in prof], key, sides=8, part_step=3)
        if cork:
            a.cyl((0, 0, h), (0, 0, h + 0.14), r * 0.32, "wood_pale", sides=6)


def candle(a, pos, h=0.6, r=0.14, light=False):
    p = Vector(pos)
    a.cyl(p, p + Vector((0, 0, h)), r, "candle", sides=6)
    a.sphere(p + Vector((0, 0, h + 0.12)), 0.08, "glow_fire", seg=6, rings=4, scale=(1, 1, 1.8))
    if light:
        a.light(p + Vector((0, 0, h + 0.3)), color=(255, 170, 90), range_=10, brightness=1.0)


def fish(a, pos, L=1.4, yaw=0.0, pitch=-80):
    p = Vector(pos)
    with a.at(loc=p, rot=(0, pitch, yaw)):
        a.sphere((0, 0, 0), L / 2, "fish", seg=8, rings=6, scale=(1.0, 0.25, 0.4))
        a.box((L * 0.55, 0, 0), (L * 0.3, 0.06, L * 0.4), "fish", rot=(0, 0, 0), bevel=0.0)


def hanging_moss(a, p, length=3.0, strands=5, spread=0.8):
    """스패니시 모스: 가지에서 늘어지는 가는 가닥들 (메시 전용)."""
    p = Vector(p)
    with a.no_parts():
        for s in range(strands):
            off = Vector((a.rng.uniform(-spread, spread), a.rng.uniform(-spread, spread), 0))
            L = length * a.rng.uniform(0.5, 1.1)
            pts = [p + off + Vector((a.rng.uniform(-0.1, 0.1) * i, a.rng.uniform(-0.1, 0.1) * i, -L * i / 5)) for i in range(6)]
            a.tube(pts, [0.12, 0.1, 0.09, 0.07, 0.05, 0.02], "moss_hang", sides=4, caps=False, part=False)
    # Part 버전: 한 가닥 요약 (no_parts 컨텍스트면 _prim 이 무시)
    a._prim_box_only((p.x, p.y, p.z - length * 0.45), (0.5, 0.5, length * 0.9), "moss_hang")
