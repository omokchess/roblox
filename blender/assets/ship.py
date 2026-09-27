"""연락선 '안개늪호' (Ferry) + 노 젓는 배 (Rowboat) + 난파선 (Shipwreck).

배 로컬 좌표: +Y = 선수(앞), +X = 우현(오른쪽, 정박 시 부두 쪽), Z=0 수면.
Roblox 로 가면 LookVector = 선수, RightVector = 우현.

선체는 파라메트릭 로프트: s(0=선미 → 1=선수), t(0=용골 → 1=현측 상단).
그룹
  Main       : 선체/갑판/선실/돛대 등 고정부
  Sails      : 돛 (클라이언트에서 부풂 애니메이션)
  Gangplank  : 도선판 (정박 시 내려감, 힌지 마커 기준 회전)
"""

import math

from mathutils import Vector

from swamplib.asset import Asset
from swamplib import geom, shapes as S


class Hull:
    def __init__(self, length=84.0, beam=11.0, keel=-5.0, sheer_mid=10.5, sheer_bow=13.5, sheer_stern=14.0,
                 transom=0.74, bow_rise=3.0, stern_rise=-3.5, y0=None):
        self.L = length
        self.B = beam
        self.keel0 = keel
        self.sm, self.sb, self.ss = sheer_mid, sheer_bow, sheer_stern
        self.transom = transom
        self.bow_rise = bow_rise
        self.stern_rise = stern_rise
        self.y0 = -length / 2 if y0 is None else y0

    def y(self, s):
        return self.y0 + self.L * s

    def width(self, s):
        """최대 반폭 비율."""
        if s <= 0.45:
            return self.transom + (1 - self.transom) * math.sin(math.pi / 2 * s / 0.45)
        u = (s - 0.45) / 0.55
        return max(0.0, math.cos(math.pi / 2 * min(1.0, u) ** 1.25))

    def keel(self, s):
        if s > 0.7:
            u = (s - 0.7) / 0.3
            return self.keel0 + (self.bow_rise - self.keel0) * (u ** 2.2)
        if s < 0.12:
            u = (0.12 - s) / 0.12
            return self.keel0 + (self.stern_rise - self.keel0) * u ** 1.5
        return self.keel0

    def sheer(self, s):
        if s >= 0.55:
            u = (s - 0.55) / 0.45
            return self.sm + (self.sb - self.sm) * u * u
        u = (0.55 - s) / 0.55
        return self.sm + (self.ss - self.sm) * u * u

    def point(self, s, t):
        """외판 한 점 (우현, x>=0)."""
        B = self.B * self.width(s)
        kz = self.keel(s)
        sz = self.sheer(s)
        depth = sz - kz
        # 선수/선미 쪽일수록 V 형 단면
        p = 0.7 + 1.1 * max(0.0, (s - 0.6) / 0.4) ** 1.5 + 0.5 * max(0.0, (0.15 - s) / 0.15)
        tb = 0.62  # 둥근 빌지가 차지하는 비율
        if t <= tb:
            th = (t / tb) * math.pi / 2
            x = B * (math.sin(th) ** p)
            z = kz + depth * 0.55 * (1 - math.cos(th))
        else:
            u = (t - tb) / (1 - tb)
            x = B * (1 - 0.05 * u * u)          # 약한 텀블홈
            z = kz + depth * (0.55 + 0.45 * u)
        return Vector((x, self.y(s), z))

    def half_width_at(self, s, z):
        """높이 z 에서 외판 반폭 (갑판 폭 계산용)."""
        best = 0.0
        prev = self.point(s, 0.0)
        for i in range(1, 61):
            cur = self.point(s, i / 60)
            if (prev.z - z) * (cur.z - z) <= 0 and abs(cur.z - prev.z) > 1e-6:
                f = (z - prev.z) / (cur.z - prev.z)
                best = prev.x + (cur.x - prev.x) * f
            prev = cur
        if best == 0.0 and self.point(s, 1.0).z < z:
            best = self.point(s, 1.0).x
        return best


def _emit_partitioned(a, geo, key_fn):
    """면 중심 z 로 머티리얼을 나눠 방출."""
    verts, faces, uvs, smooth = geo
    buckets = {}
    for f, uv, sm in zip(faces, uvs, smooth):
        c = sum((verts[i] for i in f), Vector()) / len(f)
        buckets.setdefault(key_fn(c), []).append((f, uv, sm))
    for key, items in buckets.items():
        used = sorted({i for f, _, _ in items for i in f})
        remap = {v: k for k, v in enumerate(used)}
        nv = [verts[i] for i in used]
        nf = [tuple(remap[i] for i in f) for f, _, _ in items]
        a.mesh((nv, nf, [uv for _, uv, _ in items], [sm for _, _, sm in items]), key)


def _t_at_z(H, s, z):
    """외판 곡선에서 높이 z 에 해당하는 t (z 는 t 에 대해 단조 증가)."""
    lo, hi = 0.0, 1.0
    if H.point(s, 0.0).z >= z:
        return 0.0
    if H.point(s, 1.0).z <= z:
        return 1.0
    for _ in range(30):
        mid = (lo + hi) / 2
        if H.point(s, mid).z < z:
            lo = mid
        else:
            hi = mid
    return (lo + hi) / 2


def _hull_bands(H, waterline=1.0, band=(5.6, 4.0)):
    """(t_a(s), t_b(s), key역할) 목록: 수선 아래 / 현측 / 도색 띠 / 현측 상단."""
    wl = lambda s: _t_at_z(H, s, waterline)
    b0 = lambda s: max(wl(s), _t_at_z(H, s, H.sheer(s) - band[0]))
    b1 = lambda s: max(b0(s), _t_at_z(H, s, H.sheer(s) - band[1]))
    return [
        (lambda s: 0.0, wl, "bottom"),
        (wl, b0, "side"),
        (b0, b1, "band"),
        (b1, lambda s: 1.0, "side"),
    ]


def _hull_surface(a, H, ns=56, nt=16, keys=None, part_ns=14, part_nt=5, band=(5.6, 4.0)):
    keys = keys or {"bottom": "planks_hull_dk", "side": "planks_hull", "band": "hull_paint"}
    regions = _hull_bands(H, band=band)
    rows = {"bottom": max(3, nt * 5 // 16), "side": max(2, nt * 4 // 16), "band": 2}
    for side in (1, -1):
        for (ta, tb, role) in regions:
            def fn(u, v, side=side, ta=ta, tb=tb):
                t = ta(u) + (tb(u) - ta(u)) * v
                p = H.point(u, t)
                return (p.x * side, p.y, p.z)
            v_, f_, uv_, sm_ = geom.grid_surface(fn, ns, rows[role])
            # 퇴화(0 폭) 면 제거
            keep = []
            for i, f in enumerate(f_):
                a0, b0_, c0 = v_[f[0]], v_[f[1]], v_[f[2]]
                area = (b0_ - a0).cross(c0 - a0).length + (v_[f[3]] - a0).cross(c0 - a0).length
                if area > 1e-5:
                    keep.append(i)
            f_ = [f_[i] for i in keep]; uv_ = [uv_[i] for i in keep]; sm_ = [sm_[i] for i in keep]
            if side < 0:
                f_ = [tuple(reversed(x)) for x in f_]
                uv_ = [tuple(reversed(x)) for x in uv_]
            if f_:
                with a.no_parts():
                    a.mesh((v_, f_, uv_, sm_), keys[role])
        # Part 버전: 외판 스트레이크 박스
        from mathutils import Matrix
        for i in range(part_ns):
            for j in range(part_nt):
                s0, s1 = i / part_ns, (i + 1) / part_ns
                t0, t1 = j / part_nt, (j + 1) / part_nt
                p00, p10 = H.point(s0, t0), H.point(s1, t0)
                p01, p11 = H.point(s0, t1), H.point(s1, t1)
                for P in (p00, p10, p01, p11):
                    P.x *= side
                c = (p00 + p10 + p01 + p11) / 4
                xa = ((p10 + p11) / 2 - (p00 + p01) / 2)
                ya = ((p01 + p11) / 2 - (p00 + p10) / 2)
                if xa.length < 0.05 or ya.length < 0.05:
                    continue
                xd = xa.normalized()
                n = xd.cross(ya).normalized()
                yd = n.cross(xd).normalized()
                R = Matrix((xd, yd, n)).transposed().to_4x4()
                sm = (s0 + s1) / 2
                key = keys["bottom"] if c.z < 1.0 else (keys["band"] if H.sheer(sm) - band[0] < c.z < H.sheer(sm) - band[1] else keys["side"])
                a._prim("Block", a.M @ Matrix.Translation(c) @ R, (xa.length + 0.35, ya.length + 0.35, 0.7), key)


def _deck_planks(a, H, z, s0, s1, keys=("deck",), plank_w=1.2, margin=0.5, collider=True, tag="Deck"):
    """갑판: 선체 내폭에 맞춰 판자 레인을 자른다."""
    samples = 80
    hw = [(s0 + (s1 - s0) * i / samples, H.half_width_at(s0 + (s1 - s0) * i / samples, z) - margin) for i in range(samples + 1)]
    maxw = max(w for _, w in hw)
    n = int(2 * maxw / plank_w)
    for k in range(n):
        x = -maxw + (k + 0.5) * 2 * maxw / n
        inside = [s for s, w in hw if w > abs(x) + 0.3]
        if not inside:
            continue
        sa, sb = min(inside), max(inside)
        ya, yb = H.y(sa), H.y(sb)
        # 이음매
        L = yb - ya
        cuts = [ya]
        yy = ya + a.rng.uniform(6, 12)
        while yy < yb - 3:
            cuts.append(yy)
            yy += a.rng.uniform(10, 16)
        cuts.append(yb)
        for c0, c1 in zip(cuts[:-1], cuts[1:]):
            a.box((x, (c0 + c1) / 2, z - 0.17 + a.rng.uniform(-0.02, 0.02)), (2 * maxw / n - 0.07, c1 - c0 - 0.05, 0.34), S.pick(a, keys), bevel=0.05)
    if collider:
        seg = 6
        for i in range(seg):
            sa = s0 + (s1 - s0) * i / seg
            sb = s0 + (s1 - s0) * (i + 1) / seg
            w = min(H.half_width_at(sa, z), H.half_width_at(sb, z), H.half_width_at((sa + sb) / 2, z)) - 0.2
            if w > 0.5:
                a.collider((0, (H.y(sa) + H.y(sb)) / 2, z - 0.6), (2 * w, H.y(sb) - H.y(sa) + 0.05, 1.2), tag=tag)


def _bulwark(a, H, s0, s1, z_deck, z_top_fn, openings=(), thick=0.5, collider=True):
    """현장(불워크) 안쪽 면 + 상단 레일. openings=[(s_a, s_b, side)]"""
    n = 40
    for side in (1, -1):
        pts = []
        for i in range(n + 1):
            s = s0 + (s1 - s0) * i / n
            ztop = z_top_fn(s)
            w = H.half_width_at(s, min(ztop, H.sheer(s))) if ztop <= H.sheer(s) else H.point(s, 1.0).x
            pts.append((s, Vector((side * (w - thick), H.y(s), z_deck)), Vector((side * (w - thick * 0.4), H.y(s), ztop))))
        # 안쪽 판 (세로 판자 느낌: 구간마다 박스)
        for i in range(n):
            (sa, pa, qa), (sb, pb, qb) = pts[i], pts[i + 1]
            sm = (sa + sb) / 2
            if any(o0 <= sm <= o1 and (os_ == 0 or os_ == side) for o0, o1, os_ in openings):
                continue
            c = (pa + pb + qa + qb) / 4
            dy = pb.y - pa.y
            h = (qa.z + qb.z) / 2 - z_deck
            yaw = math.degrees(math.atan2(pb.x - pa.x, dy))
            a.box((c.x, c.y, z_deck + h / 2), (thick, dy + 0.05, h), "planks_hull", rot=(0, 0, -yaw), bevel=0.0)
            # 레일 캡
            a.box(((qa.x + qb.x) / 2, (qa.y + qb.y) / 2, (qa.z + qb.z) / 2 + 0.2), (thick + 0.5, dy + 0.1, 0.4), "wood_dark", rot=(math.degrees(math.atan2(qb.z - qa.z, dy)), 0, -yaw), bevel=0.06)
            if i % 4 == 0:
                a.box((pa.x - side * 0.3, pa.y, z_deck + h / 2), (0.45, 0.45, h), "wood_dark", bevel=0.05)
        if collider:
            seg = 10
            for i in range(seg):
                sa = s0 + (s1 - s0) * i / seg
                sb = s0 + (s1 - s0) * (i + 1) / seg
                sm = (sa + sb) / 2
                if any(o0 <= sm <= o1 and (os_ == 0 or os_ == side) for o0, o1, os_ in openings):
                    continue
                wa = H.half_width_at(sa, z_deck + 1.0)
                wb = H.half_width_at(sb, z_deck + 1.0)
                ya, yb = H.y(sa), H.y(sb)
                yaw = math.degrees(math.atan2(side * (wb - wa), yb - ya))
                h = max(z_top_fn(sa), z_top_fn(sb)) - z_deck + 0.6
                a.collider((side * (wa + wb) / 2 - side * 0.3, (ya + yb) / 2, z_deck + h / 2), (1.0, math.hypot(yb - ya, wb - wa) + 0.3, h), rot=(0, 0, -yaw), tag="Rail")


def _sail_square(a, top_c, bot_c, w_top, w_bot, bulge, key="sail", nx=10, ny=8):
    top_c, bot_c = Vector(top_c), Vector(bot_c)
    def fn(u, v):
        p = top_c.lerp(bot_c, v)
        w = w_top + (w_bot - w_top) * v
        x = (u - 0.5) * w
        b = bulge * math.sin(math.pi * u) * math.sin(math.pi * (0.15 + 0.85 * v))
        return (x, p.y + b, p.z - 0.4 * math.sin(math.pi * u) * v)
    geo = geom.solidify(*geom.grid_surface(fn, nx, ny), 0.12)
    with a.in_group("Sails"):
        a.mesh(geo, key)
        mid = top_c.lerp(bot_c, 0.5)
        h = (top_c - bot_c).length
        a._prim_box_only((mid.x, mid.y + bulge * 0.55, mid.z), ((w_top + w_bot) / 2, 0.2, h), key)
    # 보강 띠 (리프 밴드)
    with a.no_parts(), a.in_group("Sails"):
        for v in (0.3, 0.55):
            pts = [Vector(fn(u / 10, v)) + Vector((0, 0.15, 0)) for u in range(11)]
            a.tube(pts, 0.1, "sail_patch", sides=4, caps=False, part=False)


def _sail_quad(a, corners, bulge_dir, bulge, key="sail", nx=10, ny=10):
    """4 꼭짓점 (tack, clew, peak, throat) 세로 돛/삼각돛 (throat==peak 이면 삼각)."""
    p00, p10, p11, p01 = [Vector(c) for c in corners]
    bd = Vector(bulge_dir).normalized()
    def fn(u, v):
        a0 = p00.lerp(p10, u)
        a1 = p01.lerp(p11, u)
        p = a0.lerp(a1, v)
        return tuple(p + bd * bulge * math.sin(math.pi * u) * math.sin(math.pi * v))
    geo = geom.solidify(*geom.grid_surface(fn, nx, ny), 0.12)
    with a.in_group("Sails"):
        a.mesh(geo, key)


def _rope(a, p0, p1, sag=0.0, r=0.1, key="rope_dk", part=True, n=6):
    p0, p1 = Vector(p0), Vector(p1)
    pts = [p0.lerp(p1, i / n) - Vector((0, 0, sag * 4 * (i / n) * (1 - i / n))) for i in range(n + 1)]
    a.tube(pts, r, key, sides=4, caps=False, part=part, part_step=n)


def _wheel(a, c, r=2.2, yaw=0.0):
    c = Vector(c)
    with a.at(loc=c, rot=(90, 0, yaw)):
        ring = [Vector((math.cos(t) * r, math.sin(t) * r, 0)) for t in [i * 2 * math.pi / 20 for i in range(21)]]
        a.tube(ring, 0.18, "wood_red", sides=6, caps=False, part_step=5)
        for k in range(8):
            ang = k * 2 * math.pi / 8
            a.cyl((0, 0, 0), (math.cos(ang) * (r + 0.6), math.sin(ang) * (r + 0.6), 0), 0.12, "wood_red", sides=6)
            a.sphere((math.cos(ang) * (r + 0.75), math.sin(ang) * (r + 0.75), 0), 0.2, "wood_red", seg=6, rings=4)
        a.cyl((0, 0, -0.3), (0, 0, 0.3), 0.45, "brass", sides=8)


def _figurehead(a, H):
    """뱀 머리 선수상 (늪 테마)."""
    s = 0.985
    base = H.point(s, 0.85)
    base.x = 0
    pts = [base + Vector((0, 0.5, 0)), base + Vector((0, 3.0, 1.5)), base + Vector((0, 5.0, 3.8)), base + Vector((0, 6.2, 6.4)), base + Vector((0, 7.4, 7.4))]
    a.tube(pts, [0.9, 0.85, 0.75, 0.7, 0.6], "hull_paint", sides=10, part_step=2)
    head = pts[-1] + Vector((0, 0.8, 0.2))
    a.sphere(head, 1.2, "hull_paint", seg=10, rings=7, scale=(0.8, 1.5, 0.7), rot=(15, 0, 0))
    for sx in (-1, 1):
        a.sphere(head + Vector((sx * 0.7, 0.4, 0.5)), 0.28, "glow_mushroom", seg=6, rings=4)
        a.tube([head + Vector((sx * 0.5, -0.6, 0.6)), head + Vector((sx * 0.9, -1.8, 1.6)), head + Vector((sx * 1.0, -2.8, 2.0))], [0.25, 0.18, 0.05], "gold", sides=5, part_step=2)
    a.box(head + Vector((0, 1.3, -0.3)), (0.9, 1.2, 0.3), "gold", bevel=0.05)


def ferry():
    a = Asset("Ferry", "Ship", replicated=True, description="연락선 '안개늪호' — 2돛대 브리간틴, 섬 사이 항로 운항")
    H = Hull()
    DECK = 7.0          # 주갑판 (부두 높이와 동일)
    QD = 10.8           # 선미 갑판
    FC = 9.6            # 선수루
    S_QD = 0.2          # 선미 갑판 끝 s
    S_FC = 0.84         # 선수루 시작 s
    _hull_surface(a, H)
    # 선미판 (트랜섬)
    tp = [H.point(0.0, i / 16) for i in range(17)]
    verts = [Vector((p.x, p.y, p.z)) for p in tp] + [Vector((-p.x, p.y, p.z)) for p in tp]
    faces = [(i, i + 1, 17 + i + 1, 17 + i) for i in range(16)]
    uvs = [tuple((verts[k].x, verts[k].z) for k in f) for f in faces]
    a.mesh((verts, faces, uvs, [False] * len(faces)), "hull_paint")
    tw = H.point(0.0, 1.0).x
    a._prim_box_only((0, H.y(0.0) - 0.2, (H.keel(0) + H.sheer(0)) / 2 + 1.5), (2 * tw, 0.5, H.sheer(0) - H.keel(0) - 3), "hull_paint")
    # 선미 창 (발광)
    for k in range(4):
        x = -tw * 0.7 + k * tw * 1.4 / 3
        a.box((x, H.y(0.0) - 0.35, 12.3), (1.8, 0.3, 1.6), "glow_lantern", bevel=0.0)
        a.box((x, H.y(0.0) - 0.45, 12.3), (2.3, 0.2, 2.1), "wood_dark", bevel=0.05)
    a.box((0, H.y(0.0) - 0.5, 14.3), (2 * tw * 0.9, 0.4, 0.5), "gold", bevel=0.05)
    a.marker("NamePlate", (0, H.y(0.0) - 0.75, 9.6), rot=(0, 0, 180), text="안개늪호", width=10.0, height=1.6)
    a.box((0, H.y(0.0) - 0.55, 9.6), (11.0, 0.3, 2.0), "wood_dark", bevel=0.06)
    # 외판 장식: 금색 웨일 라인
    with a.no_parts():
        for side in (1, -1):
            pts = []
            for i in range(41):
                s = i / 40
                z = H.sheer(s) - 4.0
                w = H.half_width_at(s, z)
                if w <= 0.1:
                    continue
                pts.append(Vector((side * (w + 0.12), H.y(s), z)))
            if len(pts) > 2:
                a.tube(pts, 0.22, "gold", sides=5, caps=False, part=False)
    # ── 갑판 ──
    _deck_planks(a, H, DECK, S_QD - 0.02, S_FC + 0.02)
    _deck_planks(a, H, QD, 0.005, S_QD, tag="Deck")
    _deck_planks(a, H, FC, S_FC, 0.975, tag="Deck")
    # 선미 갑판/선수루 앞 벽 + 계단
    for (s_edge, zt, facing) in ((S_QD, QD, 1), (S_FC, FC, -1)):
        w = H.half_width_at(s_edge, DECK) - 0.6
        y = H.y(s_edge)
        S.plank_wall(a, (-w, y), (w, y), DECK, zt, openings=[(w - 3.5, w + 3.5, DECK, zt)] if facing > 0 else [(w - 3.2, w + 3.2, DECK, zt)],
                     keys=("hull_paint", "planks_hull"), battens=True, collider=True, jag=0.0, outward=-facing)
        a.box((0, y, zt + 0.15), (2 * w + 0.4, 1.2, 0.3), "wood_dark", bevel=0.05)
        # 난간 (갑판 가장자리 앞)
        S.railing(a, [(-w, y + facing * 0.3), (-3.2, y + facing * 0.3)], zt, h=3.0, post_every=2.4)
        S.railing(a, [(3.2, y + facing * 0.3), (w, y + facing * 0.3)], zt, h=3.0, post_every=2.4)
    # 계단 (가운데 개구부 → 좌우 계단)
    ys = H.y(S_QD)
    for sx in (-1, 1):
        S.stairs(a, (sx * 1.6, ys + 7.0, DECK), (sx * 1.6, ys + 0.5, QD), width=2.8, rails=False)
    yf = H.y(S_FC)
    for sx in (-1, 1):
        S.stairs(a, (sx * 1.6, yf - 6.0, DECK), (sx * 1.6, yf - 0.5, FC), width=2.8, rails=False)
    # 선실 문 & 창 (선미 갑판 아래 벽)
    with a.at(loc=(0, ys - 0.2, 0)):
        for sx in (-1, 1):
            a.box((sx * 6.5, 0, DECK + 2.0), (1.8, 0.3, 1.6), "glow_lantern", bevel=0.0)
            a.box((sx * 6.5, -0.1, DECK + 2.0), (2.3, 0.2, 2.1), "wood_dark", bevel=0.04)
    # ── 현장 & 레일 ──
    GANG = (0.47, 0.55, 0)  # 양현 도선 개구부
    def rail_top(s):
        if s < S_QD:
            return QD + 3.0
        if s > S_FC:
            return FC + 3.0
        return DECK + 3.2
    _bulwark(a, H, 0.004, S_QD, QD, lambda s: QD + 3.0, openings=())
    _bulwark(a, H, S_QD, S_FC, DECK, lambda s: DECK + 3.2, openings=(GANG,))
    _bulwark(a, H, S_FC, 0.975, FC, lambda s: FC + 3.0, openings=())
    # 선미 난간 (트랜섬 위)
    S.railing(a, [(-tw + 0.6, H.y(0.0) + 0.6), (tw - 0.6, H.y(0.0) + 0.6)], QD, h=3.0, post_every=2.0)
    # ── 돛대 ──
    masts = [(0.70, 58.0, "Fore"), (0.42, 64.0, "Main")]
    mast_tops = {}
    for s_m, h, name in masts:
        y = H.y(s_m)
        base = Vector((0, y, DECK - 2.0))
        top = Vector((0, y, DECK + h))
        a.cyl(base, base.lerp(top, 0.62), 1.05, "wood_c", r1=0.85, sides=12, bevel=0.1)
        a.cyl(base.lerp(top, 0.6), top, 0.7, "wood_c", r1=0.4, sides=10, bevel=0.05)
        a.collider((0, y, DECK + h * 0.3), (2.0, 2.0, h * 0.6), tag="Mast")
        # 망대 (top)
        tz = DECK + h * 0.6
        a.cyl((0, y, tz - 0.3), (0, y, tz + 0.3), 3.6, "wood_dark", sides=14, bevel=0.08)
        with a.no_parts():
            for k in range(10):
                ang = k * 2 * math.pi / 10
                a.box_between((0, y, tz - 2.5), (math.cos(ang) * 3.2, y + math.sin(ang) * 3.2, tz - 0.3), 0.25, "wood_dark", width=0.25)
        # 밧줄 감기 (mast bands)
        with a.no_parts():
            for z in (DECK + 3, DECK + 12, DECK + 24):
                a.cyl((0, y, z), (0, y, z + 0.5), 1.12, "iron", sides=12)
        mast_tops[name] = (top, tz, y)
        # 돛대 꼭대기 랜턴 + 깃발
        a.sphere(top + Vector((0, 0, 0.4)), 0.6, "wood_dark", seg=8, rings=5)
    # 선수 기움 돛대 (bowsprit)
    bs0 = Vector((0, H.y(0.93), FC + 0.8))
    bs1 = Vector((0, H.y(1.0) + 22.0, FC + 9.0))
    a.cyl(bs0, bs1, 0.8, "wood_c", r1=0.35, sides=10, bevel=0.05)
    # ── 활대(야드) & 돛 ──
    fy = mast_tops["Fore"][2]
    for (z, w) in ((DECK + 15.0, 36.0), (DECK + 31.0, 32.0), (DECK + 33.0, 28.0), (DECK + 47.0, 22.0)):
        a.cyl((-w / 2, fy + 1.2, z), (w / 2, fy + 1.2, z), 0.45, "wood_c", r1=0.45, sides=8)
        a.cyl((-w / 2 - 0.5, fy + 1.2, z), (-w / 2, fy + 1.2, z), 0.25, "wood_dark", sides=6)
        a.cyl((w / 2, fy + 1.2, z), (w / 2 + 0.5, fy + 1.2, z), 0.25, "wood_dark", sides=6)
    _sail_square(a, (0, fy + 1.4, DECK + 30.6), (0, fy + 1.4, DECK + 15.6), 31.0, 35.0, 3.2)
    _sail_square(a, (0, fy + 1.4, DECK + 46.6), (0, fy + 1.4, DECK + 33.6), 21.0, 27.0, 2.6)
    # 메인 세로돛 (가프 & 붐)
    my = mast_tops["Main"][2]
    boom0 = Vector((0.3, my - 1.0, DECK + 7.0))
    boom1 = Vector((1.2, H.y(0.08), DECK + 8.5))
    a.cyl(boom0, boom1, 0.5, "wood_c", r1=0.35, sides=8)
    gaff0 = Vector((0.3, my - 1.0, DECK + 40.0))
    gaff1 = Vector((1.8, H.y(0.14), DECK + 49.0))
    a.cyl(gaff0, gaff1, 0.45, "wood_c", r1=0.3, sides=8)
    _sail_quad(a, (boom0 + Vector((0, 0, 0.6)), boom1 + Vector((0, 0, 0.6)), gaff1 - Vector((0, 0, 0.6)), gaff0 - Vector((0, 0, 0.6))), (1, 0, 0), 2.2)
    with a.in_group("Sails"):
        a._prim_box_only(((boom0.x + gaff1.x) / 2 + 1.0, (boom0.y + boom1.y) / 2, (boom0.z + gaff1.z) / 2), (0.2, abs(boom1.y - boom0.y), gaff0.z - boom0.z), "sail")
    # 삼각돛 (지브) 2장
    fore_top = mast_tops["Fore"][0]
    for (t_bs, t_mast) in ((0.95, 0.78), (0.6, 0.62)):
        tack = bs0.lerp(bs1, t_bs)
        head = Vector((0, fy + 0.8, DECK)).lerp(fore_top, t_mast)
        foot = Vector((0, H.y(0.9), FC + 3.5))
        _sail_quad(a, (foot, tack, head, head + Vector((0, -0.01, 0))), (1, 0, 0), 1.6, nx=8, ny=8)
        with a.in_group("Sails"):
            mid = (tack + head + foot) / 3
            a._prim_box_only(tuple(mid), (0.2, (tack - foot).length * 0.7, (head - foot).length * 0.6), "sail", rot=(math.degrees(math.atan2((head - foot).y, (head - foot).z)) * -1, 0, 0))
    # 깃발
    with a.no_parts(), a.in_group("Sails"):
        mt = mast_tops["Main"][0]
        def flag(u, v):
            return (0.2 * math.sin(u * 6 + v), mt.y - 0.3 - u * 8.0, mt.z - 0.6 - v * 2.4 + 0.4 * math.sin(u * 3.0))
        a.mesh(geom.solidify(*geom.grid_surface(flag, 14, 3), 0.08), "cloth_green")
    # ── 삭구 (슈라우드 + 래트라인 + 스테이) ──
    for s_m, h, name in masts:
        top, tz, y = mast_tops[name]
        for side in (1, -1):
            chain_s = [s_m - 0.05, s_m - 0.02, s_m + 0.01]
            feet = [Vector((side * (H.half_width_at(cs, DECK + 3.0) + 0.3), H.y(cs), DECK + 3.4)) for cs in chain_s]
            head = Vector((side * 1.2, y, tz - 0.4))
            for f in feet:
                _rope(a, f, head, r=0.12)
            # 래트라인
            with a.no_parts():
                for k in range(1, 12):
                    t = k / 12
                    p0 = feet[0].lerp(head, t)
                    p1 = feet[-1].lerp(head, t)
                    a.cyl(p0, p1, 0.06, "rope_dk", sides=3)
            # 위쪽 슈라우드 (망대 → 꼭대기)
            with a.no_parts():
                _rope(a, Vector((side * 3.2, y, tz + 0.2)), top - Vector((0, 0, 2.0)), r=0.09, part=False)
    # 스테이
    with a.no_parts():
        _rope(a, mast_tops["Main"][0] - Vector((0, 0, 1.0)), mast_tops["Fore"][0] - Vector((0, 0, 3.0)), sag=0.8, r=0.1, part=False)
        _rope(a, mast_tops["Fore"][0] - Vector((0, 0, 1.0)), bs1, sag=1.5, r=0.12, part=False)
        _rope(a, Vector((0, mast_tops["Main"][2], DECK + 38)), Vector((0, fy, DECK + 10)), sag=0.3, r=0.08, part=False)
        _rope(a, mast_tops["Main"][0] - Vector((0, 0, 1.0)), Vector((0, H.y(0.02), QD + 3.0)), sag=1.0, r=0.1, part=False)
        _rope(a, bs1, Vector((0, H.y(0.985), 2.5)), sag=0.3, r=0.1, part=False)
    # ── 선미 갑판 설비 ──
    _wheel(a, (0, H.y(0.1), QD + 3.2), r=2.1)
    a.box((0, H.y(0.1) - 0.3, QD + 1.5), (1.2, 1.2, 3.0), "wood_dark", bevel=0.08)
    a.collider((0, H.y(0.1), QD + 2.0), (2.6, 1.6, 4.0), tag="Prop")
    a.marker("Helm", (0, H.y(0.1) - 2.2, QD + 0.1))
    # 종
    bell = Vector((4.5, H.y(0.17), QD + 5.6))
    S.post(a, 4.5, H.y(0.17) - 1.2, QD, QD + 6.4, 0.4)
    S.post(a, 4.5, H.y(0.17) + 1.2, QD, QD + 6.4, 0.4)
    a.box((4.5, H.y(0.17), QD + 6.5), (0.6, 3.0, 0.4), "wood_dark", bevel=0.05)
    prof = [(0.0, 0.2), (-0.3, 0.38), (-0.9, 0.55), (-1.3, 0.8)]
    a.tube([bell + Vector((0, 0, z)) for z, _ in prof], [r for _, r in prof], "brass", sides=12, part_step=2)
    a.marker("ShipBell", tuple(bell))
    # 선미 랜턴 (큰 것 2)
    for sx in (-1, 1):
        S.lantern(a, (sx * (tw - 0.8), H.y(0.0) - 0.8, QD + 5.0), scale=1.6, rng_range=34, brightness=1.8, bracket=(0, 1))
    # 주갑판 설비: 승객 벤치, 화물, 해치
    for side in (1, -1):
        for s_b in (0.3, 0.62):
            y = H.y(s_b)
            w = H.half_width_at(s_b, DECK) - 1.9
            a.box((side * w, y, DECK + 1.6), (1.6, 7.0, 0.3), "wood_c", bevel=0.05)
            for dy in (-3.0, 3.0):
                a.box((side * w, y + dy, DECK + 0.8), (1.2, 0.4, 1.6), "wood_dark", bevel=0.04)
            a.collider((side * w, y, DECK + 0.9), (1.6, 7.0, 1.8), tag="Seat")
            a.marker("Seat", (side * w, y, DECK + 1.8), rot=(0, 0, -90 * side))
    # 화물 해치 (격자)
    hy = H.y(0.56)
    a.box((0, hy, DECK + 0.5), (7.0, 6.0, 1.0), "wood_dark", bevel=0.1)
    with a.no_parts():
        for k in range(6):
            a.box((-3.0 + k * 1.2, hy, DECK + 1.05), (0.25, 5.6, 0.2), "wood_c", bevel=0.0)
            a.box((0, hy - 2.5 + k * 1.0, DECK + 1.1), (6.6, 0.25, 0.2), "wood_c", bevel=0.0)
    a.collider((0, hy, DECK + 0.6), (7.0, 6.0, 1.2), tag="Prop")
    S.barrel(a, (-4.6, H.y(0.74), DECK))
    S.barrel(a, (-4.2, H.y(0.765), DECK), h=2.6, r=1.0, key="wood_c")
    S.crate(a, (4.4, H.y(0.75), DECK), 2.6, 8)
    S.rope_coil(a, (3.0, H.y(0.36), DECK))
    S.rope_coil(a, (-3.2, H.y(0.88), FC))
    # 닻 (선수 좌현)
    ax, ay = -H.half_width_at(0.9, 8.0) - 0.8, H.y(0.9)
    with a.at(loc=(ax, ay, 5.0), rot=(0, 10, 0)):
        a.cyl((0, 0, -3.5), (0, 0, 1.5), 0.3, "iron", sides=8)
        a.cyl((-1.3, 0, 1.0), (1.3, 0, 1.0), 0.22, "iron", sides=6)
        arc = [Vector((math.sin(t) * 2.0, 0, -3.5 + 1.4 * (1 - math.cos(t)))) for t in [(-1.3 + i * 2.6 / 8) for i in range(9)]]
        a.tube(arc, 0.3, "iron", sides=6, part_step=4)
    _figurehead(a, H)
    # ── 도선판 (Gangplank) — 우현 개구부, 힌지 축은 Y 방향 ──
    gs = (GANG[0] + GANG[1]) / 2
    gy = H.y(gs)
    gw = H.half_width_at(gs, DECK) - 0.3
    with a.in_group("Gangplank"):
        # 내려간(전개) 상태로 모델링: 힌지 (gw, gy, DECK) 에서 +X 로 6 stud
        for k in range(5):
            a.box((gw + 3.0, gy - 2.0 + k * 1.0, DECK - 0.15), (6.2, 0.92, 0.3), S.pick(a, S.WOOD), bevel=0.04)
        for dy in (-2.6, 2.6):
            a.box((gw + 3.0, gy + dy, DECK - 0.35), (6.2, 0.35, 0.5), "wood_dark", bevel=0.04)
        for k in range(4):
            a.box((gw + 0.8 + k * 1.5, gy, DECK + 0.05), (0.2, 4.8, 0.14), "wood_dark", bevel=0.0)
        a.collider((gw + 3.0, gy, DECK - 0.4), (6.2, 5.4, 0.8), tag="Gangplank")
    a.marker("GangplankHinge", (gw, gy, DECK), rot=(0, 0, 0), axis="Y", stowedAngle=-80)
    a.marker("Wake", (0, H.y(0.0) - 2.0, 0.2))
    a.marker("BowSpray", (0, H.y(1.0) + 1.5, 0.8))
    a.marker("SmokeLantern", (0, H.y(0.02), QD + 6.0))
    a.attributes.update({"DeckHeight": DECK, "Length": H.L, "HalfBeam": H.B})
    return a


def rowboat():
    a = Asset("Rowboat", "Prop", description="노 젓는 작은 배 (장식/정박)")
    H = Hull(length=16.0, beam=3.0, keel=-0.8, sheer_mid=1.8, sheer_bow=2.8, sheer_stern=2.4, transom=0.6, bow_rise=1.2, stern_rise=-0.4)
    _hull_surface(a, H, ns=20, nt=8, keys={"bottom": "wood_wet", "side": "wood_b", "band": "wood_teal"}, part_ns=6, part_nt=3, band=(1.2, 0.5))
    tp = [H.point(0.0, i / 8) for i in range(9)]
    verts = [Vector((p.x, p.y, p.z)) for p in tp] + [Vector((-p.x, p.y, p.z)) for p in tp]
    faces = [(i, i + 1, 9 + i + 1, 9 + i) for i in range(8)]
    a.mesh((verts, faces, [tuple((verts[k].x, verts[k].z) for k in f) for f in faces], [False] * 8), "wood_b")
    # 안쪽 바닥 & 가로대(자리)
    a.box((0, 0, -0.1), (3.6, 12.0, 0.2), "wood_dark", bevel=0.03)
    for s in (0.3, 0.55, 0.78):
        w = H.half_width_at(s, 1.2)
        a.box((0, H.y(s), 1.2), (2 * w - 0.2, 1.0, 0.25), "wood_c", bevel=0.04)
    # 거널 캡
    with a.no_parts():
        for side in (1, -1):
            pts = [Vector((side * H.point(i / 16, 1.0).x, H.y(i / 16), H.sheer(i / 16) + 0.08)) for i in range(17)]
            a.tube(pts, 0.14, "wood_dark", sides=5, caps=False, part=False)
    # 노 2개
    for side in (1, -1):
        a.cyl((side * 1.0, -0.5, 1.8), (side * 5.5, -2.5, 0.2), 0.12, "wood_pale", sides=6)
        a.box((side * 5.9, -2.7, 0.05), (0.8, 1.6, 0.12), "wood_pale", rot=(0, 0, 25 * side), bevel=0.02)
    a.collider((0, 0, 0.6), (5.6, 15.0, 2.0), tag="Prop")
    return a


def shipwreck():
    a = Asset("Shipwreck", "Landmark", description="난파선 잔해 (얕은 여울에 기운 선체)")
    H = Hull(length=60.0, beam=9.0, keel=-4.0, sheer_mid=8.0, sheer_bow=10.5, sheer_stern=11.0)
    with a.at(loc=(0, 0, -3.0), rot=(0, 18, 8)):
        # 뒤쪽 절반만 남은 선체 + 갈비뼈
        for side in (1, -1):
            def fn(u, v, side=side):
                s = 0.05 + 0.55 * u
                p = H.point(s, v)
                return (p.x * side, p.y, p.z)
            v, f, uv, sm = geom.grid_surface(fn, 18, 10)
            # 구멍: 무작위 판 제거
            keep = [i for i in range(len(f)) if a.rng.random() > (0.35 if side > 0 else 0.1)]
            f = [f[i] for i in keep]
            uv = [uv[i] for i in keep]
            sm = [sm[i] for i in keep]
            if side < 0:
                f = [tuple(reversed(x)) for x in f]
                uv = [tuple(reversed(x)) for x in uv]
            geo = geom.solidify(v, f, uv, sm, 0.4)
            a.mesh(geo, "planks_hull_dk")
        for k in range(12):
            s = 0.08 + k * 0.06
            rib = [H.point(s, i / 8) for i in range(9)]
            pts = [Vector((-p.x, p.y, p.z)) for p in reversed(rib)] + [Vector((p.x, p.y, p.z)) for p in rib[1:]]
            a.tube(pts, 0.35, "wood_wet", sides=5, caps=True, part_step=4)
        # 부러진 돛대
        a.cyl((0, H.y(0.4), 0), (2.0, H.y(0.4) + 3.0, 20.0), 0.9, "wood_dark", sides=10)
        a.box((2.2, H.y(0.4) + 3.4, 20.6), (1.6, 1.6, 1.4), "wood_dark", rot=(30, 20, 10), bevel=0.1)
        with a.no_parts():
            for k in range(6):
                a.blob((a.rng.uniform(-6, 6), H.y(a.rng.uniform(0.1, 0.55)), a.rng.uniform(0, 5)), a.rng.uniform(0.8, 1.6), "moss", seg=8, rings=5, amp=0.3, scale=(1.5, 1.3, 0.4))
            S.hanging_moss(a, (2.0, H.y(0.4) + 3.0, 19.0), length=5.0, strands=6)
        S.barrel(a, (5.0, H.y(0.3), 4.0), lying=True, yaw=40)
        S.crate(a, (-3.0, H.y(0.2), 2.0), 2.6, 25)
    a.collider((0, H.y(0.3), 0), (16, 34, 10), rot=(0, 18, 8), tag="Prop")
    a.marker("Loot", (0, H.y(0.3), 2.0))
    return a


ASSETS = [ferry, rowboat, shipwreck]
ferry.preview = {"env": "sea", "azim": 50, "elev": 14, "pad": 1.0}
shipwreck.preview = {"env": "sea"}
